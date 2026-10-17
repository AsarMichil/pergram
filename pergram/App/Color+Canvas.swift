import SwiftUI

extension Color {
    /// The base-level system background. Sheets otherwise resolve to the elevated level, grey in
    /// dark mode, which washes out the calculator's quaternary fills and glass keys — both tuned
    /// against the Check screen's black.
    static let canvas = Color(
        uiColor: UIColor { traits in
            UIColor.systemBackground.resolvedColor(
                with: traits.modifyingTraits { $0.userInterfaceLevel = .base })
        })
}
