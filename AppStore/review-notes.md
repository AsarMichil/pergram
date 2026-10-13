# App Review notes

Paste the numbered answers below into **App Review Information → Notes** for each submission. They
were first written as the Guideline 2.1 reply and are kept current with the app (last: 1.2.0).

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

Since 1.2.0 it also keeps grocery lists and a running cart for a shopping trip, so the same check
happens while shopping a list, and a trip ends with a summary of what was spent and how it rated.

The verdict is deliberately measured against the user's own saved good price rather than a market
average, so it reflects what that person considers acceptable.

## 3. Setup and access to the main features

No account, no login, no credentials, and no sample files are required. The app is fully functional
offline from first launch.

- **Check (Type).** Opens on this tab. Enter a price on the keypad, tap the amount field, enter an
  amount, and choose a unit. The verdict appears above.
- **Selecting an item.** Tap the item row between the price card and the keypad to open its menu.
  "Choose item…" searches the user's items and a built-in list of common groceries. A fresh install
  has no good prices: the user sets them. With an item selected, "Set as good price" appears where
  the verdict would be, and "Set good price to …" in the item menu does the same.
- **Display unit.** Tap the unit beside the large price (for example `/kg`) to cycle it.
- **Comparing two products.** The bookmark key parks the price on screen; check a second product and
  the chip under the price shows the difference between them.
- **Check (Scan).** Tap "Scan" at the top of the Check screen, or swipe left. iOS asks for camera
  permission the first time. Point the camera at any printed price tag and the fields fill on their
  own; there is no button to press. Pinch to zoom and tap to focus for small print.
  A printed grocery shelf tag works, and so does a photograph of one shown on another screen.
- **Shop.** The leftmost mode on the Check screen ("Shop", or swipe right from Type). It shows the
  running cart and, when shopping a list, that list by aisle. The add-to-cart key sits under the
  bookmark key; "Finish trip" shows the trip summary.
- **Lists.** Create a list with +, add items by typing, tap an item to add a note or change its
  aisle, and "Shop this list" to start a trip. The share button sends a copy of the list as a
  `.pergram` file, which PerGram Go opens on another device to import or update it.
- **Items.** Everything the user has added or priced, by aisle, searchable; tap one to set or remove
  its good prices.
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

Sharing a list uses the system share sheet: the app writes a small file and iOS sends it by whatever
the user picks (AirDrop, Messages, Files). The app itself never connects to anything.

The built-in list of common groceries is names, aliases and aisles only — no prices. It was written
by the developer and its French names were checked against Health Canada's Canadian Nutrient File,
published under the Open Government Licence – Canada, which the app credits in Settings. Nothing
comes from any retailer.

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

It contains no third-party protected material. There is no retailer branding and no price data
from anyone but the user. The only outside material is a cross-check of grocery names against an
open Government of Canada dataset, credited in Settings as its licence requires. Scanning reads the price printed on a tag the user is
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
8. Open Lists, create a list, add two items, and tap one to add a note.
9. Tap "Shop this list", then Start. Tap an item to price it and add it to the cart with the cart
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
