import Foundation

public enum StreakRules {
    /// Consecutive bullseye days ending today when today is a bullseye, otherwise ending yesterday.
    public static func current(bullseyeDays: Set<String>, today: String, keys: DayKeys = DayKeys()) -> Int {
        var day = bullseyeDays.contains(today) ? today : keys.adding(-1, to: today)
        var count = 0
        while bullseyeDays.contains(day) {
            count += 1
            day = keys.adding(-1, to: day)
        }
        return count
    }

    /// Longest run of consecutive keys in the set.
    public static func longestRun(_ days: Set<String>, keys: DayKeys = DayKeys()) -> Int {
        var best = 0
        for day in days where !days.contains(keys.adding(-1, to: day)) {
            var length = 1
            var next = keys.adding(1, to: day)
            while days.contains(next) {
                length += 1
                next = keys.adding(1, to: next)
            }
            best = max(best, length)
        }
        return best
    }

    /// A day is a bullseye when at least one habit exists and every one was fired.
    public static func isBullseye(total: Int, done: Int) -> Bool {
        total > 0 && done >= total
    }
}
