# Project Hercules — Architecture

A personal, single-user iOS app that replaces the Polar Flow UI for a **Polar Loop Gen 2**, with a modern, snappy, animated dashboard. This document is the data/backend reference: which data is reachable, from where, in what format — all validated against live API probing and the Polar Flow screens it must reproduce.

> Status: **Data layer validated end-to-end.** Every dashboard screen maps to a tested endpoint with real data confirmed — including SleepWise / "Boost from sleep," which lives in the **v3** SleepWise tree (not v4). Both halves confirmed with live data: `sleepwise/alertness/date` (Boost score + hourly levels) and `sleepwise/circadian-bedtime/date` (sleep gate + window). Biosensing (temp/SpO2) exists in v3 but the Loop returns 204 (no such sensors). SleepWise is the only screen reproduced; nothing is an open data risk. See [Gaps](#known-gaps--deferred).

---

## 1. Design principles

- **Local-first.** The UI reads **only** from a local store. No screen ever blocks on the network. Opening the app is instant.
- **Network on manual refresh only.** A refresh button triggers sync. No background cron — iOS cannot guarantee background timers. `BGAppRefreshTask` is a best-effort phase-2 nicety, never a correctness dependency.
- **Fetch window ≠ display window.** Sync pulls generously (e.g. 90 days) into the DB; each card filters locally. Range switches on a card are instant and hit zero network.
- **Config-driven domain registry.** One entry per metric (endpoint, fetch window, default display window, sync priority) so window changes are one-line edits.
- **Downsample before storing.** Raw sample streams are large (continuous HR ≈ 16 MB / 28 days; activity ≈ 90 KB / day). Bucket to per-minute min/avg/max before persisting; keep raw only transiently during a sync pass.

---

## 2. System shape

```
┌─────────────────────────────────────────────────────────┐
│                         UI layer                         │
│         SwiftUI + Swift Charts — reads local store only  │
└───────────────────────────▲─────────────────────────────┘
                            │ (observe)
┌───────────────────────────┴─────────────────────────────┐
│                     Local store (GRDB / SQLite)          │
│   downsampled samples + session/day rows + cached refs   │
└───────────────────────────▲─────────────────────────────┘
                            │ (write on refresh)
┌───────────────────────────┴─────────────────────────────┐
│                       Sync engine                        │
│   manual trigger · per-domain windows · per-day activity │
│   loop · dedup/upsert · downsample                       │
└──────▲──────────────────▲───────────────────────▲────────┘
       │                  │                       │
┌──────┴──────┐   ┌───────┴────────┐    ┌─────────┴─────────┐
│ AccessLink  │   │  AccessLink    │    │   Polar BLE SDK   │
│   v3 (core) │   │   v4 (core)    │    │   (phase 2)       │
└─────────────┘   └────────────────┘    └───────────────────┘
```

**Three data sources, distinct roles:**

| Source | Role | Gives | Build phase |
|---|---|---|---|
| **AccessLink v3** | **Primary** core history | Sleep, nightly recharge, **cardio load**, continuous 24/7 HR, **SleepWise** (alertness + circadian bedtime), **daily activity** (computed totals + samples + zones) | 1 |
| **AccessLink v4** | Targeted supplement | **Training sessions** (workout history), **user-devices**, **sports catalog** | 1 |
| **Polar BLE SDK** | Live/raw | Real-time HR, **battery level**, raw PPI/accelerometer | 2 |

> **Why both v3 and v4 — and which leads.** This inverted during validation. **v3 is the primary, richer API:** it owns sleep, recharge, cardio load, continuous HR, SleepWise, *and* daily activity (with computed totals and zone breakdowns out of the box). **v4 earns its place for exactly three things v3 can't do well:** `training-sessions/list` (backfillable workout history — v3 exercises is transactional/go-forward only), `user-devices` (device/firmware/settings), and `sports/list` (sport id → name). Everything else we use is v3. The app leans primarily on v3 with v4 as a narrow supplement — the reverse of how this project started.

---

## 3. Authentication — three asymmetric models

This is the single most important operational detail. The three sources do **not** share an auth model.

### v3 — long-lived, no refresh
- Token returned with `expires_in: 315359999` (≈ 10 years). **No refresh token issued.**
- Effectively: obtain once, store in Keychain, use forever.
- **Near-zero lifecycle code. Do not build refresh logic for v3 — it is wasted effort.**
- Authorize: `https://flow.polar.com/oauth2/authorization` · scope `accesslink.read_all`
- Token: `https://polarremote.com/v2/oauth2/token`

### v4 — short-lived, with refresh
- Access token `expires_in: 3599` (**1 hour**) + refresh token (~100 days).
- **The only source needing real refresh machinery:** on 401/expiry, POST the refresh token to the token endpoint, swap in the new access+refresh pair, persist, retry.
- Separate auth realm (`auth.polar.com`), granular per-domain scopes (see §7).
- Authorize: `https://auth.polar.com/oauth/authorize`
- Token: `https://auth.polar.com/oauth/token`
- Scopes are only granted if requested **and** consented in that authorize round. Request all needed scopes in one consent.

### BLE SDK — not a token at all
- Bluetooth **bonding/pairing**, persisted by the OS. No expiry, no refresh, just connection state.

---

## 4. Two v4 date dialects (critical gotcha)

The single hardest bug of the build. v4 endpoints split into **two incompatible date formats**, and the error message (`"Value for key 'from' could not be parsed as datetime"`) is identical and unhelpful for both.

| Dialect | Format | Example | Endpoints |
|---|---|---|---|
| **Date-only** | `YYYY-MM-DD` | `2026-06-17` | (v4) ppi-samples, skin-contacts, etc. — mostly unused now; **v3 endpoints also use plain dates** |
| **Naive datetime** | `YYYY-MM-DDTHH:MM:SS` (**no `Z`, no offset, no millis**) | `2026-06-17T00:00:00` | `training-sessions/list` (the one v4 datetime endpoint we use) |

> Since activity moved to v3 (§2), the only v4 endpoint we call with a date range is **training-sessions/list** — and it needs the **naive datetime** form. v3 endpoints all take plain `YYYY-MM-DD`. So in practice: **v3 → plain date, v4 training-sessions → naive datetime.**

**The trap:** every zoned format (`...Z`, `...+00:00`, `...000Z`, epoch) is rejected by the datetime endpoints — they expect a `LocalDateTime` with no zone info. Note that the API *emits* zoned timestamps in responses but **does not accept that format on input.**

> **Response-side reality (verified 2026-06-28).** The two dialects above govern what we **send**. What the API **emits** is messier — **five** timestamp formats appear across responses: zoned-offset (`2026-05-31T03:23:07+05:30`, sleep/activity), zoned-`Z` (`2026-05-28T08:50:19Z`, device registration), naive-seconds (`2026-05-29T18:07:39`, training sessions), naive-minute (`2026-06-21T00:00`, activity samples), and **time-only** (`00:25:21`, continuous-HR `sample_time` — pair with the day's `date`). `PolarDateParser` (`Networking/JSONDecoder+Polar.swift`) handles all five. Several sample series are JSON **objects keyed by `"HH:MM"`**, not arrays (see §7).

```swift
// Date-only endpoints
func dateOnly(_ d: Date) -> String      // "2026-06-17"
// Datetime endpoints — naive, NO timezone suffix
func naiveDateTime(_ d: Date) -> String // "2026-06-17T00:00:00"
```

---

## 5. The `features` array rule (historical — v4 activity now unused)

> Kept for reference. This applied to v4 `activity/list`, which we **no longer use** (v3 owns activity). If you ever call a v4 endpoint that takes `features`, the rule below holds.

v4 `activity/list` returned **empty `activitiesPerDevice: []`** unless you requested `features`, **and** `features` had to be a **repeated/array param**, not a comma-joined string:

```python
params={'features': ['samples', 'activity-target', 'physical-information']}  # array, not "a,b,c"
```

In `requests`, a list produces `features=samples&features=...`. `training-sessions/list` does **not** support `features` (returns 400) — its detail is inline (see §8).

---

## 6. Validated coverage map

Every screen confirmed against a tested endpoint with **real data seen**, unless noted.

| Dashboard data | Source | Endpoint | Status |
|---|---|---|---|
| Cardio load (strain/tolerance/ratio/status) | v3 | `GET /v3/users/cardio-load` | ✅ data confirmed |
| Continuous 24/7 HR graph | v3 | `GET /v3/users/continuous-heart-rate?from=&to=` | ✅ data confirmed |
| Sleep (hypnogram, stages, score, HR samples) | v3 | `GET /v3/users/sleep` | ✅ data confirmed |
| Nightly recharge (ANS, HRV/breathing samples) | v3 | `GET /v3/users/nightly-recharge` | ✅ data confirmed |
| Daily activity (steps/calories/distance/durations) | v3 | `GET /v3/users/activities/{date}` | ✅ computed totals, backfillable |
| Daily activity intensity zones + step samples | v3 | `GET /v3/users/activities/samples/{date}` | ✅ `activity_zones` + per-min steps |
| Workout list + summary + macros | v4 | `GET /training-sessions/list` | ✅ data confirmed |
| Workout HR curve + time-in-zones | derived | slice v3 continuous-HR to session window | ✅ method confirmed |
| Sport names (id → label) | v4 | `GET /sports/list` (cached) | ✅ confirmed |
| Device firmware / settings | v4 | `GET /user-devices` | ✅ confirmed |
| Battery level | BLE | `FEATURE_BATTERY_INFO` | ⏳ phase 2 |
| SleepWise — Boost score + hourly levels | v3 | `GET /v3/users/sleepwise/alertness/date` | ✅ data confirmed |
| SleepWise — sleep gate + sleep window | v3 | `GET /v3/users/sleepwise/circadian-bedtime/date` | ✅ data confirmed |
| Biosensing — skin/body temp, SpO2 | v3 | Elixir Biosensing | ⛔ Loop returns 204 (no sensors) |

---

## 7. Endpoint reference

### Base URLs
- v3: `https://www.polaraccesslink.com/v3`
- v4: `https://www.polaraccesslink.com/v4/data`

### Mandatory one-time user registration
Before any data call, register the user to the client:
```
POST https://www.polaraccesslink.com/v3/users
Body: {"member-id": "<your-member-id>"}
```
Returns the user profile (201). Note: profile `weight` may be stale vs. the band's current value — treat `physicalInformation.weight` from activity as more current if needed.

### v3 endpoints (date format: `YYYY-MM-DD`)
| Endpoint | Response key | Notes |
|---|---|---|
| `GET /v3/users/sleep` | `nights` | ✅ `hypnogram` & `heart_rate_samples` are **objects keyed by `"HH:MM"`** (stage 0/1/3/4 = wake/REM/light/deep; HR 5-min), **not arrays**. Flat fields: `light_sleep`/`deep_sleep`/`rem_sleep`/`total_interruption_duration` (sec), `sleep_score`, `sleep_charge`, `sleep_cycles`, `continuity` (Double), `continuity_class`, `sleep_start_time`/`sleep_end_time`. 28 nights seen. |
| `GET /v3/users/nightly-recharge` | `recharges` | ✅ **`ans_charge` is a signed Double** (e.g. `-1.5`); `ans_charge_status` & `nightly_recharge_status` are **Int codes**; averages `heart_rate_avg`/`heart_rate_variability_avg`/`breathing_rate_avg`/`beat_to_beat_avg`; `hrv_samples` & `breathing_samples` are **objects keyed by `"HH:MM"`**. |
| `GET /v3/users/cardio-load` | _(top-level array)_ | ✅ Per day: `strain`, `tolerance`, `cardio_load_ratio`, `cardio_load`, `cardio_load_status` (`MAINTAINING`/`PRODUCTIVE`/…), `cardio_load_level{very_low…very_high}`. 28 days. **No envelope.** |
| `GET /v3/users/continuous-heart-rate?from=&to=` | `heart_rates` | ✅ Grouped **per day** (`heart_rates[].date` + `heart_rate_samples[]{heart_rate, sample_time}`); **`sample_time` is time-only `HH:mm:ss`** — pair with the day's `date`. ~5-sec, ≈16 MB/28 d. **Bucket to per-minute before storing.** |
| `GET /v3/users/activities/{date}` (and `/activities?from=&to=`) | _(range = top-level array)_ | ✅ **No `date` field** — derive from `start_time`/`end_time` (naive-minute). Computed totals: `steps`, `calories`, `active_calories`, `active_duration`/`inactive_duration` (ISO-8601 dur), `daily_activity`, `inactivity_alert_count`, `distance_from_steps`. **Primary activity source.** |
| `GET /v3/users/activities/samples/{date}` | — | ✅ `steps.samples[]` = `{steps, timestamp}` (`interval_ms:60000`, `total_steps`); `activity_zones.samples[]` = per-minute `{timestamp, zone}` labels (`SEDENTARY`/`SLEEP`/`LIGHT`/`MODERATE`/`VIGOROUS`/`NON_WEAR`); `inactivity_stamps.samples[].stamp`. No MET derivation. |
| `GET /v3/users/sleep/available` | `available` | ✅ `{date, start_time, end_time}`. Use in sync to fetch only existing nights. |
| `GET /v3/users/sleepwise/alertness/date?from=&to=` | — | **Boost from sleep.** `grade` (Boost score), `grade_classification`, `sleep_inertia`, `hourly_data[].alertness_level` (HIGH/LOW/VERY_LOW/MINIMAL = the hourly bars). Confirmed with live data. Also a 28-day variant (no date params). |
| `GET /v3/users/sleepwise/circadian-bedtime/date?from=&to=` | — | **Sleep gate + sleep window** (the bedtime markers). `quality` = gate recognizability (e.g. `CLEARLY_RECOGNIZABLE` = 3/3). Confirmed with live data. |
| Elixir Biosensing (body temp, skin temp, SpO2) | — | Exists in v3, **but Loop Gen 2 returns 204 / empty** — no such sensors. Parked. Not available via BLE on this band either (untested but unlikely). |

### v4 endpoints (only three are used — v3 covers the rest)
| Endpoint | Date dialect | Scope | Notes |
|---|---|---|---|
| `GET /training-sessions/list?from=&to=` | **naive datetime** | `training_sessions:read` | **USED.** ✅ Envelope `trainingSessions[]`. `identifier.id` (uuid); **`sport.id` & `recoveryTimeMillis` are strings**; `startTime`/`stopTime` naive-seconds; `startTrigger` = `TRAINING_START_AUTOMATIC_TRAINING_DETECTION` (auto-detected); `exercises[]{fat/carbo/proteinPercentage}`. Rich inline (§8), no `features`. |
| `GET /user-devices` | _(`devicesData` + `userDevicesData`)_ | `devices:read` | **USED.** ✅ Split across `devicesData[]` (firmware/`productVariant.productColor`/hardware) + `userDevicesData.activeDevices[]` (`registered` + `deviceSettings[]{name,value}`), **joined by `deviceReference.uuid`**. **No battery.** |
| `GET /sports/list` | _(top-level array)_ | `sports:read` | **USED.** ✅ `{id:{id}, name, localizedNames}` — `id.id` → `name` (`"RUNNING"`). 175 sports. **Cache, refresh rarely.** |
| `GET /activity/list` | date-only | `activity:read` | ~~Superseded by v3 activities~~ (v3 gives computed totals + zones; v4 only gave raw samples + needed a per-day feature loop and MET→calorie derivation). |
| `GET /ppi-samples`, `/skin-contacts` | date-only | — | Loop returns empty — no such data. |
| `GET /nightly-recharge-results`, `/continuous-samples` | date-only | — | v4 twins of v3 endpoints we already use. Redundant. |
| ~~`GET /calendar/list`~~ | naive datetime | `calendar:read` | **DROPPED** — feeling/notes/type live on the training session. |

### v4 rate limits & range caps
- Per-client: 3000 / 15 min, 100000 / 24 h.
- Max ranges: continuous-samples 30 d, nightly-recharge 28 d, calendar 90 d.

### Full v4 scope strings (space-delimited in authorize URL)
```
activity:read calendar:read continuous_samples:read devices:read
nightly_recharge:read ppi_data:read profile:read routes:read
skin_contact:read sleep:read sports:read temperature_measurement:read
tests:read training_sessions:read training_targets:read user_subscription:read
```

---

## 8. Workout detail pattern (one call + local slice)

`training-sessions/list` is a **hybrid**: rich inline summary, but no granular zone/curve expansion (it rejects `features` with 400). Resolved without any per-session drilldown call:

**Inline from the list (per session):**
`calories`, `hrAvg`, `hrMax`, `trainingBenefit`, `recoveryTimeMillis`, `note`, `startTrigger` (`AUTOMATIC_TRAINING_DETECTION` = the auto-detected marker), `durationMillis`, `startTime`/`stopTime`, `sport.id`, `product.modelName`, and `exercises[]` with `fatPercentage` / `carboPercentage` / `proteinPercentage`.

**Derived locally (no extra fetch):**
- **HR curve** → slice stored v3 continuous-HR to `startTime`→`stopTime`.
- **Time-in-zones** → bucket that slice against HR-zone boundaries. (Activity's `activityInfos[].activityClass` values — `ACTIVITY_CLASS_CONTINUOUS_MODERATE`, `_LIGHT`, etc. — provide day-level class buckets.)

> **Fidelity caveat:** reconstructed curves are 5-sec resolution (continuous-HR) vs. possibly 1-sec native in Flow. Invisible for strength/walks; revisit only if pixel-exact parity is ever wanted.

**Result:** workout sync is **one `training-sessions/list` call**; detail assembles from data already in the store. No two-step list-then-fetch.

---

## 9. Local storage (GRDB / SQLite)

**Choice: GRDB over SwiftData.** The data shape is time-series sample tables; GRDB/SQLite handles these better, and the NOOP precedent (offline WHOOP app, same architecture) validates it.

Indicative tables (columns refined against **live captures, 2026-06-28** — full
field-by-field mapping in [`API_RESPONSE_SHAPES.md`](API_RESPONSE_SHAPES.md)):
- `hr_minute` (date, minute_ts, min, avg, max) — downsampled continuous HR
- `activity_minute` (date, minute_ts, steps) — downsampled v3 step samples
- `activity_day` (date ← `start_time`, steps, calories, active_calories, active_dur, inactive_dur, daily_activity, distance, zones_json) — v3 computed totals + per-minute zone labels
- `sleep_night` (date, score, stages_json, hypnogram_json, hr_samples_json, continuity, continuity_class, charge, cycles, start_time, end_time) — `hypnogram`/`hr_samples` are `"HH:MM"`-keyed maps
- `recharge` (date, ans_charge **REAL/signed**, ans_charge_status INT, nightly_recharge_status INT, hr_avg, hrv_avg, breathing_avg, hrv_json, breathing_json) — sample maps are `"HH:MM"`-keyed
- `cardio_load` (date, strain, tolerance, ratio, cardio_load, status, level_json)
- `training_session` (id ← `identifier.id`, start, stop, sport_id ← **string**, calories, hr_avg, hr_max, benefit, recovery_ms ← **string**, duration_ms, distance_m, macros_json, note, trigger)
- `sport_ref` (id ← `id.id`, name) — cached catalog
- `device` (uuid, firmware, color, description, hardware_id, registered, settings_json) — joined from `devicesData` + `activeDevices`
- `sync_state` (domain, last_synced_at, last_window)

Raw sample arrays are downsampled on ingest; only minute-resolution rows persist.

---

## 10. Sync engine

- **Trigger:** manual refresh button (phase 1). Optional `BGAppRefreshTask` best-effort later.
- **Per-domain windows** from the config registry (e.g. continuous HR 30 d, sleep 90 d, sessions 90 d), each capped to the API max range.
- **Activity (v3):** fetch the computed daily summary (`activities/{date}`) and the sample/zone detail (`activities/samples/{date}`) per day across the window. No MET→calorie derivation and no `features` loop — v3 returns totals and `activity_zones` directly. Still per-day; downsample the step samples on ingest.
- **Sleep manifest:** optionally hit `sleep/available` first and fetch only nights that exist, instead of blindly requesting the full range.
- **Upsert/dedup** keyed on date or session id.
- **Token handling:** v3 bearer used directly (no refresh); v4 (training-sessions/devices/sports only) wrapped in the refresh-aware client (refresh on 401, retry once).

---

## 11. Known gaps & deferred

| Item | State | Plan |
|---|---|---|
| **SleepWise — alertness + circadian bedtime** | **Fully covered** via v3 `sleepwise/alertness/date` + `sleepwise/circadian-bedtime/date` (was wrongly assumed absent earlier) | Build it — see HERC-090/091/093. |
| **Biosensing (temp/SpO2)** | Exists in v3, but **Loop Gen 2 returns 204** — band has no such sensors | Parked. Not a gap, just not this hardware. |
| **Battery level** | Not in API by design | BLE SDK phase 2 (`FEATURE_BATTERY_INFO`). |
| **Live "right now" HR** | Not possible cloud-side | BLE SDK phase 2. |
| **PPI actual data** | Endpoint + format proven; only empty arrays seen; not on any screen | Deprioritized (it's the raw input to HRV you already get computed). |
| **Skin contact** | Endpoint works, empty, unused | Pin as possible wear-time signal via BLE later. |
| **Workout HR fidelity** | 5-sec reconstructed vs. possible 1-sec native | Note only; revisit if exact parity wanted. |
| **Routes (GPS)** | Untested; needs a `routeId` from favorites/targets (returned empty) | Revisit if/when outdoor GPS workouts exist. |

---

## 12. Phase 2 — Polar BLE SDK

- `github.com/polarofficial/polar-ble-sdk` — official, Swift, SPM (`~> 7.0.1`; 8.0.0 shipped May 2026), iOS 14+. **Explicitly supports Polar Loop.**
- Adds what the cloud cannot: **battery**, **live HR**, raw PPI/accelerometer, on-device offline recordings.
- **Cost:** RxSwift + Swift Protobuf, ReactiveX API — a different paradigm than the app's `async/await` core, so it carries reactive-bridging work. Scoped to phase 2 deliberately; the AccessLink dashboard must work first.
- Does **not** provide cloud-computed metrics (no recharge/sleep-stages/cardio-load) — complementary to AccessLink, not a replacement.

---

## 13. Identifiers (reference)

| Key | Value |
|---|---|
| v4 client_id | `ded3658e-53d1-478a-b957-9ffca6005c0e` |
| user id (`x_user_id`) | `64433870` |
| member-id | `yug-hercules-test` |
| redirect URIs | `hercules://oauth/callback` · `http://localhost:8000/callback` |
| Loop device UUID | `0e030000-0084-0000-0000-000012651a32` |
| Loop deviceId (short) | `12651A32` |
| firmware | `5.0.55` |
| registered | `2026-05-28` |

> **Never** store the client *secret* in source or docs. Keychain only.

---

## 14. Open authoring/build items

- Confirm sport id → name once against `sports/list` and seed `sport_ref`.
- Build v4 refresh-aware HTTP client first; it gates all v4 sync.
- Decide phase-2 trigger for BLE (on-demand connect vs. background) when that phase starts.
- SleepWise approach TBD by user.
