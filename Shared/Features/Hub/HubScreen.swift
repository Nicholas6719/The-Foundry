import SwiftUI
import FoundryCore

/// iPhone: the Foundry hub.
struct HubScreen: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        let _ = env.clock.todayKey
        let snap = env.store.liveSnapshot()
        ScreenScroll {
            ScreenHeader {
                HexBadge(content: .emblem, label: "The Foundry")
            } trailing: {
                RankChip(xp: snap.totalXP, rank: snap.rank.rank) { env.router.showRank = true }
            }
            RadarView(snapshot: snap, pulse: env.bullseyePulse) { station in
                select(station)
            }
            .frame(maxWidth: 420)
            .frame(maxWidth: .infinity)
            MissionCard(mission: snap.mission) {
                env.router.openIsland(start: true, island: env.island)
            }
            StreakRow(streak: snap.streak, week: snap.week)
        }
    }

    private func select(_ station: Station) {
        switch station {
        case .list: env.router.tab = .list
        case .quiver: env.router.tab = .quiver
        case .train: env.router.tab = .train
        case .vitals: env.router.tab = .vitals
        case .island: env.router.openIsland(start: false, island: env.island)
        }
    }
}
