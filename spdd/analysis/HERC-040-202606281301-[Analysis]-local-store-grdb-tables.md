# SPDD Analysis: Local Store (GRDB) Tables — Epic 4

## Original Business Requirement

> based on the analysis and the api responses, we need to work on the tables for epic 4

**Resolved scope (from `BACKLOG.md` EPIC 4 — Local store (GRDB) `[infra]`).** The
request points at two grounding artifacts that already exist in the repo and were
produced by the prior phases of this work:

1. **The analysis** — `spdd/analysis/HERC-020-...-accesslink-v3-v4-clients.md`, which
   built the decode-only typed clients/models for Epic 2 (v3) and Epic 3 (v4) and
   explicitly named `PolarStore` as the out-of-scope boundary where "Epic 4/5 will
   persist what these clients decode."
2. **The API responses** — `API_RESPONSE_SHAPES.md`, the field-by-field map from each
   live-verified Polar response (11/11 decode against captures, 2026-06-28) to its
   **target GRDB table and columns**.

This requirement is therefore the next step in that chain: turn the now-verified wire
models into a persisted local store. The formal backlog scope is:

**EPIC 4 — Local store (GRDB) `[infra]`**

- **HERC-040 · Schema + migrations** · P0 — Define tables (see ARCHITECTURE §9):
  `hr_minute`, `activity_minute`, `sleep_night`, `recharge`, `cardio_load`,
  `training_session`, `sport_ref`, `device`, `sync_state`. Set up GRDB migrations.
  _AC: fresh install creates all tables; a no-op migration run is idempotent._
- **HERC-041 · Upsert helpers + dedup** · P1 — Generic upsert keyed on date
  (samples/day rows) or session id. Re-syncing an overlapping window must not
  duplicate. _AC: syncing the same window twice yields identical row counts._
- **HERC-042 · Read APIs for the UI** · P1 — Query functions returning display-ready
  ranges (e.g. HR for an arbitrary day window) entirely from the DB.
  _AC: card queries return in <16 ms on a populated DB; zero network in the read path._

> **Note on the `activity_day` table.** `BACKLOG.md` HERC-040 lists nine tables and
> omits `activity_day`, but both `ARCHITECTURE.md` §9 and `API_RESPONSE_SHAPES.md` §6
> require it (it is the home of the v3 computed daily totals + `zones_json`). This is
> treated as a documentation slip in the backlog, **not** a scope cut — `activity_day`
> is in scope. Surfaced explicitly below rather than silently assumed.

---

## Domain Concept Identification

### Existing Concepts (from codebase)

- **`PolarDatabase`** (`Packages/Sources/PolarStore/PolarDatabase.swift`): the GRDB
  store. Today it opens a `DatabasePool` (on-disk) or `DatabaseQueue` (in-memory) and
  runs an **empty `DatabaseMigrator`** with `eraseDatabaseOnSchemaChange` under DEBUG.
  This is the single seam Epic 4 fills: the migrator gains real migrations, and the
  type gains (or gateways to) upsert + read APIs. It is the only existing `PolarStore`
  code.
- **Decode-only wire models in `PolarProtocol`** — the output of the Epic 2/3
  analysis, now the *input* to Epic 4: `SleepNight`, `SleepAvailability`,
  `NightlyRecharge`, `CardioLoad` (+`CardioLoadLevel`, `CardioLoadStatus`),
  `ActivityDay`, `ActivitySamples` (+`StepMinute`, `RawStepSample`,
  `ActivityZoneSample`, `ActivityZoneKind`, `InactivityStamp`), `HeartRateMinute`
  (+`HeartRateSample`), `TrainingSession` (+`Exercise`, `StartTrigger`), `Sport`,
  `Device`. These are pure `Decodable`/`Sendable` structs with **no GRDB conformance**.
- **`Downsampler` + minute types** (`PolarProtocol/Networking/Downsampler.swift`):
  already produces `HeartRateMinute` and `StepMinute` per-minute rows from raw arrays.
  Epic 4 persists these minute rows — it does **not** re-implement bucketing. The
  "raw never persisted" guarantee is already enforced upstream; Epic 4 inherits it.
