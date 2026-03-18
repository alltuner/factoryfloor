# Sparkle Auto-Update Integration

GitHub issue: #39

## Background

Factory Floor currently notifies users about new versions by polling
`factory-floor.com/versions.json` and showing a badge in the sidebar
(see `UpdateChecker.swift`). Users must then manually download the DMG
from GitHub Releases or run `brew upgrade`. Sparkle replaces this with
true in-app auto-updates: check, download, verify, and install, all
without leaving the app.

[Sparkle](https://sparkle-project.org/) is the standard auto-update
framework for macOS apps. Both
[ghostty](https://github.com/ghostty-org/ghostty/blob/main/.github/workflows/release-tag.yml)
and [cmux](https://github.com/manaflow-ai/cmux/blob/main/.github/workflows/release.yml)
use it. Sparkle uses Ed25519 signatures to verify updates, and an
appcast (RSS-like XML feed) to advertise available versions.

## How It Works

1. On launch (or on a schedule), Sparkle fetches `appcast.xml` from a
   known URL.
2. If a newer version exists, it presents update UI to the user.
3. The user confirms; Sparkle downloads the DMG, verifies the Ed25519
   signature, extracts the app, and replaces the running binary.
4. The app relaunches.

## Implementation Plan

### 1. Generate Ed25519 Keypair

Sparkle provides a `generate_keys` tool. Run it once locally:

```bash
# From a Sparkle checkout or the SPM binary download
./bin/generate_keys
```

This outputs:
- A **private key** (base64 string) -- store as a GitHub Actions secret
  (`SPARKLE_PRIVATE_KEY`).
- A **public key** (base64 string) -- injected into `Info.plist` at
  build time as `SUPublicEDKey`.

The private key signs the DMG during CI. The public key in the app
verifies the signature before installing.

### 2. Add Sparkle SPM Dependency

In `project.yml`, add the package and link it to the `FactoryFloor`
target:

```yaml
packages:
  Sparkle:
    url: https://github.com/sparkle-project/Sparkle
    from: "2.9.0"

targets:
  FactoryFloor:
    dependencies:
      - package: Sparkle
        product: Sparkle
```

### 3. Info.plist Keys

Add placeholder keys to `Resources/Info.plist`. The CI workflow will
overwrite `SUPublicEDKey` with the real value at build time (same
pattern ghostty and cmux use).

| Key | Value | Notes |
|-----|-------|-------|
| `SUPublicEDKey` | (empty or placeholder) | Overwritten by CI with real public key |
| `SUFeedURL` | `https://github.com/alltuner/factoryfloor/releases/latest/download/appcast.xml` | Points to the appcast hosted as a GitHub release asset |
| `SUEnableAutomaticChecks` | `false` | Let users opt in via Settings |

Using `releases/latest/download/` means GitHub always redirects to the
most recent release's `appcast.xml`, so we don't need a separate CDN.

### 4. App Code Changes

**New: `Sources/Models/Updater.swift`**

Minimal Sparkle controller, similar to ghostty's `UpdateController.swift`
but simpler (we can use Sparkle's standard UI initially):

```swift
import Sparkle

@MainActor
final class Updater: ObservableObject {
    private let controller: SPUStandardUpdaterController

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var canCheckForUpdates: Bool {
        controller.updater.canCheckForUpdates
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
```

`SPUStandardUpdaterController` with `startingUpdater: true` handles
everything: scheduling background checks, showing the standard Sparkle
update dialog, downloading, verifying, and installing. This is the
simplest integration path.

**Modify: `FF2App.swift`**

- Instantiate `Updater` as a `@StateObject`.
- Add a "Check for Updates" menu item wired to `updater.checkForUpdates()`.

**Modify: `SettingsView.swift`**

- Wire the existing `bleedingEdge` toggle to select between stable and
  bleeding-edge appcast URLs (future, when we have a tip channel).
- Optionally add an "Automatically check for updates" toggle bound to
  `controller.updater.automaticallyChecksForUpdates`.

**Remove or repurpose: `UpdateChecker.swift`**

The current `UpdateChecker` that polls `versions.json` becomes
redundant once Sparkle handles update detection. It can be removed, or
kept temporarily as a fallback for Homebrew users who won't get Sparkle
updates (Homebrew replaces the app bundle, so Sparkle's in-app updater
doesn't apply to them). The sidebar badge could remain for Homebrew
users, driven by the existing `versions.json` check.

### 5. Codesign Sparkle Frameworks

Sparkle bundles embedded frameworks and XPC services that must be
codesigned. Add this to the release workflow's "Package and sign" step,
before signing the main app bundle:

```bash
# Codesign Sparkle framework components
/usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --timestamp --options=runtime \
  "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc"
/usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --timestamp --options=runtime \
  "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc"
/usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --timestamp --options=runtime \
  "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate"
/usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --timestamp --options=runtime \
  "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app"
/usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --timestamp --options=runtime \
  "$APP/Contents/Frameworks/Sparkle.framework"
```

This matches how ghostty handles it in their `release-tag.yml`.

### 6. Release Workflow Changes (`release.yml`)

Add these steps to the `build` job:

**a) Setup Sparkle tools**

Download the pre-built Sparkle binaries (specifically `sign_update` and
optionally `generate_appcast`):

```yaml
- name: Setup Sparkle
  env:
    SPARKLE_VERSION: "2.9.0"
  run: |
    mkdir -p .action/sparkle
    cd .action/sparkle
    curl -L https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-for-Swift-Package-Manager.zip > sparkle.zip
    unzip sparkle.zip
    echo "$(pwd)/bin" >> $GITHUB_PATH
```

**b) Inject Sparkle keys into Info.plist (after build, before codesign)**

```yaml
- name: Inject Sparkle keys
  env:
    SPARKLE_PUBLIC_KEY: ${{ secrets.SPARKLE_PUBLIC_KEY }}
  run: |
    APP="build/release/${APP_NAME}.app"
    /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey $SPARKLE_PUBLIC_KEY" "$APP/Contents/Info.plist"
```

**c) Generate and sign appcast (after DMG notarization)**

Two approaches are viable here. The simpler one (cmux-style) uses
`generate_appcast`:

```yaml
- name: Generate appcast
  env:
    SPARKLE_PRIVATE_KEY: ${{ secrets.SPARKLE_PRIVATE_KEY }}
  run: |
    echo "$SPARKLE_PRIVATE_KEY" > /tmp/sparkle_key
    sign_update -f /tmp/sparkle_key "build/release/$DMG_NAME" > /tmp/sign_output.txt

    # Use generate_appcast or build appcast manually
    python3 scripts/generate_appcast.py
    rm -f /tmp/sparkle_key
```

We'll need a small script (`scripts/generate_appcast.py`) to produce
the XML. This can be modeled on ghostty's `update_appcast_tag.py` but
simplified: we only need one channel and one item (the latest release).

**d) Upload appcast as release asset**

```yaml
- name: Upload appcast
  env:
    GH_TOKEN: ${{ github.token }}
    TAG_NAME: ${{ needs.release-please.outputs.tag_name }}
  run: |
    gh release upload "$TAG_NAME" appcast.xml
```

### 7. Appcast Hosting

**Recommended: GitHub release asset** (same as cmux)

Set `SUFeedURL` to:
```
https://github.com/alltuner/factoryfloor/releases/latest/download/appcast.xml
```

GitHub's `latest/download/` path always redirects to the most recent
release's assets. This means:
- No separate hosting infrastructure needed.
- The appcast is versioned alongside the DMG.
- Each release gets its own `appcast.xml` with the current version's
  entry.

**Alternative: CDN (like ghostty)**

Ghostty hosts appcast on `release.files.ghostty.org` (Cloudflare R2)
and maintains a cumulative appcast with version history. This is more
complex but supports features like delta updates and version-specific
minimum OS requirements. Not needed for our scale.

**Alternative: `factory-floor.com/appcast.xml`**

Host on our existing website. Simpler than R2 but requires the website
deploy workflow to also update the appcast. Adds a coupling between
release and website deploy that doesn't exist today.

### 8. Appcast Generation Script

Create `scripts/generate_appcast.py` that:

1. Reads the DMG signature from `sign_update` output.
2. Reads the version from the release-please output.
3. Produces a single-item appcast XML with:
   - `sparkle:version` (build number)
   - `sparkle:shortVersionString` (semver)
   - `sparkle:edSignature` and `length` on the enclosure
   - `sparkle:minimumSystemVersion` of `14.0` (matching our deployment
     target)
   - Download URL pointing to the DMG on GitHub Releases

Since we use release-please with a single stable channel, we only need
the latest version in the appcast (not a cumulative history like
ghostty).

## Security Considerations

### Key Management

| Secret | Purpose | Who generates it |
|--------|---------|-----------------|
| `SPARKLE_PRIVATE_KEY` | Signs the DMG for Ed25519 verification | One-time `generate_keys` run |
| `SPARKLE_PUBLIC_KEY` | Injected into Info.plist for verification | Derived from private key |

- The private key MUST be stored as a GitHub Actions secret, never
  committed to the repo.
- The public key is not sensitive (it's embedded in every shipped app
  binary), but deriving it at build time from the private key (like cmux
  does) avoids storing it separately and ensures they stay in sync.
- If the private key is compromised, all existing installs will trust
  updates signed with it. Rotation requires shipping a transitional
  build signed with the old key that embeds the new public key.
- Sparkle's Ed25519 signatures are independent of Apple's code signing.
  Both are required: Apple's signature satisfies Gatekeeper, Sparkle's
  signature satisfies the updater.

### Non-sandboxed App

Factory Floor runs without the App Sandbox (`com.apple.security.app-sandbox = false`).
This simplifies Sparkle integration because:
- No need for Sparkle's XPC services for privileged installation.
- The updater can replace the app bundle directly.
- Sparkle's XPC services still need to be codesigned (notarization
  requires it) but they won't be used at runtime.

