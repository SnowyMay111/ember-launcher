import SwiftUI
import AppKit

/// Curated entry in the skin catalog.
struct CatalogSkin: Identifiable {
    let id: String
    let name: String
    let category: String
    let isSlim: Bool
    let imageProvider: () -> CGImage
}

/// Standalone skin catalog screen where players can browse curated styles,
/// fetch skins by Minecraft username, inspect them in full interactive 3D, and add them with 1 click.
struct SkinCatalogScreen: View {
    @ObservedObject var store: SkinStore
    let onBack: () -> Void

    @Local private var selectedCatalogID: String = "ember"
    @Local private var playerSearchText: String = ""
    @Local private var isSearchingUser: Bool = false
    @Local private var searchError: String?
    @Local private var searchedSkinImage: CGImage?
    @Local private var searchedPlayerName: String?
    @Local private var isSlimModel: Bool = false
    @Local private var addedNotice: String?

    // Pre-loaded curated skins
    private var catalogSkins: [CatalogSkin] {
        [
            CatalogSkin(
                id: "ember",
                name: "Ember",
                category: "Signature",
                isSlim: false,
                imageProvider: { Self.makeSkin(tone: (0.74, 0.50, 0.38), shirt: (0.94, 0.45, 0.22), pants: (0.16, 0.15, 0.20), hair: (0.24, 0.14, 0.18)) }
            ),
            CatalogSkin(
                id: "wanderer",
                name: "Wanderer",
                category: "Adventurer",
                isSlim: false,
                imageProvider: { Self.makeSkin(tone: (0.72, 0.48, 0.35), shirt: (0.45, 0.32, 0.24), pants: (0.22, 0.22, 0.24), hair: (0.18, 0.12, 0.08)) }
            ),
            CatalogSkin(
                id: "nightfall",
                name: "Nightfall",
                category: "Cyberpunk",
                isSlim: true,
                imageProvider: { Self.makeSkin(tone: (0.78, 0.54, 0.42), shirt: (0.14, 0.14, 0.18), pants: (0.10, 0.10, 0.12), hair: (0.58, 0.22, 0.65)) }
            ),
            CatalogSkin(
                id: "steve",
                name: "Classic Steve",
                category: "Original",
                isSlim: false,
                imageProvider: { Self.makeSkin(tone: (0.72, 0.48, 0.35), shirt: (0.00, 0.55, 0.55), pants: (0.26, 0.20, 0.60), hair: (0.27, 0.17, 0.11)) }
            ),
            CatalogSkin(
                id: "alex",
                name: "Classic Alex",
                category: "Original",
                isSlim: true,
                imageProvider: { Self.makeSkin(tone: (0.85, 0.65, 0.50), shirt: (0.35, 0.48, 0.24), pants: (0.30, 0.22, 0.15), hair: (0.80, 0.42, 0.18)) }
            ),
            CatalogSkin(
                id: "knight",
                name: "Iron Knight",
                category: "Medieval",
                isSlim: false,
                imageProvider: { Self.makeSkin(tone: (0.70, 0.48, 0.35), shirt: (0.70, 0.72, 0.75), pants: (0.45, 0.48, 0.52), hair: (0.20, 0.20, 0.22)) }
            ),
            CatalogSkin(
                id: "mage",
                name: "Arcane Mage",
                category: "Fantasy",
                isSlim: true,
                imageProvider: { Self.makeSkin(tone: (0.80, 0.62, 0.48), shirt: (0.38, 0.18, 0.55), pants: (0.18, 0.12, 0.28), hair: (0.85, 0.85, 0.90)) }
            ),
            CatalogSkin(
                id: "astronaut",
                name: "Cosmonaut",
                category: "Sci-Fi",
                isSlim: false,
                imageProvider: { Self.makeSkin(tone: (0.75, 0.55, 0.40), shirt: (0.90, 0.90, 0.92), pants: (0.85, 0.85, 0.88), hair: (0.15, 0.15, 0.18)) }
            )
        ]
    }

    private var activeImage: CGImage? {
        if let searched = searchedSkinImage {
            return searched
        }
        return catalogSkins.first(where: { $0.id == selectedCatalogID })?.imageProvider()
    }

