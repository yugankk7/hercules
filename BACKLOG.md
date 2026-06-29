# Project Hercules — Backlog

Jira-style stories grouped by epic, sized small. Built from the validated data architecture (see ARCHITECTURE.md). Phase-1 = the working AccessLink dashboard. Phase-2 = BLE SDK (live HR + battery). Priorities: **P0** blocks everything downstream, **P1** core dashboard, **P2** enhancement, **P3** deferred.

Labels: `[v3]` `[v4]` `[ble]` `[ui]` `[infra]` `[spike]`

---

## EPIC 0 — Project foundation

**HERC-001 · Scaffold the Xcode project** · P0 · `infra`
Create the SwiftUI app target (iOS 14+), set bundle id, register the `hercules://` URL scheme for OAuth callback.
- AC: app builds and runs empty; `hercules://oauth/callback` opens the app.

**HERC-002 · Add Swift Package dependencies** · P0 · `infra`
Add GRDB via SPM. (Hold polar-ble-sdk until phase 2.)
- AC: GRDB imports and compiles; a throwaway DB opens and closes cleanly.

**HERC-003 · Modular package structure** · P1 · `infra`
Split into local packages mirroring NOOP: `PolarProtocol` (API models/clients), `PolarStore` (GRDB), `HerculesUI` (design system + screens).
- AC: each package builds independently; app depends on all three.

**HERC-004 · Keychain wrapper** · P0 · `infra`
Tiny Keychain helper for storing/reading tokens and secrets.
- AC: round-trip store/read/delete of a string works; nothing sensitive in UserDefaults.

---

## EPIC 1 — Authentication (three models)

**HERC-010 · v3 token acquisition + storage** · P0 · `v3`
One-time OAuth against `flow.polar.com/oauth2/authorization` (scope `accesslink.read_all`), exchange at `polarremote.com/v2/oauth2/token`, store the ~10-year bearer in Keychain.
- AC: a stored v3 bearer authenticates a test call; **no refresh logic built** (v3 issues none).

**HERC-011 · One-time user registration** · P0 · `v3`
`POST /v3/users` with `{"member-id": ...}` once per user; handle already-registered gracefully.
- AC: returns 201 on first run; subsequent runs no-op without error.

**HERC-012 · v4 OAuth flow** · P0 · `v4`
Authorize against `auth.polar.com/oauth/authorize` requesting **all needed scopes in one consent** (see ARCHITECTURE §7), exchange at `auth.polar.com/oauth/token`.
- AC: returns access (1 h) + refresh (~100 d) pair; both stored in Keychain; granted scopes logged.

**HERC-013 · v4 refresh-aware HTTP client** · P0 · `v4`
Wrap v4 calls so a 401/expiry triggers a refresh-token exchange, swaps the stored pair, and retries once. **This gates all v4 sync — build before any v4 fetch story.**
- AC: an expired access token transparently refreshes and the original call succeeds; a failed refresh surfaces a clean re-auth prompt.

---

## EPIC 2 — AccessLink v3 client `[v3]`

> Date format for all v3: `YYYY-MM-DD`.

**HERC-020 · Sleep fetch + model** · P1
`GET /v3/users/sleep` → decode `nights[]` (hypnogram, stage totals, `heart_rate_samples`, `sleep_score`, continuity, cycles, charge).
- AC: typed models decode a live response; ~25 nights parsed.

**HERC-021 · Nightly recharge fetch + model** · P1
`GET /v3/users/nightly-recharge` → `recharges[]` (ans_charge, statuses, HR/HRV/breathing averages + 5-min sample arrays).
- AC: models decode live data; sample arrays intact.

**HERC-022 · Cardio load fetch + model** · P1
`GET /v3/users/cardio-load` → strain/tolerance/ratio/status, 28 days.
- AC: 28-day series decodes; status string mapped to an enum.

**HERC-023 · Continuous HR fetch + downsample** · P1
`GET /v3/users/continuous-heart-rate?from=&to=` (~5-sec samples, ≈16 MB/28 d). Bucket to **per-minute min/avg/max** on ingest.
- AC: a multi-day pull never persists raw 5-sec rows; minute rows written; peak memory bounded.

**HERC-024 · Daily activity summary fetch** · P1
`GET /v3/users/activities/{date}` (and `/activities?from=&to=` for ranges). Decode computed totals: `steps`, `calories`, `active_calories`, `active_duration`/`inactive_duration`, `daily_activity`, `inactivity_alert_count`, `distance_from_steps`. **No derivation needed — v3 returns totals directly.**
- AC: a 7-day range decodes with all tiles populated; history confirmed (not transactional).

