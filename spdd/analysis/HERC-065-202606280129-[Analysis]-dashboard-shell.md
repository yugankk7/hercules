# SPDD Analysis: Dashboard Shell & Navigation Scaffold (precursor to EPIC 6 cards)

## Original Business Requirement

> for the next feature i would like to skip to epic 6 for the dashboard, have a basic dashboard ready and then add stuff into it as we keep on building the features

Expanded scope provided with the request:

> Skip ahead to EPIC 6 (Dashboard). Goal: stand up a basic, working dashboard screen now that the auth/onboarding flow lands on it, then incrementally add data domains/cards into it as we build out later features. The dashboard should replace the current HerculesRootView placeholder that connected users currently land on. Analyze against the existing codebase (PolarProtocol auth layer + PolarStore GRDB + HerculesUI design system) and the design handoff (Dashboard.dc.html + CLAUDE.md instrument design system), and the BACKLOG/ARCHITECTURE/SCREENS_AND_FEATURES docs.

**Relevant formal scope (BACKLOG.md EPIC 6 — UI wiring / dashboard):** HERC-060 Cardio load card · HERC-061 Activity card · HERC-062 HR card · HERC-063 Sleep & recharge cards · HERC-064 Workout list. Each story's AC is "reproduces the *X* screen **from local data**." Design references: `project-hercules-design-handoff/project/Dashboard.dc.html` (home feed + card states + reorder feed) and `CLAUDE.md` (instrument design system). Screen brief: `SCREENS_AND_FEATURES.md` §2 (Dashboard) and §7 (global states).

---

## Domain Concept Identification

### Existing Concepts (from codebase)

- **`AuthManager` / `ConnectionState`** (`PolarProtocol/Auth/AuthManager.swift`): the `@MainActor @Observable` orchestrator whose `state == .connected` currently routes the app root to the placeholder. The dashboard is the new `connected` destination; `signOut()` (already implemented, clears Keychain → `disconnected`) is the natural "disconnect / re-auth" action for a Settings/Profile surface.
- **`HerculesRootView`** (`HerculesUI/HerculesRootView.swift`): the EPIC-0 placeholder ("HERCULES / TELEMETRY / FOUNDATION READY") shown today to connected users. **This is what the dashboard replaces** in the app-root router (`App/HerculesApp.swift`).
- **`Theme` + onboarding views** (`HerculesUI/Onboarding/`): the established instrument design tokens (palette, Azeret-Mono mono type, pill CTAs, terminal readout) and the presentation-only convention (views observe an `@Observable` manager; no network/Keychain in the view layer). The dashboard extends this same design-system surface.
- **`PolarDatabase`** (`PolarStore/PolarDatabase.swift`): the GRDB store — **migrator is empty** (tables arrive in HERC-040). There is **no data and no read API** yet. This is the central constraint: the dashboard's data source does not exist.
- **`PolarProtocol` auth layer**: provides the only working live capability so far (auth/token lifecycle). No v3/v4 *data* clients exist yet (EPIC 2/3 unbuilt).

### New Concepts Required

- **Dashboard (home feed)**: the scrollable hub of glanceable metric cards that connected users land on — relates to `ConnectionState.connected` (routing) and, eventually, to the local store (read source).
- **Dashboard card (per-domain glance)**: a self-contained, tappable summary for one data domain (Activity, Sleep, Recharge, Cardio Load, Boost, Continuous HR, Latest Workout, Device). The unit of incremental growth — "add stuff as we build features" means adding cards. Relates 1:1 to the future per-domain data (EPIC 2–5) and to the detail screens (future).
- **Card state**: each card must render `populated · empty/first-run · no-data · stale · calibrating` (explicit in `SCREENS_AND_FEATURES.md` §2/§7 and Dashboard.dc.html frame 02). Until data lands, **every card sits in empty/first-run** — so card-state handling is the primary deliverable now, not populated visuals.
- **Navigation shell**: the app's primary nav (`Home · Trends · Workouts · Profile` per design; `SCREENS_AND_FEATURES.md` §App-structure says Dashboard · Workouts · Device · Settings) plus card→detail push. Relates to the dashboard (Home tab) and future detail screens.
- **Sync freshness / "last synced X ago"**: a header indicator and per-card stale marker derived from `sync_state` (an ARCHITECTURE §9 table that does not exist yet). New concept; needs a stub source now.
- **Manual refresh trigger (pull-to-sync)**: the *only* network trigger (ARCHITECTURE §1, SCREENS §2). The sync engine (EPIC 5) does not exist, so this is a presentation/seam concept now, backed by a stub.
- **Dashboard data provider (seam)**: the abstraction that feeds cards their glance content and the feed its freshness — a protocol with a stub implementation today, a `PolarStore`-backed implementation once read APIs (HERC-042) land. Mirrors how `InitialSyncProviding` was stubbed in the auth slice.

