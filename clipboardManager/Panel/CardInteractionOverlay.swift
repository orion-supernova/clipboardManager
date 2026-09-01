//
//  CardInteractionOverlay.swift
//  clipboardManager
//
//  An AppKit overlay on top of each card that owns all mouse handling: hover,
//  press feedback, click-to-paste, the hover controls, right-click menus and —
//  most importantly — drag sessions with a configurable copy/move operation
//  mask (SwiftUI's `onDrag` cannot restrict operations, which "copy vs. move"
//  requires). Nothing here changes geometry, so tracking areas stay stable.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

indirect enum ContextMenuEntry {
    case item(title: String, symbol: String, isDestructive: Bool = false, action: @MainActor () -> Void)
    case submenu(title: String, symbol: String, entries: [ContextMenuEntry])
    case separator
}

/// The four hover controls drawn by SwiftUI in a card's top-trailing corner.
enum CardControl: CaseIterable, Sendable {
    case preview, folder, pin, delete

    static let size: CGFloat = 26
    static let spacing: CGFloat = 4
    static let padding: CGFloat = 8
}

struct CardInteractionOverlay: NSViewRepresentable {
    var item: ClipboardItem
    var dragMode: DragMode
    var controlsVisible: Bool
    var isEnabled: Bool
    var payloadProvider: @Sendable () async -> ClipboardPayload?
    var dragPreview: @MainActor () -> NSImage?
    var onTap: @MainActor () -> Void
    var onControl: @MainActor (CardControl) -> Void
    var onHover: @MainActor (Bool) -> Void
    var onPress: @MainActor (Bool) -> Void
    var contextMenu: @MainActor () -> [ContextMenuEntry]
    var folderMenu: @MainActor () -> [ContextMenuEntry]

    func makeNSView(context: Context) -> CardInteractionView {
        let view = CardInteractionView()
        apply(to: view)
        return view
    }

    func updateNSView(_ nsView: CardInteractionView, context: Context) {
        apply(to: nsView)
    }

    private func apply(to view: CardInteractionView) {
        view.item = item
        view.dragMode = dragMode
        view.controlsVisible = controlsVisible
        view.isEnabled = isEnabled
        view.payloadProvider = payloadProvider
        view.dragPreviewProvider = dragPreview
        view.onTap = onTap
        view.onControl = onControl
        view.onHover = onHover
        view.onPress = onPress
        view.contextMenuProvider = contextMenu
        view.folderMenuProvider = folderMenu
    }
}

@MainActor
final class CardInteractionView: NSView, NSDraggingSource, NSFilePromiseProviderDelegate {
    var item: ClipboardItem?
    var dragMode: DragMode = .copy
    var controlsVisible = false
    var isEnabled = true
    var payloadProvider: (@Sendable () async -> ClipboardPayload?)?
    var dragPreviewProvider: (() -> NSImage?)?
    var onTap: (() -> Void)?
    var onControl: ((CardControl) -> Void)?
    var onHover: ((Bool) -> Void)?
    var onPress: ((Bool) -> Void)?
    var contextMenuProvider: (() -> [ContextMenuEntry])?
    var folderMenuProvider: (() -> [ContextMenuEntry])?

