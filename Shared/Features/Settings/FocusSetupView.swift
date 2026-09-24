import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Three short steps to let Foundry switch a custom Focus through Shortcuts, with a live test.
struct FocusSetupView: View {
    var onDone: () -> Void

    @Environment(AppEnvironment.self) private var env
    @AppStorage("foundry.focusStepCreated") private var focusCreated = false

    private var shortcutsInstalled: Bool {
        guard let url = URL(string: "shortcuts://") else { return false }
        #if os(iOS)
        return UIApplication.shared.canOpenURL(url)
        #else
        return NSWorkspace.shared.urlForApplication(toOpen: url) != nil
        #endif
    }

    var body: some View {
        let focus = env.focus
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    MonoTitle(text: "FOUNDRY FOCUS")
                    Spacer()
                    Button("Done", action: onDone)
                        .buttonStyle(.plain)
                        .body(16, weight: .semibold)
                        .foregroundStyle(Palette.accent)
                        .frame(minHeight: Metrics.minTap)
                        .keyboardShortcut(.cancelAction)
                }
                Text("Apps can't flip a Focus on their own. Two Shortcuts do it for Foundry. When a session starts you'll see a quick hop to Shortcuts and straight back.")
                    .body(16)
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                statusRow(ok: shortcutsInstalled, text: shortcutsInstalled ? "Shortcuts app found" : "Shortcuts app not found")

                step("A", "Create the Foundry Focus", done: focusCreated,
                     detail: "Settings › Focus › + › Custom. Name it Foundry. Allow calls from Favorites, and allow Alarms and Foundry's notifications. Optional: under Focus Filters add \"Foundry behavior\".") {
                    Button(focusCreated ? "MARKED DONE" : "I MADE IT") { focusCreated.toggle() }
                        .buttonStyle(SecondaryButtonStyle(height: 44, fontSize: 17))
                }
                step("B", "Create \u{201C}\(FocusService.onShortcut)\u{201D}", done: focus.testState == .passed || focus.isConfigured,
                     detail: "New shortcut › add Set Focus › choose Foundry › Turn On. Name it exactly \(FocusService.onShortcut).") {
                    Button("OPEN SHORTCUTS") { URLOpener.createShortcut() }
                        .buttonStyle(SecondaryButtonStyle(height: 44, fontSize: 17))
                }
                step("C", "Create \u{201C}\(FocusService.offShortcut)\u{201D}", done: focus.testState == .passed || focus.isConfigured,
                     detail: "Same again with Set Focus › Foundry › Turn Off. Name it exactly \(FocusService.offShortcut).") {
                    Button("OPEN SHORTCUTS") { URLOpener.createShortcut() }
                        .buttonStyle(SecondaryButtonStyle(height: 44, fontSize: 17))
                }

                VStack(alignment: .leading, spacing: 10) {
                    // Stays tappable: if a shortcut never calls back (cancelled prompt, app switcher),
                    // tapping again simply restarts the test.
                    Button(testLabel(focus.testState)) { focus.runTest() }
                        .buttonStyle(PrimaryButtonStyle())
                    testResult(focus.testState)
                }
            }
            .padding(Metrics.screenPadding)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.bg)
        .onAppear { focus.resetTest() }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 620)
        #endif
    }

    private func testLabel(_ state: FocusService.TestState) -> String {
        switch state {
        case .runningOn: "TURNING FOCUS ON…"
        case .runningOff: "TURNING FOCUS OFF…"
        case .passed: "TEST AGAIN"
        default: "TEST"
        }
    }

    @ViewBuilder
    private func testResult(_ state: FocusService.TestState) -> some View {
        switch state {
        case .passed:
            statusRow(ok: true, text: "Both shortcuts ran. Sessions will now switch Foundry Focus on and off.")
        case .failed(let message):
            statusRow(ok: false, text: message)
        case .idle:
            Text("Test runs On, then Off, and reports back here.").body(14).foregroundStyle(Palette.textMuted)
        default:
            EmptyView()
        }
    }

    private func statusRow(ok: Bool, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(ok ? Palette.accent : Palette.inkRed)
            Text(text).body(15, weight: .medium).foregroundStyle(Palette.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func step<Actions: View>(_ letter: String, _ title: String, done: Bool, detail: String,
                                     @ViewBuilder actions: () -> Actions) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(done ? Palette.accent : Palette.surface2)
                    if done {
                        GlyphView(glyph: .check, size: 18, lineWidth: 2.5, color: Palette.onAccent)
                    } else {
                        Text(letter).condensed(18, tracking: 0).foregroundStyle(Palette.accent)
                    }
                }
                .frame(width: 32, height: 32)
                Text(title).body(18, weight: .semibold).foregroundStyle(Palette.text)
            }
            Text(detail).body(15).foregroundStyle(Palette.textMuted).fixedSize(horizontal: false, vertical: true)
            actions()
        }
        .padding(16)
        .card(radius: 14)
        .accessibilityElement(children: .contain)
        .accessibilityValue(done ? "Done" : "Not done")
    }
}
