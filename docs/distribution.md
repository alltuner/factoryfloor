# Distribution

## Channels

Factory Floor ships via two channels:

1. **Homebrew cask** (primary): `brew install --cask alltuner/tap/factoryfloor`
   - Installs the app and the `ff` CLI automatically
   - Upgrade: `brew upgrade --cask factoryfloor`
2. **Direct DMG** via GitHub Releases
   - CLI available from Settings > Environment

## Update notification

The app checks `https://factory-floor.com/versions.json` on launch
and every 6 hours. If a newer stable version exists, a badge appears
in the sidebar linking to `factory-floor.com/get`.

`versions.json` is updated automatically by the release workflow.

## Release flow

1. Merge conventional commits into `main`
2. release-please opens or updates a version bump PR
3. Merge the release PR
4. CI runs the `build` job:
   - Checkout with submodules, install XcodeGen
   - Build release with xcodebuild
   - Create temporary keychain, import signing certificate
   - Notarize via stored keychain profile
   - Create and sign DMG
   - Upload DMG to GitHub release
   - Update Homebrew cask in `alltuner/homebrew-tap`
   - Update `versions.json` and trigger website deploy
5. Website deploys automatically (GitHub Pages)
6. Users see update badge on next app launch

## Required secrets

| Secret | Purpose |
|--------|---------|
| `CERTIFICATE_P12_BASE64` | Code signing certificate |
| `CERTIFICATE_PASSWORD` | Certificate password |
| `APPLE_ID` | Apple Developer account |
| `APPLE_TEAM_ID` | Team identifier |
| `APPLE_APP_PASSWORD` | App-specific password for notarization |
| `HOMEBREW_TAP_TOKEN` | PAT with `public_repo` scope for tap updates |

## versions.json

```json
{
  "stable": "1.0.0",
  "latest": "1.0.0"
}
```

- `stable`: current release version
- `latest`: same as stable for now; reserved for future beta channel

## Local release (manual)

```bash
./scripts/release.sh [version]
```

Builds, signs, notarizes, and creates a DMG locally. Version defaults
to the value in `.release-please-manifest.json` if not provided.

## Auto-update (future)

Sparkle integration is planned after the release pipeline is stable.
The `bleedingEdge` setting in the app is reserved for future beta
channel selection.

## Release verification checklist

After a release, verify:

1. GitHub release exists with notarized DMG attached
2. Homebrew cask points to the new DMG
3. `factory-floor.com/versions.json` reports the new version
4. `/get` page shows correct install/upgrade commands
5. App shows update badge when running an older version
