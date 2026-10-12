import Foundation
import SwiftData
import Testing

@testable import pergram

@MainActor
struct ShoppingTests {
    private let context: ModelContext
    private let chicken: GroceryItem
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
        context.insert(chicken)
        list = GroceryList(name: "Weekly")
        context.insert(list)
        milk = list.append("Milk")
        thighs = list.append("Thighs", item: chicken)
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

        #expect(two.label(listEntry: nil) == "Item 2")
        #expect(three.label(listEntry: nil) == "Item 3")
    }

    @Test func entryKeepsTheVerdictItWasAddedWith() {
        let entry = Shopping.addToCart(
            price: 5, unitPrice: perHundredGrams, item: chicken, in: context)
        chicken.setGoodPrice(NormalizedPrice(dimension: .mass, canonical: 0.5))

        #expect(entry.verdict == .good)
    }

    @Test func addingALinkedItemCrossesItsListEntry() {
        let trip = Shopping.startTrip(shopping: list, in: context)

        Shopping.addToCart(price: 5, unitPrice: perHundredGrams, item: chicken, in: context)

        #expect(trip.isCrossed(thighs))
        #expect(!trip.isCrossed(milk))
    }

    @Test func choosingAListEntryCrossesItEvenWithoutAnItem() {
        let trip = Shopping.startTrip(shopping: list, in: context)

        let entry = Shopping.addToCart(
            price: 3.49, unitPrice: nil, item: nil, listEntry: milk, in: context)

        #expect(trip.isCrossed(milk))
        #expect(entry.label(listEntry: milk) == "Milk")
    }

    @Test func uncrossingKeepsTheCartEntry() {
        let trip = Shopping.startTrip(shopping: list, in: context)
        Shopping.addToCart(price: 5, unitPrice: perHundredGrams, item: chicken, in: context)

        Shopping.setCrossed(false, for: thighs, in: trip)

        #expect(!trip.isCrossed(thighs))
        #expect(trip.entries?.count == 1)
    }

    @Test func removingTheCartEntryUncrossesItsListEntry() {
        let trip = Shopping.startTrip(shopping: list, in: context)
        let entry = Shopping.addToCart(
            price: 5, unitPrice: perHundredGrams, item: chicken, in: context)

        Shopping.remove(entry, in: context)

        #expect(!trip.isCrossed(thighs))
    }

    @Test func removingOneOfTwoClaimingEntriesKeepsTheCross() {
        let trip = Shopping.startTrip(shopping: list, in: context)
        let first = Shopping.addToCart(
            price: 3.49, unitPrice: nil, item: nil, listEntry: milk, in: context)
        Shopping.addToCart(price: 3.49, unitPrice: nil, item: nil, listEntry: milk, in: context)

        Shopping.remove(first, in: context)

        #expect(trip.isCrossed(milk))
    }

    @Test func aSecondOfTheSameItemCrossesNothingNew() {
        let trip = Shopping.startTrip(shopping: list, in: context)
        Shopping.addToCart(price: 5, unitPrice: perHundredGrams, item: chicken, in: context)
        let second = Shopping.addToCart(
            price: 5, unitPrice: perHundredGrams, item: chicken, in: context)

        #expect(second.listEntryID == nil)
        #expect(trip.crossedEntryIDs == [thighs.id])
    }

    @Test func buyingASkippedEntryCrossesItAndKeepsTheFlag() {
        thighs.isSkipped = true
        let trip = Shopping.startTrip(shopping: list, in: context)

        Shopping.addToCart(price: 5, unitPrice: perHundredGrams, item: chicken, in: context)

        #expect(trip.isCrossed(thighs))
        #expect(thighs.isSkipped)
    }

    @Test func matchingAnUnnamedEntryAdoptsTheListItemAndItsVerdict() {
        let trip = Shopping.startTrip(shopping: list, in: context)
        let entry = Shopping.addToCart(price: 5, unitPrice: perHundredGrams, item: nil, in: context)

        Shopping.match(entry, to: thighs, in: context)

        #expect(entry.item?.persistentModelID == chicken.persistentModelID)
        #expect(entry.verdict == .good)
        #expect(trip.isCrossed(thighs))
    }

    @Test func rematchingReleasesTheFirstEntry() {
        let trip = Shopping.startTrip(shopping: list, in: context)
        let entry = Shopping.addToCart(
            price: 3.49, unitPrice: nil, item: nil, listEntry: milk, in: context)

        Shopping.match(entry, to: thighs, in: context)

        #expect(!trip.isCrossed(milk))
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

    @Test func anEntryKeepsItsNameWhenTheListItCameFromIsSwitched() {
        Shopping.startTrip(shopping: list, in: context)
        let entry = Shopping.addToCart(
            price: 3.49, unitPrice: nil, item: nil, listEntry: milk, in: context)
        let other = GroceryList(name: "Other")
        context.insert(other)

        let trip = Shopping.startTrip(shopping: other, in: context)

        #expect(trip.label(for: entry) == "Milk")
    }

    @Test func anEntryKeepsItsNameWhenItsItemIsDeleted() throws {
        let entry = Shopping.addToCart(
            price: 5, unitPrice: perHundredGrams, item: chicken, in: context)
        context.delete(chicken)
        try context.save()

        #expect(entry.label(listEntry: nil) == "Chicken thigh")
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
