import Foundation

/// Hvor ting ligger på disken. Alt brugerdata ligger i Documents, så det kan ses i Filer-appen
/// og kommer med i iCloud-backup.
enum FileLocations {
    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Tegninger lagt ind af brugeren + deres manifest.
    static var userAssets: URL { documents.appendingPathComponent("Tegninger", isDirectory: true) }
    static var userManifest: URL { userAssets.appendingPathComponent("manifest.json") }

    /// Spillets gemte tilstand.
    static var saveGame: URL { documents.appendingPathComponent("spil.json") }

    /// Rå fotos der er importeret, så man kan køre dem igennem igen med en bedre model senere.
    static var importedPhotos: URL { documents.appendingPathComponent("Fotos", isDirectory: true) }

    /// Mappen i app-bundlet med de tegninger der følger med spillet.
    static var bundledAssets: URL? {
        Bundle.main.url(forResource: "BuiltIn", withExtension: nil)
    }

    static var bundledManifest: URL? {
        bundledAssets?.appendingPathComponent("manifest.json")
    }

    static var bundledStyleSeed: URL? {
        Bundle.main.url(forResource: "StyleSeed", withExtension: "json", subdirectory: "Style")
    }

    static func ensureDirectories() throws {
        for url in [userAssets, importedPhotos] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
