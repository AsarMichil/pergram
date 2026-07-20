# PerGram

A unit-price sanity checker for Canadian grocery shopping. Type or scan a shelf price, get an
instant verdict ($/100g by default): good, meh, or bad. See `pergram-spec.md` for the full spec.

## Constraints

- Single developer, portfolio piece, minimal long-term support. Optimize for **ship it, then
  leave it alone**.
- **iOS 26+**, SwiftUI, `@Observable`, SwiftData.
- **Zero third-party packages.** `swift-format` ships with the Xcode toolchain, so it does not
  count against this. Nothing to update, audit, or break.
- Canonical unit internally is **CAD per 100g**; display unit is the user's choice.

## Comment policy

After writing code, remove comments. A comment is usually a smell that the code is not legible
enough — fix the names and structure until the code explains itself, rather than annotating it.

Keep only comments that carry information the code cannot:

- Non-obvious **why** (a decision, a workaround, a constraint).
- Format/regulatory quirks (e.g. bilingual French/English shelf-tag tokens).
- Doc comments (`///`) on public Core APIs.

## Formatting

`swift-format` is the source of truth. Config lives at `.swift-format`.

- Run `Scripts/format.sh` before committing.
- The `pergram` target has a build-phase that lints and surfaces violations as Xcode warnings.

## Git

- **Semantic commit subjects:** `feat:`, `fix:`, `chore:`, `refactor:`, `test:`, `docs:`.
- **Commit body in point form** — `- ` bullets, one change per line.
- Do feature work on a **branch**, never directly on `main`.
- When running **parallel agents**, give each its own **git worktree** so they do not collide on
  the working tree.
- Never commit or push unless asked.

## Architecture

Single `pergram` app target, organized by folder (no Swift packages — nothing here benefits from
a separate module, SwiftData included):

```
pergram/
  App/        entry point, tab shell, theming
  Core/       pure logic: Unit, UnitGraph, Rate, VerdictEngine — no SwiftUI/UIKit
  Data/       SwiftData models, seed import, versioned migration
  Features/   Check/ Scan/ Items/ Help/
```

Core is pure and `nonisolated` (the target defaults to `MainActor` isolation) so it runs off the
main actor for Vision OCR and Foundation Models later, and unit-tests via `@testable import pergram`.

## Commands

- Format: `bash Scripts/format.sh`
- Lint: `xcrun swift-format lint --strict --recursive --configuration .swift-format pergram`
- Build: `xcodebuild -scheme pergram -destination 'generic/platform=iOS' build`
- Test: `xcodebuild test -scheme pergram -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`

The `xcode` MCP tools (`BuildProject`, `RunAllTests`) are the preferred way to build and test.
