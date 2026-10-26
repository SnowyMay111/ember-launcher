#!/usr/bin/env bash
# Генерирует AppIcon.icns и AppIcon-1024.png через CoreGraphics, sips и iconutil.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

RAW_PNG="$TMP_DIR/icon_1024.png"
swift scripts/make-icon.swift "$RAW_PNG"

ICONSET="$TMP_DIR/AppIcon.iconset"
mkdir -p "$ICONSET"

sips -z 16 16     "$RAW_PNG" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32     "$RAW_PNG" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32     "$RAW_PNG" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64     "$RAW_PNG" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128   "$RAW_PNG" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256   "$RAW_PNG" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$RAW_PNG" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512   "$RAW_PNG" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$RAW_PNG" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$RAW_PNG" --out "$ICONSET/icon_512x512@2x.png" >/dev/null

mkdir -p assets
iconutil -c icns "$ICONSET" -o assets/AppIcon.icns
cp "$RAW_PNG" assets/AppIcon-1024.png
