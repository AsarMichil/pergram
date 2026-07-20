import Foundation

nonisolated enum MeasureUnit: String, CaseIterable, Codable, Sendable {
    case gram
    case kilogram
    case pound
    case ounce
    case per100Grams
    case each
}
