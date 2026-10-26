import LauncherCore

extension DiagnosticIssue {
    var localizedDescription: String {
        switch code {
        case "gc_critical":
            if let maxPause = values["maxPauseMs"] {
                return L("The Java garbage collector paused the game for up to %@ ms while cleaning memory.", maxPause)
            }
            return message
        case "gc_minor":
            if let count = values["count"], let maxPause = values["maxPauseMs"] {
                return L("Minor GC micro-stutters detected (%@ times, up to %@ ms).", count, maxPause)
            }
            return message
        case "out_of_memory":
            return L("The game ran completely out of memory (OutOfMemoryError).")
        case "allocation_stall":
            if let count = values["count"] {
                return L("Memory allocation stalled waiting for memory to be freed (%@ stalls).", count)
            }
            return message
        case "memory_pressure":
            return L("High memory pressure observed; heap utilization regularly exceeded 85%.")
        case "tick_drops":
            if let count = values["tickDropCount"], let behind = values["maxTickBehindMs"] {
                return L("Server tick drops detected (%@ times, up to %@ ms behind).", count, behind)
            }
            return message
        case "rosetta_java":
            return L("Minecraft is running under Rosetta translation instead of native Apple Silicon ARM64.")
        case "voxy_render_distance":
            return L("Voxy is enabled with high render distance which causes heavy stuttering.")
        default:
            return message
        }
    }
}

extension AutoFixAction {
    func localizedTitle(refreshRate: Int?) -> String {
        switch self {
        case .installMemoryMods:
            return L("Install FerriteCore + ModernFix")
        case .installEntityAndChunkMods:
            return L("Install Lithium + Entity Culling + Async")
        case .enableZeroStutterZGC:
            return L("Enable ZGC")
        case .adjustRAMAllocation(let mb):
            let gb = max(1, mb / 1024)
            return L("Set memory to %d GB", gb)
        case .fixRenderDistanceAndLockFPS:
            if let refreshRate, refreshRate > 0 {
                return L("Lock FPS to %d Hz", refreshRate)
            } else {
                return L("Lock FPS to the screen refresh rate")
            }
        }
    }
}
