// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "mc-launcher",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LauncherCore", targets: ["LauncherCore"]),
        .executable(name: "launcher-cli", targets: ["launcher-cli"]),
        .executable(name: "LauncherApp", targets: ["LauncherApp"]),
    ],
    targets: [
        // Вся логика: только Foundation, без AppKit/SwiftUI (чтобы потом переиспользовать на Windows).
        .target(name: "LauncherCore", swiftSettings: [.swiftLanguageMode(.v6)]),
        // Консольный запуск ядра без интерфейса, для проверок.
        .executableTarget(name: "launcher-cli", dependencies: ["LauncherCore"]),
        // Интерфейс macOS.
        // Шрифты Geist и языковые файлы лежат папками, чтобы язык можно было убрать, не трогая код.
        .executableTarget(
            name: "LauncherApp",
            dependencies: ["LauncherCore"],
            resources: [
                .copy("Resources/Fonts"),
                .copy("Resources/Languages"),
                .copy("Resources/Skins")
            ]
        ),
        .testTarget(name: "LauncherCoreTests", dependencies: ["LauncherCore"]),
    ],
    swiftLanguageModes: [.v5]
)
