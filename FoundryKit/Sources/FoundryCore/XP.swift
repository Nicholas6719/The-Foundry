import Foundation

public enum XPKind: String, Sendable, CaseIterable, Codable {
    case bullseye
    case strike
    case focus
    case liftRecord
}

/// One entry in the XP ledger. `(kind, refKey)` is unique.
public struct XPEntry: Sendable, Hashable, Codable {
    public var kind: XPKind
    public var refKey: String
    public var dayKey: String
    public var base: Int
    public var multiplier: Double

    public init(kind: XPKind, refKey: String, dayKey: String, base: Int, multiplier: Double = 1.0) {
        self.kind = kind
        self.refKey = refKey
        self.dayKey = dayKey
        self.base = base
        self.multiplier = multiplier
    }

    public var id: String { XPLedger.id(kind, refKey) }
    public var total: Int { XPMath.total(base: base, multiplier: multiplier) }
}

public enum XPMath {
    /// Base × multiplier, floored per event.
    public static func total(base: Int, multiplier: Double) -> Int {
        Int((Double(base) * multiplier + 1e-9).rounded(.down))
    }

    /// `round(20 × minutes / 60)` for a completed session; abandoned sessions earn nothing.
    public static func focusXP(minutes: Int, completed: Bool) -> Int {
        guard completed, minutes > 0 else { return 0 }
        return Int((Double(GameRules.focusXPPerHour) * Double(minutes) / 60.0).rounded())
    }
}

/// An idempotent XP ledger. Totals always recompute from entries.
public struct XPLedger: Sendable {
    public private(set) var entries: [String: XPEntry] = [:]

    public init(entries: [XPEntry] = []) {
        for entry in entries { self.entries[entry.id] = entry }
    }

    public static func id(_ kind: XPKind, _ refKey: String) -> String { "\(kind.rawValue)|\(refKey)" }

    /// Adds the entry unless one with the same `(kind, refKey)` exists. Returns true when added.
    @discardableResult
    public mutating func award(_ entry: XPEntry) -> Bool {
        guard entries[entry.id] == nil else { return false }
        entries[entry.id] = entry
        return true
    }

    /// Removes the entry for `(kind, refKey)`. Returns true when something was removed.
    @discardableResult
    public mutating func revoke(_ kind: XPKind, refKey: String) -> Bool {
        entries.removeValue(forKey: Self.id(kind, refKey)) != nil
    }

    /// Re-applies a day's multiplier to every entry on that day.
    public mutating func setMultiplier(_ multiplier: Double, forDay dayKey: String) {
        for (id, entry) in entries where entry.dayKey == dayKey {
            entries[id]?.multiplier = multiplier
        }
    }

    public func contains(_ kind: XPKind, refKey: String) -> Bool {
        entries[Self.id(kind, refKey)] != nil
    }

    public var total: Int { entries.values.reduce(0) { $0 + $1.total } }

    public func total(onDay dayKey: String) -> Int {
        entries.values.filter { $0.dayKey == dayKey }.reduce(0) { $0 + $1.total }
    }
}
