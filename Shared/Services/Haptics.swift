import Foundation
#if os(iOS)
import UIKit
#endif

/// All haptics in one place. No-ops on Mac.
enum Haptics {
    /// Firing an arrow.
    static func fire() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        #endif
    }

    /// Strike, bullseye, rung unlocked, session complete.
    static func success() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    /// Undo.
    static func light() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}
