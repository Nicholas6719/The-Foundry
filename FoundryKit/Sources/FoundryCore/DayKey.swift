import Foundation

/// Local-calendar day identifiers in `yyyy-MM-dd` form.
///
/// Built from calendar components (never from a fixed 86,400 s offset), so
/// DST changes and midnight boundaries land on the right day.
public struct DayKeys: Sendable {
    public var calendar: Calendar

    public init(calendar: Calendar = DayKeys.defaultCalendar) {
        self.calendar = calendar
    }

    /// Gregorian, current time zone, Monday-start weeks.
    public static var defaultCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        cal.locale = Locale(identifier: "en_US_POSIX")
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        return cal
    }

    public func key(for date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Start of the day a key names, or nil when the key is malformed.
    public func date(for key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let comps = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        guard let date = calendar.date(from: comps) else { return nil }
        return calendar.startOfDay(for: date)
    }

    public func adding(_ days: Int, to key: String) -> String {
        guard let date = date(for: key),
              let moved = calendar.date(byAdding: .day, value: days, to: date) else { return key }
        return self.key(for: moved)
    }

    /// Whole days from `a` to `b` (positive when `b` is later).
    public func days(from a: String, to b: String) -> Int {
        guard let da = date(for: a), let db = date(for: b) else { return 0 }
        return calendar.dateComponents([.day], from: da, to: db).day ?? 0
    }

    /// 0 = Monday ... 6 = Sunday.
    public func weekdayIndex(for date: Date) -> Int {
        let weekday = calendar.component(.weekday, from: date) // 1 = Sunday
        return (weekday + 5) % 7
    }

    public func weekdayIndex(for key: String) -> Int {
        guard let date = date(for: key) else { return 0 }
        return weekdayIndex(for: date)
    }

    /// The seven keys (Monday through Sunday) of the week containing `key`.
    public func week(containing key: String) -> [String] {
        let monday = adding(-weekdayIndex(for: key), to: key)
        return (0..<7).map { adding($0, to: monday) }
    }

    /// Keys for the `count` days ending on `key`, oldest first.
    public func trailing(_ count: Int, endingOn key: String) -> [String] {
        (0..<count).reversed().map { adding(-$0, to: key) }
    }

    public static let weekdayLetters = ["M", "T", "W", "T", "F", "S", "S"]
    public static let weekdayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
}

/// A seven-bit weekday set; bit 0 = Monday ... bit 6 = Sunday.
public struct WeekdayMask: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static func day(_ index: Int) -> WeekdayMask { WeekdayMask(rawValue: 1 << index) }
    public static let all = WeekdayMask(rawValue: 0b111_1111)

    public func contains(dayIndex: Int) -> Bool { contains(.day(dayIndex)) }

    public var dayIndices: [Int] { (0..<7).filter { contains(dayIndex: $0) } }
}
