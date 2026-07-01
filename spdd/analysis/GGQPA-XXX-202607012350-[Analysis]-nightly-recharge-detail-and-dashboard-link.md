# SPDD Analysis: Nightly Recharge Detail Screen + Dashboard Card Linking

## Original Business Requirement

> nightly recharge feature and linking with dashboard click

(Terse text requirement — no attached document or ACs. Interpreted, and grounded against the codebase and the design handoff `project-hercules-design-handoff/project/Nightly Recharge.dc.html`, as: build the **Nightly Recharge detail screen** as a navigable vertical slice — mirroring the just-landed Sleep Detail and Boost From Sleep screens — and make the dashboard's **NIGHTLY RECHARGE** card tappable so a click pushes that detail screen. The ambiguities inherent in this compressed requirement are surfaced explicitly in the Risk & Gap Analysis below rather than silently assumed.)

## Domain Concept Identification

### Existing Concepts (from codebase)

- **`CardKind.nightlyRecharge`**: Already a first-class dashboard domain — glyph `"R"`, title `"NIGHTLY RECHARGE"`, positioned 3rd in the `CaseIterable` home-feed order. The card enum needs no change; it simply isn't navigable yet.
- **Nightly Recharge data pipeline (fully built, end-to-end)**: The domain is already fetched, synced, persisted, and readable — only the *presentation* half is missing.
  - `NightlyRecharge` (wire model, `PolarProtocol/V3/RechargeModels.swift`) — decodes `ans_charge` (signed Double), `ans_charge_status` / `nightly_recharge_status` (**integer codes**), HR/HRV/breathing/beat-to-beat averages, and `"HH:MM"`-keyed `hrv_samples` / `breathing_samples` maps.
  - `V3DataClient.fetchNightlyRecharge()` — `GET /v3/users/nightly-recharge`, server-bounded to ~28 days.
  - `SyncRegistry` domain `.recharge` (p1, windowless) — `store.upsertRecharge(...)`.
  - `RechargeRecord` (store) + `upsertRecharge` (write) + `recharge(date:) -> RechargeView?` (read).
- **`RechargeView`** (`PolarStore/Store/Views.swift`): The read-time value type — carries `date`, `ansCharge`, `ansChargeStatus`, `nightlyRechargeStatus`, `hrAvg`, `hrvAvg`, `breathingAvg`, `beatToBeatAvg`, and the decoded sample maps. This is the raw material a detail provider will shape.
- **Detail-screen pattern (the template to mirror)**: The Sleep and Boost slices established a repeatable four-part vertical slice:
  1. A flat UI-facing display model in `PolarProtocol` (`SleepDetail`, `BoostDetail`) with an embedded `state` enum for render modes and static `noData`/`placeholder`/`sample` factories.
  2. A `…Providing` protocol + `Stub…Provider` (for previews / no-store fallback), also in `PolarProtocol`.
  3. A `Store…DetailProvider` in `PolarStore` that assembles the model from `StoreReading`, zero network, non-throwing.
  4. A `@MainActor @Observable …DetailModel` + a bespoke SwiftUI `…View` in `HerculesUI`, with day-navigation (`showOlder`/`showNewer`, most-recent-first `index`).
- **Dashboard routing seam** (`DashboardModel`): `DetailRoute` enum, `hasDetail(for:)`, and `detailModel(for:) -> DetailRoute?` centralize navigation. Adding a new detail screen is "one more case" by design (Approach 2 comment). Injected detail providers are wired at the composition root (`HerculesApp.init`).
- **Dashboard click linking** (`DashboardView`): `NavigationLink(value: card.kind)` is emitted only when `model.hasDetail(for: card.kind)`; `.navigationDestination(for: CardKind.self)` switches over the built `DetailRoute`. The click mechanism already exists — Nightly Recharge just isn't enrolled in it.
- **`StoreDashboardProvider` + per-domain card formats** (`ActivityCardFormat`, `SleepCardFormat`, `BoostCardFormat`): Build each card's glance headline/detail from the latest stored row. Nightly Recharge currently falls through to the `default: DashboardCard(kind: kind, state: .empty)` branch.

### New Concepts Required

- **`RechargeDetail`** (display model, `PolarProtocol/Dashboard/`): The flat, UI-visible shape for the Recharge screen — a `RechargeState` render-mode enum (measured / not-measured, mirroring Boost's `state`), the recharge-status classification, the ANS-charge value + its "above/below usual" classification, the sleep-charge value + classification, the four vitals (HR, HRV, breathing rate, beat-to-beat), and the time-series needed for the ANS 4-hour-window chart.
- **`RechargeDetailProviding` protocol + `StubRechargeDetailProvider`** (`PolarProtocol`): Read seam + synthetic-data stub for previews and the no-store fallback.
- **`StoreRechargeDetailProvider`** (`PolarStore/Dashboard/`): `StoreReading`-backed assembler — shapes `RechargeView` into `RechargeDetail`, selecting render state from row presence, zero network, non-throwing.
- **`RechargeDetailModel` + `RechargeView` (UI)** (`HerculesUI/Detail/`): The `@Observable` view-model + bespoke screen, with the same day-navigation ergonomics as Sleep/Boost. (Note the UI view name will collide conceptually with the store's `RechargeView` read type — a disambiguating name is needed, e.g. `RechargeDetailView`.)
- **`RechargeCardFormat`** (`PolarStore/Dashboard/`): The dashboard-card glance builder for the NIGHTLY RECHARGE card, populated from the latest recharge row.
- **Recharge status semantics**: A mapping from the raw integer `nightly_recharge_status` and `ans_charge_status` codes to the display classifications the design names (`COMPROMISED`, `ABOVE USUAL`, `MUCH BELOW USUAL`, etc.). No such mapping exists today — the codes are persisted as raw `Int`s.
- **Recharge date-list reader**: A `StoreReading` accessor returning available recharge dates (most-recent-first) — required for both "latest night" on the dashboard and day-navigation on the detail screen. Only a single-date `recharge(date:)` reader exists today.
- **28-day baseline concept**: The design's "28-DAY BASELINE" and "ABOVE/BELOW USUAL" language implies a personal baseline computed across the stored recharge window — a derived aggregate, not a wire field.

### Key Business Rules

- **Recharge status governs the hero render**: The `nightly_recharge_status` code drives the top-level "RECHARGE STATUS" label and the hero charge-bar fill (design shows `COMPROMISED ≈ 32%`). — governs `RechargeDetail.state` + status classification.
- **No-data is a first-class state, never a zeroed reading**: When the band wasn't worn (no recharge row for that date), the screen shows the "NOT MEASURED / TELEMETRY UNAVAILABLE" frame with em-dashes and a "SYNC BAND" prompt — never a fabricated 0. — mirrors `BoostDetail.noData` / Norm "no data ≠ zero".
- **ANS charge is signed and centered on zero**: Rendered on a −10…+10 gauge with a zero tick; its classification ("ABOVE USUAL") comes from `ans_charge_status`, positioned against the personal baseline. — governs the ANS sub-detail.
- **Sleep charge is a distinct 0–100 metric with its own "usual" marker**: Shown below-usual against a dashed usual marker in the design. — governs the sleep-charge row (see the cross-domain sourcing risk below).
- **The ANS 4-hour-window chart is built from the time-keyed `hrv_samples` map**: Keys are `"HH:MM"` **local** clock (per the `sleep-night clock basis` memory pattern for these time-keyed maps) — anchor the chart on the keys, not decoded datetimes.
- **Detail screens are local-first and instant (no spinner)**: Reads return synchronously from the store; provider always returns a value, never `nil` — the empty case is carried in the state enum.
- **Day navigation is most-recent-first, bounded to the ~28-day server window**: `index = 0` is the newest night; `canShowOlder` stops at the oldest stored recharge date.

## Strategic Approach

### Solution Direction

Deliver Nightly Recharge as a **fifth instance of the established detail-screen vertical slice**, reusing the Sleep/Boost template end to end, and **enroll `nightlyRecharge` in the existing dashboard routing seam** so the card click links to it. Concretely, the data flow is: `StoreReading` (recharge row + new date-list reader) → `StoreRechargeDetailProvider` (assembles `RechargeDetail`, selects render state) → `RechargeDetailModel` (`@Observable`, day-navigation) → bespoke `RechargeDetailView`; and separately `RechargeCardFormat` → the NIGHTLY RECHARGE dashboard glance. Linking is achieved by extending `DashboardModel.hasDetail`, `detailModel`, and `DetailRoute` with a `.recharge` case, adding one `navigationDestination` branch in `DashboardView`, and injecting a `rechargeDetail` provider at the composition root (`HerculesApp.init`) — the same three-touchpoint change the Boost slice made.

The requirement's two halves map cleanly onto this: "nightly recharge feature" = the detail-screen slice (net-new presentation over the already-built data pipeline); "linking with dashboard click" = enrolling the card in the routing seam that already links Activity, Sleep, and Boost.

### Key Design Decisions

- **Reuse the detail-slice template vs. invent a new screen abstraction**: Trade-off — the template constrains the Recharge screen to the same model/provider/VM/view shape, which the design's multi-frame layout (overview + ANS sub-detail + no-data) stretches more than Boost did. → **Recommendation: reuse the template.** Consistency, injection wiring, and the "one more case" routing seam are the whole point of the pattern; the extra frames are internal composition within the bespoke `RechargeDetailView`, not a new architecture.
- **Where "recharge status" / "ANS status" classification lives**: Trade-off — the raw integer codes could be mapped in the wire model, at the store read boundary (like `CardioLoadStatus` restores its enum in `toView()`), or in the detail provider. → **Recommendation: resolve semantics in the detail provider / `PolarProtocol` display layer** (where `BoostDetail`'s `classification`/`GradeClass` live), keeping the raw `Int` codes untouched in storage. Rationale: the integer→label meaning is a *presentation* concern and its exact code mapping is currently unknown (see risks); isolating it in the provider keeps the storage schema stable and the mapping easy to revise once verified live.
- **Sleep-charge sourcing**: Trade-off — the design shows a "SLEEP CHARGE" metric, but the `nightly-recharge` endpoint (`API_RESPONSE_SHAPES.md §3`) has **no sleep-charge field**. Options: (a) source it cross-domain from the sleep / SleepWise store, (b) omit it for this slice, (c) treat it as always-unavailable. → **Recommendation: flag for clarification; default to sourcing from the existing sleep domain if a clean field exists, else render it as an explicit "no data" sub-row** rather than fabricating. This is the single biggest scoping decision and is escalated in the Risk analysis.
- **Add a `rechargeDates()` reader vs. reuse an existing dates seam**: → **Recommendation: add a dedicated `rechargeDates()` `StoreReading` accessor** mirroring `sleepwiseDates()` / `sleepDates()`. It's the minimal, pattern-consistent addition and is required for both latest-night and day-navigation.
- **Card glance scope**: → **Recommendation: `RechargeCardFormat` shows the recharge-status label + ANS charge as the headline/detail**, degrading to `.empty` when no row exists — matching `BoostCardFormat`'s shape and the "Data constraint / no per-domain `DashboardCard` fields" safeguard.

### Alternatives Considered

- **Modify `DashboardModel.select(_:)` / bespoke navigation for Recharge**: Rejected — `select` is a no-op legacy seam; the live navigation path is `NavigationLink(value:)` + `navigationDestination`, which the routing seam already drives. Adding Recharge there would fork the navigation model.
- **Add sleep-charge and status fields to the stored schema now**: Rejected for this slice — the wire endpoint doesn't supply sleep charge, and the integer-code semantics are unverified; persisting derived/uncertain values would violate the "storage stays stable, presentation derives" convention and risk a schema churn.
- **Skip the ANS 4-hour-window chart to ship faster**: Rejected as a default — the `hrv_samples` map is already stored and is the design's signature element of the ANS sub-detail; omitting it would materially under-deliver the "feature". Noted as a possible phasing fallback if scope must be cut.

## Risk & Gap Analysis

### Requirement Ambiguities

- **Scope of "feature"**: The one-line requirement doesn't state whether the full multi-frame design (overview + ANS charge sub-detail + no-data frame) is in scope, or only a minimal tappable detail screen. Assumed: full detail screen matching the design, consistent with the Sleep/Boost precedent.
- **"linking with dashboard click" granularity**: Ambiguous whether this means only dashboard-card → recharge screen, or also the design's intra-screen "TAP A CARD TO DRILL ▸" (recharge overview → ANS charge detail). Assumed: the primary ask is the dashboard-card link; the intra-screen drill is part of the detail screen's own composition.
- **Sleep-charge definition**: The design surfaces "SLEEP CHARGE" but no such field exists in the recharge wire shape — its source and 0–100 scaling are unspecified.

### Edge Cases

- **Band not worn / missing recharge row**: Must render the "NOT MEASURED" frame (em-dashes + SYNC BAND), not a zeroed reading — the provider must never return `nil` and never fabricate 0.
- **Partial night data**: A recharge row present but with `nil` `ansCharge`, empty `hrv_samples`, or missing status code — each sub-element must degrade independently (e.g. show ANS gauge but a "no data" chart).
- **Unknown / out-of-range status codes**: An integer status code outside the known mapping must fall back to a neutral label rather than crash or mislabel.
- **Empty recharge history**: Fresh user with zero synced recharge nights → day-navigation must yield a graceful no-data state, and the dashboard card must be `.empty`.
- **28-day baseline with sparse data**: "Above/below usual" needs a baseline; with only a few nights the baseline is unreliable — behavior undefined by the requirement.
- **Local vs. UTC clock for the sample maps**: The `"HH:MM"` keys are local clock while row datetimes decode as UTC (per the `sleep-night clock-basis` memory) — mixing them would misplace the chart.

### Technical Risks

- **Integer status-code semantics are unverified**: `nightly_recharge_status` / `ans_charge_status` are stored as raw `Int`s with no enum mapping; the design's labels (`COMPROMISED`, `ABOVE USUAL`, `MUCH BELOW USUAL`) imply a code→label table that must be confirmed against a live capture before it can be trusted. Mitigation: isolate the mapping in the provider/display layer and verify live (consistent with how `SleepWise`/`Boost` states were "verified live").
- **Missing `rechargeDates()` reader**: `StoreReading` only exposes `recharge(date:)`; day-navigation and "latest night" both need a dates list. Mitigation: add the reader mirroring `sleepwiseDates()`.
- **Sleep-charge cross-domain coupling**: If sourced from the sleep domain, the Recharge provider gains a dependency on sleep reads, increasing coupling; if omitted, the screen diverges from the design. Mitigation: decide sourcing explicitly (escalated above).
- **Naming collision**: The store's read type is already named `RechargeView`; a UI view named `RechargeView` would clash. Mitigation: name the SwiftUI screen `RechargeDetailView` (Boost used `BoostView`, but Recharge can't without colliding).
- **Baseline computation cost/placement**: Computing a 28-day baseline on every read is cheap at this scale but must live in the provider (read-time), not storage, to stay consistent with the "presentation derives" convention.

### Acceptance Criteria Coverage

No formal ACs were supplied with the requirement. The table below derives implicit ACs from the requirement text + the design handoff and assesses addressability with the proposed approach. These should be confirmed with the requester during REASONS Canvas.

| AC# | Description | Addressable? | Gaps/Notes |
|-----|-------------|--------------|------------|
| 1 | Tapping the NIGHTLY RECHARGE dashboard card pushes a Nightly Recharge detail screen | Yes | Enroll `.nightlyRecharge` in `hasDetail`/`detailModel`/`DetailRoute` + one `navigationDestination` branch |
| 2 | Detail screen shows recharge status, ANS charge, sleep charge, and vitals (HR/HRV/BR/B2B) from the latest stored night | Partial | Sleep charge not in recharge wire shape — sourcing must be decided |
| 3 | ANS charge sub-detail with the −10…+10 gauge and 4-hour HRV window chart | Yes | Built from stored `hrv_samples` map; anchor on local `"HH:MM"` keys |
| 4 | "NOT MEASURED" no-data frame when the band wasn't worn | Yes | Mirror `BoostDetail.noData`; provider never returns `nil` |
| 5 | Status labels (COMPROMISED / ABOVE-BELOW USUAL) reflect the night's status codes | Partial | Integer code→label mapping unverified; isolate in provider, verify live |
| 6 | Day-navigation across the ~28-day recharge window (older/newer) | Yes | Requires new `rechargeDates()` reader |
| 7 | NIGHTLY RECHARGE dashboard card shows a populated glance (vs. `.empty`) | Yes | Add `RechargeCardFormat`, wire into `StoreDashboardProvider` |
| 8 | "28-DAY BASELINE" / "usual" comparisons | Partial | Baseline is a derived aggregate; behavior with sparse data undefined |
