import Foundation
@testable import FoundryCore

/// Machine-independent calendar fixtures: Gregorian, America/New_York, Monday-first.
enum Fixture {
    static let timeZone = TimeZone(identifier: "America/New_York")!

    static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        cal.locale = Locale(identifier: "en_US_POSIX")
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        return cal
    }()

    static let keys = DayKeys(calendar: calendar)

    /// A local (New York) wall-clock date.
    static func date(_ year: Int, _ month: Int, _ day: Int,
                     _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0) -> Date {
        let comps = DateComponents(year: year, month: month, day: day,
                                   hour: hour, minute: minute, second: second)
        return calendar.date(from: comps)!
    }

    /// An absolute instant from an ISO-8601 string with offset (e.g. `2026-09-25T03:59:59Z`).
    static func instant(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: iso)!
    }
}
