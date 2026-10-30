#!/usr/bin/env bash
# Собирает релизную Ember.app и кладёт zip для друзей в dist/. Запуск из корня проекта:
#   scripts/package-app.sh
# Подпись локальная (ad-hoc), без нотаризации: на чужом Маке при первом запуске нужно «ПКМ → Открыть»
# или `xattr -dr com.apple.quarantine /Applications/Ember.app`. Для публичного релиза нужны Developer ID и нотаризация.
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/build-app.sh release
mkdir -p dist
rm -f dist/Ember-mac-arm64.zip
ditto -c -k --sequesterRsrc --keepParent build/Ember.app dist/Ember-mac-arm64.zip

echo "Готово: $PWD/dist/Ember-mac-arm64.zip ($(du -h dist/Ember-mac-arm64.zip | cut -f1))"
