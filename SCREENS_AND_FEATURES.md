# Project Hercules — Screens & Features

A complete inventory of every screen and feature for the Polar Loop Gen 2 dashboard app, organized as a design brief. Each screen lists its purpose, the data it shows (all validated against live API data), the components it needs, and the states to design.

> **Design north star:** extremely modern, snappy, fluid, **animated**. Local-first means **data never shows a spinner** — screens open instantly from the local store; the only place loading is acceptable is the very first sync. Animation should feel earned (charts drawing in, rings filling, numbers counting up, smooth card→detail transitions), not decorative.

---

## App structure (navigation shell)

```
First run ─► Onboarding / Connect ─► Initial sync ─┐
                                                    ▼
                                         ┌──── Dashboard (home) ────┐
                                         │  metric cards, tappable   │
                                         └───────────┬───────────────┘
                                                     │ tap a card
                         ┌───────────────────────────┼───────────────────────────┐
                         ▼                            ▼                           ▼
                   Detail screens              Workouts (list)              Device / Settings
              (one per metric domain)               │                            │
                                                     ▼                            │
                                              Workout detail                      │
                                                                                  ▼
                                                                       (phase 2: Live HR, Battery)
```

Primary nav: **Dashboard** · **Workouts** · **Device** · **Settings** (tab bar or equivalent). Detail screens push from Dashboard cards.

---

## 1. Onboarding & connection

| Screen | Purpose | Key elements | States |
|---|---|---|---|
| **Welcome / intro** | First-run brand moment; set the tone (this is the "better than Polar Flow" promise) | App identity, one-line value prop, "Connect Polar" CTA | First launch only |
| **Connect Polar account** | OAuth consent for v3 + v4 (two realms), then user registration | Explanation of what's accessed, "Authorize" button → web auth, success confirmation | In-progress, success, auth-failed/retry |
| **Initial sync** | The one place progress is allowed — first historical pull (sleep, recharge, activity, HR, workouts, SleepWise) | Progress indication per domain, friendly "building your dashboard" framing | Syncing, partial-failure, done |

> After first run, the app **always** opens straight to the populated Dashboard. Auth/refresh happens silently.

---

## 2. Dashboard (home)

The hub. A scrollable set of metric **cards**, each a glanceable summary that taps through to its detail screen. This is the screen users see most — it carries the "snappy and alive" feeling.

**Cards (each tappable → detail):**
- **Today's Activity** — steps, calories, distance, active time, daily-activity %, intensity-zone glance
- **Sleep** — last night's score + duration + a mini hypnogram
- **Nightly Recharge** — ANS charge status + recovery indicator
- **Cardio Load** — status ("Maintaining" etc.) + strain/tolerance glance
- **Boost from Sleep** — today's Boost score + a mini hourly-boost strip
- **Continuous HR** — current/resting HR + a mini 24h curve
- **Latest Workout** — most recent session: sport, duration, calories, benefit
- **Device glance** (compact) — band name + battery (phase 2) + sync freshness

**Interactions:** pull-to-refresh = manual sync (the only network trigger). Tap card → detail. Optional card reordering.

**States:** fully populated (default) · first-run/empty per card · per-card no-data (e.g. no workout yet) · stale-data indicator (last synced X ago) · refreshing (subtle, non-blocking).

**Animation opportunities:** cards settling in on load, number count-ups, mini-charts drawing, refresh ripple, card→detail shared-element transition.

---

## 3. Detail screens (one per metric domain)

Each detail screen shares a pattern: **header** (metric name, date/range), **hero visualization**, **supporting stats**, **range switcher** (day / week / longer), and **info/explainer**. All read from the local store — range switches are instant, zero network.

### 3.1 Sleep detail
- **Shows:** hypnogram (wake/REM/light/deep across the night), stage totals & percentages, sleep score, continuity, sleep cycles, sleep charge, HR during sleep (curve), time in bed / asleep, sleep start–end.
- **Components:** hypnogram band (the signature sleep chart), stage-breakdown bars/legend, score ring, HR-during-sleep sparkline.
- **Range:** single night (default) + weekly comparison view (nights side by side).
- **States:** full night · no sleep recorded · partial night.

