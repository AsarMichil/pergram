# PerGram — Spec v1.0

A unit-price sanity checker for Canadian grocery shopping. Type or scan a shelf price, get an instant verdict in your preferred unit ($/100g by default): good, meh, or bad. Done in five seconds.

**Constraints that shape everything below:** single junior dev, shipped to the Canadian App Store as a portfolio piece, minimal long-term support burden, family beta testers. Every decision optimizes for *ship it, then leave it alone*.

---

## 1. Product definition

### Core loop (the whole app, really)
1. User opens app → lands directly on the Check screen (no splash, no home screen).
2. User either **types** (price + weight via keypad) or **scans** (camera reads the shelf tag).
3. App normalizes to **CAD per 100g** and compares against the baseline for that item.
4. Verdict renders instantly: **Good / Meh / Bad**, with the normalized price and the baseline shown for context.
5. User puts the phone away.

Target: cold launch to verdict in under 5 seconds. This number is a design constraint, not a hope — it kills features (see §8).

### Display unit is the user's choice
**Canonical unit internally: CAD per 100g. Display unit: whatever the user picks.** A global setting offers $/100g, $/kg, $/lb, $/oz (extensible — it's just a target node in the unit graph). The verdict screen shows the normalized price and baseline in the chosen unit, and tapping the unit on the verdict itself cycles through them, so someone who thinks in $/lb at the meat counter never has to translate in their head. Baselines are stored per-100g but entered and edited in the display unit; conversion is invisible.

### Verdict logic
Each item has a baseline `goodPrice` (CAD per 100g). Verdict thresholds:

| Verdict | Condition | UI |
|---|---|---|
| Good | ≤ baseline × 1.05 | Green, big checkmark |
| Meh | baseline × 1.05 – 1.25 | Amber, tilde |
| Bad | > baseline × 1.25 | Red, X |

The multipliers live in one constants file so tuning is a one-line change. Show the math: "$1.32/100g · your good price is $1.10" — never just a color. Users should trust the verdict because they can see it, not because the app said so.

If the item isn't matched to a baseline, degrade gracefully: show the normalized per-100g price with no verdict and a one-tap "set this as my good price" action. This is also how the baseline grows over time.

---

## 2. Baseline data

- **Seeded list ships in the app bundle** as a JSON file: ~60–100 common Canadian grocery items (chicken thigh, chicken breast, ground beef, salmon, butter, cheddar, rice, pasta, apples, bananas, etc.) with a `goodPrice` per 100g in CAD. You author this once from your own receipts/flyers.
- On first launch, the seed is imported into local storage (SwiftData). After that, **the local copy is the truth** — users edit freely, edits never get clobbered by app updates.
- Seed JSON is versioned (`seedVersion`). If a future update adds new items, import only items the user doesn't already have. Never overwrite user-modified prices. This one rule prevents the most likely support complaint.
- Item schema (deliberately flat and boring):

```json
{
  "id": "chicken-thigh-boneless",
  "name": "Chicken thigh (boneless)",
  "aliases": ["thighs", "boneless thighs"],
  "category": "meat",
  "goodPricePer100g": 1.10,
  "userModified": false,
  "updatedAt": "2026-07-20T00:00:00Z"
}
```

- No sync, no backend, no accounts. iCloud sync via SwiftData's built-in CloudKit mirroring is a **checkbox-level** add later if family members want shared baselines — but v1 ships without it. (Design note: keep the model CloudKit-compatible from day one — no unique constraints SwiftData+CloudKit can't handle, all properties optional or defaulted — so flipping it on later isn't a migration.)

---

## 3. Input: keypad

The default tab. One screen:

- **Price field** (decimal keypad, `$` prefixed).
- **Amount field + unit picker**: g, kg, lb, oz, /100g, /each. Defaults to the last-used unit.
- **Item picker**: search-as-you-type against names + aliases. Optional — you can get a normalized price with no item selected.
- Verdict updates live as you type. No "Calculate" button. The verdict *is* the screen.

Edge cases handled up front: "2 for $7" (a quantity stepper: price ÷ n), and per-each items where weight is on the package (user types the package weight).

---

## 4. Input: camera + OCR

Second tab (or a camera button on the Check screen — decide in design, but camera is one tap from launch either way).

- **Live text recognition** via `VisionKit` / `Vision` framework (`RecognizeTextRequest`). Fully on-device, no network, free, works on every device you care about. **No LLM required for v1 OCR.**
- Pipeline: camera frame → Vision OCR → deterministic parser → structured `{price, weight, unit, nameGuess}` → same verdict pipeline as keypad.
- The parser is a set of regexes + heuristics tuned for Canadian shelf tags:
  - Price patterns: `$4.99`, `499`, `2/$7.00`, `4.99/lb`, `1.10/100g`
  - Canadian tags legally display a unit price (per 100g or per 100mL in most provinces) — **when the tag already shows per-100g, trust it directly** and skip the math. This is the happy path more often than you'd think.
  - Bilingual tags: match both English and French tokens (`/lb`, `/kg`, `ch.`, `l'un`, `format`).
- On ambiguity (multiple prices detected — sale price vs. regular vs. unit price), show detected candidates as tappable chips rather than guessing. One tap beats a wrong answer.
- OCR result pre-fills the keypad screen. The user can always correct before trusting the verdict. **OCR is an input accelerator, not an authority.**

### The on-device LLM (in v1, capability-gated)
Apple's **Foundation Models framework** (iOS 26) runs the ~3B on-device model with no network, no cost, and no data leaving the phone — a perfect fit for this app's privacy story, and a strong portfolio signal.

Where it earns its place:
1. **Messy tag → structured data.** When the deterministic parser's confidence is low (conflicting prices, garbled OCR), hand the raw OCR text to a `LanguageModelSession` with a `@Generable` struct (`price: Double, weight: Double, unit: Unit, nameGuess: String`). Guided generation means you get typed Swift values back, not JSON-parsing roulette.
2. **Fuzzy item matching.** "PC Blue Menu Bnls Sknls Chkn Thghs" → `chicken-thigh-boneless`. Alias matching handles common cases; the model handles the long tail of abbreviated store-brand names.

Rules that keep it low-maintenance:
- **Deterministic parser runs first, always.** The LLM is a fallback for low-confidence parses, not the primary path. High-confidence regex results never touch the model — faster and more predictable.
- **Availability check at launch** (`SystemLanguageModel.default.availability`). On non-Apple-Intelligence devices (or when the model is downloading / disabled), the app is fully functional with parser-only scanning — the feature degrades invisibly, no nag screens.
- **Model output is a pre-fill, never an authority.** Same rule as OCR: the user confirms before the verdict counts.
- Session prompts and `@Generable` schemas live in Core with unit-testable pre/post-processing around the model call, so the nondeterministic surface is as small as possible.

With the app floor at **iOS 26**, there's no `#available` dance — the framework is always present. The remaining gate is **hardware**: Foundation Models only runs on Apple-Intelligence-capable devices (iPhone 15 Pro and later), and the model can be unavailable while downloading or if the user disabled Apple Intelligence. So the `SystemLanguageModel.default.availability` check stays, and parser-only scanning remains the silent fallback on devices that run iOS 26 but not Apple Intelligence (e.g. base iPhone 15).

---

## 5. Unit / price translator (graph-based)

A small utility screen, and the internal engine for everything else.

- **Model:** units are nodes, conversions are directed weighted edges (`g → kg` ×0.001, `lb → g` ×453.592, `oz → g` ×28.3495, `100g` as a pseudo-unit ×100 from g). Currency-per-unit values convert by inverting the mass factor.
- **Resolution:** BFS from source unit to target unit, multiplying edge weights along the path. Overkill for six units — intentionally. Adding volume (mL, L, per-100mL for liquids) or count-based units later is *adding a node and an edge*, not rewriting a conversion matrix. This is the "don't design into a corner" insurance.
- **UI:** two-sided converter. Left: "what the tag says" ($/lb, $/kg, 2-for). Right: the user's chosen display unit (defaults to CAD/100g). Both sides editable; edits flow the other direction.
- **Inverses are supported by construction, exposed nowhere (yet).** A price like $1.10/100g is stored as a `Rate {money, mass}` pair, so flipping it to "how much do I get per dollar" (≈91g/$) is a reciprocal, not a new code path. The engine exposes `inverted()` and it's unit-tested, but no v1 screen offers grams-per-dollar as a display mode — it's a feature-flag flip away if it ever turns out people think that way. (Watch the divide-by-zero edge on a $0 input; clamp it in the engine, not the UI.)
- The engine is a pure Swift module with zero UI dependencies and full unit-test coverage — the highest-value tests in the app, since every verdict flows through it.

---

## 6. Architecture

Boring on purpose. Every choice is "the current Apple default," which is what you want to show in interviews and what future-you will thank present-you for.

| Layer | Choice | Why |
|---|---|---|
| UI | SwiftUI, **iOS 26+** | Liquid Glass design language for free, one OS to test, modern portfolio signal |
| State | `@Observable` + environment | No third-party architecture framework to babysit |
| Storage | SwiftData | Local-first, CloudKit-ready, zero server |
| OCR | Vision / VisionKit | On-device, free, private |
| Dependencies | **Zero third-party packages** | Nothing to update, nothing to break, nothing to audit |
| CI | Xcode Cloud free tier | TestFlight builds for family with no infra |

**Threading:** you're right that there's no data-loading problem here — SwiftData reads of ~100 items are trivial. The two things that *do* belong off the main actor: **Vision OCR requests** (run per-frame on a background queue; only the parsed candidate results hop to `@MainActor` for display) and **Foundation Models sessions** (already `async` — just never `await` them anywhere that blocks the verdict rendering; show the parser's result immediately and let the LLM refinement land when it lands). Keypad math is microseconds and stays wherever it likes.

Module layout (Swift packages inside the project, so boundaries are compiler-enforced):

```
PerGram/
  Core/            // pure logic: UnitGraph, VerdictEngine, TagParser — 100% testable, no UIKit
  Data/            // SwiftData models, seed import, versioned migration
  Features/
    Check/         // keypad screen + verdict view
    Scan/          // camera + OCR
    Items/         // baseline list, search, edit
    Help/          // about, feedback, FAQ
  App/             // entry point, tab shell, theming
```

The clean Core/Data split is precisely what makes the "later" features (§9) additive: price history is a new SwiftData entity referencing existing items; trends is a new Feature folder reading it. Nothing in v1 needs to change.

### Extensibility hooks that cost nothing now
- Every check (keypad or scan) *can* emit a `PriceObservation {item?, pricePer100g, date, source}`. **v1 writes these but builds no UI on them.** Ten lines of code now; the entire trends/metrics feature later gets historical data from day one of a user's usage instead of day one of the feature.
- Item `category` field exists in the schema even though v1 barely uses it — it's the grouping key for future shopping lists and trends.

---

## 7. Not looking like AI slop (design principles)

- **One typeface, the system one.** SF Pro / SF Rounded for the verdict numeral. No gradients-on-gradients, no emoji as iconography, no purple.
- **Liquid Glass, but the system's, not a homemade imitation.** Use standard SwiftUI containers, toolbars, and tab bars and let iOS 26's material do its thing — `glassEffect` sparingly on the few custom controls (unit picker, candidate chips). The fastest way to look like slop in 2026 is hand-rolled frosted-glass cards; the fastest way to look native is using the real components and getting out of their way. Test glass surfaces against busy camera backgrounds specifically — the Scan screen is where legibility dies first.
- The verdict screen is essentially a **giant number and a color**. Legible from arm's length in a grocery aisle in bad lighting. Think price tag, not dashboard.
- **SF Symbols only, everywhere** — no custom icon set, no third-party icon pack. They pick up Liquid Glass rendering, weights, and Dynamic Type scaling automatically. App icon built with Icon Composer so it gets the layered glass treatment on the home screen too. Standard navigation, haptics on verdict (success/warning/error patterns). Dark mode and Dynamic Type support are non-negotiable.
- Full French localization is **not** in v1 (you're shipping in Canada but not claiming Quebec-first; App Store listing in English). String catalogs from day one so adding `fr-CA` later is translation work, not engineering work. The OCR parser handles French tags regardless, since tags are bilingual everywhere.
- Empty states written like a human: "No items yet — check a price and save it."

Before building UI, read the frontend-design skill notes / Apple HIG grocery-adjacent patterns; but honestly the strongest anti-slop move is *restraint plus polish on the one screen that matters*.

---

## 8. Scope guards (what v1 deliberately does not do)

- No accounts, no backend, no analytics SDK, no ads, no subscriptions. Price it **free**. A free, useful, tiny app has zero support expectations; that's your low-maintenance win.
- No barcode scanning (barcodes give you the product, not the price — wrong problem).
- No store-price databases or flyer scraping (legal gray zone, permanent maintenance treadmill, and the exact thing that would chain you to this app for years).
- No shopping list, no trends UI, no widgets, no watch app — all parked in §9.

## 9. Roadmap (parked, not promised)

| Version | Feature | Enabled by |
|---|---|---|
| 1.1 | Price history + simple trend sparkline per item | `PriceObservation` records already accumulating |
| 1.2 | iCloud sync of baselines (family shared prices) | CloudKit-compatible models from day one |
| 1.3 | Shopping list with "target good prices" | `category` field + existing item store |
| 2.0 | `fr-CA` localization | String catalogs |
| 2.x | LLM-assisted natural-language item entry ("costco rotisserie chicken 1.2kg $8") | Foundation Models plumbing already in v1 |

---

## 10. Help & feedback

Help tab contents: a three-line "how it works," a note that prices are your own baselines (not live store data), and the thing you always wished existed:

- **Feedback box:** a plain multiline text field + optional "this is a bug / this is a suggestion" toggle + Send.
- **Transport: `MFMailComposeViewController` (mail sheet) pre-filled to `helpPERGRAM@asarmichil.com`**, with app version and iOS version auto-appended to the body. Fallback for users with no Mail configured: a share sheet with the composed text.
- Why not a backend endpoint or Google Form: the mail sheet has zero infrastructure, zero uptime obligation, zero privacy-policy complexity (nothing is transmitted except what the user knowingly sends), and it lands in an inbox you already check. For a single dev who doesn't want a support tail, an inbox *is* the support system.
- App Store requirement note: you'll still need a support URL and privacy policy page — a single static page on GitHub Pages satisfies both. Privacy label: "Data not collected." That label is also a genuinely good marketing line for this app.

---

## 11. Milestones (realistic for nights-and-weekends)

1. **Week 1–2:** Core package — UnitGraph + VerdictEngine + tests. Seed JSON authored.
2. **Week 3–4:** Keypad Check screen end-to-end. App is already useful; start dogfooding at the grocery store immediately.
3. **Week 5–6:** Items list (browse/search/edit baselines), seed import/versioning.
4. **Week 7–9:** Camera + OCR + parser, tuned against photos of real tags from your own shopping trips (build a small test-fixture folder of tag photos — this doubles as your parser test suite). Then the Foundation Models fallback path: `@Generable` schema, availability gating, and a "which parses needed the LLM" debug log so you can measure how often it actually fires.
5. **Week 10:** Help/feedback, polish, haptics, dark mode audit, Dynamic Type audit.
6. **Week 11–12:** TestFlight to family → App Store submission (screenshots, privacy label, support page). Reserve the "PerGram" name in App Store Connect **now**, not at week 11 — reservations are first-come and free. The App Store *subtitle* is where you differentiate from the stale "Per Gram Calculator": something like "Instant good-price verdicts" positions it as a verdict app, not another calculator.

Ship keypad-only if OCR drags. The keypad app alone is complete and honest; OCR is delight, not table stakes.

---

## 12. Development conventions

- **Commit subjects are semantic:** `feat:`, `fix:`, `chore:`, `refactor:`, `test:`, `docs:`. One concern per commit.
- **Commit bodies are point form** — `- ` bullets, one change per line, so a glance at the log reads like a changelog.
- **Feature work happens on a branch**, never directly on `main`.
- **Parallel agents get their own git worktree**, so concurrent work never collides on a single working tree.
- **`swift-format` is the source of truth for style** (config at `.swift-format`, run via `Scripts/format.sh`); the `pergram` target lints on build and surfaces violations as warnings. It ships with the Xcode toolchain, so it does not count against the zero-third-party-packages rule.
- **Comments are a smell.** After writing code, remove comments and fix the names/structure instead; keep only what the code cannot say itself (a non-obvious *why*, a bilingual-tag/regulatory quirk, or a `///` doc comment on a public Core API).

### Open items to resolve before v1 ship
- **Feedback address:** §10 uses `helpPERGRAM@asarmichil.com`; the developer account is `ai@asarmichil.com`. Pick one (default: keep the dedicated `helpPERGRAM@` alias so support mail is filterable).
- **Verdict boundary inclusivity (§1):** treat the thresholds as **Good** `≤ baseline × 1.05`, **Meh** `> ×1.05` and `≤ ×1.25`, **Bad** `> ×1.25` — inclusive on the low side of each band.