- **`API_RESPONSE_SHAPES.md`**: the authoritative model→table→column map. Every table's
  column set, primary key, JSON-vs-normalized decision, and stringified/signed quirks
  are already resolved here against live captures. This is the spec Epic 4 implements;
  it should not be re-derived.
- **`ARCHITECTURE.md` §9 / §10**: the indicative table list and the sync-engine
  contract (upsert/dedup keyed on date or session id; manual-refresh `sync_state`).
- **Package boundary (`Package.swift`)**: `PolarStore` depends on `PolarProtocol` +
  `GRDB`; `PolarProtocol` deliberately has **no DB dependency** ("API models + clients,
  no UI, no DB"). This boundary directly shapes where record types live (see Strategic
  Approach).

### New Concepts Required

- **Persistence record types** — GRDB-conforming representations
  (`FetchableRecord`/`PersistableRecord`, typically `Codable`) for each table:
  `HRMinuteRecord`, `ActivityMinuteRecord`, `ActivityDayRecord`, `SleepNightRecord`,
  `RechargeRecord`, `CardioLoadRecord`, `TrainingSessionRecord`, `SportRefRecord`,
  `DeviceRecord`, `SyncStateRecord` (names indicative). Each maps **from** a
  `PolarProtocol` wire model into stored columns, flattening time-keyed maps and nested
  objects into `*_json` text columns per the shapes map. Relates to every wire model
  (source) and to the migrations (schema) and read APIs (consumer).
- **The schema itself (migration `v1`)** — the concrete `CREATE TABLE` set for the ten
  tables, with primary keys and the JSON columns from §9. New; replaces the empty
  migrator.
- **Upsert / dedup helpers** — idempotent write operations keyed on each table's
  natural key (`date`, composite `(date, minute_ts)`, or `id`/`uuid`), so an
  overlapping re-sync converges to the same row count. Relates to HERC-041 and the
  Epic 5 sync engine that will call them.
- **Read / query APIs** — display-ready fetches over date windows and ids, returning
  either the records or lightweight read-models, entirely from SQLite. Relates to
  HERC-042 and the Epic 6 dashboard cards that consume them.
