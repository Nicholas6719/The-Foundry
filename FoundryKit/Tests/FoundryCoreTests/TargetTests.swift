import Foundation
import Testing
@testable import FoundryCore

@Suite("Due tags")
struct DueTagTests {
    let keys = Fixture.keys
    /// Thursday 2026-09-24, 10:00 New York.
    let now = Fixture.date(2026, 9, 24, 10)

    private func tag(_ due: Date) -> DueTag { DueTagRules.tag(due: due, now: now, keys: keys) }

    @Test func sameDayIsToday() {
        for hour in [0, 9, 10, 23] {
            let t = tag(Fixture.date(2026, 9, 24, hour))
            #expect(t == DueTag(text: "TODAY", isOverdue: false, isToday: true))
        }
        #expect(tag(Fixture.date(2026, 9, 24, 23, 59, 59)).text == "TODAY")
    }

    @Test(arguments: [
        (25, "FRI"), (26, "SAT"), (27, "SUN"), (28, "MON"), (29, "TUE"), (30, "WED"),
    ])
    func weekdayWithinNextSixDays(day: Int, text: String) {
        let t = tag(Fixture.date(2026, 9, day, 8))
        #expect(t == DueTag(text: text, isOverdue: false, isToday: false))
    }

    @Test func tomorrowJustAfterMidnightIsWeekday() {
        #expect(tag(Fixture.date(2026, 9, 25, 0, 0, 0)).text == "FRI")
    }

    @Test func sevenDaysOutIsMonthDay() {
        let t = tag(Fixture.date(2026, 10, 1, 9))
        #expect(t == DueTag(text: "OCT 1", isOverdue: false, isToday: false))
    }

    @Test func farFutureIsUppercasedMonthDay() {
        #expect(tag(Fixture.date(2026, 10, 3)).text == "OCT 3")
        #expect(tag(Fixture.date(2026, 12, 25)).text == "DEC 25")
        #expect(!tag(Fixture.date(2026, 10, 3)).isOverdue)
    }

    @Test func overdueIsFlagged() {
        let yesterday = tag(Fixture.date(2026, 9, 23, 23, 59, 59))
        #expect(yesterday == DueTag(text: "SEP 23", isOverdue: true, isToday: false))
        let old = tag(Fixture.date(2026, 8, 3))
        #expect(old == DueTag(text: "AUG 3", isOverdue: true, isToday: false))
    }

    @Test func weekdayAcrossDST() {
        // Now: Saturday 2026-10-31. Due Tuesday 2026-11-03, across fall-back.
        let t = DueTagRules.tag(due: Fixture.date(2026, 11, 3, 9), now: Fixture.date(2026, 10, 31, 22), keys: keys)
        #expect(t.text == "TUE")
    }
}

@Suite("Target ordering")
struct TargetOrderingTests {
    let keys = Fixture.keys
    let now = Fixture.date(2026, 9, 24, 10)

    private func t(_ id: String, created: Int, due: Date? = nil, primary: Bool = false, struck: Date? = nil) -> TargetSnapshot {
        TargetSnapshot(id: id, createdAt: Fixture.date(2026, 9, created), dueDate: due, isPrimary: primary, struckAt: struck)
    }

    @Test func fullOrdering() {
        let targets = [
            t("undatedNew", created: 20),
            t("struckOld", created: 1, struck: Fixture.date(2026, 9, 10)),
            t("dueLater", created: 1, due: Fixture.date(2026, 9, 30)),
            t("undatedOld", created: 5),
            t("primary", created: 22, due: Fixture.date(2026, 10, 20), primary: true),
            t("struckNew", created: 2, struck: Fixture.date(2026, 9, 23)),
            t("dueSoon", created: 15, due: Fixture.date(2026, 9, 25)),
            t("overdue", created: 3, due: Fixture.date(2026, 9, 20)),
        ]
        let order = TargetOrdering.sorted(targets).map(\.id)
        #expect(order == ["primary", "overdue", "dueSoon", "dueLater", "undatedOld", "undatedNew", "struckNew", "struckOld"])
    }

    @Test func sameDueDateFallsBackToCreatedAt() {
        let due = Fixture.date(2026, 9, 26)
        let targets = [t("b", created: 10, due: due), t("a", created: 2, due: due), t("c", created: 12, due: due)]
        #expect(TargetOrdering.sorted(targets).map(\.id) == ["a", "b", "c"])
    }

    @Test func primaryFirstEvenWithoutDueDate() {
        let targets = [t("dated", created: 1, due: Fixture.date(2026, 9, 20)), t("primary", created: 20, primary: true)]
        #expect(TargetOrdering.sorted(targets).map(\.id) == ["primary", "dated"])
    }

    @Test func struckPrimaryGoesToStruckSection() {
        let targets = [
            t("struckPrimary", created: 1, primary: true, struck: Fixture.date(2026, 9, 24)),
            t("open", created: 2),
        ]
        #expect(TargetOrdering.sorted(targets).map(\.id) == ["open", "struckPrimary"])
    }

    @Test func struckMostRecentFirst() {
        let targets = [
            t("s1", created: 1, struck: Fixture.date(2026, 9, 1)),
            t("s3", created: 1, struck: Fixture.date(2026, 9, 3)),
            t("s2", created: 1, struck: Fixture.date(2026, 9, 2)),
        ]
        #expect(TargetOrdering.sorted(targets).map(\.id) == ["s3", "s2", "s1"])
    }

    @Test func emptyList() {
        #expect(TargetOrdering.sorted([]).isEmpty)
        #expect(TargetOrdering.dueTodayOrOverdue([], now: now, keys: keys) == 0)
    }

    @Test func dueTodayOrOverdueCount() {
        let targets = [
            t("overdue", created: 1, due: Fixture.date(2026, 9, 20)),
            t("todayEarly", created: 1, due: Fixture.date(2026, 9, 24, 0)),
            t("todayLate", created: 1, due: Fixture.date(2026, 9, 24, 23, 59)),
            t("tomorrow", created: 1, due: Fixture.date(2026, 9, 25, 0)),
            t("undated", created: 1),
            t("struckOverdue", created: 1, due: Fixture.date(2026, 9, 20), struck: Fixture.date(2026, 9, 21)),
            t("primaryToday", created: 1, due: Fixture.date(2026, 9, 24, 12), primary: true),
        ]
        #expect(TargetOrdering.dueTodayOrOverdue(targets, now: now, keys: keys) == 4)
        // Mission line counts only today's: early, late and primary; not overdue, tomorrow or struck.
        #expect(TargetOrdering.dueToday(targets, now: now, keys: keys) == 3)
    }
}
