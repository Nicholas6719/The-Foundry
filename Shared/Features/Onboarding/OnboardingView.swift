import SwiftUI
import FoundryCore

/// First run: welcome → starting habits → Connect Health → Focus setup → the hub.
struct OnboardingView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var page = 0
    @State private var names: [String] = FoundryStore.defaultHabits.map(\.0)
    @State private var showFocusSetup = false

    private var pages: [Int] {
        env.health.isAvailable ? [0, 1, 2, 3] : [0, 1, 3]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(pages, id: \.self) { p in
                    Capsule().fill(p <= page ? Palette.accent : Palette.line).frame(height: 4)
                }
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.top, 16)
            .accessibilityHidden(true)
            ScrollView {
                Group {
                    switch page {
                    case 0: welcome
                    case 1: habitsPage
                    case 2: healthPage
                    default: focusPage
                    }
                }
                .padding(Metrics.screenPadding)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .transition(.opacity)
            }
        }
        .background(Palette.bg.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.25), value: page)
        .sheet(isPresented: $showFocusSetup) {
            FocusSetupView { showFocusSetup = false; finish() }
                .environment(env)
                .presentationBackground(Palette.bg)
        }
    }

    private var welcome: some View {
        VStack(spacing: 24) {
            HexBadge(content: .emblem, size: 120, label: "The Foundry")
                .padding(.top, 48)
            Text("THE FOUNDRY").condensed(52, tracking: 0.1).foregroundStyle(Palette.text)
            Text("Check in every day. Strike names off the List, fire your habits into the target, climb the ladder, hold the Island.")
                .body(18)
                .foregroundStyle(Palette.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button("ENTER") { page = 1 }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 12)
        }
    }

    private var habitsPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            MonoTitle(text: "YOUR QUIVER")
            Text("Four daily arrows to start. Rename any of them; you can change them later in Settings.")
                .body(17).foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(names.indices, id: \.self) { i in
                HStack(spacing: 14) {
                    HabitGlyphView(glyph: FoundryStore.defaultHabits[i].1, size: 24, color: Palette.accent)
                        .frame(width: 48, height: 48)
                        .background(Palette.surface2, in: Circle())
                    TextField("", text: $names[i], prompt: Text("Habit").foregroundStyle(Palette.lineDim))
                        .condensed(24, tracking: 0.06)
                        .foregroundStyle(Palette.text)
                        .accessibilityLabel("Habit \(i + 1)")
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 64)
                .card(radius: 14)
            }
            Text("Train fires itself after a workout. Sleep fires itself after 7 hours.")
                .body(14).foregroundStyle(Palette.textMuted)
            Button("NEXT") {
                let items = zip(names, FoundryStore.defaultHabits.map(\.1)).map { ($0, $1) }
                env.store.seedHabits(items)
                page = env.health.isAvailable ? 2 : 3
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var healthPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            MonoTitle(text: "VITALS")
            Text("CONNECT HEALTH").condensed(40, tracking: 0.06).foregroundStyle(Palette.text)
            Text("Foundry reads your sleep, workouts, and resting heart rate to show your Vitals and power your Recovery bonus. Nothing leaves your devices except your own private iCloud.")
                .body(17).foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            Button("CONNECT HEALTH") {
                Task {
                    await env.health.requestAccess()
                    page = 3
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            Button("SKIP FOR NOW") { page = 3 }
                .buttonStyle(SecondaryButtonStyle(tint: Palette.textMuted, stroke: Palette.line))
        }
    }

    private var focusPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            MonoTitle(text: "THE ISLAND")
            Text("FOUNDRY FOCUS").condensed(40, tracking: 0.06).foregroundStyle(Palette.text)
            Text("Island sessions can switch on a Foundry Focus so only Favorites get through. It takes two small Shortcuts. You can do it now or later in Settings.")
                .body(17).foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            Button("SET UP FOCUS") {
                env.store.defaults.set(true, forKey: DefaultsKey.focusWizardOffered)
                showFocusSetup = true
            }
            .buttonStyle(PrimaryButtonStyle())
            Button("LATER") { finish() }
                .buttonStyle(SecondaryButtonStyle(tint: Palette.textMuted, stroke: Palette.line))
        }
    }

    private func finish() {
        env.store.defaults.set(true, forKey: DefaultsKey.focusWizardOffered)
        env.store.profile().hasOnboarded = true
        env.store.refreshToday()
        env.store.save()
    }
}
