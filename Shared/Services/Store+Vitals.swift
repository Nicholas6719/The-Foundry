import Foundation
import SwiftData
import FoundryCore

/// One day's derived health numbers, as built from HealthKit on iPhone.
struct VitalsValue: Equatable {
    var dayKey: String
    var sleep: SleepSummary
    var restingHR: Int?
    var workoutMinutes: Int
    var workoutCount: Int
}

extension FoundryStore {
    // MARK: - Vitals

    func vitals(for dayKey: String) -> DailyVitals? {
        fetch(FetchDescriptor<DailyVitals>(predicate: #Predicate { $0.dayKey == dayKey }))
            .max { $0.updatedAt < $1.updatedAt }
    }

    /// Writes derived vitals, re-scores Recovery, re-applies that day's multiplier and auto-fires habits.
    func upsertVitals(_ values: [VitalsValue]) {
        let goal = profile().sleepGoalMinutes
        for value in values {
            let dayKey = value.dayKey
            let matches = fetch(FetchDescriptor<DailyVitals>(predicate: #Predicate { $0.dayKey == dayKey }))
            let record = matches.first ?? {
                let v = DailyVitals(dayKey: dayKey)
                context.insert(v)
                return v
            }()
            matches.dropFirst().forEach(context.delete)
            let unchanged = record.sleep == value.sleep && record.restingHR == value.restingHR
                && record.workoutMinutes == value.workoutMinutes && record.workoutCount == value.workoutCount
                && matches.first != nil
            if unchanged { continue }
            record.sleepMinutes = value.sleep.asleep
            record.deepMin = value.sleep.deep
            record.coreMin = value.sleep.core
            record.remMin = value.sleep.rem
            record.awakeMin = value.sleep.awake
            record.restingHR = value.restingHR
            record.workoutMinutes = value.workoutMinutes
            record.workoutCount = value.workoutCount
            record.recovery = RecoveryRules.score(value.sleep, goalMinutes: goal)
            record.updatedAt = now()
            applyMultiplier(forDay: dayKey)
        }
        autoFireEligibleHabits()
        evaluateMedals()
        save()
    }

    // MARK: - Focus sessions

    func startFocusSession(plannedMinutes: Int, at start: Date) -> FocusSession {
        let session = FocusSession(startedAt: start, plannedMinutes: plannedMinutes)
        context.insert(session)
        save()
        return session
    }

    func focusSession(id: UUID) -> FocusSession? {
        fetch(FetchDescriptor<FocusSession>(predicate: #Predicate { $0.id == id })).first
    }

    /// Ends a session. Completed sessions earn `round(20 × minutes / 60)` XP; abandoned ones earn nothing.
    func finishFocusSession(_ session: FocusSession, completed: Bool, at end: Date) {
        session.endedAt = end
        session.completed = completed
        if completed {
            let day = keys.key(for: session.startedAt)
            award(.focus, refKey: session.id.uuidString,
                  base: XPMath.focusXP(minutes: session.plannedMinutes, completed: true), dayKey: day)
            evaluateMedals()
        }
        save()
    }

    func completedFocusCount(on dayKey: String) -> Int {
        all(FocusSession.self).filter { $0.completed && keys.key(for: $0.startedAt) == dayKey }.count
    }
}
