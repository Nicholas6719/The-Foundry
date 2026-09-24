import Foundation

/// One logged set: what was asked for and what was done.
public struct SetResult: Sendable, Equatable {
    public var setIndex: Int
    public var repsDone: Int
    public var targetReps: Int
    public var weightLb: Double

    public init(setIndex: Int, repsDone: Int, targetReps: Int, weightLb: Double) {
        self.setIndex = setIndex
        self.repsDone = repsDone
        self.targetReps = targetReps
        self.weightLb = weightLb
    }

    public var hitTarget: Bool { repsDone >= targetReps }
}

public enum LadderOutcome: Sendable, Equatable {
    /// Not every prescribed set has been logged yet.
    case inProgress
    /// Every set logged at target reps: the next rung unlocks for the next session.
    case climbed
    /// Every set logged but reps were missed: the rung holds.
    case held
}

public enum LadderRules {
    /// Weight for rung `r` (1-based).
    public static func weight(rung: Int, start: Double, step: Double) -> Double {
        start + Double(max(rung, 1) - 1) * step
    }

    /// The rung whose weight is closest to `weight` (1-based, never below 1).
    public static func rung(forWeight weight: Double, start: Double, step: Double) -> Int {
        guard step > 0 else { return 1 }
        return max(1, Int(((weight - start) / step).rounded()) + 1)
    }

    /// Judges one lift's session. Sets are matched by index; duplicates keep the last one.
    public static func outcome(sets: [SetResult], prescribedSets: Int) -> LadderOutcome {
        var byIndex: [Int: SetResult] = [:]
        for set in sets { byIndex[set.setIndex] = set }
        let logged = (0..<max(prescribedSets, 0)).compactMap { byIndex[$0] }
        guard prescribedSets > 0, logged.count == prescribedSets else { return .inProgress }
        return logged.allSatisfy(\.hitTarget) ? .climbed : .held
    }

    /// The rung to use next session. Climbing adds one; holding or missing never drops it.
    public static func nextRung(current: Int, outcome: LadderOutcome) -> Int {
        outcome == .climbed ? current + 1 : current
    }

    /// A record: all sets completed at a weight above every earlier completed weight.
    public static func isRecord(weight: Double, previousCompletedWeights: [Double]) -> Bool {
        guard let best = previousCompletedWeights.max() else { return true }
        return weight > best
    }

    /// `155`, or `152.5` when the weight has a fractional part.
    public static func format(_ weight: Double) -> String {
        if weight.rounded() == weight { return String(Int(weight)) }
        return String(format: "%.1f", weight)
    }
}
