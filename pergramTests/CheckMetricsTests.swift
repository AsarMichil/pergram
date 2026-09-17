import Foundation
import Testing

@testable import pergram

/// Each tier draws its keys smaller than the touch minimum and borrows half the grid gap on either
/// side. That only works while `keyHeight + keySpacing >= minimumKeyHeight` — below it the inset
/// clamps against the gap and the target silently lands under the minimum.
@MainActor
struct CheckMetricsTests {
    private static let tiers: [(name: String, metrics: CheckMetrics)] = [
        ("spacious", .spacious), ("roomy", .roomy), ("compact", .compact),
    ]

    @Test func everyTierMeetsTheMinimumTouchTarget() {
        for (name, metrics) in Self.tiers {
            #expect(
                metrics.effectiveKeyTarget >= CheckMetrics.minimumKeyHeight,
                "\(name) key target is \(metrics.effectiveKeyTarget)pt"
            )
        }
    }

    /// Borrowing more than half the gap would make neighbouring targets overlap, so a tap landing
    /// between two keys would go to whichever happened to be hit-tested first.
    @Test func neighbouringTargetsNeverOverlap() {
        for (name, metrics) in Self.tiers {
            #expect(metrics.keyTouchInset * 2 <= metrics.keySpacing, "\(name) targets overlap")
        }
    }

    @Test func compactDrawsSmallerThanItsTarget() {
        #expect(CheckMetrics.compact.keyHeight < CheckMetrics.minimumKeyHeight)
        #expect(CheckMetrics.compact.effectiveKeyTarget == CheckMetrics.minimumKeyHeight)
    }
}
