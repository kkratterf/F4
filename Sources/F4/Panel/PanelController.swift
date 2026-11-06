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
    /// The ⓘ button: shows how to add stickers.
    var onHelp: (() -> Void)?
    /// ⌘K and ⌘M: the actions over the panel.
    private let palette = ActionPalette()
    private let organizer: LibraryOrganizer

    init(library: MemeLibrary, usage: UsageStore, organizer: LibraryOrganizer) {
        self.library = library
        self.usage = usage
        self.organizer = organizer
        model = DeckModel(library: library, usage: usage)
        panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: Self.size))
        super.init()
        let deck = DeckView(
            model: model,
            library: library,
            palette: palette,
            onPick: { [weak self] meme in self?.pick(meme) },
            onAdd: { [weak self] in self?.chooseFiles() },
            onHelp: { [weak self] in
                self?.hide()
                self?.onHelp?()
            },
            onActions: { [weak self] in self?.openActions() },
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
        CopiedToast.shared.show()
    }

    // MARK: Adding memes

    /// Set while something is dragged over the panel, so letting go of the
    /// mouse there does not hide it before the drop arrives.
    private var dragIsInside = false
    /// Set while a paste or a drop is being saved, so the panel stays up for its result.
    private var isImporting = false
    /// Polls the mouse after the panel lost focus with a button down.
    private var mouseUpTimer: Timer?

    /// Where new stickers go: the folder of the tab on screen, else the top
    /// of the library.
    private var targetFolder: URL {
        guard let name = model.tab.folder else { return library.folder }
        return library.folder.appendingPathComponent(name, isDirectory: true)
    }

    /// Adds what the pasteboard holds (⌘V or a drop) to the meme folder,
    /// turning a still image into a sticker unless `convert` is false (⌥⌘V).
    private func add(from pasteboard: NSPasteboard, convert: Bool = true) {
        let folder = targetFolder
        isImporting = true
        Task {
            defer { isImporting = false }
            do {
                let urls = try await MemeImporter.importItems(from: pasteboard, into: folder, convert: convert)
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
            + [UTType(filenameExtension: "wastickers"), UTType.zip].compactMap { $0 }
        picker.prompt = String(localized: "Add")
        picker.message = String(localized: "Choose stickers or WhatsApp sticker packs (.wastickers) to add. F4 copies them into its own folder, so the originals can stay where they are.")
        isShowingDialog = true
        NSApp.activate(ignoringOtherApps: true)
        picker.level = .modalPanel
        picker.begin { [weak self] response in
            guard let self else { return }
            self.isShowingDialog = false
            self.panel.makeKeyAndOrderFront(nil)
            guard response == .OK else { return }
            let urls = picker.urls
            let folder = self.targetFolder
            Task {
                do {
                    self.added(try await MemeImporter.importFiles(urls, into: folder))
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
            : String(localized: "Added \(String(urls.count)) stickers to \(folder)"))
        library.reload()
        model.reveal(first)
        if !panel.isVisible { show(keepingQuery: true) }
        panel.makeKeyAndOrderFront(nil)
    }

    private func failed(_ error: Error) {
        model.show(notice: error.localizedDescription)
        if panel.isVisible { panel.makeKeyAndOrderFront(nil) }
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        PanelTiming.opening()
        show(keepingQuery: false)
    }

    /// Opens the panel with `query` already typed in (`f4://search`).
    func show(query: String) {
        PanelTiming.opening()
        model.prepareForShow()
        model.query = query
        show(keepingQuery: true)
    }

    private func show(keepingQuery: Bool) {
        if !keepingQuery { model.prepareForShow() }
        position(on: screenWithMouse())
        startArrowKeys()
        panel.makeKeyAndOrderFront(nil)
        // Lay out and draw now, as the next display pass would, so the time
        // logged is the time to a panel on screen.
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.displayIfNeeded()
        PanelTiming.shown(stickers: library.memes.count)
        // The shadow follows the content's rounded shape once it is drawn.
        DispatchQueue.main.async { [panel] in panel.invalidateShadow() }
    }

    func hide() {
        palette.close()
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
            // The keyboard leads: the mouse only takes the selection back
            // once it really moves (`DeckModel.pointerMoved`).
            self.model.keyboardUsed()
            if self.palette.isOpen { return self.paletteKey(event) ? nil : event }
            self.model.feedKonami(Self.konamiKey(for: event))
            if self.switchTab(for: event) { return nil }
            if let action = self.command(for: event) {
                Self.later(action)
                return nil
            }
            if self.pasteMeme(for: event) { return nil }
            if self.pickOrHide(for: event) { return nil }
            if let direction = Self.direction(for: event) {
                return self.model.move(direction) ? nil : event
            }
            // Anything else is typing: it goes to the search field, even
            // after a click somewhere in the panel took the focus from it.
            self.focusSearchField()
            return event
        }
    }

    /// Runs `action` after the key event that asked for it is done. A
    /// rename or tags prompt is a modal alert, and a modal loop started from
    /// inside the key monitor does not get its keys: the prompt opened
    /// from the keyboard did nothing, while the same item clicked worked.
    private static func later(_ action: @escaping @MainActor () -> Void) {
        DispatchQueue.main.async { MainActor.assumeIsolated { action() } }
    }

    /// Enter copies the selected sticker and Esc closes the panel, wherever
    /// the focus is in the panel. Not while an input method is composing,
    /// whose Enter and Esc belong to the text.
    private func pickOrHide(for event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection([.command, .option, .control]).isEmpty else { return false }
        if let editor = panel.firstResponder as? NSTextView, editor.hasMarkedText() { return false }
        switch Int(event.keyCode) {
        case kVK_Return, kVK_ANSI_KeypadEnter:
            guard let meme = model.selectedMeme else { return false }
            Self.later { [weak self] in self?.pick(meme) }
        case kVK_Escape:
            Self.later { [weak self] in self?.hide() }
        default:
            return false
        }
        return true
    }

    /// Gives the search field the focus back, with the caret at the end, if
    /// something else in the panel took it (a click on a tab or a sticker).
    private func focusSearchField() {
        if let editor = panel.firstResponder as? NSTextView, editor.isFieldEditor { return }
        guard let field = panel.contentView.flatMap(Self.editableField(in:)) else {
            model.focusSearch()
            return
        }
        panel.makeFirstResponder(field)
        if let editor = field.currentEditor() {
            editor.selectedRange = NSRange(location: (editor.string as NSString).length, length: 0)
        }
    }

    private static func editableField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField, field.isEditable { return field }
        for subview in view.subviews {
            if let field = editableField(in: subview) { return field }
        }
        return nil
    }

    /// Tab / ⇧Tab cycle through Stickers, Favourites and the folder tabs; ⌘1…⌘9 jump to one. Returns true when
    /// the key was taken. The search field has no use for Tab here.
    private func switchTab(for event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if Int(event.keyCode) == kVK_Tab, modifiers.subtracting(.shift).isEmpty {
            model.cycleTab(backwards: modifiers.contains(.shift))
            return true
        }
        guard modifiers == .command else { return false }
        let digits = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]
        guard let index = digits.firstIndex(of: Int(event.keyCode)) else { return false }
        model.selectTab(at: index)
        return true
    }

    // MARK: Actions

    /// ⌘K actions, ⌘M move to a folder, ⌘D favourite, ⌘R rename, ⌘T tags and, with
    /// an empty search field, ⌘⌫ to the Trash, on the selected sticker: what
    /// to run for `event`, or nil when it is none of them. The letters are
    /// read from the keyboard layout, so ⌘T is the key marked T on any layout.
    private func command(for event: NSEvent) -> (@MainActor () -> Void)? {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard modifiers == .command, let meme = model.selectedMeme else { return nil }
        let editable = !library.isStarter(meme)
        if Int(event.keyCode) == kVK_Delete {
            guard editable, model.query.isEmpty else { return nil }
            return { [weak self] in self?.organize(meme, .trash) }
        }
        switch Self.letter(of: event) {
        case "k":
            return { [weak self] in self?.openActions() }
        case "d":
            return { [weak self] in self?.usage.toggleFavourite(meme) }
        case "m" where editable:
            return { [weak self] in self?.openMoveTo(meme) }
        case "r" where editable:
            return { [weak self] in self?.organize(meme, .rename) }
        case "t" where editable:
            return { [weak self] in self?.organize(meme, .editTags) }
        default:
            return nil
        }
    }

    /// The letter a key types on the current layout, lower case; on a
    /// layout without Latin letters, the letter at that key on a US keyboard.
    private static func letter(of event: NSEvent) -> Character? {
        if let typed = event.charactersIgnoringModifiers?.lowercased().first, typed.isASCII, typed.isLetter {
            return typed
        }
        let keys: [Int: Character] = [
            kVK_ANSI_K: "k", kVK_ANSI_D: "d", kVK_ANSI_M: "m", kVK_ANSI_R: "r", kVK_ANSI_T: "t",
        ]
        return keys[Int(event.keyCode)]
    }

    /// The keys while the palette is open: arrows move, Enter runs, Escape
    /// and ⌘K close it, and a sticker shortcut (⌘R, ⌘T, ⌘M, ⌘D, ⌘⌫) closes it
    /// and runs; everything else types in its filter field.
    private func paletteKey(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        switch Int(event.keyCode) {
        case kVK_UpArrow: palette.move(by: -1)
        case kVK_DownArrow: palette.move(by: 1)
        case kVK_Return, kVK_ANSI_KeypadEnter: Self.later { [palette] in palette.runSelected() }
        case kVK_Escape: palette.close()
        default:
            if modifiers == .command, Self.letter(of: event) == "k" {
                palette.close()
                return true
            }
            // ⌘⌫ clears the filter while there is one to clear.
            if Int(event.keyCode) == kVK_Delete, !palette.filter.isEmpty { return false }
            guard let action = command(for: event) else { return false }
            palette.close()
            Self.later(action)
        }
        return true
    }

    /// ⌘K: what can be done with the selected sticker.
    private func openActions() {
        guard let meme = model.selectedMeme else { return }
        let favourite = usage.isFavourite(meme)
        var items: [ActionPalette.Item] = [
            .init(title: String(localized: "Copy"), systemImage: "doc.on.doc", shortcut: "↵") { [weak self] in
                self?.pick(meme)
            },
            .init(
                title: favourite ? String(localized: "Remove from Favourites") : String(localized: "Add to Favourites"),
                systemImage: favourite ? "star.slash" : "star",
                shortcut: "⌘D"
            ) { [weak self] in self?.usage.toggleFavourite(meme) },
        ]
        if !library.isStarter(meme) {
            items += [
                .init(title: String(localized: "Move to Folder…"), systemImage: "folder", shortcut: "⌘M") { [weak self] in
                    self?.openMoveTo(meme)
                },
                .init(title: String(localized: "Rename…"), systemImage: "pencil", shortcut: "⌘R") { [weak self] in
                    self?.organize(meme, .rename)
                },
                .init(title: String(localized: "Edit Tags…"), systemImage: "tag", shortcut: "⌘T") { [weak self] in
                    self?.organize(meme, .editTags)
                },
                .init(title: String(localized: "Show in Finder"), systemImage: "magnifyingglass") {
                    NSWorkspace.shared.activateFileViewerSelecting([meme.url])
                },
                .init(title: String(localized: "Move to Trash"), systemImage: "trash", shortcut: "⌘⌫", isDestructive: true) { [weak self] in
                    self?.organize(meme, .trash)
                },
            ]
        }
        palette.open(title: meme.name, items: items)
    }

    /// ⌘M: the folders the selected sticker can move to, filtered by typing.
    private func openMoveTo(_ meme: Meme) {
        var items: [ActionPalette.Item] = []
        if meme.category != nil {
            items.append(.init(title: String(localized: "Top Level"), systemImage: "tray") { [weak self] in
                self?.organize(meme, .move(to: nil))
            })
        }
        for folder in library.folders where folder != meme.category {
            items.append(.init(title: folder, systemImage: "folder") { [weak self] in
                self?.organize(meme, .move(to: folder))
            })
        }
        items.append(.init(title: String(localized: "New Folder…"), systemImage: "folder.badge.plus") { [weak self] in
            self?.organize(meme, .moveToNewFolder)
        })
        palette.open(title: String(localized: "Move \(meme.name) to"), items: items)
    }

    /// ⌘V with an empty search field and an image, an image file or a link
    /// on the clipboard adds it to the meme folder as a sticker; ⌥⌘V adds
    /// the image as it is. Otherwise the search field pastes the text as usual.
    private func pasteMeme(for event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard modifiers == .command || modifiers == [.command, .option], Int(event.keyCode) == kVK_ANSI_V,
              model.query.isEmpty, MemeImporter.canImport(.general)
        else { return false }
        add(from: .general, convert: !modifiers.contains(.option))
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
