import SwiftUI

/// Vertical sizing for the price-entry screens, which are fixed, non-scrolling columns with a keypad
/// pinned at the bottom. A screen too short for the roomy set gets the compact one, so the keypad
/// never slides under the tab bar.
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
    /// The gap above *and* below the item row — equal on both sides, so the row sits between the
    /// card and the keypad rather than being pushed against either. Deliberately narrow, and capped:
    /// spare height belongs to the readout, where a taller tier spends it on a bigger number instead
    /// of on wider whitespace. An uncapped spacer here would take the lot and strand the row.
    let itemRowGap: CGFloat
    let itemRowGapMax: CGFloat
    /// What a key *draws*. The touch target is this plus `keyTouchInset` on each side.
    let keyHeight: CGFloat
    let cardPadding: CGFloat
    let fieldPadding: CGFloat
    let fieldFont: Font
    let emphasizedFieldFont: Font

    /// The HIG minimum touch *target*. Compact trades away drawn size, never this.
    static let minimumKeyHeight: CGFloat = 44

    /// Keys draw shorter than the minimum target on a short screen and claim half the surrounding
    /// grid gap on each side for touch — so neighbouring targets meet exactly and never overlap,
    /// and the keypad costs less height than 44pt keys would.
    ///
    /// Each tier must satisfy `keyHeight + keySpacing >= minimumKeyHeight`, or this clamps and the
    /// target comes out under the minimum.
    var keyTouchInset: CGFloat {
        min(keySpacing / 2, max(0, (Self.minimumKeyHeight - keyHeight) / 2))
    }

    /// What a finger actually gets. Asserted by `CheckMetricsTests`.
    var effectiveKeyTarget: CGFloat { keyHeight + keyTouchInset * 2 }
    static let smallerMinimumKeyHeight: CGFloat = 32
    static let smallestMinimumKeyHeight: CGFloat = 28

    static let spacious = CheckMetrics(
        wordHeight: 38,
        heroFontSize: 78,
        heroHeight: 92,
        comparisonHeight: 44,
        sheetHeroFontSize: 52,
        sheetHeroHeight: 72,
        contentPadding: 20,
        stackSpacing: 10,
        keySpacing: 10,
        itemRowGap: 14,
        itemRowGapMax: 24,
        keyHeight: 48,
        cardPadding: 18,
        fieldPadding: 12,
        fieldFont: .title2.weight(.semibold),
        emphasizedFieldFont: .title.weight(.bold)
    )

    static let roomy = CheckMetrics(
        wordHeight: 34,
        heroFontSize: 64,
        heroHeight: 78,
        comparisonHeight: 40,
        sheetHeroFontSize: 44,
        sheetHeroHeight: 64,
        contentPadding: 16,
        stackSpacing: 8,
        keySpacing: 8,
        itemRowGap: 12,
        itemRowGapMax: 20,
        keyHeight: 44,
        cardPadding: 16,
        fieldPadding: 10,
        fieldFont: .title3.weight(.semibold),
        emphasizedFieldFont: .title2.weight(.bold)
    )

    static let compact = CheckMetrics(
        wordHeight: 22,
        heroFontSize: 40,
        heroHeight: 46,
        comparisonHeight: 34,
        sheetHeroFontSize: 32,
        sheetHeroHeight: 46,
        contentPadding: 8,
        stackSpacing: 2,
        keySpacing: 8,
        itemRowGap: 6,
        itemRowGapMax: 12,
        keyHeight: 36,
        cardPadding: 9,
        fieldPadding: 6,
        fieldFont: .body.weight(.semibold),
        emphasizedFieldFont: .title3.weight(.bold)
    )
}
