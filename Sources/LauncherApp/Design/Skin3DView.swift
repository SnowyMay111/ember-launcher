import SwiftUI
import SceneKit
import AppKit

/// Interactive 3D Minecraft player character model (Boba) rendered with native SceneKit.
/// Features pixel-crisp nearest-neighbor textures, 360° mouse drag rotation, classic (4px) / slim (3px) arms,
/// full 2-layer skin support (base + hat/jacket/sleeves/pants), soft floor shadow, and authentic proportions.
public struct Skin3DView: NSViewRepresentable {
    public let image: CGImage?
    public let isSlim: Bool
    public var autoRotate: Bool = true

    public init(image: CGImage?, isSlim: Bool = false, autoRotate: Bool = true) {
        self.image = image
        self.isSlim = isSlim
        self.autoRotate = autoRotate
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeNSView(context: Context) -> SkinSCNView {
        let scnView = SkinSCNView()
        scnView.backgroundColor = .clear
        scnView.allowsCameraControl = false
        scnView.antialiasingMode = .none

        let scene = SCNScene()
        scnView.scene = scene

        // Camera setup: slightly elevated front view, zoomed in to fill stage beautifully
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.usesOrthographicProjection = false
        camera.fieldOfView = 36
        camera.zNear = 0.5
        camera.zFar = 50.0
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(x: 0, y: 0.1, z: 3.8)
        scene.rootNode.addChildNode(cameraNode)

        // Lighting: Soft ambient + directional key light for Minecraft blocky shading
        let ambientNode = SCNNode()
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = NSColor(white: 0.70, alpha: 1.0)
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)

        let dirNode = SCNNode()
        let dirLight = SCNLight()
        dirLight.type = .directional
        dirLight.color = NSColor(white: 0.55, alpha: 1.0)
        dirNode.light = dirLight
        dirNode.eulerAngles = SCNVector3(x: -0.45, y: 0.45, z: 0)
        scene.rootNode.addChildNode(dirNode)

        // Soft floor shadow under Boba's feet
        let shadowPlane = SCNPlane(width: 1.6, height: 1.0)
        shadowPlane.cornerRadius = 0.5
        let shadowMat = SCNMaterial()
        shadowMat.diffuse.contents = NSColor.black.withAlphaComponent(0.40)
        shadowMat.isDoubleSided = true
        shadowMat.blendMode = .alpha
        shadowPlane.materials = [shadowMat]
        let shadowNode = SCNNode(geometry: shadowPlane)
        shadowNode.eulerAngles = SCNVector3(x: -.pi / 2, y: 0, z: 0)
        shadowNode.position = SCNVector3(0, -1.34, 0)
        scene.rootNode.addChildNode(shadowNode)

        let charNode = buildCharacterNode(image: image, isSlim: isSlim)
        scene.rootNode.addChildNode(charNode)
        scnView.characterNode = charNode
        scnView.autoRotate = autoRotate

        scnView.startAnimationLoop()
        return scnView
    }

    public func updateNSView(_ scnView: SkinSCNView, context: Context) {
        let needsRebuild = context.coordinator.lastImage !== image || context.coordinator.lastSlim != isSlim
        if needsRebuild {
            context.coordinator.lastImage = image
            context.coordinator.lastSlim = isSlim

            scnView.characterNode?.removeFromParentNode()
            let newCharNode = buildCharacterNode(image: image, isSlim: isSlim)
            newCharNode.eulerAngles = SCNVector3(scnView.eulerX, scnView.eulerY, 0)
            scnView.scene?.rootNode.addChildNode(newCharNode)
            scnView.characterNode = newCharNode
        }
        scnView.autoRotate = autoRotate
    }

    public static func dismantleNSView(_ nsView: SkinSCNView, coordinator: Coordinator) {
        nsView.stopAnimationLoop()
    }

    public final class Coordinator {
        var lastImage: CGImage?
        var lastSlim: Bool = false
    }

    // MARK: - Character Geometry Builder

