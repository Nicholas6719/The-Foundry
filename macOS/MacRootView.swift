import SwiftUI
import SwiftData
import FoundryCore

/// Mac shell: sidebar plus the selected section.
struct MacRootView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        @Bindable var router = env.router
        NavigationSplitView {
            MacSidebar(selection: $router.macSection)
                .frame(minWidth: 232)
                .navigationSplitViewColumnWidth(min: 232, ideal: 232, max: 232)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            detail(router.macSection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.bg)
                .overlay(alignment: .top) { CelebrationOverlay().frame(maxWidth: 520) }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: onboardingBinding) {
            OnboardingView()
                .environment(env)
                .frame(width: 560, height: 680)
                .interactiveDismissDisabled()
        }
    }

    @ViewBuilder
    private func detail(_ section: MacSection) -> some View {
        switch section {
        case .foundry: MacDashboard()
        case .list: ListScreen(nameSize: 30)
        case .quiver: QuiverScreen()
        case .train: TrainScreen()
        case .vitals: VitalsScreen()
        case .island: IslandScreen(isWindow: true) { env.router.macSection = .foundry }
        case .rank: RankScreen(showsBack: false)
        }
    }

    private var onboardingBinding: Binding<Bool> {
        Binding(get: { env.needsOnboarding }, set: { _ in })
    }
}

/// 232 pt sidebar: wordmark, sections, rank card pinned at the bottom.
struct MacSidebar: View {
    @Binding var selection: MacSection
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        let _ = env.store.revision
        let progress = RankProgress(xp: env.store.totalXP)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                HexBadge(content: .emblem, size: 40, label: "Foundry")
                Text("FOUNDRY").condensed(26, tracking: 0.12).foregroundStyle(Palette.text)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 22)
            ForEach(Array(MacSection.allCases.enumerated()), id: \.element) { index, section in
                let active = section == selection
                Button { selection = section } label: {
                    HStack(spacing: 12) {
                        GlyphView(glyph: section.glyph, size: 22, color: active ? Palette.accent : Palette.textMuted)
                        Text(section.title).body(16, weight: .medium)
                        Spacer()
                    }
                    .foregroundStyle(active ? Palette.accent : Palette.textMuted)
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(active ? Palette.surface2 : .clear, in: RoundedRectangle(cornerRadius: 10))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(section.title)
                .accessibilityHint("Command \(index + 1)")
                .accessibilityAddTraits(active ? .isSelected : [])
            }
            Spacer()
            Button { selection = .rank } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        GlyphView(glyph: .chevrons, size: 20, lineWidth: 2)
                        Text(progress.rank.title).condensed(22, tracking: 0.08)
                    }
                    .foregroundStyle(Palette.accent)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Palette.bg)
                            Capsule().fill(Palette.accent).frame(width: geo.size.width * progress.fraction)
                        }
                    }
                    .frame(height: 8)
                    Text(progress.nextThreshold.map { "\(progress.xp.formatted()) / \($0.formatted()) XP" } ?? "\(progress.xp.formatted()) XP")
                        .mono(11, tracking: 0.06)
                        .foregroundStyle(Palette.textMuted)
                }
                .padding(14)
                .card(radius: 14)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens Rank")
        }
        .padding(EdgeInsets(top: 28, leading: 16, bottom: 20, trailing: 16))
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Palette.tabBar.ignoresSafeArea())
    }
}
