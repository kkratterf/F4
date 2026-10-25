import Foundation
import ServiceManagement

/// Starts F4 when the user logs in, with `SMAppService.mainApp`.
///
/// The state lives in macOS (System Settings → General → Login Items), not in
/// our defaults, so the toggle always reads it back from the system.
@MainActor
final class LoginItem: ObservableObject {
    @Published private(set) var isEnabled = false
    /// Set when macOS refused the change, or wants the user to approve it.
    @Published private(set) var message: String?

    init() {
        refresh()
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        message = status == .requiresApproval
            ? "Allow F4 in System Settings → General → Login Items."
            : nil
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refresh()
        } catch {
            refresh()
            message = error.localizedDescription
        }
    }
}
