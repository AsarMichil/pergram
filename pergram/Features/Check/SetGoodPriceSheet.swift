import SwiftUI

struct SetGoodPriceSheet: View {
    let price: NormalizedPrice
    var onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    private var canonicalUnit: MeasureUnit { .canonicalUnit(for: price.dimension) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Good price") {
                        Text(
                            "\(price.canonical, format: .currency(code: "CAD"))\(PriceDisplay.suffix(for: canonicalUnit))"
                        )
                        .monospacedDigit()
                    }
                }
                Section("Item name") {
                    TextField("e.g. Chicken thigh", text: $name)
                }
            }
            .navigationTitle("Save good price")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    SetGoodPriceSheet(
        price: NormalizedPrice(dimension: .mass, canonical: 1.32), onSave: { _ in })
}
