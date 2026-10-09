import Foundation

/// A routine's place in a programme: the programme and the routine's position in it, from 0. Read once from a
/// routine's stored fields (`Routine.membership`) and written back through the same property, so the programme
/// and the position are present together or not at all. A routine with no membership is in My Routines.
@MainActor
struct ProgrammeMembership {
    let programme: Programme
    let position: Int

    /// Whether the positions of one programme's routines are 0…n−1, each once. Import checks a programme with it.
    static func areValid(_ positions: [Int]) -> Bool {
        positions.sorted() == Array(positions.indices)
    }
}

@MainActor
extension Routine {
    /// The routine's programme and position; nil when either stored field is missing. Setting it writes both,
    /// and nil clears both. The caller saves and keeps the programme's positions 0…n−1.
    var membership: ProgrammeMembership? {
        get {
            guard let programme, let programmePosition else { return nil }
            return ProgrammeMembership(programme: programme, position: programmePosition)
        }
        set {
            programme = newValue?.programme
            programmePosition = newValue?.position
        }
    }
}
