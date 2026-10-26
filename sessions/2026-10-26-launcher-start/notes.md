# Старт лаунчера

**Задача:** лаунчер Minecraft для macOS (офлайн-ник, оптимизация под Mac, ИИ-генератор модпаков, проверка совместимости).
**Статус:** идёт (возобновлено 2026-10-26)
**Решения владельца (2026-10-26):** SwiftUI (позже Windows), ИИ со своим ключом Claude/Gemini, Fabric 1.21.x + 1.20.1, сначала для себя, потом публично.
**Среда:** Mac arm64, Swift 6.4, только Command Line Tools (Xcode нет), Java в системе нет (берём Java из манифеста Mojang).

## Где остановились
Ядро этапа 1 готово и проверено вживую: `launcher-cli install 1.21.1`, `install-fabric 1.21.1`, `launch 1.21.1 [--fabric] [--name] [--instance] [--dry-run]`. Игра (ваниль и Fabric 0.20.1) доходит до главного меню, ошибок в логе нет. Лог: `instances/<имя>/launcher.log`. Файлы: `Sources/LauncherCore/GameLauncher.swift`, `Sources/launcher-cli/main.swift`.
Починен баг `VersionInstaller.groupArtifact` (классификатор входил в ключ не всегда: у Fabric пропадали natives LWJGL).
Не поддерживаем: версии до 1.13 (старый формат `minecraftArguments`), Forge/NeoForge. 1.20.1 ещё не проверяли вживую.
Общая папка с UI-сессией (`sessions/2026-10-26-ui-voxel/notes.md`): НЕ трогать `Sources/LauncherApp`, `Package.swift`, `.gitignore`, `scripts/`, `Sources/LauncherCore/Localizer.swift`. Проверка сборки только `--product launcher-cli`. Коммиты: только свои файлы.

## Что дальше
1. Проверить 1.20.1 (Java 17) вживую: `install 1.20.1`, `launch 1.20.1`.
2. Скрипт сборки `.app` (согласовать с UI-сессией), подключить `GameLauncher` к интерфейсу.
3. Этап 2: Modrinth (поиск, скачивание модов) и проверка совместимости.
