import Foundation
import SwiftData
import Testing

@testable import pergram

/// Guards the shipped dictionary. Ids are stored on items and in shared lists, so these are the
/// checks that stop an edit to `catalog.json` from quietly orphaning them.
@MainActor
struct CatalogFileTests {
    private let catalog = CatalogLibrary.bundled

    @Test func theDictionaryShipsAndCoversMostOfAShop() {
        #expect(catalog.entries.count > 500)
        #expect(Set(catalog.entries.map(\.aisle)).count >= 12)
    }

    @Test func idsAreUniqueSlugs() {
        let ids = catalog.entries.map(\.id)
        #expect(Set(ids).count == ids.count)
        let slug = /^[a-z0-9]+(-[a-z0-9]+)*$/
        #expect(ids.filter { $0.wholeMatch(of: slug) == nil }.isEmpty)
    }

    /// A term two entries share would make exact linking pick one arbitrarily.
    @Test func noTermBelongsToTwoEntries() {
        var owner: [String: String] = [:]
        var clashes: [String] = []
        for entry in catalog.entries {
            for term in Set(entry.terms.map(SearchText.normalize)) {
                if let other = owner[term], other != entry.id {
                    clashes.append("\(term): \(other) / \(entry.id)")
                }
                owner[term] = entry.id
            }
        }
        #expect(clashes.isEmpty, "\(clashes)")
    }

    @Test func everyEntryIsSoldSomeWay() {
        #expect(catalog.entries.filter { $0.soldBy.isEmpty || $0.name.isEmpty }.isEmpty)
    }

    @Test(arguments: [
        ("organic bananas", Aisle.produce),
        ("paper towel", .household),
        ("dish soap", .household),
        ("almond milk", .dairy),
        ("chicken breasts", .meat),
        ("frozen peas", .frozen),
        ("sourdough", .bakery),
        ("pommes de terre", .produce),
        ("lait 2 %", .dairy),
        ("kitty litter", .pet),
    ])
    func everydayListTextLandsInTheRightAisle(text: String, aisle: Aisle) {
        #expect(catalog.guessAisle(for: text) == aisle)
    }

    @Test func everyDemoGoodPriceHasADictionaryEntry() {
        #expect(DemoGoodPrices.prices.filter { catalog.entry(id: $0.id) == nil }.isEmpty)
    }
}

struct CatalogSearchTests {
    private let catalog = Catalog(
        version: 1,
        entries: [
            .init(
                id: "bananas", name: "Bananas", aliases: ["banana", "bananes"], aisle: .produce,
                soldBy: [.mass, .count]),
            .init(
                id: "sour-cream", name: "Sour cream", aliases: ["crème sure"], aisle: .dairy,
                soldBy: [.volume]),
            .init(
                id: "tomatoes", name: "Tomatoes", aliases: ["tomato"], aisle: .produce,
                soldBy: [.mass]),
            .init(
                id: "tomato-paste", name: "Tomato paste", aliases: [], aisle: .pantry,
                soldBy: [.mass]),
            .init(
                id: "spinach", name: "Spinach", aliases: ["baby spinach"], aisle: .produce,
                soldBy: [.mass]),
            .init(
                id: "milk-oat", name: "Oat milk", aliases: [], aisle: .dairy, soldBy: [.volume]),
            .init(
                id: "old", name: "Old thing", aliases: [], aisle: .other, soldBy: [.count],
                retired: true),
        ])

    @Test func frenchAndAccentlessNamesFindTheSameEntry() {
        #expect(catalog.exactMatch(for: "Bananes")?.id == "bananas")
        #expect(catalog.exactMatch(for: "creme sure")?.id == "sour-cream")
    }

    @Test func anExactNameOutranksALongerOneStartingTheSame() {
        #expect(catalog.search("tomato").map(\.id) == ["tomatoes", "tomato-paste"])
    }

    @Test func wordsMatchFromTheirStartAnywhereInAName() {
        #expect(catalog.search("past").map(\.id) == ["tomato-paste"])
    }

