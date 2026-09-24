import Foundation

public struct SleepSummary: Sendable, Equatable, Codable {
    public var deep: Int
    public var core: Int
    public var rem: Int
    public var awake: Int

    public init(deep: Int = 0, core: Int = 0, rem: Int = 0, awake: Int = 0) {
        self.deep = deep
        self.core = core
        self.rem = rem
        self.awake = awake
    }

    public var asleep: Int { deep + core + rem }
    public var isEmpty: Bool { asleep == 0 && awake == 0 }
}

public enum RecoveryRules {
    /// Recovery 0–100, or nil when there was no sleep to score.
    public static func score(_ sleep: SleepSummary, goalMinutes: Int) -> Int? {
        let asleep = Double(sleep.asleep)
        guard asleep > 0, goalMinutes > 0 else { return nil }
        let sleepScore = min(asleep / Double(goalMinutes), 1)
        let stageScore = min(1, Double(sleep.deep + sleep.rem) / (GameRules.recoveryStageTargetShare * asleep))
        let awakeScore = 1 - min(Double(sleep.awake) / GameRules.recoveryAwakeCapMinutes, 1)
        let raw = 100 * (GameRules.recoverySleepWeight * sleepScore
                         + GameRules.recoveryStageWeight * stageScore
                         + GameRules.recoveryAwakeWeight * awakeScore)
        return Int(raw.rounded())
    }

    /// ×1.2 at recovery ≥ 80, otherwise ×1.0. Never a penalty.
    public static func multiplier(for recovery: Int?) -> Double {
        guard let recovery, recovery >= GameRules.boostedRecoveryThreshold else { return 1.0 }
        return GameRules.boostedMultiplier
    }
}
