---
name: ClarityFeedbackKit
description: A tiny Swift package that lets an app's users send a bug report or idea straight to the developer as a GitHub issue, which Clarity then imports automatically.
version: "1.0.0"
readmeUpdated: 2026-11-12
tags:
  - Package
---

# ClarityFeedbackKit

<img src="logo.png" alt="ClarityFeedbackKit logo: a white speech bubble containing a dark teal bug, on a teal background" width="128" height="128" align="left" hspace="16">

A tiny Swift Package: embed it in an app so its users can send a bug report
or idea straight to you, as a real GitHub Issue — which then gets pulled
into Clarity automatically by its GitHub importer.

```
Your app + ClarityFeedbackKit  →  clarity-feedback-relay  →  GitHub Issues  →  Clarity
        (this package)              (the relay repo)
```

The SDK never talks to GitHub directly and never holds a GitHub credential —
it POSTs to a relay you control, using a per-app **ingest token** (like a
Sentry DSN). See `clarity-feedback-relay`'s README for how to issue tokens.

<br clear="left">

## Requirements

macOS 26+ / iOS 26+, Swift 6.2+.

## Installation

Add it by URL (in Xcode: File › Add Package Dependencies…, or in a
`Package.swift`):

```swift
.package(url: "https://github.com/pdarcey/ClarityFeedbackKit", from: "2.0.0")
```

Then add the `ClarityFeedbackKit` library product to your **app** target.

Prefer the URL form over a local path for anything you commit: a
`.package(path: "../ClarityFeedbackKit")` dependency only resolves on a
machine with the same folder layout, so it breaks CI (including Xcode Cloud).
A local path is still handy for developing the package itself alongside a
host app.

## Usage

Configure once, early in app launch (e.g. in your `App`'s `init()`):

```swift
import ClarityFeedbackKit

init() {
    ClarityFeedback.configure()
}
```

`configure()` takes no values. The relay's endpoint is built into the package
(obfuscated, in `Secrets.swift`), and this app's ingest token comes from your
app's Info.plist (see "Setting up the ingest token" below). If the token is
missing, `configure()` logs a warning, leaves feedback unconfigured and returns
`false`, rather than crashing.

`configure()` is synchronous and thread-safe, so it's fine to call from an
`App`'s `init()` (which isn't main-actor-isolated) or anywhere else. Calling
it again replaces the previous values.

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

On macOS, the form's Cancel and Done buttons close it with `dismissWindow()`,
which is made for a window scene, not a sheet. Present it in its own `Window`
as shown above. On iOS they use `dismiss()`, which is what closes a sheet.

That's the entire public API: `ClarityFeedback.configure(bundle:)` (call it as
`configure()`), `ClarityFeedback.isConfigured`, `ClarityFeedback.appTokenInfoPlistKey`
and `ReportIssueView`.

### Setting up the ingest token

Every host app gets its token from an `.xcconfig` that is **never committed**.
There's no way to pass the token in code (since 2.0.0), so it can't end up in
source or git history.

1. Ask whoever runs the relay for this app's ingest token.
2. Create `Secrets.xcconfig` next to the project, and add it to `.gitignore`:

   ```
   // Secrets.xcconfig: NOT committed (it's in .gitignore)
   CLARITY_FEEDBACK_APP_TOKEN = <this app's ingest token>
   ```

3. In the project's Info tab, set it as the configuration file for Debug and
   Release (or `#include` it from an existing `.xcconfig`).
4. Add the Info.plist key `ClarityFeedbackAppToken` (a String) with the value
   `$(CLARITY_FEEDBACK_APP_TOKEN)`. Or, with a generated Info.plist, add the
   build setting `INFOPLIST_KEY_ClarityFeedbackAppToken = $(CLARITY_FEEDBACK_APP_TOKEN)`.
5. Call `ClarityFeedback.configure()` at launch.

A build without the `.xcconfig` (say, a fresh clone, or CI without the
secret) has an empty key, so `configure()` returns `false`. Use
`ClarityFeedback.isConfigured` to hide your "Report a Bug" entry point then:

```swift
if ClarityFeedback.isConfigured {
    Button("Report a Bug…", systemImage: "ladybug") { openWindow(id: "report-issue") }
}
```

`ReportIssueView` doesn't check configuration itself. An unconfigured
submission only tells the user "Feedback isn't set up in this app."

For CI, write the same `.xcconfig` from a CI secret before building.

The token still ships inside the app bundle, and a determined user can
extract it. That's accepted: the token can only create issues on one repo, the
relay rate-limits it and can revoke it per app, and no GitHub credential is
ever in a host app. The relay URL in `Secrets.swift` is only obfuscated too,
and this repo is public, so treat the URL as discoverable.

## What it does

`ReportIssueView` is a title + description form. On submit, it POSTs
`{title, body, appVersion, osVersion, deviceModel}` to the configured relay
URL with `Authorization: Bearer <ingest token>`, then shows either a simple
"Thanks for the report!" confirmation, or an inline error with the option
to retry (there's no automatic retry or offline queue in v1 — if the POST
fails, the user sees why and can try again).

That inline error is always one of three fixed messages (since 2.0.0, #680):
"Couldn’t send your report. Check your connection and try again." when the
request got no answer; "Feedback isn’t set up in this app." when `configure()`
hasn't succeeded; and "The feedback service couldn’t accept your report right
now. Try again later." for anything else, including the relay's rate limit.
The relay's own `error` text and the network error go to the log (category
`FeedbackClient`), never to the user, so nothing can reveal the GitHub repo.

Redirects are refused (#679): the report and token only ever go to the
relay's URL. A 3xx from the relay is a failure, and its `Location` is logged.

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
