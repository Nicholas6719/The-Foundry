import Foundation
import SwiftData
import FoundryCore

extension FoundryStore {
    func targets() -> [Target] {
        let all = all(Target.self)
        let byID = Dictionary(all.map { ($0.id.uuidString, $0) }, uniquingKeysWith: { a, _ in a })
        return TargetOrdering.sorted(all.map(\.snapshot)).compactMap { byID[$0.id] }
    }

    func openPrimary() -> Target? {
        all(Target.self).first { $0.isPrimary && !$0.isStruck }
    }

    @discardableResult
    func addTarget(title: String, dueDate: Date?, primary: Bool) -> Target? {
        let clean = Self.cleanTitle(title)
        guard !clean.isEmpty else { return nil }
        let target = Target(title: clean, dueDate: dueDate, isPrimary: false, createdAt: now())
        context.insert(target)
        if primary { makePrimary(target) }
        save()
        return target
    }

    func update(_ target: Target, title: String, dueDate: Date?, primary: Bool) {
        let clean = Self.cleanTitle(title)
        if !clean.isEmpty { target.title = clean }
        target.dueDate = dueDate
        if primary {
            makePrimary(target)
        } else {
            target.isPrimary = false
        }
        save()
    }

    /// Only one primary at a time.
    func makePrimary(_ target: Target) {
        for other in all(Target.self) where other.isPrimary && other.id != target.id {
            other.isPrimary = false
        }
        target.isPrimary = true
    }

    func strike(_ target: Target) {
        guard !target.isStruck else { return }
        target.struckAt = now()
        award(.strike, refKey: target.id.uuidString, base: GameRules.strikeXP, dayKey: todayKey)
        evaluateMedals()
        save()
    }

    func restore(_ target: Target) {
        guard target.isStruck else { return }
        target.struckAt = nil
        revoke(.strike, refKey: target.id.uuidString)
        save()
    }

    /// Deleting keeps XP already earned for striking it.
    func delete(_ target: Target) {
        context.delete(target)
        save()
    }

    func dueTodayCount() -> Int {
        TargetOrdering.dueTodayOrOverdue(all(Target.self).map(\.snapshot), now: now(), keys: keys)
    }

    static func cleanTitle(_ title: String) -> String {
        String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(GameRules.targetTitleMaxLength))
    }
}
