# Changelog

All notable changes to Ember.
Versions follow [Semantic Versioning](https://semver.org); downloads are on the [Releases](https://github.com/SnowyMay111/ember-launcher/releases) page.

## [Unreleased]

### Fixed
- Ember account: you are no longer signed out at random. Friends and lobbies refreshed the session at the same moment and one of them lost it; now they share one refresh. Being offline no longer signs you out either, and signing out while a refresh is running stays signed out (the same for the Microsoft account).
- A damaged list file (mods, content, skins) is no longer treated as empty and overwritten: it is kept next to the original as `.corrupt`.
- Lobby guest: leaving the lobby while its content is installing no longer starts the game afterwards.
- Updater: if the new version cannot be put in place and the broken one cannot be moved away, the old app is opened from where it is instead of being moved inside the broken bundle.
- Worlds and instances: updating a mod no longer deletes another file with the same name, a failed world restore puts the world back, creating an instance never overwrites an existing one, and a failed duplicate leaves no half-copied instance behind.
- Instance snapshots (version change): a failed snapshot leaves no half-made copy, and a restore first copies the snapshot and only then moves the current saves and mods to the Trash, so a full disk can no longer leave the instance without worlds.
- Servers screen: errors when renaming a server, saving its settings or switching a mod are shown instead of being ignored; "Max health" accepts 1 to 1024 only; two world backups made within one second no longer fail.
- Lobbies: leaving a lobby no longer clears one you joined in the meantime, content that cannot be added says why, lobby settings go back to the saved values when the change fails, and a shader and a resource pack with the same file name no longer overwrite each other in the content list.
- Mods: a slow old search can no longer refill the list after you switched away, a failed automatic update check is retried next time, and a mod present as both `.jar` and `.jar.disabled` is listed once and removed completely.
- Shaders and resource packs: updating one moves the old version's file to the Trash instead of leaving both active; nothing is downloaded when the project cannot be looked up; choosing a shader pack turns shaders on even when Iris had them off; a pack name with quotes no longer breaks the game options.
- Downloads and installs: leftover temporary files are removed after a failed download, cancelling a Forge install stops its Java process, a failed natives extraction is no longer remembered as done, and two launches at once no longer wipe each other's Java 8 download.
- Session health: an out-of-memory error now lowers the smoothness score (it stayed at 100), and memory stalls count too. The health report and player heads no longer show data from the instance or player selected before.
- Game log: characters split between two reads are no longer lost. Lobby tunnel: a reset connection is reported as closed instead of timing out again and again.
- Account and Settings: a profile that finishes loading after you signed out is not shown; "Restart" no longer quits Ember when the relaunch cannot be started; the version check shows its error instead of "no results"; memory is shown as "1.5 GB" instead of "1 GB".
- Russian and Ukrainian: 16 strings that were shown in English are translated.

### Security
- Updater: an update must be signed with the same certificate as the running app, not merely carry an intact signature. Builds run from source (ad-hoc signed) are not affected.
- Cloud: dead lobbies are deleted, tunnel signals and wrong join codes are rate limited (ten wrong codes a minute), the tunnel key is replaced when a lobby is reopened, join codes come from a cryptographic source, profiles are readable by signed-in users only, and `id` / `created_at` of a profile can no longer be written.
- CurseForge proxy: no browser access (CORS removed), request bodies up to 64 KB, a per-address request limit, a timeout for CurseForge, and errors are no longer cached for five minutes.

## [0.4.4] - 2026-11-04

### Added
- Settings > Game window: "Custom window size" (off by default) and "Borderless window" (off by default, old Minecraft up to 1.16). A borderless window set to your screen size fills the screen without full screen mode.

### Fixed
- The window size from Settings now reaches the game; before, it was saved but never passed on.

## [0.4.3] - 2026-11-03

### Fixed
- Minecraft 1.12.2 and older on Apple Silicon: the game no longer closes with code 255 right after start (JNA 4 and the narrator library had no arm64 build; Ember now uses JNA 5.8.0 and MinecraftMachina's java-objc-bridge for these versions).

## [0.4.2] - 2026-11-03

### Fixed
- Minecraft 1.12.2 and older (LWJGL 2) now start on Apple Silicon Macs: Ember downloads Azul Zulu 8 for arm64 and an arm64 build of LWJGL 2 (MinecraftMachina, as in ManyMC and Prism) and uses them for these versions. Tested with Forge 1.12.2 (SevTech: Ages).

## [0.4.1] - 2026-11-03

### Fixed
- Modpacks: searching CurseForge packs works again. Packs such as "SevTech: Ages" are found, regular mods no longer show up in the modpack list, and "Any loader" no longer hides Forge packs.
- Modpacks: the preview opens for CurseForge packs (lists their mods), and packs whose file names are not UTF-8 (zipped on Chinese Windows) unpack instead of failing.
- Modpacks: installing a CurseForge pack uses the same CurseForge access as the catalog.
- The Modpacks heading says which catalog is searched (Modrinth, CurseForge or both).
- Old Forge versions (1.12.x): the version file no longer fails with "The data couldn't be read because it isn't in the correct format", and LWJGL 2 is kept on the classpath on a Mac. Note: Minecraft 1.12.2 itself still crashes on current macOS (LWJGL 2 limitation), this is not fixed yet.

## [0.4.0] - 2026-11-03

### Added
- Singleplayer world backups: when the game closes, Ember copies worlds that changed and keeps the newest 5 copies of each (Settings > Game > Worlds, on by default; copies live in the instance's `world-backups` folder). Instance settings > Worlds: back up now, see the copies, restore one (the current world is parked as `before-restore`, never deleted).
- Mods: "Update all" now shows progress (3 of 7), keeps going if one mod fails and tells you which ones failed and why; updates are looked for automatically when you open the Mods screen. Old files go to the Trash.
- Servers redesign: server chips on top, a header card with status, Start / Join / Stop, address and stats (players, world size, last backup), quick tiles (invite friends, back up now, settings), tabs Overview / Settings / World / Mods; Overview shows players, allowed players as chips and a feed of what happens; the full console is collapsed until you open it.
- Settings: new Game section (Java and memory, game window) in a better order; language picker (System / English / Русский / Українська); your own Java path and Java arguments for every instance; Storage card with the data folder and how much room games, versions and Java take.
- Settings redesign: sections with icons, a search field, cards with plain titles, an update banner with an Update button, and a new Server section (open Minecraft with my server, menu bar icon, back up new servers by default).
- Server settings in one place: rename, difficulty, game mode, PvP, max players, automatic world backup on stop (keeps the last 5), show in Finder and Move to Trash (the world and backups can be put back).
- Your own server no longer opens Minecraft by itself: Servers has a Join button while it runs. "Open Minecraft with my server" (Servers screen and Settings) joins automatically on start; off by default.

### Fixed
- Starting a saved server no longer resets its name or its backup setting.

## [0.3.0] - 2026-11-02

### Added
- CurseForge as a second catalog: Browse searches Modrinth and CurseForge in one list. Settings → Mod catalog picks both, Modrinth only or CurseForge only. Mods install with their dependencies; mods whose authors block downloads outside CurseForge show a link instead.
- Social: real invitations from friends' lobbies (Accept / Later), a dot on the Social icon and a banner when a new invitation arrives, recent players with "Add friend" (kept on this Mac), a Join button on friends who host a lobby and a friend card with Join, Invite to my lobby and Remove.
- Import CurseForge modpacks (.zip with manifest.json) through the same "Import modpack" button as .mrpack.
- Servers screen redesign: one Panel tab with players, an "Allowed players" list (invite-only, friends who join are remembered, auto-invite on start) and the console; an Address row with Copy; world backups with one-click restore (the old world is parked in `backups/before-restore-*`).
- Server in the menu bar: optional icon with status and a Stop button (Settings → Server in the menu bar); Ember asks before quitting while a server is running.
- "Open Social" shortcut in Allowed players when you have no friends to add yet.

### Fixed
- Lobby Rules: the "Sync shaders" and "Sync resource packs" checkboxes had no visible labels.
- Mods screen opened from a lobby: a compact "Back to the lobby" button with an arrow.

## [0.2.3] - 2026-10-30

### Added
- Friends: live friend list, requests, add by tag, online status in the top bar and the Social screen.
- Lobbies: create a room, share the code, friends join with one button. The host runs a local Fabric server and friends connect through an encrypted tunnel (no port forwarding).
- Shared content list for a lobby (mods, shaders, resource packs) with authors and edit rights; guests get the host's content installed automatically.
- Servers screen: saved lobby servers with console, players, world settings and mods.
- Pick the AI model from a per-provider list or type an id.
- Delete your Ember account from the profile.
- Shaders are allowed on NeoForge instances.
- Warning when an imported pack bundles `.jar` mods that do not come from Modrinth, and a note about secrets in exported configs.
- Unit tests (`scripts/test.sh`) and one User-Agent for all requests.

### Security
- Instance names are validated in `InstanceStore` (no `..`, separators, leading dot); a crafted `.mrpack` name can no longer point outside `instances/`.
- `.mrpack` archives with symbolic links are rejected before extraction; files without both `sha1` and `sha512` hashes are refused.
- File names from the Modrinth API must be a single plain path component.
- `EMBER_UPDATE_URL` (renamed from the old project's variable) is read only in debug builds.

### Fixed
- The updater no longer gets stuck when its temporary download was cleaned up.
- The natives `.extracted` marker is written only after a successful unpack and is tied to the native libraries; a forced reinstall clears it.
- Cancelling a `.mrpack` import removes the half-made instance instead of keeping a pack without mods.
- Long AI answers are no longer cut off silently (limits raised to 8192 tokens; a truncated answer is reported).
- Data race on the update download failure; a failed `codesign` now stops release builds.
- Iris detection no longer matches any file name containing "iris".
- The account pill says "Offline nickname" unless a Microsoft account is signed in.
- Imported mods keep their real Modrinth version numbers.
- A lobby server no longer reloads its whitelist (and spams the in-game chat) every few seconds; it reloads only when the player list changes.

### Changed
- The updater no longer carries the legacy archive name or app-folder fallback, and the internal UI components and debug variables are named Ember.

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
- Messages, Settings text and the Russian and Ukrainian translations say Ember.
- `scripts/build-app.sh` builds `build/Ember.app`; `scripts/package-app.sh` writes `dist/Ember-mac-arm64.zip`.

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
