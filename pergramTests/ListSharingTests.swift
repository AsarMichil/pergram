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

    private func samplePayload(chickenPrice: Double = 0.95) -> ListPayload {
        ListPayload(
            id: UUID(),
            name: "Weekly",
            entries: [
                .init(id: UUID(), text: "Milk", isSkipped: false, item: nil),
                .init(
                    id: UUID(), text: "Thighs", isSkipped: true,
                    item: .init(
                        seedID: "chicken-thigh-boneless", name: "Chicken thigh", aisle: "meat",
                        goodPrices: [.init(dimension: .mass, canonical: chickenPrice)])),
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

    @Test func plainTextMarksSkippedEntries() {
        #expect(samplePayload().plainText == "Weekly\n☐ Milk\n– Thighs (not this time)")
    }

    @Test func exportCarriesSkipFlagsAndGoodPrices() throws {
        let context = try makeContext()
        let chicken = GroceryItem(
            seedID: "chicken-thigh-boneless",
            goodPrice: NormalizedPrice(dimension: .mass, canonical: 1.10))
        context.insert(chicken)
        let list = GroceryList(name: "Weekly")
        context.insert(list)
        list.append("Thighs", item: chicken).isSkipped = true

        let payload = ListSharing.payload(for: list)

        #expect(payload.id == list.id)
        #expect(payload.entries.first?.isSkipped == true)
        #expect(
            payload.entries.first?.item?.goodPrices == [.init(dimension: .mass, canonical: 1.10)])
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
        #expect(list.orderedEntries.last?.item?.persistentModelID == chicken.persistentModelID)
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

    @Test func anItemYouLackIsCreatedWithTheirPrice() throws {
        let context = try makeContext()

        let plan = ListSharing.plan(samplePayload(), in: context)
        ListSharing.apply(plan, accepting: [], in: context)

        #expect(plan.newItemNames == ["Chicken thigh"])
        #expect(try items(in: context).map(\.goodPricePerMass) == [0.95])
    }

    @Test func userMadeItemsMatchByName() throws {
        let context = try makeContext()
        let mine = GroceryItem(
            name: "Oat milk", goodPrice: NormalizedPrice(dimension: .mass, canonical: 0.4),
            userModified: true)
        context.insert(mine)
        let payload = ListPayload(
            id: UUID(), name: "L",
            entries: [
                .init(
                    id: UUID(), text: "oat milk", isSkipped: false,
                    item: .init(
                        seedID: "", name: " oat MILK", aisle: "",
                        goodPrices: [.init(dimension: .mass, canonical: 0.4)]))
            ])

        let list = ListSharing.apply(
            ListSharing.plan(payload, in: context), accepting: [], in: context)

        #expect(try items(in: context).count == 1)
        #expect(list.orderedEntries.first?.item?.persistentModelID == mine.persistentModelID)
    }

    @Test func reimportingUpdatesTheSameListInPlace() throws {
        let context = try makeContext()
        let first = samplePayload()
        ListSharing.apply(ListSharing.plan(first, in: context), accepting: [], in: context)

        let revised = ListPayload(
            id: first.id, name: "Weekly shop",
            entries: [
                .init(id: first.entries[1].id, text: "Thighs", isSkipped: false, item: nil),
                .init(id: UUID(), text: "Eggs", isSkipped: false, item: nil),
            ])
        let plan = ListSharing.plan(revised, in: context)
        let list = ListSharing.apply(plan, accepting: [], in: context)

        #expect(plan.replacing != nil)
        #expect(try context.fetch(FetchDescriptor<GroceryList>()).count == 1)
        #expect(list.name == "Weekly shop")
        #expect(list.orderedEntries.map(\.text) == ["Thighs", "Eggs"])
        #expect(list.orderedEntries.first?.id == first.entries[1].id)
        #expect(list.orderedEntries.first?.isSkipped == false)
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
                    id: UUID(), text: "Thighs", isSkipped: false,
                    item: .init(
                        seedID: "chicken-thigh-boneless", name: "Chicken thigh", aisle: "meat",
                        goodPrices: [
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

    @Test func anEntrysAisleTravelsWithTheList() throws {
        let context = try makeContext()
        let list = GroceryList(name: "Weekly")
        context.insert(list)
        list.append("Birthday candles", aisle: .bakery)

        let payload = ListSharing.payload(for: list)
        let receiver = try makeContext()
        let imported = ListSharing.apply(
            ListSharing.plan(payload, in: receiver), accepting: [], in: receiver)

        #expect(imported.orderedEntries.first?.aisle == .bakery)
    }

    @Test func anEntryWithNoAisleIsGuessedOnImport() throws {
        let context = try makeContext()
        let payload = ListPayload(
            id: UUID(), name: "L",
            entries: [.init(id: UUID(), text: "paper towels", isSkipped: false, item: nil)])

        let list = ListSharing.apply(
            ListSharing.plan(payload, in: context), accepting: [], in: context)

        #expect(list.orderedEntries.first?.aisle == .household)
    }

    @Test func importedGoodPricesArePriceHistory() throws {
        let context = try makeContext()

        ListSharing.apply(
            ListSharing.plan(samplePayload(), in: context), accepting: [], in: context)

        let recorded = try context.fetch(FetchDescriptor<PriceObservation>())
        #expect(recorded.map(\.reason) == [.goodPrice])
    }
}
