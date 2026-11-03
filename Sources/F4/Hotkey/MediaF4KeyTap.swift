import AppKit
import ApplicationServices
import Combine
import F4Core

/// Lets the F4 key alone open the panel on a Mac keyboard, where it is
/// Spotlight or Launchpad unless fn is held (see `MediaF4Key`).
///
/// Optional and off by default: an event tap that can swallow key presses
/// needs the Accessibility permission. The tap only acts on the media F4 key
/// and passes every other event through untouched. Without the permission,
/// or while macOS has not granted it yet, the Carbon hot key still answers
/// fn F4, so the shortcut keeps working either way.
@MainActor
final class MediaF4KeyTap: ObservableObject {
    static let shared = MediaF4KeyTap()

    /// True while the tap runs, so F4 alone opens the panel.
    @Published private(set) var isRunning = false

    /// Called on the main thread for each press of the media F4 key.
    var onPress: (() -> Void)?

    private var source: CFRunLoopSource?
    /// macOS posts nothing when the user grants Accessibility, so while the
    /// tap is wanted but not allowed, F4 checks again every couple of seconds.
    private var permissionTimer: Timer?
    private var isWanted = false

    private init() {}

    /// Starts or stops the tap. Started without the permission, it waits for it.
    func setWanted(_ wanted: Bool) {
        isWanted = wanted
        if wanted {
            if !startTap() { waitForPermission() }
        } else {
            permissionTimer?.invalidate()
            permissionTimer = nil
            stopTap()
        }
    }

    fileprivate func handlePress() {
        onPress?()
    }

    /// Called when macOS turned the tap off (it was too slow, or the
    /// permission went away): turn it back on, or wait for the permission.
    fileprivate func tapWasDisabled() {
        guard isWanted, let port = mediaF4TapPort else { return }
        if AXIsProcessTrusted() {
            CGEvent.tapEnable(tap: port, enable: true)
        } else {
            stopTap()
            waitForPermission()
        }
    }

    private func startTap() -> Bool {
        if mediaF4TapPort != nil { return true }
        guard AXIsProcessTrusted() else { return false }
        let systemDefined: CGEventMask = 14 // NX_SYSDEFINED: media keys
        let mask: CGEventMask = (1 << CGEventMask(CGEventType.keyDown.rawValue))
            | (1 << CGEventMask(CGEventType.keyUp.rawValue))
            | (1 << systemDefined)
        // At the HID level, so the press is caught before macOS opens Spotlight.
        guard let port = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: mediaF4TapCallback,
            userInfo: nil
        ) else { return false }
        mediaF4TapPort = port
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        self.source = source
        CGEvent.tapEnable(tap: port, enable: true)
        permissionTimer?.invalidate()
        permissionTimer = nil
        isRunning = true
        return true
    }

    private func stopTap() {
        if let port = mediaF4TapPort {
            CGEvent.tapEnable(tap: port, enable: false)
            CFMachPortInvalidate(port)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        mediaF4TapPort = nil
        source = nil
        isRunning = false
    }

    private func waitForPermission() {
        guard permissionTimer == nil else { return }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            Task { @MainActor in
                let tap = MediaF4KeyTap.shared
                if tap.isWanted { _ = tap.startTap() }
            }
        }
    }
}

/// The tap's mach port. A global, because the C callback cannot capture context.
private var mediaF4TapPort: CFMachPort?

/// Swallows the media F4 key (down and up) and toggles the panel on the
/// press; everything else goes on unchanged. Runs on the main run loop and
/// must stay fast, or macOS disables the tap.
private func mediaF4TapCallback(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    _ event: CGEvent,
    _ userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    let passThrough = Unmanaged.passUnretained(event)
    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        Task { @MainActor in MediaF4KeyTap.shared.tapWasDisabled() }
        return passThrough
    case .keyDown, .keyUp:
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let modifiers: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
        guard MediaF4Key.isMediaF4(keyCode: keyCode), event.flags.intersection(modifiers).isEmpty else {
            return passThrough
        }
        if type == .keyDown, event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
            Task { @MainActor in MediaF4KeyTap.shared.handlePress() }
        }
        return nil
    default:
        guard type.rawValue == 14,
              let nsEvent = NSEvent(cgEvent: event),
              Int(nsEvent.subtype.rawValue) == MediaF4Key.mediaKeySubtype
        else { return passThrough }
        let press = MediaF4Key.MediaKeyPress(data1: nsEvent.data1)
        guard press.key == MediaF4Key.launchpadMediaKey else { return passThrough }
        if press.isDown, !press.isRepeat {
            Task { @MainActor in MediaF4KeyTap.shared.handlePress() }
        }
        return nil
    }
}
