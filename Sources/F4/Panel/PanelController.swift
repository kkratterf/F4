import AppKit
import Carbon.HIToolbox
import F4Core
import SwiftUI
import UniformTypeIdentifiers

/// Owns the floating panel and shows or hides it.
///
/// The panel and its SwiftUI content are created once at launch and only
/// ordered in and out afterwards, so showing it never waits for a view to load.
///
/// It hides on Esc and as soon as the panel loses key status, which is what
/// happens when the user clicks outside it or switches app. The panel never
/// activates F4, so the app the user was in keeps the focus.
@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    static let size = NSSize(width: 720, height: 500)

    private let panel: FloatingPanel
    private let library: MemeLibrary
    private let model: DeckModel
    private var keyMonitor: Any?
    private let guides = SnapGuideWindow()
    /// True once a drag has actually moved the panel.
    private var didDrag = false

    private let usage: UsageStore
    private let organizer: LibraryOrganizer

    init(library: MemeLibrary, usage: UsageStore, organizer: LibraryOrganizer) {
        self.library = library
        self.usage = usage
        self.organizer = organizer
        model = DeckModel(library: library, usage: usage, giphy: .shared)
        panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: Self.size))
        super.init()
        let deck = DeckView(
            model: model,
            library: library,
            onPick: { [weak self] meme in self?.pick(meme) },
            onAdd: { [weak self] in self?.chooseFiles() },
            onPickWeb: { [weak self] result in self?.pick(result) },
            onPinWeb: { [weak self] result in self?.pin(result) },
            onDrag: { [weak self] drag in self?.drag(drag) },
            onOrganize: { [weak self] meme, action in self?.organize(meme, action) }
        )
        let hosting = DropHostingView(rootView: deck)
        hosting.onDragChange = { [weak self] inside in self?.dragIsInside = inside }
        hosting.onDrop = { [weak self] pasteboard in self?.add(from: pasteboard) }
        hosting.frame = NSRect(origin: .zero, size: Self.size)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        panel.delegate = self
        panel.onCancel = { [weak self] in self?.hide() }
    }

    /// Copies the meme and gets out of the way, so the user can paste right
    /// away. Also used by the recent memes in the menu bar menu.
    func pick(_ meme: Meme) {
        guard MemeClipboard.copy(meme) else {
            hide()
            return
        }
        usage.recordCopy(meme)
        hide()
        if AppSettings.shared.pasteAfterCopy {
            AutoPaster.pasteSoon()
        }
    }

    // MARK: Adding memes

    /// Set while something is dragged over the panel, so letting go of the
    /// mouse there does not hide it before the drop arrives.
    private var dragIsInside = false
    /// Set while a paste or a drop is being saved, so the panel stays up for its result.
    private var isImporting = false
    /// Polls the mouse after the panel lost focus with a button down.
    private var mouseUpTimer: Timer?

    /// Adds what the pasteboard holds (⌘V or a drop) to the meme folder.
    private func add(from pasteboard: NSPasteboard) {
        let folder = library.folder
        let tab = model.tab
        isImporting = true
        Task {
            defer { isImporting = false }
            do {
                let urls = try await MemeImporter.importItems(from: pasteboard, into: folder, tab: tab)
                added(urls)
            } catch {
                failed(error)
            }
        }
    }

    /// Set while the Add button's file picker or an organizing prompt is
    /// open: it takes the focus, and the panel must stay for the result.
    private var isShowingDialog = false

    /// The Add button: a file picker. F4 comes to the front for it (an open
    /// panel needs an active app), and the panel waits behind it.
    ///
    /// The picker only chooses files: they are copied into the meme folder,
    /// wherever they are. It starts in Downloads, where saved GIFs usually
    /// land, instead of the last folder any app's picker was in.
    private func chooseFiles() {
        let picker = NSOpenPanel()
        picker.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        picker.canChooseFiles = true
        picker.canChooseDirectories = false
        picker.allowsMultipleSelection = true
        picker.allowedContentTypes = MemeKind.allCases.compactMap { UTType($0.typeIdentifier) }
        picker.prompt = String(localized: "Add")
        picker.message = String(localized: "Choose GIFs and stickers to add. F4 copies them into its own folder, so the originals can stay where they are.")
        isShowingDialog = true
        NSApp.activate(ignoringOtherApps: true)
        picker.level = .modalPanel
        picker.begin { [weak self] response in
            guard let self else { return }
            self.isShowingDialog = false
            self.panel.makeKeyAndOrderFront(nil)
            guard response == .OK else { return }
            let urls = picker.urls
            let folder = self.library.folder
            let tab = self.model.tab
            Task {
                do {
                    self.added(try await MemeImporter.importFiles(urls, into: folder, tab: tab))
                } catch {
                    self.failed(error)
                }
            }
        }
    }

    /// Moves, renames or trashes a meme from its right-click menu. A prompt
    /// (a name to type) brings F4 to the front; the panel stays behind it
    /// and gets the focus back with the result in its notice line.
    private func organize(_ meme: Meme, _ action: MemeAction) {
        isShowingDialog = true
        let message = organizer.perform(action, on: meme)
        isShowingDialog = false
        if let message { model.show(notice: message) }
        if panel.isVisible { panel.makeKeyAndOrderFront(nil) }
    }

    private func added(_ urls: [URL]) {
        guard let first = urls.first else { return }
        // Added from the Favourites tab: that's where the user wants them.
        if model.tab == .favourites {
            for url in urls { usage.addFavourite(url) }
        }
        let folder = first.deletingLastPathComponent().lastPathComponent
        model.show(notice: urls.count == 1
            ? String(localized: "Added to \(folder)")
            : String(localized: "Added \(String(urls.count)) memes to \(folder)"))
        library.reload()
        model.reveal(first)
        if !panel.isVisible { show(keepingQuery: true) }
        panel.makeKeyAndOrderFront(nil)
    }

    private func failed(_ error: Error) {
        model.show(notice: error.localizedDescription)
        if panel.isVisible { panel.makeKeyAndOrderFront(nil) }
    }

    // MARK: GIPHY

    /// Copies a GIPHY result. It is saved in the meme folder first (GIFs/
    /// or Stickers/), so it pastes animated like any meme, shows up in the
    /// recents, and stays there for next time, offline too.
    private func pick(_ result: Giphy.Result) {
        model.show(notice: String(localized: "Downloading from GIPHY…"))
        Task {
            do {
                let url = try await save(result)
                let meme = Meme(url: url, kind: MemeKind(url: url) ?? .gif, modificationDate: Date())
                guard MemeClipboard.copy(meme) else { return hide() }
                usage.recordCopy(meme)
                library.reload()
                hide()
                if AppSettings.shared.pasteAfterCopy { AutoPaster.pasteSoon() }
            } catch {
                model.show(notice: String(localized: "Couldn't download the GIF from GIPHY."))
            }
        }
    }

    /// Saves a GIPHY result in the meme folder as a favourite: from then on
    /// it is local, instant and offline.
    private func pin(_ result: Giphy.Result) {
        Task {
            do {
                let url = try await save(result)
                usage.addFavourite(url)
                added([url])
            } catch {
                failed(error)
            }
        }
    }

    /// The GIPHY result as a file in the meme folder: downloaded and saved
    /// the first time, the same file every time after.
    private func save(_ result: Giphy.Result) async throws -> URL {
        if let saved = usage.savedFile(forWebMeme: result.saveKey) { return saved }
        let file = try await model.giphy.file(for: result)
        let url = try await MemeImporter.pin(file, name: result.name, into: library.folder, tab: result.tab)
        usage.recordSave(ofWebMeme: result.saveKey, at: url)
        return url
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        show(keepingQuery: false)
    }

    /// Opens the panel with `query` already typed in (`f4://search`).
    func show(query: String) {
        model.prepareForShow()
        model.query = query
        show(keepingQuery: true)
    }

    private func show(keepingQuery: Bool) {
        if !keepingQuery { model.prepareForShow() }
        position(on: screenWithMouse())
        startArrowKeys()
        panel.makeKeyAndOrderFront(nil)
        // The shadow follows the content's rounded shape once it is drawn.
        DispatchQueue.main.async { [panel] in panel.invalidateShadow() }
    }

    func hide() {
        mouseUpTimer?.invalidate()
        mouseUpTimer = nil
        stopArrowKeys()
        guides.hide()
        panel.orderOut(nil)
    }

    // MARK: Arrow keys

    /// Arrow keys move the selection in the grid while the search field keeps
    /// the focus, so the user can type and navigate without switching. A local
    /// monitor sees the key before the field editor does; it only exists
    /// while the panel is open and only takes events aimed at the panel.
    private func startArrowKeys() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            self.model.feedKonami(Self.konamiKey(for: event))
            if self.switchTab(for: event) { return nil }
            if self.pasteMeme(for: event) { return nil }
            guard let direction = Self.direction(for: event) else { return event }
            return self.model.move(direction) ? nil : event
        }
    }

    /// Tab / ⇧Tab cycle the tabs; ⌘1 to ⌘4 jump to one. Returns true when
    /// the key was taken. The search field has no use for Tab here.
    private func switchTab(for event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if Int(event.keyCode) == kVK_Tab, modifiers.subtracting(.shift).isEmpty {
            model.cycleTab(backwards: modifiers.contains(.shift))
            return true
        }
        guard modifiers == .command else { return false }
        let tabs: [Int: MemeTab] = [kVK_ANSI_1: .all, kVK_ANSI_2: .favourites, kVK_ANSI_3: .gifs, kVK_ANSI_4: .stickers]
        guard let tab = tabs[Int(event.keyCode)] else { return false }
        model.tab = tab
        return true
    }

    /// ⌘V with an empty search field and an image, an image file or a link
    /// on the clipboard adds it to the meme folder. Otherwise the search
    /// field pastes the text as usual.
    private func pasteMeme(for event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard modifiers == .command, Int(event.keyCode) == kVK_ANSI_V,
              model.query.isEmpty, MemeImporter.canImport(.general)
        else { return false }
        add(from: .general)
        return true
    }

    private func stopArrowKeys() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    private static func konamiKey(for event: NSEvent) -> KonamiCode.Key {
        switch Int(event.keyCode) {
        case kVK_UpArrow: return .up
        case kVK_DownArrow: return .down
        case kVK_LeftArrow: return .left
        case kVK_RightArrow: return .right
        case kVK_ANSI_B: return .b
        case kVK_ANSI_A: return .a
        default: return .other
        }
    }

    private static func direction(for event: NSEvent) -> GridDirection? {
        // Leave ⌘/⌥-arrows to the text field (jump to start/end, word by word).
        guard event.modifierFlags.intersection([.command, .option, .control]).isEmpty else { return nil }
        switch Int(event.keyCode) {
        case kVK_LeftArrow: return .left
        case kVK_RightArrow: return .right
        case kVK_UpArrow: return .up
        case kVK_DownArrow: return .down
        default: return nil
        }
    }

    // MARK: NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        // The Add button's file picker and the organizing prompts take the focus for a while.
        if isShowingDialog { return }
        // A press in another app may be the start of a drag towards the
        // panel (a sticker out of WhatsApp or a file out of Finder): stay
        // until the button is released, and stay if it was released over us.
        if NSEvent.pressedMouseButtons & 1 != 0 {
            waitForMouseUp()
            return
        }
        hide()
    }

    private func waitForMouseUp() {
        mouseUpTimer?.invalidate()
        mouseUpTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self, NSEvent.pressedMouseButtons & 1 == 0 else { return }
                timer.invalidate()
                self.mouseUpTimer = nil
                // A drop on the panel arrives right after the release and
                // brings the focus back (added(_:)); anything else hides it.
                if !self.dragIsInside && !self.isImporting && !self.panel.isKeyWindow { self.hide() }
            }
        }
    }

    // MARK: Position

    /// Where the user last left the panel, as `PanelPlacement.relativeCentre`;
    /// nil until they move it, or after they snap it back to the default spot.
    private static let positionKey = "panelPosition"

    private var savedCentre: CGPoint? {
        get {
            guard let values = UserDefaults.standard.array(forKey: Self.positionKey) as? [Double],
                  values.count == 2 else { return nil }
            return CGPoint(x: values[0], y: values[1])
        }
        set {
            if let newValue {
                UserDefaults.standard.set([Double(newValue.x), Double(newValue.y)], forKey: Self.positionKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.positionKey)
            }
        }
    }

    /// Opens on the screen with the mouse, where the user last dragged the
    /// panel (at the same place relative to that screen), or where Spotlight sits.
    private func position(on screen: NSScreen?) {
        guard let visible = (screen ?? NSScreen.main)?.visibleFrame else { return }
        let size = panel.frame.size
        let origin = savedCentre.map { PanelPlacement.origin(relativeCentre: $0, size: size, in: visible) }
            ?? PanelPlacement.defaultOrigin(size: size, in: visible)
        panel.setFrameOrigin(origin)
    }

    /// Moves the panel with the mouse, snapping to the screen's centre lines
    /// and the default height, and remembers where it was left.
    private func drag(_ drag: PanelDrag) {
        switch drag {
        case .began:
            didDrag = false
        case .moved(let proposed):
            guard let screen = screenWithMouse() ?? panel.screen else { return }
            let snap = PanelPlacement.snap(proposed, size: panel.frame.size, in: screen.visibleFrame)
            panel.setFrameOrigin(snap.origin)
            guides.show(snap.guides, on: screen, below: panel)
            didDrag = true
        case .ended:
            guides.hide()
            guard didDrag, let screen = panel.screen else { return }
            let visible = screen.visibleFrame
            let snap = PanelPlacement.snap(panel.frame.origin, size: panel.frame.size, in: visible)
            savedCentre = snap.isDefault ? nil : PanelPlacement.relativeCentre(of: panel.frame, in: visible)
        }
    }

    private func screenWithMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
    }
}
