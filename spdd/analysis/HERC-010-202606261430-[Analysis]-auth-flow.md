# SPDD Analysis: Polar Authentication & Onboarding Flow

## Original Business Requirement

> for building the auth flow, you have the design for look and feel and im assuming for v4 we will need client id and secret which i have i can put them in a local config if needed

**Formal scope (from `BACKLOG.md` EPIC 1 — Authentication, the acceptance criteria for this work):**

- **HERC-010 · v3 token acquisition + storage** · P0 — One-time OAuth against `flow.polar.com/oauth2/authorization` (scope `accesslink.read_all`), exchange at `polarremote.com/v2/oauth2/token`, store the ~10-year bearer in Keychain. _AC: a stored v3 bearer authenticates a test call; **no refresh logic built** (v3 issues none)._
- **HERC-011 · One-time user registration** · P0 — `POST /v3/users` with `{"member-id": ...}` once per user; handle already-registered gracefully. _AC: returns 201 on first run; subsequent runs no-op without error._
- **HERC-012 · v4 OAuth flow** · P0 — Authorize against `auth.polar.com/oauth/authorize` requesting **all needed scopes in one consent**, exchange at `auth.polar.com/oauth/token`. _AC: returns access (1 h) + refresh (~100 d) pair; both stored in Keychain; granted scopes logged._
- **HERC-013 · v4 refresh-aware HTTP client** · P0 — Wrap v4 calls so a 401/expiry triggers a refresh-token exchange, swaps the stored pair, and retries once. **Gates all v4 sync.** _AC: an expired access token transparently refreshes and the original call succeeds; a failed refresh surfaces a clean re-auth prompt._

**Look-and-feel reference:** `project-hercules-design-handoff/project/Onboarding and connection.dc.html` (5 frames: Welcome, OAuth consent, Secure hand-off modal, Authorizing, Initial sync) + `CLAUDE.md` (the Hercules instrument design system).

---

## Domain Concept Identification

### Existing Concepts (from codebase)

- **Keychain** (`Packages/Sources/PolarProtocol/Keychain.swift`): generic-password store keyed by account under service `dev.hercules.app`, `afterFirstUnlockThisDeviceOnly`, no iCloud sync. The designated home for **all** tokens and secrets — relates to every credential concept below.
- **PolarProtocol namespace** (`Packages/Sources/PolarProtocol/PolarProtocol.swift`): the data-layer module where auth clients and token models belong (no UI, no DB).
- **`hercules://` URL scheme + `.onOpenURL`** (`project.yml` `CFBundleURLTypes`, `App/HerculesApp.swift`): the registered OAuth callback entry point — currently only logs the URL. Relates to **OAuth callback capture**.
- **PolarDatabase** (`Packages/Sources/PolarStore/PolarDatabase.swift`): local GRDB store with an empty migrator. Auth does **not** persist tokens here (those go to Keychain), but **registration state** and `sync_state` (per `ARCHITECTURE.md` §9) are its eventual concern.
- **HerculesRootView** (`Packages/Sources/HerculesUI/HerculesRootView.swift`): placeholder shown today; the onboarding flow and an auth-state router precede/replace it.

### New Concepts Required

- **v3 Credential** — a single long-lived (~10 yr) bearer with **no refresh token**. Relates to Keychain (stored once) and to every v3 data call.
- **v4 Token Pair** — short-lived access token (1 h) + refresh token (~100 d), plus the **set of granted scopes**. Relates to Keychain and the refresh-aware client.
- **v4 Client Credentials** — `client_id` + `client_secret` identifying the app to the v4 realm. The user **has these** and proposes a local config. Storage location is an open decision (see Strategic Approach).
- **OAuth Authorization (per realm)** — the secure hand-off that yields an authorization code; v3 and v4 are **two distinct realms** with different authorize/token hosts. Relates to the design's "secure browser sheet."
- **Code → Token Exchange (per realm)** — turns an authorization code into stored credentials; distinct endpoints per realm.
- **User Registration** — one-time `POST /v3/users` with a `member-id`; idempotent. Gates all v3 data access. Relates to v3 Credential and to a persisted "registered" flag.
- **Connection / Auth State** — the app's coarse status (`disconnected` · `connected` · `re-auth-needed`) that routes between onboarding and dashboard. Relates to Keychain presence + registration flag.
- **Refresh-aware v4 client** — wraps v4 calls; refreshes on 401 and retries once. Gates all v4 sync.
- **Onboarding flow state** — the linear progression Welcome → Consent → Secure hand-off → Authorizing → Initial sync → Dashboard, with branch points for cancel/failure/re-auth.

