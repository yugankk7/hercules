# SPDD Analysis: Sync Engine — Epic 5

## Original Business Requirement

> Epic 5 — the sync engine (HERC-050 config-driven domain registry, HERC-051 manual
> refresh orchestration, HERC-052 per-day activity loop, HERC-053 range-cap guards). The
> pre-Epic-5 store-readiness items in `spdd/PRE-EPIC-5-store-readiness.md` are now
> implemented. Build the analysis grounded in the existing v3/v4 clients (Epic 2/3), the
> PolarStore (Epic 4), and the dashboard refresh stubs.

**Formal scope (from `BACKLOG.md` EPIC 5 — Sync engine `[infra]`):**

- **HERC-050 · Config-driven domain registry** · P1 — One entry per metric: endpoint,
  fetch window, default display window, sync priority, API max-range cap.
  _AC: changing a fetch window is a one-line edit; sync reads windows from config._
- **HERC-051 · Manual refresh orchestration** · P1 — Refresh button runs all domains by
  priority, writes to the store, updates `sync_state`, surfaces per-domain
  success/failure. _AC: one tap refreshes everything; partial failure (one domain)
  doesn't abort the rest._
- **HERC-052 · Per-day activity loop** · P1 — Activity detail loops per day across the
  window (heaviest path), downsampling each day immediately. _AC: a 30-day activity sync
  completes without unbounded memory; each day's samples downsampled before the next
  fetch._
- **HERC-053 · Range-cap guards** · P2 — Clamp each domain's requested window to the API
  max (continuous-samples 30 d, recharge 28 d, calendar 90 d) and page if needed.
  _AC: requesting >cap auto-splits into valid sub-requests; no 400s from oversized
  ranges._

**Supporting context (`ARCHITECTURE.md` §10 — Sync engine):** manual refresh is the
phase-1 trigger; per-domain windows come from the config registry, each capped to the
API max; activity fetches the daily summary and the sample/zone detail per day across
the window (no MET math, no `features` loop); the sleep manifest may optionally be hit
first to skip empty nights; upsert/dedup is keyed on date or session id; v3 uses the
bearer directly while v4 routes through the refresh-aware client.

**Pre-Epic-5 groundwork (now implemented, per `spdd/PRE-EPIC-5-store-readiness.md`):**
the one on-disk `PolarDatabase` is opened at the composition root
(`App/HerculesApp.swift` via `PolarDatabase.onDisk()`) and held for injection;
minute-table `date` partitioning is derived from each minute's own UTC day
(`PolarDayKey`), so the minute upsert APIs take minutes directly with no batch date to
get wrong; `StoreWriting`/`StoreReading` are the protocol seams the engine writes/reads
through.

---

## Domain Concept Identification

### Existing Concepts (from codebase)

- **`V3DataClient`** (`Packages/Sources/PolarProtocol/V3/V3DataClient.swift`): decode-only
  v3 fetchers. Three call *shapes* the engine must accommodate: **windowless** (`fetchSleep`,
  `fetchNightlyRecharge`, `fetchCardioLoad`, `fetchSleepManifest` — the server returns a
  fixed recent set), **windowed** (`fetchContinuousHeartRate(DateWindow)`,
  `fetchDailyActivity(DateWindow)`), and **per-day** (`fetchActivitySamples(date:)`,
  `fetchDailyActivity(date:)`). Continuous-HR and activity-samples already downsample
  internally, so raw arrays never reach the engine.
- **`V4DataClient`** (`.../V4/V4DataClient.swift`): windowed `fetchTrainingSessions(DateWindow)`
  (naive datetime, no `features`) and windowless `fetchSports`, `fetchDevices`. Every call
  already routes through `RefreshAwareV4Client`.
- **`V3Transport` / `RefreshAwareV4Client`** (`.../Networking`, `.../Auth`): the transports
  the two clients are built from. `V3Transport` reads the v3 credential from the token store
  **per call**; `RefreshAwareV4Client` is an actor that injects the v4 bearer and
  refreshes-on-401. The engine needs *authenticated* clients — i.e. transports wired from
  the live token store.
