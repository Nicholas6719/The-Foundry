import Foundation
import Testing
@testable import FoundryCore

@Suite("Day keys")
struct DayKeyTests {
    let keys = Fixture.keys

    // MARK: Midnight

    @Test func midnightBoundary() {
        // 23:59:59 EDT on the 24th and 00:00:00 EDT on the 25th.
        #expect(keys.key(for: Fixture.instant("2026-09-25T03:59:59Z")) == "2026-09-24")
        #expect(keys.key(for: Fixture.instant("2026-09-25T04:00:00Z")) == "2026-09-25")
        #expect(keys.key(for: Fixture.date(2026, 9, 24, 23, 59, 59)) == "2026-09-24")
        #expect(keys.key(for: Fixture.date(2026, 9, 25, 0, 0, 0)) == "2026-09-25")
    }

    @Test func yearBoundary() {
        #expect(keys.key(for: Fixture.date(2026, 12, 31, 23, 59, 59)) == "2026-12-31")
        #expect(keys.key(for: Fixture.date(2027, 1, 1)) == "2027-01-01")
        #expect(keys.adding(1, to: "2026-12-31") == "2027-01-01")
    }

    @Test func dateForKeyIsLocalStartOfDay() {
        #expect(keys.date(for: "2026-09-24") == Fixture.instant("2026-09-24T04:00:00Z"))
        #expect(keys.date(for: "2026-12-01") == Fixture.instant("2026-12-01T05:00:00Z"))
    }

    @Test func malformedKey() {
        #expect(keys.date(for: "2026-09") == nil)
        #expect(keys.date(for: "garbage") == nil)
        #expect(keys.adding(3, to: "garbage") == "garbage")
        #expect(keys.days(from: "garbage", to: "2026-09-24") == 0)
    }

    @Test func keyRoundTrips() {
        for key in ["2026-01-01", "2026-03-08", "2026-11-01", "2028-02-29"] {
            #expect(keys.key(for: keys.date(for: key)!) == key)
        }
    }

    // MARK: DST spring forward (2026-03-08, 02:00 → 03:00)

    @Test func springForwardDayIs23Hours() {
        let start = keys.date(for: "2026-03-08")!
        let next = keys.date(for: "2026-03-09")!
        #expect(next.timeIntervalSince(start) == 23 * 3600)
    }

    @Test func springForwardKeys() {
        #expect(keys.key(for: Fixture.instant("2026-03-08T05:00:00Z")) == "2026-03-08") // 00:00 EST
        #expect(keys.key(for: Fixture.instant("2026-03-08T07:30:00Z")) == "2026-03-08") // 03:30 EDT
        #expect(keys.key(for: Fixture.instant("2026-03-09T03:59:59Z")) == "2026-03-08") // 23:59:59 EDT
        #expect(keys.key(for: Fixture.instant("2026-03-09T04:00:00Z")) == "2026-03-09")
    }

    @Test func addingAcrossSpringForward() {
        #expect(keys.adding(1, to: "2026-03-07") == "2026-03-08")
        #expect(keys.adding(1, to: "2026-03-08") == "2026-03-09")
        #expect(keys.adding(2, to: "2026-03-07") == "2026-03-09")
        #expect(keys.adding(-1, to: "2026-03-09") == "2026-03-08")
        #expect(keys.adding(-2, to: "2026-03-09") == "2026-03-07")
    }

    @Test func daysAcrossSpringForward() {
        #expect(keys.days(from: "2026-03-07", to: "2026-03-09") == 2)
        #expect(keys.days(from: "2026-03-08", to: "2026-03-09") == 1)
        #expect(keys.days(from: "2026-03-01", to: "2026-03-15") == 14)
    }

    // MARK: DST fall back (2026-11-01, 02:00 → 01:00)

    @Test func fallBackDayIs25Hours() {
        let start = keys.date(for: "2026-11-01")!
        let next = keys.date(for: "2026-11-02")!
        #expect(next.timeIntervalSince(start) == 25 * 3600)
    }

