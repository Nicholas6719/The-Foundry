import SwiftUI
import SwiftData

/// iPhone shell: the current tab, the custom tab bar, and the covers on top.
struct RootView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        @Bindable var router = env.router
        NavigationStack {
            screen(for: router.tab)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(isPresented: $router.showRank) {
                    RankScreen()
                        .toolbar(.hidden, for: .navigationBar)
                }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FoundryTabBar(selection: $router.tab) { router.showRank = false }
        }
        .background(Palette.bg.ignoresSafeArea())
        .overlay(alignment: .top) { CelebrationOverlay() }
        .fullScreenCover(isPresented: $router.showIsland) {
            IslandScreen { router.showIsland = false }
                .environment(env)
        }
        .sheet(isPresented: $router.showSettings) {
            SettingsView()
                .environment(env)
                .modelContainer(env.container)
        }
        .fullScreenCover(isPresented: onboardingBinding) {
            OnboardingView()
                .environment(env)
                .modelContainer(env.container)
        }
    }

    @ViewBuilder
    private func screen(for tab: AppTab) -> some View {
        switch tab {
        case .foundry: HubScreen()
        case .list: ListScreen()
        case .quiver: QuiverScreen()
        case .train: TrainScreen()
        case .vitals: VitalsScreen()
        }
    }

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { _ = env.store.revision; return !env.store.profile().hasOnboarded },
            set: { _ in }
        )
    }
}