    private func buildCharacterNode(image: CGImage?, isSlim: Bool) -> SCNNode {
        let root = SCNNode()
        root.name = "characterRoot"
        let fallbackImage = image ?? Self.loadPresetResource(named: "ember") ?? Self.generateDefaultSkin()

        // 32-pixel tall character * 0.08 scale = ~2.56 units tall
        let scale: CGFloat = 0.08
        let armW: CGFloat = isSlim ? 3.0 : 4.0
        let is64x32 = (fallbackImage.height == 32)

        func makeBox(
            w: CGFloat, h: CGFloat, d: CGFloat,
            pos: SCNVector3,
            faces: [CGRect],
            isOverlay: Bool = false
        ) -> SCNNode {
            let box = SCNBox(width: w * scale, height: h * scale, length: d * scale, chamferRadius: 0)
            box.materials = faces.map { rect in
                makeMaterial(crop: rect, in: fallbackImage, isOverlay: isOverlay)
            }
            let node = SCNNode(geometry: box)
            node.position = SCNVector3(pos.x * scale, pos.y * scale, pos.z * scale)
            return node
        }

        // --- 1. HEAD (8x8x8) at y = 12 (base) + HAT overlay (8.7x8.7x8.7) ---
        // SCNBox faces order: [0: Front(+Z), 1: Right(+X), 2: Back(-Z), 3: Left(-X), 4: Top(+Y), 5: Bottom(-Y)]
        let headFaces = [
            CGRect(x: 8, y: 8, width: 8, height: 8),    // 0: Front
            CGRect(x: 16, y: 8, width: 8, height: 8),   // 1: Right (+X, left ear)
            CGRect(x: 24, y: 8, width: 8, height: 8),   // 2: Back
            CGRect(x: 0, y: 8, width: 8, height: 8),    // 3: Left (-X, right ear)
            CGRect(x: 8, y: 0, width: 8, height: 8),    // 4: Top
            CGRect(x: 16, y: 0, width: 8, height: 8)    // 5: Bottom
        ]
        let headNode = makeBox(w: 8, h: 8, d: 8, pos: SCNVector3(0, 12, 0), faces: headFaces)
        root.addChildNode(headNode)

        let hatFaces = [
            CGRect(x: 40, y: 8, width: 8, height: 8),
            CGRect(x: 48, y: 8, width: 8, height: 8),
            CGRect(x: 56, y: 8, width: 8, height: 8),
            CGRect(x: 32, y: 8, width: 8, height: 8),
            CGRect(x: 40, y: 0, width: 8, height: 8),
            CGRect(x: 48, y: 0, width: 8, height: 8)
        ]
        let hatNode = makeBox(w: 8.7, h: 8.7, d: 8.7, pos: SCNVector3(0, 12, 0), faces: hatFaces, isOverlay: true)
        root.addChildNode(hatNode)

        // --- 2. TORSO (8x12x4) at y = 2 + JACKET overlay (8.6x12.6x4.6) ---
        let torsoFaces = [
            CGRect(x: 20, y: 20, width: 8, height: 12), // Front
            CGRect(x: 28, y: 20, width: 4, height: 12), // Right (+X)
            CGRect(x: 32, y: 20, width: 8, height: 12), // Back
            CGRect(x: 16, y: 20, width: 4, height: 12), // Left (-X)
            CGRect(x: 20, y: 16, width: 8, height: 4),  // Top
            CGRect(x: 28, y: 16, width: 8, height: 4)   // Bottom
        ]
        let torsoNode = makeBox(w: 8, h: 12, d: 4, pos: SCNVector3(0, 2, 0), faces: torsoFaces)
        root.addChildNode(torsoNode)

        if !is64x32 {
            let jacketFaces = [
                CGRect(x: 20, y: 36, width: 8, height: 12),
                CGRect(x: 28, y: 36, width: 4, height: 12),
                CGRect(x: 32, y: 36, width: 8, height: 12),
                CGRect(x: 16, y: 36, width: 4, height: 12),
                CGRect(x: 20, y: 32, width: 8, height: 4),
                CGRect(x: 28, y: 32, width: 8, height: 4)
            ]
            let jacketNode = makeBox(w: 8.6, h: 12.6, d: 4.6, pos: SCNVector3(0, 2, 0), faces: jacketFaces, isOverlay: true)
            root.addChildNode(jacketNode)
        }

        // --- 3. RIGHT ARM (armW x 12 x 4) at x = -(4 + armW/2), y = 2 ---
        let rightArmX: CGFloat = -(4.0 + armW / 2.0)
        let rightArmFaces = [
            CGRect(x: 44, y: 20, width: armW, height: 12),         // Front
            CGRect(x: 44 + armW, y: 20, width: 4, height: 12),     // Right (+X, facing torso)
            CGRect(x: 44 + armW + 4, y: 20, width: armW, height: 12), // Back
            CGRect(x: 40, y: 20, width: 4, height: 12),             // Left (-X, outside)
            CGRect(x: 44, y: 16, width: armW, height: 4),          // Top
            CGRect(x: 44 + armW, y: 16, width: armW, height: 4)    // Bottom
        ]
        let rightArmNode = makeBox(w: armW, h: 12, d: 4, pos: SCNVector3(rightArmX, 2, 0), faces: rightArmFaces)
        root.addChildNode(rightArmNode)

        if !is64x32 {
            let rightSleeveFaces = [
                CGRect(x: 44, y: 36, width: armW, height: 12),
                CGRect(x: 44 + armW, y: 36, width: 4, height: 12),
                CGRect(x: 44 + armW + 4, y: 36, width: armW, height: 12),
                CGRect(x: 40, y: 36, width: 4, height: 12),
                CGRect(x: 44, y: 32, width: armW, height: 4),
                CGRect(x: 44 + armW, y: 32, width: armW, height: 4)
            ]
            let sleeveNode = makeBox(w: armW + 0.5, h: 12.5, d: 4.5, pos: SCNVector3(rightArmX, 2, 0), faces: rightSleeveFaces, isOverlay: true)
            root.addChildNode(sleeveNode)
        }

        // --- 4. LEFT ARM (armW x 12 x 4) at x = +(4 + armW/2), y = 2 ---
        let leftArmX: CGFloat = 4.0 + armW / 2.0
        let leftArmFaces: [CGRect]
        if is64x32 {
            leftArmFaces = rightArmFaces
        } else {
            leftArmFaces = [
                CGRect(x: 36, y: 52, width: armW, height: 12),         // Front
                CGRect(x: 32, y: 52, width: 4, height: 12),            // Right (+X, outside)
                CGRect(x: 36 + armW + 4, y: 52, width: armW, height: 12), // Back
                CGRect(x: 36 + armW, y: 52, width: 4, height: 12),     // Left (-X, facing torso)
                CGRect(x: 36, y: 48, width: armW, height: 4),          // Top
                CGRect(x: 36 + armW, y: 48, width: armW, height: 4)    // Bottom
            ]
        }
        let leftArmNode = makeBox(w: armW, h: 12, d: 4, pos: SCNVector3(leftArmX, 2, 0), faces: leftArmFaces)
        root.addChildNode(leftArmNode)

        if !is64x32 {
            let leftSleeveFaces = [
                CGRect(x: 52, y: 52, width: armW, height: 12),
                CGRect(x: 48, y: 52, width: 4, height: 12),
                CGRect(x: 52 + armW + 4, y: 52, width: armW, height: 12),
                CGRect(x: 52 + armW, y: 52, width: 4, height: 12),
                CGRect(x: 52, y: 48, width: armW, height: 4),
                CGRect(x: 52 + armW, y: 48, width: armW, height: 4)
            ]
            let leftSleeveNode = makeBox(w: armW + 0.5, h: 12.5, d: 4.5, pos: SCNVector3(leftArmX, 2, 0), faces: leftSleeveFaces, isOverlay: true)
            root.addChildNode(leftSleeveNode)
        }

        // --- 5. RIGHT LEG (4x12x4) at x = -2, y = -10 ---
        let rightLegFaces = [
            CGRect(x: 4, y: 20, width: 4, height: 12),  // Front
            CGRect(x: 8, y: 20, width: 4, height: 12),  // Right (+X, inside)
            CGRect(x: 12, y: 20, width: 4, height: 12), // Back
            CGRect(x: 0, y: 20, width: 4, height: 12),  // Left (-X, outside)
            CGRect(x: 4, y: 16, width: 4, height: 4),   // Top
            CGRect(x: 8, y: 16, width: 4, height: 4)    // Bottom
        ]
        let rightLegNode = makeBox(w: 4, h: 12, d: 4, pos: SCNVector3(-2, -10, 0), faces: rightLegFaces)
        root.addChildNode(rightLegNode)

        if !is64x32 {
            let rightPantsFaces = [
                CGRect(x: 4, y: 36, width: 4, height: 12),
                CGRect(x: 8, y: 36, width: 4, height: 12),
                CGRect(x: 12, y: 36, width: 4, height: 12),
                CGRect(x: 0, y: 36, width: 4, height: 12),
                CGRect(x: 4, y: 32, width: 4, height: 4),
                CGRect(x: 8, y: 32, width: 4, height: 4)
            ]
            let rightPantsNode = makeBox(w: 4.5, h: 12.5, d: 4.5, pos: SCNVector3(-2, -10, 0), faces: rightPantsFaces, isOverlay: true)
            root.addChildNode(rightPantsNode)
        }

        // --- 6. LEFT LEG (4x12x4) at x = +2, y = -10 ---
        let leftLegFaces: [CGRect]
        if is64x32 {
            leftLegFaces = rightLegFaces
        } else {
            leftLegFaces = [
                CGRect(x: 20, y: 52, width: 4, height: 12), // Front
                CGRect(x: 16, y: 52, width: 4, height: 12), // Right (+X, outside)
                CGRect(x: 28, y: 52, width: 4, height: 12), // Back
                CGRect(x: 24, y: 52, width: 4, height: 12), // Left (-X, inside)
                CGRect(x: 20, y: 48, width: 4, height: 4),  // Top
                CGRect(x: 24, y: 48, width: 4, height: 4)   // Bottom
            ]
        }
        let leftLegNode = makeBox(w: 4, h: 12, d: 4, pos: SCNVector3(2, -10, 0), faces: leftLegFaces)
        root.addChildNode(leftLegNode)

        if !is64x32 {
            let leftPantsFaces = [
                CGRect(x: 4, y: 52, width: 4, height: 12),
                CGRect(x: 0, y: 52, width: 4, height: 12),
                CGRect(x: 12, y: 52, width: 4, height: 12),
                CGRect(x: 8, y: 52, width: 4, height: 12),
                CGRect(x: 4, y: 48, width: 4, height: 4),
                CGRect(x: 8, y: 48, width: 4, height: 4)
            ]
            let leftPantsNode = makeBox(w: 4.5, h: 12.5, d: 4.5, pos: SCNVector3(2, -10, 0), faces: leftPantsFaces, isOverlay: true)
            root.addChildNode(leftPantsNode)
        }

        return root
    }

