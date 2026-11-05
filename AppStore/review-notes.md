# App Review notes

Paste the block below into **App Review Information → Notes** for each submission (4000 characters
max; this is about 3950). Kept current with the app (last: 1.2.0).

```text
The app has no account registration, no login, no account deletion, no user-generated content, and no paid content or in-app purchases, so none of those flows appear.

1. Purpose and target audience

PerGram Go answers two questions a grocery shopper has: what do I need from the store, and what is a good price for what I need?

Shelf prices are not comparable as printed: a 680 g pack at $8.99 and a 1.4 kg pack at $16.49 are different prices per kilogram, and working that out in an aisle is tedious enough that most people skip it. The app converts any price to a common unit — $/100 g, or $/each for things sold by count — and compares it against a good price the user sets themselves. Grocery lists and a running cart carry that check through a shopping trip.

The audience is ordinary grocery shoppers in Canada. There is no professional or business use case.

2. Setup and access to the main features

No account, credentials or sample files are required. The app is fully functional offline from first launch.

- Type: Opens on this tab. Enter a price, tap the amount field, enter an amount, and choose a unit. The verdict appears above.
  - Tap the item row above the keypad to choose an item. A fresh install has no good prices; with an item selected, tap "Set as good price" where the verdict would be.
  - Tap the unit beside the large price to change the display unit.
- Scan: Tap "Scan" at the top of the Check screen, or swipe left. iOS asks for camera permission the first time. Point the camera at any printed price tag and the fields fill on their own. A photograph of a tag shown on another screen also works.
- Lists: Create a list with +, add items by typing, then "Shop this list" and "Start". The share button sends a copy of the list as a file.
- Shop: The leftmost mode on the Check screen. It shows the running cart and the list by aisle. "Finish trip" shows a summary.
- Items: Everything the user has added or priced, searchable. Tap one to set its good prices.
- Settings: How it works, feedback email, support page, privacy policy.

3. External services, tools and platforms

None. The app makes no network requests of any kind. No third-party SDKs, analytics, advertising, payments or backend.

Camera frames are processed in memory, on device, with Apple's Vision framework, and are never written to disk, saved to the photo library, or transmitted. The privacy manifest declares no collected data and no tracking. Sharing a list uses the system share sheet; the app itself never connects to anything.

The built-in grocery list is names and aisles only, no prices, written by the developer. Its French names were checked against Health Canada's Canadian Nutrient File (Open Government Licence – Canada), credited in Settings. Nothing comes from any retailer or data provider.

4. Regional differences

The app behaves identically in every region. There is no region detection, no geolocation, and no region-conditional code or content. This may change in a future update, but the app is based in Canada and designed for Canada.

Prices display in Canadian dollars, and the tag reader understands the bilingual English and French wording Canadian shelf tags are required to carry. Those are fixed properties of the app, not switched by region. This is why the app is only available in Canada.

5. Regulated industry and third-party material

Neither applies.

The app is a unit-price calculator. It makes no health, financial, or safety claims. A verdict is arithmetic against a number the user chose.

There is no retailer branding and no price data from anyone but the user. The only outside material is the open Government of Canada dataset above, credited as its licence requires. Scanning reads the price on a tag the user is standing in front of, the way a person reads it; nothing is retained and no retailer system is accessed.

See ScreenRecording_10-20-2026 03-10-14_1.mov attached for a usual user flow.
```

---

## Shot list for the recording

One continuous take, on a physical device, roughly 60–90 seconds. Start with the app not running.

1. Launch from the Home Screen so the recording starts cold.
2. Type a price and an amount on the keypad. Let the verdict settle.
3. Tap the item row, choose "Choose item…", pick an item, and show the verdict change against that
   item's good price.
4. Open the item row menu again and choose "Set good price to …" to show the baseline being set by
   the user.
5. Tap "Scan". Allow camera access when iOS asks — leave the permission prompt in the recording.
6. Point at a printed price tag until the fields fill on their own. Pinch to zoom once.
7. Swipe to "Type" to show the scanned values can be corrected by hand.
8. Open Lists, create a list, add two items, and tap one to add a note.
9. Tap "Shop this list", uncheck one item to skip it, then Start. Tap an item to price it and add it to the cart with the cart
   key; show it cross off.
10. Open the Shop page and tap "Finish trip" to show the summary.
11. Open Items, scroll, use the search field.
12. Back on Check, tap the unit beside the large price to cycle it.
13. Open Settings and open the privacy policy link.

Include audio narration or on-screen captions if convenient; neither is required.


---

# Archived — 1.0.1 hotfix for scan (released)

**1.0 is live with scan broken.** The Guideline 4 layout work fixed the short-screen overflow but
regressed the camera: the scan view sat inside a `ViewThatFits`, which builds every candidate in
order to measure it, so the capture session was being constructed and torn down as part of layout.
It showed as a grey, frozen viewfinder. Review approved it because reading a real shelf tag is not
something a reviewer exercises.

Ship 1.0.1 as soon as scan is confirmed working on a physical device — not before, since an
unverified fix for the one broken feature is worse than waiting.

## What to Test / release notes

> Fixes a bug where the camera scanner could show a blank viewfinder and fail to read shelf tags.
> The scanner is also larger on every screen, and the Check screen now fits smaller iPhones.

Worth requesting **expedited review**: a released app whose core feature does not work is the case
Apple's expedited process exists for. Say plainly that 1.0 shipped with the scanner inoperative and
that 1.0.1 is the fix.

## Archived — Guideline 4 reply (submission 064c76af, resolved; 1.0 approved and released)

Submission 064c76af-9fb5-46ce-b88d-a13b85d397aa, reviewed on iPad Air 11-inch.

---

Thank you for the detail in the report — it was accurate, and it led us to a real bug.

PerGram Go is an iPhone-only app, so on the review iPad it ran in iPhone compatibility mode. That
window is shorter than a modern iPhone's screen, and the Check screen was a fixed, non-scrolling
layout that assumed a tall one. It did not fit, and the overflow was resolved by clipping at both
ends: the Type/Scan control was pushed off the top of the screen, and the bottom row of the keypad —
including the button that saves a price — sat behind the tab bar where it could not be tapped.

This was not confined to iPad. The same layout also failed on iPhone SE, which has a 375 × 667 point
screen, so the problem affected iPhone users directly. We are grateful it was caught.

What has changed:

- **The Check screen now adapts to the height available**, choosing between three sets of
  proportions instead of assuming one. Verified from 375 × 667 (iPhone SE) to 440 × 956
  (iPhone 17 Pro Max), and in iPhone compatibility mode on iPad Air 11-inch. Nothing is clipped at
  either end, and every control is reachable at every size.
- **Every control meets the 44 × 44 point minimum touch target.** Some are drawn smaller than their
  target — the touch area is deliberately larger than the artwork, so the interface stays light
  without becoming hard to hit.
- **The mode control's inactive state was an unlabelled circle** that read as a rendering artifact.
  It is now a camera button with a full-size target and an accessibility label.
- **The display-unit control was loose text pinned to the screen edge** with no affordance. It is now
  part of the price it modifies, and is a full-size target.
- **The screen was reduced from nine stacked rows to six**, by merging rows that described the same
  thing and removing a key that duplicated an existing gesture. The result is less crowded, not
  merely smaller.
- **Larger text sizes are supported** up to the accessibility range; the keypad bounds its own growth
  so that increasing text size cannot push controls off-screen.

We also added automated interface tests that assert each control is genuinely hittable — not merely
present — at the smallest supported screen size, so this class of problem cannot return unnoticed.

Updated screenshots reflecting the revised design have been uploaded with this build.
