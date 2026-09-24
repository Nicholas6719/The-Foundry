import SwiftUI
#if os(iOS)
import HealthKit
import HealthKitUI
#endif

/// Shows Apple Health's permission sheet when `trigger` changes.
///
/// Uses SwiftUI's `healthDataAccessRequest`, which presents from the view it's attached to.
/// Asking HealthKit directly presents from the root window, which stays invisible when the
/// request comes from onboarding or a sheet.
struct HealthAccessRequest: ViewModifier {
    var trigger: Int
    var onDone: @MainActor () -> Void = {}

    @Environment(AppEnvironment.self) private var env

    func body(content: Content) -> some View {
        #if os(iOS)
        let health = env.health
        let done = onDone
        content.healthDataAccessRequest(store: health.healthStore, readTypes: health.readTypes, trigger: trigger) { result in
            Task { @MainActor in
                await health.accessRequestFinished(result)
                done()
            }
        }
        #else
        content
        #endif
    }
}

extension View {
    /// Asks for Health access each time `trigger` changes (increment it from a button).
    func healthAccessRequest(trigger: Int, onDone: @escaping @MainActor () -> Void = {}) -> some View {
        modifier(HealthAccessRequest(trigger: trigger, onDone: onDone))
    }
}
