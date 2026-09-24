import SwiftUI
import FoundryCore

/// Vitals: last night's sleep, Recovery, resting heart rate and this week's workouts.
struct VitalsScreen: View {
    @Environment(AppEnvironment.self) private var env
    @State private var explainAccess = false

    var body: some View {
        let _ = env.clock.todayKey
        let _ = env.store.revision
        let store = env.store
        let today = store.todayKey
        let vitals = store.vitals(for: today)
        let hasAnyData = !store.all(DailyVitals.self).isEmpty
        ScreenScroll {
            ScreenHeader {
                HexBadge(content: .glyph(.pulse), label: "Vitals")
            } trailing: {
                SyncChip(hasData: hasAnyData)
            }
            content(vitals: vitals, hasAnyData: hasAnyData)
        }
        .alert("Check Health access", isPresented: $explainAccess) {
            Button("Open Settings") { URLOpener.openAppSettings() }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("iPhone doesn't tell apps whether Health access was allowed. If Foundry shows nothing, open Settings › Apps › Foundry › Health (or the Health app › Sharing › Apps) and turn on Sleep, Workouts and Resting Heart Rate.")
        }
    }

    @ViewBuilder
    private func content(vitals: DailyVitals?, hasAnyData: Bool) -> some View {
        #if os(macOS)
        if hasAnyData {
            dashboard(vitals: vitals)
        } else {
            EmptyVitals(title: "NO VITALS HERE YET",
                        message: "Health lives on your iPhone. Turn on iCloud sync to see it here.")
        }
        #else
        if hasAnyData, env.health.access != .requested {
            // Data already here (synced from iCloud, or demo data): show it.
            dashboard(vitals: vitals)
        } else {
            accessStates(vitals: vitals, hasAnyData: hasAnyData)
        }
        #endif
    }

    #if os(iOS)
    @ViewBuilder
    private func accessStates(vitals: DailyVitals?, hasAnyData: Bool) -> some View {
        let health = env.health
        switch health.access {
        case .unavailable:
            if hasAnyData {
                dashboard(vitals: vitals)
            } else {
                EmptyVitals(title: "HEALTH IS OFF",
                            message: "This build of Foundry was made without Apple Health. SETUP.md shows how to switch it on.")
            }
        case .notDetermined:
            EmptyVitals(title: "CONNECT HEALTH",
                        message: "Foundry reads your sleep, workouts, and resting heart rate from Apple Health to show your Vitals and power your Recovery bonus. It never writes to Health.") {
                Button("CONNECT HEALTH") { Task { await health.requestAccess() } }
                    .buttonStyle(PrimaryButtonStyle())
            }
        case .requested:
            if hasAnyData, (vitals?.sleepMinutes ?? 0) > 0 || env.store.weekWorkoutCount() > 0 {
                dashboard(vitals: vitals)
            } else {
                EmptyVitals(title: "NO SLEEP RECORDED YET",
                            message: "Wear your Apple Watch to bed with Sleep turned on. Last night's rest will show here in the morning.") {
                    Button("CHECK HEALTH ACCESS") { explainAccess = true }
                        .buttonStyle(SecondaryButtonStyle())
                    Button("REFRESH") { Task { await health.refresh() } }
                        .buttonStyle(SecondaryButtonStyle(tint: Palette.textMuted, stroke: Palette.line))
                }
            }
        }
    }
    #endif

    private func dashboard(vitals: DailyVitals?) -> some View {
        let store = env.store
        let goal = store.profile().sleepGoalMinutes
        let workoutGoal = store.profile().weeklyWorkoutGoal
        let sleep = vitals?.sleep ?? SleepSummary()
        let rhr = vitals?.restingHR ?? store.vitals(for: store.keys.adding(-1, to: store.todayKey))?.restingHR
        return VStack(spacing: Metrics.sectionSpacing) {
            SleepRing(asleep: sleep.asleep, goal: goal)
                .frame(maxWidth: .infinity)
            if sleep.asleep > 0 {
                StageBar(sleep: sleep)
            }
            RecoveryPill(recovery: vitals?.recovery)
            HStack(spacing: 12) {
                StatTile(icon: "heart", iconColor: Palette.inkRed, label: "RESTING",
                         value: rhr.map(String.init) ?? "—", unit: "BPM")
                StatTile(icon: "", iconColor: Palette.accent, customGlyph: .dumbbell, label: "WORKOUTS",
                         value: "\(store.weekWorkoutCount())", unit: "OF \(workoutGoal)")
            }
            WorkoutBars(minutes: store.weekWorkoutMinutes(), todayIndex: store.keys.weekdayIndex(for: store.todayKey))
        }
    }
}

/// `HEALTH SYNCED` chip: tap to refresh (iPhone), shows time since the last sync.
struct SyncChip: View {
    var hasData: Bool
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        let health = env.health
        let last = health.lastSync ?? env.store.all(DailyVitals.self).map(\.updatedAt).max()
        Button {
            Task { await health.refresh() }
        } label: {
            Chip {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .rotationEffect(.degrees(health.isRefreshing ? 360 : 0))
                    .animation(health.isRefreshing ? .linear(duration: 0.9).repeatForever(autoreverses: false) : .default,
                               value: health.isRefreshing)
                Text(hasData ? "HEALTH SYNCED" : "NOT SYNCED").mono(12, tracking: 0.06)
                if let last, hasData {
                    Text(Self.ago(last)).mono(11, tracking: 0.04).foregroundStyle(Palette.textMuted)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!health.isAvailable)
        .accessibilityLabel(hasData ? "Synced with Apple Health" : "Not synced")
        .accessibilityValue(last.map { "Last sync \(Self.ago($0).lowercased()) ago" } ?? "")
        .accessibilityHint(health.isAvailable ? "Refreshes from Apple Health" : "")
    }

    static func ago(_ date: Date) -> String {
        let minutes = max(0, Int(Date().timeIntervalSince(date) / 60))
        if minutes < 1 { return "NOW" }
        if minutes < 60 { return "\(minutes)M" }
        if minutes < 60 * 24 { return "\(minutes / 60)H" }
        return "\(minutes / (60 * 24))D"
    }
}

/// Designed empty/denied states.
struct EmptyVitals<Actions: View>: View {
    var title: String
    var message: String
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().stroke(Palette.line, lineWidth: 12).frame(width: 180, height: 180)
                Circle().stroke(Palette.surface2, lineWidth: 1.5).frame(width: 132, height: 132)
                GlyphView(glyph: .pulse, size: 44, lineWidth: 2, color: Palette.textMuted)
            }
            .padding(.vertical, 8)
            .accessibilityHidden(true)
            Text(title).condensed(28, tracking: 0.06).foregroundStyle(Palette.text).multilineTextAlignment(.center)
            Text(message)
                .body(16)
                .foregroundStyle(Palette.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            actions
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .card()
    }
}

extension EmptyVitals where Actions == EmptyView {
    init(title: String, message: String) {
        self.init(title: title, message: message) { EmptyView() }
    }
}
