import AppKit
import SwiftUI

/// Shows the current shortcut and records a new one: click, then press the keys.
///
/// While recording, a local key monitor swallows the next key press. Esc
/// cancels; a press without ⌘, ⌥ or ⌃ is ignored, since it would steal typing,
/// unless it is a function key such as F4.
struct ShortcutRecorder: View {
    @Binding var combo: HotKeyCombo
    let defaultCombo: HotKeyCombo

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Button(action: toggleRecording) {
                Group {
                    if isRecording {
                        Text("Press the shortcut…")
                    } else {
                        Text(verbatim: combo.displayString)
                    }
                }
                .frame(minWidth: 140)
            }
            .help(isRecording ? LocalizedStringKey("Esc to cancel") : LocalizedStringKey("Click to record a new shortcut"))
            Button("Reset") { combo = defaultCombo }
                .disabled(combo == defaultCombo || isRecording)
        }
        .onDisappear(perform: stopRecording)
    }

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if Int(event.keyCode) == 53 { // Esc
                stopRecording()
                return nil
            }
            if let recorded = HotKeyCombo(event: event) {
                combo = recorded
                stopRecording()
            }
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }
}
