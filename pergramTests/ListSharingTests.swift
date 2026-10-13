import Foundation
import SwiftData
import Testing

@testable import pergram

@MainActor
struct ListSharingTests {
    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(
            schema: AppSchema.schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: AppSchema.schema, configurations: [configuration])
        return ModelContext(container)
    }

    private func items(in context: ModelContext) throws -> [GroceryItem] {
        try context.fetch(FetchDescriptor<GroceryItem>())
    }

    private func item(
        _ name: String, seedID: String = "", aisle: String = "",
        prices: [ListPayload.GoodPrice] = []
    ) -> ListPayload.Item {
        .init(seedID: seedID, name: name, aisle: aisle, goodPrices: prices)
    }

    private func samplePayload(chickenPrice: Double = 0.95) -> ListPayload {
        ListPayload(
            id: UUID(),
            name: "Weekly",
            entries: [
                .init(id: UUID(), isSkipped: false, note: "2 L", item: item("Milk")),
                .init(
                    id: UUID(), isSkipped: true,
                    item: item(
                        "Chicken thigh", seedID: "chicken-thigh-boneless", aisle: "meat",
                        prices: [.init(dimension: .mass, canonical: chickenPrice)])),
            ]
        )
    }

    @Test func payloadSurvivesEncoding() throws {
        let payload = samplePayload()

        #expect(try ListPayload.decode(from: payload.encoded()) == payload)
    }

    @Test func somethingElseIsRejected() {
        #expect(throws: ListPayload.DecodingFailure.notAList) {
            try ListPayload.decode(from: Data(#"{"seedVersion": 3, "items": []}"#.utf8))
        }
    }

    @Test func aNewerVersionIsRejectedRatherThanMisread() throws {
        var json = String(decoding: try samplePayload().encoded(), as: UTF8.self)
        json = json.replacingOccurrences(of: #""version" : 1"#, with: #""version" : 9"#)

        #expect(throws: ListPayload.DecodingFailure.newerVersion(9)) {
            try ListPayload.decode(from: Data(json.utf8))
        }
    }

    @Test func plainTextShowsNotesAndSkippedEntries() {
        #expect(
            samplePayload().plainText == "Weekly\n☐ Milk — 2 L\n– Chicken thigh (not this time)")
    }

    @Test func sharedMessageEndsWithWhereToGetTheApp() {
        #expect(
            ListShareItem.message(for: samplePayload())
                == "Weekly\n☐ Milk — 2 L\n– Chicken thigh (not this time)\n\n"
                + "Get PerGram Go — grocery lists that know a good price: "
                + "https://apps.apple.com/app/id6799463251")
    }

    @Test func exportCarriesNotesSkipFlagsAndGoodPrices() throws {
        let context = try makeContext()
        let chicken = GroceryItem(
            seedID: "chicken-thigh-boneless", name: "Chicken thigh",
            goodPrice: NormalizedPrice(dimension: .mass, canonical: 1.10))
        context.insert(chicken)
        let list = GroceryList(name: "Weekly")
        context.insert(list)
        let entry = list.add(chicken)
        entry.isSkipped = true
        entry.note = "family pack"

        let payload = ListSharing.payload(for: list)

        #expect(payload.id == list.id)
        #expect(payload.entries.first?.isSkipped == true)
        #expect(payload.entries.first?.note == "family pack")
        #expect(
            payload.entries.first?.item.goodPrices == [.init(dimension: .mass, canonical: 1.10)])
    }

    @Test func aDifferentPriceIsOfferedNotApplied() throws {
        let context = try makeContext()
        let chicken = GroceryItem(
            seedID: "chicken-thigh-boneless",
            goodPrice: NormalizedPrice(dimension: .mass, canonical: 1.10))
        context.insert(chicken)

        let plan = ListSharing.plan(samplePayload(), in: context)
        let list = ListSharing.apply(plan, accepting: [], in: context)

        #expect(plan.offers.count == 1)
        #expect(chicken.goodPricePerMass == 1.10)
        #expect(list.orderedEntries.last?.item === chicken)
        #expect(list.orderedEntries.last?.isSkipped == true)
    }

    @Test func anAcceptedOfferReplacesThePrice() throws {
        let context = try makeContext()
        let chicken = GroceryItem(
            seedID: "chicken-thigh-boneless",
            goodPrice: NormalizedPrice(dimension: .mass, canonical: 1.10))
        context.insert(chicken)

        let plan = ListSharing.plan(samplePayload(), in: context)
        ListSharing.apply(plan, accepting: Set(plan.offers.map(\.id)), in: context)

        #expect(chicken.goodPricePerMass == 0.95)
        #expect(chicken.userModified)
    }

    @Test func aMatchingPriceAsksNothing() throws {
        let context = try makeContext()
        context.insert(
            GroceryItem(
                seedID: "chicken-thigh-boneless",
                goodPrice: NormalizedPrice(dimension: .mass, canonical: 0.952)))

        #expect(ListSharing.plan(samplePayload(), in: context).offers.isEmpty)
    }

    @Test func itemsYouLackAreCreatedWithTheirPrices() throws {
        let context = try makeContext()

        let plan = ListSharing.plan(samplePayload(), in: context)
        let list = ListSharing.apply(plan, accepting: [], in: context)

        #expect(plan.newItemNames == ["Milk", "Chicken thigh"])
        #expect(list.orderedEntries.map(\.name) == ["Milk", "Chicken thigh"])
        #expect(list.orderedEntries.first?.note == "2 L")
        #expect(list.orderedEntries.last?.item?.goodPricePerMass == 0.95)
    }

    @Test func namesMatchTheWayTypedTextDoes() throws {
        let context = try makeContext()
        let mine = GroceryItem(name: "Crème sure", userModified: true)
        context.insert(mine)
        let payload = ListPayload(
            id: UUID(), name: "L",
            entries: [.init(id: UUID(), isSkipped: false, item: item(" creme SURE"))])

        let list = ListSharing.apply(
            ListSharing.plan(payload, in: context), accepting: [], in: context)

        #expect(try items(in: context).count == 1)
        #expect(list.orderedEntries.first?.item === mine)
    }

    @Test func reimportingUpdatesTheSameListInPlace() throws {
        let context = try makeContext()
        let first = samplePayload()
        ListSharing.apply(ListSharing.plan(first, in: context), accepting: [], in: context)

        let revised = ListPayload(
            id: first.id, name: "Weekly shop",
            entries: [
                .init(id: first.entries[1].id, isSkipped: false, item: first.entries[1].item),
                .init(id: UUID(), isSkipped: false, item: item("Eggs")),
            ])
        let plan = ListSharing.plan(revised, in: context)
        let list = ListSharing.apply(plan, accepting: [], in: context)

        #expect(plan.replacing != nil)
        #expect(try context.fetch(FetchDescriptor<GroceryList>()).count == 1)
        #expect(list.name == "Weekly shop")
        #expect(list.orderedEntries.map(\.name) == ["Chicken thigh", "Eggs"])
        #expect(list.orderedEntries.first?.id == first.entries[1].id)
        #expect(list.orderedEntries.first?.isSkipped == false)
    }

    @Test func anItemDroppedFromTheListLeavesNothingBehind() throws {
        let context = try makeContext()
        let first = samplePayload()
        ListSharing.apply(ListSharing.plan(first, in: context), accepting: [], in: context)

        let revised = ListPayload(id: first.id, name: "Weekly", entries: [first.entries[1]])
        ListSharing.apply(ListSharing.plan(revised, in: context), accepting: [], in: context)

        #expect(try items(in: context).map(\.name) == ["Chicken thigh"])
    }

    @Test func aPriceYouLackStartsAcceptedAndOneYouHaveDoesNot() throws {
        let context = try makeContext()
        let chicken = GroceryItem(
            seedID: "chicken-thigh-boneless",
            goodPrice: NormalizedPrice(dimension: .mass, canonical: 1.10))
        context.insert(chicken)
        let payload = ListPayload(
            id: UUID(), name: "L",
            entries: [
                .init(
                    id: UUID(), isSkipped: false,
                    item: item(
                        "Chicken thigh", seedID: "chicken-thigh-boneless", aisle: "meat",
                        prices: [
                            .init(dimension: .mass, canonical: 0.95),
                            .init(dimension: .count, canonical: 2.50),
                        ]))
            ])

        let plan = ListSharing.plan(payload, in: context)
        ListSharing.apply(plan, accepting: plan.initiallyAccepted, in: context)

        #expect(plan.offers.count == 2)
        #expect(chicken.goodPricePerMass == 1.10)
        #expect(chicken.goodPricePerEach == 2.50)
    }

    @Test func anItemsAisleTravelsWithTheList() throws {
        let context = try makeContext()
        let candles = GroceryItem(name: "Birthday candles", aisle: .bakery)
        context.insert(candles)
        let list = GroceryList(name: "Weekly")
        context.insert(list)
        list.add(candles)

        let payload = ListSharing.payload(for: list)
        let receiver = try makeContext()
        let imported = ListSharing.apply(
            ListSharing.plan(payload, in: receiver), accepting: [], in: receiver)

        #expect(imported.orderedEntries.first?.aisle == .bakery)
    }

    @Test func importedGoodPricesArePriceHistory() throws {
        let context = try makeContext()

        ListSharing.apply(
            ListSharing.plan(samplePayload(), in: context), accepting: [], in: context)

        let recorded = try context.fetch(FetchDescriptor<PriceObservation>())
        #expect(recorded.map(\.reason) == [.goodPrice])
    }
}
