import Foundation

/// The focus timer. Time is kept as an end timestamp so it stays right after backgrounding.
@Observable
final class IslandController {
    enum Phase: String, Codable { case idle, running, paused }

    private(set) var phase: Phase = .idle
    private(set) var endDate: Date?
    private(set) var pausedRemaining: TimeInterval = 0
    private(set) var plannedMinutes = 25
    private(set) var sessionID: UUID?
    /// The List name the session is for.
    var targetID: UUID?
    /// Bumps each time a session completes (drives the completion animation).
    private(set) var completions = 0

    @ObservationIgnored private let store: FoundryStore
    @ObservationIgnored private let focus: FocusService
    @ObservationIgnored private var timerTask: Task<Void, Never>?

    init(store: FoundryStore, focus: FocusService) {
        self.store = store
        self.focus = focus
        restore()
    }

    var isActive: Bool { phase != .idle }

    var totalSeconds: TimeInterval { TimeInterval(plannedMinutes * 60) }

    func remaining(at date: Date) -> TimeInterval {
        switch phase {
        case .idle: TimeInterval(store.profile().focusMinutes * 60)
        case .paused: pausedRemaining
        case .running: max(0, (endDate ?? date).timeIntervalSince(date))
        }
    }

    /// Elapsed share of the session, 0...1.
    func progress(at date: Date) -> Double {
        guard phase != .idle, totalSeconds > 0 else { return 0 }
        return min(1, max(0, 1 - remaining(at: date) / totalSeconds))
    }

    // MARK: - Controls

    func start(now: Date = Date()) {
        guard phase == .idle else { return }
        let minutes = store.profile().focusMinutes
        plannedMinutes = minutes
        if targetID == nil { targetID = store.openPrimary()?.id }
        let session = store.startFocusSession(plannedMinutes: minutes, at: now)
        sessionID = session.id
        endDate = now.addingTimeInterval(TimeInterval(minutes * 60))
        phase = .running
        persist()
        scheduleCompletion()
        NotificationService.scheduleIslandEnd(at: endDate ?? now, targetName: targetName)
        focus.sessionStarted()
    }

    func pause(now: Date = Date()) {
        guard phase == .running else { return }
        pausedRemaining = remaining(at: now)
        endDate = nil
        phase = .paused
        timerTask?.cancel()
        NotificationService.cancelIslandEnd()
        persist()
    }

    func resume(now: Date = Date()) {
        guard phase == .paused else { return }
        endDate = now.addingTimeInterval(pausedRemaining)
        phase = .running
        persist()
        scheduleCompletion()
        NotificationService.scheduleIslandEnd(at: endDate ?? now, targetName: targetName)
    }

    /// Abandons the session: no XP.
    func leave(now: Date = Date()) {
        guard phase != .idle else { return }
        if let id = sessionID, let session = store.focusSession(id: id) {
            store.finishFocusSession(session, completed: false, at: now)
        }
        reset()
        focus.sessionEnded()
    }

    /// Checks for a session that ended while the app was away.
    func checkCompletion(now: Date = Date()) {
        guard phase == .running, let endDate, now >= endDate else { return }
        complete(at: endDate)
    }

    private func complete(at date: Date) {
        if let id = sessionID, let session = store.focusSession(id: id) {
            store.finishFocusSession(session, completed: true, at: date)
        }
        reset()
        completions += 1
        Haptics.success()
        focus.sessionEnded()
    }

    private func reset() {
        timerTask?.cancel()
        timerTask = nil
        phase = .idle
        endDate = nil
        pausedRemaining = 0
        sessionID = nil
        NotificationService.cancelIslandEnd()
        persist()
    }

    private func scheduleCompletion() {
        timerTask?.cancel()
        guard let endDate else { return }
        timerTask = Task { [weak self] in
            let wait = endDate.timeIntervalSinceNow
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            guard !Task.isCancelled else { return }
            self?.checkCompletion()
        }
    }

    var targetName: String? {
        guard let targetID else { return nil }
        return store.all(Target.self).first { $0.id == targetID }?.title
    }

    // MARK: - Persistence across launches

    private struct Saved: Codable {
        var phase: Phase
        var endDate: Date?
        var pausedRemaining: TimeInterval
        var plannedMinutes: Int
        var sessionID: UUID?
        var targetID: UUID?
    }

    private func persist() {
        let saved = Saved(phase: phase, endDate: endDate, pausedRemaining: pausedRemaining,
                          plannedMinutes: plannedMinutes, sessionID: sessionID, targetID: targetID)
        if let data = try? JSONEncoder().encode(saved) {
            store.defaults.set(data, forKey: DefaultsKey.islandState)
        }
    }

    private func restore() {
        guard let data = store.defaults.data(forKey: DefaultsKey.islandState),
              let saved = try? JSONDecoder().decode(Saved.self, from: data) else { return }
        phase = saved.phase
        endDate = saved.endDate
        pausedRemaining = saved.pausedRemaining
        plannedMinutes = saved.plannedMinutes
        sessionID = saved.sessionID
        targetID = saved.targetID
        if phase == .running {
            scheduleCompletion()
        }
    }
}
