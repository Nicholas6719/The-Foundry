import Foundation
import SwiftData
import Testing
import FoundryCore
@testable import Foundry

/// A store on a fresh in-memory container, a private defaults suite and a fixed clock.
@MainActor
func makeStore(now: Date = StoreFixture.noon) -> FoundryStore {
    let (container, _) = PersistenceController.makeContainer(inMemory: true)
    let suite = "foundry.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite) ?? .standard
    defaults.removePersistentDomain(forName: suite)
    let store = FoundryStore(context: container.mainContext, keys: StoreFixture.keys,
                             celebrations: CelebrationCenter(), defaults: defaults, now: { now })
    // Keep the container alive for the test's duration.
    StoreFixture.containers.append(container)
    return store
}

@MainActor
enum StoreFixture {
    static var containers: [ModelContainer] = []

    static let keys: DayKeys = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        cal.firstWeekday = 2
        return DayKeys(calendar: cal)
    }()

    /// Thursday, September 24, 2026, 12:00 PM Eastern.
    static let noon: Date = {
        keys.calendar.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: 12)) ?? Date()
    }()
}

@MainActor
@Suite("Habits and bullseye")
struct HabitStoreTests {
    @Test func bullseyeAwardsOnceAndReversesOnUndo() {
        let store = makeStore()
        store.seedHabits([("Eat", .fork), ("Read", .book)])
        let habits = store.activeHabits()
        #expect(store.fire(habits[0]) == .fired)
        #expect(store.fire(habits[1]) == .bullseye)
        #expect(store.fire(habits[1]) == .ignored)
        #expect(store.totalXP == GameRules.bullseyeXP)
        #expect(store.summary(for: store.todayKey)?.isBullseye == true)

        store.undo(habits[1])
        #expect(store.totalXP == 0)
        #expect(store.summary(for: store.todayKey)?.isBullseye == false)

        #expect(store.fire(habits[1]) == .bullseye)
        #expect(store.totalXP == GameRules.bullseyeXP)
    }

    @Test func firstBullseyeUnlocksMedal() {
        let store = makeStore()
        store.seedHabits([("Eat", .fork)])
        store.fire(store.activeHabits()[0])
        let medals = store.all(MedalUnlock.self).map(\.medalID)
        #expect(medals == [MedalID.firstBullseye.rawValue])
    }

    @Test func sleepHabitAutoFiresAndStaysUndone() {
        let store = makeStore()
        store.seedHabits([("Sleep", .moon)])
        let habit = store.activeHabits()[0]
        #expect(habit.rule == .sleepDuration)
        store.upsertVitals([VitalsValue(dayKey: store.todayKey, sleep: SleepSummary(deep: 60, core: 300, rem: 90, awake: 10),
                                        restingHR: 55, workoutMinutes: 0, workoutCount: 0)])
        #expect(store.isFired(habit, on: store.todayKey))
        #expect(store.logs(on: store.todayKey).first?.source == "auto")

        store.undo(habit)
        store.autoFireEligibleHabits()
        #expect(!store.isFired(habit, on: store.todayKey))
    }

    @Test func workoutRuleNeedsOneTwentyMinuteWorkout() {
        let store = makeStore()
        store.seedHabits([("Train", .dumbbell)])
        let habit = store.activeHabits()[0]
        // Two 10-minute walks add up to 20 but no single workout reaches it.
        store.upsertVitals([VitalsValue(dayKey: store.todayKey, sleep: SleepSummary(), restingHR: nil,
                                        workoutMinutes: 20, workoutCount: 2, longestWorkout: 10)])
        #expect(!store.isFired(habit, on: store.todayKey))
        store.upsertVitals([VitalsValue(dayKey: store.todayKey, sleep: SleepSummary(), restingHR: nil,
                                        workoutMinutes: 45, workoutCount: 3, longestWorkout: 25)])
        #expect(store.isFired(habit, on: store.todayKey))
    }

