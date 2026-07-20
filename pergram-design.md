# PerGram — Design Direction v1.0

Companion to `pergram-spec.md`. This is the taste document: what the app feels like, why, and the specific interactions that make "polished" real instead of aspirational.

**North star:** a price tag that talks back. Premium here doesn't mean luxurious — it means *instant, confident, and physically satisfying*. The app should feel like a good kitchen scale: one job, zero lag, a pleasing click.

---

## 1000ft — Identity & inspirations

### The reference board
| Inspiration | Steal this | Leave this |
|---|---|---|
| **Wealthsimple** | Typographic confidence: one huge number owns the screen. Generous whitespace. Neutral chrome that lets semantic color mean something. | The gravitas. Money-app seriousness reads wrong for chicken thighs. |
| **Flighty** | Data density without clutter; live-updating numbers that feel alive; the sense that the app *knows things*. | Its information volume — PerGram shows one fact at a time. |
| **Apple's own Calculator (iOS 26)** | Keypad ergonomics, glass done by the system, dark-first confidence. | Nothing — this is the floor for keypad feel. |
| **Structured / Crouton** | Warm utility: friendly without being cutesy, SF Rounded used with restraint. | Illustration-heavy empty states — ours stay typographic. |
| **Dan Saffer's *Microinteractions*** | The framework itself: every interaction = trigger → rules → feedback → loops/modes. §"1ft" below is written in this grammar. | — |

### Personality in one line
**Deadpan-helpful.** The app has opinions ("that's a bad price") delivered flatly, like a friend who knows meat prices. Humor lives in copy tone and timing, never in decoration. No mascots, no confetti, no exclamation marks.

### Color philosophy
Chrome is neutral (system backgrounds, glass, monochrome SF Symbols). **Verdict colors are the only saturated colors in the app**, which makes them land hard:

- **Good:** a warm confident green (not system green — slightly desaturated, like a produce sticker)
- **Meh:** amber leaning honey, not warning-yellow
- **Bad:** a tomato red, not alarm red

All three must survive: fluorescent aisle glare, dark mode, and color-blindness (verdicts always pair color + symbol + word — never color alone). Define them as asset-catalog colors with light/dark variants; tune on-device in an actual grocery store, not on a monitor.

Dark mode is the *primary* design target (Calculator-style), light mode the adaptation — glass and saturated verdicts both look best on dark, and phones in stores are often at low brightness.

---

## 100ft — Screen & system level

### Layout doctrine
- **The verdict is the layout.** On Check, the top ~55% of the screen is verdict territory: the word (GOOD/MEH/BAD), the normalized price in the user's display unit (SF Rounded, heaviest weight, largest type in the app), and the baseline comparison line. Keypad and fields live in the bottom zone within thumb reach.
- One primary action per screen. No screen has two competing calls to action.
- Standard system components everywhere structure is concerned: `TabView`, `NavigationStack`, system sheets. Custom drawing is spent only on the verdict display and the scan reticle — the two moments that define the app.

### Type scale
| Role | Face | Notes |
|---|---|---|
| Verdict numeral | SF Rounded, Black | The hero. Monospaced digits (`.monospacedDigit()`) so it doesn't jitter while typing |
| Verdict word | SF Pro, Bold, small caps feel via tracking | Sits above the numeral, colored |
| Baseline line | SF Pro, Regular, secondary color | "your good price: $1.10/100g" |
| Everything else | System defaults | Dynamic Type respected everywhere, including the hero (it scales, tested to AX sizes) |

### Glass usage map (where Liquid Glass appears, and only there)
| Surface | Treatment |
|---|---|
| Tab bar, nav bars | System default glass — untouched |
| Keypad keys | `.buttonStyle(.glass)`; the equals-moment is the verdict, so no prominent key |
| Unit picker + OCR candidate chips | `.glassEffect(.regular.interactive())` in a shared `GlassEffectContainer` so adjacent chips merge/morph |
| Scan overlay controls (shutter, torch, flip-to-keypad) | Glass, floating over the camera feed; test legibility against bright store lighting specifically |
| Verdict panel | **No glass.** Solid, opaque, maximum contrast. The one fact you came for should never be translucent |

Rule of thumb: glass = things you touch; solid = things you read.

### Motion principles
- Springs only, system-tuned: `.spring(response: 0.35, dampingFraction: 0.8)` as house default; snappier (0.25) for keypad feedback.
- Numbers never teleport: all price changes animate via `.contentTransition(.numericText())`.
- Nothing animates longer than ~400ms. Grocery aisle, one hand, cart in the other — motion must inform, then get out of the way.
- Respect Reduce Motion: morphs become crossfades, numeric ticker becomes a fade.

### Haptic map (one vocabulary, used consistently)
| Event | Haptic |
|---|---|
| Digit entry | `.selection` (light tick, like a physical keypad) |
| Unit cycle | `.selection` |
| Verdict: Good | `.success` notification |
| Verdict: Meh | single `.light` impact (deliberately understated) |
| Verdict: Bad | `.warning` notification |
| OCR lock-on | `.medium` impact |
| Baseline saved | `.success` |

Verdict haptics fire **once per settled verdict**, not on every keystroke — debounce ~350ms after typing stops so the phone doesn't buzz through a price entry.

