import SwiftUI

struct VerdictPanelView: View {
    let pricePer100g: Double?
    let baselinePer100g: Double?
    let settledVerdict: Verdict?
    let isSettled: Bool
    let hasEnoughInput: Bool
    let settleTick: Int
    var onSaveAsGoodPrice: () -> Void

    @AppStorage("checkDisplayUnit") private var displayUnitRaw = MeasureUnit.per100Grams.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var displayUnit: MeasureUnit {
        MeasureUnit(rawValue: displayUnitRaw) ?? .per100Grams
    }

    private var displayValue: Double {
        guard let pricePer100g else { return 0 }
        return PriceDisplay.price(per100g: pricePer100g, in: displayUnit)
    }

    private var neutralColor: Color {
        .secondary
    }

    var body: some View {
        VStack(spacing: 12) {
            verdictWordRow
                .frame(height: 30)
            Text(displayValue, format: .currency(code: "CAD"))
                .font(.system(size: 76, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(
                    reduceMotion
                        ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.8),
                    value: displayValue
                )
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .padding(.horizontal)
            unitCycleButton
            contextSlot
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(trigger: settleTick) { _, _ in
            guard isSettled, let settledVerdict else { return nil }
            return settledVerdict.feedback
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
        } else {
            Label("NO BASELINE", systemImage: "questionmark.circle")
                .font(.title2.bold())
                .tracking(2)
                .foregroundStyle(neutralColor)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var unitCycleButton: some View {
        Button {
            withAnimation(
                reduceMotion
                    ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.8)
            ) {
                displayUnitRaw = PriceDisplay.next(after: displayUnit).rawValue
            }
        } label: {
            Text(PriceDisplay.suffix(for: displayUnit))
                .font(.subheadline.weight(.semibold))
                .contentTransition(reduceMotion ? .opacity : .numericText())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .sensoryFeedback(.selection, trigger: displayUnitRaw)
    }

    private var contextSlot: some View {
        VStack(spacing: 4) {
            if !hasEnoughInput {
                EmptyView()
            } else if let baselinePer100g {
                Text(
                    "your good price: \(PriceDisplay.price(per100g: baselinePer100g, in: displayUnit), format: .currency(code: "CAD"))\(PriceDisplay.suffix(for: displayUnit))"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                saveLink("Update good price")
            } else {
                saveLink("Set as my good price")
            }
        }
        .frame(height: 60)
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
        pricePer100g: 1.05,
        baselinePer100g: 1.10,
        settledVerdict: .good,
        isSettled: true,
        hasEnoughInput: true,
        settleTick: 1,
        onSaveAsGoodPrice: {}
    )
}

#Preview("Unmatched") {
    VerdictPanelView(
        pricePer100g: 2.20,
        baselinePer100g: nil,
        settledVerdict: nil,
        isSettled: true,
        hasEnoughInput: true,
        settleTick: 0,
        onSaveAsGoodPrice: {}
    )
}

#Preview("Empty") {
    VerdictPanelView(
        pricePer100g: nil,
        baselinePer100g: nil,
        settledVerdict: nil,
        isSettled: true,
        hasEnoughInput: false,
        settleTick: 0,
        onSaveAsGoodPrice: {}
    )
}
