import Foundation
import OSLog

/// Diagnostics grouped by **flow** rather than by type, so a device session can be narrowed to one
/// path at a time:
///
/// ```
/// log stream --device --predicate 'subsystem == "com.asarmichil.pergram" AND category == "vision"'
/// ```
///
/// Two levels are in use, deliberately:
/// - `.info` — milestones. Low volume, reconstructs what happened without drowning the console.
/// - `.debug` — per-frame detail. The system neither persists it nor shows it unless asked, so it
///   can be as chatty as it likes.
///
/// Values are interpolated `.public` on purpose: `Logger` redacts interpolations by default, which
/// turns every diagnostic into `<private>` the moment Xcode is not attached — exactly when the log
/// matters. Nothing here is user data; shelf-tag text is the most personal thing logged, and only
/// at `.debug`.
nonisolated enum Log {
    /// Scan mode's lifecycle: permission, status, what filled the fields.
    static let scan = Logger(category: "scan")
    /// Capture session: configuration, start/stop, runtime errors and interruptions.
    static let camera = Logger(category: "camera")
    /// Text recognition: per-frame timing, what was read, what it parsed to.
    static let vision = Logger(category: "vision")
    /// The Check pipeline receiving input.
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
