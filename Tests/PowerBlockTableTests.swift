import Testing

@testable import Blocklog

/// Checks the PowerBlock table through its public interface.
@MainActor
struct PowerBlockTableTests {
    @Test func listsExactlyTheTwentySevenSettingsInOrder() {
        #expect(
            PowerBlockTable.weights == [
                5, 7.5, 10, 15, 17.5, 20, 25, 27.5, 30, 35, 37.5, 40, 45, 47.5, 50,
                55, 57.5, 60, 65, 67.5, 70, 75, 77.5, 80, 85, 87.5, 90,
            ])
    }

    @Test func stepsUpAcrossTheGaps() {
        #expect(PowerBlockTable.next(after: 5) == 7.5)
        #expect(PowerBlockTable.next(after: 7.5) == 10)
        #expect(PowerBlockTable.next(after: 10) == 15)
        #expect(PowerBlockTable.next(after: 20) == 25)
        #expect(PowerBlockTable.next(after: 87.5) == 90)
        #expect(PowerBlockTable.next(after: 12.5) == 15)
    }

    @Test func stepsDownAcrossTheGaps() {
        #expect(PowerBlockTable.previous(before: 15) == 10)
        #expect(PowerBlockTable.previous(before: 12.5) == 10)
    }

    @Test func hasNoNextAboveNinetyAndNoPreviousBelowFive() {
        #expect(PowerBlockTable.next(after: 90) == nil)
        #expect(PowerBlockTable.previous(before: 5) == nil)
    }

    @Test func setupLineForEveryWeight() {
        let lines: [(weight: Double, line: String)] = [
            (5, "Handle only · no adders"),
            (7.5, "Handle only · 1 adder"),
            (10, "Handle only · 2 adders"),
            (15, "Pin first slot · no adders"),
            (17.5, "Pin first slot · 1 adder"),
            (20, "Pin first slot · 2 adders"),
            (25, "Pin 30 · no adders"),
            (27.5, "Pin 30 · 1 adder"),
            (30, "Pin 30 · 2 adders"),
            (35, "Pin 40 · no adders"),
            (37.5, "Pin 40 · 1 adder"),
            (40, "Pin 40 · 2 adders"),
            (45, "Pin 50 · no adders"),
            (47.5, "Pin 50 · 1 adder"),
            (50, "Pin 50 · 2 adders"),
            (55, "Pin 60 · no adders"),
            (57.5, "Pin 60 · 1 adder"),
            (60, "Pin 60 · 2 adders"),
            (65, "Pin 70 · no adders"),
            (67.5, "Pin 70 · 1 adder"),
            (70, "Pin 70 · 2 adders"),
            (75, "Pin 80 · no adders"),
            (77.5, "Pin 80 · 1 adder"),
            (80, "Pin 80 · 2 adders"),
            (85, "Pin 90 · no adders"),
            (87.5, "Pin 90 · 1 adder"),
            (90, "Pin 90 · 2 adders"),
        ]
        #expect(lines.map(\.weight) == PowerBlockTable.weights)
        for (weight, line) in lines {
            #expect(PowerBlockTable.setup(for: weight)?.line == line, "\(weight) lb")
        }
    }

    @Test func setupLineOfASetFollowsItsWeight() {
        #expect(PowerBlockTable.setupLine(for: 27.5) == "Pin 30 · 1 adder")
        #expect(
            PowerBlockTable.setupLine(for: PowerBlockTable.stepUp(from: 27.5))
                == "Pin 30 · 2 adders")
    }

    @Test func bodyweightAndDurationSetsHaveNoSetupLine() {
        // Both kinds store no weight: "BW" is nil, and a duration set has none.
        #expect(PowerBlockTable.setupLine(for: nil) == nil)
        #expect(PowerBlockTable.setupLine(for: 12.5) == nil)
    }

    @Test func noSetupForAWeightThatIsNotASetting() {
        #expect(PowerBlockTable.setup(for: 12.5) == nil)
    }

    @Test func changeLineBetweenSlotsNamesTheNewSlot() {
        #expect(PowerBlockTable.changeLine(from: 27.5, to: 37.5) == "Pin 30 → 40")
        #expect(PowerBlockTable.changeLine(from: 17.5, to: 27.5) == "Pin first slot → 30")
    }

    @Test func changeLineAddsOrRemovesAdders() {
        #expect(PowerBlockTable.changeLine(from: 30, to: 37.5) == "Pin 30 → 40 · remove 1 adder")
        #expect(PowerBlockTable.changeLine(from: 25, to: 30) == "Add 2 adders")
        #expect(PowerBlockTable.changeLine(from: 27.5, to: 25) == "Remove 1 adder")
    }

    @Test func changeLineFromAndToTheHandle() {
        #expect(
            PowerBlockTable.changeLine(from: 10, to: 15)
                == "Handle only → pin first slot · remove 2 adders")
        #expect(
            PowerBlockTable.changeLine(from: 5, to: 30) == "Handle only → pin 30 · add 2 adders")
        #expect(
            PowerBlockTable.changeLine(from: 30, to: 7.5) == "Pin 30 → handle only · remove 1 adder"
        )
    }

    @Test func noChangeLineForEqualWeights() {
        #expect(PowerBlockTable.changeLine(from: 27.5, to: 27.5) == nil)
    }

    @Test func weightedStepsStopAtTheEndsAndNeedAWeight() {
        #expect(PowerBlockTable.stepUp(from: 5) == 7.5)
        #expect(PowerBlockTable.stepUp(from: 90) == nil)
        #expect(PowerBlockTable.stepUp(from: nil) == nil)
        #expect(PowerBlockTable.stepDown(from: 10) == 7.5)
        #expect(PowerBlockTable.stepDown(from: 5) == nil)
        #expect(PowerBlockTable.stepDown(from: nil) == nil)
    }
}
