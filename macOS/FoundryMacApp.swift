import SwiftUI
import SwiftData
import AppKit

@main
struct FoundryMacApp: App {
    @State private var env = AppEnvironment.shared

    var body: some Scene {
        WindowGroup("Foundry", id: "main") {
            MacRootView()
                .environment(env)
                .modelContainer(env.container)
                .preferredColorScheme(.dark)
                .tint(Palette.accent)
                .frame(minWidth: 1200, minHeight: 760)
                .onOpenURL { env.handle($0) }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    env.becameActive()
                }
        }
        .defaultSize(width: 1360, height: 860)
        .windowStyle(.hiddenTitleBar)
        .commands { MacCommands(router: env.router, island: env.island) }

        Settings {
            SettingsView()
                .environment(env)
                .modelContainer(env.container)
                .preferredColorScheme(.dark)
                .frame(width: 540, height: 680)
        }

        MenuBarExtra {
            MenuBarView()
                .environment(env)
                .modelContainer(env.container)
                .preferredColorScheme(.dark)
        } label: {
            Image("MenuBarIcon")
                .accessibilityLabel("Foundry")
        }
        .menuBarExtraStyle(.window)
    }
}

/// ⌘1…⌘7 sections, ⌘N new name, ⌘⇧I enter the Island. (⌘, opens Settings automatically.)
struct MacCommands: Commands {
    var router: Router
    var island: IslandController

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Name") { router.requestNewTarget() }
                .keyboardShortcut("n", modifiers: .command)
        }
        CommandMenu("Go") {
            ForEach(Array(MacSection.allCases.enumerated()), id: \.element) { index, section in
                Button(section.title) { router.macSection = section }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
            Divider()
            Button("Enter the Island") { router.openIsland(start: true, island: island) }
                .keyboardShortcut("i", modifiers: [.command, .shift])
        }
    }
}
