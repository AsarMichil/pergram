import Foundation
import SwiftData
import Testing

@testable import pergram

@MainActor
struct ShoppingTests {
    private let context: ModelContext
    private let chicken: GroceryItem
    private let milkItem: GroceryItem
    private let list: GroceryList
    private let milk: ListEntry
    private let thighs: ListEntry

    init() throws {
        let configuration = ModelConfiguration(
            schema: AppSchema.schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: AppSchema.schema, configurations: [configuration])
        context = ModelContext(container)
        chicken = GroceryItem(
            name: "Chicken thigh", goodPrice: NormalizedPrice(dimension: .mass, canonical: 1.10))
        milkItem = GroceryItem(name: "Milk")
        context.insert(chicken)
        context.insert(milkItem)
        list = GroceryList(name: "Weekly")
        context.insert(list)
        milk = list.add(milkItem)
        thighs = list.add(chicken)
        try context.save()
    }

    private var perHundredGrams: NormalizedPrice {
        NormalizedPrice(dimension: .mass, canonical: 1.0)
    }

    @Test func addingToCartStartsATripWhenNoneIsRunning() {
        #expect(Shopping.activeTrip(in: context) == nil)

        Shopping.addToCart(price: 4.99, unitPrice: nil, item: nil, in: context)

        let trip = Shopping.activeTrip(in: context)
        #expect(trip?.entries?.count == 1)
    }

    @Test func startingATripWhileOneRunsReturnsTheSameTrip() {
        let first = Shopping.startTrip(in: context)
        let second = Shopping.startTrip(shopping: list, in: context)

        #expect(first.id == second.id)
        #expect(second.list?.id == list.id)
    }

    @Test func priceOnlyEntriesAreNumberedAndNeverRenumbered() {
        let one = Shopping.addToCart(price: 1, unitPrice: nil, item: nil, in: context)
        let two = Shopping.addToCart(price: 2, unitPrice: nil, item: nil, in: context)
        Shopping.remove(one, in: context)
        let three = Shopping.addToCart(price: 3, unitPrice: nil, item: nil, in: context)

        #expect(two.label == "Item 2")
        #expect(three.label == "Item 3")
    }

    @Test func entryKeepsTheVerdictItWasAddedWith() {
        let entry = Shopping.addToCart(
            price: 5, unitPrice: perHundredGrams, item: chicken, in: context)
        chicken.setGoodPrice(NormalizedPrice(dimension: .mass, canonical: 0.5))

        #expect(entry.verdict == .good)
    }

    @Test func anItemInTheCartIsCrossedOnTheList() {
        let trip = Shopping.startTrip(shopping: list, in: context)

        Shopping.addToCart(price: 5, unitPrice: perHundredGrams, item: chicken, in: context)

        #expect(trip.isCrossed(thighs))
        #expect(!trip.isCrossed(milk))
    }

    @Test func anItemInTheCartCannotBeUncrossedByHand() {
        let trip = Shopping.startTrip(shopping: list, in: context)
        Shopping.addToCart(price: 5, unitPrice: perHundredGrams, item: chicken, in: context)

        Shopping.setCrossed(false, for: thighs, in: trip)

        #expect(trip.isCrossed(thighs))
    }

    @Test func removingTheCartEntryUncrossesItsListEntry() {
        let trip = Shopping.startTrip(shopping: list, in: context)
        let entry = Shopping.addToCart(
            price: 5, unitPrice: perHundredGrams, item: chicken, in: context)

        Shopping.remove(entry, in: context)

        #expect(!trip.isCrossed(thighs))
    }

    @Test func removingOneOfTwoOfTheSameItemKeepsTheCross() {
        let trip = Shopping.startTrip(shopping: list, in: context)
        let first = Shopping.addToCart(price: 3.49, unitPrice: nil, item: milkItem, in: context)
        Shopping.addToCart(price: 3.49, unitPrice: nil, item: milkItem, in: context)

        Shopping.remove(first, in: context)

        #expect(trip.isCrossed(milk))
    }

    @Test func crossingByHandNeedsNoCartEntry() {
        let trip = Shopping.startTrip(shopping: list, in: context)

        Shopping.setCrossed(true, for: milk, in: trip)

        #expect(trip.isCrossed(milk))
        #expect(trip.entries?.isEmpty == true)
    }

    @Test func buyingASkippedEntryCrossesItAndKeepsTheFlag() {
        thighs.isSkipped = true
        let trip = Shopping.startTrip(shopping: list, in: context)

        Shopping.addToCart(price: 5, unitPrice: perHundredGrams, item: chicken, in: context)

        #expect(trip.isCrossed(thighs))
        #expect(thighs.isSkipped)
    }

