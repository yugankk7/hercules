# SPDD Analysis: AccessLink v3 + v4 Data Clients (Epic 2 & Epic 3, combined)

## Original Business Requirement

> for epic 2 and epic 3, im assuming we will be fetching everything all at once in epic 4 and then store in local db in epic 5
>
> for now lets do epic 2 and 3 together

**Formal scope (from `BACKLOG.md`).** This requirement combines two epics, intentionally tackled together because they share the same shape (typed HTTP clients + decodable models over the already-built auth transports) and differ only by realm.

**EPIC 2 — AccessLink v3 client `[v3]`** (date format for all v3: `YYYY-MM-DD`):

- **HERC-020 · Sleep fetch + model** · P1 — `GET /v3/users/sleep` → decode `nights[]` (hypnogram, stage totals, `heart_rate_samples`, `sleep_score`, continuity, cycles, charge). _AC: typed models decode a live response; ~25 nights parsed._
- **HERC-021 · Nightly recharge fetch + model** · P1 — `GET /v3/users/nightly-recharge` → `recharges[]` (ans_charge, statuses, HR/HRV/breathing averages + 5-min sample arrays). _AC: models decode live data; sample arrays intact._
- **HERC-022 · Cardio load fetch + model** · P1 — `GET /v3/users/cardio-load` → strain/tolerance/ratio/status, 28 days. _AC: 28-day series decodes; status string mapped to an enum._
- **HERC-023 · Continuous HR fetch + downsample** · P1 — `GET /v3/users/continuous-heart-rate?from=&to=` (~5-sec samples, ≈16 MB/28 d). Bucket to **per-minute min/avg/max** on ingest. _AC: a multi-day pull never persists raw 5-sec rows; minute rows written; peak memory bounded._
- **HERC-024 · Daily activity summary fetch** · P1 — `GET /v3/users/activities/{date}` (and `/activities?from=&to=` for ranges). Decode computed totals: `steps`, `calories`, `active_calories`, `active_duration`/`inactive_duration`, `daily_activity`, `inactivity_alert_count`, `distance_from_steps`. **No derivation needed — v3 returns totals directly.** _AC: a 7-day range decodes with all tiles populated; history confirmed (not transactional)._
- **HERC-025 · Daily activity samples + zones fetch** · P1 — `GET /v3/users/activities/samples/{date}`. Decode per-minute `steps` (`interval_ms`, `total_steps`, `samples[]`), **`activity_zones`** (the intensity-zone bar), `inactivity_stamps`. Downsample steps on ingest. _AC: step graph + zone bar reproducible from the response; no MET math required._
- **HERC-026 · Sleep manifest (optional sync optimization)** · P2 — `GET /v3/users/sleep/available` → `available[]` (dates with data). Use to fetch only existing nights. _AC: sync queries the manifest first and skips empty nights._

**EPIC 3 — AccessLink v4 client (narrow supplement) `[v4]`** (v4 is used for **only three things** — workout history, devices, sport names; `training-sessions/list` uses **naive datetime** `YYYY-MM-DDTHH:MM:SS`; the other two take no dates):

- **HERC-032 · Training sessions fetch** · P1 — `GET /training-sessions/list?from=&to=`, **naive datetime format**. Decode inline summary + `exercises[]` macros. **No `features` param** (it 400s). _AC: 24+ sessions decode; macros (fat/carb/protein %), hrAvg/Max, benefit, recovery, trigger, sport id all populated; history backfills._
- **HERC-033 · Sports catalog fetch + cache** · P2 — `GET /sports/list` (no dates). Seed `sport_ref` (id → name). Reference data — refresh rarely, not per-sync. _AC: sport id 83 resolves to its name; catalog cached and reused across syncs._
- **HERC-034 · Device info fetch** · P2 — `GET /user-devices` (no dates). Store firmware, UUID, color, registration, `deviceSettings` (incl. `automaticTrainingDetection`). _AC: device row populated; battery correctly **absent** (documented, deferred to BLE)._

