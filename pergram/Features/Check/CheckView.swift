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
    @Environment(\.scenePhase) private var scenePhase
    @Query private var items: [GroceryItem]
    @State private var viewModel = CheckViewModel()
    /// Owned here, not by `ScanModeView`, so the session's lifetime follows the selected mode rather
    /// than the appearance of a view the layout may build more than once.
    @State private var scanModel = ScanModel()
    @State private var mode: CheckInputMode = .type
    /// Recorded by whichever candidate actually renders, so scan matches the typing layout's
    /// proportions exactly rather than arriving at its own and jumping on the way in.
    @State private var tier: CheckTier = .roomy
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
        // Only the typing layout is measured. It is the one with a fixed-height keypad, so it is the
        // one that needs a guarantee that it fits rather than an assumption that it will.
        //
        // Scan is a sibling, never a candidate: choosing between candidates means building each of
        // them, and a capture session must not be constructed or torn down as part of layout.
        Group {
            switch mode {
            case .type:
                ViewThatFits(in: .vertical) {
                    typeLayout(.spacious)
                    typeLayout(.roomy)
                    typeLayout(.compact)
                }
            case .scan:
                content(metrics: tier.metrics) {
                    ScanModeView(model: scanModel)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        // A keypad is a fixed canvas: past this size the keys and the hero grow faster than the
        // screen can give, and the bottom row is what falls off. Digits gain nothing from the
        // accessibility sizes anyway, which is why the system keypads bound themselves the same way.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .simultaneousGesture(modeSwipe)
        .onAppear {
            viewModel.attach(modelContext: modelContext)
            scanModel.onCandidate = viewModel.applyScannedEntry
        }
        .onChange(of: mode) { _, newMode in
            // Outside the animation transaction: starting a session re-renders, and doing that
            // inside the swipe's animation makes the transition stutter.
            Task { @MainActor in
                if newMode == .scan { scanModel.start() } else { scanModel.stop() }
            }
        }
        // Only `.background` stops the session. `.inactive` also fires for the permission alert,
        // Control Centre and the notification shade, none of which are worth a teardown.
        .onChange(of: scenePhase) { _, phase in
            guard mode == .scan else { return }
            switch phase {
            case .active: scanModel.start()
            case .background: scanModel.stop()
            default: break
            }
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

    /// The chrome both modes share: the toggle, the readout, and whatever the mode puts below it.
    private func content<Input: View>(
        metrics: CheckMetrics,
        @ViewBuilder input: () -> Input
    ) -> some View {
        VStack(spacing: metrics.stackSpacing) {
            // The mode branch replaces this whole column, so without these the toggle and the
            // readout crossfade on every swipe even though they render identically either side.
            ModeBubble(mode: $mode)
                .transition(.identity)

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
            .transition(.identity)

            Spacer(minLength: 0)

            input()
                .padding(metrics.contentPadding)
        }
    }

    private func typeLayout(_ candidate: CheckTier) -> some View {
        content(metrics: candidate.metrics) {
            typeInput(metrics: candidate.metrics)
                .transition(.move(edge: .leading).combined(with: .opacity))
        }
        .onAppear {
            if tier != candidate { tier = candidate }
        }
    }

    private func typeInput(metrics: CheckMetrics) -> some View {
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