    private var activeSkinName: String {
        if let name = searchedPlayerName {
            return name
        }
        return catalogSkins.first(where: { $0.id == selectedCatalogID })?.name ?? "Skin"
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                // Header with Back button
                HStack(alignment: .center) {
                    Button(action: onBack) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 13, weight: .semibold))
                            Text(tr: "Wardrobe")
                                .style(.init(size: 13, weight: .medium, color: Theme.text))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Theme.surface)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    if let notice = addedNotice {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(verbatim: notice)
                                .style(.init(size: 12, weight: .semibold, color: Theme.text))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: 1120)
                .frame(maxWidth: .infinity, alignment: .center)

                PageHeader(
                    eyebrow: "CATALOG",
                    title: "Skin Catalog",
                    subtitle: "Discover new Minecraft skins, preview Boba in 3D, and add directly to your wardrobe.",
                    alignment: .leading
                )
                .frame(maxWidth: 1120, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)

                // Nickname search input
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Theme.textMuted)
                        TextField(
                            "Get skin by player nickname (e.g. Notch, Steve, DanTDM)...",
                            text: $playerSearchText
                        )
                        .textFieldStyle(.plain)
                        .font(Theme.font(size: 13))
                        .onSubmit { fetchPlayerSkin() }

                        if !playerSearchText.isEmpty {
                            Button(action: {
                                playerSearchText = ""
                                searchedSkinImage = nil
                                searchedPlayerName = nil
                                searchError = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Theme.textMuted)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))

                    Button(action: fetchPlayerSkin) {
                        HStack(spacing: 6) {
                            if isSearchingUser {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.down.circle")
                            }
                            Text("Find player skin")
                                .font(Theme.font(size: 13, weight: .semibold))
                        }
                        .foregroundColor(Theme.ink)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Theme.ember)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(playerSearchText.trimmingCharacters(in: .whitespaces).isEmpty || isSearchingUser)
                }
                .frame(maxWidth: 1120)
                .frame(maxWidth: .infinity, alignment: .center)

                if let err = searchError {
                    StatusBadge(err, kind: .danger, systemImage: "exclamationmark.triangle.fill")
                        .frame(maxWidth: 1120)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                // Main two-column content
                GeometryReader { geo in
                    let maxContentWidth: CGFloat = min(1120, geo.size.width)
                    let columns = maxContentWidth - 18
                    HStack(alignment: .top, spacing: 18) {
                        catalog3DStage(width: columns * 0.58, height: 500)
                        catalogListPane(width: columns * 0.42, height: 500)
                    }
                    .frame(width: maxContentWidth, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(height: 500)
            }
            .padding(.top, 24)
            .padding(.horizontal, Theme.Space.xl)
            .padding(.bottom, Theme.Space.xl)
        }
    }

    // MARK: - 3D Stage

    private func catalog3DStage(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: Theme.Space.m) {
            HStack {
                HStack(spacing: 8) {
                    FilterChip(title: "Classic (4px)", isActive: !isSlimModel) {
                        isSlimModel = false
                    }
                    FilterChip(title: "Slim (3px)", isActive: isSlimModel) {
                        isSlimModel = true
                    }
                }

                Spacer()

                Button(action: addActiveToWardrobe) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add to wardrobe")
                            .font(Theme.font(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color(hex: 0x2A7E43))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Skin3DView(image: activeImage, isSlim: isSlimModel, autoRotate: true)
                .frame(width: 240, height: 320)

            Spacer()

            VStack(spacing: 4) {
                Text(verbatim: activeSkinName)
                    .style(.init(size: 15, weight: .semibold, color: Theme.text))
                Text("Drag with mouse to rotate 360° · Double-click to reset")
                    .style(.init(size: 11, weight: .regular, mono: true, color: Theme.textMuted))
            }
        }
        .padding(Theme.Space.l)
        .frame(width: width, height: height)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Theme.border, lineWidth: 1)
                )
        }
    }

    // MARK: - Catalog List

    private func catalogListPane(width: CGFloat, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text("PRESET STYLES")
                .style(.init(size: 11, weight: .semibold, mono: true, color: Theme.textMuted))
                .padding(.horizontal, 16)
                .padding(.top, 16)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(catalogSkins) { item in
                        let isSelected = (selectedCatalogID == item.id && searchedSkinImage == nil)
                        CatalogSkinRow(
                            item: item,
                            isSelected: isSelected,
                            onSelect: {
                                searchedSkinImage = nil
                                searchedPlayerName = nil
                                selectedCatalogID = item.id
                                isSlimModel = item.isSlim
                            },
                            onImport: {
                                importCatalogSkin(item)
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .frame(width: width, height: height)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Theme.border, lineWidth: 1)
                )
        }
    }

    // MARK: - Actions

    private func addActiveToWardrobe() {
        guard let img = activeImage else { return }
        guard let pngData = nsImagePNG(from: img) else { return }
        let skin = store.importSkinData(pngData, name: activeSkinName, isSlim: isSlimModel)
        if skin != nil {
            showNotice("Added \(activeSkinName) to wardrobe!")
        }
    }

    private func importCatalogSkin(_ item: CatalogSkin) {
        let img = item.imageProvider()
        guard let pngData = nsImagePNG(from: img) else { return }
        let skin = store.importSkinData(pngData, name: item.name, isSlim: item.isSlim)
        if skin != nil {
            showNotice("Added \(item.name) to wardrobe!")
        }
    }

    private func showNotice(_ text: String) {
        addedNotice = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if addedNotice == text {
                addedNotice = nil
            }
        }
    }

    private func fetchPlayerSkin() {
        let nick = playerSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nick.isEmpty else { return }

        isSearchingUser = true
        searchError = nil

        guard let url = URL(string: "https://minotar.net/skin/\(nick)") else {
            searchError = "Invalid player name."
            isSearchingUser = false
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isSearchingUser = false
                if let error = error {
                    self.searchError = error.localizedDescription
                    return
                }
                guard let data = data, let rep = NSBitmapImageRep(data: data), let cg = rep.cgImage else {
                    self.searchError = "Could not fetch skin for \(nick)."
                    return
                }
                self.searchedSkinImage = cg
                self.searchedPlayerName = nick
            }
        }.resume()
    }

    private func nsImagePNG(from cgImage: CGImage) -> Data? {
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
    }

    // MARK: - Procedural Minecraft 64x64 Skin Generator

    private static func makeSkin(
        tone: (CGFloat, CGFloat, CGFloat),
        shirt: (CGFloat, CGFloat, CGFloat),
        pants: (CGFloat, CGFloat, CGFloat),
        hair: (CGFloat, CGFloat, CGFloat)
    ) -> CGImage {
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

        // Head Base Skin
        ctx.setFillColor(red: tone.0, green: tone.1, blue: tone.2, alpha: 1.0)
        ctx.fill(CGRect(x: 0, y: 0, width: 32, height: 16))

        // Head Hair
        ctx.setFillColor(red: hair.0, green: hair.1, blue: hair.2, alpha: 1.0)
        ctx.fill(CGRect(x: 0, y: 0, width: 32, height: 6))

        // Eyes
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        ctx.fill(CGRect(x: 9, y: 10, width: 2, height: 1))
        ctx.fill(CGRect(x: 13, y: 10, width: 2, height: 1))
        ctx.setFillColor(red: 0.15, green: 0.15, blue: 0.35, alpha: 1.0)
        ctx.fill(CGRect(x: 10, y: 10, width: 1, height: 1))
        ctx.fill(CGRect(x: 14, y: 10, width: 1, height: 1))

        // Torso Shirt
        ctx.setFillColor(red: shirt.0, green: shirt.1, blue: shirt.2, alpha: 1.0)
        ctx.fill(CGRect(x: 16, y: 16, width: 24, height: 16))

        // Arms
        ctx.setFillColor(red: shirt.0, green: shirt.1, blue: shirt.2, alpha: 1.0)
        ctx.fill(CGRect(x: 40, y: 16, width: 16, height: 6))
        ctx.setFillColor(red: tone.0, green: tone.1, blue: tone.2, alpha: 1.0)
        ctx.fill(CGRect(x: 40, y: 22, width: 16, height: 10))

        // Left arm
        ctx.setFillColor(red: shirt.0, green: shirt.1, blue: shirt.2, alpha: 1.0)
        ctx.fill(CGRect(x: 32, y: 48, width: 16, height: 6))
        ctx.setFillColor(red: tone.0, green: tone.1, blue: tone.2, alpha: 1.0)
        ctx.fill(CGRect(x: 32, y: 54, width: 16, height: 10))

        // Legs (Pants)
        ctx.setFillColor(red: pants.0, green: pants.1, blue: pants.2, alpha: 1.0)
        ctx.fill(CGRect(x: 0, y: 16, width: 16, height: 16))
        ctx.fill(CGRect(x: 16, y: 48, width: 16, height: 16))

        return ctx.makeImage()!
    }
}

// MARK: - Row Subview

private struct CatalogSkinRow: View {
    let item: CatalogSkin
    let isSelected: Bool
    let onSelect: () -> Void
    let onImport: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(decorative: item.imageProvider(), scale: 1.0)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 38, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .background(Theme.elevated)

                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: item.name)
                        .style(.init(size: 13, weight: .semibold, color: isSelected ? Theme.text : Theme.textSecondary))
                    Text(verbatim: "\(item.category) · \(item.isSlim ? "Slim" : "Classic")")
                        .style(.init(size: 11, weight: .regular, color: Theme.textMuted))
                }

                Spacer()

                Button(action: onImport) {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .padding(8)
                        .background(Theme.elevated)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Add directly to wardrobe")
            }
            .padding(10)
            .background(isSelected ? Theme.elevated : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Theme.lineStrong : Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