- **`sync_state` as a domain row** — `(domain, last_synced_at, last_window)`; a new
  first-class concept that did not exist as a wire model (it is store-internal
  bookkeeping for the Epic 5 sync engine and the dashboard's freshness display).
- **JSON column encoding convention** — a single, consistent way to serialize the
  `"HH:MM"`-keyed maps (hypnogram, HR samples, HRV, breathing), the per-minute zone
  label series, the cardio level object, and the exercises/macros array into TEXT
  columns. New and cross-cutting.

### Key Business Rules

- **Idempotent re-sync (the core invariant).** Writing the same window twice must yield
  identical row counts and identical row contents — every table write is an upsert on
  its natural key, never a blind insert. Governs every record type and HERC-041.
- **Natural keys are date-derived or id-derived, never surrogate.** `sleep_night`,
  `recharge`, `cardio_load`, `activity_day` keyed on `date`; `hr_minute` /
  `activity_minute` on composite `(date, minute_ts)`; `training_session` on
  `id` (`identifier.id` uuid); `sport_ref` on `id` (`id.id` int); `device` on `uuid`.
  Governs schema PK choices and dedup.
- **Raw high-frequency samples never persist at native resolution.** Only minute-bucket
  rows enter `hr_minute` / `activity_minute`. Already guaranteed by `Downsampler`
  upstream; the store must not add a raw-sample table. Governs §9 fidelity.
- **Time-keyed maps and nested objects are stored as JSON text, not normalized rows.**
  Per §9 / shapes map: hypnogram, HR samples, HRV/breathing maps, zone-label series,
  cardio level, and exercise macros are `*_json` columns. Governs record encoding.
- **Stringified / signed-fractional wire quirks are normalized at the store boundary.**
  `sport.id` ("15") and `recoveryTimeMillis` ("32060568") arrive as strings → stored
  as INT; `ans_charge` is signed REAL (e.g. `-1.5`). Conversion happens once, when
  mapping wire model → record. Governs `training_session` and `recharge` records.
- **Battery is intentionally absent** from `device` — there is no battery column in
  phase 1; its absence is a documented condition, not missing data. Governs the device
  schema.
- **The read path touches zero network and is fast.** All HERC-042 queries resolve from
  SQLite only, targeting <16 ms on a populated DB. Governs read-API design and
  indexing.
- **`PolarProtocol` stays DB-free.** No GRDB types may leak into the wire-model package;
  the conformance/mapping lives entirely in `PolarStore`. Governs where record types are
  authored.

---

## Strategic Approach

### Solution Direction

Fill the existing `PolarStore` seam in three concentric layers, all inside the
`PolarStore` target (which already depends on `PolarProtocol` + `GRDB`):

1. **Schema (HERC-040):** replace the empty migrator with a single `v1` migration that
   creates the ten tables exactly per `API_RESPONSE_SHAPES.md` columns and
   `ARCHITECTURE.md` §9 — date/id/composite primary keys, REAL/INT/TEXT typing
   (including the signed `ans_charge` REAL), and the `*_json` TEXT columns for
   time-keyed maps and nested objects.
2. **Records + upsert (HERC-040/041):** one GRDB record type per table that conforms to
   `FetchableRecord` + `PersistableRecord` and maps **from** the corresponding
   `PolarProtocol` wire model — flattening maps/objects to JSON, normalizing the
   stringified/signed quirks. Writes go through a generic upsert keyed on the natural
   key so overlapping windows converge (idempotent).
3. **Read APIs (HERC-042):** query functions over date windows / ids that return
   display-ready data purely from SQLite, fast enough for the dashboard cards.

General data flow: `wire model (PolarProtocol) → map to record (PolarStore) → upsert
into SQLite`, and on read `date window / id → SQLite query → read-model → UI`. This
slots cleanly between the completed Epic 2/3 (which produces the wire models) and the
future Epic 5 sync engine (which orchestrates *when* to call the upserts) and Epic 6 UI
(which calls the reads). It honors the user's own framing from the prior analysis:
storage is the layer *after* the decode-only clients.

### Key Design Decisions

- **Where record types live: `PolarStore` (mapping from wire models) vs. adding GRDB
  conformance to the `PolarProtocol` models.** Trade-off: conforming the existing wire
  structs to GRDB in place is less code but **breaks the documented package boundary**
  ("PolarProtocol — no DB") and couples the API layer to a storage library; defining
  separate record types in `PolarStore` costs one mapping layer but preserves the
  boundary and lets storage shape (flattened JSON columns, normalized ints) diverge
  from wire shape (nested objects, stringified fields). → **Recommendation: separate
  record types in `PolarStore`** that initialize from the wire models. The mapping is
  exactly where the stringified/signed/JSON normalizations belong, and it keeps
  `PolarProtocol` DB-free.

- **JSON columns vs. normalized child tables for the time-keyed maps and arrays.** §9
  and the shapes map already decide this (store as JSON), and the rationale holds:
  hypnogram / HR-sample / HRV / breathing maps and the zone-label series are read as
  whole blobs by a single card, never queried field-wise. Trade-off: JSON loses
  per-key SQL query ability but matches every read pattern and avoids an explosion of
  sample rows. → **Recommendation: `*_json` TEXT columns** for all time-keyed maps,
  the cardio level object, the per-minute zone series, and the exercises/macros array —
  as already specified. Normalized rows are reserved for the genuinely tabular
  minute-series (`hr_minute`, `activity_minute`).

- **Upsert mechanism: GRDB `save`/`upsert` on a single-column PK vs. a generic helper
  spanning the mixed key shapes.** Tables have three key shapes (single `date`/`id`,
  composite `(date, minute_ts)`, single `uuid`/int id). Trade-off: relying on GRDB's
  built-in conflict handling per record is simplest but the AC asks for a *generic*
  upsert/dedup story (HERC-041); a thin generic wrapper over `PersistableRecord`
  centralizes the "insert-or-replace on natural key" semantics and the
  re-sync-yields-identical-counts guarantee in one testable place. → **Recommendation:
  lean on GRDB's primary-key conflict resolution** (declare the natural key as the
  table PK so `save`/`upsert` is inherently idempotent) **and expose a small generic
  upsert facade** for the sync engine, rather than hand-rolling dedup logic. The
  composite-key minute tables get a two-column PK so the same mechanism applies.

