import SwiftUI

struct VerdictPanelView: View {
    let entered: NormalizedPrice?
    let baseline: NormalizedPrice?
    var bookmarked: NormalizedPrice?
    let settledVerdict: Verdict?
    let isSettled: Bool
    let hasEnoughInput: Bool
    let settleTick: Int
    var metrics: CheckMetrics = .roomy
    var onClearBookmark: () -> Void = {}

    @AppStorage("checkDisplayUnit") private var displayUnitRaw = MeasureUnit.per100Grams.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var storedUnit: MeasureUnit { MeasureUnit(rawValue: displayUnitRaw) ?? .per100Grams }
    private var enteredDimension: PriceDimension { entered?.dimension ?? .mass }

    private var displayUnit: MeasureUnit {
        PriceDisplay.displayUnit(for: enteredDimension, preferred: storedUnit)
    }

    private var canCycleUnit: Bool { PriceDisplay.units(for: enteredDimension).count > 1 }

    private var displayValue: Double {
        guard let entered else { return 0 }
        return PriceDisplay.value(entered, in: displayUnit)
    }

    private var dimensionMismatch: Bool {
        guard let entered, let baseline else { return false }
        return entered.dimension != baseline.dimension
    }

    private var settleAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.8)
    }

    var body: some View {
        VStack(spacing: metrics.readoutRowGap) {
            verdictWordRow
                .frame(height: metrics.wordHeight)
            heroRow
                .frame(height: metrics.heroHeight)
            comparisonRow
                .frame(height: metrics.comparisonHeight)
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(trigger: settleTick) { _, _ in
            guard isSettled, hasEnoughInput else { return nil }
            return .impact(weight: .light)
        }
    }

    /// Empty rather than instructional before the first digit — but the row still holds its height,
    /// so the readout does not jump when the verdict arrives.
    @ViewBuilder
    private var verdictWordRow: some View {
        if !hasEnoughInput {
            Color.clear
        } else if !isSettled {
            verdictLabel("CHECKING", systemImage: "circle.dashed", color: .secondary)
                .transition(.opacity)
        } else if let settledVerdict {
            verdictLabel(
                settledVerdict.word, systemImage: settledVerdict.symbolName,
                color: settledVerdict.color
            )
            .scaleEffect(isSettled ? 1 : 1.03)
            .animation(
                reduceMotion
                    ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.55),
                value: settleTick
            )
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale))
        } else if dimensionMismatch {
            verdictLabel(
                "DIFFERENT UNIT", systemImage: "exclamationmark.triangle", color: .secondary
            )
            .transition(.opacity)
        } else {
            verdictLabel("NO BASELINE", systemImage: "questionmark.circle", color: .secondary)
                .transition(.opacity)
        }
    }

    private func verdictLabel(_ text: String, systemImage: String, color: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.title2.bold())
            .tracking(2)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    private var heroRow: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Text(PriceDisplay.money(displayValue))
                .font(.system(size: metrics.heroFontSize, weight: .black, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(settleAnimation, value: displayValue)
                .lineLimit(1)
                .minimumScaleFactor(0.3)
            unitCycleButton
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }

    private var unitCycleButton: some View {
        Button {
            withAnimation(settleAnimation) {
                displayUnitRaw =
                    PriceDisplay.next(after: displayUnit, in: enteredDimension)
                    .rawValue
            }
        } label: {
            Text(PriceDisplay.suffix(for: displayUnit))
                .font(.title3.weight(.bold))
                .contentTransition(reduceMotion ? .opacity : .numericText())
                .padding(.vertical, 11)
                .padding(.horizontal, 8)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .disabled(!canCycleUnit)
        .accessibilityLabel("Display unit \(PriceDisplay.suffix(for: displayUnit)), tap to change")
        .sensoryFeedback(.selection, trigger: displayUnitRaw)
    }

    /// The slot holds its height whether or not a price is parked. Collapsing it would shift the
    /// card, the item row and the keypad down the instant you bookmark — and because the screen
    /// picks its metrics from this layout's ideal height, it could also flip roomy to compact in the
    /// same frame.
    @ViewBuilder
    private var comparisonRow: some View {
        if let bookmarked {
            LastPriceChip(price: bookmarked, current: entered, onDelete: onClearBookmark)
        }
    }
}

private func verdictPreview(
    _ canonical: Double?,
    baseline: Double? = 1.10,
    bookmarked: Double? = nil,
    verdict: Verdict? = nil,
    isSettled: Bool = true,
    metrics: CheckMetrics = .roomy
) -> some View {
    VerdictPanelView(
        entered: canonical.map { NormalizedPrice(dimension: .mass, canonical: $0) },
        baseline: baseline.map { NormalizedPrice(dimension: .mass, canonical: $0) },
        bookmarked: bookmarked.map { NormalizedPrice(dimension: .mass, canonical: $0) },
        settledVerdict: verdict,
        isSettled: isSettled,
        hasEnoughInput: canonical != nil,
        settleTick: 1,
        metrics: metrics
    )
}

#Preview("Good") { verdictPreview(1.05, verdict: .good) }
#Preview("Meh") { verdictPreview(1.30, verdict: .meh) }
#Preview("Bad") { verdictPreview(2.40, verdict: .bad) }
#Preview("Checking") { verdictPreview(1.05, verdict: .good, isSettled: false) }
#Preview("No baseline") { verdictPreview(1.05, baseline: nil) }

/// The entered price is a count, the baseline a mass — nothing comparable between them.
#Preview("Different unit") {
    VerdictPanelView(
        entered: NormalizedPrice(dimension: .count, canonical: 0.42),
        baseline: NormalizedPrice(dimension: .mass, canonical: 1.10),
        settledVerdict: nil,
        isSettled: true,
        hasEnoughInput: true,
        settleTick: 1
    )
}

/// The word row must hold its height here, or the readout jumps on the first digit.
#Preview("Empty") { verdictPreview(nil, baseline: nil) }

#Preview("Cheaper than parked") { verdictPreview(1.05, bookmarked: 1.23, verdict: .good) }
#Preview("Pricier than parked") { verdictPreview(1.40, bookmarked: 1.23, verdict: .meh) }
#Preview("Compact") { verdictPreview(1.05, bookmarked: 1.23, verdict: .good, metrics: .compact) }
