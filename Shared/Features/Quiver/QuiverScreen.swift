import SwiftUI
import SwiftData

/// Today's habits for the Quiver and the menu bar.
struct HabitState: Identifiable {
    var habit: Habit
    var fired: Bool
    var isAuto: Bool
    var firedAt: Date? = nil
    var id: UUID { habit.id }
}

extension FoundryStore {
    /// Active habits with today's fire state.
    func habitStates() -> [HabitState] {
        let today = todayKey
        let logs = logs(on: today)
        return activeHabits().map { habit in
            let log = logs.first { $0.habitID == habit.id }
            return HabitState(habit: habit, fired: log != nil, isAuto: log?.source == LogSource.auto.rawValue,
                              firedAt: log?.firedAt)
        }
    }
}

/// The habit buttons row(s), shared by iPhone, the Mac dashboard and the menu bar.
struct HabitButtonsView: View {
    var states: [HabitState]
    var size: CGFloat = 64

    @Environment(AppEnvironment.self) private var env

    var body: some View {
        HabitRowsLayout {
            ForEach(states) { state in
                HabitButton(name: state.habit.name, glyph: state.habit.habitGlyph, fired: state.fired,
                            isAuto: state.isAuto, size: size) {
                    if state.fired { env.undo(state.habit) } else { env.fire(state.habit) }
                }
            }
        }
    }
}

/// iPhone: the Quiver.
struct QuiverScreen: View {
    @Environment(AppEnvironment.self) private var env
    #if os(macOS)
    @Environment(\.openSettings) private var openSettings
    #endif
    @State private var appeared = false

    var body: some View {
        let _ = env.clock.todayKey
        let snap = env.store.liveSnapshot()
        let states = env.store.habitStates()
        ScreenScroll {
            ScreenHeader {
                HexBadge(content: .glyph(.quiver), label: "The Quiver")
            } trailing: {
                Chip {
                    GlyphView(glyph: .arrowUpRight, size: 18, lineWidth: 2)
                    Text("\(snap.habitsDone) / \(snap.habitsTotal)").mono(13, tracking: 0.06)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(snap.habitsDone) of \(snap.habitsTotal) arrows fired")
            }
            TargetBoard(fired: snap.habitsDone, total: snap.habitsTotal, animateNew: appeared)
                .frame(maxWidth: 250)
                .frame(maxWidth: .infinity)
            if states.isEmpty {
                VStack(spacing: 12) {
                    Text("No arrows in the quiver yet.").body(17, weight: .medium).foregroundStyle(Palette.text)
                    Button("ADD HABITS") {
                        #if os(macOS)
                        openSettings()
                        #else
                        env.router.showSettings = true
                        #endif
                    }
                        .buttonStyle(SecondaryButtonStyle())
                }
                .frame(maxWidth: .infinity)
            } else {
                QuiverRack(states: states)
            }
            WeekCard(week: snap.week, todayIndex: snap.todayIndex, streak: snap.streak)
        }
        .onAppear { DispatchQueue.main.async { appeared = true } }
    }
}
