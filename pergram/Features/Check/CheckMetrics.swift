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
/// Derived from the height actually available rather than picked from a set of candidates. Choosing
/// between candidates means building each one to size it, which is harmless for a keypad and not at
/// all harmless for a camera preview. Scaling continuously also avoids the visible step that a
/// screen sitting near a threshold would otherwise land on.
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

    /// The HIG minimum touch *target*. Everything else scales; this never does.
    static let minimumKeyHeight: CGFloat = 44

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
            emphasizedFieldFont: t < 0.4 ? .title3.weight(.bold) : .title2.weight(.bold)
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