---

## Domain Concept Identification

### Existing Concepts (from codebase)

- **`RefreshAwareV4Client`** (`Packages/Sources/PolarProtocol/Auth/RefreshAwareV4Client.swift`): the single mandated transport for all v4 data calls. An `actor` exposing `data(for: URLRequest) async throws -> (Data, URLResponse)` that injects the v4 bearer, refreshes once on 401 (single-flight), and retries. **Every v4 client in Epic 3 must route through it** (Safeguard 4 in the existing design). It does not decode or know about endpoints — it is pure transport.
- **`TokenStore` / `V3Credential`** (`Packages/Sources/PolarProtocol/Auth/TokenStore.swift`, `V3Credential.swift`): the v3 long-lived bearer (no refresh) plus its `userID`. v3 data calls authenticate by reading this credential and setting a `Bearer` header directly — **there is no v3 equivalent of the refresh-aware client**, by design (v3 issues no refresh token).
- **`UserRegistrationService`** (`Packages/Sources/PolarProtocol/Auth/UserRegistrationService.swift`): the only existing example of a v3 data call against `www.polaraccesslink.com/v3`. It establishes the de-facto v3 calling pattern (build `URLRequest`, `Bearer <v3.accessToken>`, `Accept: application/json`, map status, decode) that Epic 2 clients should mirror.
- **`AuthError`** (`Packages/Sources/PolarProtocol/Auth/AuthError.swift`): the typed error currency of the data layer (`network(String)`, `tokenExchangeFailed`, etc.), explicitly redaction-safe (never tokens). New fetch errors should reuse or extend this vocabulary rather than inventing a parallel one.
- **`PolarProtocol` package**: the home module for API models + clients (no UI, no DB). All Epic 2/3 code belongs here, alongside the existing `Auth/` folder.
- **`PolarStore` / `PolarDatabase`** (`Packages/Sources/PolarStore/PolarDatabase.swift`): the GRDB store with a currently-empty migrator. **Out of scope for this work** — it is where Epic 4/5 will persist what these clients decode. Named here only to mark the boundary.
- **`ARCHITECTURE.md` §4, §7, §8**: the validated endpoint reference, the two v4 date dialects, and the workout-detail "one call + local slice" pattern — the authoritative spec these clients implement against.

### New Concepts Required

- **v3 data transport** — a thin client that reads the stored `V3Credential`, applies the `Bearer` header against base URL `www.polaraccesslink.com/v3`, and surfaces typed errors. The v3 analogue of `RefreshAwareV4Client`, but with no refresh path. Relates to `TokenStore` and every v3 endpoint model.
- **Per-domain v3 response models** — typed, `Decodable` representations of sleep nights, nightly recharge, cardio load, continuous HR samples, daily activity totals, activity samples + intensity zones, and the sleep-availability manifest. Each maps one endpoint's JSON. Relates to the eventual `sleep_night` / `recharge` / `cardio_load` / `hr_minute` / `activity_day` / `activity_minute` tables (Epic 4) but does **not** depend on them.
- **Per-domain v4 response models** — typed representations of training-session list items (inline summary + `exercises[]` macros + `startTrigger` + `sport.id`), the sports catalog (id → name), and device info (firmware/UUID/color/settings, battery deliberately absent). Relates to `training_session` / `sport_ref` / `device` tables.
- **Date-dialect formatting** — two pure formatters: `dateOnly` (`YYYY-MM-DD`, all v3 + most date params) and `naiveDateTime` (`YYYY-MM-DDTHH:MM:SS`, **no zone/offset/millis**, used only by `training-sessions/list`). New and central — neither exists in the codebase yet. The single biggest historical bug source (§4); governs every ranged request.
- **Sample downsampling (bucketing) transform** — the per-minute min/avg/max bucketing for continuous HR and the per-minute steps bucketing for activity samples. A pure transform over decoded raw arrays. Its placement (client boundary vs. ingest step) is a key decision below.
- **Status / enum mapping** — small value enums for stringly-typed fields (cardio-load `status`, `startTrigger`, `grade_classification`, etc.), keeping unknown values non-fatal.

