import SwiftData
import SwiftUI

nonisolated enum CheckInputMode: CaseIterable, Hashable, Sendable {
    case type
    case scan

    var toggled: CheckInputMode { self == .type ? .scan : .type }
    var title: String { self == .type ? "Type" : "Scan" }
    var symbolName: String { self == .type ? "keyboard" : "camera.viewfinder" }
}

struct CheckView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [GroceryItem]
    @State private var viewModel = CheckViewModel()
    @State private var mode: CheckInputMode = .type
    @State private var isShowingItemPicker = false
    @State private var isShowingSaveSheet = false

    /// Resolved from the live `@Query`, so a deleted row becomes `nil` reactively — the fix for a
    /// stale selection is that the query, not a held reference, is the source of truth.
    private var selectedItem: GroceryItem? {
        guard let id = viewModel.selectedItemID else { return nil }
        return items.first { $0.persistentModelID == id }
    }

    private var baseline: NormalizedPrice? {
        selectedItem.map {
            NormalizedPrice(dimension: $0.dimension, canonical: $0.goodPriceCanonical)
        }
    }

    private var settledVerdict: Verdict? {
        guard let settledPrice = viewModel.settledPrice, let baseline,
            settledPrice.dimension == baseline.dimension, baseline.canonical > 0
        else { return nil }
        return VerdictEngine.verdict(price: settledPrice.canonical, baseline: baseline.canonical)
    }

    var body: some View {
        // The system safe area already clears the Dynamic Island / status bar (adapting per device)
        // and reserves room for the floating Liquid Glass tab bar. Fitting inside it is the part the
        // system cannot do: this screen does not scroll, so on a short device the roomy layout would
        // overflow and clip at both ends. ViewThatFits picks the most generous one that fits.
        ViewThatFits(in: .vertical) {
            content(metrics: .spacious)
            content(metrics: .roomy)
            content(metrics: .compact)
        }
        // A keypad is a fixed canvas: past this size the keys and the hero grow faster than the
        // screen can give, and the bottom row is what falls off. Digits gain nothing from the
        // accessibility sizes anyway, which is why the system keypads bound themselves the same way.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .simultaneousGesture(modeSwipe)
        .onAppear { viewModel.attach(modelContext: modelContext) }
        .sheet(isPresented: $isShowingItemPicker) {
            ItemPickerSheet(selectedItemID: $viewModel.selectedItemID)
        }
        .sheet(isPresented: $isShowingSaveSheet) {
            if let normalizedPrice = viewModel.normalizedPrice {
                SetGoodPriceSheet(price: normalizedPrice) { name in
                    viewModel.saveAsGoodPrice(named: name)
                }
            }
        }
    }

    private func content(metrics: CheckMetrics) -> some View {
        VStack(spacing: metrics.stackSpacing) {
            ModeBubble(mode: $mode)

            Spacer(minLength: 0)

            VerdictPanelView(
                entered: viewModel.normalizedPrice,
                baseline: baseline,
                bookmarked: viewModel.lastBookmarked,
                settledVerdict: settledVerdict,
                isSettled: viewModel.isSettled,
                hasEnoughInput: viewModel.hasEnoughInput,
                settleTick: viewModel.settleTick,
                metrics: metrics,
                onClearBookmark: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        viewModel.clearBookmark()
                    }
                }
            )

            Spacer(minLength: 0)

            inputZone(metrics: metrics)
                .padding(metrics.contentPadding)
        }
    }

    @ViewBuilder
    private func inputZone(metrics: CheckMetrics) -> some View {
        switch mode {
        case .type:
            VStack(spacing: 0) {
                CheckFieldsView(
                    viewModel: viewModel,
                    selectedItemName: selectedItem?.name,
                    baseline: baseline,
                    onChooseItem: { isShowingItemPicker = true },
                    onSetGoodPrice: setGoodPrice,
                    onClearItem: { viewModel.selectedItemID = nil },
                    metrics: metrics
                )

                Spacer()
                    .frame(minHeight: metrics.itemRowGap, maxHeight: metrics.itemRowGapMax)

                KeypadView(
                    viewModel: viewModel,
                    onBookmark: { viewModel.bookmarkCurrentPrice(for: selectedItem) },
                    metrics: metrics
                )
            }
            .transition(.move(edge: .leading).combined(with: .opacity))
        case .scan:
            ScanModeView(onCandidate: viewModel.applyScannedEntry)
                .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }

    private func setGoodPrice() {
        if let selectedItem {
            viewModel.updateGoodPrice(for: selectedItem)
        } else {
            isShowingSaveSheet = true
        }
    }

    private var modeSwipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let horizontal = value.translation.width
                guard abs(horizontal) > abs(value.translation.height) * 1.5,
                    abs(horizontal) > 60
                else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    mode = horizontal < 0 ? .scan : .type
                }
            }
    }
}

@MainActor
private func previewContainer() -> ModelContainer {
    let container = try! ModelContainer(
        for: GroceryItem.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    container.mainContext.insert(
        GroceryItem(
            seedID: "chicken-thigh-boneless",
            name: "Chicken thigh (boneless)",
            aliases: ["thighs"],
            category: "meat",
            goodPriceCanonical: 1.10
        )
    )
    return container
}

#Preview("Check") {
    CheckView()
        .modelContainer(previewContainer())
}

/// The shortest supported iPhone, and the size the fixed layout has to survive.
#Preview("Check · iPhone SE (375×667)", traits: .fixedLayout(width: 375, height: 667)) {
    CheckView()
        .modelContainer(previewContainer())
}

#Preview("Check · SE + AX5 type", traits: .fixedLayout(width: 375, height: 667)) {
    CheckView()
        .modelContainer(previewContainer())
        .environment(\.dynamicTypeSize, .accessibility5)
}