    private var mouseDownPoint: NSPoint?
    private var mouseDownControl: CardControl?
    private var didDrag = false
    private var trackingArea: NSTrackingArea?
    private var menuActions: [MenuAction] = []
    private static let promiseQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.walhallaa.clipboardManager.filePromise"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        isEnabled ? super.hitTest(point) : nil
    }

    // MARK: - Control geometry (mirrors the SwiftUI overlay: top-trailing, padding 8, spacing 4)

    private func controlRect(_ control: CardControl) -> NSRect {
        let controls = CardControl.allCases
        let index = CGFloat(controls.firstIndex(of: control) ?? 0)
        let count = CGFloat(controls.count)
        let size = CardControl.size
        let x = bounds.maxX - CardControl.padding - (count - index) * size - (count - 1 - index) * CardControl.spacing
        let y = bounds.maxY - CardControl.padding - size
        return NSRect(x: x, y: y, width: size, height: size)
    }

    private func control(at point: NSPoint) -> CardControl? {
        guard controlsVisible else { return nil }
        return CardControl.allCases.first { controlRect($0).contains(point) }
    }

    // MARK: - Hover

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) {
        onHover?(false)
        if mouseDownPoint != nil, !didDrag { onPress?(false) }
    }

    // MARK: - Click & drag

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        mouseDownPoint = point
        mouseDownControl = control(at: point)
        didDrag = false
        if mouseDownControl == nil { onPress?(true) }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = mouseDownPoint, !didDrag, mouseDownControl == nil else { return }
        let current = convert(event.locationInWindow, from: nil)
        guard hypot(current.x - start.x, current.y - start.y) > 5 else { return }
        didDrag = true
        onPress?(false)
        beginDrag(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        defer { mouseDownPoint = nil; mouseDownControl = nil }
        onPress?(false)
        guard !didDrag, mouseDownPoint != nil else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point) else { return }
        if let control = control(at: point), control == mouseDownControl {
            if control == .folder {
                showFolderMenu(anchoredTo: controlRect(control))
            } else {
                onControl?(control)
            }
            return
        }
        guard mouseDownControl == nil else { return }
        onTap?()
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let entries = contextMenuProvider?(), !entries.isEmpty else { return }
        menuActions.removeAll()
        NSMenu.popUpContextMenu(makeMenu(entries), with: event, for: self)
    }

    private func showFolderMenu(anchoredTo rect: NSRect) {
        guard let entries = folderMenuProvider?(), !entries.isEmpty else { return }
        menuActions.removeAll()
        let menu = makeMenu(entries)
        menu.popUp(positioning: nil, at: NSPoint(x: rect.minX, y: rect.minY - 4), in: self)
    }

    private func makeMenu(_ entries: [ContextMenuEntry]) -> NSMenu {
        let menu = NSMenu()
        for entry in entries {
            switch entry {
            case .separator:
                menu.addItem(.separator())
            case let .item(title, symbol, isDestructive, action):
                let box = MenuAction(action)
                menuActions.append(box)
                let menuItem = NSMenuItem(title: title, action: #selector(MenuAction.invoke), keyEquivalent: "")
                menuItem.target = box
                menuItem.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
                if isDestructive {
                    menuItem.attributedTitle = NSAttributedString(string: title, attributes: [.foregroundColor: NSColor.systemRed])
                }
                menu.addItem(menuItem)
            case let .submenu(title, symbol, children):
                let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                menuItem.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
                menuItem.submenu = makeMenu(children)
                menu.addItem(menuItem)
            }
        }
        return menu
    }

    private func beginDrag(with event: NSEvent) {
        guard let item, let writer = makeWriter(for: item) else { return }
        let draggingItem = NSDraggingItem(pasteboardWriter: writer)
        let location = convert(event.locationInWindow, from: nil)
        if let preview = dragPreviewProvider?() {
            let size = preview.size
            let frame = NSRect(
                x: location.x - size.width / 2,
                y: location.y - size.height / 2,
                width: size.width,
                height: size.height
            )
            draggingItem.setDraggingFrame(frame, contents: preview)
        } else {
            draggingItem.setDraggingFrame(bounds, contents: nil)
        }
        let session = beginDraggingSession(with: [draggingItem], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    /// Builds the pasteboard writer synchronously. Payloads come from a background
    /// context that never touches the main thread, so a short bounded wait is safe.
    private func makeWriter(for item: ClipboardItem) -> (any NSPasteboardWriting)? {
        let payload = fetchPayloadBlocking()
        switch item.kind {
        case .text:
            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setString(payload?.text ?? item.preview, forType: .string)
            if let rtf = payload?.richText { pasteboardItem.setData(rtf, forType: .rtf) }
            return pasteboardItem
        case .url:
            let text = (payload?.text ?? item.preview).trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: text) { return url as NSURL }
            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setString(text, forType: .string)
            return pasteboardItem
        case .color:
            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setString(payload?.text ?? item.preview, forType: .string)
            return pasteboardItem
        case .image:
            guard let source = payload?.imageFileURL else { return nil }
            let provider = ImagePromiseProvider(fileType: UTType.png.identifier, delegate: self)
            provider.sourceURL = source
            provider.suggestedName = "Clipboard Image \(Self.nameFormatter.string(from: item.timestamp)).png"
            return provider
        case .file, .video:
            guard let url = payload?.fileURL else { return nil }
            return url as NSURL
        }
    }

    private func fetchPayloadBlocking() -> ClipboardPayload? {
        guard let payloadProvider else { return nil }
        let box = LockedBox<ClipboardPayload?>(nil)
        let semaphore = DispatchSemaphore(value: 0)
        Task.detached(priority: .userInitiated) {
            box.value = await payloadProvider()
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 1.5)
        return box.value
    }

    private static let nameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return formatter
    }()

    // MARK: - NSDraggingSource

    nonisolated func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        MainActor.assumeIsolated {
            guard context == .outsideApplication, let item else { return [] }
            guard item.kind.isFileBacked else { return .copy }
            return dragMode == .move ? [.move, .copy] : .copy
        }
    }

    nonisolated func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { false }

    // MARK: - NSFilePromiseProviderDelegate

    nonisolated func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        (filePromiseProvider as? ImagePromiseProvider)?.suggestedName ?? "Clipboard Image.png"
    }

    nonisolated func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider,
        writePromiseTo url: URL,
        completionHandler: @escaping @Sendable ((any Error)?) -> Void
    ) {
        guard let source = (filePromiseProvider as? ImagePromiseProvider)?.sourceURL else {
            completionHandler(CocoaError(.fileNoSuchFile))
            return
        }
        do {
            try FileManager.default.copyItem(at: source, to: url)
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }

    nonisolated func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
        MainActor.assumeIsolated { Self.promiseQueue }
    }
}

/// A file promise that also exposes PNG bytes, so image-accepting destinations
/// (chat apps, editors) get the picture and file destinations get a nicely named file.
private final class ImagePromiseProvider: NSFilePromiseProvider, @unchecked Sendable {
    var sourceURL: URL?
    var suggestedName: String?

    override func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        super.writableTypes(for: pasteboard) + [.png]
    }

    override func writingOptions(forType type: NSPasteboard.PasteboardType, pasteboard: NSPasteboard) -> NSPasteboard.WritingOptions {
        type == .png ? [] : super.writingOptions(forType: type, pasteboard: pasteboard)
    }

    override func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        if type == .png {
            return sourceURL.flatMap { try? Data(contentsOf: $0) }
        }
        return super.pasteboardPropertyList(forType: type)
    }
}

@MainActor
private final class MenuAction: NSObject {
    private let action: () -> Void
    init(_ action: @escaping () -> Void) { self.action = action }
    @objc func invoke() { action() }
}

private final class LockedBox<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value
    init(_ value: Value) { storage = value }
    var value: Value {
        get { lock.withLock { storage } }
        set { lock.withLock { storage = newValue } }
    }
}
