---
version: alpha
name: Tora Basic Rule — Design System
description: >
  Canonical design system for Tora. Scope: 16:9 presentation decks (1920×1080). Personality:
  technical and precise. One typeface (Plus Jakarta Sans, 300–800), compact 12-column grid,
  hairline rules, near-square corners (2/4/6px), tabular numerals, and a single signal accent
  (Signal Orange). Light is the primary theme; dark is the alternate for covers, section breaks
  and low-light rooms. Product imagery only — screenshots, wireframes, diagrams. No photography.
unit: the slide — 1920×1080 (16:9)
principle: one typeface · one accent · hairline structure · density over decoration

colors:
  # --- light (primary) ---
  paper: "#F7F7F4"
  surface: "#FFFFFF"
  ink: "#14161A"
  ink-soft: "#5B6067"
  ink-faint: "#8A8F96"
  line: "#E1E1DC"
  line-strong: "#C9CAC4"
  accent: "#E4552B"
  accent-text: "#B93E19"
  accent-press: "#C8461F"
  accent-wash: "#FBEAE3"
  accent-100: "#FBE6DF"
  accent-200: "#F6C7B8"
  accent-300: "#EE9C81"
  accent-400: "#E4552B"
  accent-500: "#B93E19"
  # --- dark (secondary) ---
  dark:
    base: "#0F1113"
    surface: "#16191C"
    surface-2: "#1D2124"
    ink: "#F1F1EE"
    ink-soft: "#9BA1A8"
    ink-faint: "#6E757C"
    line: "#282C31"
    line-strong: "#3A4046"
    accent: "#FF7A4E"
    accent-text: "#FF8C66"
    accent-on: "#1A0E08"
    accent-wash: "#2A1B15"

typography:
  family: { fontFamily: "Plus Jakarta Sans", weights: "300 400 600 700 800", style: "normal" }
  display:  { px: 104, weight: 800, lineHeight: 0.98, tracking: "-0.040em" }
  h1:       { px: 72,  weight: 800, lineHeight: 1.02, tracking: "-0.035em" }
  h2:       { px: 48,  weight: 700, lineHeight: 1.08, tracking: "-0.030em" }
  h3:       { px: 32,  weight: 700, lineHeight: 1.20, tracking: "-0.020em" }
  lede:     { px: 32,  weight: 300, lineHeight: 1.40, tracking: "-0.010em" }
  body:     { px: 24,  weight: 400, lineHeight: 1.50, tracking: "0" }
  body-sm:  { px: 20,  weight: 400, lineHeight: 1.50, tracking: "0" }
  data:     { px: 20,  weight: 600, lineHeight: 1.35, tracking: "0", tabular: true }
  stat:     { px: 64,  weight: 800, lineHeight: 1.00, tracking: "-0.030em", tabular: true }
  label:    { px: 14,  weight: 700, lineHeight: 1.20, tracking: "0.140em", upper: true }
  micro:    { px: 12,  weight: 600, lineHeight: 1.20, tracking: "0.120em", upper: true }

spacing:
  margin: "72px"
  gutter: "20px"
  baseline: "8px"
  section-gap: "48px"
  block-gap: "24px"
  cell-pad: "12px 16px"
  footer-height: "40px"
  card-pad: "24px"

