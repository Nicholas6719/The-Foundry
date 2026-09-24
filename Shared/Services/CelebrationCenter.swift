import Foundation
import FoundryCore

enum Celebration: Equatable, Identifiable {
    case rankUp(Rank)
    case medal(MedalID)

    var id: String {
        switch self {
        case .rankUp(let rank): "rank-\(rank.rawValue)"
        case .medal(let medal): "medal-\(medal.rawValue)"
        }
    }

    var eyebrow: String {
        switch self {
        case .rankUp: "RANK UP"
        case .medal: "MEDAL EARNED"
        }
    }

    var title: String {
        switch self {
        case .rankUp(let rank): rank.title
        case .medal(let medal): medal.title
        }
    }
}

/// Queues one-time rank and medal celebrations and shows them one at a time.
@Observable
final class CelebrationCenter {
    private(set) var current: Celebration?
    private var queue: [Celebration] = []
    private var holdUntil = Date.distantPast
    @ObservationIgnored private var task: Task<Void, Never>?
    /// Off while demo data loads so a seeded history does not trigger a parade.
    var isEnabled = true

    func enqueue(_ celebration: Celebration) {
        guard isEnabled, current != celebration, !queue.contains(celebration) else { return }
        queue.append(celebration)
        pump()
    }

    /// Lets a moment (the bullseye) play before toasts appear.
    func hold(for seconds: TimeInterval) {
        holdUntil = max(holdUntil, Date().addingTimeInterval(seconds))
    }

    func dismissCurrent() {
        current = nil
        pump()
    }

    private func pump() {
        guard task == nil, current == nil, !queue.isEmpty else { return }
        task = Task { [weak self] in
            guard let self else { return }
            let wait = self.holdUntil.timeIntervalSinceNow
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            guard !self.queue.isEmpty else { self.task = nil; return }
            self.current = self.queue.removeFirst()
            try? await Task.sleep(for: .seconds(2.8))
            self.current = nil
            try? await Task.sleep(for: .seconds(0.35))
            self.task = nil
            self.pump()
        }
    }
}
