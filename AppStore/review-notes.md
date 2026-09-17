# App Review reply — Guideline 2.1, new app submission

Paste the numbered answers below into the App Store Connect reply, and the same text into
**App Review Information → Notes** so future submissions carry it.

---

## 1. Screen recording

Recorded on a physical iPhone running the current iOS. See the shot list at the end of this file.

The app has no account registration, no login, no account deletion, no user-generated content, and
no paid content or in-app purchases, so none of those flows appear.

## 2. Purpose and target audience

PerGram Go answers one question a grocery shopper cannot answer in their head: is this price
actually good?

Shelf prices are not comparable as printed. A 680 g pack at $8.99 and a 1.4 kg pack at $16.49 are
different prices per kilogram, and working that out in an aisle is tedious enough that most people
skip it. The app converts any price to a common unit — $/100 g, or $/each for things sold by count —
and compares it against a good price the user sets themselves.

The audience is ordinary grocery shoppers in Canada, particularly anyone comparing package sizes,
brands or stores. There is no professional or business use case.

The verdict is deliberately measured against the user's own saved good price rather than a market
average, so it reflects what that person considers acceptable.

## 3. Setup and access to the main features

No account, no login, no credentials, and no sample files are required. The app is fully functional
offline from first launch.

- **Check (Type).** Opens on this tab. Enter a price on the keypad, tap the amount field, enter an
  amount, and choose a unit. The verdict appears above.
- **Selecting an item.** Tap the item row between the price card and the keypad to open its menu.
  "Choose item…" picks from a list of common groceries, each carrying a starting good price shown on
  the row itself. "Set good price to …" replaces that baseline with whatever is currently on screen.
- **Display unit.** Tap the unit beside the large price (for example `/kg`) to cycle it.
- **Comparing two products.** The bookmark key parks the price on screen; check a second product and
  the chip under the price shows the difference between them.
- **Check (Scan).** Tap "Scan" at the top of the Check screen, or swipe left. iOS asks for camera
  permission the first time. Point the camera at any printed price tag and the fields fill on their
  own; there is no button to press. Pinch to zoom and tap to focus for small print.
  A printed grocery shelf tag works, and so does a photograph of one shown on another screen.
- **Items.** The saved list, searchable, with prices editable via + or by swiping a row.
- **Settings.** How the app works, a feedback email, links to the support page and privacy policy,
  and the version number.

## 4. External services, tools and platforms

None. The app makes no network requests of any kind. It has no third-party SDKs, analytics,
advertising, authentication, payment processing, or backend of any sort, and no Swift Package or
CocoaPods dependencies.

Everything is Apple's own on-device frameworks:

- **Vision** — text recognition on camera frames, entirely on device. This is Apple's local
  framework, not a hosted or third-party AI service. No image or frame is uploaded anywhere.
- **AVFoundation** — the camera capture session.
- **SwiftUI, SwiftData, Foundation** — interface and local storage.

Camera frames are processed in memory in real time and are never written to disk, saved to the photo
library, or transmitted. The app's privacy manifest declares no collected data and no tracking.

The grocery items that ship with the app, and their starting prices, are the developer's own
estimates written by hand. They are not licensed from, scraped from, or supplied by any retailer or
data provider.

## 5. Regional differences

The app behaves identically in every region. There is no region detection, no geolocation, and no
region-conditional code or content.

It is designed for Canadian shopping: prices display in Canadian dollars everywhere, and the tag
reader understands the bilingual English and French wording Canadian shelf tags are required to
carry. Those are fixed properties of the app, not switched by the user's region — someone running it
elsewhere sees exactly the same app.

## 6. Regulated industry and third-party material

Neither applies.

The app is a unit-price calculator. It is not in a regulated industry, and it makes no health,
financial, or safety claims. A verdict is arithmetic against a number the user chose.

It contains no third-party protected material. There is no retailer branding, no licensed price
data, and no third-party content of any kind. Scanning reads the price printed on a tag the user is
standing in front of, using the camera, in the same way a person reads it — nothing is retained and
no retailer system is accessed.

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
8. Open Items, scroll, use the search field.
9. Back on Check, tap the unit beside the large price to cycle it.
10. Open Settings and open the privacy policy link.

Include audio narration or on-screen captions if convenient; neither is required.


---

# App Review reply — Guideline 4, Design

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
