# SPDD Analysis: Sleep Detail & Boost From Sleep Pages (with dashboard wiring)

## Original Business Requirement

> build the sleep pages, take ref from design handoff and architecure.md, and ref from current built daily activity feature
>
> the feature then also needs to be linked to the placeholder on the dashboard such as that clicking the icon on dashboard takes us to the feature

**Scope decisions confirmed with the requester (2026-07-01):**
- **Pages in scope:** *both* sleep-related dashboard cards — **Sleep Detail** (`.sleep`, glyph "Z") **and Boost From Sleep** (`.boostFromSleep`, glyph "B").
- **Sleep Detail views:** *both* the **Day** and **Week** views (the design's DAY/WK toggle), i.e. a superset of what the built Daily Activity feature shipped (day-only).

**Reference materials read:**
- `ARCHITECTURE.md` (data/backend reference — §2, §6, §7, §9, §11 especially)
- Design handoff: `project-hercules-design-handoff/project/Sleep Detail.dc.html`, `Boost From Sleep.dc.html`, `Dashboard.dc.html`, `Hercules Design System.dc.html`
- Built reference feature: the **Daily Activity Detail** vertical slice (`ActivityDetail`, `ActivityDetailView`, `ActivityDetailModel`, `StoreActivityDetailProvider`, and its dashboard wiring)
- `BACKLOG.md` (HERC-020/026 sleep data, HERC-063 sleep card, **Epic 9** HERC-090/091/093 SleepWise)

---

## Domain Concept Identification

### Existing Concepts (from codebase)

- **SleepNight** (`PolarProtocol/V3/SleepModels.swift`): one night from `GET /v3/users/sleep` — `hypnogram` (`"HH:MM"`→stage 0/1/3/4 = wake/REM/light/deep), `heart_rate_samples` (`"HH:MM"`→bpm), flat stage totals (`light_sleep`/`deep_sleep`/`rem_sleep`/`total_interruption_duration`, seconds), `sleep_score`, `sleep_charge`, `sleep_cycles`, `continuity` + `continuity_class`, `sleep_start_time`/`sleep_end_time`. **Already fetched, decoded, synced, and stored.**
- **sleep_night store row + `SleepNightView`** (`PolarStore` — `DailyRecords.swift`, `Views.swift`): the persisted, rehydrated projection of a night. Read today only via `sleepNight(date:) -> SleepNightView?` (single date; **no list/range reader exists yet**).
- **Sleep sync domain** (`SyncDomain.sleep`, `SyncRegistry`): windowless P1 descriptor calling `V3DataClient.fetchSleep()` → `store.upsertSleep(...)`. Server-bounded ~28 nights. **Live and populating the store.**
- **SleepAvailability** (`sleep/available` manifest) + `fetchSleepManifest()`: decode-only, sync optimization; relevant to the Sleep Detail "no telemetry / no record" state.
- **CardKind** (`PolarProtocol/Dashboard/CardKind.swift`): enum whose `CaseIterable` order *is* the home-feed order. Already declares both `.sleep` (title "SLEEP", glyph "Z") and `.boostFromSleep` (title "BOOST FROM SLEEP", glyph "B") — the dashboard placeholders the requirement refers to.
- **Daily Activity detail slice** (the reference pattern): `ActivityDetail` (flat display model in `PolarProtocol`), `ActivityDetailProviding` + `StoreActivityDetailProvider` (store→display assembly, zero network), `ActivityDetailModel` (`@MainActor @Observable`, day list + swipe index), `ActivityDetailView` (SwiftUI, local-first, count-up animations, day-swipe gesture). This is the template the sleep pages should mirror.
- **Dashboard navigation seam**: `DashboardView` (`NavigationStack` + `navigationDestination(for: CardKind.self)`), `DashboardModel.hasDetail(for:)` and `detailModel(for:)`. **Currently hard-wired to Daily Activity only** — `hasDetail` returns true just for `.dailyActivity`, `detailModel` returns an `ActivityDetailModel?`, and the destination renders `ActivityDetailView`. This is the exact seam the "link the icon to the feature" requirement must extend.
- **Theme / design system** (`HerculesUI/Onboarding/Theme.swift` — mono font, `accent`, `zoneRamp`, `card`, `hairline`, etc.): the instrument-panel visual vocabulary both pages must reuse (Norm consistency).

### New Concepts Required

- **SleepDetail (display model)** — the flat, UI-visible value type for the Sleep Detail screen (analogue of `ActivityDetail`), in `PolarProtocol`. Carries day-view fields (score, solidity/continuity, regen REM/deep %, hypnogram cycles, HR range, sleep window, amount-vs-average brackets) **and** week-view aggregates (weekly averages, stage totals, continuity, interrupt, the boost/rhythm matrix and trend series). Also an **empty/no-telemetry** representation.
- **SleepDetailProviding + StoreSleepDetailProvider** — assembles `SleepDetail` from the store, zero network (mirrors `StoreActivityDetailProvider`). Needs a **new store reader** for a *list/range* of nights (e.g. `sleepDates()` and/or `sleepNights(in:)`), which does not exist today — only single-date `sleepNight(date:)`.
- **SleepDetailModel + SleepDetailView (+ week-view subviews)** — `@MainActor @Observable` VM with day list + swipe + DAY/WK mode; SwiftUI screen reproducing hypnogram, HR line, metric breakdown (day) and matrix/trend/consolidation (week).
- **SleepWise / Boost domain (entirely greenfield)** — nothing exists below the `.boostFromSleep` card label:
  - **Alertness model** (`GET /v3/users/sleepwise/alertness/date`): `grade` (Boost score 0–10), `grade_classification` (FAIR/GOOD/LOW…), `sleep_inertia`, `hourly_data[].alertness_level` (HIGH/LOW/VERY_LOW/MINIMAL — the hourly bars). *[HERC-090]*
  - **Circadian bedtime model** (`GET /v3/users/sleepwise/circadian-bedtime/date`): sleep **gate** time + **sleep window** markers; `quality` = gate recognizability (1/3–3/3). *[HERC-091]*
  - **V3 client fetches** for both endpoints on `V3DataClient`.
  - **Store table(s) + record + view + reader** for SleepWise (e.g. `sleepwise_day`), plus **`SyncDomain.sleepwise`** and a `SyncRegistry` descriptor. `SyncDomain` is `CaseIterable` and drives freshness, so a new case ripples into freshness + report handling.
  - **BoostDetail display model + provider + view** combining alertness (bars + score) and circadian (gate/window). *[HERC-093]*
  - A **"calibrating"** concept — SleepWise needs ~14 nights before it forecasts; the design shows a distinct calibrating state with a "NIGHTS LOGGED 04 / 14" counter.

### Key Business Rules

- **Local-first, zero-network reads** — both screens open instantly from the store; network happens only on the dashboard's pull-to-sync (Design principle §1; Safeguard mirrored in `StoreActivityDetailProvider`). No spinners (Norm 4).
- **`"HH:MM"`-keyed maps, not arrays** — `hypnogram` and `heart_rate_samples` are objects keyed by clock time; the display model must sort/normalize these into an ordered series (the store already persists them as maps).
- **UTC day boundary** — the built activity provider keys everything to `gmt` midnight and derives fractional-hour positions; sleep spans midnight (e.g. 02:53→10:12), so the night's own `start_time`/`end_time` (not a fixed 00:00 origin) must anchor the hypnogram/HR axis.
- **Card order is CardKind order** — the feed order is fixed by `CardKind.allCases`; no reordering. Sleep sits at index 1, Boost at index 4.
- **Truthful empty/absent states** — a night not worn has no server row; the design mandates explicit "NO RECORD / NO TELEMETRY" (Sleep) and "NO DATA" / "CALIBRATING" (Boost) states rather than zeros.
- **SleepWise calibration gate** — Boost forecast is only valid after enough logged nights; below the threshold the screen shows CALIBRATING, not a score.
- **Windowless sleep sync, but week view needs a range read** — sleep is a server-bounded (~28 nights) windowless domain; the week view aggregates 7 nights, so the store must expose multi-night reads even though sync stays windowless.

---

## Strategic Approach

### Solution Direction

- **Clone the Daily Activity vertical slice, twice.** The built activity feature is a clean, layered template: display model in `PolarProtocol` → store-backed provider in `PolarStore` → `@Observable` VM + SwiftUI view in `HerculesUI`, wired through the dashboard's `NavigationStack`. Reproduce that exact shape for Sleep Detail and (after its data lands) Boost From Sleep.
- **Two tracks with very different depth:**
  - **Sleep Detail = UI-mostly.** The data layer (fetch/decode/sync/store of `sleep_night`) already exists. Work is: (1) add a *list/range* sleep reader to `StoreReading`, (2) build the display model + store provider, (3) build the VM + view with DAY/WK toggle, (4) wire navigation. General data flow: `store (sleep_night rows) → StoreSleepDetailProvider → SleepDetail → SleepDetailModel → SleepDetailView`.
  - **Boost From Sleep = full-stack greenfield (Epic 9).** Must first land the *data spine* — models, V3 client fetches, a new `SyncDomain.sleepwise` + registry descriptor, store table/record/view/reader — *before* any UI is meaningful. Data flow adds a whole left half: `V3 sleepwise/alertness + circadian → decode → upsert → store → provider → BoostDetail → model → view`.
- **Generalize the dashboard detail seam once, up front.** Today `hasDetail`/`detailModel`/`navigationDestination` are hard-typed to `ActivityDetailModel`/`ActivityDetailView`. Extending them ad-hoc per card will not scale to three (soon eight) detail screens. Refactor the seam so `CardKind` routes to a per-kind destination (a small enum of detail routes, or a `@ViewBuilder` switch on `CardKind` producing the right view+model). This *is* the "clicking the icon takes us to the feature" deliverable, and it should be done as a deliberate seam change rather than a second hard-wired branch.
- **Reuse Theme + existing chart idioms.** Hypnogram bands, HR line, and hourly boost bars should be built from the same `Theme` tokens and the Swift-Charts/GeometryReader patterns already used in `ActivityHRChart`/`ActivityClockChart`, keeping visual and code consistency.

### Key Design Decisions

- **Sequence: Sleep Detail first, Boost second.** → *Trade-off:* delivering Boost first would front-load the riskiest (greenfield data) work; Sleep Detail first delivers a shippable screen on already-validated data and exercises the navigation-seam refactor once, de-risking Boost's later wiring. → **Recommendation: build Sleep Detail (day+week) end-to-end, refactor the nav seam as part of it, then build the Boost data spine, then the Boost UI.**
- **Navigation seam: generalize now vs. add a second branch.** → *Trade-off:* a second `if kind == .sleep` branch is faster but compounds the coupling; a general `CardKind → detail route` seam costs a small refactor but makes card #3…#8 trivial and localizes future work. → **Recommendation: generalize now** — it's the requirement's core ("link the placeholder"), and the marginal cost over a hard-wired branch is low.
- **New `SyncDomain.sleepwise` vs. folding into `.sleep`.** → *Trade-off:* reusing `.sleep` avoids touching the `CaseIterable` freshness/report surface, but conflates two different endpoints/failure modes and windows (alertness is date-ranged; sleep is windowless-ish) and muddies per-domain sync outcomes. → **Recommendation: a dedicated `sleepwise` domain**, consistent with the one-entry-per-metric registry principle (Architecture §1, HERC-050).
- **Week-view store reads: range query vs. N single reads.** → *Trade-off:* looping `sleepNight(date:)` 7× is trivial to write but N round-trips through the reader; a single ranged `sleepNights(in:)` matches the existing `cardioLoad(in range:)` precedent and the perf-conscious reading layer. → **Recommendation: add a ranged sleep reader** mirroring `cardioLoad(in:)`.
- **Boost "calibrating" threshold source.** → *Trade-off:* hard-coding 14 nights is simple but may not match SleepWise's real gate; deriving from the API's own classification (if it emits a calibrating/insufficient marker) is truer. → **Recommendation: prefer an API-signaled calibrating state; fall back to a logged-nights count only if the API gives no explicit signal** (resolve during REASONS Canvas against a live probe).

### Alternatives Considered

- **Sleep Detail as day-view-only (match Activity exactly).** Rejected per the confirmed scope — the requester chose Day + Week. Noted only that Week view is the larger, newer-shape portion (matrix/trend/consolidation) with no direct activity-feature precedent.
- **Skip Boost this pass (Sleep Detail only).** Rejected per confirmed scope. Recorded as the natural fallback if Epic 9 data work proves too large for one iteration — Boost cleanly separates behind its own data spine.
- **A single generic "DetailView" driven by a config model for all cards.** Rejected: the three screens (activity/sleep/boost) have materially different visualizations; over-generalizing the *view* (as opposed to the *routing*) would fight the design fidelity. Generalize routing, keep bespoke views.

---

## Risk & Gap Analysis

### Requirement Ambiguities

- **"Sleep pages" resolved, but Week view has no built precedent.** The Daily Activity reference is day-only; the Sleep Detail Week view (SLEEP MATRIX with STAGES/RHYTHM/BOOST overlays, TREND toggle, WEEKLY CONSOLIDATION wheel + stage totals) is a new visual family. "Take ref from the activity feature" gives an architecture template but not a week-view visual template.
- **Boost Week view scope.** The Boost design also has a week dimension (28-DAY BOOST avg, LAST 7 DAYS list, trend bars). It's unstated whether Boost needs full Day+Week parity with Sleep Detail or just the Day forecast. Assumed: match the design's shown states; confirm in REASONS Canvas.
- **Interactive/authoring elements.** Sleep Detail's "RATE YOUR SLEEP" + "ASK FOR FEEDBACK" and Boost's "HOW IT WORKS" imply input/LLM affordances with no backend in the data layer. Assumed out of scope (render static or omit) unless specified.
- **Which card is "linked".** The requirement says "clicking the icon on dashboard takes us to the feature." Assumed: tapping the whole card (as Daily Activity does via `NavigationLink`), not a separate icon hit-target — matching the existing pattern.

### Edge Cases

- **Night spanning midnight / timezone origin.** Sleep window 02:53→10:12 and gate around 02:00 mean the hypnogram axis is not a clean 00:00→24:00 like activity's; must anchor on the night's own start/end. Off-by-one-day risk when mapping a "night" to a dashboard "yesterday/today" label (Boost design says "YESTERDAY · WED 23").
- **No-telemetry / not-worn nights.** No server row → provider must yield the explicit empty state (Sleep "NO RECORD"; Boost "NO DATA"), not a zeroed card. `sleep/available` manifest can distinguish "no data yet" from "not worn."
- **SleepWise calibrating (<~14 nights).** Fresh users / sparse history hit the calibrating branch; the screen must not show a bogus 0/10 Boost.
- **Partial data.** A night with a hypnogram but missing `sleep_score`, or alertness present but circadian absent (or vice-versa) — the combined Boost view must degrade per-field.
- **Week with gaps.** A 7-day window with only some nights recorded — averages/trend must handle missing days without dividing by 7 blindly.
- **Empty HR/hypnogram maps.** The store persists `[:]` when absent; charts must degrade (activity's HR curve already degrades to the intensity band alone — mirror that).

### Technical Risks

- **Navigation seam refactor touches shared dashboard code.** Generalizing `hasDetail`/`detailModel`/`navigationDestination` risks regressing the working Daily Activity route. *Mitigation:* keep the seam change additive and covered by the existing dashboard tests; verify Activity still routes before adding Sleep.
- **`SyncDomain` is `CaseIterable` and feeds freshness + reports.** Adding `.sleepwise` ripples into `StoreDashboardProvider.freshness()` (max over all domains) and `SyncReport` handling. *Mitigation:* additive case; confirm no exhaustive switch breaks.
- **Greenfield Boost data unverified end-to-end in *this* codebase.** ARCHITECTURE.md confirms the SleepWise endpoints return live data, but no decoder/store path exists here yet; response shapes (esp. `hourly_data` cadence, gate/window fields, calibrating signal) must be pinned against a live capture before the store schema is fixed (echoing the project's "verify shapes live" discipline). *Mitigation:* probe/capture first, then model — do not design the table from the doc alone.
- **Week-view aggregation cost.** Materializing 7 nights with their `"HH:MM"` maps for the matrix could be heavier than the day view; keep aggregation in the provider (off the main actor read) and pass flat arrays to the view (activity precedent).
- **Store migration for `sleepwise_*` table.** Adding a table means a GRDB migration; must be additive/versioned and not disturb existing rows.
- **Design fidelity vs. Swift Charts.** The hypnogram cycles, hourly boost bars, and consolidation wheel are custom viz; reproducing the HTML mock's exact look may need hand-rolled `GeometryReader`/`Path` work rather than stock charts (as `ActivityClockChart` already does).

### Acceptance Criteria Coverage

> The requirement is a free-form build request with no formal ACs. The table below derives ACs from the requirement + design states + the referenced backlog tickets (HERC-063, HERC-090/091/093), and assesses each against the current codebase.

| AC# | Description | Addressable? | Gaps/Notes |
|-----|-------------|--------------|------------|
| 1 | Sleep Detail **Day** view reproduces the design (score, hypnogram·cycles, HR line, metric breakdown: amount/solidity/regen) from local `sleep_night` data | **Yes** | Data already stored; needs display model + provider + view. Add a ranged/list sleep reader. |
| 2 | Sleep Detail **Week** view reproduces the design (sleep matrix stages/rhythm/boost, trend, weekly consolidation wheel + totals) | **Partial** | New visual family, no activity precedent; RHYTHM/BOOST overlays depend on SleepWise (Boost) data — couples Week view to the greenfield track. |
| 3 | Sleep Detail **no-telemetry** state renders ("NO RECORD / NO TELEMETRY", SYNC BAND CTA) for un-worn nights | **Yes** | Provider yields empty state; `sleep/available` distinguishes cases. |
| 4 | Boost From Sleep **Day** forecast (Boost score /10, classification, hourly boost bars, gate/window, inertia, duration, sleep block, 28-day avg) | **Partial** | Greenfield: needs alertness+circadian models, V3 fetches, `sleepwise` sync domain, store table+reader, provider, view (HERC-090/091/093). |
| 5 | Boost **calibrating** state (<~14 nights, "NIGHTS LOGGED 04/14") | **Partial** | Needs a nights-logged/calibration signal; prefer API-emitted marker (verify live). |
| 6 | Boost **no-data** state ("NO DATA", SYNC BAND / HOW IT WORKS) | **Yes** (once data spine exists) | Same empty-state pattern as Sleep. |
| 7 | Tapping the **SLEEP** dashboard card navigates to Sleep Detail | **Yes** | Requires generalizing `hasDetail`/`detailModel`/`navigationDestination` beyond `.dailyActivity`. |
| 8 | Tapping the **BOOST FROM SLEEP** dashboard card navigates to Boost From Sleep | **Yes** | Same nav-seam generalization; gated on the Boost feature existing. |
| 9 | Dashboard **SLEEP / BOOST cards show a real glance** (not `.empty`) | **Partial** | `StoreDashboardProvider` currently returns `.empty` for all non-activity cards; populating them mirrors HERC-063 and needs the card headline/detail formatting per kind. |
| 10 | Both screens are **local-first, no network on open, no spinners**, and reuse Theme | **Yes** | Direct mirror of the activity provider/view constraints. |

---

## Summary of the two build tracks (for REASONS Canvas sequencing)

1. **Track A — Sleep Detail (Day + Week):** UI-mostly on existing `sleep_night` data. Add ranged sleep reader → `SleepDetail` model → `StoreSleepDetailProvider` → `SleepDetailModel` + `SleepDetailView` (DAY/WK) → **generalize the dashboard nav seam** and wire the SLEEP card.
2. **Track B — Boost From Sleep (greenfield / Epic 9):** alertness + circadian models → `V3DataClient` fetches → `SyncDomain.sleepwise` + registry descriptor → store table/record/view/**reader** (+ migration) → `BoostDetail` model → provider → `BoostModel` + `BoostView` (forecast / calibrating / no-data) → wire the BOOST card into the (already generalized) nav seam.

Cross-cutting: populate the SLEEP and BOOST **dashboard card glances** (replace `.empty`), and keep the Week view's RHYTHM/BOOST overlays honest about their dependency on Track B.