### DMG vs ZIP

Our release workflow produces a DMG. Sparkle supports both DMG and ZIP
as update containers. We should continue using the DMG since it's
already part of our pipeline. Sparkle will mount it, extract the `.app`,
and replace the running copy.

## Files Changed

| File | Change |
|------|--------|
| `project.yml` | Add Sparkle SPM package and dependency |
| `Resources/Info.plist` | Add `SUPublicEDKey`, `SUFeedURL`, `SUEnableAutomaticChecks` |
| `Sources/Models/Updater.swift` | New: Sparkle controller |
| `Sources/Views/FF2App.swift` | Add "Check for Updates" menu item |
| `Sources/Views/SettingsView.swift` | Add auto-update toggle |
| `.github/workflows/release.yml` | Setup Sparkle, inject keys, sign frameworks, generate appcast, upload |
| `scripts/generate_appcast.py` | New: builds appcast.xml from release metadata |
| `Sources/Models/UpdateChecker.swift` | Remove or keep for Homebrew-only fallback |

## New GitHub Secrets

| Secret | Value |
|--------|-------|
| `SPARKLE_PRIVATE_KEY` | Base64 Ed25519 private key from `generate_keys` |

The public key can be derived at build time (like cmux) rather than
stored separately.

## Estimated Complexity

