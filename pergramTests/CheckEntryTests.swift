import Testing

@testable import pergram

@MainActor
struct CheckEntryTests {
    private let viewModel = CheckViewModel()

    private func type(_ keys: String) {
        for key in keys {
            if key == "." {
                viewModel.inputDecimalPoint()
            } else {
                viewModel.inputDigit(String(key))
            }
        }
    }

    @Test func theSecondCentMovesOnToTheAmount() {
        type("3.99")

        #expect(viewModel.focusedField == .amount)

        type("680")

        #expect(viewModel.priceText == "3.99")
        #expect(viewModel.amountText == "680")
    }

    @Test func aWholeDollarPriceStaysOnThePrice() {
        type("12")

        #expect(viewModel.focusedField == .price)
        #expect(viewModel.priceText == "12")
    }

    @Test func oneCentDigitStaysOnThePrice() {
        type("3.9")

        #expect(viewModel.focusedField == .price)
    }

    @Test func amountsTakeAsManyDecimalsAsTheyNeed() {
        viewModel.focus(.amount)
        type("1.528")

        #expect(viewModel.focusedField == .amount)
        #expect(viewModel.amountText == "1.528")
    }
}
