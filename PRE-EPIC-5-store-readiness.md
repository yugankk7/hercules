# Pre-Epic-5 — Store Readiness Checklist

> **Purpose.** Epic 4 (HERC-040/041/042) delivered the GRDB local store: the ten
> tables, idempotent upserts, and read APIs in the `PolarStore` target. Before
> Epic 5 (the sync engine — HERC-050/051/052/053) can populate those tables on
> pull-to-refresh, a handful of store-side items must be wired or respected. This
> file is the actionable handoff for whoever (or whichever Claude session) picks
> up the next slice.
>
> **Scope.** Store/SQLite layer only. The sync orchestration, domain registry, and
> range-cap logic are Epic 5 proper and belong in their own SPDD analysis/prompt.
>
> **Status legend:** `[ ]` to do · `[~]` optional / decide · `[x]` already handled.

---

## A. Must-do wiring (nothing writes until these exist)

- [x] **A1 — Create one real on-disk `PolarDatabase` at launch and share it.**
  - **Done (2026-06-28).** `HerculesApp` now opens one `PolarDatabase` via
    `PolarDatabase.onDisk()` in `init` and holds it as `store`. The discarded
    in-memory `selfTest()` is gone. Injection into the Epic 5 coordinator / Epic 6
    provider is a one-line pass of `store` once those types exist.
  - Today the app only runs `PolarDatabase.selfTest()` (in-memory, discarded) in
    [`App/HerculesApp.swift`](../App/HerculesApp.swift). There is **no persistent DB**.
  - Create a single `PolarDatabase(path:)` instance at app start and inject it into
    **both** the sync engine (writes) and the dashboard provider (reads). One
    instance, one file — never open two `DatabasePool`s on the same path.
  - **Done when:** the app holds one shared `PolarDatabase`; both the (future)
    coordinator and provider receive it.

- [x] **A2 — Put the DB file in Application Support, not Documents/tmp.**
  - **Done (2026-06-28).** `PolarDatabase.onDisk()` (in `PolarDatabase+Disk.swift`)
    resolves `Application Support/hercules.sqlite`, creating the directory.
  - Path: `Application Support/hercules.sqlite` (create the directory if missing).
  - **Not** `Documents` (user-visible / iCloud-backed) and **not** `tmp`/`Caches`
    (purgeable — iOS may delete it).
  - `init(path:)` already uses `DatabasePool` (WAL) — correct for concurrent UI
    reads during a sync write. No change needed there, just pass the right URL.
  - **Done when:** a fresh launch creates the file under Application Support and it
    survives app restarts (in Release; see E1 for DEBUG behaviour).

- [x] **A3 — Depend on the protocols, not the concrete DB.**
  - **Already held.** `StoreWriting` / `StoreReading` exist; the only concrete
    `PolarDatabase` reference is the composition root (`HerculesApp`).
  - The sync engine takes `StoreWriting`; the dashboard provider takes
    `StoreReading` (both in
    [`Packages/Sources/PolarStore/Store/StoreProtocols.swift`](../Packages/Sources/PolarStore/Store/StoreProtocols.swift)).
  - This keeps Epic 5 unit-testable against an in-memory DB or a fake.
  - **Done when:** no Epic 5 type references the concrete `PolarDatabase` directly
    except at the composition root (the app entry point).

---

## B. Correctness pitfalls to respect (these fail silently)

- [x] **B1 — Pass a *deterministic* `date` for the minute tables.**
  - **Done (2026-06-28).** Resolved by *removing the footgun*: the two minute
    upserts no longer take a batch `date:` param. `HRMinuteRecord` /
    `ActivityMinuteRecord` now derive `date` from each minute's own UTC day via the
    shared `PolarDayKey.utcDay(of:)` helper, so `(date, minute_ts)` is a pure
    function of the minute and a midnight-straddling re-sync can't create twins.
    New test `testMinuteDateDerivedFromUTCDayDedupsAcrossMidnight` covers it.
    Epic 5 just calls `upsertHeartRateMinutes(minutes)` — no date to get wrong.

- [ ] **B2 — Re-fetch overlapping windows freely; don't reinvent dedup.**
  - Every `upsert…` is idempotent on its natural key (proven in
    [`PolarStoreTests.swift`](../Packages/Tests/PolarStoreTests/PolarStoreTests.swift)).
    Epic 5 can safely always re-pull, e.g., the last 2 days each refresh without
    duplicates. Do **not** add a separate "have I seen this?" layer.

