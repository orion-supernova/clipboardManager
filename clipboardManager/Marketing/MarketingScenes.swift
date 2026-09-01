//
//  MarketingScenes.swift
//  clipboardManager
//
//  DEBUG-only sample data and compositions for `MarketingRenderer`.
//

#if DEBUG
import AppKit
import ComposableArchitecture
import SwiftUI

@MainActor
struct MarketingScenes {
    // MARK: - Layout

    static let stillSize = CGSize(width: 1440, height: 900)
    static let gifWidth: CGFloat = 1200

    /// Thumbnail/image URLs resolve to fake paths that `staticImages` answers synchronously.
    static let storeClient: ClipboardStoreClient = {
        var client = ClipboardStoreClient.previewValue
        client.thumbnailURL = { URL(fileURLWithPath: "/marketing/thumbs/\($0)") }
        client.imageURL = { URL(fileURLWithPath: "/marketing/images/\($0)") }
        return client
    }()

    private let assets = MarketingAssets()
    /// Materialised once so ids stay stable across scenes.
    private let items: [ClipboardItem]
    private let folders: [ClipboardFolder]

    init() {
        folders = [
            ClipboardFolder(id: UUID(), name: "Snippets", symbol: "folder", createdAt: Date(), itemCount: 12),
            ClipboardFolder(id: UUID(), name: "Design", symbol: "folder", createdAt: Date(), itemCount: 7),
        ]
        items = Self.makeItems()
    }

    // MARK: - Sample content

    private static func makeItems() -> [ClipboardItem] {
        let scenes = SampleContent()
        return [
            scenes.item(.text, scenes.swiftSnippet, app: scenes.xcode, minutesAgo: 1, pinned: true),
            scenes.item(.url, "https://developer.apple.com/documentation/technologyoverviews/liquid-glass", app: scenes.safari, minutesAgo: 3,
                 thumbnailPath: "link-hero.png", linkTitle: "Adopting Liquid Glass", linkIconPath: "link-icon.png"),
            scenes.item(.text, "•••• •••• •••• 4242", app: scenes.safari, minutesAgo: 4, sensitivity: .creditCard, sensitivityDetail: "Visa"),
            scenes.item(.image, "Q3 roadmap · Liquid Glass rollout · ship by Oct 14", app: scenes.finder, minutesAgo: 6, byteCount: 842_000,
                 imagePath: "screenshot-full.png", thumbnailPath: "screenshot.png", pixelSize: PixelSize(width: 1600, height: 1000)),
            scenes.item(.color, "#5E5CE6", app: scenes.figma, minutesAgo: 9),
            scenes.item(.text, "Design is not just what it looks like and feels like. Design is how it works.", app: scenes.notes, minutesAgo: 14),
            scenes.item(.file, "Launch plan.pdf", app: scenes.finder, minutesAgo: 22, byteCount: 2_400_000, fileName: "Launch plan.pdf",
                 filePath: "/Users/you/Documents/Launch plan.pdf", thumbnailPath: "pdf.png"),
            scenes.item(.text, "brew install --cask mahmut\nmahmut --help", app: scenes.terminal, minutesAgo: 48),
        ]
    }


    private func baseState(items: [ClipboardItem]? = nil) -> HistoryFeature.State {
        var state = HistoryFeature.State()
        let list = items ?? self.items
        state.items = IdentifiedArray(uniqueElements: list)
        state.folders = IdentifiedArray(uniqueElements: folders)
        state.selectedID = list.first?.id
        state.isPresented = true
        state.hasLoaded = true
        state.isEntering = false
        state.selectionAnimated = false
        return state
    }

    // MARK: - Composition

