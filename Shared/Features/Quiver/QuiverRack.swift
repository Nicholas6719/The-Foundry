import SwiftUI
import FoundryCore

/// The Quiver's habit list: arrows still "in the quiver" wait to be fired; fired ones are
/// "in the target" below. Rows glide between the two when fired or undone.
struct QuiverRack: View {
    var states: [HabitState]

    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var rack

    var body: some View {
        let pending = states.filter { !$0.fired }
        let fired = states.filter(\.fired).sorted { ($0.firedAt ?? .distantPast) < ($1.firedAt ?? .distantPast) }
        VStack(alignment: .leading, spacing: 14) {
            section(title: "IN THE QUIVER", count: pending.count) {
                if pending.isEmpty {
                    HStack(spacing: 10) {
                        GlyphView(glyph: .check, size: 20, lineWidth: 2.5)
                        Text("Quiver empty. Bullseye.").condensed(22, tracking: 0.04).foregroundStyle(Palette.accent)
                    }
                    .frame(maxWidth: .infinity, minHeight: 64)
                } else {
                    ForEach(pending) { state in
                        QuiverRow(state: state) { act(state) }
                            .matchedGeometryEffect(id: state.id, in: rack)
                        if state.id != pending.last?.id { divider }
                    }
                }
            }
            .background(alignment: .top) { stitching }
            .card(fill: Palette.surface, stroke: pending.isEmpty ? Palette.accent : Palette.lineStrong)

            if !fired.isEmpty {
                section(title: "IN THE TARGET", count: fired.count) {
                    ForEach(fired) { state in
                        QuiverRow(state: state) { act(state) }
                            .matchedGeometryEffect(id: state.id, in: rack)
                        if state.id != fired.last?.id { divider }
                    }
                }
                .card(fill: Palette.bg, stroke: Palette.line)
            }
        }
    }

    private func act(_ state: HabitState) {
        let animation: Animation = reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.82)
        withAnimation(animation) {
            if state.fired { env.undo(state.habit) } else { env.fire(state.habit) }
        }
    }

    private func section<Rows: View>(title: String, count: Int, @ViewBuilder rows: () -> Rows) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title).mono(11, tracking: 0.12).foregroundStyle(Palette.accent)
                Spacer()
                Text("\(count)").mono(11, tracking: 0.06).foregroundStyle(Palette.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 4)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            rows()
        }
        .padding(.bottom, 6)
    }

    private var divider: some View {
        Rectangle().fill(Palette.line).frame(height: 1).padding(.leading, 94)
    }

    /// Dashed stitching along the quiver's mouth.
    private var stitching: some View {
        Rectangle()
            .stroke(Palette.lineDim, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .frame(height: 1)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .accessibilityHidden(true)
    }
}

/// One habit as an arrow: fletching and shaft leading to its glyph, then a FIRE button.
struct QuiverRow: View {
    var state: HabitState
    var action: () -> Void

    var body: some View {
        let habit = state.habit
        Button(action: action) {
            HStack(spacing: 12) {
                HStack(spacing: 2) {
                    // Fletching and shaft: the arrow's tail, only while it's still in the quiver.
                    GridShape(d: "M1 6l5 6-5 6M7 6l5 6-5 6M11 12h13")
                        .stroke(Palette.accent.opacity(0.7), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .frame(width: 24, height: 24)
                        .opacity(state.fired ? 0 : 1)
                    glyphCircle(habit)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name.uppercased())
                        .condensed(22, tracking: 0.04, relativeTo: .title3)
                        .foregroundStyle(state.fired ? Palette.textMuted : Palette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(detail)
                        .mono(10, tracking: 0.08)
                        .foregroundStyle(Palette.textMuted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if state.fired {
                    GlyphView(glyph: .check, size: 20, lineWidth: 2.5)
                        .frame(width: 44, height: 44)
                } else {
                    Text("FIRE")
                        .condensed(18, tracking: 0.1)
                        .foregroundStyle(Palette.onAccent)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 40)
                        .background(Palette.accent, in: Capsule())
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 14)
            .frame(minHeight: 68)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(habit.name)
        .accessibilityValue(state.fired ? (state.isAuto ? "Fired automatically" : "Fired") : "Ready to fire. \(ruleText(habit))")
        .accessibilityHint(state.fired ? "Double-tap to undo" : "Double-tap to fire")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func glyphCircle(_ habit: Habit) -> some View {
        ZStack {
            if state.fired {
                Circle().fill(Palette.accent)
                HabitGlyphView(glyph: habit.habitGlyph, size: 20, color: Palette.onAccent)
            } else {
                Circle().fill(Palette.surface)
                Circle().stroke(Palette.accent.opacity(0.25), lineWidth: 6)
                Circle().stroke(Palette.accent, lineWidth: 2)
                HabitGlyphView(glyph: habit.habitGlyph, size: 20, color: Palette.accent)
            }
        }
        .frame(width: 44, height: 44)
    }

    private var detail: String {
        if state.fired {
            let time = state.firedAt.map { Self.time.string(from: $0) } ?? ""
            #if os(macOS)
            let undo = "CLICK TO UNDO"
            #else
            let undo = "TAP TO UNDO"
            #endif
            return state.isAuto ? "AUTO · \(time)" : "FIRED \(time) · \(undo)"
        }
        switch state.habit.rule {
        case .none: return "BY HAND"
        case .workout: return "AUTO · 20-MIN WORKOUT"
        case .sleepDuration: return "AUTO · \(SleepBuilder.formatDuration(minutes: state.habit.autoThresholdMinutes)) SLEEP"
        }
    }

    private func ruleText(_ habit: Habit) -> String {
        switch habit.rule {
        case .none: "Fire it by hand"
        case .workout: "Fires itself after a 20-min workout"
        case .sleepDuration: "Fires itself at \(SleepBuilder.formatDuration(minutes: habit.autoThresholdMinutes)) sleep"
        }
    }

    /// `7:42 AM`.
    private static let time: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "h:mm a"
        return f
    }()
}

/// This week's seven targets plus the streak, in a card.
struct WeekCard: View {
    var week: [DayMark]
    var todayIndex: Int
    var streak: Int

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("THIS WEEK").mono(11, tracking: 0.12).foregroundStyle(Palette.accent)
                Spacer()
                Text("\(streak) DAY STREAK").mono(11, tracking: 0.08).foregroundStyle(Palette.textMuted)
            }
            .accessibilityElement(children: .combine)
            WeekTargets(week: week, todayIndex: todayIndex, cutout: Palette.surface)
        }
        .padding(16)
        .card()
    }
}
