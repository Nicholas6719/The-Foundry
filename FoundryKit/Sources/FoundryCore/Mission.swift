import Foundation

/// Everything the hub mission line needs, as plain values.
public struct MissionInput: Sendable, Equatable {
    public var targetsDueToday: Int
    public var habitsTotal: Int
    public var habitsLeft: Int
    public var workoutScheduledAndNotDone: Bool
    public var focusDoneToday: Bool
    /// True when the user has set up nothing yet (no names, habits or workout days).
    public var nothingConfigured: Bool

    public init(targetsDueToday: Int = 0, habitsTotal: Int = 0, habitsLeft: Int = 0,
                workoutScheduledAndNotDone: Bool = false, focusDoneToday: Bool = false,
                nothingConfigured: Bool = false) {
        self.targetsDueToday = targetsDueToday
        self.habitsTotal = habitsTotal
        self.habitsLeft = habitsLeft
        self.workoutScheduledAndNotDone = workoutScheduledAndNotDone
        self.focusDoneToday = focusDoneToday
        self.nothingConfigured = nothingConfigured
    }
}

public enum MissionRules {
    public static func line(_ input: MissionInput) -> String {
        if input.nothingConfigured { return "Write your first name." }
        var parts: [String] = []
        if input.targetsDueToday == 1 {
            parts.append("Strike one name")
        } else if input.targetsDueToday > 1 {
            parts.append("Strike \(spelled(input.targetsDueToday)) names")
        }
        if input.habitsLeft == 1 {
            parts.append("Fire one last arrow")
        } else if input.habitsLeft > 1 {
            parts.append("Fire \(spelled(input.habitsLeft)) arrows")
        }
        if input.workoutScheduledAndNotDone { parts.append("Climb the ladder") }
        if !input.focusDoneToday { parts.append("Hold the Island") }
        if parts.isEmpty { return "Bullseye. Hold the line." }
        return parts.joined(separator: ". ") + "."
    }

    /// Small counts read better as words (`two`), larger ones as digits.
    public static func spelled(_ n: Int) -> String {
        let words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
        return n >= 0 && n < words.count ? words[n] : String(n)
    }
}
