import Foundation
import SwiftData
import FoundryCore

struct LiftDraft: Identifiable, Equatable {
    var id = UUID()
    var name = ""
    var startWeight = 45.0
    var step = GameRules.defaultStepLb
    var sets = 3
    var reps = 5
    var isLead = false
}

struct LiftLogResult: Equatable {
    var climbed = false
    var record = false
    var sessionCompleted = false
}

struct SessionHistory: Identifiable {
    var dayKey: String
    var weight: Double
    var reps: [Int]
    var id: String { dayKey }
}

extension FoundryStore {
    // MARK: - Reads

    func workoutDays() -> [WorkoutDay] {
        fetch(FetchDescriptor<WorkoutDay>(sortBy: [SortDescriptor(\.sortOrder)]))
    }

    func lifts(for day: WorkoutDay) -> [LiftDef] {
        let id = day.id
        return fetch(FetchDescriptor<LiftDef>(predicate: #Predicate { $0.workoutDayID == id }, sortBy: [SortDescriptor(\.sortOrder)]))
    }

    func setLogs(for lift: LiftDef, on dayKey: String) -> [SetLog] {
        let id = lift.id
        return fetch(FetchDescriptor<SetLog>(predicate: #Predicate { $0.liftID == id && $0.dayKey == dayKey },
                                             sortBy: [SortDescriptor(\.setIndex)]))
    }

    func scheduledDay(for dayKey: String) -> WorkoutDay? {
        let index = keys.weekdayIndex(for: dayKey)
        return workoutDays().first { $0.mask.contains(dayIndex: index) }
    }

    /// Today's session: the day already being logged, else one started by hand, else the schedule.
    func todaysWorkoutDay() -> WorkoutDay? {
        let today = todayKey
        let days = workoutDays()
        let loggedLiftIDs = Set(fetch(FetchDescriptor<SetLog>(predicate: #Predicate { $0.dayKey == today })).map(\.liftID))
        if !loggedLiftIDs.isEmpty {
            let lifts = all(LiftDef.self)
            if let dayID = lifts.first(where: { loggedLiftIDs.contains($0.id) })?.workoutDayID,
               let day = days.first(where: { $0.id == dayID }) {
                return day
            }
        }
        if let raw = defaults.string(forKey: DefaultsKey.trainOverride) {
            let parts = raw.split(separator: "|").map(String.init)
            if parts.count == 2, parts[0] == today, let day = days.first(where: { $0.id.uuidString == parts[1] }) {
                return day
            }
        }
        return scheduledDay(for: today)
    }

    func isScheduledToday() -> Bool { scheduledDay(for: todayKey) != nil }

    /// Starts a day by hand (for example on a rest day).
    func startDay(_ day: WorkoutDay) {
        defaults.set("\(todayKey)|\(day.id.uuidString)", forKey: DefaultsKey.trainOverride)
    }

    /// The weight for this lift today: whatever was already logged, else the current rung.
    func sessionWeight(for lift: LiftDef, on dayKey: String) -> Double {
        setLogs(for: lift, on: dayKey).first?.weightLb ?? lift.currentWeight
    }

    func isLiftComplete(_ lift: LiftDef, on dayKey: String) -> Bool {
        Set(setLogs(for: lift, on: dayKey).map(\.setIndex)).count >= lift.sets
    }

    func isSessionComplete(_ day: WorkoutDay, on dayKey: String) -> Bool {
        let lifts = lifts(for: day)
        return !lifts.isEmpty && lifts.allSatisfy { isLiftComplete($0, on: dayKey) }
    }

    /// The last `limit` sessions for a lift, newest first.
    func history(for lift: LiftDef, limit: Int = 5) -> [SessionHistory] {
        let id = lift.id
        let logs = fetch(FetchDescriptor<SetLog>(predicate: #Predicate { $0.liftID == id }))
        return Dictionary(grouping: logs, by: \.dayKey)
            .map { day, sets in
                let sorted = sets.sorted { $0.setIndex < $1.setIndex }
                return SessionHistory(dayKey: day, weight: sorted.first?.weightLb ?? 0, reps: sorted.map(\.repsDone))
            }
            .sorted { $0.dayKey > $1.dayKey }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Logging

    /// Logs one set (complete at target reps unless `reps` says otherwise) and judges the session.
    @discardableResult
    func logSet(_ lift: LiftDef, index: Int, reps: Int? = nil) -> LiftLogResult {
        let today = todayKey
        let day = workoutDays().first { $0.id == lift.workoutDayID }
        let wasSessionComplete = day.map { isSessionComplete($0, on: today) } ?? false
        let weight = sessionWeight(for: lift, on: today)
        let existing = setLogs(for: lift, on: today).filter { $0.setIndex == index }
        let done = max(0, min(20, reps ?? lift.reps))
        if let log = existing.first {
            log.repsDone = done
            log.targetReps = lift.reps
            log.completedAt = now()
            existing.dropFirst().forEach(context.delete)
        } else {
            context.insert(SetLog(liftID: lift.id, dayKey: today, setIndex: index, weightLb: weight,
                                  repsDone: done, targetReps: lift.reps, completedAt: now()))
        }
        if lift.workoutDayID != todaysWorkoutDay()?.id, let day { startDay(day) }
        var result = judge(lift, on: today)
        if let day, !wasSessionComplete, isSessionComplete(day, on: today) {
            result.sessionCompleted = true
            autoFireEligibleHabits()
        }
        evaluateMedals()
        save()
        return result
    }

    /// Removes one logged set and re-judges the session.
    func clearSet(_ lift: LiftDef, index: Int) {
        let today = todayKey
        setLogs(for: lift, on: today).filter { $0.setIndex == index }.forEach(context.delete)
        _ = judge(lift, on: today)
        save()
    }

    /// Applies the ladder rules for a lift's session today. Climbing takes effect next session;
    /// if a same-day undo breaks the climb, the rung steps back.
    private func judge(_ lift: LiftDef, on dayKey: String) -> LiftLogResult {
        let logs = setLogs(for: lift, on: dayKey)
        let results = logs.map { SetResult(setIndex: $0.setIndex, repsDone: $0.repsDone, targetReps: $0.targetReps, weightLb: $0.weightLb) }
        let outcome = LadderRules.outcome(sets: results, prescribedSets: lift.sets)
        let recordKey = "\(lift.id.uuidString)|\(dayKey)"
        var result = LiftLogResult()
        if outcome == .climbed, lift.lastClimbDayKey != dayKey {
            lift.currentRung = LadderRules.nextRung(current: lift.currentRung, outcome: outcome)
            lift.lastClimbDayKey = dayKey
            result.climbed = true
        } else if outcome != .climbed, lift.lastClimbDayKey == dayKey {
            lift.currentRung = max(1, lift.currentRung - 1)
            lift.lastClimbDayKey = ""
        }
        if outcome == .climbed, let weight = logs.first?.weightLb {
            let previous = completedWeights(for: lift, excluding: dayKey)
            if LadderRules.isRecord(weight: weight, previousCompletedWeights: previous) {
                result.record = award(.liftRecord, refKey: recordKey, base: GameRules.liftRecordXP, dayKey: dayKey)
            }
        } else {
            revoke(.liftRecord, refKey: recordKey)
        }
        return result
    }

    /// Weights at which every prescribed set was completed at target reps, on other days.
    private func completedWeights(for lift: LiftDef, excluding dayKey: String) -> [Double] {
        let id = lift.id
        let logs = fetch(FetchDescriptor<SetLog>(predicate: #Predicate { $0.liftID == id && $0.dayKey != dayKey }))
        return Dictionary(grouping: logs, by: \.dayKey).compactMap { _, sets in
            let results = sets.map { SetResult(setIndex: $0.setIndex, repsDone: $0.repsDone, targetReps: $0.targetReps, weightLb: $0.weightLb) }
            return LadderRules.outcome(sets: results, prescribedSets: lift.sets) == .climbed ? sets.first?.weightLb : nil
        }
    }

    // MARK: - Building days

    @discardableResult
    func createWorkoutDay(name: String, mask: WeekdayMask, lifts: [LiftDraft]) -> WorkoutDay {
        let day = WorkoutDay(name: Self.cleanDayName(name), weekdayMask: mask.rawValue,
                             sortOrder: (workoutDays().map(\.sortOrder).max() ?? -1) + 1)
        context.insert(day)
        setLifts(lifts, for: day)
        save()
        return day
    }

    func updateWorkoutDay(_ day: WorkoutDay, name: String, mask: WeekdayMask, lifts: [LiftDraft]) {
        day.name = Self.cleanDayName(name)
        day.weekdayMask = mask.rawValue
        setLifts(lifts, for: day)
        save()
    }

    func deleteWorkoutDay(_ day: WorkoutDay) {
        lifts(for: day).forEach(context.delete)
        context.delete(day)
        save()
    }

    func drafts(for day: WorkoutDay) -> [LiftDraft] {
        lifts(for: day).map {
            LiftDraft(id: $0.id, name: $0.name, startWeight: $0.startWeightLb, step: $0.stepLb,
                      sets: $0.sets, reps: $0.reps, isLead: $0.isLead)
        }
    }

    /// Syncs a day's lifts to the drafts: updates matches by id, adds new, removes missing.
    private func setLifts(_ drafts: [LiftDraft], for day: WorkoutDay) {
        let valid = drafts.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        let leadID = valid.first(where: \.isLead)?.id ?? valid.first?.id
        var existing = Dictionary(lifts(for: day).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for (i, draft) in valid.enumerated() {
            let name = String(draft.name.trimmingCharacters(in: .whitespaces).prefix(20))
            if let lift = existing.removeValue(forKey: draft.id) {
                lift.name = name
                lift.sortOrder = i
                lift.isLead = draft.id == leadID
                lift.startWeightLb = max(0, draft.startWeight)
                lift.stepLb = max(0.5, draft.step)
                lift.sets = max(1, min(10, draft.sets))
                lift.reps = max(1, min(20, draft.reps))
            } else {
                let lift = LiftDef(workoutDayID: day.id, name: name, sortOrder: i, isLead: draft.id == leadID,
                                   startWeightLb: max(0, draft.startWeight), stepLb: max(0.5, draft.step),
                                   sets: max(1, min(10, draft.sets)), reps: max(1, min(20, draft.reps)))
                lift.id = draft.id
                context.insert(lift)
            }
        }
        existing.values.forEach(context.delete)
    }

    static func cleanDayName(_ name: String) -> String {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(12).uppercased()
        return clean.isEmpty ? "DAY" : clean
    }
}
