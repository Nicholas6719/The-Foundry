import SwiftUI
import SwiftData
import FoundryCore

/// The Mac's Foundry section: everything at a glance, in two flexible rows.
struct MacDashboard: View {
    @Environment(AppEnvironment.self) private var env
    @Query private var allTargets: [Target]
    @State private var targetSheet: TargetSheet?
    /// False until first shown, so arrows already fired don't all fly in again.
    @State private var appeared = false

    private let col1 = (min: CGFloat(340), max: CGFloat(440))
    private let col2 = (min: CGFloat(300), max: CGFloat(360))

    var body: some View {
        let _ = env.clock.todayKey
        let snap = env.store.liveSnapshot()
        ScrollView {
            VStack(spacing: 16) {
                header(snap)
                HStack(alignment: .top, spacing: 16) {
                    hubCard(snap).frame(minWidth: col1.min, maxWidth: col1.max)
                    quiverCard(snap).frame(minWidth: col2.min, maxWidth: col2.max)
                    notebookCard.frame(minWidth: 300, maxWidth: .infinity)
                }
                .frame(minHeight: 460)
                HStack(alignment: .top, spacing: 16) {
                    vitalsCard.frame(minWidth: col1.min, maxWidth: col1.max)
                    ladderCard.frame(minWidth: col2.min, maxWidth: col2.max)
                    islandCard.frame(minWidth: 300, maxWidth: .infinity)
                }
                .frame(minHeight: 250)
            }
            .padding(EdgeInsets(top: 22, leading: 32, bottom: 22, trailing: 32))
        }
        .onAppear { DispatchQueue.main.async { appeared = true } }
        .sheet(item: $targetSheet) { item in
            TargetEditor(target: item.target) { targetSheet = nil }
                .environment(env)
                .frame(width: 520)
        }
    }

