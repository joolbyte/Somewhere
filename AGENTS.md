# Somewhere — Agent Guide

## Product intent

Somewhere is a local-first native macOS stash for saving things before they have
a place: images, links, articles, quotes, files, screenshots, text snippets,
ideas, and optional personal notes.

The governing product principle is:

> Make saving something easier than deciding where it belongs.

Read [DESIGN.md](DESIGN.md) before making product, UX, visual, or architectural
decisions. Treat it as the source of truth for the product vision.

## Technical baseline

- Native macOS app written in Swift.
- SwiftUI for app UI; use AppKit only when native utility behavior requires it
  (for example: floating panels, menu bar, edge/corner interactions, or
  cross-app drag and drop).
- SwiftData stores local item metadata.
- App-owned files/images will live in Application Support; never rely only on
  references to user files that may disappear.
- Minimum supported OS: macOS 14.0.
- Keep the app local-first. Do not introduce accounts, cloud sync, analytics,
  or AI dependencies without an explicit product decision.

## UX guardrails

- Do not add required folders, tags, projects, deadlines, or task status.
- Do not frame the archive as an inbox to clear or a productivity system to
  maintain.
- Capture should be immediate; notes are optional and personal.
- Search serves retrieval; Shuffle and Time Travel serve rediscovery.
- Preserve macOS conventions: SF Pro, SF Symbols, native controls, keyboard
  shortcuts, contextual menus, materials, and accessible behavior.
- The visual target is quiet editorial archive, not generic SaaS, Pinterest, or
  a playful scrapbook.

## Engineering practices

- Keep changes focused and small; avoid speculative features.
- Add SwiftUI previews for new reusable views where practical.
- Verify changes with `xcodebuild -project Somewhere.xcodeproj -scheme Somewhere -configuration Debug build`.
- Use `apply_patch` for source edits and preserve unrelated worktree changes.
- Do not commit build outputs, DerivedData, `xcuserdata`, or credentials.
- Update DESIGN.md when a deliberate product or visual decision changes.

## Near-term implementation order

1. Reliable text, URL, image, and file capture with local persistence.
2. App-owned file storage and previews.
3. Search, Shuffle, and date-based archive browsing.
4. Menu-bar and keyboard capture refinements.
5. Upper-right drag-to-stash drawer, built from an AppKit prototype and tested
   across normal, full-screen, and multi-display use.
