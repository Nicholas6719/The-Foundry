import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

/// The Island: a focus session with the Foundry Focus switched on.
struct IslandScreen: View {
    var isWindow = false
    var onClose: () -> Void

    @Environment(AppEnvironment.self) private var env
    @Query private var targets: [Target]
    @State private var askNotifications = false
    @State private var showFocusSetup = false
    @State private var flash = false
    #if os(macOS)
    @State private var activity: NSObjectProtocol?
    #endif

    var body: some View {
        let island = env.island
        let profile = env.store.profile()
        let doneToday = env.store.completedFocusCount(on: env.clock.todayKey)
        let open = targets.filter { !$0.isStruck }.sorted { $0.isPrimary && !$1.isPrimary }
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 0) {
                HStack {
                    HexBadge(content: .glyph(.crosshair), label: "The Island")
                    Spacer()
                    FocusPill(pill: env.focus.pill) { showFocusSetup = true }
                }
                Spacer(minLength: 20)
                VStack(spacing: 20) {
                    IslandRing(progress: island.progress(at: context.date), active: island.isActive,
                               diameter: isWindow ? 320 : 264) {
                        VStack(spacing: 4) {
                            Text(Clock.text(island.remaining(at: context.date)))
                                .font(FoundryFont.fixed(.monoMedium, size: isWindow ? 64 : 56))
                                .tracking(1)
                                .foregroundStyle(Palette.text)
                                .monospacedDigit()
                                .accessibilityLabel("\(Int(island.remaining(at: context.date) / 60)) minutes left")
                            SessionDots(done: doneToday, goal: profile.focusSessionsGoal)
                        }
                        .scaleEffect(flash ? 1.06 : 1)
                    }
                    targetPicker(open: open)
                }
                Spacer(minLength: 20)
                VStack(spacing: 10) {
                    IslandStatusRow(icon: "phone", text: "Favorites can still call", tint: Palette.accent)
                    IslandStatusRow(icon: "bell.slash", text: "Everything else muted", tint: Palette.textMuted)
                    IslandStatusRow(icon: "cellularbars", text: "Signal stays on", tint: Palette.accent)
                    controls
                        .padding(.top, 6)
                }
                .frame(maxWidth: 520)
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.top, isWindow ? 28 : 12)
            .padding(.bottom, isWindow ? 28 : 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Palette.bgDeep.ignoresSafeArea())
        .onAppear(perform: appeared)
        .onDisappear(perform: disappeared)
        .onChange(of: island.completions) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { flash = true }
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) { flash = false }
        }
        .alert("One ping when you're done", isPresented: $askNotifications) {
            Button("Continue") {
                Task {
                    await NotificationService.requestPermission()
                    island.start()
                }
            }
        } message: {
            Text("Foundry sends a single notification when an Island session ends. Nothing else.")
        }
        .sheet(isPresented: $showFocusSetup) {
            FocusSetupView { showFocusSetup = false }
                .environment(env)
                .presentationBackground(Palette.bg)
        }
    }

    private var controls: some View {
        let island = env.island
        return HStack(spacing: 12) {
            switch island.phase {
            case .idle:
                Button("BEGIN FOCUS", action: begin)
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
            case .running:
                Button("PAUSE") { island.pause() }
                    .buttonStyle(SecondaryButtonStyle())
            case .paused:
                Button("RESUME") { island.resume() }
                    .buttonStyle(SecondaryButtonStyle())
            }
            Button("LEAVE ISLAND") {
                island.leave()
                onClose()
            }
            .buttonStyle(SecondaryButtonStyle(tint: Palette.text, stroke: Palette.lineDim))
            .keyboardShortcut(.cancelAction)
        }
    }

    @ViewBuilder
    private func targetPicker(open: [Target]) -> some View {
        let island = env.island
        let current = open.first { $0.id == island.targetID } ?? open.first { $0.isPrimary } ?? open.first
        Menu {
            ForEach(open) { target in
                Button(target.title) { island.targetID = target.id }
            }
            if open.isEmpty {
                Text("No open names. Add one on the List.")
            }
        } label: {
            IslandTargetName(name: current?.title, size: isWindow ? 40 : 34, seed: current?.id.seed ?? 7)
        }
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .accessibilityLabel("Target for this session")
        .accessibilityValue(current?.title ?? "None")
        .accessibilityHint("Choose a different name")
    }

    private func begin() {
        Task {
            if await NotificationService.status() == .notDetermined {
                askNotifications = true
            } else {
                env.island.start()
            }
        }
    }

    private func appeared() {
        if env.island.targetID == nil { env.island.targetID = env.store.openPrimary()?.id }
        if env.router.autoStartIsland {
            env.router.autoStartIsland = false
            if !env.island.isActive { begin() }
        }
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = true
        #else
        activity = ProcessInfo.processInfo.beginActivity(options: [.idleDisplaySleepDisabled, .userInitiated],
                                                         reason: "Island session on screen")
        #endif
    }

    private func disappeared() {
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = false
        #else
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
        activity = nil
        #endif
    }
}

/// Filled dots for sessions completed today, hollow for the rest of the goal.
struct SessionDots: View {
    var done: Int
    var goal: Int
    var size: CGFloat = 10

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<max(goal, done), id: \.self) { i in
                if i < done {
                    Circle().fill(Palette.accent).frame(width: size, height: size)
                } else {
                    Circle().strokeBorder(Palette.lineDim, lineWidth: 1.5).frame(width: size, height: size)
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(done) of \(goal) sessions today")
    }
}