### Key Business Rules

- **v3 → plain date; v4 training-sessions → naive datetime.** Any zoned/offset/epoch/millis form is rejected by the datetime endpoint with an identical, unhelpful error for both dialects. Governs the date-dialect formatter and every ranged client.
- **All v4 calls route through `RefreshAwareV4Client`.** No v4 client may build its own `URLSession.data` path. Governs the three v4 clients.
- **v3 uses the bearer directly; no refresh logic.** Governs the v3 transport.
- **`training-sessions/list` takes no `features` param** (returns 400); its detail is fully inline. Governs the training-session model + request.
- **Raw high-frequency arrays must never reach the store at native resolution.** Continuous HR (~5-sec, ≈16 MB/28 d) and step samples bucket to per-minute; peak memory must stay bounded during a multi-day pull. Governs the continuous-HR and activity-samples paths.
- **Battery is intentionally absent** from `user-devices` — its absence is a documented correctness condition, not a decode failure. Governs the device model.
- **Reference data (sports catalog) is cached, not fetched per sync.** Governs how HERC-033 is consumed (a caching concern that mostly lands in Epic 4/5, but the client must be shaped to allow it).

---

## Strategic Approach

### Solution Direction

Build a layer of **stateless, decode-only typed clients** in `PolarProtocol`, one per endpoint family, grouped by realm (e.g. a `V3/` and `V4/` folder beside `Auth/`). Each client:

1. composes a `URLRequest` from a base URL + path + date-dialect-formatted query params,
2. delegates transport to the appropriate auth layer (`RefreshAwareV4Client` for v4; a new thin v3 transport for v3),
3. decodes the response into a typed model, and
4. maps non-2xx / decode failures into the existing `AuthError` vocabulary.

Crucially, these clients **return typed models and nothing else** — no persistence, no GRDB, no multi-domain orchestration, no sync windows. That coordination layer is explicitly deferred (see scope note below). General data flow: `client.fetchX(window) → URLRequest → auth transport → Data → typed model`. This directly honors the user's intent ("fetching/orchestration and storage come later") while making Epic 2/3 the well-tested foundation the later epics compose.

> **Scope reconciliation (user note).** The user wrote "fetching everything all at once in epic 4 and then store in local db in epic 5." Per `BACKLOG.md` the numbering is the reverse — **Epic 4 = Local store (GRDB), Epic 5 = Sync engine (orchestrated fetch)** — but the *intent* is unambiguous and correct: the coordinated "fetch everything" pass and persistence both live **after** this work. This analysis therefore scopes Epic 2/3 to **per-endpoint clients + models only**. The numbering mismatch is noted, not blocking.

### Key Design Decisions

- **v3 transport: build a thin dedicated client vs. reuse `URLSession` ad-hoc per client.** Trade-off: a shared `V3Client` (read credential, set bearer, base URL, error mapping) centralizes the auth/error logic exactly as `RefreshAwareV4Client` does for v4, at the cost of one more small type; ad-hoc per-client duplicates the `Bearer`/error boilerplate already seen in `UserRegistrationService`. → **Recommendation: a single thin v3 transport** mirroring the v4 client's `data(for:)` shape (minus refresh). Gives symmetry across realms and one place for v3 error mapping.

- **Date-dialect handling: one shared formatter module vs. per-client formatting.** → **Recommendation: a single, centralized date-dialect utility** (`dateOnly` / `naiveDateTime`) used by every client. This is the codebase's worst historical bug (§4); centralizing it makes the rule enforceable and testable in one spot, and prevents a v4-datetime endpoint from accidentally receiving a zoned string.

