# Somewhere — Design Vision

## The product in one sentence

**Somewhere is a quiet, local-first place for saving things before they have a place.**

It is for images, links, articles, text snippets, quotes, files, screenshots,
ideas, and small personal notes that resonate but do not belong in a folder,
board, task list, or formal note system yet.

> Just drag it to Somewhere.

## Product principles

1. **Save first; understand later.** Capture must be easier than deciding where
   something belongs.
2. **A messy stash is valid.** There are no required folders, tags, projects,
   deadlines, or inbox-zero expectations.
3. **Keep the reason, optionally.** A tiny annotation such as “liked the
   lighting” or “good UI reference” is often more valuable than categorization.
4. **Rediscovery matters as much as retrieval.** Search helps find known things;
   Shuffle and Time Travel help people encounter things they forgot they loved.
5. **The app is a utility, not a destination.** It should surface quickly,
   capture without ceremony, and get out of the way.
6. **Native behavior earns trust.** Interactions, motion, keyboard behavior, and
   visual materials should feel at home on macOS.

## What Somewhere is not

- Not a task manager.
- Not a conventional notes app.
- Not a bookmark manager.
- Not a file organizer.
- Not a productivity dashboard.
- Not Pinterest with private boards.

Avoid features that make users classify, clear, justify, or “manage” their
archive before saving an item.

## Experience model

Somewhere has three complementary surfaces.

### 1. Corner drawer — immediate capture

The signature interaction is a small floating drawer near the **upper-right
edge, just below the macOS menu bar**. It must not occupy the literal top-right
corner, which belongs to system menu items and Control Center.

When the pointer approaches the activation area during a drag:

1. A subtle Somewhere tab appears.
2. The tab softly expands into a translucent drop drawer.
3. The user drops the file, image, text, or URL.
4. The item is saved immediately and shown as a card.
5. An optional low-pressure note field appears; no organization is required.

The drawer should fade and slightly scale into view. It should fade away when
the pointer leaves, unless the user is interacting with it.

**Purpose:** “Drop it here.”

### 2. Menu-bar panel — quick access

The menu-bar icon opens a compact panel for:

- Stashing the clipboard.
- Writing or pasting a quick item.
- Dropping content directly into Somewhere.
- Seeing a few recent items.
- Opening the full archive.

**Purpose:** “Save something now.”

### 3. Full window — personal archive

The full window is a calm, resizable home for browsing the collection. It
contains search, recent items, Shuffle, and Time Travel. It is not a dashboard.

**Purpose:** “Find something—or rediscover something.”

## Browsing modes

### Recent

The default: items in reverse chronological order. Dates are visible because
the archive is also a record of attention over time.

### Shuffle

An intentional, joyful rediscovery mode—not merely a random sort toggle. It
mixes old and new saved items to surface forgotten references and memories.

### Time Travel

Browse a specific month or year: “What did I care about in June 2023?” This is
a core long-term expression of Somewhere’s value.

### Search

For known retrieval. Search titles, notes, saved text, URLs, and filenames.

## Visual direction

The visual language is **quiet editorial archive**: familiar macOS utility
design with a warm, personal undertone.

The desired feeling is:

> Finder’s trustworthiness + Apple Notes’ calm + a private museum drawer.

### Materials and color

- Use macOS vibrancy/material blur with an almost-white light-mode tint.
- Use genuine translucent dark materials in dark mode; do not merely invert
  white cards.
- Let saved content—especially images—bring most of the visual color.
- Use one restrained accent color at most, never a bright product-color system.
- Prefer soft neutral grays and charcoal text to stark pure black.

### Form

- Floating panels: soft 22–26px corner radius.
- Use a nearly imperceptible one-pixel edge to separate material from light
  backgrounds.
- Use a broad, low-opacity, atmospheric shadow rather than a web-card shadow.
- Keep spacing compact but breathable. This is a Mac utility, not an oversized
  web interface.

### Typography and controls

- Use SF Pro/system typography and native Dynamic Type behavior.
- Headings are clear but modest; metadata is quiet and secondary.
- Use SF Symbols sparingly.
- Prefer native controls, contextual menus, keyboard shortcuts, and familiar
  macOS segmented controls when they genuinely fit.
- The full window uses a normal macOS title bar and standard traffic lights.

### Item cards

Items should lead with their actual content rather than an abstract type label:

- Images lead with a thumbnail.
- Text leads with the saved text.
- Links lead with title/domain and later may have a thumbnail.
- Files lead with a filename and native file icon.
- Optional notes look like small personal captions, never compulsory metadata.

Dates and source hints remain present but subordinate.

## Motion and tone

- Panels surface with a 160–220ms fade and slight scale/translation.
- No bouncy animation, celebratory confetti, or intrusive notifications.
- A successful save receives subtle, satisfying confirmation.
- The interface should feel present when invited and invisible when not needed.

Quiet does not mean sterile. Warmth comes from materials, content, motion, and
the user’s own annotations—not decorative visual noise.

## Capture methods

Priority capture paths:

1. Upper-right corner drawer for drag-and-drop.
2. Global keyboard shortcut for clipboard capture / quick capture.
3. Menu-bar icon and menu-bar drop target.
4. Direct dropping into the full app window.
5. Later: macOS Share extension and Finder Quick Action (“Add to Somewhere”).

All capture paths should lead to the same simple outcome: an item is safely in
the stash, optionally accompanied by a note.

## Design anti-patterns

Do not turn Somewhere into:

- A dense productivity app with counts, status chips, and task framing.
- A folder tree or mandatory tagging workflow.
- A tile-heavy social feed or Pinterest clone.
- A generic SaaS dashboard with large cards and exaggerated spacing.
- A fake-paper/scrapbook aesthetic.
- A glossy, over-animated “future glass” interface.

The target is polished utility: white/translucent, soft, restrained, native,
and quietly memorable.

## Decision test

Before adding a feature or visual treatment, ask:

> Does this make saving something easier than deciding where it belongs?

If yes, it likely belongs in Somewhere. If it makes the user organize, clear,
classify, or explain their archive, it likely does not.