- [ ] **B3 — Seed `sport_ref` or workout names render blank.**
  - `trainingSessions(in:)` resolves sport names via a read-time lookup against
    `sport_ref` (no hard FK, by design). Sessions persist without it, but names are
    `nil` until the catalog is synced. The Epic 5 domain registry (HERC-050) should
    sync the sports catalog (HERC-033) at least once, early/occasionally.

- [ ] **B4 — Expect partial visibility mid-sync (intended).**
  - Each `upsert…` runs in its own transaction, so a half-finished refresh shows
    some domains updated and others not. This is correct and matches HERC-051's
    "one domain failing doesn't abort the rest." Do not wrap the whole refresh in a
    single transaction.

---

## C. Small store additions Epic 5 will likely want

- [~] **C1 — A read that returns the last *window*, not just the timestamp.**
  - `lastSync(domain:)` returns only `Date`. `sync_state` stores `last_window`, but
    nothing reads it back. If Epic 5 does incremental fetches ("fetch since last
    window"), add `lastSyncState(domain:) -> SyncStateRecord?` (or a small read-model)
    to `StoreReading`. Small, additive — only if incremental sync is in scope.

- [~] **C2 — Decide whether per-domain *failure* state must persist.**
  - `sync_state` has no error column. If HERC-051's per-domain success/failure only
    needs to live for the current refresh → return it in-memory from the coordinator,
    **no schema change**. If failures must survive an app restart → that's a **new
    migration `v2`** adding a column. Decide before writing the coordinator.

- [ ] **C3 — Any schema change is a NEW migration, never an edit to `v1`.**
  - Add `migrator.registerMigration("v2") { … }` in
    [`PolarDatabase.swift`](../Packages/Sources/PolarStore/PolarDatabase.swift).
    Editing `v1` in place would corrupt existing installs. The migrator is already
    structured for additive versions.

---

## D. Already handled — do NOT rebuild

- [x] **Read speed** — day-window HR read measured **~1.4 ms** on 43k rows after the
  `minute_ts` secondary index (`idx_hr_minute_ts` / `idx_activity_minute_ts`). Well
  under the 16 ms frame budget. See `ReadPerformanceTests`.
- [x] **Idempotent upserts** across all three key shapes (composite `(date,minute_ts)`,
  string `date`/`id`, int `id`) — tested.
- [x] **Memory-safe per-day pattern for HERC-052** — call `upsertActivity(day:zones:)`
  + `upsertActivityMinutes(date:_:)` per day inside the loop; each is its own
  transaction, so each day writes and releases before the next fetch. No store change
  needed to support this.
- [x] **`recordSync(domain:window:)`** exists for HERC-051 to call after each domain.
- [x] **Concurrency** — `DatabasePool` + WAL gives consistent read snapshots during a
  sync write; UI reads never block the writer.
- [x] **Empty input is a no-op success; reads return empty/`nil`** for absent data —
  tested. Epic 5 can call upserts with empty results without special-casing.

---

## E. Dev hygiene

- [ ] **E1 — Know that `eraseDatabaseOnSchemaChange` is ON in DEBUG.**
  - In [`PolarDatabase.swift`](../Packages/Sources/PolarStore/PolarDatabase.swift),
    guarded to `#if DEBUG`. While building Epic 5, any schema tweak wipes local data —
    expected. "I synced yesterday and the data's gone" is usually a schema change, not
    a bug. Correctly off in Release.

- [ ] **E2 — Test Epic 5 against `PolarDatabase(inMemory:)`** with a fake `V3DataClient`
  / `V4DataClient`, same as the existing store tests — fast, no simulator file needed.

- [~] **E3 — Optional: a debug row-count dump** at the end of a sync (`COUNT(*)` per
  table → console) makes bring-up verification trivial. Pairs with the manual
  `sqlite3` inspection of the on-disk file:
  ```bash
  DIR=$(xcrun simctl get_app_container booted dev.hercules.app data)
  find "$DIR" -name "*.sqlite"
  sqlite3 "<path>" "SELECT 'hr_minute', COUNT(*) FROM hr_minute
                    UNION ALL SELECT 'sleep_night', COUNT(*) FROM sleep_night;"  # etc.
  ```

---

## Suggested order

1. **A1–A3** (DB wiring + injection) — unblocks everything; do first.
2. **B1** (deterministic date helper) — correctness foundation before any minute writes.
3. **C2** decision, then **C1/C3** as the registry/incremental design firms up.
4. **B3** sport-catalog seeding when wiring the domain registry (HERC-050).
5. Verify with **E2/E3** + the `sqlite3` recipe.

Items A and B1 are squarely in the Epic 4 store layer and can land now as
"store-ready-for-Epic-5" groundwork; the rest naturally fold into the Epic 5 SPDD
analysis/prompt.
