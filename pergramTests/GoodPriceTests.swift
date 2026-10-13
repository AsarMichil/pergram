import Foundation
import SwiftData
import Testing

@testable import pergram

@MainActor
struct GoodPriceTests {
    private let perEach = NormalizedPrice(dimension: .count, canonical: 1.25)
    private let perHundredGrams = NormalizedPrice(dimension: .mass, canonical: 0.97)

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(
            schema: AppSchema.schema, isStoredInMemoryOnly: true)
        return ModelContext(
            try ModelContainer(for: AppSchema.schema, configurations: [configuration]))
    }

    @Test func eachAndWeightPricesLiveSideBySide() {
        let avocado = GroceryItem(name: "Avocado", goodPrice: perEach)

        avocado.setGoodPrice(perHundredGrams)

        #expect(avocado.goodPrices == [perHundredGrams, perEach])
    }

    @Test func theVerdictUsesTheGoodPriceInTheTypedDimension() {
        let avocado = GroceryItem(name: "Avocado", goodPrice: perEach)
        avocado.setGoodPrice(perHundredGrams)

        #expect(avocado.verdict(for: NormalizedPrice(dimension: .count, canonical: 1.20)) == .good)
        #expect(avocado.verdict(for: NormalizedPrice(dimension: .mass, canonical: 2.00)) == .bad)
    }

    @Test func noGoodPriceInADimensionMeansNoVerdict() {
        let avocado = GroceryItem(name: "Avocado", goodPrice: perEach)

        #expect(avocado.verdict(for: perHundredGrams) == nil)
    }

    @Test func clearingOneDimensionKeepsTheOthers() {
        let avocado = GroceryItem(name: "Avocado", goodPrice: perEach)
        avocado.setGoodPrice(perHundredGrams)

        avocado.clearGoodPrice(for: .count)

        #expect(avocado.goodPrices == [perHundredGrams])
    }

    @Test func aZeroPriceIsNoPrice() {
        let item = GroceryItem(name: "Rice")

        item.setGoodPrice(NormalizedPrice(dimension: .mass, canonical: 0))

        #expect(!item.hasGoodPrice)
    }

    @Test func aLegacyPriceMovesIntoItsDimension() throws {
        let context = try makeContext()
        let eggs = GroceryItem(name: "Eggs", userModified: true)
        eggs.goodPriceCanonical = 0.42
        eggs.dimensionRaw = PriceDimension.count.rawValue
        context.insert(eggs)

        LegacyGoodPriceMigration.run(in: context)

        #expect(eggs.goodPrices == [NormalizedPrice(dimension: .count, canonical: 0.42)])
        #expect(eggs.goodPriceCanonical == 0)
    }

    @Test func migrationNeverOverwritesANewerPrice() throws {
        let context = try makeContext()
        let eggs = GroceryItem(name: "Eggs", goodPrice: perEach, userModified: true)
        eggs.goodPriceCanonical = 0.42
        eggs.dimensionRaw = PriceDimension.count.rawValue
        context.insert(eggs)

        LegacyGoodPriceMigration.run(in: context)
        LegacyGoodPriceMigration.run(in: context)

        #expect(eggs.goodPrices == [perEach])
    }

    /// A price the old bundled seed set, untouched since, is not the shopper's: an upgrade starts
    /// where a fresh install does.
    @Test func anUntouchedSeedPriceIsDroppedWithItsItem() throws {
        let context = try makeContext()
        let bananas = GroceryItem(seedID: "bananas", name: "Bananas")
        bananas.goodPriceCanonical = 0.18
        context.insert(bananas)

        LegacyGoodPriceMigration.run(in: context)
        StoreUpkeep.prune(in: context)

        #expect(try context.fetch(FetchDescriptor<GroceryItem>()).isEmpty)
    }

    @Test func anUntouchedSeedItemOnAListStaysWithoutItsPrice() throws {
        let context = try makeContext()
        let bananas = GroceryItem(seedID: "bananas", name: "Bananas")
        bananas.goodPriceCanonical = 0.18
        context.insert(bananas)
        let list = GroceryList(name: "Weekly")
        context.insert(list)
        list.add(bananas)

        LegacyGoodPriceMigration.run(in: context)

        #expect(!bananas.hasGoodPrice)
        #expect(bananas.goodPriceCanonical == 0)
        #expect(list.orderedEntries.first?.item?.persistentModelID == bananas.persistentModelID)
    }

    @Test func observationsRememberTheirDimension() throws {
        let context = try makeContext()
        let avocado = GroceryItem(name: "Avocado", goodPrice: perEach)
        context.insert(avocado)
        let viewModel = CheckViewModel()
        viewModel.attach(modelContext: context)
        viewModel.amountUnit = .each
        viewModel.focus(.price)
        viewModel.inputDigit("2")
        viewModel.focus(.amount)
        viewModel.inputDigit("1")

        viewModel.updateGoodPrice(for: avocado)

        let recorded = try context.fetch(FetchDescriptor<PriceObservation>())
        #expect(recorded.map(\.dimensionRaw) == [PriceDimension.count.rawValue])
    }
}

struct AisleOrderTests {
    @Test func groupsFollowTheOrderNotTheInput() {
        let grouped = AisleOrder.standard.sorted(["milk", "apples", "soap"]) { name in
            switch name {
            case "milk": return Aisle.dairy
            case "apples": return .produce
            default: return .household
            }
        }

        #expect(grouped.map(\.aisle) == [.produce, .dairy, .household])
    }

    @Test func anAisleTheOrderLeavesOutSortsLast() {
        let order = AisleOrder(aisles: [.dairy])

        #expect(order.rank(of: .produce) > order.rank(of: .dairy))
    }

    @Test func theStandardOrderCoversEveryAisle() {
        #expect(Set(AisleOrder.standard.aisles) == Set(Aisle.allCases))
        #expect(AisleOrder.standard.aisles.count == Aisle.allCases.count)
    }
}
