import SwiftData
import SwiftUI

/// Adds a new item or sets a new good price for an existing one, reusing the Check calculator so
/// there is one price-entry surface. It shows the live good price as a hero — you are *defining* a
/// baseline here, not comparing against one — and needs no cross-tab navigation.
struct AddEditItemSheet: View {
    let item: GroceryItem?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = CheckViewModel()
    @State private var name = ""

    private var isEditing: Bool { item != nil }
    private var hasPrice: Bool { viewModel.normalizedPrice != nil }

    private var canonicalUnit: MeasureUnit {
        .canonicalUnit(for: viewModel.normalizedPrice?.dimension ?? .mass)
    }

    private var canSave: Bool {
        guard hasPrice else { return false }
        return isEditing || !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if !isEditing {
                    nameField
                }
                hero
                PriceExpressionCard(viewModel: viewModel)
                Spacer(minLength: 0)
                KeypadView(viewModel: viewModel, onBookmark: nil)
            }
            .padding()
            .navigationTitle(isEditing ? (item?.name ?? "Edit price") : "New item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
        .onAppear {
            viewModel.attach(modelContext: modelContext)
            if item?.dimension == .count {
                viewModel.amountUnit = .each
            }
        }
    }

    private var nameField: some View {
        TextField("Item name (e.g. Eggs)", text: $name)
            .textFieldStyle(.plain)
            .font(.title3.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.quaternary.opacity(0.25))
            }
    }

    private var hero: some View {
        VStack(spacing: 2) {
            Text("good price")
                .font(.caption.weight(.semibold))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(.tertiary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(viewModel.normalizedPrice?.canonical ?? 0, format: .currency(code: "CAD"))
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(PriceDisplay.suffix(for: canonicalUnit))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .opacity(hasPrice ? 1 : 0.3)
            .animation(
                reduceMotion
                    ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.8),
                value: viewModel.normalizedPrice?.canonical
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 64)
    }

    private func save() {
        if let item {
            viewModel.updateGoodPrice(for: item)
        } else {
            viewModel.saveAsGoodPrice(named: name)
        }
        dismiss()
    }
}

#Preview("Add") {
    AddEditItemSheet(item: nil)
        .modelContainer(for: GroceryItem.self, inMemory: true)
}
