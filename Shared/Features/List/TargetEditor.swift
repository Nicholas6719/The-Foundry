import SwiftUI
import FoundryCore

/// Add or edit a name: Caveat text, optional due date, "Make primary".
struct TargetEditor: View {
    var target: Target?
    var onDone: () -> Void

    @Environment(AppEnvironment.self) private var env
    @State private var title = ""
    @State private var hasDue = false
    @State private var due = Date()
    @State private var primary = false
    @FocusState private var focused: Bool

    private var trimmed: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                MonoTitle(text: target == nil ? "NEW NAME" : "EDIT NAME")
                Spacer()
                Button("Cancel", action: onDone)
                    .buttonStyle(.plain)
                    .body(16, weight: .medium)
                    .foregroundStyle(Palette.textMuted)
                    .frame(minHeight: Metrics.minTap)
            }

            TextField("", text: $title, prompt: Text("Name").foregroundStyle(Palette.inkMuted))
                .script(34)
                .foregroundStyle(Palette.ink)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(save)
                .onChange(of: title) { _, new in
                    if new.count > GameRules.targetTitleMaxLength { title = String(new.prefix(GameRules.targetTitleMaxLength)) }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 64)
                .background(Palette.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel("Name")

            Text("\(title.count) / \(GameRules.targetTitleMaxLength)")
                .mono(11)
                .foregroundStyle(Palette.textMuted)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, -12)

            VStack(spacing: 0) {
                Toggle(isOn: $hasDue.animation()) {
                    Text("Due date").body(17, weight: .medium).foregroundStyle(Palette.text)
                }
                .frame(minHeight: Metrics.minTap)
                if hasDue {
                    DatePicker("Due", selection: $due, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 8)
                }
                Divider().overlay(Palette.line)
                Toggle(isOn: $primary) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Make primary").body(17, weight: .medium).foregroundStyle(Palette.text)
                        Text("Circled in red. Only one at a time.").body(14).foregroundStyle(Palette.textMuted)
                    }
                }
                .frame(minHeight: 56)
            }
            .tint(Palette.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .card(radius: 14)

            Button(target == nil ? "WRITE IT DOWN" : "SAVE", action: save)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(trimmed.isEmpty)
                .opacity(trimmed.isEmpty ? 0.5 : 1)
                .keyboardShortcut(.defaultAction)

            if let target {
                Button("DELETE NAME", role: .destructive) {
                    env.store.delete(target)
                    onDone()
                }
                .buttonStyle(SecondaryButtonStyle(tint: Palette.inkRed, stroke: Palette.lineDim))
            }
        }
        .padding(Metrics.screenPadding)
        .frame(maxWidth: 560)
        .background(Palette.bg)
        .onAppear(perform: load)
    }

    private func load() {
        if let target {
            title = target.title
            hasDue = target.dueDate != nil
            due = target.dueDate ?? Date()
            primary = target.isPrimary
        } else {
            primary = env.store.openPrimary() == nil
        }
        focused = true
    }

    private func save() {
        guard !trimmed.isEmpty else { return }
        let dueDate = hasDue ? due : nil
        if let target {
            env.store.update(target, title: title, dueDate: dueDate, primary: primary)
        } else {
            env.store.addTarget(title: title, dueDate: dueDate, primary: primary)
        }
        onDone()
    }
}
