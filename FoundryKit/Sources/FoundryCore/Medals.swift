import Foundation

public enum MedalID: String, Sendable, CaseIterable, Codable {
    case firstBullseye
    case sevenStraight
    case rungFour
    case ironSleeper
    case deepFocus
    case tenStruck

    public var title: String {
        switch self {
        case .firstBullseye: "FIRST BULLSEYE"
        case .sevenStraight: "SEVEN STRAIGHT"
        case .rungFour: "RUNG FOUR"
        case .ironSleeper: "IRON SLEEPER"
        case .deepFocus: "DEEP FOCUS"
        case .tenStruck: "TEN STRUCK"
        }
    }

    public var rule: String {
        switch self {
        case .firstBullseye: "Fire every arrow in one day."
        case .sevenStraight: "Hit a 7-day bullseye streak."
        case .rungFour: "Climb any lift to rung four."
        case .ironSleeper: "Meet your sleep goal 5 nights in a row."
        case .deepFocus: "Complete 4 Island sessions in one day."
        case .tenStruck: "Strike 10 names."
        }
    }
}

/// A plain snapshot of the history medals are judged on.
public struct MedalStats: Sendable, Equatable {
    public var bullseyeDays: Set<String>
    public var highestRung: Int
    /// Asleep minutes by wake-day key.
    public var sleepByDay: [String: Int]
    public var sleepGoalMinutes: Int
    /// Completed focus sessions by day key.
    public var focusSessionsByDay: [String: Int]
    public var namesStruck: Int

    public init(bullseyeDays: Set<String> = [], highestRung: Int = 0, sleepByDay: [String: Int] = [:],
                sleepGoalMinutes: Int = 480, focusSessionsByDay: [String: Int] = [:], namesStruck: Int = 0) {
        self.bullseyeDays = bullseyeDays
        self.highestRung = highestRung
        self.sleepByDay = sleepByDay
        self.sleepGoalMinutes = sleepGoalMinutes
        self.focusSessionsByDay = focusSessionsByDay
        self.namesStruck = namesStruck
    }
}

public enum MedalRules {
    /// Every medal the stats qualify for. Unlocks are permanent; callers only add.
    public static func earned(_ s: MedalStats, keys: DayKeys = DayKeys()) -> Set<MedalID> {
        var result: Set<MedalID> = []
        if !s.bullseyeDays.isEmpty { result.insert(.firstBullseye) }
        if StreakRules.longestRun(s.bullseyeDays, keys: keys) >= GameRules.sevenStraightDays { result.insert(.sevenStraight) }
        if s.highestRung >= GameRules.rungFourRung { result.insert(.rungFour) }
        let goodNights = Set(s.sleepByDay.filter { $0.value > 0 && $0.value >= s.sleepGoalMinutes }.keys)
        if StreakRules.longestRun(goodNights, keys: keys) >= GameRules.ironSleeperNights { result.insert(.ironSleeper) }
        if s.focusSessionsByDay.values.contains(where: { $0 >= GameRules.deepFocusSessions }) { result.insert(.deepFocus) }
        if s.namesStruck >= GameRules.tenStruckCount { result.insert(.tenStruck) }
        return result
    }
}