- **`AuthManager`** (`.../Auth/AuthManager.swift`): owns connection state and the token
  store; the dashboard is only shown when `state == .connected`. The source of the
  credentials the transports read. `signOut()` exists — tokens can disappear under a
  long-lived engine.
- **`DateWindow`** (`.../Networking/DateWindow.swift`): formats `from`/`to` into the right
  dialect but **explicitly does not clamp** to the API max — its own doc names range-cap
  splitting as the Epic 5 concern. Directly relevant to HERC-053.
- **`PolarStore` write/read facades** (`StoreWriting`/`StoreReading`,
  `PolarDatabase+Writing/Reading.swift`): the idempotent upserts the engine calls per
  domain, plus `recordSync(domain:window:)` and `lastSync(domain:) -> Date?`. Writes are
  per-domain transactions; re-syncing overlapping windows is already proven idempotent.
- **`RefreshCoordinating` + `StubRefreshCoordinator`** (`.../Dashboard/RefreshCoordinating.swift`):
  **the seam Epic 5 fills.** `refresh() async throws -> SyncFreshness`. The stub just sleeps
  and returns a timestamp; the real engine replaces it. `throws` is already reserved for the
  partial-failure path.
- **`DashboardModel`** (`HerculesUI/Dashboard/DashboardModel.swift`): `@MainActor @Observable`;
  `refresh()` already guards re-entrancy, calls `coordinator.refresh()`, records
  `lastRefreshFailed`, and re-pulls the provider snapshot. Already shaped for partial
  failure — but currently only a single `lastRefreshFailed` Bool, not per-domain status.
- **`SyncFreshness`** (`.../Dashboard/SyncFreshness.swift`): `neverSynced` / `syncedAt(Date)` —
  the engine's aggregate return value.
- **`CardKind`** (`.../Dashboard/CardKind.swift`): the 8 dashboard domains the registry maps
  onto (dailyActivity, sleep, nightlyRecharge, cardioLoad, boostFromSleep, continuousHR,
  latestWorkout, deviceGlance).
- **On-disk `PolarDatabase`** (`App/HerculesApp.swift`, `PolarDatabase+Disk.swift`): opened
  and held at the composition root, awaiting injection into the engine and the store-backed
  provider.
- **`ARCHITECTURE.md` §7/§10**: the authoritative endpoint list, range caps, and sync-engine
  contract.

### New Concepts Required

- **Domain registry (HERC-050)** — a declarative collection of per-metric descriptors:
  identity, sync priority, fetch-window policy, default display window, and API max-range
  cap. The single place windows/priorities are configured ("one-line edit"). Relates to
  every client method and every `upsert…`.
- **Sync engine / refresh orchestrator (HERC-051)** — a concrete `RefreshCoordinating` that,
  given authenticated clients + a `StoreWriting`, runs the registry by priority, writes each
  domain, records `sync_state`, isolates per-domain failure, and returns aggregate
  `SyncFreshness` plus per-domain outcomes. The orchestration core that ties Epic 2/3/4
  together.
- **Per-domain sync outcome** — the success/failure (and error) result for one domain,
  collected across a refresh and surfaced to the UI. New currency the AC explicitly
  requires.
- **Window policy + range-cap splitter (HERC-053)** — the rule that turns "domain + now"
  into one or more API-valid `DateWindow`s: compute the requested window from the fetch
  policy, clamp to the domain's max cap, and page oversized ranges into sub-requests
  (overlaps are safe — upserts dedup). Relates to `DateWindow` and the windowed domains
  only.
- **Per-day activity sequencing (HERC-052)** — the rule that the activity-detail domain
  iterates day-by-day across the window, fetching + downsampling + upserting each day
  before the next, so peak memory stays bounded. Combines daily totals with per-day
  zone/sample detail into the store's `upsertActivity(day:zones:)`.
