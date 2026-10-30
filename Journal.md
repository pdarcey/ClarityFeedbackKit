# ClarityFeedbackKit — Journal

## The Big Picture

Picture this: Paul ships a handful of small Mac/iOS apps — RomanX, BorderMakerV2, and whatever comes next — and every one of them has the exact same missing feature. A user hits a bug, or has an idea, and has no way to tell him short of finding his email address themselves. `ClarityFeedbackKit` is the fix, packaged once so it never has to be built twice: drop it into an app, call one setup function, present one SwiftUI view, and users get a proper "Report a Bug" form that turns into a real GitHub Issue — which then flows straight into Paul's own issue tracker, Clarity, without him lifting a finger.

The trick is what the SDK *doesn't* do. It never talks to GitHub directly, and it never holds a credential that could write to Paul's GitHub account. It talks to a relay he controls (`clarity-feedback-relay`, a separate tiny Cloudflare Worker) using a scoped-down per-app token — the same shape as a Sentry DSN or a PostHog project key. If that token ever leaked out of a shipped app, the worst it could do is create issues on one repo. The real GitHub PAT never leaves the relay.

## Architecture Deep Dive

Think of it like a hotel's guest-comment card system. The guest (end user) fills out a card (`ReportIssueView`) and drops it in a box (`FeedbackClient` POSTs it to the relay). The box only ever goes to the hotel's own back office (the relay), never straight to the manager's personal inbox (GitHub) — the back office is the only one with a key that can actually file something with management. The guest never sees that key, never needs to.

- **`ClarityFeedback`** is the front desk: one `configure(ingestURL:appToken:)` call, once, at app launch. It stores the configuration behind a `Synchronization.Mutex` rather than `@MainActor` isolation — deliberately, because a SwiftUI `App`'s `init()` isn't main-actor-isolated, and forcing every caller onto the main actor just to set two strings would be an odd thing to demand of them.
- **`ReportIssueView`** is the comment card itself — title, description, an automatic footer showing app version/OS/device model (gathered without ever importing UIKit — more on that below).
- **`FeedbackClient`** is the only thing that actually talks to the network — one POST, JSON in, JSON out. It's internal; host apps never see it directly.

## The Codebase Map

- `ClarityFeedback.swift` — the public configuration surface.
- `URLRequestPerforming.swift` — the network seam (`URLSession` conforms for free) that makes `FeedbackClient` testable without a real network call.
- `FeedbackClient.swift` — builds the request, sends it, interprets the response.
- `FeedbackSubmission.swift` — the two wire DTOs, both `Codable` (both directions genuinely needed — see below).
- `DeviceInfo.swift` — app version / OS version / device model, gathered without UIKit.
- `ReportIssueView.swift` + `ReportIssueContent.swift` + `ReportForm.swift` + `ReportIssueToolbar.swift` + `SubmitButton.swift` + `SubmissionSuccessView.swift` + `SubmissionState.swift` + `FeedbackMetadataFooter.swift` — the SwiftUI form, deliberately split into one type per file/concern rather than one big view with computed properties (see "Aha!" below).

## Tech Stack & Why

- **Swift Package Manager, no Xcode project.** This has to be added as a dependency to unrelated apps in unrelated repos — a local-path package (like `ClarityStorage`) can't do that; this one needs to live somewhere host apps can point at directly. It now does: it's on GitHub at `pdarcey/ClarityFeedbackKit`, tagged `1.0.0`, and hosts depend on it by URL.
- **macOS 26 / iOS 26 floor.** Not the plan's original placeholder (`.v14`/`.v17`) — Paul's own call, matching Clarity's own floor, since every host app is getting bumped to that anyway as the SDK gets added.
- **Swift Testing, not XCTest.** Matches every other Swift package in this ecosystem (`ClarityStorage`).
- **`Synchronization.Mutex` over `@MainActor`.** The one real architectural decision in this package — see below.

## The Journey

### `Mutex`, Not `@MainActor` (24 August 2026)

The obvious way to store "has `configure` been called yet, and with what" is an `@MainActor`-isolated class, matching every `@Observable` type elsewhere in Paul's apps. It's also wrong here: `configure(...)` needs to be callable synchronously and unconditionally from a SwiftUI `App`'s `init()`, which is *not* main-actor-isolated, and there's no reason a host app should have to wrap its very first line of setup in `Task { @MainActor in }` just to call a function that sets two strings. `Synchronization.Mutex<Configuration?>` gives the same safety guarantee without demanding actor isolation from every caller — a deliberate, narrow exception to "always `@MainActor`," made because the alternative would make the SDK's simplest possible use case awkward for no real benefit.

### Caught Myself Mid-Violation: Computed View Properties

Partway through writing `ReportIssueView`, the natural thing to reach for was `@ViewBuilder private var content: some View` and `@ToolbarContentBuilder private var toolbarContent: some ToolbarContent` — split the body up without leaving the file. That's exactly the pattern the project's own conventions rule out: view logic broken up with computed properties instead of real `View`/`ToolbarContent` types. Caught it before it shipped and re-extracted into `ReportIssueContent` and `ReportIssueToolbar` as their own files instead. Worth remembering: a convention that feels like unnecessary ceremony mid-task ("it's just one more computed property") is usually there because the alternative doesn't scale — a form that grows a few more states would have turned that one computed property into an unreadable nested `if`/`switch` tower.

