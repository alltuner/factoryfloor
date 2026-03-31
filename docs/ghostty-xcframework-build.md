# Building the Ghostty XCFramework

Factory Floor depends on `libghostty` via an xcframework built from the [Ghostty](https://github.com/ghostty-org/ghostty) source. This document covers how to build it and known issues.

## Requirements

- **Zig 0.15.2** (exact version required; check with `zig version`)
- **Xcode** (not just Command Line Tools)
- **Metal Toolchain**: install via `xcodebuild -downloadComponent MetalToolchain`
- **gettext**: `brew install gettext`

Verify Xcode is the active developer directory:

```bash
xcode-select --print-path
# Expected: /Applications/Xcode.app/Contents/Developer
# If not: sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

## Standard Build (macOS 15 and earlier)

```bash
cd ghostty
zig build -Demit-xcframework=true -Dxcframework-target=native -Doptimize=ReleaseFast
```

The xcframework is output to `macos/GhosttyKit.xcframework/`.

## macOS 26 (Tahoe) Workaround

On macOS 26+, Apple's XProtect content scanning blocks a deliberately malformed JPEG test file (`hippopotamus-bad-comment-length.jpeg`) in the `wuffs` image decoding dependency. This causes Zig's package manager to fail with:

```
error: unable to hash 'wuffs-0.4.0-alpha.9/test/data/artificial-jpeg/hippopotamus-bad-comment-length.jpeg': PermissionDenied
```

This is not a file permissions issue. macOS scans file contents at the kernel level and blocks this specific file because it has an intentionally corrupted JPEG comment header. The block applies regardless of file ownership, extended attributes, or filesystem location.

**Things that do NOT fix it:**
- `sudo chown -R $(whoami) .`
- `xattr -r -d com.apple.quarantine ~/.cache/zig`
- `xattr -r -d com.apple.provenance /opt/homebrew`
- `xattr -rc ~/.cache/zig`
- Clearing the Zig cache (`rm -rf ~/.cache/zig`)
- Moving the repo out of `~/Desktop`
- Using the official Ghostty source tarball (it still fetches wuffs remotely)
- Adding the terminal to Developer Tools in Privacy & Security

### Fix: Use a local wuffs dependency with the blocked file replaced

1. **Download the Ghostty source tarball** (contains preprocessed deps, fewer fetch requirements):

   ```bash
   cd /tmp
   curl -LO https://release.files.ghostty.org/1.3.1/ghostty-1.3.1.tar.gz
   tar xzf ghostty-1.3.1.tar.gz
   ```

2. **Download and patch the wuffs dependency** (replace the blocked JPEG):

   ```bash
   cd /tmp
   mkdir wuffs-manual && cd wuffs-manual
   curl -sL "https://deps.files.ghostty.org/wuffs-122037b39d577ec2db3fd7b2130e7b69ef6cc1807d68607a7c232c958315d381b5cd.tar.gz" -o wuffs.tar.gz
   tar xzf wuffs.tar.gz

   # Replace the blocked file with a minimal valid JPEG
   rm -f wuffs-0.4.0-alpha.9/test/data/artificial-jpeg/hippopotamus-bad-comment-length.jpeg
   printf '\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00\xff\xd9' \
     > wuffs-0.4.0-alpha.9/test/data/artificial-jpeg/hippopotamus-bad-comment-length.jpeg
   ```

3. **Copy patched wuffs into the Ghostty source tree**:

   ```bash
   cp -R /tmp/wuffs-manual/wuffs-0.4.0-alpha.9 /tmp/ghostty-1.3.1/pkg/wuffs/wuffs-src
   ```

4. **Point the build at the local copy** by editing `/tmp/ghostty-1.3.1/pkg/wuffs/build.zig.zon`:

   Replace:
   ```zig
   .wuffs = .{
       .url = "https://deps.files.ghostty.org/wuffs-...",
       .hash = "N-V-__8AAAzZywE3s51XfsLbP9eyEw57ae9swYB9aGB6fCMs",
       .lazy = true,
   },
   ```

   With:
   ```zig
   .wuffs = .{
       .path = "wuffs-src",
       .lazy = true,
   },
   ```

5. **Build the xcframework**:

   ```bash
   rm -rf ~/.cache/zig
   cd /tmp/ghostty-1.3.1
   zig build -Demit-xcframework=true -Dxcframework-target=native -Doptimize=ReleaseFast
   ```

6. **Copy the result to the project** (arm64 only; sufficient for Apple Silicon development):

   ```bash
   mkdir -p ~/Desktop/vibefloor/ghostty/macos/GhosttyKit.xcframework/macos-arm64_x86_64
   cp /tmp/ghostty-1.3.1/macos/GhosttyKit.xcframework/macos-arm64/libghostty-fat.a \
      ~/Desktop/vibefloor/ghostty/macos/GhosttyKit.xcframework/macos-arm64_x86_64/libghostty.a
   ```

## Known Limitations

- **arm64 only**: This workaround produces an arm64-only binary placed in the `macos-arm64_x86_64` directory to match the expected path. It works for development on Apple Silicon but is not a true universal binary.
- **Ghostty version-specific**: The wuffs dependency URL and hash are tied to the Ghostty version. When updating the Ghostty submodule, you may need to repeat this process with the new URL from `pkg/wuffs/build.zig.zon`.
- **macOS version-specific**: This workaround is only needed on macOS 26 (Tahoe) and later. On macOS 15 (Sequoia) and earlier, the standard build command works without modification.

## Verifying the Build

```bash
ls -la ghostty/macos/GhosttyKit.xcframework/macos-arm64_x86_64/libghostty.a
# Should show ~56MB file
```

Then continue with the normal Factory Floor build:

```bash
cd ~/Desktop/vibefloor
xcodegen generate
./scripts/dev.sh build
```