    @Test func freeTextWithAnUnknownWordStillFindsTheKnownOne() {
        #expect(catalog.search("PC baby spinach").map(\.id) == ["spinach"])
        #expect(catalog.search("no name tomato").first?.id == "tomatoes")
    }

    @Test func shortWordsAloneDoNotMatch() {
        #expect(catalog.search("pc of").isEmpty)
    }

    @Test func retiredEntriesAreNotSearchedButStillResolve() {
        #expect(catalog.search("old thing").isEmpty)
        #expect(catalog.entry(id: "old")?.name == "Old thing")
    }

    @Test func freeTextLandsInTheAisleOfTheLongestTermItContains() {
        #expect(catalog.guessAisle(for: "organic baby spinach") == .produce)
        #expect(catalog.guessAisle(for: "Oat milk vanilla") == .dairy)
        #expect(catalog.guessAisle(for: "ripe banana") == .produce)
    }

    @Test func unrecognisedTextHasNoAisle() {
        #expect(catalog.guessAisle(for: "xyzzy") == nil)
    }
}

@MainActor
struct ItemSearchTests {
    private let catalog = Catalog(
        version: 1,
        entries: [
            .init(
                id: "bananas", name: "Bananas", aliases: ["banana"], aisle: .produce,
                soldBy: [.mass]),
            .init(
                id: "banana-bread", name: "Banana bread", aliases: [], aisle: .bakery,
                soldBy: [.count]),
        ])

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(
            schema: AppSchema.schema, isStoredInMemoryOnly: true)
        return ModelContext(
            try ModelContainer(for: AppSchema.schema, configurations: [configuration]))
    }

    @Test func anOwnedEntryAppearsOnceAsTheShoppersItem() {
        let mine = GroceryItem(seedID: "bananas", name: "Bananas")

        let results = ItemSearch.results(for: "banana", items: [mine], catalog: catalog)

        #expect(results.map(\.name) == ["Bananas", "Banana bread"])
        if case .item = results.first {} else { Issue.record("expected the owned item first") }
    }

    @Test func usingAnEntryTwiceReusesOneItem() throws {
        let context = try makeContext()
        let entry = try #require(catalog.entry(id: "bananas"))

        let first = CatalogLibrary.item(for: entry, in: context)
        let second = CatalogLibrary.item(for: entry, in: context)

        #expect(first.persistentModelID == second.persistentModelID)
        #expect(first.aisle == .produce)
        #expect(!first.hasGoodPrice)
    }

    @Test func anOwnItemWinsAnExactNameOverTheDictionary() throws {
        let context = try makeContext()
        let mine = GroceryItem(name: "Bananas", userModified: true)
        context.insert(mine)

        let found = ItemIdentity.item(named: "bananas", catalog: catalog, in: context)

        #expect(found.persistentModelID == mine.persistentModelID)
    }

    @Test func anAliasOrAccentFindsTheSameItem() throws {
        let context = try makeContext()
        let mine = GroceryItem(name: "Sour cream", aliases: ["crème sure"], userModified: true)
        context.insert(mine)

        #expect(ItemIdentity.item(named: "CREME SURE", catalog: catalog, in: context) === mine)
    }

    @Test func aDictionaryNameBecomesThatEntrysItem() throws {
        let context = try makeContext()

        let item = ItemIdentity.item(named: "banana", catalog: catalog, in: context)

        #expect(item.seedID == "bananas")
        #expect(item.aisle == .produce)
    }

    @Test func unknownTextBecomesANewItemNamedAsTyped() throws {
        let context = try makeContext()

        let item = ItemIdentity.item(named: "  PC thighs ", catalog: catalog, in: context)

        #expect(item.name == "PC thighs")
        #expect(item.seedID.isEmpty)
        #expect(try context.fetch(FetchDescriptor<GroceryItem>()).count == 1)
    }

    @Test func typingTheSameNameTwiceMakesOneItem() throws {
        let context = try makeContext()

        let first = ItemIdentity.item(named: "Paper towels", catalog: catalog, in: context)
        let second = ItemIdentity.item(named: "paper towels", catalog: catalog, in: context)

        #expect(first === second)
    }
}