    private func makeMaterial(crop: CGRect, in image: CGImage, isOverlay: Bool) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.lightingModel = .lambert
        mat.isDoubleSided = false

        // Exact Minecraft nearest-neighbor pixel rendering
        mat.diffuse.magnificationFilter = .nearest
        mat.diffuse.minificationFilter = .nearest
        mat.diffuse.mipFilter = .none

        if let cropped = image.cropping(to: crop) {
            let nsImage = NSImage(cgImage: cropped, size: NSSize(width: crop.width, height: crop.height))
            mat.diffuse.contents = nsImage
            if isOverlay {
                mat.blendMode = .alpha
                mat.transparencyMode = .aOne
            }
        } else {
            mat.diffuse.contents = NSColor(white: 0.2, alpha: isOverlay ? 0.0 : 1.0)
        }
        return mat
    }

    /// Loads a preset PNG skin from the bundled resources or disk.
    public static func loadPresetResource(named name: String) -> CGImage? {
        if let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Resources/Skins") ??
                     Bundle.module.url(forResource: name, withExtension: "png") {
            if let data = try? Data(contentsOf: url),
               let rep = NSBitmapImageRep(data: data),
               let cg = rep.cgImage {
                return cg
            }
        }
        // Fallback: check project or app data paths
        let paths = [
            "/Users/may/Projects/mc-launcher/Sources/LauncherApp/Resources/Skins/\(name).png",
            "/tmp/\(name).png"
        ]
        for path in paths {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
               let rep = NSBitmapImageRep(data: data),
               let cg = rep.cgImage {
                return cg
            }
        }
        return nil
    }

    private static func generateDefaultSkin() -> CGImage {
        if let steve = loadPresetResource(named: "steve") {
            return steve
        }
        let width = 64
        let height = 64
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return NSImage(size: NSSize(width: 64, height: 64)).cgImage(forProposedRect: nil, context: nil, hints: nil)!
        }
        ctx.setFillColor(red: 0.72, green: 0.48, blue: 0.35, alpha: 1.0)
        ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        return ctx.makeImage()!
    }
}

