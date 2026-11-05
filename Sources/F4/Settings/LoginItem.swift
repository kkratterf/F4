import Foundation
import ServiceManagement

/// Starts F4 when the user logs in, with `SMAppService.mainApp`.
///
/// F4 always opens at login: it registers itself once, on the first launch
/// of a real app bundle. macOS tells the user with a notification, and the
/// user can still turn it off in System Settings → General → Login Items,
/// which F4 then respects (it never registers again).
enum LoginItem {
    private static let didRegisterKey = "didRegisterLoginItem"

    @MainActor
    static func enableOnFirstLaunch(defaults: UserDefaults = .standard) {
        guard Bundle.main.bundleURL.pathExtension == "app",
              !defaults.bool(forKey: didRegisterKey) else { return }
        defaults.set(true, forKey: didRegisterKey)
        guard SMAppService.mainApp.status != .enabled else { return }
        do {
            try SMAppService.mainApp.register()
        } catch {
            NSLog("F4: could not add F4 to the login items: %@", error.localizedDescription)
        }
    }
}
