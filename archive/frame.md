---
version: alpha
name: Daylight — Frame (video / frame layer)
description: >
  Frame-scale design system for a personal / portfolio brand. Video-first: the unit is the frame
  (1920×1080). Warm off-white paper ground, one family (Plus Jakarta Sans, 300–800), soft corners
  (8 / 16 / 24 / pill), 1px hairlines instead of heavy borders, and blurred low-opacity shadows
  instead of hard offsets. Clay is the only semantic accent; butter, sage and sky are seasonal
  tints. Voice is calm, human and confident — generous space, few words, large type.
unit: the frame — 1920×1080 (16:9) primary
principle: warm paper · one family · soft edges · one accent · space over decoration

colors:
  paper: "#FAF7F2"
  surface: "#FFFFFF"
  ink: "#1F1C19"
  ink-soft: "#6B645C"
  ink-faint: "#9A9289"
  line: "#E6DFD5"
  clay: "#E0785F"
  butter: "#F2C97D"
  sage: "#A9C3A5"
  sky: "#A3C4E3"
  blush: "#F6DFD7"
  shadow-soft: "rgba(31,28,25,0.06)"
  shadow-lift: "rgba(31,28,25,0.10)"

typography:
  # — reading ramp (weight 300–600) —
  body:        { fontFamily: "Plus Jakarta Sans", cqw: 1.05, weight: 400, lineHeight: 1.65 }
  body-strong: { fontFamily: "Plus Jakarta Sans", cqw: 1.05, weight: 600, lineHeight: 1.5 }
  lede:        { fontFamily: "Plus Jakarta Sans", cqw: 1.55, weight: 300, lineHeight: 1.5 }
  caption:     { fontFamily: "Plus Jakarta Sans", px: 18, weight: 500, lineHeight: 1.4 }
  label:       { fontFamily: "Plus Jakarta Sans", px: 16, weight: 700, tracking: "0.12em", upper: true }
  eyebrow:     { fontFamily: "Plus Jakarta Sans", px: 18, weight: 700, tracking: "0.16em", upper: true }
  # — display ramp (weight 700–800, sentence case) —
  headline:    { fontFamily: "Plus Jakarta Sans", cqw: 3.2, weight: 700, lineHeight: 1.10, tracking: "-0.02em" }
  display:     { fontFamily: "Plus Jakarta Sans", cqw: 4.8, weight: 800, lineHeight: 1.02, tracking: "-0.03em" }
  hero:        { fontFamily: "Plus Jakarta Sans", cqw: 7.2, weight: 800, lineHeight: 0.95, tracking: "-0.04em" }
  closing:     { fontFamily: "Plus Jakarta Sans", cqw: 6.0, weight: 800, lineHeight: 1.00, tracking: "-0.035em" }
  stat-number: { fontFamily: "Plus Jakarta Sans", cqw: 5.6, weight: 800, lineHeight: 1.00, tracking: "-0.03em", tabular: true }
  quote:       { fontFamily: "Plus Jakarta Sans", cqw: 3.4, weight: 300, lineHeight: 1.30, tracking: "-0.01em" }

spacing:
  pad: "5cqw"
  section-gap: "4cqw"
  gap-lg: "3cqw"
  gap-md: "2cqw"
  gap-sm: "1cqw"
  card-pad: "1.8cqw"
  stack: "1.4"

components:
  card:
    backgroundColor: "{colors.surface}"
    border: "1px solid {colors.line}"
    rounded: "24px"
    shadow: "0 6px 18px {colors.shadow-soft}"
    description: "Default container for projects, stats, notes. White on paper is the only lift needed."
  tint-card:
    backgroundColor: "{colors.paper} / {colors.blush} / {colors.sage}"
    border: "1px solid {colors.line}"
    rounded: "24px"
    shadow: "none"
    description: "Flat alternative for dense groups; never put a shadow on a tint card."
  chip:
    backgroundColor: "{colors.surface}"
    border: "1px solid {colors.line}"
    rounded: "9999px"
    typography: "{typography.label}"
    description: "Pill for tags, skills, meta. 0.5cqw × 1.2cqw padding."
  chip-accent:
    backgroundColor: "{colors.blush} / {colors.butter} / {colors.sage}"
    border: "none"
    rounded: "9999px"
    typography: "{typography.label}"
    description: "Filled pill for status or the one highlighted tag. No border, no shadow."
  portrait:
    border: "3px solid {colors.surface}"
    rounded: "50%"
    shadow: "0 12px 32px {colors.shadow-lift}"
    description: "Photo circle. Sizes 240 / 320 / 420px. Ring is surface, not accent."
  stat-card:
    backgroundColor: "{colors.surface}"
    border: "1px solid {colors.line}"
    rounded: "24px"
    shadow: "0 6px 18px {colors.shadow-soft}"
    typography: "{typography.stat-number} + {typography.label}"
    description: "Number in ink or clay, label in ink-soft. Tabular numerals always on."
  underline:
    backgroundColor: "{colors.clay}"
    rounded: "9999px"
    size: "64×3 (96×3 on cover)"
    description: "The signature rule. Sits under an eyebrow or under the last line of a headline."
  highlight:
    backgroundColor: "{colors.butter}"
    rounded: "8px"
    padding: "0.08em 0.22em"
    description: "Inline emphasis behind a word — replaces bold/italic/color. One per frame."
  dot:
    backgroundColor: "{colors.clay}"
    rounded: "50%"
    size: "8px"
    description: "Bullet / status / eyebrow mark. The only decorative dot."
  atmosphere:
    background: "paper + 1 radial wash (clay or butter at 6–10% opacity, off-canvas corner) + 2% grain"
    description: "Optional softening layer. Never both a wash and a pattern."