// MARK: - Custom SCNView for Mouse Drag Rotation & Smooth Spin

public final class SkinSCNView: SCNView {
    public var characterNode: SCNNode?
    public var eulerY: CGFloat = -0.32
    public var eulerX: CGFloat = 0.04
    public var autoRotate: Bool = true

    private var lastMousePoint: CGPoint = .zero
    private var idleResumeTimer: Timer?
    private var displayTimer: Timer?

    override public func mouseDown(with event: NSEvent) {
        lastMousePoint = convert(event.locationInWindow, from: nil)
        autoRotate = false
        idleResumeTimer?.invalidate()
    }

    override public func mouseDragged(with event: NSEvent) {
        let current = convert(event.locationInWindow, from: nil)
        let dx = current.x - lastMousePoint.x
        let dy = current.y - lastMousePoint.y
        lastMousePoint = current

        eulerY += dx * 0.016
        eulerX = min(max(eulerX - dy * 0.010, -0.45), 0.45)

        characterNode?.eulerAngles = SCNVector3(eulerX, eulerY, 0)
    }

    override public func mouseUp(with event: NSEvent) {
        if event.clickCount == 2 {
            eulerY = -0.32
            eulerX = 0.04
            characterNode?.eulerAngles = SCNVector3(eulerX, eulerY, 0)
        }

        idleResumeTimer?.invalidate()
        idleResumeTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            self?.autoRotate = true
        }
    }

    public func startAnimationLoop() {
        displayTimer?.invalidate()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self = self, self.autoRotate, let node = self.characterNode else { return }
            self.eulerY += 0.0075
            node.eulerAngles = SCNVector3(self.eulerX, self.eulerY, 0)
        }
    }

    public func stopAnimationLoop() {
        displayTimer?.invalidate()
        idleResumeTimer?.invalidate()
    }

    deinit {
        stopAnimationLoop()
    }
}
