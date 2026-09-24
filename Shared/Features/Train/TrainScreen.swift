import SwiftUI
import FoundryCore

enum TrainSheet: Identifiable {
    case lift(LiftDef)
    case build
    case edit(WorkoutDay)

    var id: String {
        switch self {
        case .lift(let l): "lift-\(l.id)"
        case .build: "build"
        case .edit(let d): "edit-\(d.id)"
        }
    }
}

/// Training: the salmon ladder for today's workout day.
struct TrainScreen: View {
    @Environment(AppEnvironment.self) private var env
    @State private var sheet: TrainSheet?

    var body: some View {
        let _ = env.clock.todayKey
        let _ = env.store.revision
        let store = env.store
        let days = store.workoutDays()
        let day = store.todaysWorkoutDay()
        let items = day.map { store.liftsToday(for: $0) } ?? []
        let lead = items.first { $0.lift.isLead } ?? items.first
        ScreenScroll {
            ScreenHeader {
                HexBadge(content: .glyph(.ladder), label: "Training")
            } trailing: {
                Chip {
                    GlyphView(glyph: .dumbbell, size: 18, lineWidth: 2)
                    Text(day?.name ?? (days.isEmpty ? "NO DAYS" : "REST")).mono(13, tracking: 0.06)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(day.map { "\($0.name.capitalized) day" } ?? "Rest day")
            }
            if days.isEmpty {
                emptyState
            } else if let day, let lead {
                LeadLiftCard(item: lead, holdAnimation: sheet != nil) { sheet = .lift(lead.lift) }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(items) { item in
                        LiftTile(item: item) { sheet = .lift(item.lift) }
                    }
                }
                footer(day: day, days: days)
            } else if let day {
                Text("\(day.name) has no lifts yet.").body(17).foregroundStyle(Palette.textMuted)
                Button("ADD LIFTS") { sheet = .edit(day) }.buttonStyle(PrimaryButtonStyle())
            } else {
                RestDayCard(recovery: store.vitals(for: store.todayKey)?.recovery, days: days) { picked in
                    store.startDay(picked)
                    store.touch()
                }
                footer(day: nil, days: days)
            }
        }
        .sheet(item: $sheet) { item in
            Group {
                switch item {
                case .lift(let lift): LiftSheet(lift: lift) { sheet = nil }
                case .build: BuildDaySheet(day: nil) { sheet = nil }
                case .edit(let d): BuildDaySheet(day: d) { sheet = nil }
                }
            }
            .environment(env)
            .presentationBackground(Palette.bg)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            LadderView(currentRung: 1, start: 45, step: 5)
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .opacity(0.5)
                .accessibilityHidden(true)
            Text("NO LADDER YET").condensed(34, tracking: 0.06).foregroundStyle(Palette.text)
            Text("Build a workout day: name it, pick the weekdays, add your lifts. Every clean session climbs a rung.")
                .body(16)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            Button("BUILD YOUR FIRST DAY") { sheet = .build }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(18)
        .card()
    }

    private func footer(day: WorkoutDay?, days: [WorkoutDay]) -> some View {
        HStack(spacing: 12) {
            if let day {
                Button("EDIT \(day.name)") { sheet = .edit(day) }
                    .buttonStyle(SecondaryButtonStyle(height: 44, fontSize: 17, tint: Palette.textMuted, stroke: Palette.line))
            }
            Button("NEW DAY") { sheet = .build }
                .buttonStyle(SecondaryButtonStyle(height: 44, fontSize: 17, tint: Palette.textMuted, stroke: Palette.line))
        }
        .padding(.top, 4)
    }
}
