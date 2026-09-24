import SwiftUI
import FoundryCore

/// The notebook page: spiral holes, ruled rows, Caveat names.
struct NotebookView: View {
    var targets: [Target]
    var nameSize: CGFloat = 36
    var rowHeight: CGFloat = 76
    var minRows = 5
    var fixedHeight: CGFloat? = nil
    var onEdit: (Target) -> Void

    @Environment(AppEnvironment.self) private var env

    var body: some View {
        let paper = UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 6,
                                           bottomTrailingRadius: 16, topTrailingRadius: 16, style: .continuous)
        VStack(spacing: 0) {
            if targets.isEmpty {
                Text("Write the first name.")
                    .script(nameSize)
                    .foregroundStyle(Palette.inkMuted)
                    .frame(maxWidth: .infinity, minHeight: rowHeight * CGFloat(minRows) - 40)
                    .accessibilityLabel("The List is empty. Write the first name.")
            } else {
                ForEach(Array(targets.enumerated()), id: \.element.id) { index, target in
                    NotebookRow(target: target, nameSize: nameSize, rowHeight: rowHeight,
                                isLast: index == targets.count - 1,
                                onToggle: { env.toggleStrike(target) },
                                onEdit: { onEdit(target) },
                                onDelete: { withAnimation { env.store.delete(target) } })
                }
                Spacer(minLength: 0)
            }
        }
        .padding(EdgeInsets(top: 20, leading: 52, bottom: 20, trailing: 20))
        .frame(minHeight: fixedHeight ?? (rowHeight * CGFloat(minRows) + 40), alignment: .top)
        .frame(height: fixedHeight, alignment: .top)
        .background(alignment: .topLeading) {
            SpiralHoles().allowsHitTesting(false)
        }
        .background(Palette.paper, in: paper)
        .clipShape(paper)
        .shadow(color: Palette.shadow, radius: 15, y: 10)
    }
}

/// Punched holes down the left edge, one every 52 points.
struct SpiralHoles: View {
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 40
            while y < size.height - 8 {
                ctx.fill(Path(ellipseIn: CGRect(x: 25 - 6, y: y - 6, width: 12, height: 12)), with: .color(Palette.bg))
                y += 52
            }
        }
        .accessibilityHidden(true)
    }
}

/// One name on the page.
struct NotebookRow: View {
    var target: Target
    var nameSize: CGFloat
    var rowHeight: CGFloat
    var isLast: Bool
    var onToggle: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var strike: CGFloat = 0
    @State private var circle: CGFloat = 0
    @State private var swipe: CGFloat = 0

    private var tag: DueTag? {
        guard !target.isStruck, let due = target.dueDate else { return nil }
        return DueTagRules.tag(due: due, now: Date())
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            if swipe < 0 {
                Button(role: .destructive, action: onDelete) {
                    Text("DELETE").mono(12, tracking: 0.08)
                        .foregroundStyle(Palette.paper)
                        .frame(width: max(0, -swipe), height: rowHeight - 12)
                        .background(Palette.inkRedPaper, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            content
                .offset(x: swipe)
        }
        .frame(minHeight: rowHeight)
        .overlay(alignment: .bottom) {
            if !isLast { Rectangle().fill(Palette.paperRule).frame(height: 1) }
        }
        .onAppear {
            strike = target.isStruck ? 1 : 0
            circle = target.isPrimary && !target.isStruck ? 1 : 0
        }
        .onChange(of: target.isStruck) { _, struck in
            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .easeOut(duration: 0.35)) {
                strike = struck ? 1 : 0
                circle = target.isPrimary && !struck ? 1 : 0
            }
        }
        .onChange(of: target.isPrimary) { _, primary in
            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .easeOut(duration: 0.6)) {
                circle = primary && !target.isStruck ? 1 : 0
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(target.title)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(target.isStruck ? "Double-tap to restore" : "Double-tap to strike")
        .accessibilityAction { onToggle() }
        .accessibilityAction(named: "Edit") { onEdit() }
        .accessibilityAction(named: "Delete") { onDelete() }
        #if os(macOS)
        .contextMenu {
            Button(target.isStruck ? "Restore" : "Strike", action: onToggle)
            Button("Edit…", action: onEdit)
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
        #endif
    }

    private var content: some View {
        HStack(spacing: 12) {
            name
            Spacer(minLength: 8)
            if let tag {
                Text(tag.text)
                    .mono(12, tracking: 0.06)
                    .foregroundStyle(tag.isOverdue || target.isPrimary ? Palette.inkRedPaper : Palette.inkMuted)
            }
        }
        .frame(maxWidth: .infinity, minHeight: rowHeight, alignment: .leading)
        .background(Palette.paper)
        .contentShape(Rectangle())
        .onTapGesture {
            if swipe < 0 { withAnimation(.snappy) { swipe = 0 } } else { onToggle() }
        }
        .onLongPressGesture(minimumDuration: 0.45) { onEdit() }
        #if os(iOS)
        .simultaneousGesture(swipeGesture)
        #endif
    }

    private var name: some View {
        Text(target.title)
            .script(nameSize)
            .foregroundStyle(target.isStruck ? Palette.inkFaded : Palette.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.trailing, 4) // Caveat's slant overhangs its advance width
            .overlay {
                GeometryReader { geo in
                    Capsule()
                        .fill(Palette.inkRedPaper)
                        .frame(width: geo.size.width * strike, height: 4)
                        .position(x: geo.size.width * strike / 2, y: geo.size.height * 0.5)
                        .opacity(strike > 0 ? 1 : 0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .overlay {
                HandCircle(seed: target.id.seed, progress: circle)
                    .stroke(Palette.inkRedPaper, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .opacity(circle > 0 ? 1 : 0)
            }
            .padding(.leading, 3) // 16 + 3 = the mockup's 19 pt text inset, circled or not
    }

    private var accessibilityValue: String {
        var parts: [String] = []
        if target.isPrimary && !target.isStruck { parts.append("Primary") }
        parts.append(target.isStruck ? "Struck" : "Open")
        if let tag { parts.append(tag.isOverdue ? "Overdue, \(tag.text)" : "Due \(tag.text)") }
        return parts.joined(separator: ", ")
    }

    #if os(iOS)
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                swipe = min(0, value.translation.width)
            }
            .onEnded { value in
                if value.translation.width < -200 {
                    onDelete()
                    swipe = 0
                } else {
                    withAnimation(.snappy) { swipe = value.translation.width < -60 ? -96 : 0 }
                }
            }
    }
    #endif
}
