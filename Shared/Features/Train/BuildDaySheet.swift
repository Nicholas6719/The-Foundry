import SwiftUI
import FoundryCore

/// Guided "Build your first day" (and edit an existing day): name, weekdays, lifts.
struct BuildDaySheet: View {
    var day: WorkoutDay?
    var onDone: () -> Void

    @Environment(AppEnvironment.self) private var env
    @State private var name = ""
    @State private var mask = WeekdayMask()
    @State private var lifts: [LiftDraft] = [LiftDraft(isLead: true)]
    @State private var confirmDelete = false

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && lifts.contains { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    MonoTitle(text: day == nil ? "BUILD YOUR FIRST DAY" : "EDIT DAY")
                    Spacer()
                    Button("Cancel", action: onDone)
                        .buttonStyle(.plain)
                        .body(16, weight: .medium)
                        .foregroundStyle(Palette.textMuted)
                        .frame(minHeight: Metrics.minTap)
                        .keyboardShortcut(.cancelAction)
                }
                step(1, "Name the day", hint: "Short and loud: PUSH, PULL, LEGS.") {
                    TextField("", text: $name, prompt: Text("PUSH").foregroundStyle(Palette.lineDim))
                        .condensed(28, tracking: 0.06)
                        .foregroundStyle(Palette.text)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 52)
                        .card(radius: 12)
                        .accessibilityLabel("Day name")
                }
                step(2, "Pick the days", hint: "Unscheduled days become rest days.") {
                    HStack(spacing: 6) {
                        ForEach(0..<7, id: \.self) { i in
                            let on = mask.contains(dayIndex: i)
                            Button {
                                if on { mask.remove(.day(i)) } else { mask.insert(.day(i)) }
                            } label: {
                                Text(verbatim: DayKeys.weekdayLetters[i])
                                    .mono(13, tracking: 0)
                                    .foregroundStyle(on ? Palette.onAccent : Palette.textMuted)
                                    .frame(width: 44, height: 44)
                                    .background(on ? Palette.accent : Palette.surface, in: Circle())
                                    .overlay(Circle().strokeBorder(on ? Palette.accent : Palette.line, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(DayKeys.weekdayNames[i])
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                }
                step(3, "Add lifts", hint: "The lead lift gets the big ladder. Each clean session climbs one rung.") {
                    VStack(spacing: 12) {
                        ForEach($lifts) { $draft in
                            LiftDraftEditor(draft: $draft, isLead: draft.isLead,
                                            onLead: { setLead(draft.id) },
                                            onRemove: lifts.count > 1 ? { remove(draft.id) } : nil)
                        }
                        if lifts.count < 8 {
                            Button {
                                lifts.append(LiftDraft())
                            } label: {
                                Label("ADD LIFT", systemImage: "plus")
                            }
                            .buttonStyle(SecondaryButtonStyle(height: 48, fontSize: 18))
                        }
                    }
                }
                Button(day == nil ? "BUILD THE DAY" : "SAVE", action: save)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.5)
                if day != nil {
                    Button("DELETE DAY", role: .destructive) { confirmDelete = true }
                        .buttonStyle(SecondaryButtonStyle(tint: Palette.inkRed, stroke: Palette.lineDim))
                }
            }
            .padding(Metrics.screenPadding)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.bg)
        #if os(macOS)
        .frame(minWidth: 560, minHeight: 640)
        #endif
        .onAppear(perform: load)
        .confirmationDialog("Delete this day and its lifts?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Day", role: .destructive) {
                if let day { env.store.deleteWorkoutDay(day) }
                onDone()
            }
        }
    }

    private func step<Content: View>(_ n: Int, _ title: String, hint: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(n)").condensed(26, tracking: 0).foregroundStyle(Palette.accent)
                Text(title).body(19, weight: .semibold).foregroundStyle(Palette.text)
            }
            Text(hint).body(14).foregroundStyle(Palette.textMuted)
            content()
        }
    }

    private func load() {
        guard let day else {
            if name.isEmpty { mask = .day(env.store.keys.weekdayIndex(for: env.store.todayKey)) }
            return
        }
        name = day.name
        mask = day.mask
        let drafts = env.store.drafts(for: day)
        lifts = drafts.isEmpty ? [LiftDraft(isLead: true)] : drafts
    }

    private func setLead(_ id: UUID) {
        for i in lifts.indices { lifts[i].isLead = lifts[i].id == id }
    }

    private func remove(_ id: UUID) {
        lifts.removeAll { $0.id == id }
        if !lifts.contains(where: \.isLead), !lifts.isEmpty { lifts[0].isLead = true }
    }

    private func save() {
        guard canSave else { return }
        if let day {
            env.store.updateWorkoutDay(day, name: name, mask: mask, lifts: lifts)
        } else {
            env.store.createWorkoutDay(name: name, mask: mask, lifts: lifts)
        }
        onDone()
    }
}

/// One lift row in the builder.
struct LiftDraftEditor: View {
    @Binding var draft: LiftDraft
    var isLead: Bool
    var onLead: () -> Void
    var onRemove: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("", text: $draft.name, prompt: Text("Lift name").foregroundStyle(Palette.lineDim))
                    .body(18, weight: .semibold)
                    .foregroundStyle(Palette.text)
                    .accessibilityLabel("Lift name")
                if let onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Palette.textMuted)
                            .frame(width: Metrics.minTap, height: Metrics.minTap)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove lift")
                }
            }
            HStack(spacing: 10) {
                numberField("START LB", value: $draft.startWeight, step: 5, range: 0...1000)
                numberField("STEP LB", value: $draft.step, step: 2.5, range: 2.5...50)
            }
            HStack(spacing: 10) {
                intField("SETS", value: $draft.sets, range: 1...10)
                intField("REPS", value: $draft.reps, range: 1...20)
            }
            Button(action: onLead) {
                HStack(spacing: 8) {
                    Image(systemName: isLead ? "checkmark.circle.fill" : "circle")
                    Text(isLead ? "LEAD LIFT" : "MAKE LEAD LIFT").mono(12, tracking: 0.08)
                }
                .foregroundStyle(isLead ? Palette.accent : Palette.textMuted)
                .frame(minHeight: Metrics.minTap)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isLead ? .isSelected : [])
        }
        .padding(14)
        .card(radius: 14)
    }

    private func numberField(_ label: String, value: Binding<Double>, step: Double, range: ClosedRange<Double>) -> some View {
        stepper(label, text: LadderRules.format(value.wrappedValue)) {
            value.wrappedValue = max(range.lowerBound, value.wrappedValue - step)
        } plus: {
            value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
        }
    }

    private func intField(_ label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        stepper(label, text: "\(value.wrappedValue)") {
            value.wrappedValue = max(range.lowerBound, value.wrappedValue - 1)
        } plus: {
            value.wrappedValue = min(range.upperBound, value.wrappedValue + 1)
        }
    }

    private func stepper(_ label: String, text: String, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).mono(10, tracking: 0.1).foregroundStyle(Palette.textMuted)
            HStack(spacing: 0) {
                Button(action: minus) {
                    Image(systemName: "minus").frame(width: 40, height: Metrics.minTap)
                }
                .accessibilityLabel("Decrease \(label.lowercased())")
                Text(text)
                    .condensed(22, tracking: 0)
                    .foregroundStyle(Palette.text)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("\(label.lowercased()) \(text)")
                Button(action: plus) {
                    Image(systemName: "plus").frame(width: 40, height: Metrics.minTap)
                }
                .accessibilityLabel("Increase \(label.lowercased())")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.accent)
            .background(Palette.bg, in: RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity)
    }
}
