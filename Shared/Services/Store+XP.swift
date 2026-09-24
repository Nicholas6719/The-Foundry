import Foundation
import SwiftData
import FoundryCore

extension FoundryStore {
    // MARK: - Ledger

    func events(_ kind: XPKind, refKey: String) -> [XPEvent] {
        let k = kind.rawValue
        return fetch(FetchDescriptor<XPEvent>(predicate: #Predicate { $0.kind == k && $0.refKey == refKey }))
    }

    /// Awards XP once per `(kind, refKey)`. Re-triggering does nothing.
    @discardableResult
    func award(_ kind: XPKind, refKey: String, base: Int, dayKey: String) -> Bool {
        guard base > 0, events(kind, refKey: refKey).isEmpty else { return false }
        let multiplier = RecoveryRules.multiplier(for: vitals(for: dayKey)?.recovery)
        let event = XPEvent(dayKey: dayKey, kind: kind.rawValue, refKey: refKey, base: base,
                            multiplier: multiplier, total: XPMath.total(base: base, multiplier: multiplier),
                            createdAt: now())
        context.insert(event)
        checkRankUp()
        return true
    }

    /// Removes the XP for `(kind, refKey)`, if any.
    @discardableResult
    func revoke(_ kind: XPKind, refKey: String) -> Bool {
        let found = events(kind, refKey: refKey)
        found.forEach(context.delete)
        return !found.isEmpty
    }

    /// Re-applies the day's recovery multiplier to every event on that day.
    func applyMultiplier(forDay dayKey: String) {
        let multiplier = RecoveryRules.multiplier(for: vitals(for: dayKey)?.recovery)
        let dayEvents = fetch(FetchDescriptor<XPEvent>(predicate: #Predicate { $0.dayKey == dayKey }))
        for event in dayEvents where event.multiplier != multiplier {
            event.multiplier = multiplier
            event.total = XPMath.total(base: event.base, multiplier: multiplier)
        }
        checkRankUp()
    }

    var totalXP: Int { all(XPEvent.self).dedupedTotal }

    // MARK: - Rank-ups

    /// Celebrates the first time each rank is reached.
    func checkRankUp() {
        let rank = Rank.forXP(totalXP)
        let seen = defaults.object(forKey: DefaultsKey.lastCelebratedRank) as? Int ?? 0
        if rank.rawValue > seen {
            defaults.set(rank.rawValue, forKey: DefaultsKey.lastCelebratedRank)
            celebrations.enqueue(.rankUp(rank))
        }
    }

    /// Marks the current rank as already celebrated (after demo data or a reset).
    func markRankSeen() {
        defaults.set(Rank.forXP(totalXP).rawValue, forKey: DefaultsKey.lastCelebratedRank)
    }

    // MARK: - Medals

    func medalStats() -> MedalStats {
        let focusByDay = Dictionary(grouping: all(FocusSession.self).filter(\.completed)) {
            keys.key(for: $0.startedAt)
        }.mapValues(\.count)
        let strikes = Set(all(XPEvent.self).filter { $0.kind == XPKind.strike.rawValue }.map(\.refKey)).count
        return MedalStats(
            bullseyeDays: all(DaySummary.self).bullseyeDays,
            highestRung: all(LiftDef.self).map(\.currentRung).max() ?? 0,
            sleepByDay: all(DailyVitals.self).byDay.mapValues(\.sleepMinutes),
            sleepGoalMinutes: profile().sleepGoalMinutes,
            focusSessionsByDay: focusByDay,
            namesStruck: strikes
        )
    }

    /// Unlocks any newly earned medals. Unlocks are permanent.
    func evaluateMedals() {
        let earned = MedalRules.earned(medalStats(), keys: keys)
        let unlocked = Set(all(MedalUnlock.self).map(\.medalID))
        for medal in MedalID.allCases where earned.contains(medal) && !unlocked.contains(medal.rawValue) {
            context.insert(MedalUnlock(medalID: medal.rawValue, unlockedAt: now()))
            celebrations.enqueue(.medal(medal))
        }
    }
}
