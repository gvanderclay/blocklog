import Foundation

/// A stretch's one-line instruction and its Easier and Harder variations, from `stretch-cues.json`, keyed by
/// exercise name. Read-only; nothing of it is stored.
@MainActor
struct StretchCue: Decodable, Equatable {
    let cue: String
    let easier: String
    let harder: String

    /// The cues by exercise name, or none when the file can't be read (a unit test checks that it can).
    static let bundled: [String: StretchCue] = (try? load()) ?? [:]

    /// Reads `stretch-cues.json` from the app bundle.
    static func load() throws -> [String: StretchCue] {
        guard let url = Bundle.main.url(forResource: "stretch-cues", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode([String: StretchCue].self, from: Data(contentsOf: url))
    }
}
