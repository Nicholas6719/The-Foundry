import Testing
@testable import FoundryCore

@Suite("Recovery")
struct RecoveryTests {
    /// Reference implementation of the spec formula.
    private func reference(deep: Int, core: Int, rem: Int, awake: Int, goal: Int) -> Int {
        let asleep = Double(deep + core + rem)
        let a = 0.65 * min(asleep / Double(goal), 1)
        let b = 0.25 * min(1, Double(deep + rem) / (0.40 * asleep))
        let c = 0.10 * (1 - min(Double(awake) / 60, 1))
        return Int((100 * (a + b + c)).rounded())
    }

    @Test func perfectNightIs100() {
        let s = SleepSummary(deep: 90, core: 288, rem: 102, awake: 0)
        #expect(RecoveryRules.score(s, goalMinutes: 480) == 100)
    }

    @Test func workedExample() {
        // 0.65·(360/480) + 0.25·(120/144) + 0.10·(1 − 30/60) = 0.4875 + 0.2083 + 0.05 → 74.58 → 75
        let s = SleepSummary(deep: 60, core: 240, rem: 60, awake: 30)
        #expect(RecoveryRules.score(s, goalMinutes: 480) == 75)
    }

    @Test func componentsAreCapped() {
        // Sleep over goal, stages over 40%, awake over 60: each component caps.
        let s = SleepSummary(deep: 200, core: 100, rem: 300, awake: 500)
        #expect(RecoveryRules.score(s, goalMinutes: 480) == 90)
    }

    @Test func noDeepOrRem() {
        // 0.65·(420/420) + 0 + 0.10 → 75
        let s = SleepSummary(deep: 0, core: 420, rem: 0, awake: 0)
        #expect(RecoveryRules.score(s, goalMinutes: 420) == 75)
    }

    @Test(arguments: [
        (60, 200, 70, 15, 480), (30, 300, 40, 45, 420), (100, 100, 100, 0, 600),
        (10, 50, 5, 90, 480), (80, 280, 90, 5, 450),
    ])
    func matchesSpecFormula(deep: Int, core: Int, rem: Int, awake: Int, goal: Int) {
        let s = SleepSummary(deep: deep, core: core, rem: rem, awake: awake)
        #expect(RecoveryRules.score(s, goalMinutes: goal) == reference(deep: deep, core: core, rem: rem, awake: awake, goal: goal))
    }

    @Test func nilWhenNoSleep() {
        #expect(RecoveryRules.score(SleepSummary(), goalMinutes: 480) == nil)
        #expect(RecoveryRules.score(SleepSummary(awake: 45), goalMinutes: 480) == nil)
    }

    @Test func thresholdScoresFromFormula() {
        // 0.65·(360/520) = 0.45; + 0.25 + 0.10 → 80
        let eighty = SleepSummary(deep: 80, core: 210, rem: 70, awake: 0)
        #expect(RecoveryRules.score(eighty, goalMinutes: 520) == 80)
        // 0.65·(352/520) = 0.44; + 0.25 + 0.10 → 79
        let seventyNine = SleepSummary(deep: 80, core: 202, rem: 70, awake: 0)
        #expect(RecoveryRules.score(seventyNine, goalMinutes: 520) == 79)
    }

    @Test func multiplier() {
        #expect(RecoveryRules.multiplier(for: 80) == 1.2)
        #expect(RecoveryRules.multiplier(for: 100) == 1.2)
        #expect(RecoveryRules.multiplier(for: 79) == 1.0)
        #expect(RecoveryRules.multiplier(for: 0) == 1.0)
        #expect(RecoveryRules.multiplier(for: nil) == 1.0)
    }

    @Test func summaryAsleepExcludesAwake() {
        let s = SleepSummary(deep: 1, core: 2, rem: 3, awake: 4)
        #expect(s.asleep == 6)
        #expect(!s.isEmpty)
        #expect(SleepSummary().isEmpty)
    }
}

