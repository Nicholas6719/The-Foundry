import Testing
@testable import FoundryCore

@Suite("XP ledger and math")
struct XPTests {
    private func entry(_ kind: XPKind = .bullseye, _ ref: String, day: String = "2026-09-24",
                       base: Int = 50, multiplier: Double = 1.0) -> XPEntry {
        XPEntry(kind: kind, refKey: ref, dayKey: day, base: base, multiplier: multiplier)
    }

    // MARK: Idempotency

    @Test func awardingSameKindAndRefTwiceCountsOnce() {
        var ledger = XPLedger()
        let r1 = ledger.award(entry(.bullseye, "2026-09-24"))
        #expect(r1)
        let r2 = ledger.award(entry(.bullseye, "2026-09-24"))
        #expect(!r2)
        #expect(ledger.entries.count == 1)
        #expect(ledger.total == 50)
    }

    @Test func duplicateAwardKeepsOriginalEntry() {
        var ledger = XPLedger()
        ledger.award(entry(.strike, "target-1", base: 30))
        ledger.award(entry(.strike, "target-1", base: 999))
        #expect(ledger.total == 30)
    }

    @Test func sameRefKeyDifferentKindsAreDistinct() {
        var ledger = XPLedger()
        let r3 = ledger.award(entry(.bullseye, "x", base: 50))
        #expect(r3)
        let r4 = ledger.award(entry(.strike, "x", base: 30))
        #expect(r4)
        #expect(ledger.total == 80)
        #expect(ledger.contains(.bullseye, refKey: "x"))
        #expect(ledger.contains(.strike, refKey: "x"))
        #expect(!ledger.contains(.focus, refKey: "x"))
    }

    @Test func initDeduplicatesEntries() {
        let ledger = XPLedger(entries: [entry(.strike, "a", base: 30), entry(.strike, "a", base: 30)])
        #expect(ledger.entries.count == 1)
        #expect(ledger.total == 30)
    }

    // MARK: Reversal

    @Test func revokeRemovesEntryAndTotalDrops() {
        var ledger = XPLedger()
        ledger.award(entry(.bullseye, "2026-09-24", base: 50))
        ledger.award(entry(.strike, "target-1", base: 30))
        #expect(ledger.total == 80)

        let r5 = ledger.revoke(.strike, refKey: "target-1")
        #expect(r5)
        #expect(ledger.total == 50)
        #expect(!ledger.contains(.strike, refKey: "target-1"))
    }

    @Test func revokeMissingEntryIsNoOp() {
        var ledger = XPLedger()
        ledger.award(entry(.bullseye, "d", base: 50))
        let r6 = ledger.revoke(.strike, refKey: "d")
        #expect(!r6)
        let r7 = ledger.revoke(.bullseye, refKey: "other")
        #expect(!r7)
        #expect(ledger.total == 50)
    }

    @Test func revokeThenReawardCountsAgain() {
        var ledger = XPLedger()
        ledger.award(entry(.strike, "t", base: 30))
        ledger.revoke(.strike, refKey: "t")
        #expect(ledger.total == 0)
        let r8 = ledger.award(entry(.strike, "t", base: 30))
        #expect(r8)
        #expect(ledger.total == 30)
    }

    // MARK: Multiplier

    @Test func setMultiplierRecomputesOnlyThatDay() {
        var ledger = XPLedger()
        ledger.award(entry(.bullseye, "2026-09-24", day: "2026-09-24", base: 50))
        ledger.award(entry(.strike, "t1", day: "2026-09-24", base: 30))
        ledger.award(entry(.strike, "t2", day: "2026-09-23", base: 30))
        #expect(ledger.total == 110)

        ledger.setMultiplier(1.2, forDay: "2026-09-24")
        #expect(ledger.total(onDay: "2026-09-24") == 60 + 36)
        #expect(ledger.total(onDay: "2026-09-23") == 30)
        #expect(ledger.total == 126)

        ledger.setMultiplier(1.0, forDay: "2026-09-24")
        #expect(ledger.total(onDay: "2026-09-24") == 80)
        #expect(ledger.total == 110)
    }

    @Test func setMultiplierOnEmptyDayChangesNothing() {
        var ledger = XPLedger()
        ledger.award(entry(.strike, "t", day: "2026-09-24", base: 30))
        ledger.setMultiplier(1.2, forDay: "2026-01-01")
        #expect(ledger.total == 30)
        #expect(ledger.total(onDay: "2026-01-01") == 0)
    }

    // MARK: Floor per event

    @Test(arguments: [(50, 1.2, 60), (8, 1.2, 9), (30, 1.2, 36), (20, 1.2, 24), (15, 1.2, 18),
                      (100, 1.2, 120), (7, 1.0, 7), (0, 1.2, 0)])
    func totalIsBaseTimesMultiplierFloored(base: Int, multiplier: Double, expected: Int) {
        #expect(XPMath.total(base: base, multiplier: multiplier) == expected)
        #expect(XPEntry(kind: .focus, refKey: "r", dayKey: "d", base: base, multiplier: multiplier).total == expected)
    }

    @Test func floorAppliesPerEventNotToTheSum() {
        var ledger = XPLedger()
        ledger.award(entry(.focus, "s1", base: 8, multiplier: 1.2))
        ledger.award(entry(.focus, "s2", base: 8, multiplier: 1.2))
        // 9 + 9, not floor(9.6 + 9.6) = 19.
        #expect(ledger.total == 18)
    }

    // MARK: Focus XP

    @Test(arguments: [(25, 8), (60, 20), (45, 15), (15, 5), (90, 30)])
    func focusXPForCompletedSessions(minutes: Int, expected: Int) {
        #expect(XPMath.focusXP(minutes: minutes, completed: true) == expected)
    }

    @Test(arguments: [15, 25, 45, 60])
    func abandonedSessionsEarnNothing(minutes: Int) {
        #expect(XPMath.focusXP(minutes: minutes, completed: false) == 0)
    }

    @Test func zeroMinuteSessionEarnsNothing() {
        #expect(XPMath.focusXP(minutes: 0, completed: true) == 0)
    }
}
