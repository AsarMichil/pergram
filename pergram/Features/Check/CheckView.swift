import SwiftData
import SwiftUI

/// Ordered as the swipe moves through them: Shop ← Type → Scan.
nonisolated enum CheckInputMode: CaseIterable, Hashable, Sendable {
    case shop
    case type
    case scan

    var title: String {
        switch self {
        case .shop: return "Shop"
        case .type: return "Type"
        case .scan: return "Scan"
        }
    }

    var symbolName: String {
        switch self {
        case .shop: return "cart"
        case .type: return "keyboard"
        case .scan: return "camera.viewfinder"
        }
    }

    /// The neighbour a swipe lands on, or `nil` at either end.
    func swiped(forward: Bool) -> CheckInputMode? {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self) else { return nil }
        let target = forward ? index + 1 : index - 1
        return all.indices.contains(target) ? all[target] : nil
    }
}

struct CheckView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var items: [GroceryItem]
    @State private var viewModel = CheckViewModel()
    /// Owned here, not by `ScanModeView`, so the session's lifetime follows the selected mode rather
    /// than the appearance of a view the layout may build more than once.
    @State private var scanModel = ScanModel()
    @Environment(AppRouter.self) private var router
    @Query(filter: #Predicate<Trip> { !$0.isFinished }, sort: \Trip.startedAt, order: .reverse)
    private var activeTrips: [Trip]
    @State private var isShowingItemPicker = false
    @State private var isShowingSaveSheet = false

    private var mode: CheckInputMode { router.checkMode }
    private var activeTrip: Trip? { activeTrips.first }

    /// Resolved from the live `@Query`, so a deleted row becomes `nil` reactively — the fix for a
    /// stale selection is that the query, not a held reference, is the source of truth.
    private var selectedItem: GroceryItem? {
        guard let id = viewModel.selectedItemID else { return nil }
        return items.first { $0.persistentModelID == id }
    }

    /// The good price in the dimension being typed. An item with good prices only in another
    /// dimension still shows one, so the panel can say they do not compare rather than go blank.
    private var baseline: NormalizedPrice? {
        guard let selectedItem else { return nil }
        let dimension = viewModel.normalizedPrice?.dimension ?? viewModel.amountUnit.dimension
        return selectedItem.goodPrice(for: dimension) ?? selectedItem.goodPrices.first
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
                ModeBubble(
                    mode: Binding(get: { router.checkMode }, set: { router.checkMode = $0 }),
                    cartTotal: activeTrip?.tally.total
                )
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)

                if mode == .shop {
                    ShopView(trip: activeTrip, onPrice: price)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    // Shop sits left of Type, so the column always arrives from and leaves to the
                    // trailing edge. One container, so the move is the column's and not the keypad's
                    // own Scan-facing transition.
                    // A keypad is a fixed canvas: past this size the keys and the hero grow faster
                    // than the screen can give, and the bottom row is what falls off. Digits gain
                    // nothing from the accessibility sizes anyway, which is why the system keypads
                    // bound themselves the same way. Shop scrolls, so it is left unbounded.
                    priceColumn(metrics: metrics, viewfinderHeight: viewfinderHeight)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .onChange(of: viewfinderRatio, initial: true) { _, ratio in
                scanModel.setPreviewAspectRatio(ratio)
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(modeSwipe)
        .sensoryFeedback(.success, trigger: viewModel.cartTick)
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
            if phase == .background { viewModel.commitCheck() }
            if phase == .active { Shopping.finishIdleTrip(in: modelContext) }
            guard mode == .scan else { return }
            switch phase {
            case .active: scanModel.start()
            case .background: scanModel.stop()
            default: break
            }
        }
        .sheet(isPresented: $isShowingItemPicker) {
            ItemPickerSheet(
                selectedItemID: $viewModel.selectedItemID,
                listEntries: pickableListEntries
            )
        }
        .sheet(isPresented: $isShowingSaveSheet) {
            if let normalizedPrice = viewModel.normalizedPrice {
                SetGoodPriceSheet(price: normalizedPrice) { name in
                    viewModel.saveAsGoodPrice(named: name)
                }
            }
        }
    }

    /// Type and Scan share this column, so switching between them keeps the readout's identity and
    /// only the input zone swaps.
    private func priceColumn(metrics: CheckMetrics, viewfinderHeight: CGFloat) -> some View {
        VStack(spacing: metrics.stackSpacing) {
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
                },
                onSetGoodPrice: setGoodPrice
            )

            Spacer(minLength: 0)

            inputZone(metrics: metrics, viewfinderHeight: viewfinderHeight)
                .padding(metrics.contentPadding)
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
            ScanModeView(
                model: scanModel,
                viewfinderHeight: viewfinderHeight,
                selectionName: selectedItem?.name,
                canBookmark: viewModel.hasEnoughInput,
                canAddToCart: viewModel.canAddToCart,
                onBookmark: bookmark,
                onAddToCart: addToCart
            )
            .transition(.move(edge: .trailing).combined(with: .opacity))
        case .shop:
            EmptyView()
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
                onBookmark: bookmark,
                onAddToCart: addToCart,
                metrics: metrics
            )
        }
    }

    private func price(_ entry: ListEntry) {
        viewModel.selectedItemID = entry.item?.persistentModelID
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            router.checkMode = router.lastPriceMode
        }
    }

    private func bookmark() {
        viewModel.bookmarkCurrentPrice(for: selectedItem)
    }

    private func addToCart() {
        viewModel.addToCart(item: selectedItem)
    }

    /// While a list is being shopped, its uncrossed entries lead the picker.
    private var pickableListEntries: [ListEntry] {
        guard let trip = activeTrip, let list = trip.list else { return [] }
        return list.orderedEntries.filter { !trip.isCrossed($0) }
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
                guard let target = mode.swiped(forward: horizontal < 0) else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    router.checkMode = target
                }
            }
    }
}

@MainActor
private func previewContainer() -> ModelContainer {
    let container = try! ModelContainer(
        for: AppSchema.schema,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let chicken = GroceryItem(
        seedID: "chicken-thigh-boneless",
        name: "Chicken thigh (boneless)",
        aliases: ["thighs"],
        aisle: .meat,
        goodPrice: NormalizedPrice(dimension: .mass, canonical: 1.10)
    )
    container.mainContext.insert(chicken)
    let list = GroceryList(name: "Weekly")
    container.mainContext.insert(list)
    for name in ["Milk", "Paper towels"] {
        list.add(GroceryItem(name: name))
    }
    list.add(chicken)
    return container
}

#Preview("Check") {
    CheckView()
        .modelContainer(previewContainer())
        .environment(AppRouter())
}

/// The shortest supported iPhone, and the size the fixed layout has to survive.
#Preview("Check · iPhone SE (375×667)", traits: .fixedLayout(width: 375, height: 667)) {
    CheckView()
        .modelContainer(previewContainer())
        .environment(AppRouter())
}

#Preview("Check · SE + AX5 type", traits: .fixedLayout(width: 375, height: 667)) {
    CheckView()
        .modelContainer(previewContainer())
        .environment(AppRouter())
        .environment(\.dynamicTypeSize, .accessibility5)
}
