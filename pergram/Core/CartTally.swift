import Foundation

nonisolated struct CartLine: Equatable, Sendable {
    let price: Double
    let quantity: Double
    let verdict: Verdict?

    var total: Double { price * quantity }
}

/// What the cart adds up to. A sum of what was checked, not a receipt: tax, deposits and weighing at
/// the till are deliberately absent.
nonisolated struct CartTally: Equatable, Sendable {
    let total: Double
    let count: Int
    let good: Int
    let meh: Int
    let bad: Int

    init(_ lines: [CartLine]) {
        total = lines.reduce(0) { $0 + $1.total }
        count = lines.count
        good = lines.count { $0.verdict == .good }
        meh = lines.count { $0.verdict == .meh }
        bad = lines.count { $0.verdict == .bad }
    }
}
