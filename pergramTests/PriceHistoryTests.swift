import Foundation
import SwiftData
import Testing

@testable import pergram

/// Price history keeps only prices the shopper acted on; checks count every price looked at, once.
@MainActor
struct PriceHistoryTests {
    private let context: ModelContext
    private let chicken: GroceryItem

    init() throws {
        let configuration = ModelConfiguration(
            schema: AppSchema.schema, isStoredInMemoryOnly: true)
        context = ModelContext(
            try ModelContainer(for: AppSchema.schema, configurations: [configuration]))
        chicken = GroceryItem(
            name: "Chicken thigh", goodPrice: NormalizedPrice(dimension: .mass, canonical: 1.10))
        context.insert(chicken)
        try context.save()
    }

    private var observations: [PriceObservation] {
        (try? context.fetch(FetchDescriptor<PriceObservation>())) ?? []
    }

    private var checks: [PriceCheck] {
        (try? context.fetch(FetchDescriptor<PriceCheck>())) ?? []
    }

    /// Drives the keypad the way the view does, leaving `$<price> per 100 g`.
    private func makeViewModel(
        price: String = "2", selecting item: GroceryItem? = nil
    )
        -> CheckViewModel
    {
        let viewModel = CheckViewModel()
        viewModel.attach(modelContext: context)
        viewModel.amountUnit = .gram
        viewModel.selectedItemID = item?.persistentModelID
        type(price, into: viewModel)
        viewModel.focus(.amount)
        for digit in ["1", "0", "0"] { viewModel.inputDigit(digit) }
        return viewModel
    }

    private func type(_ price: String, into viewModel: CheckViewModel) {
        viewModel.focus(.price)
        price.forEach { viewModel.inputDigit(String($0)) }
    }

    @Test func aBookmarkIsNotPriceHistory() {
        let viewModel = makeViewModel(selecting: chicken)

        viewModel.bookmarkCurrentPrice(for: chicken)

        #expect(viewModel.lastBookmarked != nil)
        #expect(observations.isEmpty)
    }

    @Test func addingToTheCartIsNotHistoryUntilTheTripIsFinished() {
        let viewModel = makeViewModel(selecting: chicken)

        viewModel.addToCart(item: chicken, listEntry: nil)

        #expect(observations.isEmpty)
    }

    @Test func settingAGoodPriceIsHistory() {
        let viewModel = makeViewModel(price: "1")

        viewModel.updateGoodPrice(for: chicken)

        #expect(observations.map(\.reason) == [.goodPrice])
        #expect(observations.first?.priceCanonical == 1)
    }

    @Test func savingANewItemsGoodPriceIsHistory() {
        let viewModel = makeViewModel()

        viewModel.saveAsGoodPrice(named: "Oat milk")

        #expect(observations.map(\.reason) == [.goodPrice])
        #expect(observations.first?.item?.name == "Oat milk")
    }

    @Test func typingOnePriceIsOneCheckOnceTheShopperMovesOn() {
        let viewModel = makeViewModel(selecting: chicken)
        #expect(checks.isEmpty)

        viewModel.focus(.price)
        viewModel.inputDigit("3")

        #expect(checks.count == 1)
        #expect(checks.first?.priceCanonical == 2)
        #expect(checks.first?.verdict == .bad)
        #expect(checks.first?.itemName == "Chicken thigh")
    }

    @Test func theSamePriceTwiceIsOneCheck() {
        let viewModel = makeViewModel()

        viewModel.bookmarkCurrentPrice(for: nil)
        viewModel.addToCart(item: nil, listEntry: nil)

        #expect(checks.count == 1)
    }

    @Test func aScanThatReplacesAPriceChecksTheOneItReplaced() {
        let viewModel = makeViewModel()

        viewModel.applyScannedEntry(ScanCandidate(price: 5, amount: 100, unit: .gram))
        viewModel.commitCheck()

        #expect(checks.map(\.priceCanonical) == [2, 5])
        #expect(checks.last?.sourceRawValue == CheckSource.scan.rawValue)
    }

    @Test func theGoodPriceSheetDoesNotCountAsChecking() {
        let viewModel = makeViewModel()
        viewModel.recordsChecks = false

        viewModel.commitCheck()

        #expect(checks.isEmpty)
    }

    @Test func finishingATripRecordsWhatWasBought() throws {
        Shopping.addToCart(price: 3, unitPrice: nil, item: nil, in: context)
        let bought = Shopping.addToCart(
            price: 5, unitPrice: NormalizedPrice(dimension: .mass, canonical: 1.0), item: chicken,
            in: context)
        let trip = try #require(Shopping.activeTrip(in: context))

        Shopping.finish(trip, in: context)

        #expect(observations.count == 1)
        #expect(observations.first?.reason == .bought)
        #expect(observations.first?.verdict == .good)
        #expect(observations.first?.tripID == trip.id)
        #expect(observations.first?.date == bought.addedAt)
    }

    @Test func aPriceMatchedToAnItemBeforeFinishingIsRecorded() throws {
        let list = GroceryList(name: "Weekly")
        context.insert(list)
        let thighs = list.append("Thighs", item: chicken)
        let trip = Shopping.startTrip(shopping: list, in: context)
        let entry = Shopping.addToCart(
            price: 5, unitPrice: NormalizedPrice(dimension: .mass, canonical: 1.0), item: nil,
            in: context)
        Shopping.match(entry, to: thighs, in: context)

        Shopping.finish(trip, in: context)

        #expect(observations.map { $0.item?.name } == ["Chicken thigh"])
    }

    @Test func finishingTwiceRecordsOnce() throws {
        Shopping.addToCart(
            price: 5, unitPrice: NormalizedPrice(dimension: .mass, canonical: 1.0), item: chicken,
            in: context)
        let trip = try #require(Shopping.activeTrip(in: context))

        Shopping.finish(trip, in: context)
        Shopping.finish(trip, in: context)

        #expect(observations.count == 1)
    }

    @Test func aTripIdleForSixHoursIsFinishedAndItsPricesKept() throws {
        let entry = Shopping.addToCart(
            price: 5, unitPrice: NormalizedPrice(dimension: .mass, canonical: 1.0), item: chicken,
            in: context)

        Shopping.finishIdleTrip(now: entry.addedAt.addingTimeInterval(5 * 60 * 60), in: context)
        #expect(Shopping.activeTrip(in: context) != nil)

        Shopping.finishIdleTrip(now: entry.addedAt.addingTimeInterval(6 * 60 * 60), in: context)
        #expect(Shopping.activeTrip(in: context) == nil)
        #expect(observations.map(\.reason) == [.bought])
    }
}
