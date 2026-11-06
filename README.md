# Tora Basic Rule

A technical, compact design system for 16:9 decks. One typeface, one accent, hairlines instead of shadows, tabular numerals everywhere.

```
design.md              the spec — tokens + rules (read this first)
tokens.css             the same tokens as CSS variables + primitives
deck-template.html     7-slide 16:9 template using them (open in a browser)
fonts/                 Plus Jakarta Sans variable woff2 (Latin subset, self-hosted)
shots/                 preview renders of the template + deck.pdf
archive/               retired files (video-era frame.md, palette study)
```

## Use it

**Look at the deck**

Open `deck-template.html` in a browser. Arrow keys or the buttons move between slides; `P` prints. Jump straight to a slide with `?slide=5` in the URL. The stage scales to fit any window.

**Export a PDF**

Press `P` in the browser, or headless:

```
msedge --headless=new --no-pdf-header-footer --print-to-pdf="deck.pdf" "file:///C:/.../deck-template.html"
```

Each slide becomes one 1920×1080 page.

**Start a new slide**

Copy a `<section class="slide">` block. Keep the structure: `padding: 72px`, content inside `.cols` (12 columns, 20px gutter), `.foot` last. Use the type classes (`.t-display`, `.t-h1` … `.t-micro`) — never raw `font-size`. Use `data-theme="dark"` on a slide to switch it to the dark token set.

**Start a new artifact**

```html
<link rel="stylesheet" href="tokens.css">
```

Then use `var(--tora-bg)`, `var(--tora-fg)`, `var(--tora-border)`, `var(--tora-signal)` instead of hex values. If a value you need is missing, it belongs in the spec first — add it to `design.md` and `tokens.css` together.

## The five laws

1. **One accent moment per slide.** Signal Orange is a signal, not a theme. A rule, one active row, one active path, one key figure.
2. **Hairlines, never shadows.** 1px for content, 1.5px for structure. There is no elevation in this system.
3. **One typeface, extreme contrast.** Plus Jakarta Sans only; 300 ↔ 800 carries hierarchy. Sentence case, negative tracking on display.
4. **Numbers are tabular.** Any column, stat, year or page number gets `font-variant-numeric: tabular-nums`.
5. **The grid is the decoration.** 1920×1080, 72px margin, 12 columns, 8px baseline. Nothing floats between columns.

## Change the system

- **Swap the accent** — change `--tora-accent`, `--tora-accent-text`, `--tora-accent-wash` and the `--tora-accent-100…500` ramp in `tokens.css`, and the matching `colors:` block in `design.md`. Check contrast: accent text on paper must stay ≥ 4.5:1.
- **Dark** — `data-theme="dark"` on a slide or container. Dark is a whole-slide alternate (cover, section breaks, low-light rooms), never a panel inside a light slide.
- **Type sizes** — the ramp is in `tokens.css` (`--tora-fs-*`) and `design.md` (`typography:`). Keep at least one 300→800 jump per slide.

## Known gaps

- **Decks only.** No A4 document, social, web UI or print spec yet. Adding one needs a new grid, not a new palette.
- **Latin subset only.** `fonts/PlusJakartaSans-Variable.woff2` covers basic Latin. Non-Latin glyphs fall back per-glyph; add the relevant Google subset and a second `@font-face` if a deck needs it.
- **No motion spec.** If decks become animated, that is a separate layer.
- **The prohibition list is provisional.** "Don't" in `design.md` was written as a default — strike anything you actually want to allow.