    @Test func namingAPriceOnlyEntryTakesTheItemAndItsVerdict() {
        let trip = Shopping.startTrip(shopping: list, in: context)
        let entry = Shopping.addToCart(price: 5, unitPrice: perHundredGrams, item: nil, in: context)

        Shopping.name(entry, as: chicken, in: context)

        #expect(entry.label == "Chicken thigh")
        #expect(entry.verdict == .good)
        #expect(trip.isCrossed(thighs))
    }

    @Test func aNewTripStartsWithNothingCrossed() {
        let first = Shopping.startTrip(shopping: list, in: context)
        Shopping.setCrossed(true, for: milk, in: first)
        Shopping.finish(first, in: context)

        let second = Shopping.startTrip(shopping: list, in: context)

        #expect(first.id != second.id)
        #expect(!second.isCrossed(milk))
    }

    @Test func tallyMultipliesQuantity() {
        let entry = Shopping.addToCart(
            price: 5, unitPrice: perHundredGrams, item: chicken, in: context)
        Shopping.addToCart(price: 2, unitPrice: nil, item: nil, in: context)
        Shopping.setQuantity(3.5, for: entry, in: context)

        let tally = Shopping.activeTrip(in: context)?.tally
        #expect(tally?.total == 19.5)
        #expect(tally?.count == 2)
        #expect(tally?.good == 1)
    }

    @Test func anEntryKeepsItsNameWhenItsItemIsDeleted() throws {
        let entry = Shopping.addToCart(
            price: 5, unitPrice: perHundredGrams, item: chicken, in: context)
        context.delete(chicken)
        try context.save()

        #expect(entry.label == "Chicken thigh")
    }

    @Test func aListHoldsAnItemOnce() {
        milk.isSkipped = true

        let again = list.add(milkItem)

        #expect(again === milk)
        #expect(!milk.isSkipped)
        #expect(list.entries?.count == 2)
    }

    @Test func deletingAnItemTakesItOffItsLists() throws {
        context.delete(milkItem)
        try context.save()

        #expect(list.orderedEntries.map(\.name) == ["Chicken thigh"])
    }

    @Test func aPlannedTripIsNotIdleWhileTheShopperIsStillUsingIt() throws {
        let trip = Shopping.startTrip(shopping: list, in: context)
        let entry = Shopping.addToCart(price: 1, unitPrice: nil, item: nil, in: context)
        let morning = Date.now.addingTimeInterval(-10 * 60 * 60)
        trip.startedAt = morning
        entry.addedAt = morning
        Shopping.setCrossed(true, for: milk, in: trip)
        let crossedAt = trip.lastActivityAt

        Shopping.finishIdleTrip(now: crossedAt.addingTimeInterval(5 * 60 * 60), in: context)

        #expect(Shopping.activeTrip(in: context) != nil)
    }

    @Test func anIdleTripWithAnEmptyCartIsDiscardedNotKept() throws {
        let trip = Shopping.startTrip(shopping: list, in: context)

        Shopping.finishIdleTrip(
            now: trip.lastActivityAt.addingTimeInterval(7 * 60 * 60), in: context)

        #expect(try context.fetch(FetchDescriptor<Trip>()).isEmpty)
    }
}

@MainActor
struct PruneTests {
    private let context: ModelContext

    init() throws {
        let configuration = ModelConfiguration(
            schema: AppSchema.schema, isStoredInMemoryOnly: true)
        context = ModelContext(
            try ModelContainer(for: AppSchema.schema, configurations: [configuration]))
    }

    private var names: [String] {
        ((try? context.fetch(FetchDescriptor<GroceryItem>())) ?? []).map(\.name).sorted()
    }

    @Test func anItemNothingNeedsIsRemoved() throws {
        context.insert(GroceryItem(name: "bannanas"))
        try context.save()

        StoreUpkeep.prune(in: context)

        #expect(names.isEmpty)
    }

    @Test func itemsOnAListPricedOrBoughtAreKept() throws {
        let listed = GroceryItem(name: "Milk")
        let priced = GroceryItem(
            name: "Eggs", goodPrice: NormalizedPrice(dimension: .count, canonical: 0.42))
        let carted = GroceryItem(name: "Bread")
        [listed, priced, carted].forEach(context.insert)
        let list = GroceryList(name: "Weekly")
        context.insert(list)
        list.add(listed)
        Shopping.addToCart(price: 3, unitPrice: nil, item: carted, in: context)

        StoreUpkeep.prune(in: context)

        #expect(names == ["Bread", "Eggs", "Milk"])
    }

    @Test func anOldBookmarkIsNotWorthKeepingAnItemFor() throws {
        let item = GroceryItem(name: "Butter")
        context.insert(item)
        context.insert(
            PriceObservation(
                price: NormalizedPrice(dimension: .mass, canonical: 1.4), reason: .seenOnKeypad,
                item: item))
        try context.save()

        StoreUpkeep.prune(in: context)

        #expect(names.isEmpty)
    }
}