components:
  monogram:
    shape: "square, 4px radius"
    fill: "{colors.ink}"
    glyph: "T — Plus Jakarta Sans 800, {colors.paper}"
    sizes: "32 / 48 / 64px"
    outline-variant: "1.5px {colors.ink} stroke, transparent fill, ink glyph"
    clearspace: "0.5 × mark size on all sides"
    description: "The only logo. Never rotate, recolor, stretch, or add effects."
  card:
    backgroundColor: "{colors.surface}"
    border: "1px solid {colors.line}"
    rounded: "4px"
    shadow: "none"
    padding: "{spacing.card-pad}"
    description: "Flat container. A card without a border is a background block, not a card."
  table:
    rowHeight: "44px"
    border: "1px solid {colors.line} horizontal only"
    header: "{typography.micro} in {colors.ink-soft}, bottom border {colors.line-strong}"
    numeric: "{typography.data}, right-aligned, tabular"
    activeRow: "2px {colors.accent} left bar + {colors.accent-wash} fill"
    description: "Never zebra-stripe. Never vertical rules. Max 9 body rows per slide."
  tag:
    rounded: "2px"
    border: "1px solid {colors.line-strong}"
    padding: "3px 8px"
    typography: "{typography.micro}"
    accentVariant: "{colors.accent} fill, white glyphs, no border"
  node:
    rounded: "4px"
    border: "1.5px solid {colors.ink}"
    size: "72 / 96px"
    typography: "{typography.body-sm} centered, weight 600, +0.04em tracking"
    description: "Diagram node. Accent stroke marks the active path only; never fill a node with accent."
  connector:
    stroke: "1.5px {colors.line-strong}"
    activeStroke: "1.5px {colors.accent}"
    marker: "6px arrowhead"
    description: "Orthogonal routing, square corners. No curves except a single 90° fillet at 4px."
  rule:
    height: "1px"
    color: "{colors.line-strong}"
    accentRule: "3px × 64px {colors.accent}, 0 radius"
  stat-block:
    typography: "{typography.stat} + {typography.label}"
    underline: "1px {colors.line-strong} full width, 12px below number"
  slide-meta:
    typography: "{typography.micro} in {colors.ink-faint}"
    placement: "footer, 72px margin, 1px {colors.line} rule above"
    content: "left = document title · right = section / page number"
---

# Tora Basic Rule — Design System

## Overview

Tora is a **technical, compact system for presentation decks.** The deck is a fixed 1920×1080
canvas, and every slide is built on the same 12-column grid with the same 72px margin — the
structure does not change between a cover and a data table. Precision comes from alignment and
rules, not from decoration: every element sits on the 8px baseline, every separator is a 1px
hairline, and every number is tabular.

One typeface does all the work. **Plus Jakarta Sans** at 300 for quiet copy, 400 for reading, 600
for data, 700–800 for statements. The weight jump is the hierarchy. There is no second font, no
italic display, no display serif. The only chromatic element is **Signal Orange**, used as a
signal — a rule, one active row, one active path, one key number — never as a background wash
behind body text.

**What this system is not:** it is not a video or motion system, not a web UI kit, and not a
photographic brand. Photography is out of scope; imagery is **product only** — screenshots,
wireframes, diagrams.

## The Slide

### Canvas

- **1920×1080** fixed. Author in `px`; scale the whole stage with one transform when previewing.
- **Margin:** 72px on all four edges. Nothing enters the margin except the footer rule.
- **Grid:** 12 columns, 20px gutter. Column width = 136px (`(1920 − 144 − 220) / 12`).
- **Baseline:** 8px. Line heights and block gaps are multiples of 8.
- **Footer:** 40px band at the bottom, 1px `{colors.line}` rule above it, `slide-meta` inside.

### Density law

Dense is the default; chaos is not. A content slide carries **one idea, one dominant element, and
supporting evidence** — 6–9 table rows, 4–9 diagram nodes, or 3–4 text blocks. The outer 72px
margin stays empty, and at least one grid column stays unoccupied on text-heavy slides so the eye
has somewhere to rest. **Compact does not mean edge-to-edge.**

### Composition tests

- **Squint** — one element dominates at 2.5–4× its nearest neighbor. On data slides, the table is the dominant element.
- **Align** — every edge lands on a column line; nothing floats between columns.
- **Silence** — the margin is empty, one column breathes, and there is no filler chrome.
- **Reference** — aim at a **technical manual / spec sheet**; failure looks like a **generic startup pitch deck with centered text and blue buttons**.

## Color

### Light (primary)

`{colors.paper}` is the page ground. `{colors.surface}` (white) is for cards, table bodies and
screenshot frames only — never for a whole slide. `{colors.ink}` is all headline and body text;
`{colors.ink-soft}` secondary copy and table labels; `{colors.ink-faint}` metadata only.
`{colors.line}` draws hairlines; `{colors.line-strong}` draws the heavier structural rules (table
header, footer, diagram connectors).