    private func panel(_ state: HistoryFeature.State, width: CGFloat, height: CGFloat, ringOffset: CGFloat = 0, sheetProgress: CGFloat = 1) -> some View {
        let store = Store(initialState: state) {
            HistoryFeature()
        } withDependencies: {
            $0.clipboardStore = Self.storeClient
            $0.imageLoader = .previewValue
            $0.clipboardMonitor = .previewValue
            $0.paste = .previewValue
            $0.panel = .previewValue
            $0.workspace = .previewValue
            $0.linkMetadata = .previewValue
            $0.textRecognition = .previewValue
            $0.hotKeys = .previewValue
        }
        return HistoryView(store: store)
            .frame(width: width, height: height)
            .environment(\.marketingRender, true)
            .environment(\.staticImages, assets.images)
            .environment(\.marketingRingOffset, ringOffset)
            .environment(\.marketingSheetProgress, sheetProgress)
            .environment(\.colorScheme, .dark)
    }

    private struct Caption {
        var title: String
        var subtitle: String
        var compact = false
    }

    private func scene(size: CGSize, caption: Caption?, wallpaper: MarketingWallpaper.Style = .aurora, @ViewBuilder panel: () -> some View) -> AnyView {
        AnyView(
            ZStack(alignment: .bottom) {
                MarketingWallpaper(style: wallpaper)
                if let caption {
                    VStack(alignment: .leading, spacing: caption.compact ? 6 : 14) {
                        HStack(spacing: 12) {
                            Image(nsImage: NSApp.applicationIconImage)
                                .resizable()
                                .frame(width: caption.compact ? 32 : 44, height: caption.compact ? 32 : 44)
                            Text("Mahmut Clipboard")
                                .font(.system(size: caption.compact ? 18 : 22, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        Text(caption.title)
                            .font(.system(size: caption.compact ? 40 : 58, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(caption.subtitle)
                            .font(.system(size: caption.compact ? 19 : 24, weight: .medium))
                            .foregroundStyle(.white.opacity(0.78))
                    }
                    .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
                    .padding(.horizontal, 64)
                    .padding(.top, caption.compact ? 34 : 64)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                panel()
                    .padding(.bottom, PanelMetrics.bottomScreenInset)
            }
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .dark)
        )
    }

    private func panelWidth(for size: CGSize) -> CGFloat {
        min(size.width - 2 * PanelMetrics.horizontalScreenInset, PanelMetrics.maxWidth)
    }

    // MARK: - Stills

    func stills() -> [MarketingRenderer.Still] {
        let size = Self.stillSize
        let width = panelWidth(for: size)
        let all = items

        var previewCode = baseState()
        previewCode.previewID = all[0].id
        previewCode.previewPayload = ClipboardPayload(kind: .text, text: SampleContent().swiftSnippet)

        var previewCard = baseState()
        previewCard.selectedID = all[2].id
        previewCard.previewID = all[2].id
        previewCard.previewPayload = ClipboardPayload(kind: .text, text: "4242 4242 4242 4242")

        var chooser = baseState()
        chooser.selectedID = all[5].id
        chooser.dialog = .chooseFolder(all[5].id)

        var search = baseState(items: all.filter { $0.preview.localizedCaseInsensitiveContains("glass") || ($0.linkTitle ?? "").localizedCaseInsensitiveContains("glass") })
        search.searchText = "glass"
        search.isSearchFocused = true

        var pasteAs = baseState()
        pasteAs.dialog = .pasteAs(all[0].id)

        var folderScope = baseState(items: Array(all.prefix(4)).map { var copy = $0; copy.folderID = folders[0].id; return copy })
        folderScope.activeScope = .folder(folders[0].id)

        return [
            .init(name: "01-hero", size: size, scale: 2, view: scene(size: size, caption: .init(title: "Your clipboard, reimagined.", subtitle: "Everything you copy — text, code, links, images, files — one keystroke away.")) {
                panel(baseState(), width: width, height: PanelMetrics.height)
            }),
            .init(name: "02-quick-look", size: size, scale: 2, view: scene(size: size, caption: .init(title: "Space to Quick Look.", subtitle: "Full text with syntax colouring, large images, rich links, files — without leaving the panel.", compact: true), wallpaper: .dusk) {
                panel(previewCode, width: width, height: PanelMetrics.expandedHeight)
            }),
            .init(name: "03-sensitive", size: size, scale: 2, view: scene(size: size, caption: .init(title: "Secrets stay masked.", subtitle: "Cards, IBANs, API keys and passwords are detected, masked, and forgotten on a timer.", compact: true), wallpaper: .ember) {
                panel(previewCard, width: width, height: PanelMetrics.expandedHeight)
            }),
            .init(name: "04-folders", size: size, scale: 2, view: scene(size: size, caption: .init(title: "Save the keepers.", subtitle: "Folders keep snippets out of the timeline. ⌘S, pick a number, done."), wallpaper: .ocean) {
                panel(chooser, width: width, height: PanelMetrics.height)
            }),
            .init(name: "05-search", size: size, scale: 2, view: scene(size: size, caption: .init(title: "Just start typing.", subtitle: "Search text, code, link titles — even the words inside your screenshots."), wallpaper: .aurora) {
                panel(search, width: width, height: PanelMetrics.height)
            }),
            .init(name: "06-paste-as", size: size, scale: 2, view: scene(size: size, caption: .init(title: "Paste it your way.", subtitle: "Plain text, UPPERCASE, trimmed, single line, pretty-printed JSON — ⌘T."), wallpaper: .dusk) {
                panel(pasteAs, width: width, height: PanelMetrics.height)
            }),
            .init(name: "07-folder-scope", size: size, scale: 2, view: scene(size: size, caption: .init(title: "Folders, not clutter.", subtitle: "Switch scopes with ⌘[ and ⌘]. Folder items never expire."), wallpaper: .ocean) {
                panel(folderScope, width: width, height: PanelMetrics.height)
            }),
            .init(name: "readme-hero", size: CGSize(width: 1600, height: 720), scale: 2, view: scene(size: CGSize(width: 1600, height: 720), caption: nil) {
                panel(baseState(), width: panelWidth(for: CGSize(width: 1600, height: 720)), height: PanelMetrics.height)
            }),
        ]
    }

    // MARK: - Animations

    func animations() -> [MarketingRenderer.Animation] {
        let baseSize = CGSize(width: Self.gifWidth, height: PanelMetrics.height + 60)
        let tallSize = CGSize(width: Self.gifWidth, height: PanelMetrics.expandedHeight + 60)
        let width = panelWidth(for: baseSize)
        let all = items

        func easeOut(_ t: Double) -> Double { 1 - pow(1 - t, 3) }

        // Panel appearing.
        var appear: [MarketingRenderer.Frame] = []
        for index in 0..<16 {
            let t = easeOut(Double(index) / 15)
            appear.append(.init(view: scene(size: baseSize, caption: nil) {
                panel(baseState(), width: width, height: PanelMetrics.height)
                    .offset(y: (1 - t) * 70)
                    .opacity(t)
            }, delay: index == 15 ? 1.4 : 0.04))
        }

        // Keyboard navigation: the ring glides across three cards.
        var navigation: [MarketingRenderer.Frame] = []
        let step = PanelMetrics.cardWidth + PanelMetrics.cardSpacing
        for move in 0..<3 {
            var state = baseState()
            state.selectedID = all[move].id
            navigation.append(.init(view: scene(size: baseSize, caption: nil) { panel(state, width: width, height: PanelMetrics.height) }, delay: 0.55))
            for index in 1...8 {
                let t = easeOut(Double(index) / 8)
                navigation.append(.init(view: scene(size: baseSize, caption: nil) {
                    panel(state, width: width, height: PanelMetrics.height, ringOffset: t * step)
                }, delay: 0.035))
            }
        }
        var last = baseState()
        last.selectedID = all[3].id
        navigation.append(.init(view: scene(size: baseSize, caption: nil) { panel(last, width: width, height: PanelMetrics.height) }, delay: 1.2))

        // Search: typing "glass" filters live.
        var search: [MarketingRenderer.Frame] = []
        search.append(.init(view: scene(size: baseSize, caption: nil) { panel(baseState(), width: width, height: PanelMetrics.height) }, delay: 0.7))
        let query = "glass"
        for length in 0...query.count {
            let typed = String(query.prefix(length))
            var state = baseState(items: typed.isEmpty ? all : all.filter { $0.preview.localizedCaseInsensitiveContains(typed) || ($0.linkTitle ?? "").localizedCaseInsensitiveContains(typed) })
            state.searchText = typed
            state.isSearchFocused = true
            search.append(.init(view: scene(size: baseSize, caption: nil) { panel(state, width: width, height: PanelMetrics.height) }, delay: length == query.count ? 1.6 : 0.22))
        }

        // Quick Look opening and closing.
        var quickLook: [MarketingRenderer.Frame] = []
        quickLook.append(.init(view: scene(size: tallSize, caption: nil) { panel(baseState(), width: width, height: PanelMetrics.height) }, delay: 0.7))
        var previewState = baseState()
        previewState.previewID = all[0].id
        previewState.previewPayload = ClipboardPayload(kind: .text, text: SampleContent().swiftSnippet)
        for index in 1...10 {
            let t = easeOut(Double(index) / 10)
            quickLook.append(.init(view: scene(size: tallSize, caption: nil) {
                panel(previewState, width: width, height: PanelMetrics.expandedHeight, sheetProgress: t)
            }, delay: index == 10 ? 1.6 : 0.04))
        }
        for index in stride(from: 9, through: 0, by: -1) {
            let t = easeOut(Double(index) / 10)
            quickLook.append(.init(view: scene(size: tallSize, caption: nil) {
                panel(previewState, width: width, height: PanelMetrics.expandedHeight, sheetProgress: t)
            }, delay: 0.035))
        }
        quickLook.append(.init(view: scene(size: tallSize, caption: nil) { panel(baseState(), width: width, height: PanelMetrics.height) }, delay: 0.8))

        return [
            .init(name: "panel-appear", size: baseSize, frames: appear),
            .init(name: "keyboard-navigation", size: baseSize, frames: navigation),
            .init(name: "search", size: baseSize, frames: search),
            .init(name: "quick-look", size: tallSize, frames: quickLook),
        ]
    }
}


@MainActor
private struct SampleContent {
    let swiftSnippet = """
    struct GlassCard: View {
        @State private var isHovered = false

        var body: some View {
            content
                .padding(14)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
                .animation(.easeOut(duration: 0.18), value: isHovered)
        }
    }
    """

    func item(
        _ kind: ClipboardKind,
        _ preview: String,
        app: SourceApp,
        minutesAgo: Double,
        byteCount: Int64 = 0,
        pinned: Bool = false,
        fileName: String? = nil,
        filePath: String? = nil,
        imagePath: String? = nil,
        thumbnailPath: String? = nil,
        pixelSize: PixelSize? = nil,
        sensitivity: SensitiveKind? = nil,
        sensitivityDetail: String? = nil,
        linkTitle: String? = nil,
        linkIconPath: String? = nil
    ) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            kind: kind,
            timestamp: Date().addingTimeInterval(-minutesAgo * 60),
            isPinned: pinned,
            preview: preview,
            source: app,
            byteCount: byteCount > 0 ? byteCount : Int64(preview.utf8.count),
            fileName: fileName,
            filePath: filePath,
            imagePath: imagePath,
            thumbnailPath: thumbnailPath,
            pixelSize: pixelSize,
            contentHash: UUID().uuidString,
            isFileAvailable: true,
            folderID: nil,
            sensitivity: sensitivity,
            sensitivityDetail: sensitivityDetail,
            linkTitle: linkTitle,
            linkIconPath: linkIconPath,
            codeLanguage: kind == .text && sensitivity == nil ? CodeLanguage.detect(preview) : nil
        )
    }

    let safari = SourceApp(name: "Safari", bundleID: "com.apple.Safari")
    let xcode = SourceApp(name: "Xcode", bundleID: "com.apple.dt.Xcode")
    let finder = SourceApp(name: "Finder", bundleID: "com.apple.finder")
    let notes = SourceApp(name: "Notes", bundleID: "com.apple.Notes")
    let terminal = SourceApp(name: "Terminal", bundleID: "com.apple.Terminal")
    let figma = SourceApp(name: "Figma", bundleID: "com.figma.Desktop")

}

// MARK: - Wallpaper

struct MarketingWallpaper: View {
    enum Style { case aurora, dusk, ember, ocean }
    let style: Style

    private var colors: [Color] {
        switch style {
        case .aurora:
            [Color(red: 0.07, green: 0.06, blue: 0.20), Color(red: 0.16, green: 0.10, blue: 0.40), Color(red: 0.05, green: 0.20, blue: 0.35),
             Color(red: 0.30, green: 0.12, blue: 0.50), Color(red: 0.12, green: 0.12, blue: 0.32), Color(red: 0.06, green: 0.30, blue: 0.45),
             Color(red: 0.55, green: 0.20, blue: 0.55), Color(red: 0.20, green: 0.20, blue: 0.48), Color(red: 0.10, green: 0.42, blue: 0.55)]
        case .dusk:
            [Color(red: 0.12, green: 0.05, blue: 0.18), Color(red: 0.32, green: 0.10, blue: 0.30), Color(red: 0.55, green: 0.18, blue: 0.28),
             Color(red: 0.18, green: 0.08, blue: 0.28), Color(red: 0.42, green: 0.15, blue: 0.38), Color(red: 0.78, green: 0.35, blue: 0.30),
             Color(red: 0.10, green: 0.06, blue: 0.20), Color(red: 0.30, green: 0.12, blue: 0.32), Color(red: 0.62, green: 0.30, blue: 0.36)]
        case .ember:
            [Color(red: 0.10, green: 0.04, blue: 0.08), Color(red: 0.35, green: 0.08, blue: 0.10), Color(red: 0.60, green: 0.16, blue: 0.10),
             Color(red: 0.18, green: 0.05, blue: 0.10), Color(red: 0.45, green: 0.12, blue: 0.12), Color(red: 0.80, green: 0.32, blue: 0.14),
             Color(red: 0.12, green: 0.04, blue: 0.10), Color(red: 0.36, green: 0.10, blue: 0.14), Color(red: 0.70, green: 0.26, blue: 0.16)]
        case .ocean:
            [Color(red: 0.03, green: 0.10, blue: 0.20), Color(red: 0.04, green: 0.22, blue: 0.36), Color(red: 0.06, green: 0.36, blue: 0.46),
             Color(red: 0.04, green: 0.14, blue: 0.28), Color(red: 0.06, green: 0.30, blue: 0.44), Color(red: 0.12, green: 0.50, blue: 0.52),
             Color(red: 0.03, green: 0.08, blue: 0.20), Color(red: 0.05, green: 0.24, blue: 0.40), Color(red: 0.10, green: 0.44, blue: 0.50)]
        }
    }

    var body: some View {
        ZStack {
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.45, 0.55], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1],
                ],
                colors: colors
            )
            Circle()
                .fill(.white.opacity(0.10))
                .frame(width: 720, height: 720)
                .blur(radius: 90)
                .offset(x: -420, y: -260)
            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 520, height: 520)
                .blur(radius: 110)
                .offset(x: 480, y: 160)
        }
    }
}

