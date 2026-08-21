import Foundation
import OSLog
import SwiftData

/// Owns keypad entry state and the verdict-settle debounce. Numeral output stays live on every
/// keystroke; only the word, colour and haptic wait out the settle pause.
@MainActor
@Observable
final class CheckViewModel {
    enum Field {
        case price
        case amount
    }

    static let amountUnits: [MeasureUnit] = [
        .gram, .kilogram, .pound, .ounce, .millilitre, .litre, .each,
    ]

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
    /// Held by identity rather than as a live object: SwiftData object references do not react to
    /// deletion, so the view resolves the item from its `@Query` and a deleted row resolves to `nil`.
    var selectedItemID: PersistentIdentifier? {
        didSet { scheduleSettle() }
    }
    private(set) var focusedField: Field = .price
    private(set) var isEditingFresh = true

    private(set) var isSettled = true
    private(set) var settledPrice: NormalizedPrice?
    private(set) var settleTick = 0

    private(set) var lastBookmarked: NormalizedPrice?

    private var settleTask: Task<Void, Never>?
    private var acceleratingClearTask: Task<Void, Never>?
    private var deleteWasLongPress = false
    private var modelContext: ModelContext?
    private var lastRecordedSignature: String?

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.amountUnitDefaultsKey),
            let unit = MeasureUnit(rawValue: raw), Self.amountUnits.contains(unit)
        {
            amountUnit = unit
        } else {
            amountUnit = .gram
        }
    }

    func attach(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    var priceValue: Double? { Double(priceText) }
    var amountValue: Double? { Double(amountText) }

    var normalizedPrice: NormalizedPrice? {
        guard let priceValue, let amountValue else { return nil }
        return NormalizedPrice(money: priceValue, quantity: amountValue, unit: amountUnit)
    }

    var hasEnoughInput: Bool { normalizedPrice != nil }

    func focus(_ field: Field) {
        focusedField = field
        isEditingFresh = true
    }

    func inputDigit(_ digit: String) {
        setFocusedText(Self.appending(digit, to: consumeFreshBase()))
    }

    func inputDecimalPoint() {
        setFocusedText(Self.appending(".", to: consumeFreshBase()))
    }

    func backspace() {
        isEditingFresh = false
        var text = focusedText
        if !text.isEmpty { text.removeLast() }
        setFocusedText(text)
    }

    func clearFocusedField() {
        isEditingFresh = false
        setFocusedText("")
    }

    private func consumeFreshBase() -> String {
        guard isEditingFresh else { return focusedText }
        isEditingFresh = false
        return ""
    }

    func deleteKeyPressStarted() {
        deleteWasLongPress = false
    }

    func deleteKeyLongPressRecognized() {
        deleteWasLongPress = true
        startAcceleratingClear()
    }

    func deleteKeyPressEnded() {
        acceleratingClearTask?.cancel()
        acceleratingClearTask = nil
        if !deleteWasLongPress {
            backspace()
        }
    }

    /// A throwaway reference for comparison shopping, deliberately independent of the good-price
    /// baseline and needing no selected item.
    func bookmarkCurrentPrice() {
        guard let normalizedPrice else { return }
        lastBookmarked = normalizedPrice
    }

    func clearBookmark() {
        lastBookmarked = nil
    }

    func updateGoodPrice(for item: GroceryItem) {
        guard let normalizedPrice, let modelContext else { return }
        item.goodPriceCanonical = normalizedPrice.canonical
        item.dimension = normalizedPrice.dimension
        item.userModified = true
        item.updatedAt = .now
        try? modelContext.save()
        settle()
    }

    func saveAsGoodPrice(named name: String) {
        guard let normalizedPrice, let modelContext else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = GroceryItem(
            name: trimmed.isEmpty ? "Untitled item" : trimmed,
            goodPriceCanonical: normalizedPrice.canonical,
            dimension: normalizedPrice.dimension,
            userModified: true
        )
        modelContext.insert(item)
        try? modelContext.save()
        selectedItemID = item.persistentModelID
        settle()
    }

    /// Fills the fields and lets the normal settle run, so a scan reaches the verdict by the same
    /// path as a typed price. A tag that yielded only a price leaves the amount and unit alone.
    func applyScannedEntry(_ candidate: ScanCandidate) {
        priceText = Self.priceText(candidate.price)
        if let amount = candidate.amount, let unit = candidate.unit {
            amountText = Self.amountText(amount)
            amountUnit = unit
        }
        focusedField = .price
        isEditingFresh = true
        scheduleSettle()
        Log.check.info(
            "scanned entry: \(self.priceText, privacy: .public) per \(self.amountText, privacy: .public) \(self.amountUnit.rawValue, privacy: .public)"
        )
    }

    private static func priceText(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.2f", value)
    }

    /// A net weight carries three decimals — `1.528 kg` — and rounding it to two moves the unit
    /// price it produces.
    private static func amountText(_ value: Double) -> String {
        guard value != value.rounded() else { return String(Int(value)) }
        var text = String(format: "%.3f", value)
        while text.hasSuffix("0") { text.removeLast() }
        return text
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
        acceleratingClearTask?.cancel()
        acceleratingClearTask = Task { @MainActor [weak self] in
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
        settleTask?.cancel()
        isSettled = true
        settledPrice = normalizedPrice
        settleTick &+= 1
    }

    /// Records the settled check against its item so a future per-item trend has history. The view
    /// supplies the item it resolved from its `@Query`, or `nil` when nothing is selected.
    func recordSettledObservation(for item: GroceryItem?) {
        guard let settledPrice, let item, let modelContext,
            !item.isDeleted, item.dimension == settledPrice.dimension
        else { return }
        let cents = Int((settledPrice.canonical * 100).rounded())
        let signature = "\(ObjectIdentifier(item))-\(cents)"
        guard signature != lastRecordedSignature else { return }
        lastRecordedSignature = signature
        let observation = PriceObservation(
            priceCanonical: settledPrice.canonical,
            date: .now,
            source: .keypad,
            item: item
        )
        modelContext.insert(observation)
        try? modelContext.save()
    }
}
