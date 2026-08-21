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

A comment earns its place only by carrying what the code cannot:

- Non-obvious **why**: a decision, a workaround, a constraint that would otherwise read as arbitrary.
- Format/regulatory quirks (e.g. bilingual French/English shelf-tag tokens).
- Doc comments (`///`) on public Core APIs.

Do not write:

- **Provenance.** How a rule was discovered — a device log, a bug report, a conversation — belongs
  in the commit message or a spec. "Found on a real capture", "straight from the aisle" and
  "the case from the log" give a future reader nothing to act on.
- **Specification.** Rationale, trade-offs and rejected alternatives belong in `agent-docs/`. A
  comment restating the spec goes stale the moment the spec moves, and then misleads.
- **Narration.** Anything the reader already gets from the line beneath it.

**Density is a signal.** A file needing many comments is usually asking to be refactored — extract
the named function the comment is describing, and delete the comment.

**Tests carry the least.** The test name is the comment. Add `///` only when a case looks arbitrary
and the reason cannot be recovered from the name and the assertions — then one line, about the case,
never about how it was found.

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