// MARK: - Sample images

@MainActor
struct MarketingAssets {
    let images: [String: CGImage]

    init() {
        var images: [String: CGImage] = [:]
        images["/marketing/thumbs/screenshot.png"] = Self.render(size: CGSize(width: 480, height: 300)) { SampleScreenshot() }
        images["/marketing/images/screenshot-full.png"] = Self.render(size: CGSize(width: 960, height: 600)) { SampleScreenshot() }
        images["/marketing/thumbs/link-hero.png"] = Self.render(size: CGSize(width: 480, height: 240)) { SampleLinkHero() }
        images["/marketing/thumbs/link-icon.png"] = Self.render(size: CGSize(width: 64, height: 64)) { SampleFavicon() }
        images["/marketing/thumbs/pdf.png"] = Self.render(size: CGSize(width: 200, height: 260)) { SampleDocument() }
        for bundleID in ["com.apple.Safari", "com.apple.dt.Xcode", "com.apple.finder", "com.apple.Notes", "com.apple.Terminal", "com.figma.Desktop"] {
            let workspace = NSWorkspace.shared
            let icon: NSImage
            if let url = workspace.urlForApplication(withBundleIdentifier: bundleID) {
                icon = workspace.icon(forFile: url.path)
            } else {
                icon = workspace.icon(for: .application)
            }
            var rect = CGRect(x: 0, y: 0, width: 64, height: 64)
            if let cg = icon.cgImage(forProposedRect: &rect, context: nil, hints: nil) { images["app:" + bundleID] = cg }
        }
        self.images = images
    }

