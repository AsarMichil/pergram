import SwiftUI

struct VerdictPanelView<UnitRowLeading: View>: View {
    let entered: NormalizedPrice?
    let baseline: NormalizedPrice?
    let settledVerdict: Verdict?
    let isSettled: Bool
    let hasEnoughInput: Bool
    let settleTick: Int
    var onSaveAsGoodPrice: () -> Void
    @ViewBuilder var unitRowLeading: UnitRowLeading

    @AppStorage("checkDisplayUnit") private var displayUnitRaw = MeasureUnit.per100Grams.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var storedUnit: MeasureUnit { MeasureUnit(rawValue: displayUnitRaw) ?? .per100Grams }
    private var enteredDimension: PriceDimension { entered?.dimension ?? .mass }

    private var displayUnit: MeasureUnit {
        PriceDisplay.displayUnit(for: enteredDimension, preferred: storedUnit)
    }

    private var baselineUnit: MeasureUnit {
        PriceDisplay.displayUnit(for: baseline?.dimension ?? .mass, preferred: storedUnit)
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

    private var neutralColor: Color {
        .secondary
    }

    var body: some View {
        VStack {
            verdictWordRow
                .frame(height: 34)
            Text(displayValue, format: .currency(code: "CAD"))
                .font(.system(size: 64, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(
                    reduceMotion
                        ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.8),
                    value: displayValue
                )
                .minimumScaleFactor(0.2)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 78, alignment: .top)
                .padding(.horizontal)
            unitRow
            contextSlot
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(trigger: settleTick) { _, _ in
            guard isSettled, hasEnoughInput else { return nil }
            return .impact(weight: .light)
        }
    }

    @ViewBuilder
    private var verdictWordRow: some View {
        if !hasEnoughInput {
            Label("ENTER A PRICE", systemImage: "circle.dashed")
                .font(.title3.bold())
                .tracking(2)
                .foregroundStyle(neutralColor)
        } else if !isSettled {
            Label("CHECKING", systemImage: "circle.dashed")
                .font(.title2.bold())
                .tracking(2)
                .foregroundStyle(neutralColor)
                .transition(.opacity)
        } else if let settledVerdict {
            Label(settledVerdict.word, systemImage: settledVerdict.symbolName)
                .font(.title2.bold())
                .tracking(2)
                .foregroundStyle(settledVerdict.color)
                .scaleEffect(isSettled ? 1 : 1.03)
                .animation(
                    reduceMotion
                        ? .easeInOut(duration: 0.2)
                        : .spring(response: 0.35, dampingFraction: 0.55), value: settleTick
                )
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale))
        } else if dimensionMismatch {
            Label("DIFFERENT UNIT", systemImage: "exclamationmark.triangle")
                .font(.title2.bold())
                .tracking(2)
                .foregroundStyle(neutralColor)
                .transition(.opacity)
        } else {
            Label("NO BASELINE", systemImage: "questionmark.circle")
                .font(.title2.bold())
                .tracking(2)
                .foregroundStyle(neutralColor)
                .transition(.opacity)
        }
    }

    private var unitRow: some View {
        HStack {
            unitRowLeading
            Spacer()
            unitCycleButton
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var unitCycleButton: some View {
        Button {
            withAnimation(
                reduceMotion
                    ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.8)
            ) {
                displayUnitRaw =
                    PriceDisplay.next(after: displayUnit, in: enteredDimension).rawValue
            }
        } label: {
            Text(PriceDisplay.suffix(for: displayUnit))
                .font(.subheadline.weight(.semibold))
                .contentTransition(reduceMotion ? .opacity : .numericText())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .disabled(!canCycleUnit)
        .sensoryFeedback(.selection, trigger: displayUnitRaw)
    }

    private var contextSlot: some View {
        VStack(spacing: 4) {
            if !hasEnoughInput {
                EmptyView()
            } else if let baseline {
                Text(
                    "your good price: \(PriceDisplay.value(baseline, in: baselineUnit), format: .currency(code: "CAD"))\(PriceDisplay.suffix(for: baselineUnit))"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                saveLink("Update good price")
            } else {
                saveLink("Set as my good price")
            }
        }
        .frame(height: 40)
    }

    private func saveLink(_ title: String) -> some View {
        Button(title, action: onSaveAsGoodPrice)
            .font(.footnote.weight(.semibold))
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
    }
}

#Preview("Good") {
    VerdictPanelView(
        entered: NormalizedPrice(dimension: .mass, canonical: 1.05),
        baseline: NormalizedPrice(dimension: .mass, canonical: 1.10),
        settledVerdict: .good,
        isSettled: true,
        hasEnoughInput: true,
        settleTick: 1,
        onSaveAsGoodPrice: {}
    ) {
        Text("leading slot").font(.caption).foregroundStyle(.secondary)
    }
}

#Preview("Count") {
    VerdictPanelView(
        entered: NormalizedPrice(dimension: .count, canonical: 0.42),
        baseline: NormalizedPrice(dimension: .count, canonical: 0.50),
        settledVerdict: .good,
        isSettled: true,
        hasEnoughInput: true,
        settleTick: 1,
        onSaveAsGoodPrice: {}
    ) {
        EmptyView()
    }
}

#Preview("Empty") {
    VerdictPanelView(
        entered: nil,
        baseline: nil,
        settledVerdict: nil,
        isSettled: true,
        hasEnoughInput: false,
        settleTick: 0,
        onSaveAsGoodPrice: {}
    ) {
        EmptyView()
    }
}
