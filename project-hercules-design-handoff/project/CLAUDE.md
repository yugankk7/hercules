# Project Hercules — Instrument Design System

A dark, high-contrast, precision-instrument design language for a personal iOS fitness app
(a modern replacement for Polar Flow). **Always follow this system on every screen.**
Full visual reference: `Hercules Design System.dc.html`.

## Aesthetic
Precision-instrument dashboard — engineered, sharp, snappy. NOT a soft/rounded wellness app.
Oversized numerals, technical/monospace type, dials/gauges/sparklines/bars, pill-shaped
buttons and tags, generous negative space on pure black. iOS, dark mode, single screen inside
an iPhone frame (`ios-frame.jsx`, mounted with `dark={{ true }}`).

## Palette
Core (carry every screen):
- Background  `#000000`  near-black canvas
- Accent      `#FE7F2D`  orange — key numbers, active/live states, highlights, primary CTAs
- Secondary   `#233D4D`  slate — cards, glyph tiles, secondary surfaces
- Text        `#EAECF0`  off-white — primary copy + numerals

Extended (tints of slate):
- Card `#0E1B22` · Modal/sheet `#0B141A` · Panel-dark `#070F13`
- Hairline divider `#16242C` · Card border `#1B2D38` · faint border `#111E25`
- Muted text `#5E7280` (labels, units, "/10") · Faint/disabled `#3A5160`

Data-encoding scale (intensity ramp, used for bars/dots/levels):
HIGH `#FE7F2D` · MED `#E0793A` · LOW `#5E7280` · VERY_LOW `#3A5160` · MINIMAL `#2A4253`
(trend "below target" bars use `#2E4E61`)

## Typography
One family: **Azeret Mono** (Google Fonts, weights 400–800). Monospace, tabular figures.
- Hero numeral: 800, negative tracking (−2 to −5px), orange. Oversize the one figure that matters.
- Display: 800, −0.5px. Title: 700, +2.5px letter-spacing, often UPPERCASE.
- Label: 600, +1.5px, ~9–11px, muted. Body: 500, +0.3px, ~12.5px, text at 50–60% opacity.
- Caption: 600, +1.5px, 10px, `#5E7280`.

## Components (all built inline — no external CSS, no class-based styles)
- **Oversized score** — huge accent numeral + small `/10` in muted + outlined classification pill.
- **Status / classification pill** — outlined for class (orange = good/fair, slate = low),
  filled orange w/ black label for primary/active. Always `border-radius:999px`.
- **Hourly bar strip** — row of vertical bars, height + color from the encoding scale;
  draws in left-to-right, staggered. The signature viz.
- **Timeline markers** — gate band (dashed orange box w/ tinted fill), sleep-window line
  (orange→transparent gradient), wake node (orange dot, black ring). Slide in after bars.
- **Secondary stat row** — 3 divided cells (`border-right:#16242C`); first value accents orange.
- **Trend mini-chart** — sparkline of thin bars in a `#0E1B22` card; peaks ≥ target turn orange.
- **Primary pill CTA** — full-width, 56–58px tall, orange fill, black 800-weight label, +2px tracking.
  Secondary = outline (`1px solid #233D4D`).
- **Data-domain list item** — slate card (`#0E1B22`/`#1B2D38`), 34px glyph tile, label + sublabel,
  trailing 20px check/state chip.
- **Terminal progress readout** — the ONLY loading pattern. Giant count-up %, linear fill bar,
  per-domain rows with `[|||||     ]` ticks + count-up numbers. Never a circular spinner.
- **Screen header** — back chevron in a 34px circle · centered title + date label · segmented
  DAY/WK range toggle (active segment filled orange).
- **States** — every data screen needs: populated · calibrating ("learning your rhythm", sparse) ·
  no-data/empty. Empty/disabled values render as `—` in `#3A5160`.

## Motion (fast, crisp, mechanical — never slow/lazy, no fade-only)
- Bars draw in: `grow` scaleY 0→1, 0.5s cubic-bezier(.16,.84,.3,1), +40ms/bar L→R.
- Count up: requestAnimationFrame, ~1.1s ease-out cubic, on every hero number.
- Marker slide-in: gate/window after the strip finishes.
- Snap in (onboarding): translateY up + settle, 0.4–0.5s, staggered top-first.
- Sheet slide-up: web-auth modal over dimmed+blurred backdrop, 0.45s cubic.
- Terminal fill: bars L→R, % races up, domains light top-down, snaps to dashboard at 100%.

## Principles
1. Precision instrument, not a wellness app.
2. Numbers are the hero — oversize the one that matters; labels surround it.
3. Loading happens once (onboarding only) — no spinners anywhere else.
4. Orange is a spotlight — reserve for live/active/important; slate carries the rest.
5. Monospace + tabular figures everywhere (numbers don't jitter while animating).
6. Generous negative space — density comes from data, not chrome.

## Conventions
- Build every design as a Design Component (`.dc.html`), inline styles only.
- App identity used so far: **HERCULES / TELEMETRY** (bar-glyph logo mark).
- Existing screens: `Boost From Sleep.dc.html` (day + week views, all states),
  `Onboarding and connection.dc.html` (welcome · OAuth · web-auth modal · initial sync).
- To show multiple frames/states side by side, use canvas mode
  (`<meta name="design_doc_mode" content="canvas">`).
- Avoid: circular gauges except on genuinely gauge-shaped data (e.g. activity);
  emoji; gradients-as-decoration; rounded "wellness" softness; AI-slop tropes.
