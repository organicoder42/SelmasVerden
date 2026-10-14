import Foundation

/// Gemmer SaveGame til disk med en lille forsinkelse, så hurtige træk-og-slip-ændringer ikke skriver
/// hundredvis af gange i sekundet.
@MainActor
final class SaveStore {
    private var pendingTask: Task<Void, Never>?
    private let url: URL

    init(url: URL = FileLocations.saveGame) {
        self.url = url
    }

    func load() -> SaveGame {
        JSONStore.loadIfExists(SaveGame.self, from: url) ?? .empty
    }

    func scheduleSave(_ game: SaveGame, delay: Duration = .milliseconds(600)) {
        pendingTask?.cancel()
        let snapshot = game
        let target = url
        pendingTask = Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            do {
                try JSONStore.save(snapshot, to: target)
            } catch {
                print("Kunne ikke gemme spillet: \(error)")
            }
        }
    }

    func saveNow(_ game: SaveGame) {
        pendingTask?.cancel()
        try? JSONStore.save(game, to: url)
    }
}
