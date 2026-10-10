import SwiftData
import Testing

@testable import Blocklog

/// Checks the bundled stretch cues against the starter exercises and the stretch routines.
@MainActor
struct StretchCueTests {
    @Test func theCuesLoadAndNameOnlyStretchesWithEveryStretchCovered() throws {
        let cues = try StretchCue.load()
        let container = try BlocklogApp.makeContainer(inMemory: true)
        let stretches = Set(
            try container.mainContext.fetch(FetchDescriptor<Exercise>())
                .filter { $0.muscleGroup == .stretching }.map(\.name))

        #expect(Set(cues.keys) == stretches)
        for (name, cue) in cues {
            #expect(!cue.cue.isEmpty && cue.cue.count < 120, "\(name)'s cue")
            #expect(!cue.easier.isEmpty, "\(name)'s easier variation")
            #expect(!cue.harder.isEmpty, "\(name)'s harder variation")
        }
        let routineStretches = StarterRoutine.stretching(in: try StarterRoutine.load())
            .flatMap(\.exercises).map(\.exercise)
        #expect(Set(routineStretches) == stretches)
        #expect(StretchCue.bundled == cues)
    }
}