    @Test func autoFiredLastArrowPlaysTheBullseyeMoment() {
        let store = makeStore()
        var moments = 0
        store.onBullseye = { moments += 1 }
        store.seedHabits([("Sleep", .moon)])
        store.upsertVitals([VitalsValue(dayKey: store.todayKey, sleep: SleepSummary(deep: 60, core: 300, rem: 90, awake: 10),
                                        restingHR: nil, workoutMinutes: 0, workoutCount: 0)])
        #expect(moments == 1)
        // That night also earns the Recovery bonus, so check the award itself rather than the total.
        #expect(store.events(.bullseye, refKey: store.todayKey).count == 1)
    }

    @Test func duplicateProfilesResolveTheSameWayEverywhere() {
        let store = makeStore()
        let older = Profile()
        older.createdAt = StoreFixture.noon.addingTimeInterval(-3600)
        older.sleepGoalMinutes = 450
        let newer = Profile()
        newer.createdAt = StoreFixture.noon
        newer.hasOnboarded = true
        store.context.insert(newer)
        store.context.insert(older)
        let winner = store.profile()
        #expect(winner.sleepGoalMinutes == 450)
        #expect(winner.hasOnboarded)
        #expect(store.all(Profile.self).count == 1)
    }

    @Test func duplicateSeededHabitsAreArchived() {
        let store = makeStore()
        store.seedHabits([("Read", .book)])
        store.context.insert(Habit(name: "Read", glyph: HabitGlyph.book.rawValue, sortOrder: 1))
        store.resolveSyncDuplicates()
        #expect(store.activeHabits().count == 1)
    }

    @Test func habitLimitIsSix() {
        let store = makeStore()
        for i in 0..<6 { #expect(store.addHabit(name: "H\(i)", glyph: .pen) != nil) }
        #expect(store.addHabit(name: "Seventh", glyph: .pen) == nil)
    }
}

@MainActor
@Suite("List")
struct TargetStoreTests {
    @Test func strikeAndRestore() {
        let store = makeStore()
        let target = store.addTarget(title: "Call the dentist", dueDate: StoreFixture.noon, primary: false)
        #expect(target != nil)
        guard let target else { return }
        #expect(store.dueTodayCount() == 1)
        store.strike(target)
        store.strike(target)
        #expect(store.totalXP == GameRules.strikeXP)
        #expect(store.dueTodayCount() == 0)
        store.restore(target)
        #expect(store.totalXP == 0)
    }

    @Test func onlyOnePrimary() {
        let store = makeStore()
        let a = store.addTarget(title: "A", dueDate: nil, primary: true)
        let b = store.addTarget(title: "B", dueDate: nil, primary: true)
        #expect(a?.isPrimary == false)
        #expect(b?.isPrimary == true)
        #expect(store.targets().first?.title == "B")
    }

    @Test func titleIsTrimmedAndCapped() {
        let store = makeStore()
        let t = store.addTarget(title: "  " + String(repeating: "x", count: 60) + "  ", dueDate: nil, primary: false)
        #expect(t?.title.count == GameRules.targetTitleMaxLength)
        #expect(store.addTarget(title: "   ", dueDate: nil, primary: false) == nil)
    }
}

@MainActor
@Suite("Ladder, focus and recovery")
struct TrainingFocusTests {
    private func pushDay(_ store: FoundryStore) -> LiftDef {
        let index = store.keys.weekdayIndex(for: store.todayKey)
        let day = store.createWorkoutDay(name: "push", mask: .day(index), lifts: [
            LiftDraft(name: "Bench", startWeight: 140, step: 5, sets: 3, reps: 5, isLead: true)
        ])
        #expect(day.name == "PUSH")
        return store.lifts(for: day)[0]
    }

    @Test func cleanSessionClimbsAndUndoStepsBack() {
        let store = makeStore()
        let lift = pushDay(store)
        store.logSet(lift, index: 0)
        store.logSet(lift, index: 1)
        let result = store.logSet(lift, index: 2)
        #expect(result.climbed && result.record && result.sessionCompleted)
        #expect(lift.currentRung == 2)
        #expect(store.totalXP == GameRules.liftRecordXP)
        // Today's sets stay at the weight they were lifted at.
        #expect(store.sessionWeight(for: lift, on: store.todayKey) == 140)

        store.clearSet(lift, index: 2)
        #expect(lift.currentRung == 1)
        #expect(store.totalXP == 0)
    }