### Key Business Rules

- **v3 issues no refresh token — do not build v3 refresh logic** (`ARCHITECTURE.md` §3; HERC-010 AC). Obtain once, store, use forever.
- **v4 access expires hourly; refresh via the refresh token; request ALL v4 scopes in one consent round** (scopes are only granted if requested *and* consented together).
- **Two separate auth realms**: v3 = `flow.polar.com` authorize / `polarremote.com/v2` token; v4 = `auth.polar.com` authorize+token. Two independent round trips.
- **Secrets and tokens never in `UserDefaults` or source — Keychain only** (`ARCHITECTURE.md` §13). The user's "local config" proposal is in tension with this and must be reconciled.
- **Redirect URI must exactly match** what is registered with Polar (exact-string match is an OAuth requirement).
- **Registration is one-time and idempotent** — already-registered must no-op cleanly.
- **After first successful auth + sync, the app always opens to the Dashboard**; auth/refresh happens silently thereafter (`SCREENS_AND_FEATURES.md` §1).
- **Read-only** — nothing is ever written back to Polar (a trust claim made on the consent screen).

---

## Strategic Approach

### Solution Direction

- **Layering follows the existing module split.** Auth clients, token models, the OAuth coordinator, and the refresh-aware HTTP client live in **PolarProtocol**; tokens persist via the existing **Keychain**; the onboarding screens live in **HerculesUI**; an observable **auth/connection state** in the app target decides onboarding-vs-dashboard routing. No new package is needed.
- **Use the platform OAuth primitive.** The design's "secure browser sheet / Continue to Polar / Cancel" maps directly to `ASWebAuthenticationSession` (ephemeral, system-secured, captures the `hercules://` redirect in its completion handler). The existing `.onOpenURL` hook becomes a fallback rather than the primary path.
- **Two round trips presented as one logical step.** Execute the v3 and v4 authorizations back-to-back (each: authorize → code → token exchange → store), then run the one-time v3 user registration, then hand off to initial sync. The UI frames this as a single "Grant data access" moment even though Polar shows two authorize pages.
- **General data-flow direction:** `Onboarding UI → OAuth coordinator (PolarProtocol) → ASWebAuthenticationSession per realm → token exchange → Keychain → registration → auth-state flips to connected → router shows Dashboard`. v4 data calls route through the refresh-aware client; v3 calls use the stored bearer directly.

### Key Design Decisions

- **Where the v4 `client_id`/`client_secret` live** — _options:_ (a) gitignored local config file (e.g. an xcconfig or untracked plist) read at build/first-run; (b) Keychain-only, seeded manually; (c) config file as the source, **promoted into Keychain on first run** then read from Keychain. _Trade-offs:_ a config file is the most ergonomic for a personal repo and matches the user's stated preference, but any secret shipped in an app binary is extractable, and architecture says "Keychain only"; Keychain-only is the strictest but needs a one-time seeding mechanism. _Recommendation:_ **(c)** — keep the secret in a gitignored config as the human-editable source, copy it into Keychain on first launch, and read from Keychain at runtime. This honours both the user's "local config" preference and the architecture's Keychain rule, and keeps the secret out of source control. (For a single-user personal app the extractability risk is acceptable and should be documented.)
- **One combined onboarding vs two visible consents** — _trade-off:_ the design promises "granted in one consent," but two realms mean two Polar authorize screens. _Recommendation:_ keep the single-step UX, but sequence two `ASWebAuthenticationSession` presentations; treat the pair as one atomic "connect" operation (see partial-failure edge case).
- **Callback capture** — _trade-off:_ `ASWebAuthenticationSession` completion handler (clean, scoped) vs app-level `.onOpenURL` (global, needs state plumbing). _Recommendation:_ rely on the session completion handler; retain the registered scheme as a safety net.
- **Auth-state ownership & routing** — _trade-off:_ a global observable in the app vs a coordinator object. _Recommendation:_ a small observable auth/connection state derived from Keychain presence + a persisted "registered" flag, observed at the app root to switch between onboarding and dashboard.
- **Initial-sync screen coupling** — the sync engine (EPIC 5) does not exist yet. _Trade-off:_ build the sync screen against a stub now vs defer it. _Recommendation:_ build the onboarding sync screen against a **protocol/stub** so the visual flow is complete, and wire the real sync when EPIC 5 lands.

