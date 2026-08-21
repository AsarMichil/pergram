import Foundation
import OSLog

/// Diagnostics grouped by **flow** rather than by type, so a device session can be narrowed to one
/// path at a time. `.info` carries milestones and `.debug` per-frame detail, which the system
/// neither persists nor shows unless asked.
///
/// Values are interpolated `.public` on purpose: `Logger` redacts interpolations by default, which
/// turns every diagnostic into `<private>` the moment Xcode is not attached — exactly when the log
/// matters. Nothing here is user data.
nonisolated enum Log {
    static let scan = Logger(category: "scan")
    static let camera = Logger(category: "camera")
    static let vision = Logger(category: "vision")
    static let check = Logger(category: "check")
}

extension Logger {
    fileprivate nonisolated init(category: String) {
        self.init(
            subsystem: Bundle.main.bundleIdentifier ?? "com.asarmichil.pergram",
            category: category
        )
    }
}

nonisolated extension Duration {
    /// `Duration` has no lossy accessor, and log lines want one number.
    var milliseconds: Double {
        Double(components.seconds) * 1000 + Double(components.attoseconds) / 1e15
    }
}
