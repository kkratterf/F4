import AppKit
import F4Core
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
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
                Text("F4 shows the GIF, PNG and JPEG files in this folder and updates when you add or remove one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
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
        panel.prompt = "Use Folder"
        panel.message = "Choose the folder with your memes"
        if panel.runModal() == .OK, let url = panel.url {
            settings.memeFolder = url
        }
    }
}