**Small-to-medium.** The core integration is straightforward because:

- Sparkle's `SPUStandardUpdaterController` handles all UI and download
  logic out of the box.
- The release workflow already handles signing, notarization, and DMG
  creation; we're adding steps, not rewriting.
- The appcast generation is a short script.

Breakdown:
- SPM dependency + project.yml: ~30 min
- Updater.swift + menu item + settings toggle: ~1-2 hours
- Info.plist keys: ~15 min
- Release workflow changes (Sparkle setup, key injection, codesign,
  appcast generation, upload): ~2-3 hours
- Appcast generation script: ~1 hour
- Testing (local release build, CI dry run): ~2-3 hours
- Key generation and secret setup: ~30 min

**Total: ~1-2 days**

The main risk is getting the codesigning of Sparkle's embedded
frameworks right on CI. Ghostty's workflow is a reliable reference for
the exact codesign invocations needed.

## Future Work (Not In Scope)

- **Bleeding-edge channel**: Use the existing `bleedingEdge` setting to
  switch `SUFeedURL` between stable and tip appcast URLs (like ghostty's
  dual-channel approach). Requires a separate CI workflow for tip builds.
- **Custom update UI**: Replace Sparkle's standard dialog with an
  in-sidebar update experience (like ghostty's `UpdateDriver` and
  `UpdatePopoverView`). The standard dialog is fine to start with.
- **Delta updates**: Sparkle supports binary diffs to reduce download
  size. Not worth the complexity at our current app size.
- **Cumulative appcast**: Maintain version history in the appcast for
  rollback support. Single-item appcast is sufficient for now.
