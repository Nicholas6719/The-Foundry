import SwiftUI

/// Custom five-tab bar: `tabBar` fill, hairline top border, mono uppercase labels.
struct FoundryTabBar: View {
    @Binding var selection: AppTab
    var onReselect: () -> Void = {}
    @ScaledMetric(relativeTo: .caption2) private var labelSize: CGFloat = 11

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                let active = tab == selection
                Button {
                    if tab == selection { onReselect() }
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        GlyphView(glyph: tab.glyph, size: 24, color: active ? Palette.accent : Palette.tabInactive)
                        Text(tab.title)
                            .font(FoundryFont.fixed(.monoRegular, size: min(labelSize, 15)))
                            .tracking(0.66)
                            .textCase(.uppercase)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(active ? Palette.accent : Palette.tabInactive)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.accessibilityName)
                .accessibilityAddTraits(active ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(.top, 6)
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
        .background {
            Palette.tabBar
                .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
                .ignoresSafeArea(edges: .bottom)
        }
    }
}
