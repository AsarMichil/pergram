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

    /// Scan is never measured by `ViewThatFits` — the viewfinder is sized from the canvas instead,
    /// so nothing checks at runtime that its column fits. Heights below the shortest canvas the
    /// layout is drawn for clamp to the same metrics, so they are held to that floor.
    @Test func theViewfinderNeverPushesTheScanColumnPastTheCanvas() {
        for height in Self.heights {
            let metrics = CheckMetrics.tier(forCanvas: height).metrics
            let viewfinder = metrics.viewfinderHeight(inCanvas: height)
            let readout =
                metrics.wordHeight + metrics.heroHeight + metrics.comparisonHeight
                + metrics.readoutRowGap * 2
            let chrome = CheckMetrics.modeBubbleHeight + readout
            let spacing = metrics.stackSpacing * 4 + metrics.contentPadding * 2
            let column = chrome + spacing + viewfinder + CheckMetrics.captionAllowance
            // Below the shortest canvas the viewfinder holds its floor instead of vanishing, so the
            // column is allowed to exceed a height the layout was never drawn for.
            #expect(column <= max(height, 560), "scan column \(column)pt at height \(height)")
        }
    }

    @Test func theViewfinderKeepsAUsableFloorOnAnyCanvas() {
        for height in Self.heights {
            let metrics = CheckMetrics.tier(forCanvas: height).metrics
            #expect(metrics.viewfinderHeight(inCanvas: height) >= 220)
        }
    }

    /// Layout no longer measures, so nothing at runtime will notice a tier that outgrew the canvas
    /// it was sampled for. This is the check that would.
    @Test func everyTierFitsTheCanvasItWasSampledFor() {
        let designs: [(CheckTier, CGFloat)] = [(.compact, 560), (.roomy, 685), (.spacious, 810)]
        for (tier, canvas) in designs {
            #expect(
                tier.metrics.requiredHeight <= canvas,
                "\(tier) needs \(tier.metrics.requiredHeight)pt of \(canvas)pt"
            )
        }
    }

    @Test func aCanvasTakesTheMostGenerousTierItCanHold() {
        #expect(CheckMetrics.tier(forCanvas: 810) == .spacious)
        #expect(CheckMetrics.tier(forCanvas: 685) == .roomy)
        #expect(CheckMetrics.tier(forCanvas: 560) == .compact)
    }

    /// Below the shortest canvas there is nothing smaller to fall back to, so compact has to hold.
    @Test func animpossiblyShortCanvasStillResolves() {
        for height in [CGFloat(0), 100, 300, .nan] {
            #expect(CheckMetrics.tier(forCanvas: height) == .compact)
        }
    }

    @Test func aTallerCanvasNeverPicksASmallerTier() {
        var previous = CheckTier.compact
        for height in stride(from: 400.0, through: 1000.0, by: 5.0) {
            let tier = CheckMetrics.tier(forCanvas: CGFloat(height))
            let order: [CheckTier] = [.compact, .roomy, .spacious]
            #expect(
                order.firstIndex(of: tier)! >= order.firstIndex(of: previous)!,
                "went backwards at \(height)"
            )
            previous = tier
        }
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
