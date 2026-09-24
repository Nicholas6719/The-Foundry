import Foundation
import SwiftData
import FoundryCore

enum DayMark: Equatable {
    case bullseye
    /// Today, not yet a bullseye. Progress 0...1.
    case today(Double)
    case missed
    case future
}

enum TrainState: Equatable { case done, rest, pending }

/// Everything the hub (and the Mac dashboard) shows, computed in one pass.
struct TodaySnapshot: Equatable {
    var totalXP = 0
    var rank = RankProgress(xp: 0)
    var habitsTotal = 0
    var habitsDone = 0
    var openTargets = 0
    var struckTargets = 0
    var dueToday = 0
    var train: TrainState = .rest
    var workoutName: String?
    var focusDoneToday = 0
    var vitalsSynced = false
    var mission = ""
    var streak = 0
    var week: [DayMark] = Array(repeating: .future, count: 7)
    var todayIndex = 0

    var isBullseye: Bool { StreakRules.isBullseye(total: habitsTotal, done: habitsDone) }
    var habitProgress: Double { habitsTotal == 0 ? 0 : Double(habitsDone) / Double(habitsTotal) }
}

extension FoundryStore {
    func snapshot() -> TodaySnapshot {
        let today = todayKey
        var s = TodaySnapshot()
        s.totalXP = totalXP
        s.rank = RankProgress(xp: s.totalXP)

        let habits = activeHabits()
        let fired = Set(logs(on: today).map(\.habitID))
        s.habitsTotal = habits.count
        s.habitsDone = habits.filter { fired.contains($0.id) }.count

        let targets = all(Target.self)
        s.openTargets = targets.filter { !$0.isStruck }.count
        s.struckTargets = targets.count - s.openTargets
        s.dueToday = dueTodayCount()

        let scheduled = scheduledDay(for: today)
        let session = todaysWorkoutDay()
        s.workoutName = session?.name
        if let session, isSessionComplete(session, on: today) {
            s.train = .done
        } else {
            s.train = scheduled == nil && session == nil ? .rest : .pending
        }

        s.focusDoneToday = completedFocusCount(on: today)
        s.vitalsSynced = (vitals(for: today)?.sleepMinutes ?? 0) > 0

        s.mission = MissionRules.line(MissionInput(
            targetsDueToday: s.dueToday,
            habitsTotal: s.habitsTotal,
            habitsLeft: s.habitsTotal - s.habitsDone,
            workoutScheduledAndNotDone: s.train == .pending && scheduled != nil,
            focusDoneToday: s.focusDoneToday > 0,
            nothingConfigured: targets.isEmpty && habits.isEmpty && workoutDays().isEmpty))

        let bullseyes = all(DaySummary.self).bullseyeDays
        s.streak = StreakRules.current(bullseyeDays: bullseyes, today: today, keys: keys)
        s.todayIndex = keys.weekdayIndex(for: today)
        s.week = weekMarks(bullseyes: bullseyes, progress: s.habitProgress)
        return s
    }

    /// Monday–Sunday marks for the current week.
    func weekMarks(bullseyes: Set<String>, progress: Double) -> [DayMark] {
        let today = todayKey
        return keys.week(containing: today).map { key in
            if bullseyes.contains(key) { return .bullseye }
            if key == today { return .today(progress) }
            return key < today ? .missed : .future
        }
    }

    /// Workout minutes for Monday–Sunday of this week.
    func weekWorkoutMinutes() -> [Int] {
        let byDay = all(DailyVitals.self).byDay
        return keys.week(containing: todayKey).map { byDay[$0]?.workoutMinutes ?? 0 }
    }

    func weekWorkoutCount() -> Int {
        let byDay = all(DailyVitals.self).byDay
        return keys.week(containing: todayKey).reduce(0) { $0 + (byDay[$1]?.workoutCount ?? 0) }
    }
}
