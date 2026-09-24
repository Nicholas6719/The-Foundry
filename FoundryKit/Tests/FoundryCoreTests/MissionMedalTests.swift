import Testing
@testable import FoundryCore

@Suite("Mission line")
struct MissionTests {
    @Test func namesAndLastArrow() {
        let input = MissionInput(targetsDueToday: 2, habitsTotal: 4, habitsLeft: 1, focusDoneToday: true)
        #expect(MissionRules.line(input) == "Strike two names. Fire one last arrow.")
    }

    @Test func allParts() {
        let input = MissionInput(targetsDueToday: 2, habitsTotal: 4, habitsLeft: 1,
                                 workoutScheduledAndNotDone: true, focusDoneToday: false)
        #expect(MissionRules.line(input) == "Strike two names. Fire one last arrow. Climb the ladder. Hold the Island.")
    }

    @Test func allDoneIsBullseye() {
        let input = MissionInput(targetsDueToday: 0, habitsTotal: 3, habitsLeft: 0,
                                 workoutScheduledAndNotDone: false, focusDoneToday: true)
        #expect(MissionRules.line(input) == "Bullseye. Hold the line.")
    }

    @Test func nothingConfiguredWins() {
        #expect(MissionRules.line(MissionInput(nothingConfigured: true)) == "Write your first name.")
        let busy = MissionInput(targetsDueToday: 3, habitsLeft: 2, workoutScheduledAndNotDone: true, nothingConfigured: true)
        #expect(MissionRules.line(busy) == "Write your first name.")
    }

    @Test func singleTarget() {
        let input = MissionInput(targetsDueToday: 1, focusDoneToday: true)
        #expect(MissionRules.line(input) == "Strike one name.")
    }

    @Test func threeHabits() {
        let input = MissionInput(habitsTotal: 5, habitsLeft: 3, focusDoneToday: true)
        #expect(MissionRules.line(input) == "Fire three arrows.")
    }

    @Test func climbTheLadderAlone() {
        let input = MissionInput(workoutScheduledAndNotDone: true, focusDoneToday: true)
        #expect(MissionRules.line(input) == "Climb the ladder.")
    }

    @Test func holdTheIslandAlone() {
        #expect(MissionRules.line(MissionInput(focusDoneToday: false)) == "Hold the Island.")
    }

    @Test func singleTargetAndThreeHabits() {
        let input = MissionInput(targetsDueToday: 1, habitsTotal: 3, habitsLeft: 3, focusDoneToday: true)
        #expect(MissionRules.line(input) == "Strike one name. Fire three arrows.")
    }

    @Test func largeCountsUseDigits() {
        let input = MissionInput(targetsDueToday: 12, focusDoneToday: true)
        #expect(MissionRules.line(input) == "Strike 12 names.")
        #expect(MissionRules.spelled(10) == "ten")
        #expect(MissionRules.spelled(11) == "11")
    }
}

@Suite("Medals")
struct MedalTests {
    let keys = Fixture.keys

    private func earned(_ stats: MedalStats) -> Set<MedalID> { MedalRules.earned(stats, keys: keys) }

    private func run(_ count: Int, endingOn end: String = "2026-09-24") -> [String] {
        keys.trailing(count, endingOn: end)
    }

    @Test func nothingEarnedFromEmptyStats() {
        #expect(earned(MedalStats()).isEmpty)
    }

    // First bullseye
    @Test func firstBullseye() {
        #expect(earned(MedalStats(bullseyeDays: ["2026-09-24"])) == [.firstBullseye])
        #expect(!earned(MedalStats(bullseyeDays: [])).contains(.firstBullseye))
    }

    // Seven straight
    @Test func sevenStraightAtSevenDayRun() {
        #expect(earned(MedalStats(bullseyeDays: Set(run(7)))) == [.firstBullseye, .sevenStraight])
        #expect(!earned(MedalStats(bullseyeDays: Set(run(6)))).contains(.sevenStraight))
    }

    @Test func sevenStraightNeedsConsecutiveDays() {
        // Seven bullseyes with a gap: 3 + 4.
        let days = Set(run(3, endingOn: "2026-09-10") + run(4, endingOn: "2026-09-24"))
        #expect(days.count == 7)
        #expect(!earned(MedalStats(bullseyeDays: days)).contains(.sevenStraight))
    }

    @Test func sevenStraightAcrossDST() {
        #expect(earned(MedalStats(bullseyeDays: Set(run(7, endingOn: "2026-03-11")))).contains(.sevenStraight))
    }

    // Rung four
    @Test func rungFour() {
        #expect(earned(MedalStats(highestRung: 4)) == [.rungFour])
        #expect(earned(MedalStats(highestRung: 9)) == [.rungFour])
        #expect(earned(MedalStats(highestRung: 3)).isEmpty)
    }

    // Iron sleeper
    @Test func ironSleeperAtFiveConsecutiveNights() {
        let nights = Dictionary(uniqueKeysWithValues: run(5).map { ($0, 480) })
        #expect(earned(MedalStats(sleepByDay: nights, sleepGoalMinutes: 480)) == [.ironSleeper])
    }

    @Test func ironSleeperNotAtFourNights() {
        let nights = Dictionary(uniqueKeysWithValues: run(4).map { ($0, 500) })
        #expect(earned(MedalStats(sleepByDay: nights, sleepGoalMinutes: 480)).isEmpty)
    }

    @Test func ironSleeperBrokenByNightBelowGoal() {
        var nights = Dictionary(uniqueKeysWithValues: run(5).map { ($0, 480) })
        nights["2026-09-22"] = 479
        #expect(earned(MedalStats(sleepByDay: nights, sleepGoalMinutes: 480)).isEmpty)
    }

    @Test func ironSleeperBrokenByMissingNight() {
        let nights = Dictionary(uniqueKeysWithValues: (run(2, endingOn: "2026-09-20") + run(3)).map { ($0, 480) })
        #expect(nights.count == 5)
        #expect(earned(MedalStats(sleepByDay: nights, sleepGoalMinutes: 480)).isEmpty)
    }

    // Deep focus
    @Test func deepFocusAtFourSessionsInOneDay() {
        #expect(earned(MedalStats(focusSessionsByDay: ["2026-09-24": 4])) == [.deepFocus])
        #expect(earned(MedalStats(focusSessionsByDay: ["2026-09-24": 3])).isEmpty)
    }

    @Test func deepFocusNeedsSameDay() {
        let spread = ["2026-09-23": 3, "2026-09-24": 3]
        #expect(earned(MedalStats(focusSessionsByDay: spread)).isEmpty)
    }

    // Ten struck
    @Test func tenStruck() {
        #expect(earned(MedalStats(namesStruck: 10)) == [.tenStruck])
        #expect(earned(MedalStats(namesStruck: 25)) == [.tenStruck])
        #expect(earned(MedalStats(namesStruck: 9)).isEmpty)
    }

    @Test func everythingAtOnce() {
        let stats = MedalStats(
            bullseyeDays: Set(run(7)),
            highestRung: 4,
            sleepByDay: Dictionary(uniqueKeysWithValues: run(5).map { ($0, 420) }),
            sleepGoalMinutes: 420,
            focusSessionsByDay: ["2026-09-24": 4],
            namesStruck: 10
        )
        #expect(earned(stats) == Set(MedalID.allCases))
    }

    @Test func titlesAndRulesExist() {
        for medal in MedalID.allCases {
            #expect(!medal.title.isEmpty)
            #expect(!medal.rule.isEmpty)
        }
    }
}
