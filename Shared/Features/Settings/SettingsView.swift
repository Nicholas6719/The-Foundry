import SwiftUI
import SwiftData
import FoundryCore

enum SettingsSheet: Identifiable {
    case habit(Habit?)
    case focus

    var id: String {
        switch self {
        case .habit(let h): "habit-\(h?.id.uuidString ?? "new")"
        case .focus: "focus"
        }
    }
}

/// Settings: habits, goals, Health, Focus, sync, about (and debug tools in debug builds).
struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Habit> { !$0.isArchived }, sort: \Habit.sortOrder) private var habits: [Habit]
    @Query private var profiles: [Profile]
    @State private var sheet: SettingsSheet?
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                habitsSection
                if let profile = profiles.first { GoalsSection(profile: profile) }
                healthSection
                focusSection
                syncSection
                aboutSection
                #if DEBUG
                debugSection
                #endif
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Palette.bg)
            .tint(Palette.accent)
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) { EditButton() }
            }
            #endif
        }
        .sheet(item: $sheet) { item in
            Group {
                switch item {
                case .habit(let habit): HabitEditor(habit: habit) { sheet = nil }
                case .focus: FocusSetupView { sheet = nil }
                }
            }
            .environment(env)
            .presentationBackground(Palette.bg)
            #if os(macOS)
            .frame(minWidth: 480, minHeight: 560)
            #endif
        }
        .confirmationDialog("Erase everything in Foundry?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Erase All Data", role: .destructive) { env.store.deleteEverything() }
        } message: {
            Text("Names, habits, lifts, XP and medals on this device are removed.")
        }
    }

    private var habitsSection: some View {
        Section {
            ForEach(habits) { habit in
                Button { sheet = .habit(habit) } label: {
                    HStack(spacing: 12) {
                        HabitGlyphView(glyph: habit.habitGlyph, size: 22, color: Palette.accent)
                        Text(habit.name).foregroundStyle(Palette.text)
                        Spacer()
                        if habit.rule != .none {
                            Text(habit.rule == .workout ? "AUTO · WORKOUT" : "AUTO · SLEEP").mono(10).foregroundStyle(Palette.textMuted)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(Palette.surface)
            }
            .onMove { env.store.moveHabits(from: $0, to: $1) }
            if habits.count < GameRules.maxHabits {
                Button { sheet = .habit(nil) } label: {
                    Label("Add Habit", systemImage: "plus")
                }
                .listRowBackground(Palette.surface)
            }
        } header: {
            MonoTitle(text: "HABITS")
        } footer: {
            Text("Up to \(GameRules.maxHabits). Drag to reorder.").foregroundStyle(Palette.textMuted)
        }
    }

    private var healthSection: some View {
        Section {
            let health = env.health
            switch health.access {
            case .unavailable:
                #if os(macOS)
                row("Apple Health", value: "Read on iPhone")
                #else
                row("Apple Health", value: "Off in this build")
                #endif
            case .notDetermined:
                row("Apple Health", value: "Not connected")
                Button("Connect Health") { Task { await health.requestAccess() } }
                    .listRowBackground(Palette.surface)
            case .requested:
                row("Apple Health", value: health.lastSync.map { "Synced \(SyncChip.ago($0).lowercased()) ago" } ?? "Connected")
                #if os(iOS)
                Button("Review Access in Settings") { URLOpener.openAppSettings() }
                    .listRowBackground(Palette.surface)
                #endif
            }
        } header: {
            MonoTitle(text: "HEALTH")
        } footer: {
            Text("Read only: sleep, workouts and resting heart rate. Only daily summaries sync, to your own private iCloud.")
                .foregroundStyle(Palette.textMuted)
        }
    }

    private var focusSection: some View {
        Section {
            row("Foundry Focus", value: env.focus.isConfigured ? "Set up" : "Not set up")
            Button(env.focus.isConfigured ? "Setup and Test" : "Set Up Foundry Focus") { sheet = .focus }
                .listRowBackground(Palette.surface)
        } header: {
            MonoTitle(text: "FOCUS")
        } footer: {
            Text("To start the Island whenever you turn the Foundry Focus on yourself, add the \"Foundry behavior\" filter in Settings › Focus › Foundry and switch it on.")
                .foregroundStyle(Palette.textMuted)
        }
    }

    private var syncSection: some View {
        Section {
            row("iCloud sync", value: syncText)
        } header: {
            MonoTitle(text: "SYNC")
        } footer: {
            Text(env.syncState == .iCloud
                 ? "Your data syncs through your private iCloud between iPhone and Mac."
                 : "Sync is switched off in this build. SETUP.md explains how to turn it on.")
                .foregroundStyle(Palette.textMuted)
        }
    }

    private var syncText: String {
        switch env.syncState {
        case .iCloud: "On"
        case .localOnly: "Off (this device only)"
        case .memoryOnly: "Unavailable"
        }
    }

    private var aboutSection: some View {
        Section {
            row("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
            Text("A personal project for personal use. Not affiliated with or endorsed by any rights holder.")
                .font(.footnote)
                .foregroundStyle(Palette.textMuted)
                .listRowBackground(Palette.surface)
        } header: {
            MonoTitle(text: "ABOUT")
        }
    }

    #if DEBUG
    private var debugSection: some View {
        Section {
            Button("Load Demo Data") { DemoData.load(into: env.store) }
                .listRowBackground(Palette.surface)
            Button("Reset All Data", role: .destructive) { confirmReset = true }
                .listRowBackground(Palette.surface)
        } header: {
            MonoTitle(text: "DEBUG")
        }
    }
    #endif

    private func row(_ title: String, value: String) -> some View {
        LabeledContent(title) {
            Text(value).foregroundStyle(Palette.textMuted)
        }
        .foregroundStyle(Palette.text)
        .listRowBackground(Palette.surface)
    }
}

/// Goals, bound to the profile, re-scoring Recovery when the sleep goal changes.
struct GoalsSection: View {
    @Bindable var profile: Profile
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        Section {
            Stepper(value: $profile.sleepGoalMinutes, in: 300...660, step: 15) {
                LabeledContent("Sleep goal", value: SleepBuilder.formatDuration(minutes: profile.sleepGoalMinutes))
            }
            .listRowBackground(Palette.surface)
            Stepper(value: $profile.weeklyWorkoutGoal, in: 1...7) {
                LabeledContent("Workouts per week", value: "\(profile.weeklyWorkoutGoal)")
            }
            .listRowBackground(Palette.surface)
            Picker("Focus length", selection: $profile.focusMinutes) {
                ForEach(GameRules.focusLengthOptions, id: \.self) { Text("\($0) min").tag($0) }
            }
            .listRowBackground(Palette.surface)
            Stepper(value: $profile.focusSessionsGoal, in: 1...8) {
                LabeledContent("Island sessions per day", value: "\(profile.focusSessionsGoal)")
            }
            .listRowBackground(Palette.surface)
        } header: {
            MonoTitle(text: "GOALS")
        }
        .foregroundStyle(Palette.text)
        .onChange(of: profile.sleepGoalMinutes) { env.store.goalsChanged() }
        .onChange(of: profile.weeklyWorkoutGoal) { env.store.save() }
        .onChange(of: profile.focusMinutes) { env.store.save() }
        .onChange(of: profile.focusSessionsGoal) { env.store.save() }
    }
}
