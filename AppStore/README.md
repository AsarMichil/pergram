# App Store assets

Screenshots are 1206 × 2622 — the native iPhone 16 Pro size, which is the **6.3" display** slot in
Media Manager. App Store Connect scales one set down for smaller sizes, so this is the only set
that has to exist.

| File | Source | Shows |
|---|---|---|
| `01-good-verdict.png` | device | Bananas under the good price |
| `02-meh-verdict.png` | simulator | Ground beef in the middle band |
| `03-items.png` | simulator | The seeded item list with saved good prices |
| `04-bad-verdict.png` | device | Bananas well over the good price |
| `05-scan-device.png` | device | Scan reading a real shelf label — held back, see below |

## Regenerating the simulator shots

`pergramUITests/ScreenshotTests.swift` drives the app into each state and attaches a screenshot.
The UI test target is `skipped = "YES"` in the scheme so it stays out of the normal test run; flip
it to `"NO"`, run the capture, and flip it back:

```sh
xcodebuild test -scheme pergram -destination 'id=<simulator>' \
  -only-testing:pergramUITests/ScreenshotTests -resultBundlePath build/shots.xcresult
xcrun xcresulttool export attachments --path build/shots.xcresult --output-path <dir>
```

Boot the simulator with `xcrun simctl ui <id> appearance dark` and the standard status bar override
(`--time "9:41"`, full bars, charged) so the output matches the device shots.

## Scan

`05-scan-device.png` is a real capture and is accurate, but a camera view of plastic-wrapped meat
reads as visual noise at thumbnail size. Either reshoot against a high-contrast printed tag — the
yellow `$4 /lb` produce signs photograph far better than a barcode label — or leave Scan out of the
uploaded set. Do not composite a viewfinder image that was never captured: screenshots have to show
the app as it actually behaves.
