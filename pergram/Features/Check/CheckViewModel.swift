import Foundation
import SwiftData

/// Owns keypad entry state and the verdict-settle debounce. Numeral output stays live on every
/// keystroke; only the word/color/haptic wait out the settle pause, per the design doc's "no
/// stale verdicts, ever" rule.
@MainActor
@Observable
final class CheckViewModel {
    enum Field {
        case price
        case amount
    }

    private static let amountUnitDefaultsKey = "checkAmountUnit"
    private static let settleDelayNanoseconds: UInt64 = 350_000_000

    private(set) var priceText = ""
    private(set) var amountText = ""
    var amountUnit: MeasureUnit {
        didSet {
            UserDefaults.standard.set(amountUnit.rawValue, forKey: Self.amountUnitDefaultsKey)
            scheduleSettle()
        }
    }
    var quantityCount = 1 {
        didSet { scheduleSettle() }
    }
    var selectedItem: GroceryItem? {
        didSet { scheduleSettle() }
    }
    var focusedField: Field = .price

    private(set) var isSettled = true
    private(set) var settledVerdict: Verdict?
    private(set) var settleTick = 0

    private var settleTask: Task<Void, Never>?
    private var deleteRollbackTask: Task<Void, Never>?
    private var deleteWasLongPress = false
    private var modelContext: ModelContext?
    private var lastRecordedSignature: String?

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.amountUnitDefaultsKey),
            let unit = MeasureUnit(rawValue: raw)
        {
            amountUnit = unit
        } else {
            amountUnit = .per100Grams
        }
    }

    func attach(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    var priceValue: Double? { Double(priceText) }
    var amountValue: Double? { Double(amountText) }

    var rate: Rate? {
        guard let priceValue, priceValue > 0, quantityCount > 0 else { return nil }
        guard let amountValue, amountValue > 0 else { return nil }
        return Rate(
            money: priceValue / Double(quantityCount), quantity: amountValue, unit: amountUnit)
    }

    var pricePer100g: Double? { rate?.pricePer100g }

    var hasEnoughInput: Bool { pricePer100g != nil }

    var liveVerdict: Verdict? {
        guard let pricePer100g else { return nil }
        return VerdictEngine.evaluate(
            pricePer100g: pricePer100g,
            baselinePer100g: selectedItem?.goodPricePer100g
        )
    }

    func inputDigit(_ digit: String) {
        setFocusedText(Self.appending(digit, to: focusedText))
    }

    func inputDecimalPoint() {
        setFocusedText(Self.appending(".", to: focusedText))
    }

    func backspace() {
        var text = focusedText
        if !text.isEmpty { text.removeLast() }
        setFocusedText(text)
    }

    func deleteKeyPressStarted() {
        deleteWasLongPress = false
    }

    func deleteKeyLongPressRecognized() {
        deleteWasLongPress = true
        startAcceleratingClear()
    }

    func deleteKeyPressEnded() {
        deleteRollbackTask?.cancel()
        deleteRollbackTask = nil
        if !deleteWasLongPress {
            backspace()
        }
    }

    func saveAsGoodPrice(named name: String) {
        guard let pricePer100g, let modelContext else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = GroceryItem(
            name: trimmed.isEmpty ? "Untitled item" : trimmed,
            goodPricePer100g: pricePer100g,
            userModified: true
        )
        modelContext.insert(item)
        try? modelContext.save()
        selectedItem = item
    }

    private var focusedText: String {
        switch focusedField {
        case .price: return priceText
        case .amount: return amountText
        }
    }

    private func setFocusedText(_ text: String) {
        switch focusedField {
        case .price: priceText = text
        case .amount: amountText = text
        }
        scheduleSettle()
    }

    private static func appending(_ token: String, to text: String) -> String {
        if token == "." {
            guard !text.contains(".") else { return text }
            return text.isEmpty ? "0." : text + "."
        }
        guard text.count < 7 else { return text }
        if text == "0" { return token }
        return text + token
    }

    private func startAcceleratingClear() {
        deleteRollbackTask?.cancel()
        deleteRollbackTask = Task { @MainActor [weak self] in
            var delay: UInt64 = 55_000_000
            while true {
                guard let self, !Task.isCancelled else { return }
                if self.focusedText.isEmpty { return }
                self.backspace()
                try? await Task.sleep(nanoseconds: delay)
                delay = max(12_000_000, delay * 7 / 10)
            }
        }
    }

    private func scheduleSettle() {
        isSettled = false
        settleTask?.cancel()
        settleTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Self.settleDelayNanoseconds)
            guard let self, !Task.isCancelled else { return }
            self.settle()
        }
    }

    private func settle() {
        isSettled = true
        settledVerdict = liveVerdict
        settleTick &+= 1
        recordObservationIfNeeded()
    }

    /// Only matched checks are recorded, and identical consecutive settles are skipped: history
    /// exists to feed a future per-item trend, so unmatched or partial-entry values are noise.
    private func recordObservationIfNeeded() {
        guard let pricePer100g, let selectedItem, let modelContext else { return }
        let cents = Int((pricePer100g * 100).rounded())
        let signature = "\(selectedItem.persistentModelID.hashValue)-\(cents)"
        guard signature != lastRecordedSignature else { return }
        lastRecordedSignature = signature
        let observation = PriceObservation(
            pricePer100g: pricePer100g,
            date: .now,
            source: .keypad,
            item: selectedItem
        )
        modelContext.insert(observation)
        try? modelContext.save()
    }
}
