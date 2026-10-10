import Foundation
import SwiftData
import Testing

@testable import Blocklog

/// Checks the bundled exercise animations against the starter exercises seeded into an in-memory store, and the
/// clip's play, pause and Reduce Motion rules.
@MainActor
struct ExerciseAnimationTests {
    let container: ModelContainer

    init() throws {
        container = try BlocklogApp.makeContainer(inMemory: true)
    }

    private func starter(_ name: String) throws -> Exercise {
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == name })
        return try #require(try container.mainContext.fetch(descriptor).first)
    }

    @Test func everyAnimationNamesAStarterExercise() throws {
        let animations = try ExerciseAnimation.load()
        #expect(!animations.isEmpty)
        let starters = try container.mainContext.fetch(FetchDescriptor<Exercise>())
        for animation in animations {
            let match = starters.first { $0.name == animation.exercise }
            #expect(match != nil, "\(animation.exercise) isn't a starter exercise")
            if let match {
                #expect(ExerciseAnimation.animation(for: match)?.clip == animation.clip)
            }
        }
    }

    @Test func everyAnimationHasItsClipAndStillAndOneSentence() throws {
        for animation in try ExerciseAnimation.load() {
            #expect(FileManager.default.fileExists(atPath: animation.clip.path))
            #expect(FileManager.default.fileExists(atPath: animation.still.path))
            let description = animation.description
            #expect(description.hasSuffix("."), "\(animation.exercise)")
            // One sentence: no sentence ends before the last character.
            let ends = description.dropLast().filter { ".!?".contains($0) }
            #expect(ends.isEmpty, "\(animation.exercise): \(description)")
            #expect(description.count > 20)
        }
    }

    @Test func everyBundledClipBelongsToAnAnimation() throws {
        let clips = Set(try ExerciseAnimation.load().map(\.clip.lastPathComponent))
        let bundled = Bundle.main.urls(forResourcesWithExtension: "mov", subdirectory: nil) ?? []
        #expect(!bundled.isEmpty)
        for url in bundled {
            #expect(
                clips.contains(url.lastPathComponent), "\(url.lastPathComponent) has no animation")
        }
    }

    @Test func gobletSquatHasAnAnimationMatchedIgnoringCase() throws {
        let animation = try #require(
            ExerciseAnimation.animation(for: try starter("Dumbbell Goblet Squat")))
        #expect(animation.clip.lastPathComponent == "dumbbell-goblet-squat.mov")
        #expect(animation.still.lastPathComponent == "dumbbell-goblet-squat.png")
        let renamed = Exercise(
            name: " dumbbell GOBLET squat", muscleGroup: .quads, equipment: .dumbbell,
            type: .weightReps)
        #expect(ExerciseAnimation.animation(for: renamed)?.clip == animation.clip)
    }

    @Test(arguments: ["Dumbbell Goblet Squat", "Dumbbell Bench Press", "Plank"])
    func theTrialExercisesHaveAnimations(name: String) throws {
        let animation = try #require(ExerciseAnimation.animation(for: try starter(name)))
        #expect(animation.exercise == name)
    }

    @Test func aCustomExerciseHasNone() throws {
        let catalog = ExerciseCatalog(context: container.mainContext)
        let custom = try #require(
            try catalog.createCustomExercise(
                named: "Goblet Squat Hold", muscleGroup: .quads, equipment: .dumbbell,
                type: .duration))
        #expect(ExerciseAnimation.animation(for: custom) == nil)
        let sameName = Exercise(
            name: "Dumbbell Goblet Squat", muscleGroup: .quads, equipment: .dumbbell,
            type: .weightReps,
            isCustom: true)
        #expect(ExerciseAnimation.animation(for: sameName) == nil)
    }

    @Test func playsAtOnceOnceTheFirstFrameIsReady() {
        var playback = ExerciseAnimation.Playback(reduceMotion: false)
        #expect(playback.isPlaying && playback.runs)
        #expect(playback.showsStill)
        playback.frameBecameReady()
        #expect(!playback.showsStill)
        playback.toggle()
        #expect(!playback.isPlaying && !playback.runs)
        #expect(!playback.showsStill, "a paused clip shows its current frame")
        playback.toggle()
        #expect(playback.isPlaying)
    }

    @Test func underReduceMotionShowsTheStillUntilTapped() {
        var playback = ExerciseAnimation.Playback(reduceMotion: true)
        playback.frameBecameReady()
        #expect(!playback.isPlaying && !playback.runs)
        #expect(playback.showsStill)
        playback.toggle()
        #expect(playback.isPlaying && playback.runs)
        #expect(!playback.showsStill)
        playback.toggle()
        #expect(!playback.isPlaying)
    }

    @Test func turningOnReduceMotionPausesAndReturnsToTheStill() {
        var playback = ExerciseAnimation.Playback(reduceMotion: false)
        playback.frameBecameReady()
        playback.reduceMotionChanged(to: true)
        #expect(!playback.isPlaying && playback.showsStill)
        playback.reduceMotionChanged(to: false)
        #expect(!playback.isPlaying, "turning it off doesn't start the clip")
    }

    @Test func pausesWhileTheAppIsInactive() {
        var playback = ExerciseAnimation.Playback(reduceMotion: false)
        playback.sceneChanged(isActive: false)
        #expect(playback.isPlaying && !playback.runs)
        playback.sceneChanged(isActive: true)
        #expect(playback.runs)
    }
}
