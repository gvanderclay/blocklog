import Foundation

/// A routine's place in a program: the program and the routine's position in it, from 0. Read once from a
/// routine's stored fields (`Routine.membership`) and written back through the same property, so the program
/// and the position are present together or not at all. A routine with no membership is in My Routines.
@MainActor
struct ProgramMembership {
    let program: Program
    let position: Int

    /// Whether the positions of one program's routines are 0…n−1, each once. Import checks a program with it.
    static func areValid(_ positions: [Int]) -> Bool {
        positions.sorted() == Array(positions.indices)
    }
}

@MainActor
extension Routine {
    /// The routine's program and position; nil when either stored field is missing. Setting it writes both,
    /// and nil clears both. The caller saves and keeps the program's positions 0…n−1.
    var membership: ProgramMembership? {
        get {
            guard let program, let programPosition else { return nil }
            return ProgramMembership(program: program, position: programPosition)
        }
        set {
            program = newValue?.program
            programPosition = newValue?.position
        }
    }
}
