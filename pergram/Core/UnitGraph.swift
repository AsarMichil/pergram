import Foundation

/// Converts a quantity between units by walking a graph of bidirectional conversion edges,
/// multiplying weights along the path.
///
/// Mass and volume are separate connected components, anchored on grams and on millilitres. A
/// search between them finds no path, which is the guard against comparing volume to mass.
nonisolated struct UnitGraph: Sendable {
    static let standard = UnitGraph()

    private struct Edge {
        let target: MeasureUnit
        let factor: Double
    }

    private let adjacency: [MeasureUnit: [Edge]]

    init() {
        var adjacency: [MeasureUnit: [Edge]] = [:]
        func link(_ a: MeasureUnit, _ b: MeasureUnit, perA factor: Double) {
            adjacency[a, default: []].append(Edge(target: b, factor: factor))
            adjacency[b, default: []].append(Edge(target: a, factor: 1 / factor))
        }
        link(.kilogram, .gram, perA: 1000)
        link(.pound, .gram, perA: 453.592)
        link(.ounce, .gram, perA: 28.3495)
        link(.per100Grams, .gram, perA: 100)
        link(.litre, .millilitre, perA: 1000)
        link(.per100Millilitres, .millilitre, perA: 100)
        self.adjacency = adjacency
    }

    /// The multiplier that converts a quantity in `source` units to `target` units, or `nil`
    /// when the units are not connected (e.g. `.each`, which carries no mass).
    func conversionFactor(from source: MeasureUnit, to target: MeasureUnit) -> Double? {
        if source == target { return 1 }
        var visited: Set<MeasureUnit> = [source]
        var queue: [(unit: MeasureUnit, factor: Double)] = [(source, 1)]
        while !queue.isEmpty {
            let (unit, factor) = queue.removeFirst()
            for edge in adjacency[unit] ?? [] where !visited.contains(edge.target) {
                let reached = factor * edge.factor
                if edge.target == target { return reached }
                visited.insert(edge.target)
                queue.append((edge.target, reached))
            }
        }
        return nil
    }

    func convert(_ value: Double, from source: MeasureUnit, to target: MeasureUnit) -> Double? {
        guard let factor = conversionFactor(from: source, to: target) else { return nil }
        return value * factor
    }
}