- **Incremental window / last-sync anchor (HERC-054)** — the rule that a routine refresh
  fetches only what changed since the domain's last *successful* sync, instead of re-pulling
  the whole window every time. The anchor is the existing `lastSync(domain:) -> Date?` read:
  if a prior sync exists, the effective window is `[lastSync − overlap, now]` (a small
  re-pull buffer so server-side corrections to recent days are caught); if not, it falls
  back to the full lookback (the first-sync **backfill** that captures existing history).
  Idempotent upserts absorb the overlap. Relates to `lastSync`/`recordSync`, the windowed
  and per-day domains (windowless domains are unaffected — the server fixes their set).
- **Authenticated client provisioning** — building the v3/v4 clients (and their transports)
  from the live token store and handing them to the engine. A composition-root concern, but
  new wiring that did not exist while the clients were decode-only.
- **A "now"/clock seam** — an injectable current-time source so window computation and the
  engine are deterministically testable.

### Key Business Rules

- **Manual refresh is the only network trigger** (Safeguard 5). One tap runs the whole
  registry. Governs the engine's entry point; background refresh stays deferred (HERC-103).
- **Run by priority; partial failure is isolated.** Domains execute in priority order and
  one domain's failure must not abort the others (HERC-051 AC). Governs the orchestration
  loop and the per-domain outcome.
- **Windows come from config, not call sites** (HERC-050 AC). Changing a fetch window is a
  one-line registry edit. Governs the registry's shape.
- **Range caps bound windowed requests** (HERC-053): continuous-HR 30 d, calendar/activity
  90 d, training sessions 90 d. Over-cap → 400. Governs the splitter — but **only for the
  windowed endpoints**; the recharge/cardio/sleep clients are windowless (server returns a
  fixed recent set), so the "recharge 28 d" cap is enforced server-side, not by the engine.
- **Activity is the heaviest path and must stay memory-bounded** (HERC-052). Per-day loop;
  each day downsampled (already client-side) and written before the next fetch. Governs the
  activity domain's sequencing.
- **Writes are idempotent; re-sync is safe.** The store guarantees dedup on natural keys, so
  the engine may re-pull overlapping windows freely without duplicates. This is what makes
  the incremental overlap buffer (and any first-sync/backfill overlap) safe.
- **`sync_state` is updated per domain** after a successful sync (`recordSync`), and
  `lastSync(domain:)` is **read at the start of each domain** to compute its incremental
  window (HERC-054). A domain whose last sync failed keeps its old anchor, so the next
  refresh re-pulls from the last *successful* point. Governs incremental windowing and
  freshness.
- **Authentication is a precondition.** Refresh runs only when connected; v3 uses the
  long-lived bearer (no refresh), v4 refreshes-on-401 inside its transport. A failed/absent
  credential must surface cleanly (clean failure / re-auth), never crash. Governs error
  handling.
- **Reference data (sports catalog) is not per-sync churn** (B3). Sport names resolve at
  read time against `sport_ref`, which must be seeded; how often to refresh it is a registry
  policy. Governs catalog cadence.

---

## Strategic Approach

### Solution Direction

Introduce a **config-driven sync engine** that replaces `StubRefreshCoordinator` and sits
exactly between the existing layers: it consumes the Epic 2/3 **clients** (fetch) and the
Epic 4 **`StoreWriting`** facade (persist), and is driven by an Epic 5 **domain registry**
(what to fetch, with which window, at which priority, under which cap).

General data flow per refresh: `refresh() → registry sorted by priority → for each domain:
read lastSync → compute incremental window (or full first-sync window) + range-cap split →
fetch via client → upsert via StoreWriting → recordSync → collect outcome → continue on
failure → aggregate into SyncFreshness + per-domain results`. The activity domain follows
the per-day variant (loop the window, downsample+write each day). The first sync of each
domain pulls the full lookback (capturing existing history); every later sync pulls only
`[lastSync − overlap, now]` (HERC-054), so routine refreshes stay cheap while the
idempotent store absorbs the overlap. The engine is pure orchestration — it owns no
decoding, no SQL, no transport — so it is unit-testable with fake clients + an in-memory
store.

