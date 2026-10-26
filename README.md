Voxel: как установить (Mac)
Нужно: Mac на чипе Apple (M1 и новее), macOS 14 или новее, интернет. Minecraft и Java ставить не надо, лаунчер скачает сам.

Скачай Voxel-mac-arm64.zip со страницы Releases на GitHub и дважды кликни, чтобы распаковать.
Перетащи Voxel.app в папку «Программы».
Первый запуск: macOS напишет, что не может проверить приложение (подписи Apple пока нет). Открой Терминал, вставь команду и нажми Enter:
xattr -dr com.apple.quarantine /Applications/Voxel.app
Потом открой Voxel как обычно. Вместо команды можно: «Системные настройки → Конфиденциальность и безопасность → Всё равно открыть». 4. Нажми «New instance», выбери версию Minecraft и «Create». Ник задаётся в Settings. Кнопка Play скачает игру и запустит её. 5. Версии до 1.18 и старые alpha/beta идут через Rosetta. Если лаунчер попросит, один раз выполни в Терминале:

softwareupdate --install-rosetta --agree-to-license
Моды, сборки, шейдеры и ресурспаки: вкладка Mods, в каждой строке кнопка Install. Логи игры: Instance settings → Logs.

Voxel: install (Mac)
Needs an Apple Silicon Mac, macOS 14+. Download Voxel-mac-arm64.zip from GitHub Releases, unzip, drag Voxel.app to Applications, then run once in Terminal: xattr -dr com.apple.quarantine /Applications/Voxel.app (the app is not Apple-notarized yet). Old versions (before 1.18) need Rosetta: softwareupdate --install-rosetta --agree-to-license.