- **Downsampling boundary for high-frequency data (HERC-023, HERC-025): in the client vs. in a later ingest step.** The AC ("never persists raw 5-sec rows; peak memory bounded") is partly a *storage* guarantee (Epic 4/5) and partly a *fetch-time memory* guarantee (this epic). Trade-off: pushing bucketing fully to Epic 5 keeps these clients pure but risks fully materializing ≈16 MB of raw samples in memory first; doing it in the client couples decode with a transform but bounds memory at the source. → **Recommendation: keep the bucketing transform a pure function authored *now* (alongside the model), and have the continuous-HR/activity-sample clients expose minute-bucketed output as their primary product**, so raw native-resolution arrays never escape the client. This satisfies "peak memory bounded" within Epic 2 while leaving the actual row-writing to Epic 4. (The clients may still optionally expose raw arrays for tests, but the default return is bucketed.)

- **Decode depth: model every field now vs. only what the dashboard needs.** Trade-off: full fidelity future-proofs against re-fetch but enlarges the models; minimal decode is leaner but may force schema churn later. → **Recommendation: decode the fields named in each story's AC and `ARCHITECTURE.md` §7, tolerantly** (unknown/extra keys ignored, optionals for fields not guaranteed present), rather than exhaustively mapping every JSON key. This matches the ACs precisely and keeps models aligned with the eventual tables.

- **P2 stories (HERC-026 manifest, HERC-033 sports, HERC-034 devices): include in this pass vs. defer.** → **Recommendation: include the *clients* for all three** (they are small and complete the realm surface), but treat their *consumption semantics* — manifest-driven skipping (026) and catalog caching (033) — as Epic 5/4 concerns. The clients should be shaped to enable those without implementing the orchestration here.

### Alternatives Considered

- **A single generic "PolarClient" parameterized by endpoint.** Rejected: the two realms have different transports (refresh vs. none), different base URLs, and different date dialects; a generic over all of them would hide exactly the asymmetries (§3) that cause bugs. Per-realm grouping with shared utilities is clearer.
- **Deferring downsampling entirely to Epic 5.** Rejected for continuous HR: it violates the "peak memory bounded" AC during a multi-day pull, since the raw arrays would fully materialize before any later transform runs.
- **Decoding into untyped dictionaries and mapping later.** Rejected: loses compile-time safety and the "typed models decode a live response" ACs, and contradicts the existing typed-DTO convention (`TokenResponseDTO`, `V4TokenPair`).

---

## Risk & Gap Analysis

### Requirement Ambiguities

- **Epic numbering vs. intent (user note).** "Epic 4 fetch / Epic 5 store" inverts the backlog ("Epic 4 store / Epic 5 sync"). Resolved by reading intent: orchestration + persistence are both post-Epic-3. Flagged so the REASONS Canvas phase doesn't accidentally pull storage into scope.
- **"Downsample on ingest" ownership.** The ACs for HERC-023/025 mix a fetch-time concern (bounded memory) with a storage concern ("minute rows written"). Needs an explicit boundary decision (recommended above: pure bucketing transform authored now, row-writing deferred).
- **`userID` injection.** v3 endpoints address the authenticated user implicitly via the bearer, but registration captures an `x_user_id`/`polar-user-id`. Whether any Epic 2 path needs the id in the URL/header (vs. bearer-only) should be confirmed against a live call shape — `UserRegistrationService` uses bearer-only.

### Edge Cases

