import Foundation
import Testing

@testable import pergram

/// Keys draw smaller than the touch minimum and borrow half the grid gap on either side. That only
/// holds while `keyHeight + keySpacing >= minimumKeyHeight`; below it the inset clamps against the
/// gap and the target silently lands under the minimum. Sizing is continuous now, so this has to be
/// true across the range rather than at a few chosen points.
@MainActor
struct CheckMetricsTests {
    /// Well past both ends, so the clamping is covered too.
    private static let heights: [CGFloat] = stride(from: 300.0, through: 1200.0, by: 10.0).map {
        CGFloat($0)
    }

    @Test func everyHeightMeetsTheMinimumTouchTarget() {
        for height in Self.heights {
            let metrics = CheckMetrics.fitting(height: height)
            #expect(
                metrics.effectiveKeyTarget >= CheckMetrics.minimumKeyHeight,
                "target \(metrics.effectiveKeyTarget)pt at height \(height)"
            )
        }
    }

    /// Borrowing more than half the gap would overlap neighbouring targets, so a tap between two
    /// keys would go to whichever was hit-tested first.
    @Test func neighbouringTargetsNeverOverlap() {
        for height in Self.heights {
            let metrics = CheckMetrics.fitting(height: height)
            #expect(
                metrics.keyTouchInset * 2 <= metrics.keySpacing,
                "targets overlap at height \(height)"
            )
        }
    }

    @Test func aShortScreenDrawsSmallerThanItsTarget() {
        let metrics = CheckMetrics.fitting(height: 560)
        #expect(metrics.keyHeight < CheckMetrics.minimumKeyHeight)
        #expect(metrics.effectiveKeyTarget >= CheckMetrics.minimumKeyHeight)
    }

    @Test func sizingGrowsWithTheHeightAvailable() {
        let short = CheckMetrics.fitting(height: 560)
        let tall = CheckMetrics.fitting(height: 810)
        #expect(tall.heroFontSize > short.heroFontSize)
        #expect(tall.keyHeight > short.keyHeight)
        #expect(tall.contentPadding > short.contentPadding)
    }

    /// A degenerate proposal must not produce a NaN that propagates into every frame.
    @Test func degenerateHeightsStayFinite() {
        for height in [CGFloat(0), -100, .infinity, .nan] {
            let metrics = CheckMetrics.fitting(height: height)
            #expect(metrics.heroFontSize.isFinite)
            #expect(metrics.keyHeight.isFinite)
            #expect(metrics.effectiveKeyTarget >= CheckMetrics.minimumKeyHeight)
        }
    }
}