### Codable Needs Both Directions More Often Than It Looks Like It Does

`FeedbackSubmission` only ever gets *encoded* in production (it's the outgoing POST body); `FeedbackSubmissionResponse` only ever gets *decoded* (it's what comes back). Declaring them `Encodable`-only and `Decodable`-only respectively looked like the more precise, honest choice — until the test suite needed the opposite direction of each: decoding a captured `FeedbackSubmission` back out to verify what was actually sent, and encoding a `FeedbackSubmissionResponse` to build a scripted mock response. The build caught both mismatches immediately and unambiguously; the fix was just making both fully `Codable`. Lesson: "this type is only ever used in one direction in production" is a fact about production, not a reason to narrow the type's conformance — tests routinely need the mirror-image operation.

### A Two-Character Property Name Tripped SwiftLint, and the Fix Turned Out Better Than the Original

The relay's response JSON uses `"ok"` as its success-flag key — short, conventional, fine on the wire. As a Swift property name it's two characters, below SwiftLint's `identifier_name` minimum, and for good reason: `ok` reads as almost meaningless out of context, compared to `succeeded`. Renamed the Swift-side property to `succeeded` with an explicit `CodingKeys` mapping back to `"ok"`, so the wire contract never had to change and the relay never needed touching. A small reminder that a linter complaint about naming is sometimes pointing at a real readability problem, not just a rule to silence.

### First Real Use Found What No Unit Test Could (24 August 2026)

Everything above passed `swift test` cleanly and built on both macOS and iOS. None of that caught what happened the moment Paul actually wired the package into RomanX: `.sheet(isPresented:)` and `@Environment(\.dismiss)` compile perfectly fine on macOS and are simply the wrong idiom there — a sheet reads as a modal interruption for something that should be its own window, and `dismiss()` silently does nothing to a `Window` scene. Nothing about that is a *type error*; it's a platform-convention mismatch, and the only thing that finds those is a real app on a real platform actually presenting the view. Fixed by making the toolbar's dismiss action platform-conditional (`dismissWindow()` on macOS, `dismiss()` on iOS) and rewriting the README's usage example to show both platforms side by side instead of a single sheet snippet — since that one-sided example is exactly what had pointed the first integration the wrong way.

The same integration also surfaced that a bare `TextEditor` has no visible border or background of its own — invisible in a `Form`, especially bad in dark mode — fixed with a `.thinMaterial` background and a subtle stroke border around it.

### Weekly Docs Pass Found One Real Gap, One Stale Comment (25 August 2026)

The scheduled docs-freshness sweep landed on a quiet week — `HEAD` was
already the commit that last touched the docs, so there was no drift from
new code to chase. But "nothing changed recently" isn't the same as
"nothing to fix": a standing Clarity issue had already flagged that
`configure(ingestURL:appToken:)`'s only example (`appToken: "<this app's
ingest token>"`) shows the token as a bare string literal, with nothing in
the README steering integrators away from hardcoding it — exactly the
mistake a later audit of RomanX turned up for real. Added a "Handling the
ingest token" section to the README with a build-setting/`Info.plist`
pattern instead. Small reminder that a docs pass isn't just "did the prose
fall out of sync with the code" — the code and the docs can agree with each
other and still both be quietly steering people toward a bad practice.

Also found that `ReportIssueView`'s own doc comment still says to present
it "as a sheet," a leftover from before the macOS-vs-iOS windowing fix
(a81219b) made that platform-conditional everywhere else, including the
README. Couldn't fix it directly — this pass is scoped to
`README.md`/`Journal.md`/`CLAUDE.md` only, and that line lives in
`Sources/` — so it's filed as a Clarity issue instead of silently ignored.

### "Why Am I Being Sent to GitHub?" (30 September 2026)

Real users sending real reports turned up something that looked perfectly
sensible from the developer's chair: the success screen had a "View on
GitHub" button linking to the freshly created issue. For Paul, handy. For
someone who just wanted to say "the export button is broken", it's a door
into the kitchen — a developer tool they never asked about, on a site they
may not have an account for, pointing at a repo that might well be private
and 404 on them anyway. It's the restaurant equivalent of handing a diner
the order ticket from the kitchen printer.

The fix was mostly subtraction: the link is gone, and `SubmissionState`'s
`.succeeded(URL)` became plain `.succeeded`, since the URL had only ever been
riding along in the state to feed that one link. The URL didn't vanish,
though — it now goes to `OSLog`, which is where developer-facing
information belongs. Nice side effect: half of an open security issue
(rendering an unvalidated relay-supplied URL as a tappable link) evaporated
along with it. Code you delete can't be exploited.

While in there, fixed a small title bug: the navigation title flipped to
"Feedback sent" on *any* state other than `.idle` — including while the
request was still in flight, and after it had failed. Comparing against
`.succeeded` instead of `!= .idle` says what we actually mean. Lesson:
"not the starting state" and "the success state" are only the same thing
when there are exactly two states, and there were four.

