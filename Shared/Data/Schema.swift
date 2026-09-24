import Foundation
import SwiftData

// CloudKit rules: every attribute has a default or is optional, no unique constraints,
// no required relationships (records reference each other by UUID), enums stored as raw strings.

enum FoundrySchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Profile.self, Target.self, Habit.self, HabitLog.self, DaySummary.self, WorkoutDay.self,
         LiftDef.self, SetLog.self, FocusSession.self, DailyVitals.self, XPEvent.self, MedalUnlock.self]
    }

    @Model final class Profile {
        /// With sync, two devices can each create a profile; the oldest (then lowest id) wins everywhere.
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var sleepGoalMinutes: Int = 480
        var weeklyWorkoutGoal: Int = 4
        var focusMinutes: Int = 25
        var focusSessionsGoal: Int = 4
        var hasOnboarded: Bool = false
        var healthEnabled: Bool = false
        var focusShortcutsConfigured: Bool = false
        var focusAutoStartFromFilter: Bool = false

        init() {}
    }

    @Model final class Target {
        var id: UUID = UUID()
        var title: String = ""
        var createdAt: Date = Date()
        var dueDate: Date?
        var isPrimary: Bool = false
        var struckAt: Date?

        init(title: String, dueDate: Date? = nil, isPrimary: Bool = false, createdAt: Date = Date()) {
            self.title = title
            self.dueDate = dueDate
            self.isPrimary = isPrimary
            self.createdAt = createdAt
        }
    }

    @Model final class Habit {
        var id: UUID = UUID()
        var name: String = ""
        var glyph: String = "dumbbell"
        var sortOrder: Int = 0
        var autoRule: String = "none"
        var autoThresholdMinutes: Int = 0
        var isArchived: Bool = false

        init(name: String, glyph: String, sortOrder: Int, autoRule: String = "none", autoThresholdMinutes: Int = 0) {
            self.name = name
            self.glyph = glyph
            self.sortOrder = sortOrder
            self.autoRule = autoRule
            self.autoThresholdMinutes = autoThresholdMinutes
        }
    }

    @Model final class HabitLog {
        var habitID: UUID = UUID()
        var dayKey: String = ""
        var firedAt: Date = Date()
        var source: String = "manual"

        init(habitID: UUID, dayKey: String, firedAt: Date, source: String) {
            self.habitID = habitID
            self.dayKey = dayKey
            self.firedAt = firedAt
            self.source = source
        }
    }

    @Model final class DaySummary {
        var dayKey: String = ""
        var habitsTotal: Int = 0
        var habitsDone: Int = 0
        var isBullseye: Bool = false

        init(dayKey: String) { self.dayKey = dayKey }
    }

    @Model final class WorkoutDay {
        var id: UUID = UUID()
        var name: String = ""
        var weekdayMask: Int = 0
        var sortOrder: Int = 0

        init(name: String, weekdayMask: Int, sortOrder: Int) {
            self.name = name
            self.weekdayMask = weekdayMask
            self.sortOrder = sortOrder
        }
    }

    @Model final class LiftDef {
        var id: UUID = UUID()
        var workoutDayID: UUID = UUID()
        var name: String = ""
        var sortOrder: Int = 0
        var isLead: Bool = false
        var startWeightLb: Double = 45
        var stepLb: Double = 5
        var sets: Int = 3
        var reps: Int = 5
        var currentRung: Int = 1
        /// Day key of the session that last climbed a rung, so an undo on that day can step back.
        var lastClimbDayKey: String = ""

        init(workoutDayID: UUID, name: String, sortOrder: Int, isLead: Bool, startWeightLb: Double,
             stepLb: Double, sets: Int, reps: Int, currentRung: Int = 1) {
            self.workoutDayID = workoutDayID
            self.name = name
            self.sortOrder = sortOrder
            self.isLead = isLead
            self.startWeightLb = startWeightLb
            self.stepLb = stepLb
            self.sets = sets
            self.reps = reps
            self.currentRung = currentRung
        }
    }

    @Model final class SetLog {
        var id: UUID = UUID()
        var liftID: UUID = UUID()
        var dayKey: String = ""
        var setIndex: Int = 0
        var weightLb: Double = 0
        var repsDone: Int = 0
        var targetReps: Int = 0
        var completedAt: Date = Date()

        init(liftID: UUID, dayKey: String, setIndex: Int, weightLb: Double, repsDone: Int, targetReps: Int, completedAt: Date) {
            self.liftID = liftID
            self.dayKey = dayKey
            self.setIndex = setIndex
            self.weightLb = weightLb
            self.repsDone = repsDone
            self.targetReps = targetReps
            self.completedAt = completedAt
        }
    }

    @Model final class FocusSession {
        var id: UUID = UUID()
        var startedAt: Date = Date()
        var endedAt: Date?
        var plannedMinutes: Int = 25
        var completed: Bool = false

        init(startedAt: Date, plannedMinutes: Int) {
            self.startedAt = startedAt
            self.plannedMinutes = plannedMinutes
        }
    }

    @Model final class DailyVitals {
        var dayKey: String = ""
        var sleepMinutes: Int = 0
        var deepMin: Int = 0
        var coreMin: Int = 0
        var remMin: Int = 0
        var awakeMin: Int = 0
        var restingHR: Int?
        var workoutMinutes: Int = 0
        var workoutCount: Int = 0
        /// Longest single workout that day, for the "workout ≥ 20 min" auto rule.
        var longestWorkoutMin: Int = 0
        var recovery: Int?
        var updatedAt: Date = Date()

        init(dayKey: String) { self.dayKey = dayKey }
    }

    @Model final class XPEvent {
        var id: UUID = UUID()
        var dayKey: String = ""
        var kind: String = ""
        var refKey: String = ""
        var base: Int = 0
        var multiplier: Double = 1
        var total: Int = 0
        var createdAt: Date = Date()

        init(dayKey: String, kind: String, refKey: String, base: Int, multiplier: Double, total: Int, createdAt: Date) {
            self.dayKey = dayKey
            self.kind = kind
            self.refKey = refKey
            self.base = base
            self.multiplier = multiplier
            self.total = total
            self.createdAt = createdAt
        }
    }

    @Model final class MedalUnlock {
        var medalID: String = ""
        var unlockedAt: Date = Date()

        init(medalID: String, unlockedAt: Date) {
            self.medalID = medalID
            self.unlockedAt = unlockedAt
        }
    }
}

/// Migration scaffold. Add `FoundrySchemaV2` and a stage here when the schema changes.
enum FoundryMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [FoundrySchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

typealias Profile = FoundrySchemaV1.Profile
typealias Target = FoundrySchemaV1.Target
typealias Habit = FoundrySchemaV1.Habit
typealias HabitLog = FoundrySchemaV1.HabitLog
typealias DaySummary = FoundrySchemaV1.DaySummary
typealias WorkoutDay = FoundrySchemaV1.WorkoutDay
typealias LiftDef = FoundrySchemaV1.LiftDef
typealias SetLog = FoundrySchemaV1.SetLog
typealias FocusSession = FoundrySchemaV1.FocusSession
typealias DailyVitals = FoundrySchemaV1.DailyVitals
typealias XPEvent = FoundrySchemaV1.XPEvent
typealias MedalUnlock = FoundrySchemaV1.MedalUnlock
