import Foundation

/// Converts a quantity between mass units by walking a graph of conversion edges.
///
/// Units are nodes and conversions are bidirectional weighted edges anchored on grams.
/// Resolution is a breadth-first search that multiplies edge weights along the path — overkill
/// for six units on purpose, so adding volume (mL, L, per-100mL) later is a new node and edge
/// rather than a rewrite.
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
        // A second component, anchored on millilitres. Nothing links it to grams, so a search
        // across the two returns nil — which is the guard against comparing volume to mass.
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