The test run also coughed up a one-off failure unrelated to the change —
two suites racing on the global `ClarityFeedback` configuration, since
`.serialized` only serialises within a suite, not across them. Filed rather
than fixed, to keep this change focused.

### The README Was Promising a Safe It Didn't Have (4 October 2026)

Another quiet week for code (nothing new since 30 September), so this
docs sweep checked the integration story itself, line by line. Two things
turned up.

First, the "Handling the ingest token" section suggested that moving the
token out of a string literal and into an `.xcconfig`-fed `Info.plist` key
would stop it being extractable from the binary. It doesn't. An `Info.plist`
value ships inside the app bundle just like a literal does. It's a bit like
moving the spare key from under the doormat to under the pot plant: it's
out of git history, which is what actually matters, but anyone who goes
looking will still find it. The real protection was there all along in the
design: the token can only create issues on one repo, and the relay can
revoke it. The README now says that honestly instead of implying the token
is hidden.

Second, the README's sample code called `fatalError` when the token was
missing. That would crash any contributor's build without the secret
`.xcconfig`. It also ignored `ClarityFeedback.isConfigured`, which exists
for exactly this case. The README now shows the gentler pattern: skip
`configure`, then hide the "Report a Bug" button. There's a less obvious
reason this matters. `ReportIssueView` doesn't check configuration itself,
so an unconfigured submission shows end users the developer-facing message
"ClarityFeedback.configure(…) hasn't been called yet." Gating the entry
point keeps that message away from users.

Smaller fix: `CLAUDE.md` listed `FeedbackClient.SubmissionError` as public
API. It isn't, because it's nested inside the `internal` `FeedbackClient`,
and Swift won't make a nested type more visible than the type containing
it. The README had it right; the two now agree. Also tidied this journal's
own layout: the last two Journey entries had ended up under
"Engineer's Wisdom", so they're back where they belong.

### A Logo, and Two Halves of One Docs Update (13 October 2026)

The package got a logo: a bug inside a speech bubble, which is about as literal as a logo for "tell the developer about a bug" can be. It lives at the repo root as `logo.png` and `logo.svg` and shows under the README title.

A small process lesson came with it. The README already had uncommitted edits from the 4 October docs sweep, so committing "the logo line" meant committing those too, while the matching `CLAUDE.md` and `Journal.md` edits stayed behind. For a few minutes one docs update was split across a commit and a working tree. Paul had them committed together straight after. Docs that were written together should be committed together; a half-committed docs pass is a small lie about what the repo knows.

### The Package Moved Out, and the README Was Still Giving the Old Address (18 October 2026)

Another quiet week for code: nothing has changed under `Sources/` since 30 September. What *had* changed was where the package lives. It's on GitHub now, with a `1.0.0` tag sitting on `HEAD`. The README's Installation section hadn't caught up. It still led with `.package(path: "../ClarityFeedbackKit")` and had the URL form commented out, "once pushed somewhere". That's like a café that's moved to a new street but still has the old address on its menus. The regulars find it fine; anyone new turns up at an empty shopfront.

For a package, the old address does real damage. A local path resolves only on a machine whose folders happen to line up the same way, so a host app that copied the snippet would build on Paul's Mac and fail everywhere else, Xcode Cloud included. The URL form is now the main instruction, with the local path kept as a note for working on the package alongside a host app. The README also now spells out two things a consumer would otherwise have to read the source to learn: `configure` is safe to call from a non-main-actor `App.init()`, and the configuration is only read when a report is submitted.

The lesson: once a package has a real release, the version tag is how anything actually ships. Pushing to `main` changes nothing for the apps that depend on it until a new tag is cut. That's now written down in `CLAUDE.md`, so a future change to `Sources/` doesn't quietly sit on `main` while the hosts carry on with `1.0.0`.

## Engineer's Wisdom

- **A credential's scope should match its exposure.** This package never holds anything more powerful than a single per-app token that can only create issues on one repo, because it's the one component of the system that actually ships to end-users.
- **Match an existing pattern in the surrounding codebase before inventing a new one**, even across a package boundary — `FeedbackClient`'s injectable `session`/`configurationProvider` shape deliberately mirrors `Database.importGitHubIssues(for:importer:tokenProvider:)` in the sibling Clarity project, for the same reason: consistency lets anyone who already knows one codebase immediately understand the other.
- **A green test suite proves the internals are correct, not that the package is finished.** The platform-idiom bugs here (sheet/dismiss on macOS, invisible TextEditor) are exactly the class of thing no unit test written *for* the package would ever catch — only a real host app, on a real platform, actually presenting the thing.
- **A client-side secret is never really secret, so plan around that.** Keep it out of git history, but design the system so that losing it doesn't matter much. Docs should say which of those two protections you're actually getting.

## If I Were Starting Over...

Would build the SDK's usage documentation *with* a platform split from the very first draft, rather than writing the obvious single-platform example first and fixing it after a real integration found the gap. The bug wasn't really in the code — `ReportIssueView` itself never assumed a presentation style — it was in the README steering the very first integration toward the wrong one.
