import SwiftUI
import SwiftData

/// The menu bar popover: focus timer, today's habits, and session controls.
struct MenuBarView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let _ = env.store.revision
        let island = env.island
        let states = Array(env.store.habitStates().prefix(4))
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 14) {
                HStack {
                    Button {
                        openWindow(id: "main")
                        NSApplication.shared.activate()
                    } label: {
                        HexBadge(content: .emblem, size: 36, fill: Palette.bg, label: "Open Foundry")
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    FocusPill(pill: env.focus.pill, compact: true) {
                        env.router.macSection = .island
                        openWindow(id: "main")
                    }
                }
                IslandRing(progress: island.progress(at: context.date), active: island.isActive, diameter: 148, guides: false) {
                    VStack(spacing: 2) {
                        Text(Clock.text(island.remaining(at: context.date)))
                            .font(FoundryFont.fixed(.monoMedium, size: 32))
                            .foregroundStyle(Palette.text)
                        Text(island.targetName ?? env.store.openPrimary()?.title ?? "")
                            .script(18)
                            .foregroundStyle(Palette.inkRed)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: 110)
                    }
                }
                if !states.isEmpty {
                    HabitButtonsView(states: states, size: 44)
                        .padding(.horizontal, 6)
                }
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    switch island.phase {
                    case .idle:
                        Button("BEGIN FOCUS") { begin() }
                            .buttonStyle(PrimaryButtonStyle(height: 44, fontSize: 18))
                    case .running:
                        Button("PAUSE") { island.pause() }
                            .buttonStyle(SecondaryButtonStyle(height: 44, fontSize: 18))
                        leave
                    case .paused:
                        Button("RESUME") { island.resume() }
                            .buttonStyle(SecondaryButtonStyle(height: 44, fontSize: 18))
                        leave
                    }
                }
            }
            .padding(20)
            .frame(width: 320, height: 420)
            .background(Palette.surface)
        }
    }

    private var leave: some View {
        Button("LEAVE ISLAND") { env.island.leave() }
            .buttonStyle(SecondaryButtonStyle(height: 44, fontSize: 18, tint: Palette.text, stroke: Palette.lineDim))
    }

    private func begin() {
        Task {
            if await NotificationService.status() == .notDetermined {
                // First session: the Island window explains the one notification before asking.
                env.router.openIsland(start: true, island: env.island)
                openWindow(id: "main")
                NSApplication.shared.activate()
            } else {
                env.island.start()
            }
        }
    }
}
