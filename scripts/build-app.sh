#!/usr/bin/env bash
# Собирает build/Voxel.app из SwiftPM (Xcode не нужен). Запуск из корня проекта:
#   scripts/build-app.sh [debug|release]
# Папка build/ целиком генерируется, внутри неё скрипт обновляет Voxel.app на месте.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-debug}"
# Версия приложения берётся из LauncherInfo.swift (`version = "x.y.z"`), чтобы лаунчер и Info.plist не расходились.
VERSION="$(sed -n 's/.*version = "\([^"]*\)".*/\1/p' Sources/LauncherCore/LauncherInfo.swift | head -n 1)"
[ -n "$VERSION" ] || { echo "error: не нашёл version в Sources/LauncherCore/LauncherInfo.swift"; exit 1; }
swift build -c "$CONFIG" --product LauncherApp
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

APP="build/Voxel.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/LauncherApp" "$APP/Contents/MacOS/LauncherApp"
# --delete: убранный языковой файл исчезает и из готового приложения.
rsync -a --delete "$BIN_DIR/mc-launcher_LauncherApp.bundle/" "$APP/Contents/Resources/mc-launcher_LauncherApp.bundle/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>LauncherApp</string>
    <key>CFBundleIdentifier</key><string>dev.mclauncher.voxel</string>
    <key>CFBundleName</key><string>Voxel</string>
    <key>CFBundleDisplayName</key><string>Voxel</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Локальная подпись, чтобы приложение запускалось на Apple Silicon. Подпись для публики и нотаризация позже.
codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "warning: codesign failed (приложение может не запуститься)"
echo "Готово: $PWD/$APP"