- **Empty / 204 responses.** Sleep and several v3 endpoints legitimately return no data for some dates; the manifest (HERC-026) exists precisely because of this. Clients must treat "no nights / empty array" as success, not error. (Biosensing's 204 is the known precedent — §11.)
- **Sample arrays present but partial.** Recharge/continuous-HR sample arrays may be shorter than expected or have gaps; bucketing must not assume a fixed sample count per minute.
- **Stringly-typed enums with unknown values.** cardio-load `status`, `startTrigger`, `grade_classification` — an unrecognized value should map to an `unknown`/raw case, never fail the whole decode.
- **Multi-day windows exceeding API range caps.** continuous-samples 30 d, nightly-recharge 28 d (§7). A requested window larger than the cap will 400. Splitting/paging is formally an Epic 5 (`HERC-053`) concern, but the clients should accept a window and not silently assume it is within cap — surface the boundary.
- **Time-zone of date boundaries.** "A night" / "a day" is local to the user; constructing `from`/`to` for ranged v3 calls must use a consistent local-day boundary, or sleep/activity rows can land on the wrong date.

### Technical Risks

- **Date-dialect regression (highest).** A zoned/millis string sent to `training-sessions/list` fails with an opaque error identical to the date-only failure. Mitigation: centralized formatter + a test asserting the exact emitted string shape per dialect.
- **Memory blow-up on continuous HR.** ≈16 MB/28 d of 5-sec samples. Mitigation: client returns minute-buckets as its primary product (decision above); avoid holding the full raw array longer than a single decode.
- **`features`/param traps on v4.** `training-sessions/list` 400s if `features` is sent; only `from`/`to` (naive datetime) are valid. Mitigation: explicitly omit `features`; encode the rule in the request builder.
- **Transport coupling for v4.** If any v4 client bypasses `RefreshAwareV4Client`, refresh-on-401 breaks silently. Mitigation: v4 clients take the actor as a dependency and have no `URLSession` of their own.
- **Decode brittleness vs. live JSON drift.** Models assert on real Polar payload shapes that aren't in-repo. Mitigation: tolerant decoding (optionals, ignore-unknown) + validate against a captured live sample per endpoint as the AC requires ("decode a live response").

### Acceptance Criteria Coverage

| AC# | Description | Addressable? | Gaps/Notes |
|-----|-------------|--------------|------------|
| HERC-020 | Sleep `nights[]` typed models decode a live response; ~25 nights | Yes | Tolerant decode of hypnogram/stages/HR-samples; needs a captured live sample to verify. |
| HERC-021 | Nightly recharge decodes; 5-min sample arrays intact | Yes | Sample arrays kept intact at this layer (downsampling not required for recharge). |
| HERC-022 | Cardio load 28-day series decodes; status → enum | Yes | Enum must tolerate unknown status strings. |
| HERC-023 | Multi-day continuous HR never persists raw 5-sec; minute rows; bounded memory | **Partial** | "Minute rows written" is Epic 4 (storage). This epic delivers the bucketing transform + bounded-memory fetch; row-writing deferred. Boundary decision required. |
| HERC-024 | 7-day activity range decodes; all tiles; history (not transactional) | Yes | Both `/activities/{date}` and `/activities?from=&to=` shapes; ISO-8601 durations parsed. |
| HERC-025 | Step graph + zone bar reproducible; no MET math | **Partial** | Decode + step bucketing here; "reproducible graph/bar" is realized when UI (Epic 6) reads it. Downsample boundary same as HERC-023. |
| HERC-026 | Sync queries manifest first, skips empty nights (P2) | **Partial** | Client for `sleep/available` is in scope; the "sync skips empty nights" behavior is Epic 5 orchestration. |
| HERC-032 | 24+ sessions decode; macros/hr/benefit/recovery/trigger/sport id; backfills | Yes | Naive-datetime window; no `features`; `exercises[]` macros + `startTrigger` + `sport.id` modeled. |
| HERC-033 | sport id 83 → name; catalog cached, reused (P2) | **Partial** | Fetch + model in scope; caching/reuse across syncs is Epic 4/5. |
| HERC-034 | Device row populated; battery correctly absent (P2) | Yes | Battery absence modeled as expected, not an error. |

**Overall:** 6 of 10 ACs fully addressable within Epic 2/3 as scoped (decode-only clients); 4 are **partial by design** because their tail (row-writing, manifest-driven skipping, catalog caching, graph reproduction) belongs to Epic 4/5/6 per the user's own framing. No AC is unaddressable.
