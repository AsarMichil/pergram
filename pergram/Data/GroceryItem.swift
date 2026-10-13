import Foundation
import SwiftData

/// Every property is defaulted and no attribute is `.unique`, so the model can be mirrored to
/// CloudKit later by flipping a checkbox rather than performing a migration.
@Model
final class GroceryItem {
    /// The `catalog.json` entry's stable slug; empty for an item the user made up. Item identity
    /// for SwiftUI (`ForEach`, `sheet(item:)`) is SwiftData's `persistentModelID`, not this —
    /// empty slugs must never collide items. Renamed from `id`.
    @Attribute(originalName: "id")
    var seedID: String = ""
    var name: String = ""
    var aliases: [String] = []
    /// An `Aisle` raw value. Kept under its original name so stores from before aisles carry over.
    var category: String = ""

    /// One good price per way of buying, each in its dimension's canonical unit: an avocado can be
    /// good at `$1.25/each` and at `$4.40/lb`. `nil` means no good price yet.
    var goodPricePerMass: Double?
    var goodPricePerVolume: Double?
    var goodPricePerEach: Double?

    /// Legacy single good price, read once by `LegacyGoodPriceMigration` and zeroed. Kept as a
    /// column so an upgrade has something to migrate from.
    @Attribute(originalName: "goodPricePer100g")
    var goodPriceCanonical: Double = 0
    var dimensionRaw: String = PriceDimension.mass.rawValue

    var userModified: Bool = false
    var updatedAt: Date = Date.distantPast

    @Relationship(deleteRule: .cascade, inverse: \PriceObservation.item)
    var observations: [PriceObservation]? = []

    /// Deleting an item takes it off every list: an entry is nothing without its item.
    @Relationship(deleteRule: .cascade, inverse: \ListEntry.item)
    var listEntries: [ListEntry]? = []

    @Relationship(deleteRule: .nullify, inverse: \CartEntry.item)
    var cartEntries: [CartEntry]? = []

    init(
        seedID: String = "",
        name: String = "",
        aliases: [String] = [],
        aisle: Aisle? = nil,
        goodPrice: NormalizedPrice? = nil,
        userModified: Bool = false,
        updatedAt: Date = .now
    ) {
        self.seedID = seedID
        self.name = name
        self.aliases = aliases
        self.category = aisle?.rawValue ?? ""
        self.userModified = userModified
        self.updatedAt = updatedAt
        if let goodPrice { setGoodPrice(goodPrice) }
    }

    var aisle: Aisle? {
        get { Aisle(rawValue: category) }
        set { category = newValue?.rawValue ?? "" }
    }

    func goodPrice(for dimension: PriceDimension) -> NormalizedPrice? {
        storedGoodPrice(for: dimension).map { NormalizedPrice(dimension: dimension, canonical: $0) }
    }

    /// In `PriceDimension` order, so a list of them reads the same everywhere.
    var goodPrices: [NormalizedPrice] {
        PriceDimension.allCases.compactMap(goodPrice(for:))
    }

    var hasGoodPrice: Bool { !goodPrices.isEmpty }

    /// Replaces the good price for `price`'s dimension, leaving the others alone.
    func setGoodPrice(_ price: NormalizedPrice) {
        setStoredGoodPrice(price.canonical > 0 ? price.canonical : nil, for: price.dimension)
    }

    func clearGoodPrice(for dimension: PriceDimension) {
        setStoredGoodPrice(nil, for: dimension)
    }

    /// On no list, no good price, never in a cart, nothing bought or set: a typo or a passing search
    /// that left nothing worth keeping. Bookmark-era observations do not count as history.
    var isUnused: Bool {
        (listEntries ?? []).isEmpty && !hasGoodPrice && (cartEntries ?? []).isEmpty
            && !(observations ?? []).contains { $0.reason == .bought || $0.reason == .goodPrice }
    }

    /// `nil` when there is no good price in the price's dimension yet.
    func verdict(for price: NormalizedPrice) -> Verdict? {
        guard let baseline = storedGoodPrice(for: price.dimension) else { return nil }
        return VerdictEngine.verdict(price: price.canonical, baseline: baseline)
    }

    private func storedGoodPrice(for dimension: PriceDimension) -> Double? {
        switch dimension {
        case .mass: return goodPricePerMass
        case .volume: return goodPricePerVolume
        case .count: return goodPricePerEach
        }
    }

    private func setStoredGoodPrice(_ value: Double?, for dimension: PriceDimension) {
        switch dimension {
        case .mass: goodPricePerMass = value
        case .volume: goodPricePerVolume = value
        case .count: goodPricePerEach = value
        }
    }
}
