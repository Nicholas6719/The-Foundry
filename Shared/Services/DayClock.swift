import Foundation
import FoundryCore

/// Publishes the current day so screens roll over at midnight.
@Observable
final class DayClock {
    private(set) var todayKey: String
    private(set) var now: Date
    let keys: DayKeys
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored var onDayChange: (() -> Void)?

    init(keys: DayKeys = DayKeys()) {
        self.keys = keys
        let date = Date()
        now = date
        todayKey = keys.key(for: date)
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                self?.tick()
            }
        }
    }

    /// Call on foreground and on system clock changes too.
    func tick() {
        now = Date()
        let key = keys.key(for: now)
        if key != todayKey {
            todayKey = key
            onDayChange?()
        }
    }
}