- **Batch minute-row writes inside a single transaction vs. per-row.** A multi-day HR
  pull is ~1k minute rows; activity similar. Trade-off: per-row writes are simplest but
  slow and non-atomic across a day; a single `write {}` transaction per domain/day is
  fast and gives all-or-nothing semantics that pair well with the idempotent re-sync
  rule. → **Recommendation: batch each domain's write in one GRDB transaction**, which
  also makes the "identical row counts on re-sync" assertion clean to verify.

- **Read-API return shape: raw records vs. dedicated read-models.** Trade-off:
  returning records leaks storage shape (JSON strings) into the UI and forces the cards
  to re-parse; returning decoded read-models (maps re-hydrated, ints typed) gives the UI
  display-ready data but adds small projection types. → **Recommendation: return
  display-ready read-models** for the map/JSON-bearing tables (sleep, recharge, cardio,
  activity-day, training) and plain records/rows for the simple minute series. Keeps the
  Epic 6 cards thin and the <16 ms target achievable. (Exact projection types are a
  REASONS Canvas concern.)

### Alternatives Considered

- **Conform the existing `PolarProtocol` wire models directly to GRDB.** Rejected:
  violates the explicit "PolarProtocol — no DB" boundary in `Package.swift`/§2, couples
  the API layer to GRDB, and forces wire shape (nested objects, stringified ids) to
  double as storage shape.
- **Normalize the time-keyed maps into child sample tables** (e.g. a `sleep_hr_sample`
  table). Rejected: contradicts §9 and the shapes map, multiplies row counts for data
  that is always read as a whole blob by one card, and buys SQL queryability no screen
  needs.
- **Persist raw 5-sec HR / raw step samples and downsample at read time.** Rejected:
  violates the "raw never persisted / bounded memory" rule already enforced by
  `Downsampler`; the store's contract is minute rows only.
- **Defer `sync_state` to Epic 5.** Rejected: §9 lists it as part of the store schema
  and HERC-040 enumerates it; the table belongs to the schema migration now even though
  its *writers* (sync engine) and *readers* (freshness UI) arrive later.

---

## Risk & Gap Analysis

### Requirement Ambiguities

- **`activity_day` omission in HERC-040's table list.** The backlog story names nine
  tables but not `activity_day`, which §9 and the shapes map require. Resolved above as
  a doc slip — `activity_day` is in scope — but flagged so REASONS Canvas treats ten
  tables, not nine.
- **`date` representation across tables.** The wire models carry `date` as a `String`
  (`SleepNight.date`) in some cases and as a derived value (`ActivityDay` has **no**
  `date` — it is derived from `start_time`) in others. Whether stored `date` columns
  are TEXT (`YYYY-MM-DD`) or normalized to another form, and how the activity date is
  derived and on which timezone boundary, needs an explicit decision (impacts dedup
  correctness — see edge cases).
- **`minute_ts` storage form.** `HeartRateMinute.minute` / `StepMinute.minute` are
  `Date` floored to the UTC minute. Whether `minute_ts` is stored as epoch seconds,
  ISO text, or `"HH:MM"`-within-day affects composite-PK comparison and read-window
  queries. Must be pinned.
- **"Generic upsert" scope (HERC-041).** How generic — a protocol-level facade over all
  records, or per-table upserts that happen to share a pattern? The AC only requires
  idempotent re-sync; the degree of abstraction is open.
- **Read-API surface granularity (HERC-042).** "Display-ready ranges" is illustrated
  only by "HR for a day window." The full set of card queries (which windows, which
  tables, what projection) is under-specified here and should be enumerated against the
  Epic 6 cards in REASONS Canvas.

### Edge Cases

- **Timezone of the day boundary for date-keyed dedup.** If two syncs derive a night's
  or day's `date` on different timezone assumptions, the natural key shifts and dedup
  silently fails (duplicate rows under two dates). The "identical row counts on re-sync"
  AC depends on a single, stable date-derivation rule (esp. for `activity_day`, whose
  date comes from `start_time`).
- **Partial / empty domains.** Sleep, activity, etc. legitimately return no data for a
  date (the manifest exists for this). The store must accept an empty write set as a
  no-op success, and read APIs must return empty (not error) for windows with no rows.
- **Overlapping-window re-sync with changed values.** Re-fetching a day whose computed
  totals changed server-side must **update in place** (upsert), not insert a second row
  nor keep the stale one — row count identical, content refreshed.