---

# Daylight — Frame (video / frame layer)

## Overview

Daylight is a **calm personal-brand system built on warm paper and one typeface.** The ground is
never pure white — `{colors.paper}` at #FAF7F2 carries a faint warmth that makes screenshots and
portraits sit naturally. Everything is separated by a **1px `{colors.line}` hairline** rather than a
border or a heavy shadow; depth is a **soft blurred shadow at 6–10% ink**, never a hard offset.

The voice is a single family at two extremes: **Plus Jakarta Sans** at 300 for long, quiet copy and
at 700–800 for statements. That 300 ↔ 800 gap is the entire hierarchy — there is no second font,
no italic display voice, no condensed chrome. Color is rationed: **clay** is the one semantic
accent (rules, status, the single highlighted word); butter, sage, sky and blush are **seasonal
tints** used as fills at most two at a time.

**Key characteristics at frame scale:**

- **Warm paper ground**, white surfaces, 1px hairlines — no pure-black-on-pure-white.
- **Plus Jakarta Sans only**, 300 ↔ 800 weight contrast, sentence case, negative-tracked display.
- **Soft geometry** — 8 / 16 / 24px radii plus pills; nothing sharp, nothing fully circular except portraits and dots.
- **One clay accent**, tints as fills; type stays ink or ink-soft.
- **Blurred, low-opacity shadows** on white cards only; tint cards and chips are flat.
- **Space is content** — wide margins, 3–5 elements per frame, one idea per frame.

## The Frame

### Frame Craft Bar

Four eyeball tests before any structural check:

- **Squint** — one element (headline, portrait, or stat) dominates at **3–6×** its nearest neighbor.
- **Silence** — declarative frames hold **3–5 elements**; one image, one headline, one support line is a complete frame.
- **Restraint** — one clay moment per frame; at most two tints; no second font; no heavier than 1px borders.
- **Reference** — aim at a **printed portfolio monograph / warm stationery set**; failure looks like a **generic SaaS dashboard with default blue and 16px body copy**.

- **Primary:** 1920×1080 (16:9). Author display sizes in **`cqw`** (`px ÷ 1920 × 100 = cqw`).
- **Safe area:** `pad` = 5cqw (96px) on all edges; keep type inside it, let images bleed if they must.
- **Container law:** the frame root sets `container-type: size`; all frame-relative units are `cqw`/`cqh`, never `vw`. Radii are shape and stay in px.

## Colors

`{colors.paper}` is the ground; `{colors.surface}` is reserved for white cards; `{colors.ink}` is
type, `{colors.ink-soft}` secondary copy, `{colors.ink-faint}` meta only. `{colors.line}` draws
every hairline.

`{colors.clay}` is the **only semantic color** — use it for the underline rule, the status dot, a
single key word, and the primary stat. **Butter, sage, sky, blush are tints**, never type colors on
headlines; they fill chips and tint cards. Max two tints per frame, and never clay + three others.
No new hex values at authoring time.

## Typography

One family, two registers. The **reading register** is weight 300–400 at `lede` / `body`, 600 at
`body-strong` for a single emphasized phrase, and `label` / `eyebrow` uppercase at 0.12–0.16em
tracking. The **statement register** is 700–800, sentence case, negative-tracked: `headline` 3.2cqw
→ `display` 4.8cqw → `hero` 7.2cqw.

