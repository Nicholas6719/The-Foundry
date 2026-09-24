import SwiftUI
import FoundryCore

/// Set logging for one lift: tap a dot to complete it at target reps, long-press to adjust reps.
struct LiftSheet: View {
    var lift: LiftDef
    var onDone: () -> Void

    @Environment(AppEnvironment.self) private var env
    @State private var adjusting: Int?
    @State private var reps = 5
    @State private var message: String?

    var body: some View {
        let _ = env.store.revision
        let today = env.store.todayKey
        let logs = env.store.setLogs(for: lift, on: today)
        let weight = env.store.sessionWeight(for: lift, on: today)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    MonoTitle(text: "SET LOG")
                    Spacer()
                    Button("Done", action: onDone)
                        .buttonStyle(.plain)
                        .body(16, weight: .semibold)
                        .foregroundStyle(Palette.accent)
                        .frame(minHeight: Metrics.minTap)
                        .keyboardShortcut(.cancelAction)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(lift.name.uppercased()).condensed(34, tracking: 0.04).foregroundStyle(Palette.text)
                    Text("\(LadderRules.format(weight)) LB · \(lift.sets) × \(lift.reps)")
                        .mono(13, tracking: 0.08)
                        .foregroundStyle(Palette.textMuted)
                }
                HStack(spacing: 14) {
                    ForEach(0..<lift.sets, id: \.self) { i in
                        setDot(index: i, log: logs.first { $0.setIndex == i })
                    }
                }
                Text("Tap a set when it's done. Hold to change the reps.")
                    .body(14)
                    .foregroundStyle(Palette.textMuted)

                if let adjusting {
                    repsEditor(index: adjusting)
                }
                if let message {
                    Text(message)
                        .condensed(20, tracking: 0.06)
                        .foregroundStyle(Palette.accent)
                        .transition(.opacity)
                }
                history
            }
            .padding(Metrics.screenPadding)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.bg)
        // Rung Four and rank-ups usually land here, so their banner shows on top of the sheet.
        .overlay(alignment: .top) { CelebrationOverlay() }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 600)
        #endif
    }

    private func setDot(index: Int, log: SetLog?) -> some View {
        let done = log != nil
        let missed = (log?.repsDone ?? lift.reps) < lift.reps
        return VStack(spacing: 6) {
            ZStack {
                Circle().fill(done ? (missed ? Palette.surface2 : Palette.accent) : Palette.surface)
                Circle().strokeBorder(done && !missed ? Palette.accent : Palette.lineDim, lineWidth: 2)
                Text(done ? "\(log?.repsDone ?? 0)" : "\(index + 1)")
                    .condensed(20, tracking: 0)
                    .foregroundStyle(done && !missed ? Palette.onAccent : Palette.text)
            }
            .frame(width: 56, height: 56)
            Text(done ? "REPS" : "SET").mono(10).foregroundStyle(Palette.textMuted)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if done {
                env.clearSet(lift, index: index)
                message = nil
            } else {
                record(env.logSet(lift, index: index))
            }
        }
        .onLongPressGesture(minimumDuration: 0.4) {
            reps = log?.repsDone ?? lift.reps
            withAnimation(.snappy) { adjusting = index }
        }
        .keyboardActivatable {
            if done { env.clearSet(lift, index: index) } else { record(env.logSet(lift, index: index)) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Set \(index + 1)")
        .accessibilityValue(done ? "\(log?.repsDone ?? 0) reps done" : "Not done")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { if done { env.clearSet(lift, index: index) } else { record(env.logSet(lift, index: index)) } }
        .accessibilityAction(named: "Adjust reps") {
            reps = log?.repsDone ?? lift.reps
            adjusting = index
        }
    }

    private func repsEditor(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SET \(index + 1) · REPS").mono(11, tracking: 0.12).foregroundStyle(Palette.accent)
            HStack(spacing: 18) {
                CircleIconButton(systemImage: "minus", label: "Fewer reps") { reps = max(0, reps - 1) }
                Text("\(reps)")
                    .condensed(44, tracking: 0)
                    .foregroundStyle(Palette.text)
                    .frame(minWidth: 56)
                    .accessibilityLabel("\(reps) reps")
                CircleIconButton(systemImage: "plus", label: "More reps") { reps = min(20, reps + 1) }
                Spacer()
            }
            HStack(spacing: 12) {
                Button("SAVE") {
                    record(env.logSet(lift, index: index, reps: reps))
                    withAnimation(.snappy) { adjusting = nil }
                }
                .buttonStyle(PrimaryButtonStyle(height: 44, fontSize: 18))
                Button("CANCEL") { withAnimation(.snappy) { adjusting = nil } }
                    .buttonStyle(SecondaryButtonStyle(height: 44, fontSize: 18, tint: Palette.text, stroke: Palette.lineDim))
            }
        }
        .padding(16)
        .card(radius: 14)
    }

    private var history: some View {
        let sessions = env.store.history(for: lift)
        return VStack(alignment: .leading, spacing: 10) {
            MonoTitle(text: "LAST SESSIONS")
            if sessions.isEmpty {
                Text("No sessions yet. The first one sets the bar.")
                    .body(15)
                    .foregroundStyle(Palette.textMuted)
            }
            ForEach(sessions) { session in
                let clean = session.reps.count >= lift.sets && session.reps.allSatisfy { $0 >= lift.reps }
                HStack {
                    Text(session.dayKey == env.store.todayKey ? "TODAY" : Self.shortDate(session.dayKey, keys: env.store.keys))
                        .mono(12).foregroundStyle(Palette.textMuted)
                    Spacer()
                    Text("\(LadderRules.format(session.weight)) LB").mono(12).foregroundStyle(Palette.text)
                    Text(session.reps.map(String.init).joined(separator: "·"))
                        .mono(12)
                        .foregroundStyle(clean ? Palette.accent : Palette.textMuted)
                        .frame(minWidth: 80, alignment: .trailing)
                }
                .frame(minHeight: 32)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(16)
        .card(radius: 14)
    }

    private func record(_ result: LiftLogResult) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if result.climbed {
                message = result.record ? "RUNG UNLOCKED · NEW RECORD +100 XP" : "RUNG UNLOCKED FOR NEXT SESSION"
            } else if result.sessionCompleted {
                message = "SESSION COMPLETE"
            }
        }
    }

    /// `MM/DD` in U.S. style.
    static func shortDate(_ dayKey: String, keys: DayKeys) -> String {
        let parts = dayKey.split(separator: "-")
        guard parts.count == 3 else { return dayKey }
        return "\(parts[1])/\(parts[2])"
    }
}
