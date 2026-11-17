# ClarityFeedbackKit: Plan

Written on 17 Nov 2026, when the docs moved into `Documentation/` (#901). The package was built and
hardened before it had a plan of its own; that work is summarised under "Done". The next stage is
not started.

## Goal

A tiny Swift package that lets an app's users send a bug report or idea, as a GitHub issue that
Clarity imports. It never holds a GitHub credential: it posts to the Clarity Feedback Relay with a
per-app ingest token, and shows users only fixed, harmless messages.

## Decisions

| Decision | Choice | Date |
|---|---|---|
| No "View on GitHub" link after sending (#434) | The repo is internal plumbing and may be private; the issue's URL is logged instead | 2026-09-30 |
| How a host supplies the token (#255) | `configure()` with no values: the relay URL from an obfuscated `Secrets.swift`, the token from the host's Info.plist via an uncommitted `.xcconfig` (Paul's design). It removed the old API, so 2.0.0 | 2026-11-12 |
| Errors shown to users (#680) | Three fixed messages; the relay's text goes to the log | 2026-11-12 |
| Redirects (#679) | Refused, so the token only ever goes to the relay | 2026-11-12 |
| Platforms | macOS 26 and iOS 26, matching Clarity's floor, not the usual 27 (`CLAUDE.md`) | 2026-11-12 |
| ClarityTesting | Linked into the test target, by URL | 2026-11-17 |
| Docs | In `Documentation/`, like every other repo (#901) | 2026-11-17 |

## Done

- 1.0.0: the form, the client and the relay contract (Aug–Oct 2026).
- 2.0.0 (tagged and pushed 12 Nov 2026): #679, #680, #255 and #257.

## Stages

### Stage 1: The 15 Nov audit's findings, and older security issues (not started)

- [ ] #899: an ephemeral session of its own, not `URLSession.shared`
- [ ] #900: log the relay's error text and redirect `Location` as private
- [ ] #256: refuse a non-`https` relay URL (the response-URL half went with #434)
- [ ] #875: keep the `Playgrounds` import and `#Playground` block out of release builds (a fix in
      obfuscate, then regenerate `Secrets.swift`)
- [ ] #435: the two suites that race on the global configuration

### Stage 2: The Readme for integrators

- [ ] #873: an "Upgrading from 1.x" section, including revoking any token that was ever in source
- [ ] #874: say that 2.0.0 only works with Xerodonia's relay

### Stage 3: Host apps move to 2.0.0

- [ ] Each host app adds the `.xcconfig` and the `ClarityFeedbackAppToken` key, then calls
      `configure()`. The first real submission also proves the relay end to end (relay #451).
- [ ] #434: Paul's check of the success screen in a host app

## Later

- Attachments and write-back to GitHub: deliberate cuts from v1 (Readme, "What it deliberately
  doesn't do").
- #871: regenerate the relay's GitHub token by 10 Feb 2027.
