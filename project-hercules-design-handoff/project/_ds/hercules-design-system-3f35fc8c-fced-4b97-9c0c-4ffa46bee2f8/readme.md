# Project Hercules — Design System

> **Hercules Telemetry** · A precision-instrument dashboard language for a dark, high-contrast iOS fitness app. Oversized numerals, monospace type, dials and bars over decoration. Sharp and snappy — never soft or wellness-y.

This is the design system for **Project Hercules**, a telemetry-style fitness app that reads sleep, heart-rate, activity and workout data and renders it as engineered instrument readouts. The whole language is built so that **the one number that matters is the hero**, surrounded by terse monospace labels on pure black.

## Sources
- `uploads/Hercules Design System.dc.html` — the original brand spec (palette, type, components, motion, principles), authored in Claude Design. **All tokens, components and the UI kit derive from this one file.** No external codebase, GitHub repo or Figma was provided.

If you have a production codebase or Figma for Hercules, attach it via the Import menu and this system can be reconciled against it.

---

## CONTENT FUNDAMENTALS — how Hercules writes

The voice is an **instrument readout**, not a coach. It reports; it never cheers.

- **Casing:** UPPERCASE for every label, title, status and button (`GRANT ACCESS`, `BOOST FROM SLEEP`, `CONNECT POLAR`, `SYNCING`). Sentence case is reserved for the occasional body line.
- **Person:** Implied second person, but mostly **subjectless and declarative** — "Decent rest, steady day ahead." Not "You slept well!". No exclamation marks. Ever.
- **Tone:** Clinical, confident, terse. Like a flight instrument or a terminal. "Loading happens once." "Numbers are the hero."
- **Numbers lead.** Copy frames a figure; it doesn't replace it. `8.1 /10` then a one-line read: "Sleep carried the score; activity load is light."
- **Units are muted, not loud:** `7H 19M`, `48 BPM`, `/10` — the unit sits in slate next to an off-white/orange value.
- **Tracking is part of the voice:** titles ride at +2.5px, labels at +1.5px. The spacing reads as engineered.
- **No emoji. No marketing adjectives** (no "amazing", "boost your wellness journey"). Status words are flat: `GOOD`, `FAIR`, `LOW`, `MILD`, `SYNCING`, `ACTIVE`.
- **Caption microcopy** is spec-like: `SECURE OAUTH · ~30S`, `28-DAY`, `GATE 02:00–02:30 ▸`.

Examples:
- ✅ `GRANT ACCESS` / "Connect once — the sync happens in the background, every morning."
- ✅ `READINESS  8.1 /10  · FAIR`
- ❌ "You're crushing it! 🎉 Let's boost your wellness today!"

---

## VISUAL FOUNDATIONS

**Palette.** Four cores carry every screen; everything else is a tint of slate.
- Background `#000000` — pure/near-black canvas. Every screen sits on black.
- Accent `#FE7F2D` (orange) — key numbers, active states, highlights, primary CTAs. A **spotlight**, used sparingly.
- Secondary `#233D4D` (slate) — cards, glyph tiles, secondary surfaces, borders.
- Text `#EAECF0` (off-white) — primary copy and large numerals.
- Extended slate tints handle surfaces (`#0E1B22` card, `#070F13` well), hairlines (`#16242C`), borders (`#1B2D38`), muted/faint text (`#5E7280`, `#3A5160`).
- **Data-encoding scale** ramps orange→slate for any "level" metric: `HIGH #FE7F2D · MED #E0793A · LOW #5E7280 · VERY_LOW #3A5160 · MINIMAL #2A4253`.

**Type.** One family — **Azeret Mono** (technical monospace). Weights 400–800. Tabular figures keep numbers from jittering as they animate. Roles: HERO NUMERAL (800, −2px), DISPLAY (24px/800), TITLE (14px/700, +2.5px), LABEL (11px/600, +1.5px), BODY (12.5px/500), CAPTION (10px/600, +1.5px). *(Azeret Mono is loaded from Google Fonts — see Caveats.)*

**Spacing.** 8px-rooted. Sections breathe at 64px vertical / 72px horizontal; cards pad ~28–30px. **Generous negative space — let the black breathe; density comes from data, not chrome.**

**Backgrounds.** Flat pure black. No photographic imagery, no full-bleed pictures, no textures or repeating patterns. The *only* gradients allowed are functional: a marker tail fade on the timeline, a faint orange "gate band" wash (`rgba(254,127,45,0.12)`), and a dim+blur backdrop behind a slide-up sheet. No decorative purple/blue hero gradients.

**Cards & surfaces.** Near-black fills (`#0E1B22` / `#070F13`) with a **1px hairline border** and 16px soft-square corners. **Depth comes from the border + a darker fill, never a drop shadow.** Glyph tiles are 9px-radius slate squares with an orange letter.

**Corner radii.** Sharp instrument geometry: bars 2px, glyph tiles 9px, list rows 13px, cards 16px, the logo tile 26px, and full pills (999px) for CTAs, status chips and toggles. Never round-cute.

