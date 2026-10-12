import Foundation
import SwiftData
import Testing

@testable import pergram

/// One person shares a list, another shops it, the first edits it and shares it again.
@MainActor
struct ReshareTests {
    private let sender: ModelContext
    private let receiver: ModelContext
    private let list: GroceryList

    init() throws {
        func context() throws -> ModelContext {
            let configuration = ModelConfiguration(
                schema: AppSchema.schema, isStoredInMemoryOnly: true)
            return ModelContext(
                try ModelContainer(for: AppSchema.schema, configurations: [configuration]))
        }
        sender = try context()
        receiver = try context()
        list = GroceryList(name: "Weekly")
        sender.insert(list)
        list.append("Milk")
        list.append("Eggs")
        list.append("Paper towels")
        try sender.save()
    }

    private func receive() -> ListSharing.ImportPlan {
        ListSharing.plan(ListSharing.payload(for: list), in: receiver)
    }

    private func receiverLists() throws -> [GroceryList] {
        try receiver.fetch(FetchDescriptor<GroceryList>())
    }

    private func entry(_ text: String, in list: GroceryList) -> ListEntry? {
        list.orderedEntries.first { $0.text == text }
    }

    @Test func aReshareShowsWhatTheSenderChanged() throws {
        ListSharing.apply(receive(), accepting: [], in: receiver)
        list.orderedEntries.first { $0.text == "Paper towels" }?.isSkipped = true
        list.append("Bananas")

        let changes = try #require(receive().changes)

        #expect(changes.added == ["Bananas"])
        #expect(changes.nowSkipped == ["Paper towels"])
        #expect(changes.removed.isEmpty)
    }

    @Test func updatingBringsTheSendersNotThisTime() throws {
        ListSharing.apply(receive(), accepting: [], in: receiver)
        list.orderedEntries.first { $0.text == "Paper towels" }?.isSkipped = true
        list.append("Bananas")

        let updated = ListSharing.apply(receive(), accepting: [], in: receiver)

        #expect(try receiverLists().count == 1)
        #expect(entry("Paper towels", in: updated)?.isSkipped == true)
        #expect(entry("Bananas", in: updated) != nil)
    }

    @Test func anUpdateMidTripKeepsWhatTheReceiverCrossedOff() throws {
        let theirs = ListSharing.apply(receive(), accepting: [], in: receiver)
        let trip = Shopping.startTrip(shopping: theirs, in: receiver)
        let milk = try #require(entry("Milk", in: theirs))
        Shopping.setCrossed(true, for: milk, in: trip)
        list.append("Bananas")

        ListSharing.apply(receive(), accepting: [], in: receiver)

        #expect(trip.isCrossed(milk))
    }

    @Test func aCopyLeavesTheReceiversListAlone() throws {
        let original = ListSharing.apply(receive(), accepting: [], in: receiver)
        try #require(entry("Eggs", in: original)).isSkipped = true
        list.append("Bananas")

        let copy = ListSharing.apply(receive(), accepting: [], asCopy: true, in: receiver)

        #expect(try receiverLists().count == 2)
        #expect(copy.id != original.id)
        #expect(copy.name == "Weekly (copy)")
        #expect(entry("Bananas", in: original) == nil)
        #expect(entry("Eggs", in: original)?.isSkipped == true)
        #expect(
            Set(copy.orderedEntries.map(\.id)).isDisjoint(with: original.orderedEntries.map(\.id)))
    }

    @Test func laterSharesUpdateTheOriginalNotTheCopy() throws {
        let original = ListSharing.apply(receive(), accepting: [], in: receiver)
        let copy = ListSharing.apply(receive(), accepting: [], asCopy: true, in: receiver)
        list.append("Bananas")

        let plan = receive()
        ListSharing.apply(plan, accepting: [], in: receiver)

        #expect(plan.replacing?.id == original.id)
        #expect(entry("Bananas", in: original) != nil)
        #expect(entry("Bananas", in: copy) == nil)
    }
}
