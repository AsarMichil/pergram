import Foundation
import SwiftData
import Testing

@testable import pergram

@MainActor
struct BookmarkObservationTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([GroceryItem.self, PriceObservation.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    private func makeItem(in context: ModelContext) -> GroceryItem {
        let item = GroceryItem(name: "Chicken thigh", goodPriceCanonical: 1.10)
        context.insert(item)
        return item
    }

    private func observations(in context: ModelContext) throws -> [PriceObservation] {
        try context.fetch(FetchDescriptor<PriceObservation>())
    }

    /// Drives the keypad the way the view does, leaving a valid `$2.00 per 100 g`.
    private func makeViewModel(in context: ModelContext) -> CheckViewModel {
        let viewModel = CheckViewModel()
        viewModel.attach(modelContext: context)
        viewModel.amountUnit = .gram
        viewModel.focus(.price)
        viewModel.inputDigit("2")
        viewModel.focus(.amount)
        for digit in ["1", "0", "0"] { viewModel.inputDigit(digit) }
        return viewModel
    }

    @Test func enteringAPriceWithoutBookmarkingRecordsNothing() throws {
        let context = try makeContext()
        _ = makeItem(in: context)
        let viewModel = makeViewModel(in: context)

        #expect(viewModel.normalizedPrice != nil)
        #expect(try observations(in: context).isEmpty)
    }

    @Test func bookmarkingRecordsTheObservation() throws {
        let context = try makeContext()
        let item = makeItem(in: context)
        let viewModel = makeViewModel(in: context)

        viewModel.bookmarkCurrentPrice(for: item)

        let recorded = try observations(in: context)
        #expect(recorded.count == 1)
        #expect(recorded.first?.priceCanonical == 2.0)
        #expect(recorded.first?.item?.persistentModelID == item.persistentModelID)
    }

    @Test func bookmarkingWithNoItemSelectedStillParksThePrice() throws {
        let context = try makeContext()
        let viewModel = makeViewModel(in: context)

        viewModel.bookmarkCurrentPrice(for: nil)

        #expect(viewModel.lastBookmarked != nil)
        #expect(try observations(in: context).isEmpty)
    }

    @Test func bookmarkingTheSamePriceTwiceRecordsOnce() throws {
        let context = try makeContext()
        let item = makeItem(in: context)
        let viewModel = makeViewModel(in: context)

        viewModel.bookmarkCurrentPrice(for: item)
        viewModel.bookmarkCurrentPrice(for: item)

        #expect(try observations(in: context).count == 1)
    }
}
