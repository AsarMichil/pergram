import Foundation

/// Where an item lives in a store. Raw values are stable identifiers: they are stored on items, list
/// entries and shared lists, so a case is never renamed or removed — only added.
nonisolated enum Aisle: String, CaseIterable, Codable, Sendable {
    case produce
    case meat
    case seafood
    case deli
    case bakery
    case dairy
    case frozen
    case pantry
    case snacks
    case drinks
    case household
    case personalCare = "personal-care"
    case baby
    case pet
    case other

    var title: String {
        switch self {
        case .produce: return "Produce"
        case .meat: return "Meat"
        case .seafood: return "Seafood"
        case .deli: return "Deli"
        case .bakery: return "Bakery"
        case .dairy: return "Dairy & eggs"
        case .frozen: return "Frozen"
        case .pantry: return "Pantry"
        case .snacks: return "Snacks"
        case .drinks: return "Drinks"
        case .household: return "Household"
        case .personalCare: return "Personal care"
        case .baby: return "Baby"
        case .pet: return "Pet"
        case .other: return "Other"
        }
    }
}

/// The order aisles are walked in. A value rather than a fixed list so a store's own layout can
/// replace `standard` without anything that sorts by it changing.
nonisolated struct AisleOrder: Equatable, Sendable {
    let aisles: [Aisle]

    /// A typical Canadian supermarket from the entrance: fresh around the edge, then the centre.
    static let standard = AisleOrder(aisles: [
        .produce, .bakery, .deli, .meat, .seafood, .dairy, .frozen, .pantry, .snacks, .drinks,
        .household, .personalCare, .baby, .pet, .other,
    ])

    /// An aisle the order does not mention sorts last rather than disappearing.
    func rank(of aisle: Aisle) -> Int {
        aisles.firstIndex(of: aisle) ?? aisles.count
    }

    func sorted<T>(_ elements: [T], by aisle: (T) -> Aisle) -> [(aisle: Aisle, elements: [T])] {
        Dictionary(grouping: elements, by: aisle)
            .map { (aisle: $0.key, elements: $0.value) }
            .sorted { rank(of: $0.aisle) < rank(of: $1.aisle) }
    }
}
