# Changelog

All notable changes to Ember. Releases up to 0.2.0 were published under the name Voxel.
Versions follow [Semantic Versioning](https://semver.org); downloads are on the [Releases](https://github.com/SnowyMay111/ember-launcher/releases) page.

## [Unreleased]

### Security
- Instance names are validated in `InstanceStore` (no `..`, separators, leading dot); a crafted `.mrpack` name can no longer point outside `instances/`.
- `.mrpack` archives with symbolic links are rejected before extraction; files without both `sha1` and `sha512` hashes are refused.
- File names from the Modrinth API must be a single plain path component.
- `VOXEL_UPDATE_URL` is read only in debug builds.

### Fixed
- The updater no longer gets stuck when its temporary download was cleaned up.
- The natives `.extracted` marker is written only after a successful unpack and is tied to the native libraries; a forced reinstall clears it.
- Cancelling a `.mrpack` import removes the half-made instance instead of keeping a pack without mods.
- Long AI answers are no longer cut off silently (limits raised to 8192 tokens; a truncated answer is reported).
- Data race on the update download failure; a failed `codesign` now stops release builds.
- Iris detection no longer matches any file name containing "iris".
- The account pill says "Offline nickname" unless a Microsoft account is signed in.
- Imported mods keep their real Modrinth version numbers.
- `Voxel-mac-arm64.zip` is built and uploaded again, so launchers older than 0.2.1 can still update.

### Added
- Warning when an imported pack bundles `.jar` mods that do not come from Modrinth, and a note about secrets in exported configs.
- Unit tests (`scripts/test.sh`) and one User-Agent for all requests.

## [0.2.2] - 2026-10-28

### Added
- **Social & Friends preview**: Added Social screen, quick-access Friends drawer in top bar, and multiplayer lobby creation flow.
- **Settings Screen redesign**: Clean split-view layout with categorized navigation (General, Java & memory, Downloads, Appearance, AI, About Ember).

### Performance
- **Faster game launch**: Cached native libraries extraction via `.extracted` marker in `GameLauncher`, avoiding repeated `/usr/bin/unzip` process invocations and recursive permission updates on every start (saving 0.5–1.5 seconds per launch).
- **Asset verification fast path**: Existing assets with a different size are now re-downloaded without computing a SHA-1 first; a file of the right size is still verified by SHA-1, so disk I/O is only saved for files that are plainly broken.
- **Zero-allocation hex encoding**: Replaced intermediate String array allocations in `sha1Hex`, `sha256Hex`, and `sha512Hex` with a fast in-place byte lookup table.
- **Network concurrency**: Increased `URLSession` maximum connections per host from 8 to 16 to utilize all parallel download worker tasks.
- **Reduced background GPU/CPU usage**: Lowered particle & dust animation rate in `AmbientBackdrop` from 30 FPS to 15 FPS without visible difference.

### Fixed
- **Preset skin loading on standalone Macs**: Fixed skin resource bundle path lookup (`Skins` subdirectory instead of `Resources/Skins`), removing broken hardcoded developer paths and ensuring default skins load reliably on all machines.
- **Dual sun visual glitch**: Eliminated duplicate sky gradient and second sun overlay in `HomeHeroCard`, delegating landscape rendering cleanly to `HeroScene`.
- **Download cancellation**: Handled `CancellationError` immediately in `Downloader` without retrying 3 times with backoff sleep.
- **Download size validation**: Validated received file size when SHA-1 is omitted, preventing corrupted partial downloads.
- **Swift 6 & SwiftUI warnings**: Fixed mutable state on `Sendable` `GameLauncher`, thread-safe progress reporting in `launcher-cli`, and deprecated `onChange` / open panel handlers.

### Changed
- The GitHub repository is now `SnowyMay111/ember-launcher` (was `mc-launcher`). Old links and the updater of earlier versions keep working through GitHub's redirect; the updater now points to the new address.

## [0.2.1] - 2026-10-28

The launcher is now called **Ember**.

### Changed
- The app is `Ember.app` and the download is `Ember-mac-arm64.zip`. The bundle identifier, the data folder (`~/Library/Application Support/mc-launcher`) and the Keychain entry are unchanged, so instances, worlds, settings and your AI key carry over.
- The self-updater understands both names. Copies of 0.1.0 and 0.2.0 look for `Voxel-mac-arm64.zip`, so each release also ships that file (the same build inside `Voxel.app`); from 0.2.1 on the updater prefers `Ember-mac-arm64.zip`.
- Messages, Settings text and the Russian and Ukrainian translations say Ember.
- `scripts/build-app.sh` builds `build/Ember.app`; `scripts/package-app.sh` writes `dist/Ember-mac-arm64.zip` and the legacy `dist/Voxel-mac-arm64.zip`.

### Docs
- New README in English, Russian and Ukrainian: banner, "What's new", architecture diagram, FAQ.
- This changelog, `CONTRIBUTING.md`, issue and pull request templates.

## [0.2.0] - 2026-10-28

A new look and a lot more under the hood.

### Added
- The warm dark **Ember** interface: hero Play screen, animated backdrop (can be turned off), new fonts, an app icon drawn as white line art.
- **Forge and NeoForge** install together with Minecraft; the mod and shader catalog works on any instance.
- `.mrpack` import and export for Forge and NeoForge packs; *New instance* maps the pack's loader.
- **Skins** screen: import 64×64 PNG skins, preview front and back, keep a collection.
- Instance details panel (overview, mods, worlds, logs), instance groups, and a mod page with one-button install.
- Delete instances and downloaded Minecraft versions; a version that an instance still uses is protected.
- Our own dropdown lists instead of system menus; Settings on one scrolling page with a side navigation.

### Changed
- Mod versions are picked to fit installed mods and the game version; incompatible results hide behind a *Show incompatible* switch; modpacks filter by Minecraft version and loader.
- Freshly installed resource packs and shaders are enabled automatically, without overriding your own choice.
- The *All versions* dialog has one folded note about old versions instead of a warning on every row.

### Fixed
- `.mrpack` archives built on Windows (zero unix permissions) now extract and import correctly.

## [0.1.0] - 2026-10-26

First public build.

### Added
- Any Minecraft version in one click, from the newest release down to old beta and alpha builds, with native ARM Java from Mojang's runtime manifest.
- Fabric, offline nickname launch, instance management (new, settings, duplicate, delete), live game log and crash analyzer.
- Catalog of mods, modpacks, shaders and resource packs (Modrinth) with a compatibility check and one-button install.
- AI modpack generator with your own Claude or Gemini key, stored in the macOS Keychain.
- JVM profiles (G1 / ZGC), memory recommendations, the Optimize profile with Sodium and Lithium, world backups and one-button rollback.
- `.mrpack` import and export.
- Self-update from GitHub Releases.
- English, Russian and Ukrainian interface.

[0.2.2]: https://github.com/SnowyMay111/ember-launcher/releases/tag/v0.2.2
[0.2.1]: https://github.com/SnowyMay111/ember-launcher/releases/tag/v0.2.1
[0.2.0]: https://github.com/SnowyMay111/ember-launcher/releases/tag/v0.2.0
[0.1.0]: https://github.com/SnowyMay111/ember-launcher/releases/tag/v0.1.0