    private func header(_ snap: TodaySnapshot) -> some View {
        HStack(spacing: 16) {
            Text(Self.dateLine(env.clock.now)).mono(13, tracking: 0.1).foregroundStyle(Palette.textMuted)
            Chip(height: 36) {
                GlyphView(glyph: .arrowUpRight, size: 16, lineWidth: 2)
                Text("\(snap.streak) DAY STREAK").mono(12, tracking: 0.06)
            }
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "moon").font(.system(size: 15, weight: .semibold))
                Text(focusText).body(15, weight: .medium)
            }
            .foregroundStyle(env.focus.pill == .on ? Palette.accent : Palette.textMuted)
            .padding(.horizontal, 16)
            .frame(height: 44)
            .card(radius: 12, stroke: env.focus.pill == .on ? Palette.accent : Palette.line)
            .accessibilityElement(children: .combine)
            Button {
                env.router.openIsland(start: true, island: env.island)
            } label: {
                HStack(spacing: 10) {
                    GlyphView(glyph: .crosshair, size: 20, lineWidth: 2, color: Palette.onAccent)
                    Text("ENTER THE ISLAND")
                }
            }
            .buttonStyle(PrimaryButtonStyle(height: 44, fontSize: 19))
            .fixedSize()
        }
        .frame(height: 48)
    }

    private var focusText: String {
        switch env.focus.pill {
        case .on: "Foundry Focus: on"
        case .off: "Foundry Focus: off"
        case .setUp: "Foundry Focus: not set up"
        }
    }

    private func hubCard(_ snap: TodaySnapshot) -> some View {
        VStack(spacing: 16) {
            RadarView(snapshot: snap, centerFill: Palette.surface, hexFill: Palette.bg, pulse: env.bullseyePulse) { station in
                switch station {
                case .list: env.router.macSection = .list
                case .quiver: env.router.macSection = .quiver
                case .train: env.router.macSection = .train
                case .vitals: env.router.macSection = .vitals
                case .island: env.router.macSection = .island
                }
            }
            .frame(maxWidth: 366)
            MissionCard(mission: snap.mission, compact: true, fill: Palette.bg) {
                env.router.openIsland(start: true, island: env.island)
            }
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .card(radius: 18)
    }

    private func quiverCard(_ snap: TodaySnapshot) -> some View {
        VStack(spacing: 16) {
            TargetBoard(fired: snap.habitsDone, total: snap.habitsTotal, animateNew: appeared)
                .frame(maxWidth: 280)
            HabitButtonsView(states: env.store.habitStates(), size: 56)
            WeekTargets(week: snap.week, todayIndex: snap.todayIndex, size: 24, showLetters: false, cutout: Palette.surface)
                .padding(.top, 12)
                .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .card(radius: 18)
    }

    private var notebookCard: some View {
        let byID = Dictionary(allTargets.map { ($0.id.uuidString, $0) }, uniquingKeysWith: { a, _ in a })
        let ordered = TargetOrdering.sorted(allTargets.map(\.snapshot)).compactMap { byID[$0.id] }
        return VStack(spacing: 14) {
            NotebookView(targets: Array(ordered.prefix(5)), nameSize: 30, rowHeight: 78, fixedHeight: 430) {
                targetSheet = .edit($0)
            }
            Button {
                targetSheet = .new
            } label: {
                Label("ADD A NAME", systemImage: "plus")
            }
            .buttonStyle(SecondaryButtonStyle(height: 56))
        }
    }

    @ViewBuilder
    private var vitalsCard: some View {
        let store = env.store
        let vitals = store.vitals(for: store.todayKey)
        Group {
            if let vitals, vitals.sleepMinutes > 0 || store.weekWorkoutCount() > 0 {
                HStack(alignment: .center, spacing: 16) {
                    SleepRing(asleep: vitals.sleepMinutes, goal: store.profile().sleepGoalMinutes, diameter: 118, showGoal: false)
                    VStack(spacing: 12) {
                        StageBar(sleep: vitals.sleep, height: 12, showLegend: false)
                        RecoveryPill(recovery: vitals.recovery, height: 40, fontSize: 15, includeToday: false)
                        WorkoutBars(minutes: store.weekWorkoutMinutes(),
                                    todayIndex: store.keys.weekdayIndex(for: store.todayKey), height: 70, maxBar: 42)
                    }
                }
            } else {
                VStack(spacing: 10) {
                    GlyphView(glyph: .pulse, size: 36, lineWidth: 2, color: Palette.textMuted)
                    Text("Health lives on your iPhone. Turn on iCloud sync to see it here.")
                        .body(15)
                        .foregroundStyle(Palette.textMuted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(20)
        .frame(maxHeight: .infinity)
        .card(radius: 18)
        .onTapGesture { env.router.macSection = .vitals }
    }

    @ViewBuilder
    private var ladderCard: some View {
        let store = env.store
        if let day = store.todaysWorkoutDay(), let lead = store.liftsToday(for: day).first(where: { $0.lift.isLead }) ?? store.liftsToday(for: day).first {
            LeadLiftCard(item: lead, ladderWidth: 120, numeralSize: 72) { env.router.macSection = .train }
                .frame(maxHeight: .infinity)
        } else {
            VStack(spacing: 12) {
                GlyphView(glyph: .ladder, size: 36, lineWidth: 2, color: Palette.textMuted)
                Text(store.workoutDays().isEmpty ? "No ladder yet." : "Rest day.").body(16, weight: .medium).foregroundStyle(Palette.text)
                Button("OPEN TRAINING") { env.router.macSection = .train }
                    .buttonStyle(SecondaryButtonStyle(height: 40, fontSize: 17))
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .card(radius: 18)
        }
    }

    private var islandCard: some View {
        let island = env.island
        return TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 12) {
                IslandRing(progress: island.progress(at: context.date), active: island.isActive, diameter: 108, guides: false) {
                    Text(Clock.text(island.remaining(at: context.date)))
                        .font(FoundryFont.fixed(.monoMedium, size: 24))
                        .foregroundStyle(Palette.text)
                }
                Button(island.isActive ? "OPEN THE ISLAND" : "BEGIN FOCUS") {
                    env.router.openIsland(start: !island.isActive, island: island)
                }
                .buttonStyle(PrimaryButtonStyle(height: 44, fontSize: 19))
                HStack(spacing: 8) {
                    Image(systemName: "moon").font(.system(size: 15, weight: .semibold))
                    Text("Turns on Foundry Focus · signal stays on").body(14, weight: .medium)
                }
                .foregroundStyle(Palette.textMuted)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .card(radius: 18)
        }
    }

    /// `THURSDAY · SEP 24`.
    static func dateLine(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEEE · MMM d"
        return f.string(from: date).uppercased()
    }
}