This honors the established conventions: the engine conforms to the existing
`RefreshCoordinating` protocol (so `DashboardModel` is unchanged in shape), reuses
`DateWindow` for formatting, and relies on the store's proven idempotency so re-syncs are
safe.

### Key Design Decisions

- **Engine placement (module boundary).** `HerculesUI` depends only on `PolarProtocol`, so
  the concrete engine — which needs *both* the clients (`PolarProtocol`) and `StoreWriting`
  (`PolarStore`) — cannot live in `HerculesUI`. Options: (a) put it in **`PolarStore`**
  (already bridges clients + the writer), (b) a **new `PolarSync` module** depending on
  both. → **Recommendation: place it in `PolarStore`** (e.g. a `Sync/` area), conforming to
  the `RefreshCoordinating` protocol from `PolarProtocol`, and inject it into
  `DashboardModel` at the app composition root. Avoids a fourth module while keeping
  `HerculesUI` store-free. A new module is the cleaner-conceptually alternative if sync
  grows large, noted below.

- **Registry representation: declarative descriptors with a sync action vs. an enum/protocol
  per domain.** Domains are heterogeneous (windowless / windowed / per-day), but the
  orchestrator wants them uniform. → **Recommendation: a descriptor carrying identity +
  priority + window policy + cap, plus a per-domain "sync action" that closes over the right
  client call and `upsert…`.** The orchestrator stays generic (sort, run, isolate, record);
  the registry holds the per-domain wiring. Keeps "change a window in one line" true while
  not forcing windowless/per-day domains into a windowed mold.

- **Incremental sync anchoring (HERC-054): on `lastSync` Date vs. stored `last_window`
  string.** A routine refresh should fetch only days changed since the last successful sync,
  not re-pull the whole window (the activity per-day loop is ~`lastDays` round-trips
  otherwise). Two anchors are possible: the stored `last_window` string (needs an unbuilt
  `lastSyncState` read and window-stitching) or the existing `lastSync(domain:) -> Date?`
  (the time the last sync ran). → **Recommendation: anchor on `lastSync` Date.** Effective
  window = `[lastSync − overlap, now]` when a prior sync exists, else the full lookback
  (first-sync backfill). It reuses an existing read (no schema/API addition), and a small
  overlap (≈2 days) re-pulls recent days so server-side corrections land — idempotent
  upserts make the overlap free. Windowless domains are unaffected (server-fixed set).

- **Execution: sequential by priority vs. concurrent.** → **Recommendation: sequential by
  priority.** It matches the AC's "by priority" wording, avoids API hammering and v4
  refresh-token races (the refresh-aware actor single-flights, but parallel first-calls
  still race), and makes partial-failure isolation and progress reporting trivial.
  Bounded concurrency is a later optimization, not a phase-1 need.

- **Per-domain failure surfacing.** The AC requires per-domain success/failure, but
  `DashboardModel` currently exposes only a single `lastRefreshFailed` Bool. → **Recommendation:
  the engine returns a richer result (aggregate freshness + per-domain outcomes) and the UI
  view-model is extended to hold per-domain status**, rather than persisting failure in
  `sync_state` (no error column today; pre-Epic-5 C2). In-memory per-refresh status meets
  the AC without a schema change.

- **Client provisioning from auth.** Transports read the token store dynamically
  (`V3Transport` per call; the v4 actor on refresh), so the clients can be **built once at
  the composition root** from the live token store and handed to the engine; they remain
  valid across token refreshes. → **Recommendation: compose clients at app start from the
  same auth/token store `AuthManager` uses**, and inject them — keeping the engine free of
  auth knowledge. Re-auth/sign-out simply causes the next fetch to fail cleanly.

### Alternatives Considered

- **A new `PolarSync` module.** Rejected for phase 1: adds a fourth target and build edges
  for orchestration that `PolarStore` can already host; revisit if the engine grows
  (background refresh, multiple triggers).
- **Incremental sync anchored on the stored `last_window` string.** Rejected: needs an
  unbuilt `lastSyncState` read plus window-stitching/parsing, for no benefit over anchoring
  on the `lastSync` Date (which an existing read already provides). The Date anchor is
  strictly simpler and sufficient.
