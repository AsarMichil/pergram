import SwiftUI

struct SetGoodPriceSheet: View {
    let pricePer100g: Double
    var onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Good price") {
                        Text(pricePer100g, format: .currency(code: "CAD"))
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
    SetGoodPriceSheet(pricePer100g: 1.32, onSave: { _ in })
}