    @Test func missedRepsHoldTheRung() {
        let store = makeStore()
        let lift = pushDay(store)
        store.logSet(lift, index: 0)
        store.logSet(lift, index: 1, reps: 3)
        let result = store.logSet(lift, index: 2)
        #expect(!result.climbed)
        #expect(result.sessionCompleted)
        #expect(lift.currentRung == 1)
    }

    @Test func completedFocusEarnsRoundedXP() {
        let store = makeStore()
        let done = store.startFocusSession(plannedMinutes: 25, at: StoreFixture.noon)
        store.finishFocusSession(done, completed: true, at: StoreFixture.noon.addingTimeInterval(1500))
        let left = store.startFocusSession(plannedMinutes: 60, at: StoreFixture.noon)
        store.finishFocusSession(left, completed: false, at: StoreFixture.noon.addingTimeInterval(600))
        #expect(store.totalXP == 8)
        #expect(store.completedFocusCount(on: store.todayKey) == 1)
    }

    @Test func lateVitalsBoostThatDaysXP() {
        let store = makeStore()
        let target = store.addTarget(title: "A", dueDate: nil, primary: false)
        if let target { store.strike(target) }
        #expect(store.totalXP == 30)
        store.upsertVitals([VitalsValue(dayKey: store.todayKey, sleep: SleepSummary(deep: 90, core: 300, rem: 100, awake: 5),
                                        restingHR: nil, workoutMinutes: 0, workoutCount: 0)])
        #expect((store.vitals(for: store.todayKey)?.recovery ?? 0) >= 80)
        #expect(store.totalXP == 36)
    }

    @Test func missionLineReflectsToday() {
        let store = makeStore()
        #expect(store.snapshot().mission == "Write your first name.")
        store.seedHabits([("Eat", .fork), ("Read", .book)])
        store.addTarget(title: "A", dueDate: StoreFixture.noon, primary: false)
        #expect(store.snapshot().mission == "Strike one name. Fire two arrows. Hold the Island.")
        // Overdue names light the hub's red dot but aren't counted as "due today" in the mission.
        store.addTarget(title: "Old", dueDate: StoreFixture.noon.addingTimeInterval(-3 * 86_400), primary: false)
        #expect(store.snapshot().mission == "Strike one name. Fire two arrows. Hold the Island.")
        #expect(store.snapshot().dueToday == 2)
    }
}

@MainActor
@Suite("Health folding")
struct HealthBuildTests {
    @Test func foldsSamplesPerDay() {
        let keys = StoreFixture.keysNonisolated
        let cal = keys.calendar
        func at(_ d: Int, _ h: Int, _ m: Int = 0) -> Date {
            cal.date(from: DateComponents(year: 2026, month: 9, day: d, hour: h, minute: m)) ?? Date()
        }
        let sleep = [
            SleepSample(sourceID: "watch", stage: .core, start: at(23, 23), end: at(24, 3)),
            SleepSample(sourceID: "watch", stage: .deep, start: at(24, 3), end: at(24, 4)),
            SleepSample(sourceID: "phone", stage: .unspecified, start: at(23, 23), end: at(24, 1))
        ]
        let values = HealthService.build(days: ["2026-09-24"], sleep: sleep,
                                         workouts: [(at(24, 7), 1800), (at(24, 18), 1200)],
                                         heart: [(at(23, 8), 60), (at(24, 8), 57)], keys: keys)
        #expect(values.count == 1)
        #expect(values[0].sleep.core == 240)
        #expect(values[0].sleep.deep == 60)
        #expect(values[0].workoutMinutes == 50)
        #expect(values[0].workoutCount == 2)
        #expect(values[0].restingHR == 57)
    }
}

extension StoreFixture {
    nonisolated static var keysNonisolated: DayKeys {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        cal.firstWeekday = 2
        return DayKeys(calendar: cal)
    }
}
