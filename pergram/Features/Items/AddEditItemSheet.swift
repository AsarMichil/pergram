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
    @FocusState private var isNameFocused: Bool
    @State private var canvasHeight: CGFloat?

    private var isEditing: Bool { item != nil }

    /// How the dictionary says this item is usually priced, so a first good price starts in the right
    /// unit — avocados by the each, chicken by weight.
    private var usualDimension: PriceDimension? {
        guard let seedID = item?.seedID, !seedID.isEmpty else { return nil }
        return CatalogLibrary.bundled.entry(id: seedID)?.soldBy.first
    }
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
            // The column hangs in an overlay at the height the sheet had before the name took
            // focus. An overlay cannot resize or re-centre what it sits on, so the keyboard covers
            // the keypad instead of shrinking the calculator and lifting it under the title bar.
            Color.clear
                .onGeometryChange(for: CGFloat.self, of: \.size.height) { height in
                    if !isNameFocused { canvasHeight = height }
                }
                .overlay(alignment: .top) {
                    form.frame(height: canvasHeight, alignment: .top)
                }
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .navigationTitle(isEditing ? (item?.name ?? "Edit price") : "New item")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: close)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", action: save)
                            .fontWeight(.semibold)
                            .disabled(!canSave)
                    }
                }
        }
        .presentationBackground(Color.canvas)
        .onAppear {
            viewModel.attach(modelContext: modelContext)
            viewModel.recordsChecks = false
            switch item?.goodPrices.first?.dimension ?? usualDimension {
            case .count: viewModel.amountUnit = .each
            case .volume: viewModel.amountUnit = .millilitre
            default: break
            }
        }
    }

    private var form: some View {
        VStack(spacing: 0) {
            if !isEditing {
                nameField
                    .padding(.top, 8)
            }
            // Listed rather than looped: ViewThatFits treats a ForEach as one child, which would
            // leave it with a single candidate and no fallback at all.
            ViewThatFits(in: .vertical) {
                calculator(metrics: .spacious)
                calculator(metrics: .roomy)
                calculator(metrics: .compact)
            }
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture().onEnded { isNameFocused = false })
        }
        .padding(.horizontal)
    }

    /// The sheet carries the same calculator as the Check screen, so it settles the same way: a
    /// fixed column with a keypad at the bottom, on the most generous layout that fits. Safe to
    /// measure by candidate here — nothing in this one holds a system resource.
    private func calculator(metrics: CheckMetrics) -> some View {
        VStack(spacing: 0) {
            hero(metrics: metrics)

            // The card belongs with the keypad you type into it with, so the slack goes above them
            // and the good price gets the room instead.
            Spacer(minLength: metrics.stackSpacing)

            PriceExpressionCard(viewModel: viewModel, metrics: metrics)

            Spacer()
                .frame(minHeight: metrics.itemRowGap, maxHeight: metrics.itemRowGapMax)

            KeypadView(viewModel: viewModel, onBookmark: nil, metrics: metrics)
        }
        .padding(.vertical, metrics.contentPadding)
    }

    private var nameField: some View {
        TextField("Item name (e.g. Eggs)", text: $name)
            .focused($isNameFocused)
            .submitLabel(.done)
            .textFieldStyle(.plain)
            .font(.title3.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.quaternary.opacity(0.25))
            }
    }

    private func hero(metrics: CheckMetrics) -> some View {
        VStack(spacing: 2) {
            Text("good price")
                .font(.caption.weight(.semibold))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(.tertiary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(PriceDisplay.money(viewModel.normalizedPrice?.canonical ?? 0))
                    .font(
                        .system(size: metrics.sheetHeroFontSize, weight: .black, design: .rounded)
                    )
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
        .frame(height: metrics.sheetHeroHeight)
    }

    private func save() {
        if let item {
            viewModel.updateGoodPrice(for: item)
        } else {
            viewModel.saveAsGoodPrice(named: name)
        }
        close()
    }

    private func close() {
        isNameFocused = false
        dismiss()
    }
}

#Preview("Add") {
    AddEditItemSheet(item: nil)
        .modelContainer(for: GroceryItem.self, inMemory: true)
}
