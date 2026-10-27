<div align="center">

<img src="assets/AppIcon-1024.png" alt="Иконка Voxel" width="112">

# Voxel

**Быстрый нативный лаунчер Minecraft для Mac на Apple Silicon, с ИИ-генератором сборок.**

[English](README.md) · Русский · [Українська](README.uk.md)

[![Latest release](https://img.shields.io/github/v/release/SnowyMay111/mc-launcher?style=for-the-badge&label=download&color=2ea043)](https://github.com/SnowyMay111/mc-launcher/releases/latest)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?style=for-the-badge&logo=apple)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-native-blue?style=for-the-badge)
![Swift 6](https://img.shields.io/badge/Swift-6%20%C2%B7%20SwiftUI-F05138?style=for-the-badge&logo=swift&logoColor=white)
[![MIT](https://img.shields.io/badge/license-MIT-lightgrey?style=for-the-badge)](LICENSE)

[Скачать](https://github.com/SnowyMay111/mc-launcher/releases/latest) · [Возможности](#features) · [Скриншоты](#screenshots) · [Установка](#install) · [Сборка из исходников](#build-from-source) · [Планы](#roadmap)

<img src="docs/screenshots/play.png" alt="Voxel: экран запуска с главной карточкой, выбором версии и кнопкой «Играть»" width="860">

</div>

<a id="features"></a>
## Возможности

- **Любая версия Minecraft в один клик.** Релизы, снапшоты и даже старые беты и альфы прямо с серверов Mojang. Выберите версию, нажмите **Установить**, играйте.
- **Vanilla, Fabric, Forge и NeoForge.** Загрузчик ставится вместе с игрой, а в любой сборке доступен каталог модов и шейдеров.
- **Каталог модов, сборок, шейдеров и ресурспаков** из [Modrinth](https://modrinth.com). Каждая карточка показывает, подходит ли она вашей версии игры и загрузчику, и ставится вместе с зависимостями одной кнопкой. Версии модов подбираются под то, что уже установлено; неподходящие результаты спрятаны за переключателем *Показать несовместимые*. Шейдеры сами подтягивают Iris и Sodium.
- **ИИ-генератор сборок.** Опишите сборку обычными словами («лёгкая, быстрая, техно в стиле Create, без хорроров»): ИИ подберёт моды и объяснит выбор, вы снимете галочки с лишнего, и после проверки совместимости всё установится. Используйте свой ключ Claude или Gemini, он хранится в связке ключей macOS (Keychain).
- **Сделан для Mac.** Нативная ARM-Java из манифеста рантаймов Mojang, профили JVM (G1 / ZGC), пресеты памяти под ваш Mac, профиль производительности одним кликом с Sodium и Lithium.
- **Безопасные изменения.** Бэкап миров перед каждой сменой версии, откат одной кнопкой, проверка, смогут ли ваши моды перейти на новую версию.
- **Понятно, почему игра вылетела.** Живой лог игры, анализатор вылетов, который называет виновный мод или настройку, отчёт о состоянии сессии.
- **Делитесь сборками.** Импорт и экспорт файлов `.mrpack`, в том числе сборок Forge и NeoForge.
- **Аккуратная библиотека.** Группы для сборок, панель с деталями (обзор, моды, миры, логи), безопасное удаление сборок и скачанных версий игры: версию, которую ещё использует сборка, удалить нельзя.
- **Скины.** Импорт скинов PNG 64×64, просмотр спереди и сзади, своя коллекция на вашем Mac. Выбранный скин игра применит после входа через Microsoft, которого пока нет.
- **Красиво и спокойно.** Тёплый тёмный интерфейс *Ember* с живым фоном (один переключатель отключает анимации и экономит батарею), английский, русский и украинский языки.
- **Обновляется сам.** Лаунчер проверяет GitHub Releases при запуске; когда выходит новая версия, появляется кнопка, один клик скачивает и устанавливает её.
- По умолчанию ник работает офлайн.

<a id="screenshots"></a>
## Скриншоты

<table>
  <tr>
    <td align="center"><img src="docs/screenshots/library.png" alt="Библиотека сборок с группами" width="430"><br><sub><b>Библиотека</b>: все миры в одном месте</sub></td>
    <td align="center"><img src="docs/screenshots/mods.png" alt="Каталог модов с отметками совместимости" width="430"><br><sub><b>Каталог</b>: совместимость на каждой карточке</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/mod-details.png" alt="Страница мода с установкой одной кнопкой" width="430"><br><sub><b>Страница мода</b>: одна кнопка, зависимости включены</sub></td>
    <td align="center"><img src="docs/screenshots/versions.png" alt="Все версии: установка одной кнопкой" width="430"><br><sub><b>Все версии</b>: релизы, снапшоты, беты, альфы</sub></td>
  </tr>
  <tr>
    <td align="center" colspan="2"><img src="docs/screenshots/settings.png" alt="Настройки на одной прокручиваемой странице с боковым меню" width="430"><br><sub><b>Настройки</b>: одна страница, боковое меню идёт за вами</sub></td>
  </tr>
</table>

<a id="install"></a>
## Установка

Нужен Mac с чипом Apple (M1 или новее) и macOS 14 или новее. Устанавливать Minecraft или Java **не нужно**: Voxel сам скачает всё, что нужно игре.

1. Скачайте **`Voxel-mac-arm64.zip`** из [последнего релиза](https://github.com/SnowyMay111/mc-launcher/releases/latest) и распакуйте.
2. Перетащите **`Voxel.app`** в папку **Программы**.
3. Только при первом запуске: приложение ещё не нотаризовано Apple, поэтому macOS откажется его открыть. Откройте **Терминал**, вставьте команду и нажмите Enter:

   ```bash
   xattr -dr com.apple.quarantine /Applications/Voxel.app
   ```

   (Или: *Системные настройки → Конфиденциальность и безопасность → Всё равно открыть*.) После этого приложение открывается как обычно.
4. Нажмите **Новая сборка**, выберите версию Minecraft, нажмите **Создать**, затем **Играть**. Ник задаётся в **Настройках**.

Старые версии (до 1.18) работают через Rosetta. Если Voxel попросит, выполните один раз:

```bash
softwareupdate --install-rosetta --agree-to-license
```

Дальше Voxel обновляется сам.

<a id="build-from-source"></a>
## Сборка из исходников

Xcode не нужен, достаточно Command Line Tools и Swift 6.

```bash
git clone https://github.com/SnowyMay111/mc-launcher.git
cd mc-launcher
scripts/build-app.sh          # builds build/Voxel.app
scripts/package-app.sh        # release build + dist/Voxel-mac-arm64.zip
```

Вся логика игры лежит в пакете `LauncherCore` (только Foundation, без AppKit и SwiftUI), чтобы позже её можно было использовать для версии под Windows. `launcher-cli` запускает то же ядро из терминала.

<a id="roadmap"></a>
## Планы

- [x] Vanilla и Fabric, каталог модов, ИИ-генератор
- [x] Forge и NeoForge
- [x] Импорт и экспорт `.mrpack`
- [x] Самообновление из GitHub Releases
- [ ] Вход через Microsoft
- [ ] CurseForge как второй каталог
- [ ] Нотаризация Apple
- [ ] Windows

Нашли ошибку или есть идея? [Создайте issue](https://github.com/SnowyMay111/mc-launcher/issues).

## Отказ от ответственности

Voxel — неофициальный лаунчер. Он не одобрен Mojang или Microsoft и не связан с ними. Файлы игры Minecraft в лаунчер не входят: они скачиваются с официальных серверов Mojang. Офлайн-режим с ником предназначен для одиночной игры, локальной сети и офлайн-серверов; чтобы играть на официальных серверах, купите игру.

## Благодарности и лицензия

Моды и сборки приходят из API [Modrinth](https://modrinth.com). Шрифты интерфейса: [Geist](https://vercel.com/font), [Manrope](https://fonts.google.com/specimen/Manrope) и [DM Mono](https://fonts.google.com/specimen/DM+Mono) (все под SIL Open Font License). Voxel распространяется по лицензии [MIT](LICENSE).
