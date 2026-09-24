import CoreText
import SwiftUI
import os

/// Registers the bundled OFL fonts and hands out `Font`s, falling back to system fonts
/// when a face failed to register.
enum FoundryFont {
    enum Face: String, CaseIterable {
        case condensedSemiBold = "BarlowCondensed-SemiBold"
        case condensedBold = "BarlowCondensed-Bold"
        case bodyRegular = "Barlow-Regular"
        case bodyMedium = "Barlow-Medium"
        case bodySemiBold = "Barlow-SemiBold"
        case monoRegular = "IBMPlexMono-Regular"
        case monoMedium = "IBMPlexMono-Medium"
        case script = "Caveat-Bold"
    }

    nonisolated(unsafe) private static var available: Set<String> = []
    nonisolated(unsafe) private static var didRegister = false

    /// Registers every bundled `.ttf` with CoreText (process scope) and logs the PostScript names found.
    static func registerAll() {
        guard !didRegister else { return }
        didRegister = true
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in urls {
            var error: Unmanaged<CFError>?
            let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] ?? []
            for descriptor in descriptors {
                if let name = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String {
                    // Already-registered faces report an error but are still usable.
                    available.insert(name)
                    Log.app.debug("Font \(name, privacy: .public) registered: \(ok)")
                }
            }
            if !ok, let err = error?.takeRetainedValue() {
                Log.app.debug("Font registration note for \(url.lastPathComponent, privacy: .public): \(err.localizedDescription, privacy: .public)")
            }
        }
        let missing = Face.allCases.map(\.rawValue).filter { !available.contains($0) }
        if !missing.isEmpty {
            Log.app.error("Fonts missing, using system fallback: \(missing.joined(separator: ", "), privacy: .public)")
        }
    }

    static func isAvailable(_ face: Face) -> Bool { available.contains(face.rawValue) }

    static func font(_ face: Face, size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        if isAvailable(face) {
            return .custom(face.rawValue, size: size, relativeTo: style)
        }
        return fallback(face, size: size)
    }

    /// A fixed-size font for text drawn inside graphics (the caller scales `size` with `@ScaledMetric`).
    static func fixed(_ face: Face, size: CGFloat) -> Font {
        isAvailable(face) ? .custom(face.rawValue, fixedSize: size) : fallback(face, size: size)
    }

    private static func fallback(_ face: Face, size: CGFloat) -> Font {
        switch face {
        case .condensedSemiBold: .system(size: size, weight: .semibold).width(.condensed)
        case .condensedBold: .system(size: size, weight: .bold).width(.condensed)
        case .bodyRegular: .system(size: size, weight: .regular)
        case .bodyMedium: .system(size: size, weight: .medium)
        case .bodySemiBold: .system(size: size, weight: .semibold)
        case .monoRegular: .system(size: size, weight: .regular, design: .monospaced)
        case .monoMedium: .system(size: size, weight: .medium, design: .monospaced)
        case .script: .system(size: size, weight: .bold, design: .serif).italic()
        }
    }
}

// MARK: - Text styles

extension View {
    /// Barlow Condensed display type, uppercase with wide tracking.
    func condensed(_ size: CGFloat, weight: Font.Weight = .bold, tracking: CGFloat = 0.06,
                   relativeTo style: Font.TextStyle = .title) -> some View {
        let face: FoundryFont.Face = weight == .semibold ? .condensedSemiBold : .condensedBold
        return self.font(FoundryFont.font(face, size: size, relativeTo: style))
            .tracking(size * tracking)
    }

    /// Barlow body type.
    func body(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> some View {
        let face: FoundryFont.Face = switch weight {
        case .semibold, .bold: .bodySemiBold
        case .medium: .bodyMedium
        default: .bodyRegular
        }
        return self.font(FoundryFont.font(face, size: size, relativeTo: style))
    }

    /// IBM Plex Mono small label, uppercase.
    func mono(_ size: CGFloat = 11, tracking: CGFloat = 0.08, weight: Font.Weight = .regular,
              relativeTo style: Font.TextStyle = .caption) -> some View {
        let face: FoundryFont.Face = weight == .medium ? .monoMedium : .monoRegular
        return self.font(FoundryFont.font(face, size: size, relativeTo: style))
            .tracking(size * tracking)
            .textCase(.uppercase)
    }

    /// Caveat handwriting.
    func script(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> some View {
        self.font(FoundryFont.font(.script, size: size, relativeTo: style))
    }
}
