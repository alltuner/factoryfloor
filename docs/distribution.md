# Distribution Guide

## Homebrew Cask (alltuner tap)

### Setting up the tap

1. Create a public repo `alltuner/homebrew-tap` (the `homebrew-` prefix is required)
2. Add a cask formula at `Casks/factory-floor.rb`:

```ruby
cask "factory-floor" do
  version "0.1.0"
  sha256 "SHA256_OF_DMG_OR_ZIP"

  url "https://github.com/alltuner/factory-floor/releases/download/v#{version}/FactoryFloor-#{version}.dmg"
  name "Factory Floor"
  desc "AI-powered development workspace for macOS"
  homepage "https://factory-floor.com"

  app "Factory Floor.app"
  binary "#{appdir}/Factory Floor.app/Contents/MacOS/ff", target: "ff"

  zap trash: [
    "~/.config/factoryfloor",
  ]
end
```

3. Users install with: `brew install alltuner/tap/factory-floor`

### Automating cask updates

After each release-please release, a GitHub Action should:
1. Build the signed/notarized app
2. Create a DMG or ZIP
3. Upload it as a release asset
4. Update the cask formula in `alltuner/homebrew-tap` with the new version and SHA256

Use `dawidd6/action-homebrew-bump-cask` or a simple script that updates the formula file via the GitHub API.

## macOS Code Signing and Notarization

### Prerequisites

1. **Apple Developer account** ($99/year): https://developer.apple.com/programs/
2. **Developer ID Application certificate**: Xcode > Settings > Accounts > Manage Certificates > Developer ID Application
3. **Notarization credentials**: App-specific password from https://appleid.apple.com (under "Sign-In and Security" > "App-Specific Passwords")

### Signing the app

```bash
# Build release
xcodegen generate
xcodebuild -project FactoryFloor.xcodeproj -scheme FactoryFloor -configuration Release build

# Sign with Developer ID
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: Your Name (TEAM_ID)" \
  --options runtime \
  "build/Release/Factory Floor.app"
```

### Creating a DMG

```bash
# Create DMG with Applications symlink
hdiutil create -volname "Factory Floor" \
  -srcfolder "build/Release/Factory Floor.app" \
  -ov -format UDZO \
  "FactoryFloor-0.1.0.dmg"

# Sign the DMG
codesign --sign "Developer ID Application: Your Name (TEAM_ID)" \
  "FactoryFloor-0.1.0.dmg"
```

### Notarizing

```bash
# Submit for notarization
xcrun notarytool submit "FactoryFloor-0.1.0.dmg" \
  --apple-id "your@email.com" \
  --team-id "TEAM_ID" \
  --password "app-specific-password" \
  --wait

# Staple the notarization ticket
xcrun stapler staple "FactoryFloor-0.1.0.dmg"
```

### CI automation (GitHub Actions)

Store these as repository secrets:
- `APPLE_CERTIFICATE_BASE64`: Base64-encoded .p12 certificate
- `APPLE_CERTIFICATE_PASSWORD`: Password for the .p12
- `APPLE_ID`: Your Apple ID email
- `APPLE_TEAM_ID`: Your team ID
- `APPLE_APP_SPECIFIC_PASSWORD`: App-specific password for notarytool

The release workflow should:
1. Import the certificate into a temporary keychain
2. Build the release
3. Sign with `codesign`
4. Create DMG
5. Notarize with `notarytool`
6. Staple
7. Upload as release asset

## App Updates (Sparkle)

### Why Sparkle

[Sparkle](https://sparkle-project.org/) is the standard macOS auto-update framework. It checks for updates via an RSS feed (appcast) and handles download, verification, and installation.

### Setup steps

1. **Add Sparkle** as a dependency in `project.yml`:
   ```yaml
   packages:
     Sparkle:
       url: https://github.com/sparkle-project/Sparkle
       from: "2.6.0"
   ```

2. **Generate EdDSA keys** for signing updates:
   ```bash
   ./bin/generate_keys  # from Sparkle tools
   ```
   Store the private key securely. The public key goes in Info.plist.

3. **Add to Info.plist**:
   ```xml
   <key>SUFeedURL</key>
   <string>https://factory-floor.com/appcast.xml</string>
   <key>SUPublicEDKey</key>
   <string>YOUR_PUBLIC_KEY</string>
   ```

4. **Generate appcast** after each release:
   ```bash
   ./bin/generate_appcast /path/to/releases/
   ```
   This creates `appcast.xml` which should be hosted at the `SUFeedURL`.

5. **Add update check** to the app (in `FF2App.swift`):
   ```swift
   import Sparkle
   // In the App struct:
   @StateObject private var updater = SPUStandardUpdaterController(
       startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
   )
   ```

### Update flow

1. User launches app
2. Sparkle checks appcast.xml in background
3. If new version found, shows update dialog
4. User clicks "Install Update"
5. Sparkle downloads, verifies EdDSA signature, installs, relaunches

### Hosting the appcast

The simplest approach: host `appcast.xml` on GitHub Pages alongside the website. The release workflow generates it and commits it to the website.

## CLI Binary (`ff`)

The `ff` command is a shell script installed to `/usr/local/bin/ff` (or via Homebrew). It opens directories in Factory Floor using the `factoryfloor://` URL scheme.

See `Sources/CLI/ff` for the script. Installation is handled by the Homebrew cask's `binary` directive, or manually:

```bash
sudo ln -sf "/Applications/Factory Floor.app/Contents/Resources/ff" /usr/local/bin/ff
```
