import Foundation

public struct DueTag: Sendable, Equatable {
    public var text: String
    public var isOverdue: Bool
    public var isToday: Bool
}

public enum DueTagRules {
    /// `TODAY`; a weekday (`FRI`) within the next 6 days; else `MMM d` (`OCT 3`). Overdue is flagged.
    public static func tag(due: Date, now: Date, keys: DayKeys = DayKeys()) -> DueTag {
        let todayKey = keys.key(for: now)
        let dueKey = keys.key(for: due)
        let delta = keys.days(from: todayKey, to: dueKey)
        if delta == 0 { return DueTag(text: "TODAY", isOverdue: false, isToday: true) }
        if delta > 0 && delta <= 6 {
            let names = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
            return DueTag(text: names[keys.weekdayIndex(for: due)], isOverdue: false, isToday: false)
        }
        let formatter = DateFormatter()
        formatter.calendar = keys.calendar
        formatter.timeZone = keys.calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return DueTag(text: formatter.string(from: due).uppercased(), isOverdue: delta < 0, isToday: false)
    }
}

/// A plain view of a List target for ordering.
public struct TargetSnapshot: Sendable, Equatable {
    public var id: String
    public var createdAt: Date
    public var dueDate: Date?
    public var isPrimary: Bool
    public var struckAt: Date?

    public init(id: String, createdAt: Date, dueDate: Date? = nil, isPrimary: Bool = false, struckAt: Date? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.isPrimary = isPrimary
        self.struckAt = struckAt
    }
}

public enum TargetOrdering {
    /// Primary first, then open by due date (undated last, then oldest first), then struck (most recent first).
    public static func sorted(_ targets: [TargetSnapshot]) -> [TargetSnapshot] {
        let open = targets.filter { $0.struckAt == nil }
        let struck = targets.filter { $0.struckAt != nil }
        let primary = open.filter(\.isPrimary)
        let others = open.filter { !$0.isPrimary }.sorted { a, b in
            switch (a.dueDate, b.dueDate) {
            case let (da?, db?) where da != db: return da < db
            case (.some, nil): return true
            case (nil, .some): return false
            default: return a.createdAt < b.createdAt
            }
        }
        let struckSorted = struck.sorted { ($0.struckAt ?? .distantPast) > ($1.struckAt ?? .distantPast) }
        return primary + others + struckSorted
    }

    /// Open targets due today or earlier.
    public static func dueTodayOrOverdue(_ targets: [TargetSnapshot], now: Date, keys: DayKeys = DayKeys()) -> Int {
        let today = keys.key(for: now)
        return targets.filter { t in
            guard t.struckAt == nil, let due = t.dueDate else { return false }
            return keys.days(from: keys.key(for: due), to: today) >= 0
        }.count
    }
}
