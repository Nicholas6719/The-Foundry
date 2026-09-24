import SwiftUI
import FoundryCore

/// Rank: XP progress, the rank path and the six medals.
struct RankScreen: View {
    var showsBack = true

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    #if os(macOS)
    @Environment(\.openSettings) private var openSettings
    #endif

    var body: some View {
        let _ = env.store.revision
        let progress = RankProgress(xp: env.store.totalXP)
        let earned = Set(env.store.all(MedalUnlock.self).compactMap { MedalID(rawValue: $0.medalID) })
        ScreenScroll {
            ScreenHeader {
                if showsBack {
                    CircleIconButton(systemImage: "chevron.left", label: "Back to the Foundry") {
                        env.router.showRank = false
                        dismiss()
                    }
                } else {
                    HexBadge(content: .glyph(.chevrons), label: "Rank")
                }
            } trailing: {
                HStack(spacing: 12) {
                    CircleIconButton(systemImage: "gearshape", label: "Settings") { openSettingsAction() }
                    if showsBack {
                        HexBadge(content: .glyph(.chevrons), label: "Rank")
                    }
                }
            }
            VStack(spacing: 12) {
                RankEmblem(fraction: progress.fraction)
                Text(progress.rank.title)
                    .condensed(44, tracking: 0.06, relativeTo: .largeTitle)
                    .foregroundStyle(Palette.text)
                    .multilineTextAlignment(.center)
                Text(xpLine(progress)).mono(12, tracking: 0.08).foregroundStyle(Palette.textMuted)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            RankPath(current: progress.rank)
                .padding(.horizontal, 10)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 12) {
                ForEach(MedalID.allCases, id: \.self) { medal in
                    MedalBadge(medal: medal, earned: earned.contains(medal))
                }
            }
            .padding(.top, 4)
        }
    }

    private func xpLine(_ p: RankProgress) -> String {
        if let next = p.nextThreshold {
            return "\(p.xp.formatted()) / \(next.formatted()) XP"
        }
        return "\(p.xp.formatted()) XP · TOP RANK"
    }

    private func openSettingsAction() {
        #if os(macOS)
        openSettings()
        #else
        env.router.showSettings = true
        #endif
    }
}
