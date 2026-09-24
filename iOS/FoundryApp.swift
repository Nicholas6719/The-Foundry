import SwiftUI
import SwiftData

@main
struct FoundryApp: App {
    @State private var env = AppEnvironment.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(env)
                .modelContainer(env.container)
                .preferredColorScheme(.dark)
                .tint(Palette.accent)
                .onOpenURL { env.handle($0) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { env.becameActive() }
        }
    }
}
