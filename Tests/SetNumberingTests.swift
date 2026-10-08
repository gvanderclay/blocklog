import Testing

@testable import Blocklog

@MainActor
struct SetNumberingTests {
    @Test func warmUpsDoNotAdvanceTheCount() {
        let types: [SetType] = [.warmUp, .warmUp, .normal, .drop, .failure]
        #expect(SetNumbering.labels(for: types) == ["W", "W", "1", "D", "F"])
        #expect(SetNumbering.countedNumbers(for: types) == [nil, nil, 1, 2, 3])
    }

    @Test func everyTypeButWarmUpIsCounted() {
        #expect(!SetNumbering.isCounted(.warmUp))
        for type in [SetType.normal, .drop, .failure] {
            #expect(SetNumbering.isCounted(type))
        }
    }
}
