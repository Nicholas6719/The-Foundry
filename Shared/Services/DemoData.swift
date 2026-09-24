#if DEBUG
import Foundation
import FoundryCore

/// Debug-only sample history so every screen can be checked in the simulator. Not in release builds.
enum DemoData {
    static func load(into store: FoundryStore) {
        store.celebrations.isEnabled = false
        defer {
            store.markRankSeen()
            store.celebrations.isEnabled = true
        }
        store.deleteEverything()
        let keys = store.keys
        let now = store.now()
        let today = keys.key(for: now)
        let day: (Int) -> String = { keys.adding($0, to: today) }
        let date: (Int, Int) -> Date = { offset, hour in
            let start = keys.date(for: day(offset)) ?? now
            return keys.calendar.date(byAdding: .hour, value: hour, to: start) ?? start
        }

        let profile = store.profile()
        profile.hasOnboarded = true
        profile.healthEnabled = true

        // Habits: three fired today, Sleep still pending.
        store.seedHabits(FoundryStore.defaultHabits)
        let habits = store.activeHabits()
        habits.first { $0.habitGlyph == .moon }?.autoThresholdMinutes = 450

        // Past days: a seven-day run two weeks back and a four-day streak into today.
        let bullseyeOffsets = [-1, -2, -3, -4, -6, -8, -9, -10, -11, -12, -13, -14]
        for offset in -14...(-1) {
            let key = day(offset)
            let summary = DaySummary(dayKey: key)
            summary.habitsTotal = habits.count
            let hit = bullseyeOffsets.contains(offset)
            summary.habitsDone = hit ? habits.count : max(0, habits.count - 2)
            summary.isBullseye = hit
            store.context.insert(summary)
            for habit in habits.prefix(summary.habitsDone) {
                store.context.insert(HabitLog(habitID: habit.id, dayKey: key, firedAt: date(offset, 20), source: "manual"))
            }
            if hit { store.award(.bullseye, refKey: key, base: GameRules.bullseyeXP, dayKey: key) }
        }

        // The List.
        let ship = store.addTarget(title: "Ship the side project", dueDate: date(2, 12), primary: true)
        _ = ship
        store.addTarget(title: "Call the dentist", dueDate: date(0, 12), primary: false)
        store.addTarget(title: "Read 20 pages", dueDate: date(0, 12), primary: false)
        let cancel = store.addTarget(title: "Cancel the subscription", dueDate: nil, primary: false)
        let meal = store.addTarget(title: "Meal prep Sunday", dueDate: nil, primary: false)
        for (target, offset) in [(cancel, -1), (meal, 0)] {
            guard let target else { continue }
            store.now = { date(offset, 9) }
            store.strike(target)
        }
        store.now = { Date() }
        for i in 0..<5 {
            store.award(.strike, refKey: "demo-archived-\(i)", base: GameRules.strikeXP, dayKey: day(-3 - i * 2))
        }

        // Training: PUSH today and two other days.
        let todayIndex = keys.weekdayIndex(for: today)
        let mask = WeekdayMask.day(todayIndex).union(.day((todayIndex + 3) % 7)).union(.day((todayIndex + 5) % 7))
        let push = store.createWorkoutDay(name: "Push", mask: mask, lifts: [
            LiftDraft(name: "Bench", startWeight: 140, step: 5, sets: 3, reps: 5, isLead: true),
            LiftDraft(name: "Incline", startWeight: 95, step: 5, sets: 3, reps: 8),
            LiftDraft(name: "Press", startWeight: 75, step: 5, sets: 3, reps: 6),
            LiftDraft(name: "Pushdown", startWeight: 40, step: 5, sets: 3, reps: 12)
        ])
        let lifts = store.lifts(for: push)
        for (lift, rung) in zip(lifts, [4, 3, 2, 2]) {
            lift.currentRung = rung
            for r in 1..<rung {
                let key = day(-7 * (rung - r))
                for s in 0..<lift.sets {
                    store.context.insert(SetLog(liftID: lift.id, dayKey: key, setIndex: s, weightLb: lift.weight(forRung: r),
                                                repsDone: lift.reps, targetReps: lift.reps, completedAt: date(-7 * (rung - r), 18)))
                }
                if lift.isLead {
                    store.award(.liftRecord, refKey: "\(lift.id.uuidString)|\(key)", base: GameRules.liftRecordXP, dayKey: key)
                }
            }
        }
        store.startDay(push)
        for lift in lifts.prefix(2) {
            store.logSet(lift, index: 0)
            store.logSet(lift, index: 1)
        }

        // Focus sessions on past days.
        for offset in [-1, -2, -2, -4, -5, -6, -8, -9, -11, -13] {
            let session = store.startFocusSession(plannedMinutes: 25, at: date(offset, 15))
            store.finishFocusSession(session, completed: true, at: date(offset, 15).addingTimeInterval(1500))
        }

        // Fourteen nights of sleep, a boosted Recovery today, and three workouts this week.
        let weekStart = keys.days(from: keys.week(containing: today)[0], to: today)
        var values: [VitalsValue] = []
        for offset in -13...0 {
            let ironRun = (-13)...(-9) ~= offset
            let sleep = offset == 0
                ? SleepSummary(deep: 60, core: 320, rem: 52, awake: 17)
                : SleepSummary(deep: 55 + (offset & 3) * 6, core: ironRun ? 360 : 280 + (offset % 3) * 12,
                               rem: 85 + (offset % 2) * 10, awake: 14 + abs(offset % 4) * 4)
            let inWeek = offset >= -weekStart
            let trained = offset == 0 || (inWeek && (offset == -weekStart || offset == -weekStart + 2) && offset < 0)
            let minutes = offset == 0 ? 42 : (offset == -weekStart ? 40 : 46)
            values.append(VitalsValue(dayKey: day(offset), sleep: sleep, restingHR: 58 + abs(offset % 3),
                                      workoutMinutes: trained ? minutes : 0, workoutCount: trained ? 1 : 0,
                                      longestWorkout: trained ? minutes : 0))
        }
        store.upsertVitals(values)
        store.defaults.set(Date(), forKey: DefaultsKey.healthLastSync)

        store.refreshToday()
        // Fire three of four arrows for today (after vitals so the Recovery bonus applies).
        for habit in habits.prefix(3) where !store.isFired(habit, on: today) {
            store.fire(habit)
        }
        store.save()
    }
}
#endif
