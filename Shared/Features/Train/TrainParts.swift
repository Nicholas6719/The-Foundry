import SwiftUI
import FoundryCore

/// Everything a lift card needs for today.
struct LiftToday: Identifiable {
    var lift: LiftDef
    var loggedSets: Set<Int>
    var climbedToday: Bool
    var id: UUID { lift.id }

    var isComplete: Bool { loggedSets.count >= lift.sets }
}

extension FoundryStore {
    func liftsToday(for day: WorkoutDay) -> [LiftToday] {
        let today = todayKey
        return lifts(for: day).map { lift in
            LiftToday(lift: lift, loggedSets: Set(setLogs(for: lift, on: today).map(\.setIndex)),
                      climbedToday: lift.lastClimbDayKey == today)
        }
    }
}

/// Ladder plus the big weight for the lead lift.
struct LeadLiftCard: View {
    var item: LiftToday
    var ladderWidth: CGFloat = 190
    var numeralSize: CGFloat = 76
    var holdAnimation = false
    var onOpen: () -> Void

    var body: some View {
        let lift = item.lift
        HStack(spacing: 14) {
            LadderView(currentRung: lift.currentRung, start: lift.startWeightLb, step: lift.stepLb,
                       holdAnimation: holdAnimation)
                .frame(maxWidth: ladderWidth)
            VStack(alignment: .leading, spacing: 4) {
                Text(LadderRules.format(lift.currentWeight))
                    .condensed(numeralSize, tracking: 0, relativeTo: .largeTitle)
                    .foregroundStyle(Palette.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: lift.currentRung)
                Text("LB · RUNG \(lift.currentRung)").mono(12, tracking: 0.1).foregroundStyle(Palette.textMuted)
                HStack(spacing: 6) {
                    ForEach(0..<lift.sets, id: \.self) { i in
                        SetDot(filled: item.loggedSets.contains(i), size: 16)
                    }
                }
                .padding(.top, 14)
                .accessibilityElement()
                .accessibilityLabel("\(item.loggedSets.count) of \(lift.sets) sets complete")
                HStack(spacing: 6) {
                    GlyphView(glyph: item.climbedToday ? .check : .chevronUp, size: 16, lineWidth: 2.5)
                    Text(item.climbedToday
                         ? "CLIMBED FROM \(LadderRules.format(lift.weight(forRung: lift.currentRung - 1)))"
                         : "NEXT \(LadderRules.format(lift.weight(forRung: lift.currentRung + 1)))")
                        .mono(12, tracking: 0.06)
                }
                .foregroundStyle(Palette.accent)
                .padding(.top, 14)
                Text(lift.name.uppercased())
                    .mono(11, tracking: 0.1)
                    .foregroundStyle(Palette.textMuted)
                    .padding(.top, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .card()
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens set logging for \(lift.name)")
    }
}

/// A 2×2 grid tile for one lift.
struct LiftTile: View {
    var item: LiftToday
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(item.lift.name.uppercased())
                        .condensed(22, tracking: 0.04, relativeTo: .title3)
                        .foregroundStyle(Palette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Spacer(minLength: 4)
                    if item.isComplete {
                        GlyphView(glyph: .check, size: 18, lineWidth: 2.5)
                    }
                }
                HStack(spacing: 6) {
                    ForEach(0..<item.lift.sets, id: \.self) { i in
                        SetDot(filled: item.loggedSets.contains(i))
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(radius: Metrics.tileRadius)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.lift.name)
        .accessibilityValue(item.isComplete ? "Done" : "\(item.loggedSets.count) of \(item.lift.sets) sets")
        .accessibilityHint("Opens set logging")
    }
}

/// Rest-day card with last night's Recovery.
struct RestDayCard: View {
    var recovery: Int?
    var days: [WorkoutDay]
    var onStart: (WorkoutDay) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("REST DAY").condensed(44, tracking: 0.06).foregroundStyle(Palette.text)
            Text("Nothing on the ladder today. Recover, or pick a day and climb anyway.")
                .body(16)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            if let recovery {
                HStack(spacing: 8) {
                    Image(systemName: "bolt").font(.system(size: 16, weight: .semibold))
                    Text("RECOVERY \(recovery)%").condensed(20, tracking: 0.06)
                }
                .foregroundStyle(Palette.accent)
                .accessibilityElement(children: .combine)
            }
            ForEach(days) { day in
                Button("START \(day.name)") { onStart(day) }
                    .buttonStyle(SecondaryButtonStyle(height: 48, fontSize: 18))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
