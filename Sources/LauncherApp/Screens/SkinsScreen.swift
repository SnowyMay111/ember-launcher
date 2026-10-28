import SwiftUI

/// Perspective angle for the character preview canvas.
private enum SkinPreviewAngle: String, CaseIterable {
    case front = "Front"
    case back = "Back"
}

/// Canvas rendering a flat pixel-art character preview with base and overlay layers.
private struct SkinCharacterCanvas: View {
    let cgImage: CGImage
    let isSlim: Bool
    let isBack: Bool

    var body: some View {
        Canvas { context, size in
            let is64x32 = (cgImage.height == 32)
            let armW: Int = isSlim ? 3 : 4
            let scale: CGFloat = 10.0

            let charWidth: CGFloat = CGFloat(armW * 2 + 8) * scale
            let charHeight: CGFloat = 32.0 * scale
            let startX: CGFloat = (size.width - charWidth) / 2.0
            let startY: CGFloat = (size.height - charHeight) / 2.0

            let headX = startX + CGFloat(armW) * scale
            let headY = startY
            let headW: CGFloat = 8.0 * scale
            let headH: CGFloat = 8.0 * scale

            let bodyX = headX
            let bodyY = startY + 8.0 * scale
            let bodyW: CGFloat = 8.0 * scale
            let bodyH: CGFloat = 12.0 * scale

            let armWidthPts: CGFloat = CGFloat(armW) * scale
            let armHeightPts: CGFloat = 12.0 * scale
            let legWidthPts: CGFloat = 4.0 * scale
            let legHeightPts: CGFloat = 12.0 * scale

            func drawPart(cropRect: CGRect, destRect: CGRect, mirrored: Bool = false) {
                guard let cropped = cgImage.cropping(to: cropRect) else { return }
                if mirrored {
                    var sub = context
                    sub.translateBy(x: destRect.midX, y: destRect.midY)
                    sub.scaleBy(x: -1, y: 1)
                    sub.draw(
                        Image(decorative: cropped, scale: 1).interpolation(.none),
                        in: CGRect(x: -destRect.width / 2.0, y: -destRect.height / 2.0, width: destRect.width, height: destRect.height)
                    )
                } else {
                    context.draw(
                        Image(decorative: cropped, scale: 1).interpolation(.none),
                        in: destRect
                    )
                }
            }

            if !isBack {
                // Front view: base layer
                let rightArmRect = CGRect(x: startX, y: bodyY, width: armWidthPts, height: armHeightPts)
                drawPart(cropRect: CGRect(x: 44, y: 20, width: armW, height: 12), destRect: rightArmRect)

                let headRect = CGRect(x: headX, y: headY, width: headW, height: headH)
                drawPart(cropRect: CGRect(x: 8, y: 8, width: 8, height: 8), destRect: headRect)

                let bodyRect = CGRect(x: bodyX, y: bodyY, width: bodyW, height: bodyH)
                drawPart(cropRect: CGRect(x: 20, y: 20, width: 8, height: 12), destRect: bodyRect)

                let leftArmRect = CGRect(x: startX + CGFloat(armW + 8) * scale, y: bodyY, width: armWidthPts, height: armHeightPts)
                if is64x32 {
                    drawPart(cropRect: CGRect(x: 44, y: 20, width: armW, height: 12), destRect: leftArmRect, mirrored: true)
                } else {
                    drawPart(cropRect: CGRect(x: 36, y: 52, width: armW, height: 12), destRect: leftArmRect)
                }

                let rightLegRect = CGRect(x: headX, y: bodyY + bodyH, width: legWidthPts, height: legHeightPts)
                drawPart(cropRect: CGRect(x: 4, y: 20, width: 4, height: 12), destRect: rightLegRect)

                let leftLegRect = CGRect(x: headX + legWidthPts, y: bodyY + bodyH, width: legWidthPts, height: legHeightPts)
                if is64x32 {
                    drawPart(cropRect: CGRect(x: 4, y: 20, width: 4, height: 12), destRect: leftLegRect, mirrored: true)
                } else {
                    drawPart(cropRect: CGRect(x: 20, y: 52, width: 4, height: 12), destRect: leftLegRect)
                }

                // Front view: overlay layer
                drawPart(cropRect: CGRect(x: 40, y: 8, width: 8, height: 8), destRect: headRect)

                if !is64x32 {
                    drawPart(cropRect: CGRect(x: 20, y: 36, width: 8, height: 12), destRect: bodyRect)
                    drawPart(cropRect: CGRect(x: 44, y: 36, width: armW, height: 12), destRect: rightArmRect)
                    drawPart(cropRect: CGRect(x: 52, y: 52, width: armW, height: 12), destRect: leftArmRect)
                    drawPart(cropRect: CGRect(x: 4, y: 36, width: 4, height: 12), destRect: rightLegRect)
                    drawPart(cropRect: CGRect(x: 4, y: 52, width: 4, height: 12), destRect: leftLegRect)
                }
            } else {
                // Back view: base layer
                let leftArmRect = CGRect(x: startX, y: bodyY, width: armWidthPts, height: armHeightPts)
                if is64x32 {
                    drawPart(cropRect: CGRect(x: 52, y: 20, width: armW, height: 12), destRect: leftArmRect, mirrored: true)
                } else {
                    drawPart(cropRect: CGRect(x: 44, y: 52, width: armW, height: 12), destRect: leftArmRect)
                }

                let headRect = CGRect(x: headX, y: headY, width: headW, height: headH)
                drawPart(cropRect: CGRect(x: 24, y: 8, width: 8, height: 8), destRect: headRect)

                let bodyRect = CGRect(x: bodyX, y: bodyY, width: bodyW, height: bodyH)
                drawPart(cropRect: CGRect(x: 32, y: 20, width: 8, height: 12), destRect: bodyRect)

                let rightArmRect = CGRect(x: startX + CGFloat(armW + 8) * scale, y: bodyY, width: armWidthPts, height: armHeightPts)
                drawPart(cropRect: CGRect(x: 52, y: 20, width: armW, height: 12), destRect: rightArmRect)

                let leftLegRect = CGRect(x: headX, y: bodyY + bodyH, width: legWidthPts, height: legHeightPts)
                if is64x32 {
                    drawPart(cropRect: CGRect(x: 12, y: 20, width: 4, height: 12), destRect: leftLegRect, mirrored: true)
                } else {
                    drawPart(cropRect: CGRect(x: 28, y: 52, width: 4, height: 12), destRect: leftLegRect)
                }

                let rightLegRect = CGRect(x: headX + legWidthPts, y: bodyY + bodyH, width: legWidthPts, height: legHeightPts)
                drawPart(cropRect: CGRect(x: 12, y: 20, width: 4, height: 12), destRect: rightLegRect)

                // Back view: overlay layer
                drawPart(cropRect: CGRect(x: 56, y: 8, width: 8, height: 8), destRect: headRect)

                if !is64x32 {
                    drawPart(cropRect: CGRect(x: 32, y: 36, width: 8, height: 12), destRect: bodyRect)
                    drawPart(cropRect: CGRect(x: 52, y: 52, width: armW, height: 12), destRect: leftArmRect)
                    drawPart(cropRect: CGRect(x: 44, y: 36, width: armW, height: 12), destRect: rightArmRect)
                    drawPart(cropRect: CGRect(x: 4, y: 52, width: 4, height: 12), destRect: leftLegRect)
                    drawPart(cropRect: CGRect(x: 4, y: 36, width: 4, height: 12), destRect: rightLegRect)
                }
            }
        }
    }
}