### Key Business Rules

- **Local-first / never blocks on network** (ARCHITECTURE §1, SCREENS §0): the dashboard reads **only** from the local store; opening it is instant; no spinners on data screens. The view layer holds no network/Keychain access (established convention).
- **Always opens to the dashboard after first connect** (SCREENS §1): once `connected`, the app routes straight to the populated dashboard; auth/refresh is silent.
- **Pull-to-refresh is the sole network trigger** (SCREENS §2, ARCHITECTURE §1): no background cron in phase 1.
- **Fetch window ≠ display window** (ARCHITECTURE §1): cards filter a locally-held range; range switches hit zero network. (Future-facing, but it shapes the card data contract.)
- **Every card must degrade gracefully** to empty/no-data (SCREENS §2 states; Dashboard.dc.html frame 02 "EMPTY / NO DATA"). Non-negotiable for *this* slice since no data exists.
- **Orange is reserved for live/active/important** (CLAUDE.md); slate carries the rest; no circular spinners (terminal readout only).
- **Read-only, single-user** (project-wide): the dashboard never writes back to Polar.

---

## Strategic Approach

### Solution Direction

- **Build a presentation-only dashboard shell in `HerculesUI`** that replaces `HerculesRootView` as the `connected` route in the app-root router. The shell is the home feed + a navigation shell + the pull-to-refresh affordance, rendered entirely in the instrument design language.
- **Make the card feed the unit of incremental growth.** Model the home feed as an ordered collection of cards driven by a small card abstraction, so that "adding a feature" later means dropping in one populated card + its detail link, without restructuring the dashboard. This directly serves the user's "add stuff as we keep building" intent.
- **Introduce a thin data-provider seam, stubbed now.** A dashboard view-model (`@MainActor @Observable`, mirroring `AuthManager`) reads from a `DashboardProviding`-style protocol whose stub returns first-run/empty card states and "never synced" freshness. The `PolarStore`-backed implementation lands when read APIs (HERC-042) exist. **No `PolarStore` schema migration in this slice** — mirroring the conservative boundary the auth slice held.
- **Wire pull-to-refresh to a stub sync coordinator.** The interaction (pull → in-progress affordance → updated "synced just now") is established now against a local stub that performs no network I/O; the real EPIC-5 engine swaps in behind the same seam later.
- **General flow:** `App root observes AuthManager.state` → `connected` renders `DashboardView` → `DashboardView` observes a dashboard view-model → view-model pulls card glances + freshness from the (stubbed) provider → cards render their populated/empty/stale states → pull-to-refresh invokes the (stubbed) sync coordinator.
- **Give sign-out / re-auth a home.** Surface `AuthManager.signOut()` from a Profile/Settings entry in the nav shell — this also resolves the standing need to replay onboarding without uninstalling the app.

### Key Design Decisions