**Borders & shadows.** Borders over shadow throughout. 1px hairlines divide sections and outline cards; 1.5px orange/slate outlines define status pills and the back button. Shadows are essentially absent except a subtle lip under a slide-up sheet.

**Transparency & blur.** Off-white text is tiered by alpha (70→35%) rather than mixed colors. Blur (`blur(8px)`) appears only on the dimmed backdrop behind the web-auth sheet — nowhere else.

**Imagery vibe.** There is none by design — the "imagery" is data viz. Bars and dials, warm orange against cool slate on black.

**Motion.** Fast, crisp, mechanical — never slow or lazy, **no fade-only transitions.**
- Bars draw in: scale up from the baseline, staggered L→R (+40ms/bar, 0.5s, `cubic-bezier(.16,.84,.3,1)`).
- Count up: hero numbers tick 0→target on a cubic ease-out (~1.1s).
- Marker slide-in: gate band + window node drop in after the strip draws.
- Snap in: onboarding elements translate up and settle sharply, staggered.
- Sheet slide-up: web-auth modal rises over a dimmed/blurred backdrop (0.45s).
- Terminal fill: progress bars fill L→R, percentages race, domains light top-down, snaps to dashboard at 100% (2.6s). *This is the only loading pattern — no spinners anywhere.*

**Hover / press states.** This is a touch product: press shrinks to ~0.97 with a fast snap; the active segment/pill fills orange with a black label. Hover (in web kits) is a subtle opacity drop.

**Layout rules.** Detail screens use a fixed top bar (back chevron · centered spaced title + date · optional range toggle). One primary CTA per screen, full-width, pinned to the bottom. Content scrolls under the status bar.

---

## ICONOGRAPHY

Hercules is **near-iconless by design** — it favors numbers, bars and short letter-glyphs over a decorative icon set.
- **Letter glyphs** carry data domains: a single orange letter (`Z` sleep, `H` heart rate, `A` activity, `W` workouts) inside a 9px-radius slate tile. This is the primary "icon" system.
- **Inline functional SVG only**, hand-built to match the 1.8–2px stroke, round-cap geometry of the brand: back chevron, forward chevron, the orange ✓ check node, and the CTA forward-arrow. These live inside the components (`Button`, `DataDomainItem`, `ScreenHeader`) — no external icon font or sprite.
- **No emoji. No Unicode pictographs.** The only "decorative" Unicode used is the small `▸` and `▼`/`▲` arrows in spec captions and stat deltas.
- **Status is encoded by color + shape**, not iconography: an orange dot = live/syncing; a filled orange pill = active.

If you need a broader icon set for a new surface, match the stroke (≈1.8–2px), round caps/joins, and keep fills hollow unless the icon is an *active* node — then fill orange. A close CDN match would be **Lucide** (2px round) or **Feather**; flag any substitution.

---

## INDEX — what's in this system

**Root**
- `styles.css` — the single entry point consumers link. `@import`s every token file.
- `readme.md` — this guide.
- `SKILL.md` — Agent-Skills-compatible front-matter wrapper.

**`tokens/`** — CSS custom properties (`--hc-*`), each `@import`ed from `styles.css`
- `colors.css` · `typography.css` (+ Azeret Mono import) · `spacing.css` · `radius.css` · `effects.css` · `motion.css` (+ signature `@keyframes`).

**`components/`** — reusable React primitives (namespace `HerculesDesignSystem_3f35fc`)
- `core/` — **Button**, **StatusPill**, **Card**, **OversizedScore**
- `viz/` — **BarStrip** (signature hourly strip), **TrendChart**
- `data/` — **StatRow**, **DataDomainItem**
- `navigation/` — **ScreenHeader**, **SegmentedToggle**
- `feedback/` — **ProgressReadout** (terminal sync, the only loader)
- `brand/` — **LogoMark**

**`guidelines/`** — foundation specimen cards (Colors, Type, Spacing, Brand) shown in the Design System tab.

**`ui_kits/hercules-app/`** — interactive iOS app recreation: Onboarding → Sync → Dashboard → Sleep Detail. See its `README.md`.

---

## PRINCIPLES
1. **Precision instrument, not a wellness app.** Engineered, sharp, high-contrast — never soft or rounded-cute.
2. **Numbers are the hero.** Oversize the one figure that matters; everything else is a label around it.
3. **Loading happens once.** Syncing is permitted only at onboarding — never a spinner anywhere else.
4. **Orange is a spotlight.** Reserve the accent for the live, the active, the important. Slate carries the rest.
5. **Monospace everywhere.** Tabular figures keep numbers from jittering as they animate.
6. **Generous negative space.** Let the black breathe; density comes from data, not chrome.

---

## CAVEATS
- **Font substitution:** the spec calls for **Azeret Mono**, loaded here from **Google Fonts** (no licensed binary was supplied). If you have a licensed/self-hosted file, drop it in and add a `@font-face` in `tokens/typography.css`.
- **No production source:** there was no codebase or Figma — components and the UI kit are recreated faithfully from the brand spec, and all data/copy is representative sample content.