    @Test func fallBackKeys() {
        // 01:30 happens twice; both belong to Nov 1.
        #expect(keys.key(for: Fixture.instant("2026-11-01T05:30:00Z")) == "2026-11-01") // 01:30 EDT
        #expect(keys.key(for: Fixture.instant("2026-11-01T06:30:00Z")) == "2026-11-01") // 01:30 EST
        #expect(keys.key(for: Fixture.instant("2026-11-02T04:59:59Z")) == "2026-11-01") // 23:59:59 EST
        #expect(keys.key(for: Fixture.instant("2026-11-02T05:00:00Z")) == "2026-11-02")
    }

    @Test func addingAcrossFallBack() {
        #expect(keys.adding(1, to: "2026-10-31") == "2026-11-01")
        #expect(keys.adding(1, to: "2026-11-01") == "2026-11-02")
        #expect(keys.adding(2, to: "2026-10-31") == "2026-11-02")
        #expect(keys.adding(-1, to: "2026-11-02") == "2026-11-01")
        #expect(keys.adding(-7, to: "2026-11-05") == "2026-10-29")
    }

    @Test func daysAcrossFallBack() {
        #expect(keys.days(from: "2026-10-31", to: "2026-11-02") == 2)
        #expect(keys.days(from: "2026-11-01", to: "2026-11-02") == 1)
        #expect(keys.days(from: "2026-11-02", to: "2026-10-31") == -2)
    }

    @Test func daysSpanningBothTransitions() {
        #expect(keys.days(from: "2026-03-01", to: "2026-11-30") == 274)
        #expect(keys.days(from: "2026-09-24", to: "2026-09-24") == 0)
        #expect(keys.days(from: "2026-09-24", to: "2026-09-20") == -4)
    }

    // MARK: Weekdays

    @Test(arguments: [
        ("2026-09-21", 0), ("2026-09-22", 1), ("2026-09-23", 2), ("2026-09-24", 3),
        ("2026-09-25", 4), ("2026-09-26", 5), ("2026-09-27", 6),
        ("2026-03-08", 6), ("2026-11-01", 6), ("2026-11-02", 0),
    ])
    func weekdayIndexMondayIsZero(key: String, index: Int) {
        #expect(keys.weekdayIndex(for: key) == index)
        #expect(keys.weekdayIndex(for: keys.date(for: key)!) == index)
    }

    @Test func weekdayIndexIgnoresCalendarFirstWeekday() {
        var sundayFirst = Fixture.calendar
        sundayFirst.firstWeekday = 1
        let k = DayKeys(calendar: sundayFirst)
        #expect(k.weekdayIndex(for: "2026-09-21") == 0)
        #expect(k.weekdayIndex(for: "2026-09-27") == 6)
    }

    @Test func weekContainingIsMondayThroughSunday() {
        let expected = ["2026-09-21", "2026-09-22", "2026-09-23", "2026-09-24",
                        "2026-09-25", "2026-09-26", "2026-09-27"]
        #expect(keys.week(containing: "2026-09-24") == expected)
        #expect(keys.week(containing: "2026-09-21") == expected)
        #expect(keys.week(containing: "2026-09-27") == expected)
    }

    @Test func weekContainingDSTDays() {
        #expect(keys.week(containing: "2026-03-08") ==
                ["2026-03-02", "2026-03-03", "2026-03-04", "2026-03-05", "2026-03-06", "2026-03-07", "2026-03-08"])
        #expect(keys.week(containing: "2026-11-01") ==
                ["2026-10-26", "2026-10-27", "2026-10-28", "2026-10-29", "2026-10-30", "2026-10-31", "2026-11-01"])
    }

    @Test func trailingDays() {
        #expect(keys.trailing(3, endingOn: "2026-03-09") == ["2026-03-07", "2026-03-08", "2026-03-09"])
        #expect(keys.trailing(0, endingOn: "2026-03-09").isEmpty)
    }

    @Test func weekdayMask() {
        let mask: WeekdayMask = [.day(0), .day(2), .day(6)]
        #expect(mask.dayIndices == [0, 2, 6])
        #expect(mask.contains(dayIndex: 2))
        #expect(!mask.contains(dayIndex: 1))
        #expect(WeekdayMask.all.dayIndices == Array(0...6))
    }
}