@Suite("Ladder")
struct LadderTests {
    private func sets(_ reps: [Int], target: Int = 5, weight: Double = 135) -> [SetResult] {
        reps.enumerated().map { SetResult(setIndex: $0.offset, repsDone: $0.element, targetReps: target, weightLb: weight) }
    }

    @Test(arguments: [(1, 135.0), (2, 140.0), (4, 150.0), (10, 180.0)])
    func weightForRung(rung: Int, expected: Double) {
        #expect(LadderRules.weight(rung: rung, start: 135, step: 5) == expected)
    }

    @Test func weightWithFractionalStep() {
        #expect(LadderRules.weight(rung: 3, start: 45, step: 2.5) == 50)
    }

    @Test func outcomeInProgressUntilEverySetLogged() {
        #expect(LadderRules.outcome(sets: [], prescribedSets: 3) == .inProgress)
        #expect(LadderRules.outcome(sets: sets([5, 5]), prescribedSets: 3) == .inProgress)
        #expect(LadderRules.outcome(sets: sets([2, 1]), prescribedSets: 3) == .inProgress)
    }

    @Test func outcomeClimbedWhenAllSetsHitTarget() {
        #expect(LadderRules.outcome(sets: sets([5, 5, 5]), prescribedSets: 3) == .climbed)
        #expect(LadderRules.outcome(sets: sets([6, 5, 7]), prescribedSets: 3) == .climbed)
    }

    @Test func outcomeHeldWhenAnySetMissed() {
        #expect(LadderRules.outcome(sets: sets([5, 5, 4]), prescribedSets: 3) == .held)
        #expect(LadderRules.outcome(sets: sets([0, 0, 0]), prescribedSets: 3) == .held)
    }

    @Test func duplicateSetIndexKeepsLastLog() {
        var logged = sets([5, 5, 3])
        logged.append(SetResult(setIndex: 2, repsDone: 5, targetReps: 5, weightLb: 135))
        #expect(LadderRules.outcome(sets: logged, prescribedSets: 3) == .climbed)
    }

    @Test func nextRungClimbsOnlyOnClimbed() {
        #expect(LadderRules.nextRung(current: 3, outcome: .climbed) == 4)
        #expect(LadderRules.nextRung(current: 3, outcome: .held) == 3)
        #expect(LadderRules.nextRung(current: 3, outcome: .inProgress) == 3)
    }

    @Test func nextRungNeverDrops() {
        for outcome in [LadderOutcome.inProgress, .climbed, .held] {
            #expect(LadderRules.nextRung(current: 7, outcome: outcome) >= 7)
        }
    }

    @Test func isRecord() {
        #expect(LadderRules.isRecord(weight: 135, previousCompletedWeights: []))
        #expect(!LadderRules.isRecord(weight: 150, previousCompletedWeights: [135, 150, 145]))
        #expect(LadderRules.isRecord(weight: 155, previousCompletedWeights: [135, 150, 145]))
        #expect(!LadderRules.isRecord(weight: 140, previousCompletedWeights: [135, 150]))
    }

    @Test(arguments: [(135.0, 1), (140.0, 2), (150.0, 4), (152.0, 4), (153.0, 5), (100.0, 1)])
    func rungForWeight(weight: Double, expected: Int) {
        #expect(LadderRules.rung(forWeight: weight, start: 135, step: 5) == expected)
    }

    @Test func rungForWeightRoundTripsWeight() {
        for rung in 1...20 {
            let w = LadderRules.weight(rung: rung, start: 45, step: 2.5)
            #expect(LadderRules.rung(forWeight: w, start: 45, step: 2.5) == rung)
        }
    }

    @Test func rungForWeightWithZeroStepIsOne() {
        #expect(LadderRules.rung(forWeight: 200, start: 135, step: 0) == 1)
    }

    @Test func formatWeight() {
        #expect(LadderRules.format(155) == "155")
        #expect(LadderRules.format(152.5) == "152.5")
    }
}