- **Composite-key collisions across days.** `minute_ts` alone is not unique across days;
  the PK must be `(date, minute_ts)` or an absolute timestamp, or minutes from
  different days with the same clock time collide.
- **JSON encode/decode round-trip fidelity.** The `"HH:MM"`-keyed maps and the macros
  array must survive store→read intact (ordering of a `"HH:MM"` map is not guaranteed by
  JSON object semantics — the UI must sort, not rely on stored order).
- **`sport_ref` referential integrity.** `training_session.sport_id` resolves against
  `sport_ref`, but the catalog is fetched separately (HERC-033, P2) and may be absent or
  stale when a session is written. A session must persist even if its sport id is not
  yet in `sport_ref` (no hard FK that blocks the write); resolution is a read-time join.
- **`eraseDatabaseOnSchemaChange` under DEBUG.** Convenient in dev but means a schema
  tweak wipes local data; fine for phase 1 but worth a deliberate note before any real
  user data exists (and it must be off for release builds).

### Technical Risks

- **Dedup correctness hinges on key + date-derivation discipline.** The single most
  important risk: any inconsistency in how a row's natural key is computed across syncs
  breaks the core idempotency invariant. Mitigation: derive keys once in the wire→record
  mapping, store date/minute in a single canonical form, and assert "sync twice → equal
  counts and equal rows" as a test (directly the HERC-041 AC).
- **Read latency at scale (<16 ms target).** A populated DB holds ~weeks of minute rows
  (hr_minute, activity_minute) — thousands of rows per domain. Without an index on the
  date / `(date, minute_ts)` key, a day-window scan degrades. Mitigation: PK on the
  composite key (GRDB indexes the PK) and window queries that range over it; verify the
  <16 ms AC on a realistically populated DB.
- **JSON column bloat / encoding cost.** Hypnogram + HR-sample + HRV + breathing maps per
  night, zone series per day — non-trivial TEXT. Mitigation: store as compact JSON; these
  are read whole, so size is acceptable, but avoid re-encoding on every read.
- **Wire-quirk normalization drift.** If the stringified `sport.id` / `recoveryTimeMillis`
  or signed `ans_charge` are normalized inconsistently between the wire model and the
  record, stored values silently corrupt. Mitigation: normalize exactly once, at the
  wire→record boundary, with the shapes map as the checklist; unit-test each conversion.
- **Migration idempotency / forward-compat.** HERC-040 AC requires a no-op migration run
  to be idempotent and a fresh install to build all tables. Mitigation: a single
  registered `v1` migration; rely on GRDB's migration tracking; test fresh-create and
  re-run.
- **Boundary leakage of GRDB into `PolarProtocol`.** A careless import would couple the
  API package to the DB. Mitigation: keep all record/conformance code in `PolarStore`;
  the wire models stay untouched.

### Acceptance Criteria Coverage

| AC# | Description | Addressable? | Gaps/Notes |
|-----|-------------|--------------|------------|
| HERC-040 | Fresh install creates all tables; no-op migration run is idempotent | Yes | Single `v1` migration over **ten** tables (incl. `activity_day`, corrected from the 9 listed). PK/JSON columns per `API_RESPONSE_SHAPES.md`. `sync_state` included now. |
| HERC-041 | Re-syncing an overlapping window yields identical row counts | Yes | Hinges on natural-key + stable date-derivation discipline; verify via "sync twice → equal counts/rows" test. Composite `(date, minute_ts)` PK for minute tables. |
| HERC-042 | Card queries return <16 ms on a populated DB; zero network in read path | Partial | Read APIs fully in scope; the **exact query set** is under-specified (only "HR for a day window" is illustrated) — enumerate against Epic 6 cards in REASONS Canvas. <16 ms depends on PK indexing; verify on a realistically populated DB. |

**Overall:** All three Epic 4 ACs are addressable within `PolarStore`, building directly
on the verified shapes map. HERC-040 and HERC-041 are fully scoped here; HERC-042 is
addressable but its concrete query surface should be enumerated during REASONS Canvas
against the Epic 6 dashboard cards. The chief watch-items are the corrected ten-table
set (don't drop `activity_day`), a single canonical date/key-derivation rule (the dedup
invariant), and keeping GRDB out of `PolarProtocol`.