- **Full-window pulls every refresh (no incremental).** Rejected (was the earlier phase-1
  plan): correct via idempotent upserts, but every refresh re-fetches the whole window — the
  activity per-day loop alone is ~`lastDays` round-trips each time, so refreshes never get
  cheaper. Incremental anchored on `lastSync` removes that cost for little added complexity.
- **One uniform windowed descriptor for every domain.** Rejected: would force windowless
  endpoints (sleep/recharge/cardio/sports/devices) to fabricate windows they ignore, and
  bury the genuinely different per-day activity path — hiding exactly the asymmetries that
  cause bugs.
- **Parallel domain fetches.** Rejected for phase 1: marginal latency gain on a manual
  refresh, at the cost of race/ordering/progress complexity and API politeness.

---

## Risk & Gap Analysis

### Requirement Ambiguities

- **Range-cap list vs. actual client shapes (HERC-053).** The AC names a "recharge 28 d"
  cap, but the implemented recharge/cardio/sleep clients are **windowless** — they take no
  `from`/`to`. So the engine can only clamp the genuinely windowed endpoints (continuous-HR
  30 d, activity/calendar 90 d, training sessions 90 d). Needs confirmation that windowless
  domains are intentionally server-bounded and out of HERC-053's scope.
- **Fetch window vs. display window.** HERC-050 lists both "fetch window" and "default
  display window." The display window is a read/UI concern (Epic 6); whether the registry
  should own it now, or only the fetch window, needs a call. Recommend the registry declares
  both but the engine consumes only the fetch window.
- **Per-domain status persistence.** "Surfaces per-domain success/failure" — transient
  (this refresh only) vs. persisted across launches. Resolved above as in-memory, but worth
  explicit confirmation (drives whether a `sync_state` error column / migration `v2` is
  needed — pre-Epic-5 C2).
- **Sports/device cadence.** Reference data need not sync every refresh, but there is no
  per-domain cadence concept. Whether the registry models "every sync" vs "occasionally"
  vs "once if empty" is open.
- **Sleep-manifest optimization (HERC-026).** §10 mentions optionally hitting
  `sleep/available` first. Whether Epic 5 wires this now or defers it (the sleep client is
  windowless anyway) is unspecified.

### Edge Cases

- **Not connected / expired credentials mid-refresh.** Refresh is reachable only when
  `state == .connected`, but a v3 bearer could be revoked or a v4 refresh could fail. Each
  must produce a clean per-domain failure (and, for v4, a re-auth signal), never a crash or
  a half-written domain.
- **Partial registry failure.** One domain throwing (network, decode, 400) must not stop the
  rest; the refresh still reports the domains that succeeded and a fresh timestamp for them.
- **Activity per-day loop, one bad day.** A single day's samples failing must not abort the
  whole activity window nor the other domains; the loop continues and reports.
- **Oversized window paging + overlap.** Splitting a >cap window into sub-requests creates
  overlapping/adjacent windows; the store's idempotent upserts must absorb the overlap
  (they do) — but the splitter must not drop or duplicate boundary days.
- **Empty domains.** Many endpoints legitimately return empty (no nights, no workouts); the
  engine must treat empty as success (no-op upsert) and still `recordSync`.
- **Timezone of window boundaries vs. storage keys.** `DateWindow` formats params in
  `.current` timezone, while minute rows are keyed by **UTC** day (`PolarDayKey`). These are
  distinct concerns (request window vs. storage partition), but the fetch-window day
  boundaries should be derived consistently so "last N days" is stable and dedup holds.
- **Refresh re-entrancy / overlap.** `DashboardModel` guards re-entrancy, but a long refresh
  + sign-out, or app backgrounding mid-refresh, should leave the store consistent (per-domain
  transactions already give this) and not write under a torn-down auth.
- **Incremental anchor on a failed domain (HERC-054).** `recordSync` runs only on full-domain
  success, so a domain that failed keeps its prior `lastSync`; the next refresh correctly
  re-pulls from the last *successful* point (no silent gap). A domain that has never synced
  reads `nil` and gets the full first-sync window.