**HERC-025 · Daily activity samples + zones fetch** · P1
`GET /v3/users/activities/samples/{date}`. Decode per-minute `steps` (`interval_ms`, `total_steps`, `samples[]`), **`activity_zones`** (the intensity-zone bar), `inactivity_stamps`. Downsample steps on ingest.
- AC: step graph + zone bar reproducible from the response; no MET math required.

**HERC-026 · Sleep manifest (optional sync optimization)** · P2
`GET /v3/users/sleep/available` → `available[]` (dates with data). Use to fetch only existing nights.
- AC: sync queries the manifest first and skips empty nights.

---

## EPIC 3 — AccessLink v4 client (narrow supplement) `[v4]`

> v4 is used for **only three things** — workout history, devices, sport names. Activity moved to v3 (EPIC 2). `training-sessions/list` uses **naive datetime** (`YYYY-MM-DDTHH:MM:SS`); the other two take no dates.

**HERC-032 · Training sessions fetch** · P1
`GET /training-sessions/list?from=&to=`, **naive datetime format**. Decode inline summary + `exercises[]` macros. **No `features` param** (it 400s).
- AC: 24+ sessions decode; macros (fat/carb/protein %), hrAvg/Max, benefit, recovery, trigger, sport id all populated; history backfills.

**HERC-033 · Sports catalog fetch + cache** · P2
`GET /sports/list` (no dates). Seed `sport_ref` (id → name). Reference data — refresh rarely, not per-sync.
- AC: sport id 83 resolves to its name; catalog cached and reused across syncs.

**HERC-034 · Device info fetch** · P2
`GET /user-devices` (no dates). Store firmware, UUID, color, registration, `deviceSettings` (incl. `automaticTrainingDetection`).
- AC: device row populated; battery correctly **absent** (documented, deferred to BLE).

---

## EPIC 4 — Local store (GRDB) `[infra]`

**HERC-040 · Schema + migrations** · P0
Define tables (see ARCHITECTURE §9): hr_minute, activity_minute, sleep_night, recharge, cardio_load, training_session, sport_ref, device, sync_state. Set up GRDB migrations.
- AC: fresh install creates all tables; a no-op migration run is idempotent.

**HERC-041 · Upsert helpers + dedup** · P1
Generic upsert keyed on date (samples/day rows) or session id. Re-syncing an overlapping window must not duplicate.
- AC: syncing the same window twice yields identical row counts.

**HERC-042 · Read APIs for the UI** · P1
Query functions returning display-ready ranges (e.g. HR for an arbitrary day window) entirely from the DB.
- AC: card queries return in <16 ms on a populated DB; zero network in the read path.

---

## EPIC 5 — Sync engine `[infra]`

**HERC-050 · Config-driven domain registry** · P1
One entry per metric: endpoint, fetch window, default display window, sync priority, API max-range cap.
- AC: changing a fetch window is a one-line edit; sync reads windows from config.

**HERC-051 · Manual refresh orchestration** · P1
Refresh button runs all domains by priority, writes to the store, updates `sync_state`, surfaces per-domain success/failure.
- AC: one tap refreshes everything; partial failure (one domain) doesn't abort the rest.

**HERC-052 · Per-day activity loop** · P1
Activity detail loops per day across the window (heaviest path), downsampling each day immediately.
- AC: a 30-day activity sync completes without unbounded memory; each day's samples downsampled before the next fetch.

**HERC-053 · Range-cap guards** · P2
Clamp each domain's requested window to the API max (continuous-samples 30 d, recharge 28 d, calendar 90 d) and page if needed.
- AC: requesting >cap auto-splits into valid sub-requests; no 400s from oversized ranges.

**HERC-054 · Incremental sync ("just the new days")** · P1 — *in Epic 5 scope*
A domain's first sync pulls the full lookback (the backfill that captures existing history); every later refresh fetches only what changed since the last *successful* sync, so routine refreshes stay cheap (the activity per-day loop shrinks from ~`lastDays` round-trips to just the recent days). Anchored on the existing `lastSync(domain:) -> Date?` read (no `last_window` parsing, no schema change): effective window = `[lastSync − overlap, now]`, with a small overlap (~2 d) so server-side corrections to recent days are re-pulled; idempotent upserts absorb the overlap. `recordSync` runs only on success, so a failed domain keeps its anchor. Windowless domains (sleep/recharge/cardio/sports/devices) are exempt — server-fixed set. Distinct from backfill (HERC-053 reaches *old* history; this avoids re-pulling *recent* history).
- AC: a refresh shortly after a previous one fetches only the new/changed days (few round-trips), not the whole window; data remains identical to a full re-pull; a never-synced domain gets the full lookback.

---

## EPIC 6 — UI wiring (dashboard) `[ui]`

> Visual design handled separately in Claude Design; these wire data into the views.

