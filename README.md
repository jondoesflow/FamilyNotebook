# Notebook

A beautiful notebooks app for Jon & Katie: native SwiftUI, synced and shared through your own iCloud. No server, no accounts, nothing to pay for beyond the Apple Developer membership.

Inspired by notebook.tizon.in: warm paper, serif type, an illustrated cover for every notebook, and a shelf for the ones you've finished with.

## What's inside

- **Notebooks with covers**: 76 illustrated covers in 12 themes (landscapes, travel, city, cooking, study & work, plants, sports, the seasons, animals, patterns), 16 plain bookcloth colours, or one of your own photos. The artwork is SVG in `scripts/covers/art.py`; `python3 scripts/covers/build.py` re-renders it into the asset catalog.
- **A page that stays out of the way**: rich text with bold, italic, underline, strikethrough, headings and quotes. Tap **+** above the keyboard to add a sketch, a photo, a divider, a code block, a bullet list or a tap-to-tick checklist.
- **Notes as sheets of lined paper** in each notebook, with a big **Write** button.
- **Every version**: each editing session is saved, so you can see who wrote what and restore any earlier version.
- **Move** a note to another notebook, even between your own and shared ones.
- **By hand**: Apple Pencil / finger sketches with PencilKit, plus photos (re-encoded, so their location is removed).
- **Journal notebooks**: one entry a day, a streak, days-this-year, a calendar and a daily prompt.
- **Trip notebooks**: a countdown, an itinerary by day with "Up next", spending split between the two of you, who owes whom, and **Settle**.
- **Write together**: share any notebook with one tap via iCloud. Both of you can edit, and you can see who changed what.
- **Behind a PIN**: lock any notebook or note with a 4–8 digit PIN you both know. After you've entered it once on a phone, Face ID opens it there.
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
