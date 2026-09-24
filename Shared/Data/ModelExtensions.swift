import Foundation
import FoundryCore

enum AutoRule: String, CaseIterable, Identifiable {
    case none, workout, sleepDuration

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "Manual only"
        case .workout: "Workout done"
        case .sleepDuration: "Slept enough"
        }
    }
}

enum LogSource: String {
    case manual, auto
}

extension Habit {
    var habitGlyph: HabitGlyph {
        get { HabitGlyph(rawValue: glyph) ?? .dumbbell }
        set { glyph = newValue.rawValue }
    }

    var rule: AutoRule {
        get { AutoRule(rawValue: autoRule) ?? .none }
        set { autoRule = newValue.rawValue }
    }
}

extension Target {
    var snapshot: TargetSnapshot {
        TargetSnapshot(id: id.uuidString, createdAt: createdAt, dueDate: dueDate, isPrimary: isPrimary, struckAt: struckAt)
    }

    var isStruck: Bool { struckAt != nil }
}

extension WorkoutDay {
    var mask: WeekdayMask {
        get { WeekdayMask(rawValue: weekdayMask) }
        set { weekdayMask = newValue.rawValue }
    }
}

extension LiftDef {
    func weight(forRung rung: Int) -> Double {
        LadderRules.weight(rung: rung, start: startWeightLb, step: stepLb)
    }

    var currentWeight: Double { weight(forRung: currentRung) }
}

extension DailyVitals {
    var sleep: SleepSummary {
        SleepSummary(deep: deepMin, core: coreMin, rem: remMin, awake: awakeMin)
    }
}

extension XPEvent {
    var xpKind: XPKind? { XPKind(rawValue: kind) }
}

extension Array where Element == XPEvent {
    /// Ledger total with sync duplicates of the same `(kind, refKey)` counted once.
    var dedupedTotal: Int {
        var seen: [String: Int] = [:]
        for e in self { seen["\(e.kind)|\(e.refKey)"] = e.total }
        return seen.values.reduce(0, +)
    }
}

extension Array where Element == DailyVitals {
    /// Latest record per day (sync can produce duplicates).
    var byDay: [String: DailyVitals] {
        var result: [String: DailyVitals] = [:]
        for v in self where (result[v.dayKey]?.updatedAt ?? .distantPast) <= v.updatedAt {
            result[v.dayKey] = v
        }
        return result
    }
}

extension Array where Element == DaySummary {
    var bullseyeDays: Set<String> { Set(filter(\.isBullseye).map(\.dayKey)) }
}
