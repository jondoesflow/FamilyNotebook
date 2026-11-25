# Notebook

A beautiful notebooks app for Jon & Katie: native SwiftUI, synced and shared through your own iCloud. No server, no accounts, nothing to pay for beyond the Apple Developer membership.

Inspired by notebook.tizon.in: warm paper, serif type, an illustrated cover for every notebook, and a shelf for the ones you've finished with.

## What's inside

- **Notebooks with covers**: 16 illustrated covers drawn in code (Midnight, Lemons, Monstera, Waves, Map…) or one of your own photos.
- **A page that stays out of the way**: rich text with bold, italic, underline, strikethrough, headings, quotes, bullets and tap-to-tick checklists, from a bar above the keyboard.
- **By hand**: Apple Pencil / finger sketches with PencilKit, plus photos (re-encoded, so their location is removed).
- **Journal notebooks**: one entry a day, a streak, days-this-year, a calendar and a daily prompt.
- **Trip notebooks**: a countdown, an itinerary by day with "Up next", spending split between the two of you, who owes whom, and **Settle**.
- **Write together**: share any notebook with one tap via iCloud. Both of you can edit, and you can see who changed what.
- **Private by default**: lock any notebook behind Face ID.
- Pinned notes, search across everything, a 30-day trash, Markdown export, and light/dark/system themes. Works on iPhone and iPad.

## How it's built

| | |
|---|---|
| UI | SwiftUI (iOS 18+), New York serif, custom paper palette, zoom transitions |
| Data | Core Data + `NSPersistentCloudKitContainer` with a private and a shared store |
| Sharing | `CKShare` via `UICloudSharingController`; notes, photos, plans and expenses move with the notebook |
| Editor | `UITextView` with runs stored as JSON (`RichText.swift`) |
| Project | `project.yml` (XcodeGen). There's no `.xcodeproj` in git; CI generates it |
| CI/CD | `.github/workflows/ios.yml` + `fastlane/Fastfile` (match → gym → TestFlight) |

```
FamilyNotebook/
  App/            app entry, AppDelegate/SceneDelegate (accepting shares)
  Data/           Core Data model, persistence & sharing, helpers (journal/trip maths)
  Design/         theme, covers
  Features/       Home, Notebook, Journal, Trip, Note editor, Sharing, Settings, Onboarding
```

## Publishing

See **[docs/PUBLISHING.md](docs/PUBLISHING.md)** for step-by-step TestFlight setup from a Windows PC or phone. No Mac needed.
