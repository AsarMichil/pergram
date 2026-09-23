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
        // The column is written once and only its input swaps. When the mode branch sat above the
        // shared chrome the two modes were separate identities, so every swipe destroyed and rebuilt
        // the readout — and rebuilding it inside the swipe's animation is what made the verdict jump.
        //
        // The tier is computed from the canvas rather than measured. Measuring meant building each
        // candidate, which is what duplicated the chrome in the first place, and would also have
        // built the camera preview speculatively.
        GeometryReader { proxy in
            let metrics = CheckMetrics.tier(forCanvas: proxy.size.height).metrics
            let viewfinderHeight = metrics.viewfinderHeight(inCanvas: proxy.size.height)
            // The card fills the width it is given, so its shape varies by device. Vision crops to
            // whatever the card does not show, so it has to be told the shape it came out as.
            let viewfinderRatio =
                (proxy.size.width - metrics.contentPadding * 2) / viewfinderHeight

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

                inputZone(metrics: metrics, viewfinderHeight: viewfinderHeight)
                    .padding(metrics.contentPadding)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .onChange(of: viewfinderRatio, initial: true) { _, ratio in
                scanModel.setPreviewAspectRatio(ratio)
            }
        }
        // A keypad is a fixed canvas: past this size the keys and the hero grow faster than the
        // screen can give, and the bottom row is what falls off. Digits gain nothing from the
        // accessibility sizes anyway, which is why the system keypads bound themselves the same way.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
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

    /// Only this swaps between modes, so the toggle and the readout above it keep their identity and
    /// nothing animates that the user did not ask to change.
    @ViewBuilder
    private func inputZone(metrics: CheckMetrics, viewfinderHeight: CGFloat) -> some View {
        switch mode {
        case .type:
            typeInput(metrics: metrics)
                .transition(.move(edge: .leading).combined(with: .opacity))
        case .scan:
            ScanModeView(model: scanModel, viewfinderHeight: viewfinderHeight)
                .transition(.move(edge: .trailing).combined(with: .opacity))
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
