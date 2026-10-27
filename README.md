<div align="center">

<img src="assets/AppIcon-1024.png" alt="Voxel icon" width="112">

# Voxel

**A fast, native Minecraft launcher for Apple Silicon Macs, with an AI modpack generator.**

English · [Русский](README.ru.md) · [Українська](README.uk.md)

[![Latest release](https://img.shields.io/github/v/release/SnowyMay111/mc-launcher?style=for-the-badge&label=download&color=2ea043)](https://github.com/SnowyMay111/mc-launcher/releases/latest)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?style=for-the-badge&logo=apple)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-native-blue?style=for-the-badge)
![Swift 6](https://img.shields.io/badge/Swift-6%20%C2%B7%20SwiftUI-F05138?style=for-the-badge&logo=swift&logoColor=white)
[![MIT](https://img.shields.io/badge/license-MIT-lightgrey?style=for-the-badge)](LICENSE)

[Download](https://github.com/SnowyMay111/mc-launcher/releases/latest) · [Features](#features) · [Screenshots](#screenshots) · [Install](#install) · [Build from source](#build-from-source) · [Roadmap](#roadmap)

<img src="docs/screenshots/play.png" alt="Voxel: Play screen with the hero card, version picker and Play button" width="860">

</div>

## Features

- **Any Minecraft version in one click.** Releases, snapshots and even old beta/alpha builds, straight from Mojang's servers. Pick a version, press **Install**, play.
- **Vanilla, Fabric, Forge and NeoForge.** The loader installs together with the game, and every instance gets the mod and shader catalog.
- **Catalog of mods, modpacks, shaders and resource packs** from [Modrinth](https://modrinth.com). Every entry shows whether it fits your game version and loader, and installs with its dependencies in one button. Mod versions are picked to fit what you already have; results that do not fit hide behind a *Show incompatible* switch. Shaders pull in Iris and Sodium by themselves.
- **AI modpack generator.** Describe the pack in plain words ("light, fast, Create-style tech, no horror"); the AI picks the mods, tells you why, you untick what you do not want, and it installs after a compatibility check. Bring your own Claude or Gemini key, stored in the macOS Keychain.
- **Built for Mac.** Native ARM Java from Mojang's own runtime manifest, JVM profiles (G1 / ZGC), memory presets that fit your Mac, a one-click performance profile with Sodium and Lithium.
- **Safe changes.** World backups before every version change, one-button rollback, a check that tells you if your mods can follow to the new version.
- **Know why the game crashed.** Live game log, crash analyzer that names the guilty mod or setting, a session health report.
- **Share packs.** Import and export `.mrpack` files, including Forge and NeoForge packs.
- **A tidy library.** Group your instances, open a details panel (overview, mods, worlds, logs), and delete instances or downloaded game versions safely: a version that an instance still uses is protected.
- **Skins.** Import 64×64 PNG skins, preview them from the front and the back, keep a collection on your Mac. The game applies the chosen skin after Microsoft sign-in, which is not available yet.
- **Looks good, stays quiet.** The warm dark *Ember* interface with an animated backdrop (one switch turns the animations off to save battery), English / Russian / Ukrainian.
- **Updates itself.** The launcher checks GitHub Releases on start; when a new version is out a button appears, one click downloads and installs it.
- Offline nickname by default.

## Screenshots

<table>
  <tr>
    <td align="center"><img src="docs/screenshots/library.png" alt="Instances library with groups" width="430"><br><sub><b>Library</b>: every world in one place</sub></td>
    <td align="center"><img src="docs/screenshots/mods.png" alt="Mod catalog with compatibility badges" width="430"><br><sub><b>Catalog</b>: compatibility on every card</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/mod-details.png" alt="Mod page with one-button install" width="430"><br><sub><b>Mod page</b>: one button, dependencies included</sub></td>
    <td align="center"><img src="docs/screenshots/versions.png" alt="All versions: one-button install" width="430"><br><sub><b>All versions</b>: releases, snapshots, beta, alpha</sub></td>
  </tr>
  <tr>
    <td align="center" colspan="2"><img src="docs/screenshots/settings.png" alt="Settings on one scrolling page with a side navigation" width="430"><br><sub><b>Settings</b>: one page, a side menu that follows you</sub></td>
  </tr>
</table>

## Install

You need a Mac with an Apple chip (M1 or newer) and macOS 14 or newer. You do **not** need to install Minecraft or Java: Voxel downloads what the game needs.

1. Download **`Voxel-mac-arm64.zip`** from the [latest release](https://github.com/SnowyMay111/mc-launcher/releases/latest) and unzip it.
2. Drag **`Voxel.app`** into your **Applications** folder.
3. First launch only: the app is not notarized by Apple yet, so macOS will refuse to open it. Open **Terminal**, paste this and press Enter:

   ```bash
   xattr -dr com.apple.quarantine /Applications/Voxel.app
   ```

   (Or: *System Settings → Privacy & Security → Open Anyway*.) After this it opens like any app.
4. Press **New instance**, choose a Minecraft version, press **Create**, then **Play**. Set your nickname in **Settings**.

Old versions (before 1.18) run through Rosetta. If Voxel asks for it, run once:

```bash
softwareupdate --install-rosetta --agree-to-license
```

From then on Voxel updates itself.

## Build from source

Xcode is not required, only the Command Line Tools and Swift 6.

```bash
git clone https://github.com/SnowyMay111/mc-launcher.git
cd mc-launcher
scripts/build-app.sh          # builds build/Voxel.app
scripts/package-app.sh        # release build + dist/Voxel-mac-arm64.zip
```

The game logic lives in the `LauncherCore` package (Foundation only, no AppKit or SwiftUI) so it can be reused for a Windows version later. `launcher-cli` runs the same core from the terminal.

## Roadmap

- [x] Vanilla and Fabric, mod catalog, AI generator
- [x] Forge and NeoForge
- [x] `.mrpack` import and export
- [x] Self-update from GitHub Releases
- [ ] Microsoft sign-in
- [ ] CurseForge as a second catalog
- [ ] Apple notarization
- [ ] Windows

Found a bug or have an idea? [Open an issue](https://github.com/SnowyMay111/mc-launcher/issues).

## Disclaimer

Voxel is an unofficial launcher. It is not approved by or associated with Mojang or Microsoft. Minecraft game files are never bundled: they are downloaded from Mojang's official servers. Offline nickname mode is meant for single-player, LAN and offline servers; please buy the game to play on official servers.

## Credits and license

Mods and packs come from the [Modrinth](https://modrinth.com) API. Interface fonts: [Geist](https://vercel.com/font), [Manrope](https://fonts.google.com/specimen/Manrope) and [DM Mono](https://fonts.google.com/specimen/DM+Mono) (all SIL Open Font License). Voxel is released under the [MIT License](LICENSE).
