import SwiftUI

struct SetGoodPriceSheet: View {
    let price: NormalizedPrice
    var onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("checkDisplayUnit") private var displayUnitRaw = MeasureUnit.per100Grams.rawValue
    @State private var name = ""
    @FocusState private var isNameFocused: Bool

    private var displayUnit: MeasureUnit {
        PriceDisplay.displayUnit(
            for: price.dimension, preferred: MeasureUnit(rawValue: displayUnitRaw) ?? .per100Grams)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Good price") {
                        Text(PriceDisplay.formatted(price, in: displayUnit))
                            .monospacedDigit()
                    }
                }
                Section("Item name") {
                    TextField("e.g. Chicken thigh", text: $name)
                        .focused($isNameFocused)
                        .submitLabel(.done)
                        .onSubmit(save)
                }
            }
            .navigationTitle("Save good price")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear { isNameFocused = true }
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        onSave(trimmedName)
        dismiss()
    }
}

#Preview {
    SetGoodPriceSheet(
        price: NormalizedPrice(dimension: .mass, canonical: 1.32), onSave: { _ in })
}