**HERC-060 · Cardio load card** · P1
Strain/tolerance trend lines + per-day load bars + status text, from `cardio_load`.
- AC: reproduces the Cardio Load screen from local data.

**HERC-061 · Activity card** · P1
Steps, distance, calories, intensity-zone bar, goal ring, from the v3 `activity_day` totals + `activity_zones` (direct, no derivation).
- AC: reproduces the daily activity screen; range switch hits zero network.

**HERC-062 · HR card** · P1
24/7 HR curve with min/avg/max markers, from `hr_minute`.
- AC: reproduces the continuous-HR screen at minute resolution.

**HERC-063 · Sleep & recharge cards** · P1
Hypnogram + score; ANS/HRV/breathing, from `sleep_night` / `recharge`.
- AC: reproduces both screens from local data.

**HERC-064 · Workout list** · P1
Session rows (sport name, time, calories, benefit) from `training_session`, sport id resolved via `sport_ref`.
- AC: list renders with human sport names; auto-detected sessions flagged via `startTrigger`.

---

## EPIC 7 — Workout detail (one call + local slice) `[ui]`

**HERC-070 · HR-curve reconstruction** · P1
On opening a session, slice stored continuous HR to `startTime`→`stopTime`; render the curve. No extra fetch.
- AC: detail HR graph renders purely from the local HR table.

**HERC-071 · Time-in-zones bucketing** · P1
Bucket the sliced HR against zone boundaries to build the zone-distribution bar.
- AC: zone bar renders; totals sum to session duration.

**HERC-072 · Macros + summary panel** · P2
Render inline session fields (fat/carb/protein %, recovery, benefit) from the session row.
- AC: panel matches the Polar workout detail summary fields.

---

## EPIC 8 — BLE SDK (Phase 2) `[ble]`

**HERC-080 · Integrate polar-ble-sdk + bonding** · P2 · `spike`
Add the SDK (SPM), establish Bluetooth bonding to the Loop, handle connection state. Budget for the RxSwift/Protobuf bridge.
- AC: app connects to the Loop and reports connection state; bond persists across launches.

**HERC-081 · Battery level** · P2
`FEATURE_BATTERY_INFO` → `batteryLevelReceived`; surface on the device/dashboard view.
- AC: live battery % displayed when connected.

**HERC-082 · Live HR stream** · P2
Real-time HR while connected, shown as a live pulse on the dashboard.
- AC: HR updates in real time when the band is connected.

---

## EPIC 9 — SleepWise & Biosensing (Boost from sleep) `[v3]`

> Phase-1 core. SleepWise lives in the **v3** tree (date format `YYYY-MM-DD`). Earlier assumed absent — it isn't.

**HERC-090 · SleepWise alertness fetch + model** · P1
`GET /v3/users/sleepwise/alertness/date?from=&to=`. Decode `grade` (Boost score), `grade_classification`, `sleep_inertia`, `hourly_data[].alertness_level`. Confirmed with live data.
- AC: a live day decodes; hourly alertness levels map to bar buckets; 28-day variant also wired.

**HERC-091 · SleepWise circadian bedtime fetch** · P1
`GET /v3/users/sleepwise/circadian-bedtime/date?from=&to=` (path confirmed). Decode **sleep gate** + **sleep window**; `quality` = gate recognizability (1/3–3/3).
- AC: sleep-gate time + window decoded for a live day; quality mapped.

**HERC-092 · Biosensing (temp / SpO2)** · P3 — PARKED
Probed: Loop Gen 2 returns **204 / empty** — no body-temp/skin-temp/SpO2 sensors. Endpoints exist but no data on this hardware.
- AC: parked; re-open only if hardware changes.

**HERC-093 · Boost-from-sleep card** · P1 · `ui`
Combine alertness (hourly bars + Boost score) and circadian bedtime (sleep gate/window markers) into the screen.
- AC: reproduces the Boost from sleep screen from local data once HERC-090/091 land.

---

## EPIC 10 — Deferred / spikes `[spike]`

**HERC-100 · PPI data** · P3
Endpoint/format proven, no data seen, not on any screen. Revisit only if a feature needs raw beat-to-beat.
- AC: parked; re-open only with a concrete use case.

**HERC-101 · Skin contact (wear-time)** · P3
Possible data-quality signal. Revisit, likely via BLE.
- AC: parked.

**HERC-102 · Routes / GPS** · P3
Needs a `routeId` (favorites/targets returned empty). Revisit if outdoor GPS workouts appear.
- AC: parked until GPS sessions exist.

**HERC-103 · Background refresh** · P3
Best-effort `BGAppRefreshTask`. Never a correctness dependency.
- AC: opportunistic background sync when iOS grants it; manual refresh remains source of truth.
