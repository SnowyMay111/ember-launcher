import LauncherCore

/// What the user reads about a crash cause. LauncherCore only names the cause; the words live here so they can be translated.
extension CrashKind {
    var title: String {
        switch self {
        case .outOfMemory: return L("The game ran out of memory")
        case .wrongJavaVersion: return L("Wrong Java version")
        case .missingDependency: return L("A mod is missing something it needs")
        case .modConflict: return L("Two mods do not work together")
        case .brokenMod: return L("A mod crashed the game")
        case .graphicsDriver: return L("Graphics problem")
        case .jvmCrash: return L("Java itself crashed")
        case .unknown: return L("The game crashed")
        }
    }

    var advice: String {
        switch self {
        case .outOfMemory: return L("Give the game more memory in Instance settings.")
        case .wrongJavaVersion: return L("Clear the Java field in Settings so the launcher picks the right Java itself.")
        case .missingDependency: return L("Install the missing mod, or remove the mod that needs it.")
        case .modConflict: return L("Remove one of the two mods.")
        case .brokenMod: return L("Update the mod named here, or remove it.")
        case .graphicsDriver: return L("Update macOS, then try a smaller window size in Settings.")
        case .jvmCrash: return L("Try again. If it repeats, lower the memory in Instance settings.")
        case .unknown: return L("The last lines of the log below usually show the cause.")
        }
    }
}
