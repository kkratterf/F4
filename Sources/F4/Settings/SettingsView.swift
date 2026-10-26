import AppKit
import F4Core
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    /// Set when macOS refused the shortcut, usually because another app owns it.
    let shortcutError: String?
    @StateObject private var loginItem = LoginItem()
    @ObservedObject private var updater = AppUpdater.shared
    @State private var isTrusted = AutoPaster.isTrusted

    var body: some View {
        Form {
            Section("General") {
                LabeledContent("Show and hide F4") {
                    ShortcutRecorder(combo: $settings.toggleShortcut, defaultCombo: .toggleDefault)
                }
                if let shortcutError {
                    Text(shortcutError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                if settings.toggleShortcut.isBareFunctionKey {
                    Text("On a Mac keyboard, hold fn and press \(settings.toggleShortcut.displayString), or turn on “Use F1, F2, etc. keys as standard function keys” in System Settings › Keyboard › Keyboard Shortcuts › Function Keys.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Toggle("Open F4 at login", isOn: Binding(
                    get: { loginItem.isEnabled },
                    set: { loginItem.setEnabled($0) }
                ))
                if let message = loginItem.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Paste") {
                Toggle("Paste into the front app after copying", isOn: Binding(
                    get: { settings.pasteAfterCopy },
                    set: { isOn in
                        settings.pasteAfterCopy = isOn
                        if isOn { isTrusted = AutoPaster.requestTrust() }
                    }
                ))
                if settings.pasteAfterCopy && !isTrusted {
                    HStack {
                        Text("F4 needs Accessibility access to press ⌘V for you. Until then it only copies.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Settings") { AutoPaster.openAccessibilitySettings() }
                    }
                } else {
                    Text("Off: F4 copies the meme and you paste it with ⌘V.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .opacity(settings.pasteAfterCopy ? 0 : 1)
                }
            }
            Section("Meme folder") {
                LabeledContent("Folder") {
                    Text(settings.memeFolder.path(percentEncoded: false))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                HStack {
                    Button("Choose…", action: chooseFolder)
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([settings.memeFolder])
                    }
                    Spacer()
                    Button("Use ~/Pictures/Memes") {
                        settings.memeFolder = MemeScanner.defaultFolder
                    }
                    .disabled(settings.isUsingDefaultFolder)
                }
                Text("F4 shows the GIF, PNG and JPEG files in this folder and its subfolders, and updates when you add or remove one. Subfolder names work as categories in search.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            // Hidden in builds without a real Sparkle key (see AppUpdater).
            if updater.isAvailable {
                Section("Updates") {
                    Toggle("Check for updates automatically", isOn: $updater.automaticallyChecksForUpdates)
                    HStack {
                        Text("F4 updates itself: new versions are downloaded from the release feed and installed in one click. This is the only request F4 makes to the network.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Check Now") { updater.checkForUpdates() }
                            .disabled(!updater.canCheckForUpdates)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            // The user may have changed these in System Settings meanwhile.
            loginItem.refresh()
            isTrusted = AutoPaster.isTrusted
        }
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = settings.memeFolder
        panel.prompt = String(localized: "Use Folder")
        panel.message = String(localized: "Choose the folder with your memes")
        if panel.runModal() == .OK, let url = panel.url {
            settings.memeFolder = url
        }
    }
}
