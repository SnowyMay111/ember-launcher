#!/usr/bin/env bash
# Собирает build/Ember.app из SwiftPM (Xcode не нужен). Запуск из корня проекта:
#   scripts/build-app.sh [debug|release]
# Папка build/ целиком генерируется, внутри неё скрипт обновляет Ember.app на месте.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-debug}"
# Версия приложения берётся из LauncherInfo.swift (`version = "x.y.z"`), чтобы лаунчер и Info.plist не расходились.
VERSION="$(sed -n 's/.*version = "\([^"]*\)".*/\1/p' Sources/LauncherCore/LauncherInfo.swift | head -n 1)"
[ -n "$VERSION" ] || { echo "error: не нашёл version в Sources/LauncherCore/LauncherInfo.swift"; exit 1; }
swift build -c "$CONFIG" --product LauncherApp
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

APP="build/Ember.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/LauncherApp" "$APP/Contents/MacOS/LauncherApp"
# --delete: убранный языковой файл исчезает и из готового приложения.
rsync -a --delete "$BIN_DIR/mc-launcher_LauncherApp.bundle/" "$APP/Contents/Resources/mc-launcher_LauncherApp.bundle/"
[ -f "assets/AppIcon.icns" ] && cp "assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>LauncherApp</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIdentifier</key><string>dev.mclauncher.voxel</string>
    <key>CFBundleName</key><string>Ember</string>
    <key>CFBundleDisplayName</key><string>Ember</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Подпись: EMBER_SIGN_IDENTITY (SHA-1 отпечаток или имя), иначе сертификат "Ember Signing" из связки ключей,
# иначе ad-hoc ("-"), чтобы приложение запускалось на Apple Silicon. Нотаризация позже.
SIGN_IDENTITY="${EMBER_SIGN_IDENTITY:-}"
if [ -z "$SIGN_IDENTITY" ]; then
    SIGN_IDENTITY="$(security find-certificate -c "Ember Signing" -Z 2>/dev/null | sed -n 's/^SHA-1 hash: //p' | head -n 1)"
fi
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
if ! codesign --force --sign "$SIGN_IDENTITY" "$APP" >/dev/null 2>&1; then
    # Релиз без подписи не запустится на Apple Silicon, поэтому для него это ошибка; для debug хватает предупреждения.
    if [ "$CONFIG" = "release" ]; then
        echo "error: codesign failed (релизная сборка без подписи не запустится)"
        exit 1
    fi
    echo "warning: codesign failed (приложение может не запуститься)"
fi
echo "Готово: $PWD/$APP"
