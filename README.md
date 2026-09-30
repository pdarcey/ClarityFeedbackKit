# ClarityFeedbackKit

A tiny Swift Package: embed it in an app so its users can send a bug report
or idea straight to you, as a real GitHub Issue — which then gets pulled
into [Clarity](../../Apps/Clarity/) automatically by its GitHub importer.

```
Your app + ClarityFeedbackKit  →  clarity-feedback-relay  →  GitHub Issues  →  Clarity
        (this package)              (the relay repo)
```

The SDK never talks to GitHub directly and never holds a GitHub credential —
it POSTs to a relay you control, using a per-app **ingest token** (like a
Sentry DSN). See `clarity-feedback-relay`'s README for how to issue tokens.

## Requirements

macOS 26+ / iOS 26+, Swift 6.2+.

## Installation

Add as a local or git-hosted Swift Package dependency:

```swift
.package(path: "../ClarityFeedbackKit")
// or, once pushed somewhere:
// .package(url: "https://github.com/pdarcey/ClarityFeedbackKit", from: "1.0.0")
```

## Usage

Configure once, early in app launch (e.g. in your `App`'s `init()`):

```swift
import ClarityFeedbackKit

ClarityFeedback.configure(
    ingestURL: URL(string: "https://clarity-feedback-relay.<your-subdomain>.workers.dev/v1/feedback")!,
    appToken: "<this app's ingest token>"
)
```

Then present the ready-made form from anywhere. `ReportIssueView` closes itself
(Cancel/Done) using whatever dismissal mechanism matches how it's presented, so
present it the idiomatic way for each platform rather than a single `.sheet`
everywhere — a sheet reads as a modal interruption on macOS, where a
self-contained form like this is normally its own window:

```swift
// iOS/iPadOS — a sheet is the right call here.
.sheet(isPresented: $showingReportSheet) {
    ReportIssueView()
}
```

```swift
// macOS — give it its own Window scene instead of a sheet...
Window("Report a Bug", id: "report-issue") {
    ReportIssueView()
}

// ...and open it with:
@Environment(\.openWindow) private var openWindow
// ...
openWindow(id: "report-issue")
```

That's the entire public API: `ClarityFeedback.configure(ingestURL:appToken:)`,
`ClarityFeedback.isConfigured`, and `ReportIssueView`.

### Handling the ingest token

`appToken` is scoped to one repo's issues, but it's still a credential —
don't commit it as a string literal the way the example above shows for
brevity. If it ships in your source, it ships in the built binary too
(extractable with `strings`) and in your git history if the repo is ever
made public.

Prefer pulling it in at build time instead, e.g. via an `.xcconfig` that
injects an `Info.plist` key (kept out of source control) and reading it back
at launch:

```swift
guard let appToken = Bundle.main.object(forInfoDictionaryKey: "ClarityFeedbackAppToken") as? String else {
    fatalError("Missing ClarityFeedbackAppToken — check your .xcconfig")
}
ClarityFeedback.configure(ingestURL: ingestURL, appToken: appToken)
```

Any equivalent scheme (keychain-provisioned, CI-injected build setting,
etc.) works just as well — the point is keeping the token out of source and
out of git history, the same way you'd handle a Sentry DSN or API key.

## What it does

`ReportIssueView` is a title + description form. On submit, it POSTs
`{title, body, appVersion, osVersion, deviceModel}` to the configured relay
URL with `Authorization: Bearer <appToken>`, then shows either a simple
"Thanks for the report!" confirmation, or an inline error with the option
to retry (there's no automatic retry or offline queue in v1 — if the POST
fails, the user sees why and can try again).

The confirmation deliberately doesn't link to the created GitHub issue —
that repo is your internal plumbing (and may be private), not something your
users should see. The issue's URL is logged via `OSLog` instead (subsystem
`com.xerodonia.ClarityFeedbackKit`, category `ReportIssueView`), so you can
still trace a report while developing.

`appVersion`/`osVersion`/`deviceModel` are gathered automatically —
`deviceModel` via `uname(2)` (a raw hardware identifier like `"iPhone15,3"`,
not a friendly name), so the package never imports UIKit.

## What it deliberately doesn't do (v1)

- **No screenshot/attachment support.** GitHub's Issues REST API has no
  first-party attachment endpoint; solving that cleanly needs blob storage
  (e.g. R2) on the relay. Deliberate v1 cut, not an oversight.
- **No local persistence or retry queue.** A failed submission just shows an
  inline error; the user re-submits manually.
- **No write-back.** This is GitHub → Clarity only, for now — closing the
  GitHub issue when the Clarity issue is marked complete is a possible
  future addition, not built yet.

## Testing

```bash
swift test
```

Uses Swift Testing with an injected `URLRequestPerforming` stub — no real
network access or relay needed to run the suite.
