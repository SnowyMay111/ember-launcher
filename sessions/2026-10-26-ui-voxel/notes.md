# Интерфейс «Voxel» по дизайн-спеке

**Задача:** собрать интерфейс лаунчера (Play, Library, Settings + заглушки Mods, Skins) строго по спеке владельца: чёрный фон, Geist, белые пилюли, своё «стекло», монохром.
**Статус:** экраны готовы и закоммичены, ждёт ревью владельца (2026-10-26)

## Где остановились
Все 5 экранов собраны и проверены в живом окне (клики, фильтры, поиск, настройки, ru): Play, Library, Settings, Mods/Skins-заглушки. Gemini не понадобился, всё написал Claude мелкими файлами. Закоммичено (второй коммит в репо, первый — ядро другой сессии).

## Что дальше
1. Владелец смотрит `scripts/build-app.sh && open build/Voxel.app` и даёт правки по виду.
2. Мелочи на его решение: кнопки Play / Instance settings / New instance / аккаунт пока без действия; Mods и Skins пустые.
3. Новый коммит только по просьбе.

## Принятые решения
Все решения интервью и мои, с причинами: `sessions/2026-10-26-ui-voxel/spec.md`, раздел «Решения интервью» (старая версия заметок: `notes-archive.md`). Коротко: SwiftUI, своё стекло по токенам, родные кнопки окна (старт 1120×720, min 900×600), заглушки данных, английский + JSON-языки, иконки рисуем сами.

## Что сделано
- Шрифты Geist (OFL) в `/Users/may/Projects/mc-launcher/Sources/LauncherApp/Resources/Fonts`; спека: `.../sessions/2026-10-26-ui-voxel/spec.md`.
- `Sources/LauncherCore/Localizer.swift` (ключ = английский текст); `Package.swift` с ресурсами Fonts и Languages (бэкап `backups/Package.swift.backup-2026-10-26`, `backups/LauncherApp.swift.backup-2026-10-26`).
- `Sources/LauncherApp/Design/`: Theme, Fonts, Localization, Glass, Glow, Icons, WindowConfigurator; `RootView.swift` пока заглушка.
- `scripts/build-app.sh` собирает `build/Voxel.app`: `scripts/build-app.sh && open build/Voxel.app`.
- Побочно: `/Users/may/Projects/tools/gemini-watch.py` и приложение `/Users/may/Projects/tools/gemini-watch-app/build/Gemini Watch.app` (прогресс-бар, оценка времени; история в `~/Library/Application Support/GeminiWatch/`).

## Мои решения в этой сессии (спека молчала)
- Клик по карточке в Library → сборка становится текущей и открывается Play.
- Описания строк Settings (13 muted) и надпись «No instances found.» придумал сам, короткие нейтральные. Плейсхолдер поиска «Search instances».
- ru/uk без плюралов: «Дней назад: N», «Модов: N» (Localizer не умеет склонять).
- Подложка-размытие (`PassthroughEffectView` в `Design/Glass.swift`) пропускает клики, иначе карточки не нажимались.
- Модель UI: `Sources/LauncherApp/Model/` (LibraryInstance, SampleData, AppState, SettingsStore), `Components/` (Buttons, Fields, Cards), `Screens/`. Не путать с `LauncherCore.Instance`. В UserDefaults уже лежит тестовое memoryGB=8.

## Для другой сессии (передача)
- Я отвечаю за `Sources/LauncherApp/` (интерфейс), `scripts/build-app.sh`, `Sources/LauncherCore/Localizer.swift`. Ядро (`LauncherCore/*`, `launcher-cli`) твоё, я его не трогал.
- Интерфейс пока на заглушках: `Sources/LauncherApp/Model/SampleData.swift`. Подключать ядро сюда: заменить `LibraryInstance` на `LauncherCore.Instance` (имя UI-модели специально другое) в `Model/AppState.swift`.
- Кнопки Play / Instance settings / New instance / аккаунт без действия: оживлять через `AppState`. Тексты только через `L("English")`, переводы в `Resources/Languages/*.json`.
- Сборка и запуск: `scripts/build-app.sh && open build/Voxel.app`. Обе сессии делят `.build`: SwiftPM ждёт друг друга, это нормально.
- Правила дизайна: `spec.md` рядом, строго по ней, без своих цветов и теней.

## Открытые вопросы
- Чужое задание Gemini из другого чата (ядро игры, launcher-cli) тоже висело; сборки делят одну `.build`.
- Скриншоты окна: computer-use `app_screenshot`, bundle id `dev.mclauncher.voxel` (доступ дан, окно может быть на другом мониторе).

Чищу контекст; потом напиши любое слово — я сразу продолжу.
