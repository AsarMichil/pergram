import SwiftData
import SwiftUI

struct ImportListSheet: View {
    let incoming: IncomingList
    var onImported: (GroceryList) -> Void = { _ in }
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var plan: ListSharing.ImportPlan?
    @State private var accepted: Set<PersistentIdentifier> = []

    var body: some View {
        NavigationStack {
            Group {
                switch incoming.result {
                case .success:
                    if let plan { review(plan) } else { ProgressView() }
                case .failure(let error):
                    ContentUnavailableView(
                        "Can't open this list",
                        systemImage: "exclamationmark.triangle",
                        description: Text(Self.message(for: error))
                    )
                }
            }
            .navigationTitle("Import list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if let plan {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(plan.replacing == nil ? "Import" : "Update") {
                            let list = ListSharing.apply(
                                plan, accepting: accepted, in: modelContext)
                            dismiss()
                            onImported(list)
                        }
                        .accessibilityIdentifier("confirmImport")
                    }
                }
            }
        }
        .onAppear {
            guard plan == nil, case .success(let payload) = incoming.result else { return }
            plan = ListSharing.plan(payload, in: modelContext)
        }
    }

    private func review(_ plan: ListSharing.ImportPlan) -> some View {
        List {
            Section {
                LabeledContent(plan.payload.name) {
                    Text(
                        plan.payload.entries.count == 1
                            ? "1 item" : "\(plan.payload.entries.count) items")
                }
            } footer: {
                if plan.replacing != nil {
                    Text("You already have this list. Importing updates it to match.")
                }
            }

            if !plan.offers.isEmpty {
                Section {
                    ForEach(plan.offers) { offer in
                        Toggle(isOn: binding(for: offer)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(offer.item.name)
                                Text(
                                    "Theirs \(format(offer.theirs)) · yours \(format(offer.yours))"
                                )
                                .font(.footnote)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Their good prices")
                        Spacer()
                        Button(accepted.count == plan.offers.count ? "Keep mine" : "Use all theirs")
                        {
                            accepted =
                                accepted.count == plan.offers.count
                                ? [] : Set(plan.offers.map(\.id))
                        }
                        .font(.footnote)
                        .textCase(nil)
                    }
                } footer: {
                    Text("Your prices stay unless you switch one on.")
                }
            }

            if !plan.newItemNames.isEmpty {
                Section {
                    ForEach(plan.newItemNames, id: \.self, content: Text.init)
                } header: {
                    Text("New items")
                } footer: {
                    Text("Added to your items with their good price.")
                }
            }
        }
    }

    private func binding(for offer: ListSharing.PriceOffer) -> Binding<Bool> {
        Binding(
            get: { accepted.contains(offer.id) },
            set: { isOn in
                if isOn { accepted.insert(offer.id) } else { accepted.remove(offer.id) }
            }
        )
    }

    private func format(_ price: NormalizedPrice) -> String {
        PriceDisplay.formatted(price, in: MeasureUnit.canonicalUnit(for: price.dimension))
    }

    private static func message(for error: Error) -> String {
        if case ListPayload.DecodingFailure.newerVersion = error {
            return "It was shared from a newer version of PerGram. Update the app to open it."
        }
        return "The file isn't a PerGram list, or it was damaged on the way."
    }
}