### Dark (secondary)

Dark is a **whole-slide alternate**, never a panel inside a light slide. Use it for the cover,
section dividers, the closing slide, and decks presented in a dark room. Content pages stay light.
Dark tokens are under `colors.dark`; the accent lightens to `{colors.dark.accent}` for contrast, and
type on accent becomes `{colors.dark.accent-on}` (near-black) — never white on the light accent in
dark theme.

### Usage law

- **`{colors.accent}` = signal.** A rule, one active row, one active path, one key figure, one tag. **Once per slide.**
- **`{colors.accent-text}` = accent-colored type.** Body and small type use this darker value; `{colors.accent}` itself only appears at ≥32px or as a graphic element.
- **Accent is never a page background** and never a full card fill behind running text.
- **No invented colors.** Chart and diagram steps come only from `accent-100…500` or the gray steps.
- **Contrast minimums:** body text 4.5:1, large text (≥32px/700) and UI strokes 3:1. Verified values: `{colors.ink}` on `{colors.paper}` = 16.9:1, `{colors.ink-soft}` on `{colors.paper}` = 5.9:1, `{colors.accent-text}` on `{colors.paper}` = 5.2:1, white on `{colors.accent}` = 3.7:1 (large text and UI only).

## Typography

One family, six working sizes. **Weight contrast carries hierarchy**: 300 ↔ 800, or 400 ↔ 700.
Never 400 vs 500 — it is invisible at presentation distance.

| Role | Size | Weight | Use |
|---|---|---|---|
| `display` | 104 | 800 | Cover statement, 1–3 words |
| `h1` | 72 | 800 | Single-line slide statement |
| `h2` | 48 | 700 | Slide headline with support |
| `h3` | 32 | 700 | Block or card heading |
| `lede` | 32 | 300 | One-sentence framing under a headline |
| `body` | 24 | 400 | Reading copy, never below |
| `body-sm` | 20 | 400 | Table cells, captions, dense support |
| `data` | 20 | 600 | Table numerals, labels in diagrams (tabular) |
| `stat` | 64 | 800 | Key figures (tabular) |
| `label` | 14 | 700 | Section labels, uppercase, +0.14em |
| `micro` | 12 | 600 | Footer, table header, tags, uppercase, +0.12em |

Rules:

- **Sentence case** for every headline. Uppercase only at `label` / `micro` size.
- **Tracking:** −0.03 to −0.04em on `display`/`h1`, −0.02em on `h2`/`h3`; +0.12 to +0.14em on uppercase.
- **Tabular numerals always** on `data`, `stat`, table columns, page numbers, and years.
- **No 900** — the family tops out at 800 and will synthesize. No italics in headlines. No underline for emphasis (use a rule or a tag).
- **Fit to measure:** headline blocks cap at **≤ 14 columns** (1184px). 1–3 words → `display`; one line → `h1`; two lines → `h2`; a heading over a block → `h3`.
- **Line length for body:** 42–62 characters, never full width.

### Font embedding

Plus Jakarta Sans is a real Google font but **not one of the renderer's bundled families**. Self-host
it for anything that must render offline or in cloud:

```css
@font-face {
  font-family: "Plus Jakarta Sans";
  src: url("./fonts/PlusJakartaSans-Variable.woff2") format("woff2");
  font-weight: 200 800;
  font-style: normal;
  font-display: block;
}
```

`tokens.css` already points at `./fonts/`; a Google Fonts link is acceptable for browser preview
only, never for a render or a distributed PDF.

## Layout & Density

- **Columns:** 12. Use 12 for a table, 8+4 for content+aside, 7+5 for text+diagram, 6+6 for comparison. Never a 5-column split.
- **Row rhythm:** block gaps 24px, section gaps 48px. A card grid uses 20px gutters, equal heights.
- **Tables:** full grid width or 8 columns; max 9 body rows; header row 40px, body rows 44px; numeric columns right-aligned.
- **Diagrams:** drawn on the grid, left-to-right flow, max 9 nodes, orthogonal connectors at 1.5px. One accent path only.
- **Text blocks:** max 3 per slide, each ≤ 3 lines at `body` size. A fourth block means the slide is a document, not a slide.
- **Footer:** always present on content slides; omitted on cover and full-bleed section dividers.

