# Старт лаунчера

**Задача:** лаунчер Minecraft для macOS (офлайн-ник, оптимизация под Mac, ИИ-генератор модпаков, проверка совместимости).
**Статус:** ждёт возобновления (рестарт 2026-10-26 ~19:20)
**Решения владельца (2026-10-26):** SwiftUI (позже Windows), ИИ со своим ключом Claude/Gemini, Fabric 1.21.x + 1.20.1, сначала для себя, потом публично.
**Среда:** Mac arm64, Swift 6.4, только Command Line Tools (Xcode нет), Java в системе нет (берём Java из манифеста Mojang).

## Где остановились
Ядро этапа 1 готово и проверено вживую: `launcher-cli install 1.21.1`, `install-fabric 1.21.1`, `launch 1.21.1 [--fabric] [--name] [--instance] [--dry-run]`. Игра (ваниль 1.21.1, ваниль 1.20.1 на Java 17, Fabric 0.20.1 на 1.21.1) доходит до главного меню; в логе только ожидаемая офлайн-ошибка авторизации (401). Лог: `instances/<имя>/launcher.log`. Файлы: `Sources/LauncherCore/GameLauncher.swift`, `Sources/launcher-cli/main.swift`.
Починен баг `VersionInstaller.groupArtifact` (классификатор входил в ключ не всегда: у Fabric пропадали natives LWJGL).
Не поддерживаем: версии до 1.13 (старый формат `minecraftArguments`), Forge/NeoForge. Fabric на 1.20.1 ещё не проверяли.
Первый коммит: `e6456ef` (только свои файлы, без push). Остальное в репозитории (LauncherApp, Package.swift, scripts, .gitignore, Localizer.swift) — UI-сессии.
Общая папка с UI-сессией (`sessions/2026-10-26-ui-voxel/notes.md`): НЕ трогать `Sources/LauncherApp`, `Package.swift`, `.gitignore`, `scripts/`, `Sources/LauncherCore/Localizer.swift`. Проверка сборки только `--product launcher-cli`. Коммиты: только свои файлы.

## Что дальше
1. Скрипт сборки `.app` (согласовать с UI-сессией), подключить `GameLauncher` к интерфейсу.
2. Этап 2: Modrinth (поиск, скачивание модов) и проверка совместимости.