---

## 1ft — Microinteractions (Saffer grammar: trigger → rules → feedback → loops)

### 1. The verdict settle (the signature moment)
- **Trigger:** enough input exists to compute (price + weight, or OCR result confirmed).
- **Rules:** compute instantly, but *settle* deliberately — verdict color floods the panel with a fast spring scale (1.0 → 1.03 → 1.0) on the word, numeral ticks to final value via numericText transition.
- **Feedback:** color + word + numeral + haptic land together, ~250ms total. This is the app's "cha-ching."
- **Loops:** re-typing dissolves the verdict to neutral gray immediately (no stale verdicts, ever), then re-settles on pause.

### 2. Keypad digits
- **Trigger:** key press.
- **Rules:** glass key responds via `.interactive()`; digit appears in field instantly — zero perceived latency is the entire premium feel.
- **Feedback:** selection haptic + the live per-100g preview (small, above the field) ticking in real time.
- **Loops:** long-press delete clears the field with an accelerating digit-by-digit rollback rather than an instant blank — feels mechanical, communicates "held," takes <400ms.

### 3. Unit cycling on the verdict
- **Trigger:** tap the unit label on the hero numeral.
- **Rules:** cycles through the user's enabled display units; persists the choice.
- **Feedback:** numeral rolls to converted value (numericText), unit label does a tight crossfade, selection haptic. The *number visibly transforming* is the unit-graph made tangible — it's also the converter's marketing.
- **Loops:** order of cycle = user's settings order; two-second toast on first-ever use: "Tap to switch units."

### 4. Scan lock-on
- **Trigger:** Vision produces a stable high-confidence parse across ~3 consecutive frames.
- **Rules:** reticle corners draw in and snap to the detected tag region; parse chips slide up from the bottom in a glass container.
- **Feedback:** medium impact haptic at snap; chips morph (glassEffectID) from a single "reading…" pill into discrete price/weight candidates.
- **Loops/modes:** losing the tag relaxes the reticle back to searching state (no error, no red — searching is a calm state). Ambiguity mode: multiple prices → chips wiggle is *not* used; they simply coexist and await a tap.

### 5. Save-as-baseline
- **Trigger:** tap "set as my good price" on an unmatched or better-than-baseline result.
- **Rules:** writes/updates the item; if it overwrites, show the old value in the confirmation.
- **Feedback:** the button's glass morphs (container + glassEffectID) into a checkmark pill — the Saffer-style "the control becomes the confirmation" move — then settles back after 1.2s.
- **Loops:** undo lives in the confirmation pill itself (tap to revert within the 1.2s), not a toast graveyard.

### 6. Swipe between Check ↔ Scan
- **Trigger:** horizontal swipe on the Check screen (in addition to tab tap).
- **Rules:** keypad and camera are two faces of the same input; swiping between them keeps any partially-entered state.
- **Feedback:** the shared glass elements (unit chip, item pill) morph across via glassEffectID — the interface visibly *is* the same tool changing grip.
- **Loops:** app remembers which face you left it on and cold-launches there.

### Anti-checklist (polish killers, banned)
- Loading spinners anywhere in the core loop (nothing in this app is slow enough to justify one).
- Toasts stacking, confetti, badge dots, onboarding carousels, rating prompts before v1.2.
- Any animation that delays input readiness — the keypad accepts digits at frame zero.

---

## Appendix — Liquid Glass, condensed (working reference)

The uploaded skill, cut to what PerGram uses, with house rules inline:

```swift
// Single element — after layout modifiers, always
.padding().glassEffect()                                  // default: regular, capsule
.glassEffect(.regular.tint(.accent).interactive(), in: .rect(cornerRadius: 16))

// Buttons
.buttonStyle(.glass)            // keypad keys, secondary actions
.buttonStyle(.glassProminent)   // at most one per screen; Check has zero

// Multiple glass siblings — ALWAYS containered (perf + morphing)
GlassEffectContainer(spacing: 20) {  // spacing = merge distance
    ...chips.glassEffect().glassEffectID("chip-\(id)", in: ns)
}

// Morphs: same glassEffectID + withAnimation across hierarchy changes
// Unions: .glassEffectUnion(id:namespace:) to fuse a group into one pane
```

House rules (superset of Apple's guidance, subset of the uploaded skill):
1. **Glass = touchable.** Never on read-only surfaces; never on the verdict panel.
2. `.interactive()` only on things that respond — decorative interactivity is noise.
3. No standalone sibling glass views — container or don't.
4. No opaque fills behind glass (defeats it); no glass on glass (muddies it).
5. Every glass surface tested in light, dark, and over the live camera feed.
6. Widgets (future): handle `.accented` rendering mode from day one of the widget, not as a retrofit.

---

## Build order for polish (so it ships, not slips)
1. Verdict settle + keypad haptics — the two interactions that define feel; do these in Week 3–4 alongside the Check screen, not as a "polish pass."
2. Unit-cycle roll (Week 3–4, it's nearly free with numericText).
3. Scan lock-on + chip morphs (Week 7–9 with OCR).
4. Save-as-baseline morph, swipe-between-faces (Week 10).

Polish that's scheduled is polish that exists. "We'll make it feel nice at the end" is how apps end up feeling like the old Per Gram Calculator.