## Components

- **monogram** — the only mark: 4px-radius ink square with a paper `T`. Outline variant for light photographic backgrounds. Minimum 32px; clear space 0.5× the mark.
- **card** — white, 1px hairline, 4px radius, flat. No shadow exists in this system.
- **table** — horizontal hairlines only, `micro` header, tabular numerics, accent left-bar on the one active row.
- **tag** — 2px radius, uppercase `micro`; accent fill reserved for status.
- **node / connector** — diagram primitives at 1.5px stroke; accent marks the active path, never fills a node.
- **rule** — 1px `line-strong` for structure, 3×64px accent rule for the single emphasis stroke.
- **stat-block** — `stat` number over a `label`, 1px underline, tabular.
- **slide-meta** — footer line: document title left, section / page right, `micro` in `ink-faint`.

## Slide Grammar

> Recipe: ground · grid · composes · focal · chrome · accent · density.

### 1 · Cover
**Ground** light (or dark alternate). **Grid** 12, margin 72. **Composes** monogram 48, `label` "Tora Basic Rule", `display` title, one `lede` line, accent rule. **Focal** the `display` title, max 3 words. **Chrome** monogram top-left, document date bottom-left. **Accent** the 64×3 rule under the title. **Density** sparse: title at columns 1–9, nothing at columns 10–12.

### 2 · Section Divider
**Ground** dark alternate (or paper with a full-width rule). **Composes** `label` "Section 02", `h1` section name, `body-sm` one-line scope. **Focal** the section name. **Chrome** page number only. **Accent** the section number in `accent` at 32px+. **Density** sparse, left-aligned at column 1.

### 3 · Statement
**Ground** paper. **Composes** `h1` or `display` sentence, optional one `body` line, accent rule. **Focal** the statement, 1–2 lines, columns 1–10. **Chrome** footer. **Accent** the rule, once. **Density** sparse — no card, no list, no image.

### 4 · Two-Column Content
**Ground** paper. **Composes** `h2` headline across columns 1–10, then 7+5 or 6+6 split: text block left, card or diagram right. **Focal** the headline; supporting blocks are equal weight. **Chrome** footer. **Accent** one tag or one rule, not both. **Density** standard, 3 blocks max per side.

### 5 · Data Table
**Ground** paper. **Composes** `h2` or `h3` headline, table (12 or 8 cols), one-line `body-sm` note under the table, footer. **Focal** the table. **Chrome** column headers in `micro`; units in the header, not the cell. **Accent** the active row's 2px left bar + wash. **Density** dense-exception: up to 9 rows, 6 columns.

### 6 · Diagram
**Ground** paper. **Composes** `h3` headline, orthogonal flow diagram (max 9 nodes), legend in `micro`, footer. **Focal** the diagram. **Chrome** node labels in `body-sm`, connector labels in `body-sm` in `ink-faint`. **Accent** one path only. **Density** standard; diagram occupies 8–12 columns.

### 7 · Comparison
**Ground** paper. **Composes** `h2`, two 6-column blocks separated by a 1px vertical `line` rule, each with `h3` + 3 bullets or a mini table. **Focal** the two headings. **Chrome** footer. **Accent** the winning column's heading only — or no accent at all. **Density** dense: 3 rows/side.

### 8 · Closing
**Ground** dark alternate or paper. **Composes** `display` or `closing` line, `body-sm` contact line, monogram outline variant, footer omitted. **Focal** the sign-off. **Chrome** monogram bottom-right at 32px. **Accent** none, or one 64×3 rule. **Density** sparse, left-aligned.

## Imagery (product only)

