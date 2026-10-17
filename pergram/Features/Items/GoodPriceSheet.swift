import SwiftData
import SwiftUI

/// Sets a good price for an item, reusing the Check calculator so there is one price-entry surface.
/// It shows the live good price as a hero — you are *defining* one here, not comparing against
/// one.
struct GoodPriceSheet: View {
    let item: GroceryItem

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = CheckViewModel()

    /// How the dictionary says this item is usually priced, so a first good price starts in the right
    /// unit — avocados by the each, chicken by weight.
    private var usualDimension: PriceDimension? {
        guard !item.seedID.isEmpty else { return nil }
        return CatalogLibrary.bundled.entry(id: item.seedID)?.soldBy.first
    }
    private var hasPrice: Bool { viewModel.normalizedPrice != nil }

    private var canonicalUnit: MeasureUnit {
        .canonicalUnit(for: viewModel.normalizedPrice?.dimension ?? .mass)
    }

    var body: some View {
        NavigationStack {
            // Listed rather than looped: ViewThatFits treats a ForEach as one child, which would
            // leave it with a single candidate and no fallback at all.
            ViewThatFits(in: .vertical) {
                calculator(metrics: .spacious)
                calculator(metrics: .roomy)
                calculator(metrics: .compact)
            }
            .padding(.horizontal)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(!hasPrice)
                }
            }
        }
        .presentationBackground(Color.canvas)
        .onAppear {
            viewModel.attach(modelContext: modelContext)
            viewModel.recordsChecks = false
            switch item.goodPrices.first?.dimension ?? usualDimension {
            case .count: viewModel.amountUnit = .each
            case .volume: viewModel.amountUnit = .millilitre
            default: break
            }
        }
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
        viewModel.updateGoodPrice(for: item)
        dismiss()
    }
}

#Preview {
    GoodPriceSheet(item: GroceryItem(name: "Eggs", aisle: .dairy))
        .modelContainer(for: GroceryItem.self, inMemory: true)
}
