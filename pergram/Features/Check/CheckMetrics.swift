import SwiftUI

/// The candidates a keypad layout is allowed to settle on, tallest first. Sampled from
/// `CheckMetrics.fitting(height:)` so there is still one source of truth for the numbers.
///
/// Discrete on purpose: `ViewThatFits` picking between these is what *guarantees* the column fits,
/// which interpolating from the available height only ever assumed.
enum CheckTier: CaseIterable, Equatable {
    case spacious
    case roomy
    case compact

    var metrics: CheckMetrics {
        switch self {
        case .spacious: return .spacious
        case .roomy: return .roomy
        case .compact: return .compact
        }
    }
}

/// Vertical sizing for the price-entry screens, which are fixed, non-scrolling columns with a keypad
/// pinned at the bottom.
///
/// `fitting(height:)` generates a set for any canvas, but layout does not call it directly: it picks
/// between the three sampled tiers so the column is *guaranteed* to fit rather than assumed to.
/// Scan is the exception — it cannot be measured, so it reuses the tier typing settled on.
struct CheckMetrics {
    let wordHeight: CGFloat
    let heroFontSize: CGFloat
    let heroHeight: CGFloat
    let comparisonHeight: CGFloat
    let sheetHeroFontSize: CGFloat
    let sheetHeroHeight: CGFloat
    let contentPadding: CGFloat
    let stackSpacing: CGFloat
    let keySpacing: CGFloat
    let itemRowGap: CGFloat
    let itemRowGapMax: CGFloat
    let keyHeight: CGFloat
    /// What the item row draws. It keeps a full-size target regardless — unlike the keypad it has no
    /// neighbouring gap to borrow from, so drawing smaller buys a lighter look, not height.
    let itemRowHeight: CGFloat
    let cardPadding: CGFloat
    let fieldPadding: CGFloat
    let fieldFont: Font
    let emphasizedFieldFont: Font
    /// Gap between the three readout rows.
    let readoutRowGap: CGFloat
    /// Roughly what `fieldFont` and `emphasizedFieldFont` occupy on a line. Approximate by nature —
    /// only `requiredHeight` uses them, and it carries a margin for exactly this reason.
    let fieldLineHeight: CGFloat
    let emphasizedFieldLineHeight: CGFloat

    /// The HIG minimum touch *target*. Everything else scales; this never does.
    static let minimumKeyHeight: CGFloat = 44

    /// `ModeBubble` draws a small glyph inside a full-size target, so its row is a fixed 44.
    static let modeBubbleHeight: CGFloat = 44

    /// Slack against the estimate below. Font line heights and the padding a glass button adds are
    /// decided by the system, so the sum is close rather than exact.
    private static let fitMargin: CGFloat = 24

    /// What the typing column needs, summed from its parts rather than measured.
    ///
    /// Summed, because measuring meant `ViewThatFits` building each candidate — which duplicated the
    /// shared chrome and made every mode switch recreate the readout mid-animation. Arithmetic costs
    /// exactness; `ShortScreenTests` asserts every control is still reachable, which is what catches
    /// drift if a font or a glass inset moves.
    var requiredHeight: CGFloat {
        let readout = wordHeight + heroHeight + comparisonHeight + readoutRowGap * 2
        let card =
            cardPadding * 2 + emphasizedFieldLineHeight + fieldLineHeight + fieldPadding * 4
            + stackSpacing + 1
        let keypad = keyHeight * 4 + keySpacing * 3
        // The item row draws smaller but always reserves a full target.
        let input =
            card + itemRowGap * 2 + Self.minimumKeyHeight + keypad + contentPadding * 2
        return Self.modeBubbleHeight + readout + input + stackSpacing * 4 + Self.fitMargin
    }

    /// What the caption below the viewfinder reserves, whether or not it has anything to say.
    static let captionAllowance: CGFloat = 44

    /// Never shrink the viewfinder past this, even on a canvas that cannot really spare the room —
    /// below it there is not enough of a shelf tag in frame to read.
    private static let minimumViewfinderHeight: CGFloat = 220

