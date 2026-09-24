import CoreData
import Foundation
import SwiftData
import FoundryCore

enum AppTab: String, CaseIterable, Identifiable {
    case foundry, list, quiver, train, vitals

    var id: String { rawValue }

    var title: String {
        switch self {
        case .foundry: "Foundry"
        case .list: "List"
        case .quiver: "Quiver"
        case .train: "Train"
        case .vitals: "Vitals"
        }
    }

    var accessibilityName: String {
        switch self {
        case .foundry: "Foundry"
        case .list: "The List"
        case .quiver: "The Quiver"
        case .train: "Training"
        case .vitals: "Vitals"
        }
    }

    var glyph: Glyph {
        switch self {
        case .foundry: .emblem
        case .list: .notebook
        case .quiver: .quiver
        case .train: .ladder
        case .vitals: .pulse
        }
    }
}

/// Mac sidebar sections, in ⌘1…⌘7 order.
enum MacSection: String, CaseIterable, Identifiable {
    case foundry, list, quiver, train, vitals, island, rank

    var id: String { rawValue }

    var title: String {
        switch self {
        case .foundry: "Foundry"
        case .list: "The List"
        case .quiver: "The Quiver"
        case .train: "Training"
        case .vitals: "Vitals"
        case .island: "The Island"
        case .rank: "Rank"
        }
    }

    var glyph: Glyph {
        switch self {
        case .foundry: .emblem
        case .list: .notebook
        case .quiver: .quiver
        case .train: .ladder
        case .vitals: .pulse
        case .island: .crosshair
        case .rank: .chevrons
        }
    }
}

/// Where the user is, shared by both apps and the menu bar.
@Observable
final class Router {
    var tab: AppTab = .foundry
    var showRank = false
    var showIsland = false
    var showSettings = false
    var macSection: MacSection = .foundry
    /// Asks the List to open its "new name" sheet (⌘N) as soon as it is on screen.
    var pendingNewTarget = false

    func requestNewTarget() {
        #if os(macOS)
        macSection = .list
        #else
        tab = .list
        #endif
        pendingNewTarget = true
    }
    /// Set when the Island should begin a session as soon as it appears.
    var autoStartIsland = false

    func openIsland(start: Bool, island: IslandController) {
        if start, !island.isActive { autoStartIsland = true }
        #if os(macOS)
        macSection = .island
        #else
        showIsland = true
        #endif
    }
}

/// Owns the long-lived services. One per process.
@Observable
final class AppEnvironment {
    static let shared = AppEnvironment()

    let container: ModelContainer
    let syncState: PersistenceController.SyncState
    let celebrations = CelebrationCenter()
    let store: FoundryStore
    let clock = DayClock()
    let focus = FocusService()
    let health: HealthService
    let island: IslandController
    let router = Router()
    /// Bumps on each bullseye so the hub emblem can pulse.
    private(set) var bullseyePulse = 0
    @ObservationIgnored private var remoteChangeObserver: NSObjectProtocol?
    @ObservationIgnored private var remoteRefreshTask: Task<Void, Never>?
    /// With iCloud on, first-run onboarding waits briefly for another device's data to arrive,
    /// so a second device doesn't seed a duplicate set of habits.
    private(set) var syncGraceOver: Bool

    // MARK: - Actions with feedback (haptics, moments)

    func fire(_ habit: Habit) {
        // A bullseye plays its own moment through `store.onBullseye`.
        if store.fire(habit) == .fired { Haptics.fire() }
    }

    /// The bullseye moment: ring completes, emblem pulses, success haptic, toasts wait their turn.
    private func bullseyeMoment() {
        guard celebrations.isEnabled else { return }
        celebrations.hold(for: 1.4)
        bullseyePulse += 1
        Haptics.success()
    }

    func undo(_ habit: Habit) {
        store.undo(habit)
        Haptics.light()
    }

    func toggleStrike(_ target: Target) {
        if target.isStruck {
            store.restore(target)
            Haptics.light()
        } else {
            store.strike(target)
            Haptics.success()
        }
    }

    @discardableResult
    func logSet(_ lift: LiftDef, index: Int, reps: Int? = nil) -> LiftLogResult {
        let result = store.logSet(lift, index: index, reps: reps)
        if result.climbed || result.sessionCompleted {
            Haptics.success()
        } else {
            Haptics.fire()
        }
        return result
    }

    func clearSet(_ lift: LiftDef, index: Int) {
        store.clearSet(lift, index: index)
        Haptics.light()
    }

    private init() {
        FoundryFont.registerAll()
        let inMemory = ProcessInfo.processInfo.arguments.contains("-FoundryInMemory")
        (container, syncState) = PersistenceController.makeContainer(inMemory: inMemory)
        syncGraceOver = syncState != .iCloud
        store = FoundryStore(context: container.mainContext, celebrations: celebrations)
        health = HealthService(store: store)
        island = IslandController(store: store, focus: focus)

        let profile = store.profile()
        focus.isConfigured = profile.focusShortcutsConfigured
        focus.onConfigured = { [store] in
            store.profile().focusShortcutsConfigured = true
            store.save()
        }
        clock.onDayChange = { [store] in store.refreshToday() }
        if store.defaults.object(forKey: DefaultsKey.lastCelebratedRank) == nil { store.markRankSeen() }
        applyLaunchArguments()
        store.onBullseye = { [weak self] in self?.bullseyeMoment() }
        store.refreshToday()
        health.startObserving()
        observeRemoteChanges()
        if !syncGraceOver {
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(8))
                self?.syncGraceOver = true
            }
        }
    }

    /// First run, once any synced profile from another device has had a chance to arrive.
    var needsOnboarding: Bool {
        _ = store.revision
        return syncGraceOver && !store.profile().hasOnboarded
    }

    /// iCloud delivered changes from another device: recompute today and redraw.
    private func observeRemoteChanges() {
        guard syncState == .iCloud else { return }
        remoteChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleRemoteRefresh() }
        }
    }

    /// Imports arrive in bursts; refresh once they settle.
    private func scheduleRemoteRefresh() {
        remoteRefreshTask?.cancel()
        remoteRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled, let self else { return }
            self.store.resolveSyncDuplicates()
            self.store.refreshToday()
            self.store.touch()
        }
    }

    /// Foreground: roll the day, catch a finished Island session, pull fresh Health data.
    func becameActive() {
        clock.tick()
        store.refreshToday()
        island.checkCompletion()
        Task { await health.refresh() }
    }

    func handle(_ url: URL) {
        if focus.handle(url) { return }
        if url.scheme == "foundry", url.host == "island" {
            router.openIsland(start: false, island: island)
        }
    }

    private func applyLaunchArguments() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-FoundryDemoData") {
            DemoData.load(into: store)
        }
        if let i = args.firstIndex(of: "-FoundryTab"), i + 1 < args.count {
            let value = args[i + 1]
            if let tab = AppTab(rawValue: value) { router.tab = tab }
            if let section = MacSection(rawValue: value) { router.macSection = section }
            if value == "rank" { router.showRank = true }
            if value == "island" { router.showIsland = true }
            if value == "settings" { router.showSettings = true }
        }
        if args.contains("-FoundryStartIsland") { island.start() }
        #endif
    }
}
