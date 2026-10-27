# Contributing to Ember

Thanks for wanting to help. Bug reports, ideas, translations and pull requests are all welcome.

## Report a bug or suggest something

Use [Issues](https://github.com/SnowyMay111/mc-launcher/issues/new/choose); the forms ask for what is needed. For a bug please include the Ember version (shown at the bottom of the Home screen), your macOS version, the Minecraft version and loader, and the game log or crash report if there is one.

## Build and run

You need a Mac with Apple Silicon, macOS 14 or newer, and the Command Line Tools with Swift 6. Xcode is not required.

```bash
git clone https://github.com/SnowyMay111/mc-launcher.git
cd mc-launcher
swift build                   # quick compile check
scripts/build-app.sh          # builds build/Ember.app
open build/Ember.app
```

`scripts/package-app.sh` makes the release zips in `dist/`.

## How the code is split

- `Sources/LauncherCore` is the engine: install, launch, Java, mods, compatibility, `.mrpack`, AI planner, updater. It uses **Foundation only**: no AppKit, no SwiftUI. Please keep it that way, it is what makes a Windows version possible later.
- `Sources/LauncherApp` is the SwiftUI interface.
- `Sources/launcher-cli` is a thin terminal front end for the same core.

## Translations

English text is written directly in the code. Russian and Ukrainian translations live in `Sources/LauncherApp/Resources/Languages/ru.json` and `uk.json`, keyed by the English string. When you add or change a visible string, add the key to both files. A new language is a new JSON file with the same keys.

## Pull requests

1. Open an issue first for anything big, so we can agree on the direction.
2. Keep a pull request focused on one thing, and match the style of the code around it.
3. Make sure `swift build` passes and, for interface changes, attach a screenshot.
4. Never commit secrets (API keys, tokens) or Mojang's game files.

By contributing you agree that your work is released under the [MIT License](LICENSE).