/// 48pt head thumbnail showing the front face with hat overlay.
private struct SkinHeadThumbnail: View {
    let image: CGImage?

    var body: some View {
        Canvas { context, size in
            guard let image = image else { return }
            let rect = CGRect(origin: .zero, size: size)

            if let head = image.cropping(to: CGRect(x: 8, y: 8, width: 8, height: 8)) {
                context.draw(Image(decorative: head, scale: 1).interpolation(.none), in: rect)
            }
            if let hat = image.cropping(to: CGRect(x: 40, y: 8, width: 8, height: 8)) {
                context.draw(Image(decorative: hat, scale: 1).interpolation(.none), in: rect)
            }
        }
        .frame(width: 48, height: 48)
        .background(Theme.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// Skins management screen featuring local skin storage, full preview stage, and collection management.
struct SkinsScreen: View {
    @StateObject private var store = SkinStore()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Local private var selectedSkinID: UUID?
    @Local private var viewAngle: SkinPreviewAngle = .front
    @Local private var is3DMode: Bool = true
    @Local private var isCatalogOpen: Bool = false
    @Local private var isRenaming = false
    @Local private var renameText = ""
    @Local private var showDeleteConfirm = false

    private var activeSkin: SavedSkin? {
        if let id = selectedSkinID, let match = store.skins.first(where: { $0.id == id }) {
            return match
        }
        if let equipped = store.equippedID, let match = store.skins.first(where: { $0.id == equipped }) {
            return match
        }
        return store.skins.first
    }

    var body: some View {
        if isCatalogOpen {
            SkinCatalogScreen(store: store, onBack: { isCatalogOpen = false })
        } else {
            ScrollView(.vertical, showsIndicators: false) { content }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            // Header with Wardrobe title + Skin Catalog and Import actions
            HStack(alignment: .bottom) {
                PageHeader(
                    eyebrow: "WARDROBE",
                    title: "Skins",
                    subtitle: "Choose how you arrive in every world.",
                    alignment: .leading
                )
                Spacer()
                HStack(spacing: 10) {
                    Button(action: { isCatalogOpen = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles.rectangle.stack.fill")
                            Text(tr: "Skin Catalog")
                                .font(Theme.font(size: 13, weight: .semibold))
                        }
                        .foregroundColor(Theme.text)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.lineStrong, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button(action: { store.pickAndImport() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                            Text(tr: "Import skin")
                                .font(Theme.font(size: 13, weight: .semibold))
                        }
                        .foregroundColor(Theme.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Theme.ember)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: 1120, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)

            // Error notice banner
            if let errorMessage = store.message {
                HStack(spacing: Theme.Space.s) {
                    StatusBadge(errorMessage, kind: .danger, systemImage: "exclamationmark.triangle.fill")
                    Spacer()
                    IconButton(systemName: "xmark", label: "Dismiss", help: "Dismiss error message") {
                        store.message = nil
                    }
                }
            }

            GeometryReader { geo in
                let maxContentWidth: CGFloat = min(1120, geo.size.width)
                let columns = maxContentWidth - 18
                HStack(alignment: .top, spacing: 18) {
                    previewStage(width: columns * 0.625, height: 480)
                    collectionPane(width: columns * 0.375, height: 480)
                }
                .frame(width: maxContentWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(height: 480)
        }
        .padding(.top, 28)
        .padding(.horizontal, Theme.Space.xl)
        .padding(.vertical, Theme.Space.l)
        .frame(minHeight: 600)
    }

    // MARK: - Left: Preview Stage

    @ViewBuilder
    private func previewStage(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: Theme.Space.m) {
            HStack {
                HStack(spacing: Theme.Space.xs) {
                    FilterChip(title: "3D Boba", isActive: is3DMode) {
                        is3DMode = true
                    }
                    FilterChip(title: "2D Flat", isActive: !is3DMode) {
                        is3DMode = false
                    }
                }

                if !is3DMode {
                    HStack(spacing: Theme.Space.xs) {
                        FilterChip(title: "Front", isActive: viewAngle == .front) {
                            switchAngle(to: .front)
                        }
                        FilterChip(title: "Back", isActive: viewAngle == .back) {
                            switchAngle(to: .back)
                        }
                    }
                }

                Spacer()

                Button(action: { isCatalogOpen = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text(tr: "Catalog")
                            .font(Theme.font(size: 11, weight: .medium))
                    }
                    .foregroundColor(Theme.ember)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.elevated)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if let skin = activeSkin, let cgImage = store.image(for: skin.id) {
                if is3DMode {
                    Skin3DView(image: cgImage, isSlim: skin.slim, autoRotate: true)
                        .frame(width: 240, height: 310)
                } else {
                    SkinCharacterCanvas(cgImage: cgImage, isSlim: skin.slim, isBack: viewAngle == .back)
                        .frame(width: 170, height: 300)
                        .rotation3DEffect(
                            .degrees(viewAngle == .front ? 0 : 360),
                            axis: (x: 0, y: 1, z: 0)
                        )
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: viewAngle)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.artframe")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .foregroundColor(Theme.textSecondary)
                    Text("No skins yet")
                        .style(.init(size: 13, weight: .semibold, color: Theme.text))
                    Text("Import a 64×64 PNG skin or pick one from the catalog.")
                        .style(.init(size: 11, weight: .regular, color: Theme.textSecondary))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Spacer()

            if let skin = activeSkin {
                VStack(spacing: 4) {
                    Text(verbatim: "\(skin.name) · \(skin.slim ? "Slim" : "Classic")")
                        .style(.init(size: 12, weight: .medium, mono: true, color: Theme.textSecondary))
                    if is3DMode {
                        Text("Drag with mouse to rotate Boba 360° · Double-click to reset")
                            .style(.init(size: 10, weight: .regular, mono: true, color: Theme.textMuted))
                    }
                }
            }

            Text(tr: "Skins are stored on this Mac. In offline mode the game shows its default skin; your selection is applied after Microsoft sign-in.")
                .style(.init(size: 9, weight: .regular, mono: true, color: Color(hex: 0x4F4A50)))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Space.l)
        .frame(width: width, height: height)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.surface)

                RadialGradient(
                    gradient: Gradient(colors: [Theme.violet.opacity(0.18), Color.clear]),
                    center: .center,
                    startRadius: 20,
                    endRadius: 220
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Canvas { context, size in
                    var path = Path()
                    let step: CGFloat = 32
                    for x in stride(from: step, to: size.width, by: step) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    for y in stride(from: step, to: size.height, by: step) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(path, with: .color(Color.white.opacity(0.02)), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                // Floor shadow (stage-shadow) – matches prototype
                Ellipse()
                    .fill(Color.black.opacity(0.45))
                    .frame(width: 180, height: 28)
                    .blur(radius: 8)
                    .offset(y: 0.14 * 340) // 14% of stage height (~340)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color(hex: 0x262325), lineWidth: 1)
            }
        }
    }

    // MARK: - Right: Collection

    @ViewBuilder
    private func collectionPane(width: CGFloat, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                // NEWKEY: YOUR COLLECTION
                Text("YOUR COLLECTION")
                    .style(.eyebrow)
                Spacer()
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    if store.skins.isEmpty {
                        Text("Your imported skins will appear here.")
                            .style(.init(size: 11, weight: .regular, color: Theme.textSecondary))
                            .padding(.top, 18)
                    }
                    ForEach(store.skins) { skin in
                        let isSelected = (skin.id == activeSkin?.id)

                        Button {
                            selectedSkinID = skin.id
                            isRenaming = false
                        } label: {
                            HStack(spacing: 12) {
                                SkinHeadThumbnail(image: store.image(for: skin.id))
                                    .frame(width: 45, height: 45)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verbatim: skin.name)
                                        .style(.init(size: 11, weight: .bold, color: isSelected ? Color(hex: 0xEEE7EF) : Color(hex: 0xAAA3AB)))
                                        .lineLimit(1)
                                    Text(tr: skin.id == store.equippedID ? "Currently equipped" : "Saved skin")
                                        .style(.init(size: 8, weight: .regular, color: Color(hex: 0x625D63)))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(9)
                            .background(isSelected ? Color(hex: 0x201A21) : Color(hex: 0x161416))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(
                                        isSelected ? Color(hex: 0x564057) : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 18)
            }

            if let skin = activeSkin {
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    Divider()
                        .background(Theme.border)

                    HStack(spacing: Theme.Space.s) {
                        if store.equippedID == skin.id {
                            HStack(spacing: 7) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                Text(tr: "Equipped")
                                    .style(.init(size: 15, weight: .medium, color: Theme.ember))
                            }
                            .foregroundColor(Theme.ember)
                            .padding(.horizontal, 22)
                            .frame(height: 36)
                            .background(Capsule().fill(Theme.ember.opacity(0.12)))
                            .overlay(Capsule().strokeBorder(Theme.ember.opacity(0.35), lineWidth: 1))
                            .fixedSize()
                        } else {
                            PrimaryPill(title: "Equip", height: 36, horizontalPadding: 22) {
                                store.equip(id: skin.id)
                            }
                            .fixedSize()
                        }

                        Spacer(minLength: Theme.Space.s)

                        HStack(spacing: 8) {
                            VoxelToggle(
                                label: "Slim arms",
                                isOn: Binding(
                                    get: { skin.slim },
                                    set: { store.setSlim(id: skin.id, $0) }
                                )
                            )
                            Text(tr: "Slim arms")
                                .style(.init(size: 13, weight: .medium, color: Theme.textSecondary))
                        }
                    }

                    if isRenaming {
                        VStack(alignment: .leading, spacing: Theme.Space.xs) {
                            VoxelInput(label: "Skin name", text: $renameText, width: width - 44, placeholder: "Skin name")

                            HStack(spacing: Theme.Space.xs) {
                                PrimaryPill(title: "Save", height: 36, horizontalPadding: 22) {
                                    let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !trimmed.isEmpty {
                                        store.rename(id: skin.id, to: trimmed)
                                    }
                                    isRenaming = false
                                }
                                .fixedSize()

                                SecondaryPill(title: "Cancel", height: 36) {
                                    isRenaming = false
                                }
                                .fixedSize()
                            }
                        }
                    } else {
                        HStack(spacing: Theme.Space.s) {
                            SecondaryPill(title: "Rename", height: 36, fillsWidth: true) {
                                renameText = skin.name
                                isRenaming = true
                            }

                            SecondaryPill(title: "Remove", height: 36, fillsWidth: true) {
                                showDeleteConfirm = true
                            }
                            .confirmationDialog(
                                "Remove this skin from the collection?",
                                isPresented: $showDeleteConfirm,
                                titleVisibility: .visible
                            ) {
                                Button("Remove", role: .destructive) {
                                    store.remove(id: skin.id)
                                }
                                Button("Cancel", role: .cancel) {}
                            }
                        }
                    }
                }
            }
        }
        .padding(22)
        .frame(width: width, height: height)
        .background(Color(hex: 0x111011))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color(hex: 0x242124), lineWidth: 1)
        )
    }

    private func switchAngle(to target: SkinPreviewAngle) {
        guard viewAngle != target else { return }
        if reduceMotion {
            viewAngle = target
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                viewAngle = target
            }
        }
    }
}