    private static func render(size: CGSize, scale: CGFloat = 2, @ViewBuilder _ content: () -> some View) -> CGImage? {
        let renderer = ImageRenderer(content: content().frame(width: size.width, height: size.height))
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = scale
        return renderer.cgImage
    }
}

private struct SampleScreenshot: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.98, green: 0.62, blue: 0.35), Color(red: 0.55, green: 0.25, blue: 0.55), Color(red: 0.12, green: 0.10, blue: 0.30)], startPoint: .top, endPoint: .bottom)
            Circle().fill(.white.opacity(0.9)).frame(width: 90, height: 90).offset(x: 110, y: -70).blur(radius: 1)
            GeometryReader { proxy in
                let w = proxy.size.width, h = proxy.size.height
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h))
                    path.addLine(to: CGPoint(x: 0, y: h * 0.62))
                    path.addLine(to: CGPoint(x: w * 0.22, y: h * 0.38))
                    path.addLine(to: CGPoint(x: w * 0.40, y: h * 0.58))
                    path.addLine(to: CGPoint(x: w * 0.58, y: h * 0.30))
                    path.addLine(to: CGPoint(x: w * 0.78, y: h * 0.55))
                    path.addLine(to: CGPoint(x: w, y: h * 0.42))
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.closeSubpath()
                }
                .fill(Color(red: 0.10, green: 0.08, blue: 0.22))
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h))
                    path.addLine(to: CGPoint(x: 0, y: h * 0.78))
                    path.addLine(to: CGPoint(x: w * 0.30, y: h * 0.60))
                    path.addLine(to: CGPoint(x: w * 0.55, y: h * 0.80))
                    path.addLine(to: CGPoint(x: w * 0.80, y: h * 0.66))
                    path.addLine(to: CGPoint(x: w, y: h * 0.76))
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.closeSubpath()
                }
                .fill(Color(red: 0.05, green: 0.04, blue: 0.14))
            }
        }
    }
}

