import Foundation
import SwiftData
import Testing

@testable import pergram

@MainActor
struct AddToCartTests {
    private let context: ModelContext
    private let viewModel = CheckViewModel()

    init() throws {
        let configuration = ModelConfiguration(
            schema: AppSchema.schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: AppSchema.schema, configurations: [configuration])
        context = ModelContext(container)
        viewModel.attach(modelContext: context)
        viewModel.amountUnit = .gram
    }

    private func type(price: String, amount: String? = nil) {
        viewModel.focus(.price)
        price.forEach { viewModel.inputDigit(String($0)) }
        guard let amount else { return }
        viewModel.focus(.amount)
        amount.forEach { viewModel.inputDigit(String($0)) }
    }

    private var cart: [CartEntry] { Shopping.activeTrip(in: context)?.orderedEntries ?? [] }

    @Test func aPriceAloneCanGoInTheCart() {
        type(price: "4")

        #expect(viewModel.canAddToCart)
        #expect(!viewModel.hasEnoughInput)

        viewModel.addToCart(item: nil, listEntry: nil)

        #expect(cart.map(\.price) == [4])
        #expect(cart.first?.unitPrice == nil)
        #expect(cart.first?.label(listEntry: nil) == "Item 1")
    }

    @Test func nothingTypedAddsNothing() {
        viewModel.addToCart(item: nil, listEntry: nil)

        #expect(Shopping.activeTrip(in: context) == nil)
    }

    @Test func theNextDigitStartsANewPrice() {
        type(price: "4", amount: "100")
        viewModel.addToCart(item: nil, listEntry: nil)

        viewModel.inputDigit("7")

        #expect(viewModel.priceText == "7")
        #expect(viewModel.amountText == "100")
    }

    @Test func addingRecordsTheObservationForTheItem() throws {
        let item = GroceryItem(
            name: "Chicken thigh", goodPrice: NormalizedPrice(dimension: .mass, canonical: 1.10))
        context.insert(item)
        type(price: "2", amount: "100")

        viewModel.addToCart(item: item, listEntry: nil)

        #expect(try context.fetch(FetchDescriptor<PriceObservation>()).count == 1)
        #expect(cart.first?.verdict == .bad)
    }

    @Test func theChosenListEntryIsUsedOnce() {
        let list = GroceryList(name: "Weekly")
        context.insert(list)
        let milk = list.append("Milk")
        Shopping.startTrip(shopping: list, in: context)
        viewModel.selectedListEntryID = milk.id
        type(price: "3")

        viewModel.addToCart(item: nil, listEntry: milk)

        #expect(viewModel.selectedListEntryID == nil)
        #expect(cart.first?.listEntryID == milk.id)
    }
}