### 3.2 Nightly Recharge detail
- **Shows:** ANS charge value + status, nightly recharge status, HR/HRV/breathing-rate averages, 5-min HRV samples (curve), 5-min breathing samples (curve), beat-to-beat readout. Self-computed baselines for context.
- **Components:** recovery/ANS indicator (gauge or dial), HRV trend chart, breathing-rate chart, status pill.
- **Range:** single night + multi-day trend.
- **States:** measured · not measured (band off / short sleep).

### 3.3 Cardio Load detail
- **Shows:** strain (short-term load), tolerance (long-term load), load ratio, status ("Maintaining" / "Detraining" / "Productive" etc.), per-day load bars, 28-day trend.
- **Components:** dual-line trend chart (strain vs tolerance — the two crossing lines), per-day load bars, status banner with explanatory text.
- **Range:** weekly default + longer trend.
- **States:** enough data · "needs more training data" (sparse) state.

### 3.4 Continuous HR detail
- **Shows:** 24/7 HR curve, min / max / resting / average markers, current HR, time-of-day scrubbing, day-over-day.
- **Components:** full-day HR line chart with min/avg/max annotations, resting-HR callout, scrubber.
- **Range:** single day (default) + multi-day.
- **States:** full day · gaps (band off) · today (partial, live edge).

### 3.5 Daily Activity detail
- **Shows:** steps, calories (total + active), distance, active vs inactive duration, daily-activity score, inactivity-alert count, **intensity-zone breakdown** (time in each zone — the stacked bar), intraday step graph, daily goal progress.
- **Components:** stat tiles (steps/cal/distance/active-time), stacked intensity-zone bar, intraday step bar chart, goal ring, inactivity markers.
- **Range:** single day (default) + weekly totals.
- **States:** active day · low/no-activity day · today (partial).

### 3.6 Boost from Sleep (SleepWise) detail
- **Shows:** daily Boost score + classification (e.g. "Fair"), **hourly boost levels** across the day (the green bar strip — high/low/very-low/minimal), **sleep gate** (when the body wants to sleep) + **sleep window** (the markers), sleep-gate recognizability (1/3–3/3), sleep inertia, 28-day Boost trend, sleep block overlay.
- **Components:** hourly-boost bar strip (signature SleepWise viz), Boost score display, sleep-gate/window timeline markers, sleep-overlay band, trend chart for history.
- **Range:** day (default) + 28-day history.
- **States:** full forecast · still-calibrating (SleepWise needs 1–2 weeks) · no data.

> **Note:** feeling/notes/feedback that Polar Flow showed in a separate "calendar" view live on the **workout** in this app (see 4.2) — no separate journal screen needed.

---

## 4. Workouts

### 4.1 Workout list
- **Shows:** chronological session rows — sport (with icon/name), date/time, duration, calories, training benefit, an auto-detected badge where applicable.
- **Components:** workout row (sport icon + stats), section headers by date, sport-type theming.
- **Range:** infinite scroll back through history (backfillable).
- **Interactions:** tap row → workout detail. Optional filter by sport.
- **States:** has workouts · none yet · auto-detected vs manually started distinction.

### 4.2 Workout detail
- **Shows:** sport, start/stop, duration, calories, avg & max HR, training benefit, recovery time, **fuel macros** (fat / carb / protein %), note, start trigger (auto-detected vs manual), device. **Reconstructed:** HR curve over the session (sliced from continuous HR) and **time-in-HR-zones** bar.
- **Components:** session header, stat tiles, macro breakdown viz (fat/carb/protein), reconstructed HR curve, HR-zone distribution bar, benefit/recovery callouts.
- **States:** strength/indoor (no route) · (future) outdoor w/ route map · sparse HR.
- **Animation:** HR curve drawing in, zone bar filling, macro segments animating.

---

## 5. Device & Settings

### 5.1 Device screen
- **Shows:** band model (Polar Loop Gen 2), color, firmware version, registration date, device settings (e.g. automatic training detection on/off + sensitivity, handedness, language), **battery level (phase 2, BLE)**, connection status (phase 2).
- **Components:** device hero/illustration, settings list, battery indicator (phase 2), firmware/info rows.
- **States:** connected (phase 2) · cloud-info-only (phase 1, no battery) · syncing.

