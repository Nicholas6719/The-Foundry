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
    /// Bumped to ask the List to open its "new name" sheet (⌘N).
    var newTargetRequests = 0
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

    // MARK: - Actions with feedback (haptics, moments)

    func fire(_ habit: Habit) {
        let result = store.fire(habit)
        switch result {
        case .bullseye:
            celebrations.hold(for: 1.4)
            bullseyePulse += 1
            Haptics.success()
        case .fired:
            Haptics.fire()
        case .ignored:
            break
        }
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
        store.refreshToday()
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