- **Clock skew vs. `lastSync` anchor.** If the device clock moves backward, an incremental
  window could under-reach. The ≈2-day overlap absorbs small skew; gross skew is out of scope
  for a single-user phone app. The first-sync full lookback is unaffected (it ignores
  `lastSync`).

### Technical Risks

- **Orchestration correctness across heterogeneous domain shapes.** The biggest design risk:
  uniformly running windowless / windowed / per-day domains while keeping per-domain
  isolation and config-driven windows. Mitigation: the descriptor + sync-action shape above;
  cover each shape with a fake-client engine test.
- **Memory on the activity path (HERC-052).** A 30-day activity sync must not materialize all
  days at once. Mitigation: strictly sequential per-day fetch→downsample(already client)→
  upsert→release; assert bounded behavior with a multi-day test.
- **Range-cap paging bugs (HERC-053).** Off-by-one at chunk boundaries → dropped/duplicated
  days or a lingering 400. Mitigation: a pure, unit-tested window-splitter independent of the
  network; rely on idempotent upserts for overlap safety.
- **Engine placement / boundary leak.** Putting the engine where it pulls `PolarStore` into
  `HerculesUI` would break the module boundary. Mitigation: engine in `PolarStore`, injected
  via the `RefreshCoordinating` protocol at the composition root.
- **Token lifecycle under a long-lived engine.** Clients built once must keep reading current
  tokens. Mitigation: confirmed `V3Transport` reads the store per call; verify the v4 actor
  reads current tokens on refresh; build clients over the same token store, not a snapshot.
- **Per-domain status plumbing to the UI.** Meeting the "surfaces per-domain success/failure"
  AC requires extending the view-model beyond a single Bool. Mitigation: richer engine return
  type + a small `DashboardModel` addition; no schema change.

### Acceptance Criteria Coverage

| AC# | Description | Addressable? | Gaps/Notes |
|-----|-------------|--------------|------------|
| HERC-050 | Changing a fetch window is a one-line edit; sync reads windows from config | Yes | Declarative registry of per-domain descriptors. Clarify fetch-vs-display window ownership. |
| HERC-051 | One tap refreshes everything; partial failure doesn't abort the rest | **Partial** | Orchestration + `recordSync` + isolation are addressable. "Surfaces per-domain success/failure" needs a richer engine return + a `DashboardModel` addition (today only one Bool). |
| HERC-052 | 30-day activity sync completes without unbounded memory; each day downsampled before next | Yes | Downsampling already client-side; engine sequences per-day fetch→write→release. Combine daily totals + per-day zones into `upsertActivity(day:zones:)`. |
| HERC-053 | Requesting >cap auto-splits into valid sub-requests; no 400s from oversized ranges | **Partial** | Applies to the **windowed** endpoints only (continuous-HR 30 d, activity/sessions 90 d). The "recharge 28 d" cap is moot — that client is windowless. Confirm scope. |
| HERC-054 | A refresh shortly after a previous one fetches only the new/changed days, not the whole window; data identical to a full re-pull | Yes | Now **in scope** (promoted from deferred). Anchored on the existing `lastSync(domain:)` Date: window = `[lastSync − overlap, now]`, else full first-sync lookback. No schema/API addition; engine also needs `StoreReading` (for `lastSync`). Windowless domains unaffected. |

**Overall:** All five Epic 5 ACs are addressable by a config-driven engine that composes the
existing clients with the Epic 4 store. HERC-050/052/054 are fully scoped; HERC-051 is partial
only in its UI-surfacing tail (a small view-model extension), and HERC-053 is partial only
because the range-cap list over-reaches the windowed endpoints. The chief watch-items are:
engine placement in `PolarStore` (not `HerculesUI`), uniform handling of the three domain
call-shapes with per-domain failure isolation, a unit-tested range splitter, incremental
windowing anchored on `lastSync` (full first-sync backfill, small overlap thereafter), and a strictly
sequential per-day activity loop for bounded memory.