### 5.2 Settings
- **Shows:** account/connection status & re-auth, units (metric/imperial), data refresh controls, sync history / last-synced, about, sign-out/disconnect.
- **Components:** settings list, account section, sync-status row, destructive disconnect action.
- **States:** connected · token-expired/re-auth-needed · disconnected.

---

## 6. Phase 2 — Live (BLE SDK)

> Requires the band connected over Bluetooth. These are enhancements, not phase-1.

| Feature | Purpose | Elements |
|---|---|---|
| **Live HR** | Real-time pulse on the dashboard / a dedicated live view while connected | Animated live HR number + pulsing indicator, optional live mini-trace |
| **Battery level** | The one stat the cloud can't give — surface on device card & dashboard | Battery indicator, low-battery state |
| **Connection state** | Show band connected/disconnected, pairing flow | Connection status, pair/reconnect affordance |

---

## 7. Global states & cross-cutting patterns

Design these once; they apply everywhere.

- **Loading** — only on first sync or an explicit manual refresh. Data screens otherwise never block. Design a tasteful refresh affordance (pull-to-refresh + subtle in-progress), not full-screen spinners.
- **Empty / no-data** — per metric, before data exists or for days with no recording. Friendly, not error-like.
- **Stale data** — "last synced X ago" indicator; gentle nudge to refresh.
- **Error / offline** — refresh failed, token needs re-auth, no connection. Non-alarming, actionable.
- **Date scrubbing & range switching** — a consistent control for day/week/longer across all detail screens; instant (local).
- **Calibrating** — SleepWise (and cardio load early on) need warm-up time; design a "building up" state.
- **Sync feedback** — per-domain success/partial-failure surfaced cleanly.

---

## 8. Design-system component inventory

The reusable building blocks every screen composes from. **This is the most useful section for the design session** — nail these and the screens assemble from them.

**Charts / data viz**
- **HR curve** — full-day & per-workout line chart with min/avg/max/resting annotations
- **Hypnogram** — sleep-stage band (wake/REM/light/deep)
- **Stacked zone bar** — intensity zones (activity) & HR zones (workouts); time-in-zone distribution
- **Dual-line trend** — cardio load (strain vs tolerance, crossing lines)
- **Hourly boost strip** — SleepWise alertness bars (shade = level)
- **Sparkline / mini-chart** — for dashboard card glances
- **Sample-series charts** — HRV samples, breathing-rate samples (recharge)
- **Intraday bar chart** — step samples per minute/hour

**Indicators / gauges**
- **Score ring / gauge** — sleep score, Boost score, daily goal
- **Recovery / ANS indicator** — nightly recharge dial
- **Status pill** — "Maintaining", "Fair", recharge status, benefit (color-coded)
- **Battery indicator** (phase 2)
- **Live HR pulse** (phase 2)

**Stats / breakdowns**
- **Stat tile** — number + label + icon (steps, calories, distance, active time, HR avg/max…)
- **Macro breakdown** — fat / carb / protein split (workouts)
- **Stage breakdown** — sleep stage totals + percentages

**Navigation / structure**
- **Metric card** — dashboard summary tile (with mini-viz), tappable
- **Detail header** — metric name + date/range + back
- **Date scrubber / range toggle** — day/week/longer selector
- **Workout row** — sport icon + key stats
- **Section headers** — date grouping
- **Timeline markers** — sleep gate / sleep window on a 24h axis

**Sport theming**
- Sport icons + per-sport color/identity (driven by `sport_ref` id→name mapping)

---

## 9. Screen count summary

| Group | Screens |
|---|---|
| Onboarding & connection | 3 |
| Dashboard | 1 (with ~8 card types) |
| Metric detail screens | 6 (Sleep, Recharge, Cardio Load, Continuous HR, Activity, Boost from Sleep) |
| Workouts | 2 (list, detail) |
| Device & Settings | 2 |
| Phase 2 (live) | ~2–3 (Live HR, Battery, Connection) |
| Global states | designed as shared patterns, not standalone screens |

**~16 core screens** + a shared component system + phase-2 live views.

---

## Build-order suggestion (for reference)

Design and build can both start with **one vertical slice** to prove the pattern end-to-end before fanning out: pick **Cardio Load** or **Boost from Sleep** → its card → its detail → the components they need. Once that pipeline (data → store → card → detail → range switch, all animated and instant) feels right, the remaining screens reuse the same skeleton and component set.
