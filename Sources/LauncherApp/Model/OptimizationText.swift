import LauncherCore

extension BlockedMod {
    var localizedReason: String {
        switch code {
        case "vulkanmod_shaders_heavy":
            return L("VulkanMod is incompatible with shaders or heavy modpack configurations.")
        case "c2me_heavy_modpack":
            return L("C2ME breaks custom mod structures in heavy modpacks.")
        case "voxy_mac_opengl":
            return L("Apple froze OpenGL at 4.1; this mod requires OpenGL 4.4-4.6 and crashes on macOS.")
        default:
            return reason
        }
    }
}

extension OptimizationNotice {
    var localizedMessage: String {
        switch code {
        case "native_vulkan":
            return L("Mojang native Vulkan renderer active for Minecraft 26.3+.")
        case "vulkanmod_mac_moltenvk":
            return L("VulkanMod runs through MoltenVK on macOS and may be unstable; using Sodium instead.")
        case "voxy_mac_opengl":
            return L("Apple froze OpenGL at 4.1. Voxy and GGTU require OpenGL 4.4-4.6 (compute shaders / DSA) and crash on Mac; using Distant Horizons instead.")
        case "ggtu_input_lag":
            return L("GGTU frame generation may introduce noticeable input lag.")
        case "framegen_unavailable_mac":
            return L("Frame generation is not available on macOS.")
        default:
            return message
        }
    }
}
