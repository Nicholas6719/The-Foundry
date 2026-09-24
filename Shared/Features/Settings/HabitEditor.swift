import SwiftUI
import FoundryCore

/// Add or edit a habit: name, glyph, auto rule and threshold, archive.
struct HabitEditor: View {
    var habit: Habit?
    var onDone: () -> Void

    @Environment(AppEnvironment.self) private var env
    @State private var name = ""
    @State private var glyph: HabitGlyph = .dumbbell
    @State private var rule: AutoRule = .none
    @State private var thresholdMinutes = GameRules.defaultSleepThresholdMinutes

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    MonoTitle(text: habit == nil ? "NEW HABIT" : "EDIT HABIT")
                    Spacer()
                    Button("Cancel", action: onDone)
                        .buttonStyle(.plain)
                        .body(16, weight: .medium)
                        .foregroundStyle(Palette.textMuted)
                        .frame(minHeight: Metrics.minTap)
                        .keyboardShortcut(.cancelAction)
                }
                TextField("", text: $name, prompt: Text("Name").foregroundStyle(Palette.lineDim))
                    .condensed(26, tracking: 0.06)
                    .foregroundStyle(Palette.text)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 52)
                    .card(radius: 12)
                    .onChange(of: name) { _, new in if new.count > 16 { name = String(new.prefix(16)) } }
                    .accessibilityLabel("Habit name")

                MonoTitle(text: "ICON")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
                    ForEach(HabitGlyph.allCases) { g in
                        Button { glyph = g } label: {
                            ZStack {
                                Circle().fill(g == glyph ? Palette.accent : Palette.surface)
                                Circle().strokeBorder(g == glyph ? Palette.accent : Palette.line, lineWidth: 1.5)
                                HabitGlyphView(glyph: g, size: 24, color: g == glyph ? Palette.onAccent : Palette.accent)
                            }
                            .frame(width: 56, height: 56)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(g.name)
                        .accessibilityAddTraits(g == glyph ? .isSelected : [])
                    }
                }

                MonoTitle(text: "FIRES ITSELF WHEN")
                VStack(spacing: 0) {
                    Picker("Auto rule", selection: $rule) {
                        ForEach(AutoRule.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 12)
                    Text(ruleHint).body(14).foregroundStyle(Palette.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 12)
                    if rule == .sleepDuration {
                        Stepper(value: $thresholdMinutes, in: 240...720, step: 15) {
                            Text("At least \(SleepBuilder.formatDuration(minutes: thresholdMinutes))")
                                .body(17, weight: .medium).foregroundStyle(Palette.text)
                        }
                        .frame(minHeight: Metrics.minTap)
                        .padding(.bottom, 8)
                    }
                }
                .padding(.horizontal, 16)
                .card(radius: 14)

                Button(habit == nil ? "ADD HABIT" : "SAVE", action: save)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                if let habit {
                    Button("ARCHIVE HABIT") {
                        env.store.archive(habit)
                        onDone()
                    }
                    .buttonStyle(SecondaryButtonStyle(tint: Palette.inkRed, stroke: Palette.lineDim))
                    Text("Archiving keeps its history but takes it out of the Quiver.")
                        .body(13).foregroundStyle(Palette.textMuted)
                }
            }
            .padding(Metrics.screenPadding)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.bg)
        .onAppear(perform: load)
    }

    private var ruleHint: String {
        switch rule {
        case .none: "You fire it by hand."
        case .workout: "Fires when Health shows a 20-minute workout today, or you finish a Foundry session."
        case .sleepDuration: "Fires when last night's sleep reaches the amount below."
        }
    }

    private func load() {
        guard let habit else { return }
        name = habit.name
        glyph = habit.habitGlyph
        rule = habit.rule
        if habit.autoThresholdMinutes > 0 { thresholdMinutes = habit.autoThresholdMinutes }
    }

    private func save() {
        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(16))
        guard !clean.isEmpty else { return }
        let threshold = rule == .sleepDuration ? thresholdMinutes : 0
        if let habit {
            habit.name = clean
            habit.habitGlyph = glyph
            habit.rule = rule
            habit.autoThresholdMinutes = threshold
            env.store.habitsChanged()
        } else {
            env.store.addHabit(name: clean, glyph: glyph, rule: rule, threshold: threshold)
        }
        onDone()
    }
}
