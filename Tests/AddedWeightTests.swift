import Testing

@testable import Blocklog

@MainActor
struct AddedWeightTests {
    @Test func addedWeightStepsBetweenBodyweightAndTheTable() {
        #expect(AddedWeight.label(for: nil) == "BW")
        #expect(AddedWeight.label(for: 10) == "+10 lb")
        #expect(AddedWeight.next(after: nil) == 5)
        #expect(AddedWeight.next(after: 5) == 7.5)
        #expect(AddedWeight.next(after: 90) == nil)
        #expect(AddedWeight.previous(before: 7.5) == 5)
    }

    @Test func decreasingFromTheLowestSettingGivesBodyweight() {
        #expect(AddedWeight.previous(before: 5) == nil)
        #expect(AddedWeight.canDecrease(from: 5))
        #expect(AddedWeight.previous(before: nil) == nil)
        #expect(!AddedWeight.canDecrease(from: nil))
    }

    @Test func menuOffersBodyweightThenEveryPowerBlockSetting() {
        #expect(AddedWeight.options == [nil] + PowerBlockTable.weights.map { Optional($0) })
        #expect(AddedWeight.options.count == 28)
    }
}
