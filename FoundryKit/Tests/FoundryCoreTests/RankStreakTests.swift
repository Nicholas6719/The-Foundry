import Testing
@testable import FoundryCore

@Suite("Ranks")
struct RankTests {
    @Test func thresholds() {
        #expect(Rank.castaway.threshold == 0)
        #expect(Rank.vigilante.threshold == 500)
        #expect(Rank.hood.threshold == 2000)
        #expect(Rank.greenArrow.threshold == 5000)
    }

    @Test(arguments: [
        (0, Rank.castaway), (499, .castaway),
        (500, .vigilante), (1999, .vigilante),
        (2000, .hood), (4999, .hood),
        (5000, .greenArrow), (100_000, .greenArrow),
    ])
    func rankForXPAtBoundaries(xp: Int, rank: Rank) {
        #expect(Rank.forXP(xp) == rank)
    }

    @Test func negativeXPIsCastaway() {
        #expect(Rank.forXP(-10) == .castaway)
        #expect(RankProgress(xp: -10).rank == .castaway)
        #expect(RankProgress(xp: -10).fraction == 0)
    }

    @Test func progressMidBand() {
        let p = RankProgress(xp: 1240)
        #expect(p.rank == .vigilante)
        #expect(p.nextThreshold == 2000)
        #expect(abs(p.fraction - Double(1240 - 500) / 1500) < 1e-12)
    }

    @Test func progressAtBandStartIsZero() {
        let p = RankProgress(xp: 500)
        #expect(p.rank == .vigilante)
        #expect(p.fraction == 0)
        #expect(RankProgress(xp: 0).fraction == 0)
        #expect(RankProgress(xp: 0).nextThreshold == 500)
    }

    @Test func progressJustBelowNextRank() {
        let p = RankProgress(xp: 4999)
        #expect(p.rank == .hood)
        #expect(p.nextThreshold == 5000)
        #expect(abs(p.fraction - 2999.0 / 3000) < 1e-12)
    }

    @Test(arguments: [5000, 9999])
    func topRankFractionIsOne(xp: Int) {
        let p = RankProgress(xp: xp)
        #expect(p.rank == .greenArrow)
        #expect(p.nextThreshold == nil)
        #expect(p.fraction == 1)
    }

    @Test func ordering() {
        #expect(Rank.castaway < .vigilante)
        #expect(Rank.hood < .greenArrow)
        #expect(Rank.greenArrow.next == nil)
        #expect(Rank.castaway.next == .vigilante)
    }
}

@Suite("Streaks")
struct StreakTests {
    let keys = Fixture.keys

    @Test func emptyIsZero() {
        #expect(StreakRules.current(bullseyeDays: [], today: "2026-09-24", keys: keys) == 0)
        #expect(StreakRules.longestRun([], keys: keys) == 0)
    }

    @Test func todayBullseyeCountsToday() {
        let days: Set = ["2026-09-22", "2026-09-23", "2026-09-24"]
        #expect(StreakRules.current(bullseyeDays: days, today: "2026-09-24", keys: keys) == 3)
    }

    @Test func todayInProgressEndsAtYesterday() {
        let days: Set = ["2026-09-21", "2026-09-22", "2026-09-23"]
        #expect(StreakRules.current(bullseyeDays: days, today: "2026-09-24", keys: keys) == 3)
    }

    @Test func missingYesterdayBreaksStreak() {
        let days: Set = ["2026-09-20", "2026-09-21", "2026-09-22"]
        #expect(StreakRules.current(bullseyeDays: days, today: "2026-09-24", keys: keys) == 0)
    }

    @Test func gapsBreakTheRun() {
        let days: Set = ["2026-09-18", "2026-09-19", "2026-09-20", "2026-09-22", "2026-09-23", "2026-09-24"]
        #expect(StreakRules.current(bullseyeDays: days, today: "2026-09-24", keys: keys) == 3)
        #expect(StreakRules.current(bullseyeDays: days, today: "2026-09-21", keys: keys) == 3)
    }

    @Test func onlyTodayIsOne() {
        #expect(StreakRules.current(bullseyeDays: ["2026-09-24"], today: "2026-09-24", keys: keys) == 1)
    }

    @Test func futureDaysDoNotCount() {
        #expect(StreakRules.current(bullseyeDays: ["2026-09-25"], today: "2026-09-24", keys: keys) == 0)
    }

    @Test func streakCrossesMonthAndDST() {
        let days: Set = ["2026-03-06", "2026-03-07", "2026-03-08", "2026-03-09"]
        #expect(StreakRules.current(bullseyeDays: days, today: "2026-03-09", keys: keys) == 4)
        let fall: Set = ["2026-10-30", "2026-10-31", "2026-11-01", "2026-11-02"]
        #expect(StreakRules.current(bullseyeDays: fall, today: "2026-11-02", keys: keys) == 4)
    }

    @Test func longestRunFindsBestRun() {
        let days: Set = ["2026-09-01", "2026-09-02",
                         "2026-09-10", "2026-09-11", "2026-09-12", "2026-09-13",
                         "2026-09-20"]
        #expect(StreakRules.longestRun(days, keys: keys) == 4)
        #expect(StreakRules.longestRun(["2026-09-24"], keys: keys) == 1)
    }

    @Test func longestRunAcrossMonthBoundary() {
        let days: Set = ["2026-09-29", "2026-09-30", "2026-10-01", "2026-10-02"]
        #expect(StreakRules.longestRun(days, keys: keys) == 4)
    }

    @Test func isBullseye() {
        #expect(StreakRules.isBullseye(total: 3, done: 3))
        #expect(!StreakRules.isBullseye(total: 3, done: 2))
        #expect(!StreakRules.isBullseye(total: 0, done: 0))
    }
}