- **Card extensibility model — hardcoded stack vs. data-driven feed**: A fixed `VStack` of bespoke card views is simplest but fights the "add incrementally / reorder" goal. A fully data-driven, drag-reorderable feed (design frame 03) is the long-term target but heavier. → **Recommendation:** a *data-driven feed of typed card slots* (an ordered list the dashboard renders via a card abstraction), but **defer drag-to-reorder** (design frame 03) to a later enhancement. This gives clean incremental growth now without the reorder complexity.
- **Data source for this slice — stub provider vs. wait for `PolarStore`**: Waiting blocks the UI work behind EPIC 2–5. → **Recommendation:** a **stub `DashboardProviding`** returning empty/first-run card states (a state the design explicitly specifies). The shell becomes real, runnable, and testable immediately, and the seam is the exact insertion point for real data later.
- **Refresh behavior now — stub vs. omit**: Omitting pull-to-refresh leaves a core interaction unmodeled; a real sync doesn't exist. → **Recommendation:** a **no-network stub sync coordinator** wired to pull-to-refresh that animates the affordance and updates a freshness stamp, establishing the seam for HERC-051. Must visibly do nothing to the (empty) data.
- **Navigation shell — full tabs+detail vs. single scroll**: Detail screens and Trends/Workouts/Profile tabs are future epics. → **Recommendation:** a **minimal tab shell** (Home active; other tabs as labelled placeholders) matching the design's bottom nav, with card taps routing to a lightweight placeholder detail (or disabled) for now — enough to host sign-out and to validate the shell, without building detail screens.
- **Where the dashboard data contract lives — UI view-state vs. `PolarStore` read APIs**: The HERC-042 read APIs (display-ready ranges) are `PolarStore`'s eventual job but don't exist. → **Recommendation:** define the **provider seam at the UI/view-model boundary** with UI-facing glance types (only the fields the design renders), keep `PolarStore` untouched, and have `PolarStore` conform to the seam later. Avoids premature coupling to unbuilt table shapes.
- **Freshness source — stub vs. lightweight persistence**: `sync_state` (GRDB) is unbuilt. → **Recommendation:** **stub freshness** ("NEVER SYNCED" / "—") via the provider now; back it with `sync_state` when the store schema lands. Avoid a throwaway `UserDefaults` timestamp (tokens/state hygiene + it would be replaced immediately).

### Alternatives Considered

- **Build EPIC 4 (store schema) + EPIC 2 (a first v3 client) first, then a data-backed dashboard** — rejected for this slice: it inverts the user's explicit "skip ahead, basic dashboard now, add data later" intent and delays a visible, navigable app. The seam-based shell lets those epics land incrementally behind a stable UI.
- **Reuse `InitialSyncProviding` as the refresh mechanism** — rejected: that protocol models the one-time onboarding sync (progress 0→1), not the dashboard's repeatable manual refresh + per-domain freshness. A distinct (stubbed) refresh seam keeps responsibilities clean.
- **Skip the navigation shell, ship only a scrolling card list** — rejected: the design and screen brief make tabs + card→detail the structural spine, and Profile is where sign-out/re-auth belongs; a minimal shell now avoids a disruptive re-host later.
- **Implement drag-to-reorder feed now (design frame 03)** — rejected for scope: it's an enhancement on top of the feed model; the data-driven feed leaves room for it without building it yet.

---

## Risk & Gap Analysis

### Requirement Ambiguities

- **"Basic dashboard" depth is unspecified.** Does "basic" mean (a) a single scrolling list of empty card shells, or (b) the full nav shell (tabs) + card→detail routing + refresh, all against stubs? The recommended scope is (b)-minimal; the exact line (e.g. are non-Home tabs included now?) needs confirmation.
- **Navigation taxonomy conflicts between sources.** Dashboard.dc.html shows `HOME · TRENDS · WORKOUTS · PROFILE`; `SCREENS_AND_FEATURES.md` App-structure says `Dashboard · Workouts · Device · Settings`. Which tab set is authoritative for the shell must be decided.
- **Which cards appear in the first shell, and in what order.** The design lists eight (Activity, Sleep, Recharge, Cardio Load, Boost, Continuous HR, Latest Workout, Device). Building all eight as empty shells vs. a representative subset is a scope choice.
- **Are cards tappable before detail screens exist?** Need to decide between no-op, disabled, or placeholder-detail behavior for this slice.
- **Freshness semantics with no sync.** What does a never-synced app show in the "SYNCED Xm AGO" slot — "NEVER SYNCED", hidden, or "—"? Affects the header design.

### Edge Cases

