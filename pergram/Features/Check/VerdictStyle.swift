import SwiftUI

extension Verdict {
    var word: String {
        switch self {
        case .good: return "GOOD"
        case .meh: return "MEH"
        case .bad: return "BAD"
        }
    }

    var color: Color {
        switch self {
        case .good: return Color("VerdictGood")
        case .meh: return Color("VerdictMeh")
        case .bad: return Color("VerdictBad")
        }
    }

    var symbolName: String {
        switch self {
        case .good: return "checkmark.circle.fill"
        case .meh: return "equal.circle.fill"
        case .bad: return "xmark.circle.fill"
        }
    }
}
