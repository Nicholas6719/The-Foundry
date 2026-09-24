import SwiftUI
import SwiftData
import FoundryCore

/// Sheet routing for the List (new or editing one).
enum TargetSheet: Identifiable {
    case new
    case edit(Target)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let t): t.id.uuidString
        }
    }

    var target: Target? {
        if case .edit(let t) = self { return t }
        return nil
    }
}

/// Five pips: filled red for struck, hollow for open, `+N` beyond five.
struct StrikePips: View {
    var struck: Int
    var open: Int

    var body: some View {
        let total = struck + open
        HStack(spacing: 8) {
            ForEach(0..<min(total, 5), id: \.self) { i in
                if i < struck {
                    Circle().fill(Palette.inkRed).frame(width: 12, height: 12)
                } else {
                    Circle().strokeBorder(Palette.textMuted, lineWidth: 1.5).frame(width: 11, height: 11)
                }
            }
            if total > 5 {
                Text("+\(total - 5)").mono(12, tracking: 0.04).foregroundStyle(Palette.textMuted)
            }
            if total == 0 {
                Text("EMPTY").mono(12).foregroundStyle(Palette.textMuted)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(total == 0 ? "No names yet" : "\(struck) of \(total) names struck")
    }
}

/// The List screen (iPhone, and the Mac's larger version).
struct ListScreen: View {
    var nameSize: CGFloat = 36

    @Environment(AppEnvironment.self) private var env
    @Query private var allTargets: [Target]
    @State private var sheet: TargetSheet?

    private var ordered: [Target] {
        let byID = Dictionary(allTargets.map { ($0.id.uuidString, $0) }, uniquingKeysWith: { a, _ in a })
        return TargetOrdering.sorted(allTargets.map(\.snapshot)).compactMap { byID[$0.id] }
    }

    var body: some View {
        let struck = allTargets.filter(\.isStruck).count
        ScreenScroll {
            ScreenHeader {
                HexBadge(content: .glyph(.notebook), label: "The List")
            } trailing: {
                Chip { StrikePips(struck: struck, open: allTargets.count - struck) }
            }
            NotebookView(targets: ordered, nameSize: nameSize) { sheet = .edit($0) }
            HStack {
                Spacer()
                RoundAccentButton(systemImage: "plus", diameter: 64, label: "Add a name to the List") {
                    sheet = .new
                }
                Spacer()
            }
            .padding(.top, 4)
        }
        .sheet(item: $sheet) { item in
            TargetEditor(target: item.target) { sheet = nil }
                .environment(env)
                .presentationDetents([.large])
                .presentationBackground(Palette.bg)
        }
        .onChange(of: env.router.newTargetRequests) { sheet = .new }
    }
}