private struct SampleLinkHero: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.16, green: 0.20, blue: 0.55), Color(red: 0.40, green: 0.22, blue: 0.62), Color(red: 0.90, green: 0.45, blue: 0.40)], startPoint: .topLeading, endPoint: .bottomTrailing)
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 28)
                    .fill(.white.opacity(0.18 + Double(index) * 0.08))
                    .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(.white.opacity(0.4), lineWidth: 1.5))
                    .frame(width: 180 - CGFloat(index) * 30, height: 110 - CGFloat(index) * 12)
                    .rotationEffect(.degrees(-12 + Double(index) * 9))
                    .offset(x: CGFloat(index) * 60 - 40, y: CGFloat(index) * 12 - 10)
            }
        }
    }
}

private struct SampleFavicon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14).fill(LinearGradient(colors: [.blue, .indigo], startPoint: .top, endPoint: .bottom))
            Image(systemName: "link").font(.system(size: 30, weight: .bold)).foregroundStyle(.white)
        }
    }
}

private struct SampleDocument: View {
    var body: some View {
        ZStack(alignment: .top) {
            Color.white
            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.8)).frame(width: 110, height: 14)
                RoundedRectangle(cornerRadius: 3).fill(Color.black.opacity(0.25)).frame(width: 140, height: 8)
                ForEach(0..<9, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3).fill(Color.black.opacity(0.18)).frame(width: index % 3 == 2 ? 100 : 150, height: 7)
                }
                RoundedRectangle(cornerRadius: 6).fill(LinearGradient(colors: [.indigo.opacity(0.6), .pink.opacity(0.6)], startPoint: .leading, endPoint: .trailing)).frame(height: 44)
            }
            .padding(22)
        }
    }
}
#endif
