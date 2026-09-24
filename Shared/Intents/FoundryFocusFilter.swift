import AppIntents
import Foundation

/// "Foundry behavior" Focus Filter. Add it to the Foundry Focus in Settings › Focus.
///
/// On iPhone it also conforms to `LiveActivityIntent` so the system runs it inside the app process even when
/// the app is closed (no extension target needed). When the Focus turns off the system
/// calls `perform()` again with default values.
struct FoundryFocusFilter: SetFocusFilterIntent {
    static let title: LocalizedStringResource = "Foundry behavior"
    static let description: IntentDescription? = IntentDescription("Choose what Foundry does when this Focus turns on.")

    @Parameter(title: "Start the Island when this Focus turns on", default: false)
    var startIslandWhenOn: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: startIslandWhenOn ? "Starts the Island" : "Foundry Focus")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let env = AppEnvironment.shared
        // The "off" call arrives with default values, so only a `true` means the Focus just turned on.
        if startIslandWhenOn {
            UserDefaults.standard.set(Date(), forKey: DefaultsKey.focusFilterActive)
            env.focus.filterReported(active: true)
            env.store.profile().focusAutoStartFromFilter = true
            env.store.save()
            if !env.island.isActive { env.island.start() }
        }
        Log.focus.info("Focus filter performed, startIsland=\(startIslandWhenOn)")
        return .result()
    }
}

#if os(iOS)
extension FoundryFocusFilter: LiveActivityIntent {}
#endif
