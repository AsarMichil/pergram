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
        // and reserves room for the floating Liquid Glass tab bar, so this fixed keypad screen just
        // lives inside it — no manual clearances or edge-to-edge overrides needed.
        VStack {
            ModeBubble(mode: $mode)

            Spacer(minLength: 0)

            VerdictPanelView(
                entered: viewModel.normalizedPrice,
                baseline: baseline,
                settledVerdict: settledVerdict,
                isSettled: viewModel.isSettled,
                hasEnoughInput: viewModel.hasEnoughInput,
                settleTick: viewModel.settleTick,
                onSaveAsGoodPrice: {
                    if let selectedItem {
                        viewModel.updateGoodPrice(for: selectedItem)
                    } else {
                        isShowingSaveSheet = true
                    }
                }
            ) {
                if let lastBookmarked = viewModel.lastBookmarked {
                    LastPriceChip(price: lastBookmarked) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            viewModel.clearBookmark()
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            inputZone.padding()
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .simultaneousGesture(modeSwipe)
        .onAppear { viewModel.attach(modelContext: modelContext) }
        .onChange(of: viewModel.settleTick) {
            viewModel.recordSettledObservation(for: selectedItem)
        }
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

    @ViewBuilder
    private var inputZone: some View {
        switch mode {
        case .type:
            VStack {
                CheckFieldsView(
                    viewModel: viewModel,
                    selectedItemName: selectedItem?.name,
                    isShowingItemPicker: $isShowingItemPicker
                )
                KeypadView(viewModel: viewModel, onBookmark: viewModel.bookmarkCurrentPrice)
            }
            .transition(.move(edge: .leading).combined(with: .opacity))
        case .scan:
            ScanModeView(onCandidate: viewModel.applyScannedEntry)
                .transition(.move(edge: .trailing).combined(with: .opacity))
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

#Preview {
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
    return CheckView()
        .modelContainer(container)
}
