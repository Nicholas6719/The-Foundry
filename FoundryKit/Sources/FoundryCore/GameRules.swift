import Foundation

/// Every tunable number in the game lives here.
public enum GameRules {
    // MARK: XP
    public static let bullseyeXP = 50
    public static let strikeXP = 30
    public static let focusXPPerHour = 20
    public static let liftRecordXP = 100

    // MARK: Recovery
    public static let recoverySleepWeight = 0.65
    public static let recoveryStageWeight = 0.25
    public static let recoveryAwakeWeight = 0.10
    /// Deep + REM should make up this share of time asleep for a full stage score.
    public static let recoveryStageTargetShare = 0.40
    /// Awake minutes at which the awake component reaches zero.
    public static let recoveryAwakeCapMinutes = 60.0
    public static let boostedRecoveryThreshold = 80
    public static let boostedMultiplier = 1.2

    // MARK: Ranks (XP thresholds)
    public static let vigilanteXP = 500
    public static let hoodXP = 2_000
    public static let greenArrowXP = 5_000

    // MARK: Ladder
    public static let defaultStepLb = 5.0

    // MARK: Habits
    public static let maxHabits = 6
    public static let workoutAutoFireMinutes = 20
    public static let defaultSleepThresholdMinutes = 420

    // MARK: Medals
    public static let sevenStraightDays = 7
    public static let rungFourRung = 4
    public static let ironSleeperNights = 5
    public static let deepFocusSessions = 4
    public static let tenStruckCount = 10

    // MARK: Focus
    public static let focusLengthOptions = [15, 25, 45, 60]

    // MARK: Limits
    public static let targetTitleMaxLength = 40

    // MARK: Sleep window (hours, local time)
    /// Sleep for a wake day counts from this hour on the previous evening...
    public static let sleepWindowStartHour = 18
    /// ...until this hour on the wake day.
    public static let sleepWindowEndHour = 12
}
