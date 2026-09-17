# App Store assets

Two sets, generated natively rather than scaled — the slots differ in aspect ratio, so resizing one
into the other would distort or crop.

| Directory | Pixels | Media Manager slot |
|---|---|---|
| `screenshots/6.3-inch/` | 1206 × 2622 | iPhone 6.3" |
| `screenshots/6.5-inch/` | 1284 × 2778 | iPhone 6.5" |

Both sets show the same four states, in upload order:

| File | Shows |
|---|---|
| `01-good.png` | Bananas under the good price |
| `02-meh.png` | Ground beef in the middle band |
| `03-bad.png` | Cheddar cheese well over |
| `04-items.png` | The seeded item list with saved good prices |

`ScreenshotTests` also captures `05-compare.png` — a parked price with the difference against the
one being checked. It is not in either uploaded set; it exists so the comparison chip is verifiable
without driving the app by hand, and is a candidate if a fifth slot is ever wanted.

> **The committed PNGs predate the short-screen rework** (the merged item row, the hero's inline
> unit, the reworked mode toggle). They must be regenerated before the next submission.

## Regenerating

`pergramUITests/ScreenshotTests.swift` drives the app into each state and attaches a screenshot.
The UI test target is `skipped = "YES"` in the scheme so it stays out of the normal test run; flip
it to `"NO"`, capture, and flip it back.

```sh
xcrun simctl ui <id> appearance dark
xcrun simctl status_bar <id> override --time "9:41" --wifiBars 3 --cellularBars 4 \
  --batteryState charged --batteryLevel 100
xcodebuild test -scheme pergram -destination 'id=<id>' \
  -only-testing:pergramUITests/ScreenshotTests -resultBundlePath build/shots.xcresult
xcrun xcresulttool export attachments --path build/shots.xcresult --output-path <dir>
```

Device types: `iPhone-16-Pro` for 6.3", `iPhone-13-Pro-Max` for 6.5".

## Scan

`device-captures/scan-beef-label.png` is a real capture and is accurate, but a camera view of
plastic-wrapped meat reads as noise at thumbnail size, so it is not in either uploaded set. To
include Scan, reshoot against a high-contrast printed tag — the yellow `$4 /lb` produce signs
photograph far better than a barcode label. Do not composite a viewfinder image that was never
captured: screenshots have to show the app as it actually behaves.
