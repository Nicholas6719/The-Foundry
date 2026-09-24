import Foundation

public enum Rank: Int, Sendable, CaseIterable, Comparable, Codable {
    case castaway = 0
    case vigilante
    case hood
    case greenArrow

    public static func < (a: Rank, b: Rank) -> Bool { a.rawValue < b.rawValue }

    public var threshold: Int {
        switch self {
        case .castaway: 0
        case .vigilante: GameRules.vigilanteXP
        case .hood: GameRules.hoodXP
        case .greenArrow: GameRules.greenArrowXP
        }
    }

    /// Uppercase display title, e.g. `GREEN ARROW`.
    public var title: String {
        switch self {
        case .castaway: "CASTAWAY"
        case .vigilante: "VIGILANTE"
        case .hood: "HOOD"
        case .greenArrow: "GREEN ARROW"
        }
    }

    /// Short label for the rank path, where space is tight.
    public var shortTitle: String {
        self == .greenArrow ? "ARROW" : title
    }

    public var next: Rank? { Rank(rawValue: rawValue + 1) }

    public static func forXP(_ xp: Int) -> Rank {
        allCases.last { xp >= $0.threshold } ?? .castaway
    }
}

public struct RankProgress: Sendable, Equatable {
    public let rank: Rank
    public let xp: Int
    /// XP needed for the next rank, or nil at the top rank.
    public let nextThreshold: Int?
    /// 0...1 progress through the current rank band (1 at the top rank).
    public let fraction: Double

    public init(xp: Int) {
        let xp = max(0, xp)
        let rank = Rank.forXP(xp)
        self.rank = rank
        self.xp = xp
        if let next = rank.next {
            nextThreshold = next.threshold
            let span = Double(next.threshold - rank.threshold)
            fraction = min(1, max(0, Double(xp - rank.threshold) / span))
        } else {
            nextThreshold = nil
            fraction = 1
        }
    }
}