- **Allowed:** application screenshots, wireframes, UI crops, technical diagrams, annotated flows.
- **Treatment:** 1px `{colors.line-strong}` frame, 4px radius, no shadow, no perspective, no device mockups, no reflection, no tilt.
- **Crops:** align the screenshot's content edge to a column line. Crop rather than shrink — text inside a screenshot must stay legible at 20px equivalent.
- **Annotations:** accent 1.5px callout lines + `micro` labels only.
- **Forbidden:** stock photography, team/office imagery, people, 3D renders, abstract gradient art, AI-generated illustration.

## Monogram

The mark is a **4px-radius square in `{colors.ink}` with a paper `T` at 800**, not a letter in a
circle and not a custom drawn symbol. Sizes 32 / 48 / 64px only. Clear space = 0.5× the square on
all sides. On dark, invert: `{colors.dark.ink}` square with `{colors.dark.base}` glyph. Never rotate,
stretch, add a shadow, change radius, or place the mark on the accent color.

## Motion

Out of scope. Deck slides are static frames; transitions belong to the presentation tool, not this
system. If a build animates, it uses opacity only (120ms, `ease-out`) and no spatial movement.

## Do

- Build every slide on the 12-column grid with the 72px margin.
- Separate with 1px hairlines; use `line-strong` for structure and `line` for content.
- Set hierarchy with 300 ↔ 800; sentence case; tabular numerals everywhere.
- Spend exactly one accent moment per slide.
- Keep the footer on content slides and off covers/dividers.
- Frame product screenshots with a hairline and align them to a column.
- Leave the outer margin and one column empty, always.

## Don't

- No gradients, glows, drop shadows, or neumorphism — there is **zero shadow** in this system.
- No radius above 6px on surfaces; no pills; no rounded blobs.
- No emoji as icons or bullets; no third-party icon libraries; no illustrated icon sets.
- No stock photography, no people, no 3D renders, no abstract AI art.
- No colored page background behind body text; no accent-filled cards with running copy.
- No centered body text; no centered lists; only the cover and closing may center.
- No second typeface, no 900 weight, no italic headlines, no underlined emphasis.
- No more than 9 table rows or 9 diagram nodes; no slide without a footer rule (except cover/divider).

## Numerals & Claims

Every figure, percentage, date, client name and project count must trace to a source. Where a value
is not yet known, render `— figure —`, `{metric}` or `N%`. A template placeholder is correct; an
invented number is a defect.

## Accessibility

- Body text ≥ 4.5:1; large text and graphic strokes ≥ 3:1 (verified values above).
- Never encode meaning by color alone — the active table row also gets a left bar; the active diagram path also gets a heavier stroke.
- Minimum type 20px for anything a viewer must read; 12–14px is chrome only.
- No motion, so no reduced-motion variant is required.
- Tab order and reading order follow the visual order: left to right, top to bottom.

## Pre-Flight Checklist

- **Grid** — every edge on a column line; 72px margin intact.
- **Type** — one family, 300↔800 contrast, sentence case, tabular numerics, nothing under 20px except chrome.
- **Color** — one accent moment; no invented hex; no accent background behind text; hairline rules 1px.
- **Shape** — radii 2/4/6 only; no pills; no shadows anywhere.
- **Density** — one idea per slide; ≤9 table rows; ≤9 nodes; one column breathing.
- **Footer** — present on content slides, absent on cover and dividers.
- **Imagery** — product only; hairline frame; column-aligned; legible at size.
- **Truth** — every number and name sourced, otherwise a placeholder.

## Known Gaps

- **Deck-only scope.** No web UI, no print, no social formats defined here. Adding them requires new grids, not new colors.
- **Font must be self-hosted.** `./fonts/PlusJakartaSans-Variable.woff2` is bundled (Latin subset, 27KB); `tokens.css` points at it. Non-Latin glyphs fall back per-glyph — add the latin-ext/other subsets if a deck needs them.
- **Dark is secondary.** Dark content pages (tables, diagrams) are not specified beyond tokens — verify contrast and hairline visibility before using dark for a full deck.
- **No motion spec.** If decks become animated, a separate layer is required.
- **Prohibition list is provisional.** Confirm or strike items in "Don't" before treating it as law.
