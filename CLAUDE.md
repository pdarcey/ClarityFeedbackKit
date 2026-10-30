# ClarityFeedbackKit

## Overview

A Swift Package that gives a host app a ready-made "Report a Bug" feature.
An end user fills in `ReportIssueView` (title + description); the SDK POSTs
it to a relay the host app's developer controls (`clarity-feedback-relay`,
a separate Cloudflare Worker), which turns it into a real GitHub Issue.
Clarity then imports that issue automatically via its own GitHub importer.

The SDK never talks to GitHub directly and never holds a GitHub credential —
only a per-app **ingest token** scoped to creating issues on one repo (same
shape as a Sentry DSN). See `Readme.md` for the full data-flow diagram and
integration instructions, including how a host app should supply that token.

## Key architecture decisions

- **`Synchronization.Mutex`, not `@MainActor`, for `ClarityFeedback`'s
  stored configuration.** `configure(ingestURL:appToken:)` has to be
  callable synchronously from a SwiftUI `App`'s `init()`, which isn't
  main-actor-isolated — forcing every caller onto the main actor just to
  set two strings would be an unreasonable ask. This is a deliberate,
  narrow exception to the global "always `@MainActor`" convention.
- **Dependency injection in `FeedbackClient`** (`session`,
  `configurationProvider`) so tests can exercise request construction and
  response handling without a real network call. Mirrors the same
  injectable-seam pattern used by Clarity's own `GitHubIssueImporter`.
- **One type per file.** `ReportIssueView`'s body is split into
  `ReportIssueContent`, `ReportForm`, `ReportIssueToolbar`,
  `SubmitButton`, `SubmissionSuccessView`, `SubmissionState`, and
  `FeedbackMetadataFooter` — real `View`/`ToolbarContent` types, not
  computed properties on `ReportIssueView` itself.
- **Both DTOs (`FeedbackSubmission`, `FeedbackSubmissionResponse`) are
  fully `Codable`**, even though production code only ever encodes one and
  decodes the other — the test suite needs the mirror-image operation for
  each (decoding what was sent, encoding a scripted mock response).
- **No UIKit import, anywhere.** `DeviceInfo.deviceModel` reads the raw
  hardware identifier via `uname(2)` instead, since that works identically
  on macOS and iOS.

## Conventions

- Platform-specific presentation is conditionalized per-platform
  (`#if os(macOS)`), never assumed — see `ReportIssueToolbar`'s dismiss
  handling (`dismissWindow()` vs `dismiss()`). macOS hosts are expected to
  present `ReportIssueView` in its own `Window` scene, not a sheet; iOS
  hosts use a sheet. Don't "fix" this to a single code path.
- The public surface is deliberately just `ClarityFeedback.configure(ingestURL:appToken:)`,
  `ClarityFeedback.isConfigured`, and `ReportIssueView` (its `init()`).
  Everything else — including `FeedbackClient` and its nested
  `SubmissionError` — is `internal`. Keep `Readme.md`'s "entire public API"
  line in sync if this ever changes.
- Swift Testing (not XCTest), matching the rest of this ecosystem
  (`ClarityStorage`, Clarity itself).
- Logging via `OSLog`/`Logger` (subsystem
  `com.xerodonia.ClarityFeedbackKit`, one category per file —
  `FeedbackClient`, `ReportIssueView`), never `print()`.
- **Never show GitHub to end users.** The success screen confirms the
  report was sent and nothing more — the created issue's URL is logged, not
  displayed. The GitHub repo is the developer's internal plumbing (and may
  be private); don't add a "View on GitHub" link back.

## Build/test instructions

```bash
swift build
swift test
```

`swift test` needs no real network access or relay — `FeedbackClientTests`
stubs `URLRequestPerforming` instead of hitting `URLSession.shared`.

SwiftLint should pass clean before committing:

```bash
swiftlint
```

## Quirks and gotchas

- This package targets **macOS 26 / iOS 26 minimum**, not the repo
  template's usual placeholder floor — matches Clarity's own floor, since
  every host app embedding this SDK is being bumped to that OS floor
  anyway.
- `DeviceInfo.appVersion` returns `nil` when there's no bundle version info
  at all (e.g. running under `swift test`, where there's no real app
  bundle) — this is expected, not a bug; `FeedbackMetadataFooter` and the
  wire payload both already treat it as optional.
- The relay's response JSON uses `"ok"` as its success-flag key.
  `FeedbackSubmissionResponse` maps that to a Swift property named
  `succeeded` via explicit `CodingKeys` — `ok` is below SwiftLint's
  `identifier_name` minimum and reads as meaningless out of context, but
  the wire key itself must stay `"ok"` since the relay isn't part of this
  repo.
- `ReportIssueView`'s own doc comment currently says to present it "as a
  sheet from your app's UI" — that's stale relative to the platform-split
  guidance actually implemented in `ReportIssueToolbar` and documented in
  `Readme.md`. Worth fixing next time `Sources/` is touched (tracked as a
  Clarity issue rather than fixed here, since doc-freshness passes are
  README/Journal/CLAUDE.md only and don't edit `Sources/`).
- `ReportIssueView` never checks `ClarityFeedback.isConfigured` itself; an
  unconfigured submission surfaces `SubmissionError.notConfigured`'s
  developer-facing message ("ClarityFeedback.configure(…) hasn't been called
  yet.") directly to end users. The README tells hosts to gate their entry
  point on `isConfigured` for this reason.
- `ClarityFeedback`'s configuration is process-global. `.serialized` only
  serialises tests *within* a suite, so suites that touch the global config
  can occasionally race each other under `swift test`. Prefer injecting
  `configurationProvider` into `FeedbackClient` in tests over calling
  `configure(...)`.
- Host apps consume this package **by URL**
  (`https://github.com/pdarcey/ClarityFeedbackKit`, `from: "1.0.0"`), and
  SemVer tags are the release mechanism (`1.0.0` is the only tag so far).
  Pushing to `main` alone doesn't ship anything to hosts. A change to
  `Sources/` only reaches them once a new tag is cut, and any change to the
  public API needs a version bump to match.
- The test target doesn't link `ClarityTesting` (from `ClarityLinks`) yet,
  although the ecosystem convention is to link it into every Swift Testing
  target. Adding it means editing `Package.swift`.
- See `Journal.md` for the fuller story behind each of these decisions,
  including the bugs that surfaced them.
