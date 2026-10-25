import CoreServices
import Foundation

/// Calls `onChange` when files are added to, removed from or renamed in a
/// folder or any of its subfolders.
///
/// Uses an FSEvents stream, which watches the whole tree and coalesces bursts
/// of events, like a Finder copy of twenty GIFs, into one call after
/// `latency`. It follows the path, so a folder that is deleted and created
/// again keeps being watched.
final class FolderWatcher {
    private let url: URL
    private let latency: TimeInterval
    private let onChange: @Sendable () -> Void
    private let queue = DispatchQueue(label: "F4.FolderWatcher", qos: .utility)
    private var stream: FSEventStreamRef?

    init(url: URL, latency: TimeInterval = 0.3, onChange: @escaping @Sendable () -> Void) {
        self.url = url
        self.latency = latency
        self.onChange = onChange
    }

    deinit {
        stop()
    }

    /// Starts watching. Returns false when macOS refuses the stream.
    @discardableResult
    func start() -> Bool {
        guard stream == nil else { return true }
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue().onChange()
        }
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [url.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagWatchRoot)
        ) else { return false }
        FSEventStreamSetDispatchQueue(stream, queue)
        guard FSEventStreamStart(stream) else {
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            return false
        }
        self.stream = stream
        return true
    }

    var isWatching: Bool { stream != nil }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }
}
