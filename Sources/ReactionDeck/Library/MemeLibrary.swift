import Foundation
import ReactionDeckCore

/// The memes the panel shows, read from the meme folder in the background.
@MainActor
final class MemeLibrary: ObservableObject {
    @Published private(set) var memes: [Meme] = []
    /// Set when the folder cannot be read.
    @Published private(set) var error: String?

    let folder: URL
    private var scanTask: Task<Void, Never>?

    init(folder: URL = MemeScanner.defaultFolder) {
        self.folder = folder
    }

    /// Rescans the folder off the main thread and publishes the result.
    /// Creates the folder on first launch, so the user has a place to drop memes.
    func reload() {
        scanTask?.cancel()
        let folder = folder
        scanTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) { () -> Result<[Meme], Error> in
                Result {
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    return try MemeScanner.scan(folder: folder)
                }
            }.value
            guard !Task.isCancelled, let self else { return }
            switch result {
            case .success(let memes):
                self.memes = memes
                self.error = nil
            case .failure(let error):
                self.memes = []
                self.error = error.localizedDescription
            }
        }
    }
}
