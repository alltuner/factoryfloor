# Distribution Plan

## Summary

This document consolidates the previous release runbook and the
distribution strategy notes into a single source of truth.

The core conclusion is:

- Homebrew cask distribution is live
- direct DMG distribution is also live
- in-app update notification exists
- full auto-update does not exist yet
- the main gap is that release publishing and `versions.json` updates are not automated together

That last point is the real scope issue. The docs describe an update
story that is conceptually sound, but the current pipeline does not
fully implement it.

## Current Reality

### Distribution channels

These channels are already live:

- Homebrew cask via `alltuner/homebrew-tap`
- direct DMG via GitHub Releases

This is not future tense. The release workflow in
[`.github/workflows/release.yml`](/Users/dpoblador/repos/ff2/.github/workflows/release.yml)
already:

- builds and signs the app
- creates and notarizes a DMG
- uploads the DMG to the GitHub release
- updates the Homebrew cask in `alltuner/homebrew-tap`

### Update notification

The app already checks
[`website/static/versions.json`](/Users/dpoblador/repos/ff2/website/static/versions.json)
through
[`Sources/Models/UpdateChecker.swift`](/Users/dpoblador/repos/ff2/Sources/Models/UpdateChecker.swift).

That means update notification is not hypothetical either. It already
exists and is shown in the sidebar.

### Website deployment

The website deploy workflow only runs when `website/**` changes or when
it is triggered manually. It is not part of the release workflow.

That means a new app release does not automatically guarantee a matching
update to `versions.json`.

## Corrections To The Existing Docs

The current docs drift in a few places.

### 1. Direct DMG is live

The strategy doc says direct DMG is secondary and implied as not fully
there yet. In practice, it is already part of the automated release
pipeline and should be treated as live.

### 2. Homebrew now installs `ff`

The old guide says the cask does not install the bundled `ff` command
automatically. That is no longer true.

The current release workflow writes this into the cask:

- `binary "#{appdir}/Factory Floor.app/Contents/Resources/ff", target: "ff"`

So Homebrew installs the CLI automatically.

### 3. The update feed is operational but not release-coupled

The strategy doc is directionally right about `versions.json`, but it
underspecifies the operational problem: nothing in the release workflow
currently updates that file.

## Recommended Distribution Model

### Channel strategy

Keep two supported channels:

1. Homebrew cask, primary for developers
2. direct DMG, primary for non-Homebrew users

Do not make one of them “experimental.” Both are already part of the
actual shipped system.

### Update strategy

For the current phase:

- keep in-app update notification
- do not add full auto-update yet
- defer Sparkle until the release pipeline is stable and the update feed is automated

This is the right order. Shipping Sparkle before the release metadata
story is reliable would create a second update mechanism on top of an
already inconsistent one.

## Release Flow

The real release flow today is:

1. merge conventional commits into `main`
2. release-please opens or updates a release PR
3. merge the release PR
4. GitHub creates the tagged release
5. CI builds, signs, notarizes, uploads the DMG, and updates the Homebrew cask
6. users can install or upgrade via Homebrew or download the DMG from GitHub Releases

What is missing from that flow:

7. update the app-visible version feed
8. deploy the website changes for that feed

Without those two steps, the app can ship a release that the sidebar
does not advertise.

## Main Scope Improvement

Automate the version feed as part of release publishing.

This is the highest-value improvement because it closes the gap between:

- what the release pipeline publishes
- what the app tells users is available

### Recommendation

Treat `versions.json` as release metadata, not website content that
happens to live in the website tree.

In practical terms:

- the release workflow should update `website/static/versions.json`
- that update should trigger website deployment automatically
- the release should not be considered fully published until the feed is updated

## Recommended `versions.json` Scope

The current shape is:

```json
{
  "stable": "0.1.0",
  "latest": "0.1.0"
}
```

That is enough for the current app behavior, but the naming is vague.

Recommended shape:

```json
{
  "stable": "1.2.0",
  "latest": "1.2.0",
  "url": "https://factory-floor.com/get"
}
```

If beta or bleeding-edge releases are introduced later, add them
explicitly rather than overloading `latest`.

For example:

```json
{
  "stable": "1.2.0",
  "latest": "1.3.0-beta.1",
  "beta": "1.3.0-beta.1",
  "url": "https://factory-floor.com/get"
}
```

That keeps the semantics obvious.

## Open Questions And Recommended Answers

### 1. Should the website be part of release completion?

Yes.

If the app uses `factory-floor.com/versions.json` to advertise updates,
then website deployment is part of the release path, not a side concern.

### 2. Should the app query GitHub Releases directly instead of `versions.json`?

Not yet.

That would remove one moving part, but it also adds:

- GitHub API dependency
- rate-limit concerns
- more parsing logic in the app
- less control over stable versus beta presentation

`versions.json` is still the simpler product surface. The issue is not
the file. The issue is that the release workflow does not own it yet.

### 3. Should Sparkle be added now?

No.

Sparkle should wait until:

- release assets are stable
- the version feed is automated
- channel semantics are clear

Otherwise the team will end up debugging distribution and auto-update at
the same time.

### 4. Should Homebrew and direct DMG remain equally supported after Sparkle?

Yes, but with different expectations.

- Homebrew remains manual-update friendly and developer-oriented
- direct DMG becomes the path that benefits most from Sparkle

Do not try to force Homebrew users into app-managed updates.

### 5. Should `ff` installation still be documented as manual?

No.

That should be documented differently by channel:

- Homebrew: `ff` is installed automatically
- direct DMG: `ff` requires manual symlink or a future installer step

## Recommended V1 Documentation Position

If we want one honest document that matches the current product, it
should say:

- Factory Floor ships via Homebrew and direct DMG today
- the app shows update notifications today
- upgrades are still manual today
- Sparkle is intentionally deferred
- release automation already covers signing, notarization, GitHub upload, and Homebrew updates
- release automation does not yet fully cover the website-backed version feed

That is accurate and not hand-wavy.

## Suggested Follow-Up Work

### Must do

- automate `website/static/versions.json` updates from the release workflow
- ensure website deployment happens as part of release completion
- update docs to reflect that Homebrew installs `ff`

### Should do

- add a release verification checklist for feed freshness and download path
- decide whether `latest` should mean “latest stable” or “latest any channel”
- document direct-DMG CLI installation more clearly

### Later

- Sparkle integration
- beta channel semantics tied to `bleedingEdge`
- richer update feed metadata such as release notes URL and download URL

## Release Verification Checklist

After a release, verify:

1. the GitHub release exists with the notarized DMG attached
2. the Homebrew cask points at the new DMG and checksum
3. `/get` still points users to valid install and download paths
4. `versions.json` reports the released stable version
5. the app surfaces the update when run against an older installed version

This is the missing operational discipline in the current docs.

## Recommendation

Use this as the new source of truth.

The main technical decision is not which distribution channel to choose.
That part is already settled. The real decision is to make release
metadata part of the release pipeline, so the app, website, GitHub
release, and Homebrew tap stop drifting apart.