    /// The tallest viewfinder the canvas can hold once the rest of the scan column is paid for.
    ///
    /// Taken from the canvas rather than from the space left inside the layout: a capture preview
    /// has no intrinsic size, so a height that resolved against its content would change the moment
    /// the session replaced the placeholder.
    func viewfinderHeight(inCanvas height: CGFloat) -> CGFloat {
        guard height.isFinite, height > 0 else { return Self.minimumViewfinderHeight }
        let rest =
            Self.modeBubbleHeight + wordHeight + heroHeight + comparisonHeight + readoutRowGap * 2
            + Self.captionAllowance + contentPadding * 2 + stackSpacing * 4 + Self.fitMargin
        return max(Self.minimumViewfinderHeight, height - rest)
    }

    /// The most generous tier the canvas can hold.
    static func tier(forCanvas height: CGFloat) -> CheckTier {
        CheckTier.allCases.first { $0.metrics.requiredHeight <= height } ?? .compact
    }

    /// The heights the two ends of the scale were drawn against: roughly what an iPhone SE and an
    /// iPhone Pro Max leave once the status bar and the floating tab bar are taken out.
    private static let shortestCanvas: CGFloat = 560
    private static let tallestCanvas: CGFloat = 810

    /// Keys draw shorter than the minimum target and claim half the surrounding grid gap on each
    /// side for touch, so neighbouring targets meet exactly and never overlap.
    ///
    /// Holds only while `keyHeight + keySpacing >= minimumKeyHeight`; `fitting(height:)` guarantees
    /// that, and `CheckMetricsTests` checks it across the range.
    var keyTouchInset: CGFloat {
        min(keySpacing / 2, max(0, (Self.minimumKeyHeight - keyHeight) / 2))
    }

    /// What a finger actually gets.
    var effectiveKeyTarget: CGFloat { keyHeight + keyTouchInset * 2 }

    static func fitting(height: CGFloat) -> CheckMetrics {
        let t = progress(height)
        let keyHeight = lerp(36, 48, t)
        return CheckMetrics(
            wordHeight: lerp(22, 38, t),
            heroFontSize: lerp(40, 78, t),
            heroHeight: lerp(46, 92, t),
            comparisonHeight: lerp(34, 44, t),
            sheetHeroFontSize: lerp(32, 52, t),
            sheetHeroHeight: lerp(46, 72, t),
            contentPadding: lerp(8, 20, t),
            stackSpacing: lerp(2, 10, t),
            // Whatever the key draws, the gap has to cover the rest of the 44pt target.
            keySpacing: max(lerp(8, 10, t), minimumKeyHeight - keyHeight),
            itemRowGap: lerp(6, 14, t),
            itemRowGapMax: lerp(12, 24, t),
            keyHeight: keyHeight,
            itemRowHeight: lerp(32, 44, t),
            cardPadding: lerp(9, 18, t),
            fieldPadding: lerp(6, 12, t),
            // Stepped, not interpolated: these are Dynamic Type styles, and a fixed point size would
            // stop them responding to the user's text size at all.
            fieldFont: t < 0.4 ? .body.weight(.semibold) : .title3.weight(.semibold),
            emphasizedFieldFont: t < 0.4 ? .title3.weight(.bold) : .title2.weight(.bold),
            readoutRowGap: lerp(4, 8, t),
            fieldLineHeight: t < 0.4 ? 22 : 25,
            emphasizedFieldLineHeight: t < 0.4 ? 25 : 28
        )
    }

    /// 0 at the shortest canvas the layout supports, 1 at the tallest, clamped outside.
    private static func progress(_ height: CGFloat) -> CGFloat {
        guard height.isFinite, height > 0 else { return 0 }
        let span = tallestCanvas - shortestCanvas
        return min(max((height - shortestCanvas) / span, 0), 1)
    }

    private static func lerp(_ low: CGFloat, _ high: CGFloat, _ t: CGFloat) -> CGFloat {
        low + (high - low) * t
    }

    /// Reference points, for previews and tests rather than for layout.
    static let compact = fitting(height: shortestCanvas)
    static let roomy = fitting(height: (shortestCanvas + tallestCanvas) / 2)
    static let spacious = fitting(height: tallestCanvas)
}
