import Foundation
import SwiftData

/// A fresh install has no good prices: setting them is the shopper's own work. App Store screenshots
/// need verdicts to show, so a debug build launched with `-demoGoodPrices` gets a few. Release
/// builds ignore the flag.
@MainActor
enum DemoGoodPrices {
    static let prices: [(id: String, price: NormalizedPrice)] = [
        ("bananas", NormalizedPrice(dimension: .mass, canonical: 0.18)),
        ("ground-beef-lean", NormalizedPrice(dimension: .mass, canonical: 1.30)),
        ("cheddar", NormalizedPrice(dimension: .mass, canonical: 2.20)),
    ]

    static func insertIfRequested(in context: ModelContext) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-demoGoodPrices") else { return }
        for (id, price) in prices {
            guard let entry = CatalogLibrary.bundled.entry(id: id) else { continue }
            let item = CatalogLibrary.item(for: entry, in: context)
            if item.goodPrice(for: price.dimension) == nil { item.setGoodPrice(price) }
        }
        try? context.save()
        #endif
    }
}
