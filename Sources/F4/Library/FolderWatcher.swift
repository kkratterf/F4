import Foundation

/// Calls `onChange` when files are added to, removed from or renamed in a folder.
///
/// Uses a `DispatchSource` on the folder's file descriptor (opened with
/// `O_EVTONLY`, so it never blocks the volume from unmounting). Bursts of events,
/// like a Finder copy of twenty GIFs, are coalesced into one call after `delay`.
/// If the folder itself is deleted or renamed, the watcher reopens the path.
final class FolderWatcher {
    private let url: URL
    private let delay: TimeInterval
    private let onChange: @Sendable () -> Void
    private let queue = DispatchQueue(label: "F4.FolderWatcher", qos: .utility)
    private var source: DispatchSourceFileSystemObject?
    private var pending: DispatchWorkItem?

    init(url: URL, delay: TimeInterval = 0.3, onChange: @escaping @Sendable () -> Void) {
        self.url = url
        self.delay = delay
        self.onChange = onChange
    }

    deinit {
        source?.cancel()
    }

    /// Starts watching. Returns false when the folder cannot be opened.
    @discardableResult
    func start() -> Bool {
        queue.sync { open() }
    }

    /// False after the folder disappeared and could not be reopened.
    var isWatching: Bool {
        queue.sync { source != nil }
    }

    func stop() {
        queue.sync {
            pending?.cancel()
            source?.cancel()
            source = nil
        }
    }

    // Runs on `queue`.
    private func open() -> Bool {
        source?.cancel()
        source = nil
        let descriptor = Darwin.open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return false }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .extend, .attrib, .link],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let events = source.data
            if events.contains(.delete) || events.contains(.rename) {
                // The folder itself moved away: watch whatever is at the path now.
                _ = self.open()
            }
            self.schedule()
        }
        source.setCancelHandler {
            close(descriptor)
        }
        self.source = source
        source.resume()
        return true
    }

    // Runs on `queue`.
    private func schedule() {
        pending?.cancel()
        let onChange = onChange
        let item = DispatchWorkItem { onChange() }
        pending = item
        queue.asyncAfter(deadline: .now() + delay, execute: item)
    }
}
