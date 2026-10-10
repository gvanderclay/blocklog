import Foundation

/// A starter exercise's bundled looping clip, its still for Reduce Motion and its one-sentence description for
/// VoiceOver, read from `exercise-animations.json`, which `scripts/animations/manifest.py` generates.
@MainActor
struct ExerciseAnimation {
    /// The starter exercise's name, as in `starter-exercises.json`.
    let exercise: String
    let clip: URL
    let still: URL
    let description: String

    /// One manifest entry: the bundled files are `<file>.mov` and `<file>.png`.
    private struct Entry: Decodable {
        let exercise: String
        let file: String
        let description: String
    }

    /// The animations in `exercise-animations.json`, or none when it can't be read or a file is missing (a unit
    /// test checks that it can).
    static let bundled: [ExerciseAnimation] = (try? load()) ?? []

    /// Reads `exercise-animations.json` from the app bundle; throws when it or any entry's clip or still is missing.
    static func load() throws -> [ExerciseAnimation] {
        guard let url = Bundle.main.url(forResource: "exercise-animations", withExtension: "json")
        else {
            throw CocoaError(.fileNoSuchFile)
        }
        let entries = try JSONDecoder().decode([Entry].self, from: Data(contentsOf: url))
        return try entries.map { entry in
            guard let clip = Bundle.main.url(forResource: entry.file, withExtension: "mov"),
                let still = Bundle.main.url(forResource: entry.file, withExtension: "png")
            else {
                throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: entry.file])
            }
            return ExerciseAnimation(
                exercise: entry.exercise, clip: clip, still: still, description: entry.description)
        }
    }

    /// The exercise's animation, matched by name ignoring case, or nil. A custom exercise has none.
    static func animation(for exercise: Exercise) -> ExerciseAnimation? {
        guard !exercise.isCustom else { return nil }
        let key = ExerciseCatalog.normalized(exercise.name).key
        return bundled.first { ExerciseCatalog.normalized($0.exercise).key == key }
    }

    /// Whether the clip plays and whether its still covers it. Without Reduce Motion the clip starts playing at
    /// once; with it, the still shows and nothing plays until a tap. A tap toggles play and pause, and turning
    /// Reduce Motion on pauses the clip and returns to the still. The still also covers the clip until its
    /// first frame is ready, and the clip pauses while the app isn't active.
    struct Playback {
        /// What VoiceOver reads as the clip's value: "Playing" or "Paused".
        private(set) var isPlaying: Bool
        private var hasStarted: Bool
        private var isFrameReady = false
        private var isSceneActive = true

        init(reduceMotion: Bool) {
            isPlaying = !reduceMotion
            hasStarted = !reduceMotion
        }

        var showsStill: Bool { !hasStarted || !isFrameReady }

        /// Whether the player should be running now.
        var runs: Bool { isPlaying && isSceneActive }

        mutating func toggle() {
            isPlaying.toggle()
            if isPlaying { hasStarted = true }
        }

        mutating func frameBecameReady() { isFrameReady = true }

        mutating func reduceMotionChanged(to isOn: Bool) {
            guard isOn else { return }
            isPlaying = false
            hasStarted = false
        }

        mutating func sceneChanged(isActive: Bool) { isSceneActive = isActive }
    }
}