- **Legibility floor:** any load-bearing line ≥ **1.05cqw** (≈20px). `caption` (18px) and `label` (16px) are chrome only.
- **Fit to measure:** cap a headline block at **≤ 72cqw**. 1–3 words → `hero`; 4–6 → `display`; 7–12 → `headline`; longer is body copy, not a headline.
- **Weight contrast must read at a glance:** pair 300 with 800, or 400 with 700. Never 400 vs 500 for hierarchy.
- **Tracking:** −0.02 to −0.04em on `display`/`hero`/`closing`; +0.12 to +0.16em on uppercase labels.
- **Numerals:** `font-variant-numeric: tabular-nums` on every stat, year, or price.
- **Never** 900 (the family tops out at 800 and will synthesize), never italic headlines, never two families.

### Font embedding (required for Plus Jakarta Sans)

Plus Jakarta Sans is a real Google font but **not in the renderer's 18 bundled families**, so it is
not guaranteed offline. Embed it explicitly with `@font-face` (variable woff2, weights 200–800) in
the composition or a shared `fonts.css`, then reference `font-family: "Plus Jakarta Sans"`:

```css
@font-face {
  font-family: "Plus Jakarta Sans";
  src: url("./fonts/PlusJakartaSans-Variable.woff2") format("woff2");
  font-weight: 200 800;
  font-style: normal;
  font-display: block;
}
```

Without the `@font-face`, the build fetches from Google Fonts at build time — it renders locally but
logs a `font_family_without_font_face` lint warning and **fails closed in cloud/distributed renders**.
Self-host the woff2 next to the composition.

## Depth & Surface

Soft blurred shadow is the only depth. Two values only:

- `0 6px 18px {colors.shadow-soft}` — default `card` / `stat-card`.
- `0 12px 32px {colors.shadow-lift}` — one elevated element per frame (portrait, hero card).

**Ceiling:** no hard-offset shadows, no colored shadows, no inset shadows, no glassmorphism, no
gradients as depth. Tint cards and chips are flat — a shadow on a tint card is a violation.

## Shapes

- **8px** — inline highlight, tags inside text.
- **16px** — small tiles, thumbnails inside cards, inputs.
- **24px** — cards, image blocks, stat cards.
- **9999px** — chips, underlines, accent rules.
- **50%** — portraits and the 8px dot.

Nothing sharp (0px) except full-bleed image edges; no radius above 24px on rectangles.

## Components

- **card / stat-card** — white surface, 1px line, 24px radius, soft shadow.
- **tint-card** — paper/blush/sage fill, hairline, flat. For dense rows and secondary information.
- **chip / chip-accent** — pill meta. Accent fill marks exactly one item per group.
- **portrait** — circular photo with a 3px surface ring and the lift shadow.
- **underline** — the clay rule under an eyebrow or the headline's final line.
- **highlight** — butter block behind one word; the only inline emphasis mechanism.
- **dot** — 8px clay bullet used before eyebrow text or as a live/status marker.
- **atmosphere** — an optional single radial wash plus 2% grain; omit rather than stack.

## Frame Treatments

> Recipe: ground · container · composes · focal · chrome · accent · silence · Fixed/Free · density.

### 1 · Cover (identity · move: eyebrow + hero + lede · left)

**Ground** paper + optional wash. **Composes** dot + eyebrow, `hero`, `lede` (≤2 lines), underline. **Focal** a 2–3 line `hero` greeting in ink; the clay underline closes it. **Chrome** uppercase eyebrow, 18px. **Accent** the underline only. **Silence** one portrait optional on the right third; nothing else. **Fixed** ink type, sentence case, clay rule. **Free** the greeting, whether a portrait appears. **Density** sparse.

### 2 · About (intro · move: portrait + facts · left)

**Ground** paper. **Composes** portrait (320–420px), `headline`, `body` (≤3 lines), 3–4 `chip`s. **Focal** the portrait circle at the left; text column starts at 42cqw. **Chrome** eyebrow above the headline. **Accent** one `chip-accent` in sage. **Silence** no background pattern behind the portrait. **Fixed** circular crop, 3px surface ring, chips below body. **Free** fact wording, chip count (3–4). **Density** standard.

### 3 · Work Strip (catalog · move: 3-up cards · left — the dense frame)

**Ground** paper. **Composes** `headline`, 3× `card`, each with a 16:9 thumbnail (16px inner radius), project name in `body-strong`, one-line `caption`, and a `chip`. **Focal** the three white cards on paper; cards are equal weight, no hero card unless the piece leads with one project. **Chrome** year in `caption` at card foot. **Accent** one clay chip across the row. **Silence** tight — this is the density exception. **Fixed** 24px cards, 1px line, shadow-soft, equal heights. **Free** thumbnails, project names. **Density** dense-exception.

