import Foundation
import SwiftData
import FoundryCore

enum FireResult: Equatable {
    case fired
    case bullseye
    case ignored
}

extension FoundryStore {
    // MARK: - Reads

    func activeHabits() -> [Habit] {
        fetch(FetchDescriptor<Habit>(predicate: #Predicate { !$0.isArchived }, sortBy: [SortDescriptor(\.sortOrder)]))
    }

    func logs(on dayKey: String) -> [HabitLog] {
        fetch(FetchDescriptor<HabitLog>(predicate: #Predicate { $0.dayKey == dayKey }))
    }

    func isFired(_ habit: Habit, on dayKey: String) -> Bool {
        logs(on: dayKey).contains { $0.habitID == habit.id }
    }

    func summary(for dayKey: String) -> DaySummary? {
        fetch(FetchDescriptor<DaySummary>(predicate: #Predicate { $0.dayKey == dayKey }))
            .max { $0.habitsDone < $1.habitsDone }
    }

    // MARK: - Fire / undo

    @discardableResult
    func fire(_ habit: Habit, source: LogSource = .manual) -> FireResult {
        let today = todayKey
        guard !habit.isArchived, !isFired(habit, on: today) else { return .ignored }
        context.insert(HabitLog(habitID: habit.id, dayKey: today, firedAt: now(), source: source.rawValue))
        if source == .manual { setSuppressed(false, habit: habit, day: today) }
        let becameBullseye = updateDaySummary(for: today)
        evaluateMedals()
        save()
        return becameBullseye ? .bullseye : .fired
    }

    func undo(_ habit: Habit) {
        let today = todayKey
        let mine = logs(on: today).filter { $0.habitID == habit.id }
        guard !mine.isEmpty else { return }
        // An undone habit stays undone for the day; auto rules will not re-fire it.
        setSuppressed(true, habit: habit, day: today)
        mine.forEach(context.delete)
        updateDaySummary(for: today)
        save()
    }

    /// Recomputes a day's summary and keeps the bullseye XP in step. Returns true when the day just became a bullseye.
    @discardableResult
    func updateDaySummary(for dayKey: String) -> Bool {
        let habits = activeHabits()
        let firedIDs = Set(logs(on: dayKey).map(\.habitID))
        let done = habits.filter { firedIDs.contains($0.id) }.count
        // Synced copies of the same day are all kept in step rather than deleted, so two devices
        // can never remove each other's history.
        var summaries = fetch(FetchDescriptor<DaySummary>(predicate: #Predicate { $0.dayKey == dayKey }))
        if summaries.isEmpty {
            let s = DaySummary(dayKey: dayKey)
            context.insert(s)
            summaries = [s]
        }
        let was = summaries.contains(where: \.isBullseye)
        let isBullseye = StreakRules.isBullseye(total: habits.count, done: done)
        for summary in summaries {
            summary.habitsTotal = habits.count
            summary.habitsDone = done
            summary.isBullseye = isBullseye
        }
        if isBullseye {
            award(.bullseye, refKey: dayKey, base: GameRules.bullseyeXP, dayKey: dayKey)
        } else {
            revoke(.bullseye, refKey: dayKey)
        }
        let became = isBullseye && !was
        // The bullseye moment plays however the last arrow was fired (by hand or by an auto rule).
        if became, dayKey == todayKey { onBullseye?() }
        return became
    }

    /// If two devices both seeded the same starting habits before syncing, archive the copies.
    /// Every device keeps the same one (lowest id), so they agree after sync.
    func resolveSyncDuplicates() {
        let groups = Dictionary(grouping: activeHabits()) { "\($0.name.lowercased())|\($0.glyph)" }
        var changed = false
        for (_, copies) in groups where copies.count > 1 {
            for extra in copies.sorted(by: { $0.id.uuidString < $1.id.uuidString }).dropFirst() {
                extra.isArchived = true
                changed = true
            }
        }
        if changed { updateDaySummary(for: todayKey) }
    }

    // MARK: - Streak

    func currentStreak() -> Int {
        StreakRules.current(bullseyeDays: all(DaySummary.self).bullseyeDays, today: todayKey, keys: keys)
    }

    // MARK: - Auto rules

    /// Fires habits whose auto rule is satisfied today, unless the user undid them.
    func autoFireEligibleHabits() {
        let today = todayKey
        let vitals = vitals(for: today)
        let trained = todaysWorkoutDay().map { isSessionComplete($0, on: today) } ?? false
        var changed = false
        for habit in activeHabits() where habit.rule != .none && !isFired(habit, on: today) {
            guard !isSuppressed(habit: habit, day: today) else { continue }
            let eligible: Bool = switch habit.rule {
            case .none: false
            case .workout: (vitals?.longestWorkoutMin ?? 0) >= GameRules.workoutAutoFireMinutes || trained
            case .sleepDuration: (vitals?.sleepMinutes ?? 0) >= max(1, habit.autoThresholdMinutes)
            }
            if eligible {
                context.insert(HabitLog(habitID: habit.id, dayKey: today, firedAt: now(), source: LogSource.auto.rawValue))
                changed = true
            }
        }
        if changed {
            updateDaySummary(for: today)
            evaluateMedals()
            save()
        }
    }

    private func suppressedSet() -> Set<String> {
        Set(defaults.stringArray(forKey: DefaultsKey.suppressedAuto) ?? [])
    }

    private func isSuppressed(habit: Habit, day: String) -> Bool {
        suppressedSet().contains("\(habit.id.uuidString)|\(day)")
    }

    private func setSuppressed(_ on: Bool, habit: Habit, day: String) {
        var set = suppressedSet().filter { $0.hasSuffix(day) } // drop old days
        let key = "\(habit.id.uuidString)|\(day)"
        if on { set.insert(key) } else { set.remove(key) }
        defaults.set(Array(set), forKey: DefaultsKey.suppressedAuto)
    }

    // MARK: - Editing

    @discardableResult
    func addHabit(name: String, glyph: HabitGlyph, rule: AutoRule = .none, threshold: Int = 0) -> Habit? {
        let active = activeHabits()
        guard active.count < GameRules.maxHabits else { return nil }
        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(16))
        guard !clean.isEmpty else { return nil }
        let habit = Habit(name: clean, glyph: glyph.rawValue, sortOrder: (active.map(\.sortOrder).max() ?? -1) + 1,
                          autoRule: rule.rawValue, autoThresholdMinutes: threshold)
        context.insert(habit)
        habitsChanged()
        return habit
    }

    func archive(_ habit: Habit) {
        habit.isArchived = true
        habitsChanged()
    }

    func moveHabits(from source: IndexSet, to destination: Int) {
        var list = activeHabits()
        list.move(fromOffsets: source, toOffset: destination)
        for (i, habit) in list.enumerated() { habit.sortOrder = i }
        save()
    }

    /// Call after renaming, re-gluing or re-ruling a habit.
    func habitsChanged() {
        updateDaySummary(for: todayKey)
        autoFireEligibleHabits()
        evaluateMedals()
        save()
    }

    /// First-run habits. Seeded ones carry sensible auto rules.
    func seedHabits(_ names: [(String, HabitGlyph)]) {
        guard activeHabits().isEmpty else { return }
        for (i, item) in names.prefix(GameRules.maxHabits).enumerated() {
            let (rule, threshold): (AutoRule, Int) = switch item.1 {
            case .dumbbell: (.workout, 0)
            case .moon: (.sleepDuration, GameRules.defaultSleepThresholdMinutes)
            default: (.none, 0)
            }
            let name = String(item.0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(16))
            guard !name.isEmpty else { continue }
            context.insert(Habit(name: name, glyph: item.1.rawValue, sortOrder: i, autoRule: rule.rawValue,
                                 autoThresholdMinutes: threshold))
        }
        habitsChanged()
    }

    static let defaultHabits: [(String, HabitGlyph)] = [
        ("Train", .dumbbell), ("Eat", .fork), ("Read", .book), ("Sleep", .moon)
    ]
}
