<div align="center">

<img src="docs/banner.svg" alt="Ember: a native Minecraft launcher for Apple Silicon" width="100%">

<br>

**Pick a version, press Play. Or describe the modpack you want and let the AI build it.**

English · [Русский](README.ru.md) · [Українська](README.uk.md)

[![Latest release](https://img.shields.io/github/v/release/SnowyMay111/mc-launcher?style=for-the-badge&label=download&color=ee8a56)](https://github.com/SnowyMay111/mc-launcher/releases/latest)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?style=for-the-badge&logo=apple)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-native-blue?style=for-the-badge)
![Swift 6](https://img.shields.io/badge/Swift-6%20%C2%B7%20SwiftUI-F05138?style=for-the-badge&logo=swift&logoColor=white)
[![MIT](https://img.shields.io/badge/license-MIT-lightgrey?style=for-the-badge)](LICENSE)

[Download](https://github.com/SnowyMay111/mc-launcher/releases/latest) · [What's new](#whats-new) · [Features](#features) · [Screenshots](#screenshots) · [How it works](#how-it-works) · [Install](#install) · [FAQ](#faq) · [Roadmap](#roadmap)

<img src="docs/screenshots/play.png" alt="Ember: Play screen with the hero card, version picker and Play button" width="860">

</div>

<table>
  <tr>
    <td width="33%" valign="top"><b>Made for the Mac</b><br>Native ARM Java straight from Mojang's runtime manifest, JVM profiles, memory presets that fit your Mac, a one-click Sodium and Lithium performance profile. No system Java needed.</td>
    <td width="33%" valign="top"><b>Mods without the guesswork</b><br>A Modrinth catalog where every card says whether it fits your game version and loader, and installs with its dependencies. Or let the AI plan a whole pack from a sentence.</td>
    <td width="33%" valign="top"><b>Changes you can undo</b><br>World backups before every version change, one-button rollback, a crash analyzer that names the guilty mod, and a live game log.</td>
  </tr>
</table>

<a id="whats-new"></a>
## What's new

**0.2.1: Voxel is now Ember.** The launcher has a new name. The app is `Ember.app`, the download is `Ember-mac-arm64.zip`, and your instances, worlds, settings and Keychain key stay exactly where they were. If you already have 0.1.0 or 0.2.0, the built-in updater brings you to Ember by itself; the first update keeps the old `Voxel.app` file name, and you can rename it in Finder if you like.

**0.2.0: a new look and a lot more under the hood.**

- The warm dark **Ember** interface with a hero Play screen and an animated backdrop that can be turned off.
- **Forge and NeoForge** install together with Minecraft, the catalog works on any instance, and `.mrpack` import and export covers both.
- A **Skins** screen, an instance details panel, instance groups, and a mod page with one-button install.
- Safe deletion of instances and downloaded game versions, smarter mod version picking, and Settings on one scrolling page.

The full history is in the [changelog](CHANGELOG.md).

<a id="features"></a>
## Features

- **Any Minecraft version in one click.** Releases, snapshots and even old beta/alpha builds, straight from Mojang's servers. Pick a version, press **Install**, play.
- **Vanilla, Fabric, Forge and NeoForge.** The loader installs together with the game, and every instance gets the mod and shader catalog.
- **Catalog of mods, modpacks, shaders and resource packs** from [Modrinth](https://modrinth.com). Every entry shows whether it fits your game version and loader, and installs with its dependencies in one button. Mod versions are picked to fit what you already have; results that do not fit hide behind a *Show incompatible* switch. Shaders pull in Iris and Sodium by themselves.
- **AI modpack generator.** Describe the pack in plain words ("light, fast, Create-style tech, no horror"); the AI picks the mods, tells you why, you untick what you do not want, and it installs after a compatibility check. Bring your own Claude or Gemini key, stored in the macOS Keychain.
- **Built for Mac.** Native ARM Java, JVM profiles (G1 / ZGC), memory presets that fit your Mac, a one-click performance profile with Sodium and Lithium.
- **Safe changes.** World backups before every version change, one-button rollback, a check that tells you if your mods can follow to the new version.
- **Know why the game crashed.** Live game log, crash analyzer that names the guilty mod or setting, a session health report.
- **Share packs.** Import and export `.mrpack` files, including Forge and NeoForge packs.
- **A tidy library.** Group your instances, open a details panel (overview, mods, worlds, logs), and delete instances or downloaded game versions safely: a version that an instance still uses is protected.
- **Skins.** Import 64×64 PNG skins, preview them from the front and the back, keep a collection on your Mac. The game applies the chosen skin after Microsoft sign-in, which is not available yet.
- **Looks good, stays quiet.** The warm dark Ember interface with an animated backdrop (one switch turns the animations off to save battery), English / Russian / Ukrainian.
- **Updates itself.** The launcher checks GitHub Releases on start; when a new version is out a button appears, one click downloads and installs it.
- Offline nickname by default.

<a id="screenshots"></a>
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

<a id="how-it-works"></a>
## How it works

<img src="docs/architecture.svg" alt="Ember.app and launcher-cli use the LauncherCore package, which talks to Mojang, Modrinth, an AI provider and GitHub Releases" width="100%">

All game logic lives in `LauncherCore`, a Swift package that uses only Foundation (no AppKit, no SwiftUI). The app is just one interface on top of it, and `launcher-cli` is another, so the core can be reused for a Windows version later. Game files and Java come from Mojang, mods from Modrinth, and your AI key goes only to the provider you chose.

<a id="install"></a>
## Install

You need a Mac with an Apple chip (M1 or newer) and macOS 14 or newer. You do **not** need to install Minecraft or Java: Ember downloads what the game needs.

1. Download **`Ember-mac-arm64.zip`** from the [latest release](https://github.com/SnowyMay111/mc-launcher/releases/latest) and unzip it.
2. Drag **`Ember.app`** into your **Applications** folder.
3. First launch only: the app is not notarized by Apple yet, so macOS will refuse to open it. Open **Terminal**, paste this and press Enter:

   ```bash
   xattr -dr com.apple.quarantine /Applications/Ember.app
   ```

   (Or: *System Settings → Privacy & Security → Open Anyway*.) After this it opens like any app.
4. Press **New instance**, choose a Minecraft version, press **Create**, then **Play**. Set your nickname in **Settings**.

Old versions (before 1.18) run through Rosetta. If Ember asks for it, run once:

```bash
softwareupdate --install-rosetta --agree-to-license
```

From then on Ember updates itself.

<a id="faq"></a>
## FAQ

<details>
<summary><b>Is Ember free?</b></summary>

Yes. It is open source under the [MIT License](LICENSE). Minecraft itself is not included, and the launcher never bundles Mojang's files.
</details>

<details>
<summary><b>Do I need to own Minecraft?</b></summary>

The offline nickname mode is meant for single-player, LAN and offline servers. To play on official servers, please buy the game. Microsoft sign-in is on the roadmap.
</details>

<details>
<summary><b>macOS says the app cannot be opened. Is it safe?</b></summary>

The build is signed locally but not yet notarized by Apple (that needs a paid developer account), so Gatekeeper blocks the first launch. The `xattr` command in [Install](#install) removes the quarantine flag; the source is in this repository if you want to check or build it yourself.
</details>

<details>
<summary><b>Does it run on an Intel Mac?</b></summary>

No, the build is Apple Silicon only (M1 or newer).
</details>

<details>
<summary><b>Where does Ember keep its files?</b></summary>

In `~/Library/Application Support/mc-launcher`: instances, worlds, backups, downloaded versions and Java. The folder name stayed the same through the rename so nothing has to be moved. Your AI key is in the macOS Keychain, not in a file.
</details>

<details>
<summary><b>Is my AI key safe?</b></summary>

It is stored in the macOS Keychain, kept out of logs, and sent only to the provider you picked (Claude or Gemini). You pay your provider directly; Ember has no servers of its own.
</details>

<details>
<summary><b>I already have a modpack. Can I use it?</b></summary>

Yes. Import any Modrinth `.mrpack` file in **New instance**, Forge and NeoForge packs included. You can export your own instances the same way.
</details>

<details>
<summary><b>Why was it called Voxel before?</b></summary>

Releases up to 0.2.0 were published as Voxel. From 0.2.1 the project is Ember. The built-in updater takes care of the switch, and the old download names still work for installed copies.
</details>

<details>
<summary><b>Will there be Windows or Linux versions?</b></summary>

Windows is on the roadmap. The core is portable; the SwiftUI interface is not, so Windows needs its own interface on top of `LauncherCore`.
</details>

<a id="build-from-source"></a>
## Build from source

Xcode is not required, only the Command Line Tools and Swift 6.

```bash
git clone https://github.com/SnowyMay111/mc-launcher.git
cd mc-launcher
scripts/build-app.sh          # builds build/Ember.app
scripts/package-app.sh        # release build + dist/Ember-mac-arm64.zip
```

See [CONTRIBUTING.md](CONTRIBUTING.md) if you want to send a change.

<a id="roadmap"></a>
## Roadmap

- [x] Vanilla and Fabric, mod catalog, AI generator
- [x] Forge and NeoForge
- [x] `.mrpack` import and export
- [x] Self-update from GitHub Releases
- [x] The Ember interface and name
- [ ] Microsoft sign-in
- [ ] CurseForge as a second catalog
- [ ] Apple notarization
- [ ] Windows

Found a bug or have an idea? [Open an issue](https://github.com/SnowyMay111/mc-launcher/issues/new/choose).

## Disclaimer

Ember is an unofficial launcher. It is not approved by or associated with Mojang or Microsoft. Minecraft game files are never bundled: they are downloaded from Mojang's official servers. Offline nickname mode is meant for single-player, LAN and offline servers; please buy the game to play on official servers.

## Credits and license

Mods and packs come from the [Modrinth](https://modrinth.com) API. Interface fonts: [Geist](https://vercel.com/font), [Manrope](https://fonts.google.com/specimen/Manrope) and [DM Mono](https://fonts.google.com/specimen/DM+Mono) (all SIL Open Font License). Ember is released under the [MIT License](LICENSE).
