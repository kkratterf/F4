import AppKit
import Carbon
import Combine
import F4Core
import SwiftUI

@main
struct F4App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The app has no regular windows: its UI is the floating panel owned
        // by AppDelegate. SwiftUI needs at least one scene, and an empty
        // Settings scene opens nothing on its own.
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: PanelController?
    private var statusItem: StatusItemController?
    private let settings = AppSettings.shared
    private lazy var library = MemeLibrary(
        folder: settings.memeFolder,
        showsStarterPack: settings.showStarterPack,
        needsSeeding: !settings.didSeedLibrary
    )
    private let usage = UsageStore()
    private lazy var organizer = LibraryOrganizer(library: library, usage: usage)
    private lazy var packs = PackDownloader(library: library)
    private var cancellables: Set<AnyCancellable> = []
    /// `f4://` URLs that arrive before the app has finished launching.
    private var pendingURLs: [URL] = []
    private var hasLaunched = false

    /// Handles `f4://` URLs with an Apple Event handler rather than
    /// `application(_:open:)`, which the SwiftUI app lifecycle does not
    /// reliably forward. Installed before launch finishes, so a URL that
    /// starts F4 is not lost.
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // No Dock icon and no menu bar of our own (also set via LSUIElement in the bundle).
        NSApp.setActivationPolicy(.accessory)
        library.onSeeded = { [weak self] in self?.settings.didSeedLibrary = true }
        library.reload()
        settings.$memeFolder
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] url in self?.library.setFolder(url) }
            .store(in: &cancellables)
        settings.$showStarterPack
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] shows in self?.library.setShowsStarterPack(shows) }
            .store(in: &cancellables)
        let panel = PanelController(library: library, usage: usage, organizer: organizer)
        self.panel = panel
        // Before the shortcut, so a shortcut macOS refuses shows in the menu.
        statusItem = StatusItemController(
            settings: settings,
            library: library,
            organizer: organizer,
            packs: packs,
            shortcut: settings.toggleShortcut.displayString,
            recentMemes: { [weak self] in self?.recentMemes() ?? [] },
            onCopy: { [weak self] meme in self?.panel?.pick(meme) },
            onOpen: { [weak self] in self?.panel?.show() }
        )
        registerToggleShortcut()
        // F4 always starts at login: registered once, on the first launch.
        LoginItem.enableOnFirstLaunch()
        // Auto-update; a no-op until Info.plist has a real Sparkle public key.
        AppUpdater.shared.start()
        hasLaunched = true
        if pendingURLs.isEmpty {
            // Opening the app from Finder or Spotlight shows the panel right away.
            panel.show()
        } else {
            // Started by a URL: do what it asks instead (f4://copy shows nothing).
            let urls = pendingURLs
            pendingURLs = []
            urls.forEach(handle)
        }
    }

    // MARK: f4:// URLs

    @objc private func handleGetURL(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        guard let string = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: string)
        else { return }
        if hasLaunched {
            handle(url)
        } else {
            pendingURLs.append(url)
        }
    }

    private func handle(_ url: URL) {
        guard let command = URLCommand(url: url) else {
            NSLog("F4: ignoring %@, not a known f4:// command", url.absoluteString)
            return
        }
        switch command {
        case .open:
            panel?.show()
        case .search(let query):
            panel?.show(query: query)
        case .copy(let name):
            whenLibraryLoaded { [weak self] in self?.copyBestMatch(for: name) }
        case .reload:
            library.reload()
        case .settings:
            // F4 has no Settings window: its options are in the menu.
            statusItem?.popUpAtPointer()
        }
    }

    /// Runs `action` now, or after the first scan when F4 was just started.
    private func whenLibraryLoaded(_ action: @escaping () -> Void) {
        guard !library.hasLoaded else { return action() }
        library.$hasLoaded
            .first { $0 }
            .sink { _ in action() }
            .store(in: &cancellables)
    }

    /// Copies the meme that best matches `name` without showing the panel,
    /// as if it had been picked there, with the same "Copied" toast. Beeps
    /// when nothing matches.
    private func copyBestMatch(for name: String) {
        guard let meme = URLCommand.bestMatch(
            for: name,
            in: library.memes,
            favourites: usage.favourites,
            recents: usage.recents
        ) else {
            NSLog("F4: no meme matches %@", name)
            NSSound.beep()
            return
        }
        if MemeClipboard.copy(meme) {
            usage.recordCopy(meme)
            CopiedToast.shared.show()
        }
    }

    /// The F4 key (fn F4 on a Mac keyboard) shows or hides the panel from
    /// anywhere. It is fixed: there is no other shortcut. Carbon hot keys
    /// need no Accessibility or Input Monitoring permission and swallow the
    /// key press.
    private func registerToggleShortcut() {
        let combo = settings.toggleShortcut
        let registered = HotKeyCenter.shared.register(id: Self.toggleShortcutID, combo: combo) { [weak self] in
            self?.panel?.toggle()
        }
        statusItem?.update(shortcut: combo.displayString)
        if !registered {
            // Usually another app owns the key.
            NSLog("F4: could not register %@, another app may be using it", combo.displayString)
            statusItem?.setShortcutError(String(localized: "\(combo.displayString) is taken by another app."))
        }
    }

    private static let toggleShortcutID = "togglePanel"

    /// The last copied memes that are still in the folder, most recent first.
    private func recentMemes() -> [Meme] {
        let byURL = Dictionary(library.memes.map { ($0.url, $0) }, uniquingKeysWith: { first, _ in first })
        return usage.recents.compactMap { byURL[$0] }
    }

    /// Opening the app again while it runs (Finder, Spotlight) shows the panel.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panel?.show()
        return false
    }
}
