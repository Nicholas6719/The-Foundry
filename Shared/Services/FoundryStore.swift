import Foundation
import SwiftData
import FoundryCore

/// The one gateway for changing data. Views read with `@Query` and write through here,
/// so XP, streaks, medals and summaries always stay in step.
@Observable
final class FoundryStore {
    let context: ModelContext
    let keys: DayKeys
    let celebrations: CelebrationCenter
    let defaults: UserDefaults
    @ObservationIgnored var now: () -> Date
    /// Bumps after every save or remote change. Views read it to recompute derived numbers.
    private(set) var revision = 0

    init(context: ModelContext, keys: DayKeys = DayKeys(), celebrations: CelebrationCenter,
         defaults: UserDefaults = .standard, now: @escaping () -> Date = { Date() }) {
        self.context = context
        self.keys = keys
        self.celebrations = celebrations
        self.defaults = defaults
        self.now = now
    }

    var todayKey: String { keys.key(for: now()) }

    // MARK: - Fetch helpers

    func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            Log.data.error("Fetch failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func all<T: PersistentModel>(_ type: T.Type) -> [T] {
        fetch(FetchDescriptor<T>())
    }

    func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            Log.data.error("Save failed: \(error.localizedDescription, privacy: .public)")
        }
        revision += 1
    }

    /// Marks derived numbers stale (for example after iCloud delivers changes).
    func touch() { revision += 1 }

    /// Today's numbers, recomputed whenever data changes.
    func liveSnapshot() -> TodaySnapshot {
        _ = revision
        return snapshot()
    }

    // MARK: - Profile

    /// The singleton profile. Sync can briefly produce two; the first one wins and flags merge.
    @discardableResult
    func profile() -> Profile {
        let profiles = all(Profile.self)
        if let first = profiles.first {
            for extra in profiles.dropFirst() {
                first.hasOnboarded = first.hasOnboarded || extra.hasOnboarded
                first.healthEnabled = first.healthEnabled || extra.healthEnabled
                first.focusShortcutsConfigured = first.focusShortcutsConfigured || extra.focusShortcutsConfigured
                context.delete(extra)
            }
            return first
        }
        let profile = Profile()
        context.insert(profile)
        save()
        return profile
    }

    /// Called when a goal changes: re-scores every night and re-applies multipliers.
    func goalsChanged() {
        let goal = profile().sleepGoalMinutes
        for vitals in all(DailyVitals.self) {
            vitals.recovery = RecoveryRules.score(vitals.sleep, goalMinutes: goal)
            applyMultiplier(forDay: vitals.dayKey)
        }
        evaluateMedals()
        save()
    }

    /// Runs when the app becomes active or the day rolls over.
    func refreshToday() {
        profile()
        updateDaySummary(for: todayKey)
        autoFireEligibleHabits()
        evaluateMedals()
        save()
    }

    // MARK: - Reset (Settings, DEBUG)

    func deleteEverything() {
        for type in FoundrySchemaV1.models {
            deleteAll(type)
        }
        for key in [DefaultsKey.trainOverride, DefaultsKey.suppressedAuto, DefaultsKey.lastCelebratedRank] {
            defaults.removeObject(forKey: key)
        }
        save()
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) {
        do {
            try context.delete(model: type)
        } catch {
            Log.data.error("Delete-all failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

enum DefaultsKey {
    static let trainOverride = "foundry.trainOverride"
    static let suppressedAuto = "foundry.suppressedAuto"
    static let lastCelebratedRank = "foundry.lastCelebratedRank"
    static let healthRequested = "foundry.healthRequested"
    static let healthLastSync = "foundry.healthLastSync"
    static let islandState = "foundry.islandState"
    static let notificationsAsked = "foundry.notificationsAsked"
    static let focusFilterActive = "foundry.focusFilterActive"
    static let focusWizardOffered = "foundry.focusWizardOffered"
}
