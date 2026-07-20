import Foundation
import Testing

@testable import pergram

struct RateTests {
    @Test func perPoundNormalizesToPer100g() throws {
        let rate = try #require(Rate(money: 4.99, quantity: 1, unit: .pound))
        #expect(abs(rate.pricePer100g - 1.1002) < 0.001)
    }

    @Test func alreadyPer100gIsUnchanged() throws {
        let rate = try #require(Rate(money: 1.10, quantity: 1, unit: .per100Grams))
        #expect(abs(rate.pricePer100g - 1.10) < 1e-9)
    }

    @Test func perKilogramNormalizesToPer100g() throws {
        let rate = try #require(Rate(money: 11.00, quantity: 1, unit: .kilogram))
        #expect(abs(rate.pricePer100g - 1.10) < 1e-9)
    }

    @Test func gramsPerDollarIsReciprocal() {
        let rate = Rate(money: 2, grams: 500)
        #expect(rate.gramsPerDollar() == 250)
    }

    @Test func zeroMoneyClampsGramsPerDollar() {
        let rate = Rate(money: 0, grams: 500)
        #expect(rate.gramsPerDollar() == 0)
    }

    @Test func zeroGramsClampsPricePer100g() {
        let rate = Rate(money: 5, grams: 0)
        #expect(rate.pricePer100g == 0)
    }

    @Test func eachUnitHasNoRate() {
        #expect(Rate(money: 5, quantity: 1, unit: .each) == nil)
    }
}
