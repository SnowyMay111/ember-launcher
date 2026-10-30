#!/usr/bin/env bash
# Собирает релизную Ember.app и кладёт zip для друзей в dist/. Запуск из корня проекта:
#   scripts/package-app.sh
# Подпись локальная (ad-hoc), без нотаризации: на чужом Маке при первом запуске нужно «ПКМ → Открыть»
# или `xattr -dr com.apple.quarantine /Applications/Ember.app`. Для публичного релиза нужны Developer ID и нотаризация.
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/build-app.sh release
mkdir -p dist
rm -f dist/Ember-mac-arm64.zip dist/Voxel-mac-arm64.zip
ditto -c -k --sequesterRsrc --keepParent build/Ember.app dist/Ember-mac-arm64.zip

# До 0.2.1 проект назывался Voxel: версии 0.1.0 и 0.2.0 ищут в релизе Voxel-mac-arm64.zip с Voxel.app внутри
# (тот же bundle id и исполняемый файл LauncherApp, версия в Info.plist должна совпасть с релизом).
# Кладём ту же сборку под старым именем, чтобы они смогли обновиться сами.
LEGACY="$(mktemp -d)"
cp -R build/Ember.app "$LEGACY/Voxel.app"
ditto -c -k --sequesterRsrc --keepParent "$LEGACY/Voxel.app" dist/Voxel-mac-arm64.zip
rm -rf "$LEGACY"

echo "Готово: $PWD/dist/Ember-mac-arm64.zip ($(du -h dist/Ember-mac-arm64.zip | cut -f1)) и старое имя Voxel-mac-arm64.zip"
