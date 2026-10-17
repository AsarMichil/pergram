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
        didSet {
            itemLeavesWithThisPrice = false
            scheduleSettle()
        }
    }
    /// Set once the price is in the cart: the item stays while its verdict is on screen and lets go
    /// when the next price starts, so that price is not judged against the last thing bought.
    private var itemLeavesWithThisPrice = false
    private(set) var focusedField: Field = .price
    private(set) var isEditingFresh = true

    private(set) var isSettled = true
    private(set) var settledPrice: NormalizedPrice?
    private(set) var settleTick = 0

    private(set) var lastBookmarked: NormalizedPrice?

    private(set) var cartTick = 0

    private var settleTask: Task<Void, Never>?
    private var acceleratingClearTask: Task<Void, Never>?
    private var deleteWasLongPress = false
    private var modelContext: ModelContext?
    private var lastCheckSignature: String?
    private var inputSource: CheckSource = .keypad
    /// Off for the good-price sheet, whose calculator defines a baseline rather than checking one.
    var recordsChecks = true

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

    /// A price alone is enough: it goes in the cart as "Item N", without a verdict.
    var canAddToCart: Bool { (priceValue ?? 0) > 0 }

    func focus(_ field: Field) {
        focusedField = field
        isEditingFresh = true
    }

    func inputDigit(_ digit: String) {
        setFocusedText(Self.appending(digit, to: consumeFreshBase()))
        if focusedField == .price && Self.hasCents(priceText) { focus(.amount) }
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

    /// Starting a new price is the moment the last one was checked and moved on from.
    private func consumeFreshBase() -> String {
        guard isEditingFresh else { return focusedText }
        if focusedField == .price {
            commitCheck()
            releaseCartedItem()
        }
        isEditingFresh = false
        inputSource = .keypad
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
    /// baseline and needing no selected item. Not price history: a bookmark is a glance, and only a
    /// price acted on — bought or made the good price — is kept against the item.
    func bookmarkCurrentPrice(for item: GroceryItem?) {
        guard let normalizedPrice else { return }
        lastBookmarked = normalizedPrice
        commitCheck()
    }

    /// The entry stays on screen so its verdict does not vanish; the next digit starts a new price.
    /// Its price becomes history when the trip is finished, once the cart has been reviewed.
    func addToCart(item: GroceryItem?) {
        guard let priceValue, priceValue > 0, let modelContext else { return }
        Shopping.addToCart(
            price: priceValue, unitPrice: normalizedPrice, item: item, in: modelContext)
        commitCheck()
        focusedField = .price
        isEditingFresh = true
        itemLeavesWithThisPrice = true
        cartTick &+= 1
    }

    private func releaseCartedItem() {
        if itemLeavesWithThisPrice { selectedItemID = nil }
    }

    func clearBookmark() {
        lastBookmarked = nil
    }

    func updateGoodPrice(for item: GroceryItem) {
        guard let normalizedPrice, let modelContext else { return }
        item.setGoodPrice(normalizedPrice)
        item.userModified = true
        item.updatedAt = .now
        modelContext.insert(
            PriceObservation(price: normalizedPrice, reason: .goodPrice, item: item))
        try? modelContext.save()
        settle()
    }

    func saveAsGoodPrice(named name: String) {
        guard let modelContext else { return }
        saveAsGoodPrice(for: ItemIdentity.item(named: name, in: modelContext))
    }

    /// Sets the price on screen as the item's good price and selects it, so the verdict that
    /// follows is judged against what was just saved.
    func saveAsGoodPrice(for item: GroceryItem) {
        guard normalizedPrice != nil, modelContext != nil else { return }
        selectedItemID = item.persistentModelID
        updateGoodPrice(for: item)
    }

    /// Fills the fields and lets the normal settle run, so a scan reaches the verdict by the same
    /// path as a typed price. A tag that yielded only a price leaves the amount and unit alone.
    func applyScannedEntry(_ candidate: ScanCandidate) {
        commitCheck()
        releaseCartedItem()
        inputSource = .scan
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

    /// A shelf price never runs past cents, so the second one finishes it.
    private static func hasCents(_ text: String) -> Bool {
        guard let point = text.firstIndex(of: ".") else { return false }
        return text[text.index(after: point)...].count == 2
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

    /// Keeps the price on screen as one check, once. Called when the shopper moves on from it —
    /// starts the next price, scans another tag, bookmarks, adds to the cart or leaves the app — so
    /// the pauses while typing one price do not each count as a check.
    func commitCheck() {
        guard recordsChecks, let modelContext, let normalizedPrice else { return }
        // `registeredModel`, not `model(for:)`: the latter hands back an invalidated instance for an
        // identifier it cannot find, which traps the moment it is read.
        let item: GroceryItem? = selectedItemID.flatMap { modelContext.registeredModel(for: $0) }
        let cents = Int((normalizedPrice.canonical * 100).rounded())
        let signature =
            "\(item.map { "\($0.persistentModelID)" } ?? "-")-\(normalizedPrice.dimension.rawValue)-\(cents)"
        guard signature != lastCheckSignature else { return }
        lastCheckSignature = signature
        modelContext.insert(
            PriceCheck(
                price: normalizedPrice,
                verdict: item?.verdict(for: normalizedPrice),
                source: inputSource,
                itemName: item?.name
            ))
        try? modelContext.save()
    }
}
