import Foundation
#if os(iOS)
import UIKit
#else
import AppKit
#endif

enum URLOpener {
    static func open(_ url: URL) {
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }

    /// Opens this app's page in iOS Settings (Health access lives under it).
    static func openAppSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) { open(url) }
        #endif
    }

    static func openShortcutsApp() {
        if let url = URL(string: "shortcuts://") { open(url) }
    }

    static func createShortcut() {
        if let url = URL(string: "shortcuts://create-shortcut") { open(url) }
    }
}

/// Switches the custom "Foundry" Focus by running two user-made Shortcuts.
///
/// There is no public API for an app to toggle a Focus, so the supported path is
/// `shortcuts://x-callback-url/run-shortcut`, with results coming back on `foundry://focus/...`.
@Observable
final class FocusService {
    enum Pill: Equatable { case on, off, setUp }

    enum TestState: Equatable {
        case idle
        case runningOn
        case runningOff
        case passed
        case failed(String)
    }

    static let onShortcut = "Foundry Focus On"
    static let offShortcut = "Foundry Focus Off"

    /// Mirrors `Profile.focusShortcutsConfigured`.
    var isConfigured = false
    private(set) var isOn = false
    private(set) var testState: TestState = .idle
    private(set) var lastError: String?
    /// Called when the wizard's test passes so the profile can remember it.
    @ObservationIgnored var onConfigured: (() -> Void)?

    var pill: Pill {
        guard isConfigured else { return .setUp }
        return isOn ? .on : .off
    }

    // MARK: - Session hooks (never block the timer)

    func sessionStarted() {
        guard isConfigured else { return }
        run(Self.onShortcut, success: "on-ok")
    }

    func sessionEnded() {
        guard isConfigured else { return }
        isOn = false
        run(Self.offShortcut, success: "off-ok")
    }

    // MARK: - Wizard

    func runTest() {
        testState = .runningOn
        run(Self.onShortcut, success: "test-on-ok")
    }

    func resetTest() { testState = .idle }

    // MARK: - Callbacks

    /// Handles `foundry://focus/...`. Returns true when the URL was ours.
    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard url.scheme == "foundry", url.host == "focus" else { return false }
        let result = url.pathComponents.dropFirst().first ?? ""
        Log.focus.info("Shortcut callback: \(result, privacy: .public)")
        switch result {
        case "on-ok":
            isOn = true
            lastError = nil
        case "off-ok":
            isOn = false
            lastError = nil
        case "test-on-ok":
            isOn = true
            testState = .runningOff
            run(Self.offShortcut, success: "test-off-ok")
        case "test-off-ok":
            isOn = false
            testState = .passed
            isConfigured = true
            onConfigured?()
        case "cancelled":
            fail("The shortcut was cancelled.")
        default:
            let message = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "errorMessage" }?.value
            fail(message ?? "Shortcuts could not run it. Check the name is exact.")
        }
        return true
    }

    /// The Focus Filter reported the Foundry Focus turning on or off.
    func filterReported(active: Bool) {
        isOn = active
    }

    private func fail(_ message: String) {
        lastError = message
        switch testState {
        case .runningOn, .runningOff: testState = .failed(message)
        default: break
        }
    }

    private func run(_ name: String, success: String) {
        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "x-callback-url"
        components.path = "/run-shortcut"
        components.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "x-success", value: "foundry://focus/\(success)"),
            URLQueryItem(name: "x-cancel", value: "foundry://focus/cancelled"),
            URLQueryItem(name: "x-error", value: "foundry://focus/error")
        ]
        guard let url = components.url else { return }
        URLOpener.open(url)
    }
}