- **Every card empty simultaneously (the actual default now).** With no store data, the whole feed is in first-run state; the dashboard must read as intentional ("building up / calibrating"), not broken — the design's empty state must be the *primary* visual for this slice.
- **Pull-to-refresh with nothing to fetch.** The stub must complete cleanly and not imply data arrived; repeated pulls must be idempotent and non-blocking.
- **Sign-out from the dashboard.** Invoking `signOut()` must cleanly route back to onboarding (`connected → disconnected`) and clear any dashboard view-model state, with no stale cards left rendered.
- **Re-auth required mid-session.** `ConnectionState.reauthRequired` (set when a future v4 refresh fails) needs a defined dashboard behavior — banner vs. forced route to onboarding. Currently only `connected` vs. not-connected is routed.
- **Calibrating domains.** SleepWise and early cardio load are "warming up" even once data exists (SCREENS §7) — the card-state model should reserve a `calibrating` state distinct from `empty`, even if unused now.

### Technical Risks

- **Building card UIs before real data shapes exist → rework.** Card glance view-models risk drifting from the eventual v3/v4 decoded models (EPIC 2/3) and HERC-042 read APIs. *Mitigation:* type each glance to only the fields the design renders, treat the provider seam as the contract, and keep populated visuals thin until a domain's data lands.
- **No read path / store schema yet.** The dashboard cannot satisfy any "from local data" AC. *Mitigation:* explicitly scope this slice as the shell + seams; keep `PolarStore` unmodified (no migration), consistent with the auth slice's boundary.
- **Swift 6 strict concurrency + `@MainActor @Observable` view-model.** Must match the established auth-layer concurrency model (Sendable seams, MainActor view-model, presentation-only views). *Mitigation:* mirror `AuthManager`'s patterns and injection style.
- **Navigation architecture lock-in.** The chosen shell (tabs + push routing) becomes the spine many later epics plug into; a weak abstraction is expensive to change. *Mitigation:* keep the card-feed and detail-routing seams explicit and minimal.
- **iOS 26 / Swift Charts.** The design's mini-charts (hypnogram, HR curve, cardio trend) imply Swift Charts; building them with no data is premature. *Mitigation:* render chart areas as empty-state placeholders now; introduce charts per-domain as data lands.
- **Design-vs-screen-brief divergence (nav, card set).** Two source documents disagree (see ambiguities); proceeding without reconciling risks building the wrong shell.

### Acceptance Criteria Coverage

> The BACKLOG EPIC 6 stories are all data-backed ("reproduces the *X* screen **from local data**"). This slice is a **precursor shell**; the data-backed ACs are **not** satisfiable until EPIC 2–5 land. The table assesses the formal EPIC 6 ACs against *this* shell slice and notes the shell's own implicit acceptance.

| AC# | Description | Addressable? | Gaps/Notes |
|-----|-------------|--------------|------------|
| HERC-060 | Cardio load card reproduces the screen from local data | Partial (shell only) | Empty/stale card shell + slot now; populated visual + data needs `cardio_load` (EPIC 2 HERC-022) + read API (HERC-042) |
| HERC-061 | Activity card from v3 totals + zones; range switch zero-network | Partial (shell only) | Card shell now; needs `activity_day`/zones (HERC-024/025) + read API |
| HERC-062 | HR card: 24/7 curve from `hr_minute` | Partial (shell only) | Card shell now; needs downsampled HR (HERC-023) + read API + Swift Charts |
| HERC-063 | Sleep & recharge cards from `sleep_night`/`recharge` | Partial (shell only) | Two card shells now; needs sleep/recharge fetch+models (HERC-020/021) + read API |
| HERC-064 | Workout list from `training_session`, sport names via `sport_ref` | Partial (shell only) | Latest-workout card shell now; full list + names need HERC-032/033 + read API |
| Shell-A (implicit) | Connected users land on the dashboard (replaces `HerculesRootView`) | Yes | App-root router swaps `connected` route to `DashboardView` |
| Shell-B (implicit) | All cards render the empty/first-run state cleanly with no data | Yes | Primary deliverable; design specifies the empty state |
| Shell-C (implicit) | Pull-to-refresh runs a no-network stub and updates freshness affordance | Yes | Seam for HERC-051; must not imply data fetched |
| Shell-D (implicit) | Adding a future card is a localized change (feed/card abstraction) | Yes | Data-driven feed; drag-reorder (design 03) deferred |
| Shell-E (implicit) | Sign-out / disconnect available; routes back to onboarding | Yes | `AuthManager.signOut()` surfaced from Profile/Settings; also enables onboarding replay without uninstall |