### Alternatives Considered

- **`SFSafariViewController` / `WKWebView`** for the hand-off — rejected; `ASWebAuthenticationSession` is the platform-standard for OAuth, provides the ephemeral secure session and redirect capture the design depicts, and avoids hand-rolling cookie/callback handling.
- **Persisting tokens in GRDB/SwiftData** — rejected; Keychain is the security boundary for credentials (architecture §13).
- **Building a v3 refresh path** — explicitly rejected; v3 issues no refresh token and a ~10-year expiry (architecture §3, HERC-010 AC).

---

## Risk & Gap Analysis

### Requirement Ambiguities

- **Client-secret storage is unresolved.** The user offers a local config; `ARCHITECTURE.md` §13 says "Keychain only." Needs a decision (see recommended option (c) above).
- **Redirect URI mismatch in the source material.** `ARCHITECTURE.md` §13 registers `hercules://oauth/callback`; the design's "Authorizing" frame (2c) shows `hercules://auth/callback`. The value compiled into the app **must exactly match** what is registered at Polar. Which is authoritative must be confirmed before implementation.
- **v3 client credentials are undocumented.** Architecture lists a v4 `client_id` (§13) but no v3 `client_id`/`secret`, while v3 still has an OAuth authorize/token round trip. Whether v3 needs its own registered client (and where those credentials are) must be confirmed.
- **`member-id` value & source.** §13 lists `member-id: yug-hercules-test`; HERC-011 parameterises it. Confirm the exact value and whether it is fixed or user-entered.
- **Single-consent UX vs two realms.** Confirm the desired experience: one combined "connect" that internally runs two Polar authorize pages.
- **Does the dashboard gate on initial-sync completion** given the sync engine isn't built? Scope boundary for this slice.

### Edge Cases

- **User cancels the secure session** (the design has a Cancel control): must return to the consent screen with no partial credential state.
- **One realm succeeds, the other fails:** must not leave the app half-connected; treat "connect" as atomic or clearly recoverable.
- **v3 already registered** (`POST /v3/users` returns conflict/200): idempotent no-op per HERC-011.
- **v4 refresh token expired (~100 d idle):** full re-auth required; the onboarding design has no explicit "re-auth needed" entry point — a gap.
- **Partial scope grant:** if the user unchecks a scope at Polar, dependent data must degrade gracefully (scopes are only granted if requested *and* consented).
- **Token present but revoked/invalid:** detect on first call → route to re-auth rather than failing silently.
- **App reinstall on the same device:** `afterFirstUnlockThisDeviceOnly` Keychain items can survive reinstall → stale tokens may linger; decide whether to clear on first run.

### Technical Risks

- **Shipped client secret is extractable** from the app binary regardless of storage choice — acceptable for a single-user personal app, but must be documented, not assumed.
- **Concurrent 401s racing the refresh:** the refresh-aware client (HERC-013) needs **single-flight** refresh so simultaneous expired calls don't trigger parallel refreshes that invalidate each other.
- **Main-actor / presentation-context correctness** for `ASWebAuthenticationSession` under Swift 6 strict concurrency (the project builds in Swift 6 mode).
- **No cross-device auth** by design (device-only Keychain, no iCloud sync) → re-auth per device; fine for this app but worth stating.
- **Secret leakage via build artifacts:** a config-file secret must not leak into the generated `Info.plist`, build logs, or the committed `.xcodeproj` (which is gitignored — good).

### Acceptance Criteria Coverage

| AC# | Description | Addressable? | Gaps/Notes |
|-----|-------------|--------------|------------|
| HERC-010 | Stored v3 bearer authenticates a test call; no refresh logic built | Yes | Pending confirmation of v3 client credentials & exact redirect URI |
| HERC-011 | `POST /v3/users` returns 201 first run; subsequent runs no-op | Yes | Confirm `member-id` value/source; define idempotent handling for conflict response |
| HERC-012 | v4 returns access+refresh pair; both stored in Keychain; granted scopes logged | Partial | Blocked on the client-secret storage decision; "one consent" spans two realms |
| HERC-013 | Expired token transparently refreshes & retries once; failed refresh → clean re-auth prompt | Partial | Single-flight refresh required; the "re-auth prompt" UI/state is not in the current onboarding design — a gap to design |