### 4 · Stat Row (evidence · move: 3 stat cards · left head)

**Ground** paper. **Composes** `headline` or `eyebrow`, 3× `stat-card`. **Focal** three numbers in `stat-number`, tabular, ink with **one** in clay. **Chrome** uppercase labels under each number. **Accent** the single clay numeral — never all three. **Silence** no icons, no bars, no sparklines. **Fixed** equal card widths, 2cqw gap, 24px radius. **Free** the three figures (from the script only). **Density** standard.

### 5 · Quote (testimonial · move: quiet quote · left)

**Ground** paper, one wash. **Composes** `quote` at weight 300, attribution line (`body-strong` + `caption`), portrait 240px or `dot`. **Focal** the quote block; one phrase wrapped in `highlight`. **Chrome** no quotation glyph larger than the text. **Accent** the butter highlight. **Silence** ~50% empty; no card around the quote. **Fixed** weight 300, one highlight, attribution below. **Free** the quote text. **Density** sparse.

### 6 · Closing (contact · move: closing line + links · centered)

**Ground** paper + wash. **Composes** `closing`, one line of `body`, 2–3 `chip`s (email, site, handle). **Focal** a short `closing` sign-off, centered; clay underline beneath the last word. **Chrome** chips as the only chrome. **Accent** underline + one chip-accent. **Silence** generous top/bottom space; nothing in the corners. **Fixed** centered, chips in one row, no portrait. **Free** sign-off wording, link order. **Density** sparse.

## Composition Rules

### Do

- Ground on `{colors.paper}`; put content on white `card`s or directly on paper.
- Separate with **1px `{colors.line}`** hairlines; use shadow only on white cards and the portrait.
- Set hierarchy with **300 vs 700/800**; sentence case; negative-track display.
- Keep one **clay** moment per frame; let tints fill chips, never headlines.
- Give every frame **≥35% empty space**; 3–5 elements is the target, not a minimum to fill.
- Left-align copy and headlines; center only the closing frame.
- Crop portraits in circles; use 24px rectangles for everything else.

### Don't

- No pure white ground, no pure black type, no default blue.
- No second typeface, no 900 weight, no italic display, no uppercase headline.
- No hard-offset or colored shadow, no border heavier than 1px, no glass effect.
- No more than two tints per frame; no tint-colored headline.
- No icon sets, badges, gradients, sparklines, or decorative shapes as filler.
- Don't set body copy below 20px or let a headline run wider than 72cqw.

## Aspect-Ratio Behavior

| Treatment   | 16:9 (primary)                | 9:16 (if commissioned)          |
| ----------- | ----------------------------- | ------------------------------- |
| Cover       | hero left, portrait right     | hero top, portrait below        |
| About       | portrait left, text right     | portrait top, text below        |
| Work Strip  | 3 cards across                | 3 cards stacked                 |
| Stat Row    | 3 across                      | 3 stacked, 2-up only if short   |
| Quote       | quote left, attribution below | quote top, highlight inline     |
| Closing     | centered                      | centered, chips stacked in 2    |

`pad` holds on the short edge; re-step display sizes so nothing drops under the 1.05cqw floor.

## Numerals & Claims (hard rule)

Never invent figures, dates, client names, project counts, or testimonials. Render slots as
`— figure —`, `{metric}`, `N%`, `{project}`, `{client}` until the script supplies values. A
placeholder in the spec is correct; a fabricated number in the frame is not.

## Pre-Render Self-Audit

- **Squint** — one element dominates at 3–6×; no two elements competing.
- **Silence** — 3–5 elements, ≥35% empty, one idea per frame.
- **Colors** — every hex is in the palette; one clay moment; ≤2 tints; no blue.
- **Type** — one family, 300↔800 contrast, sentence case, tabular numerals, ≥1.05cqw body.
- **Corners** — 8/16/24/9999/50 only; no 0px text containers.
- **Depth** — shadow on white cards + portrait only; tint cards and chips flat.
- **Anchor** — left-aligned except the closing; centered only once.
- **Fabrication** — every number and name traces to the script, else placeholder.

## Known Gaps

- **Font requires embedding.** Plus Jakarta Sans is not renderer-bundled; without `@font-face` the build fetches Google Fonts and cloud renders fail closed.
- **Motion is out of scope here.** This spec covers frame composition; timing lives in the animation skill.
- **9:16 is guidance only** — verify scale and density on a real render before shipping vertical.
- **No imagery set defined.** Portraits and project thumbs are placeholders until real assets exist.
