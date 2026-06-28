# API Response → Schema Map (Epic 2/3 → Epic 4)

Maps each Polar AccessLink response (Epic 2/3 clients) to its target GRDB table
(Epic 4, HERC-040). **All shapes verified against live captures on 2026-06-28**
(Polar Loop Gen 2) — every model decodes the real payload (11/11). Target columns
are from `ARCHITECTURE.md` §9; the wire shapes are the actual captured structure.

**Legend:** ✅ verified against live capture.

> Cross-cutting facts confirmed during capture:
> - **Timestamps come in 5 formats** — zoned-offset (`...+05:30`), zoned-`Z`,
>   naive-seconds (`2026-05-29T18:07:39`), naive-minute (`2026-06-21T00:00`), and
>   **time-only** (`00:25:21`, continuous HR). `PolarDateParser` handles all five.
> - **Sample series are JSON objects keyed by `"HH:MM"`** (hypnogram, sleep HR, HRV,
>   breathing), not arrays. Continuous-HR and activity steps/zones are arrays of
>   `{timestamp,value}`.
> - Several numbers arrive **stringified** (`sport.id`, `recoveryTimeMillis`) or
>   **signed-fractional** (`ans_charge = -1.5`).

---

## v3 — Epic 2

### 1. `GET /v3/users/sleep` → table `sleep_night` ✅
- **Model:** `SleepNight` · envelope `{ nights: [...] }`
- **Wire shape (per night):** `date`, `hypnogram` **`{"HH:MM": stage}`**, `heart_rate_samples` **`{"HH:MM": hr}`**, flat `light_sleep`/`deep_sleep`/`rem_sleep`/`total_interruption_duration` (seconds), `sleep_score`, `sleep_charge`, `sleep_cycles`, `continuity` (Double), `continuity_class` (Int), `sleep_start_time`/`sleep_end_time` (zoned-offset).
- **Columns:** `date` PK · `score` ← `sleep_score` · `hypnogram_json` ← hypnogram map · `hr_samples_json` ← heart_rate_samples map · `stages_json` ← {light,deep,rem,interruption} · `continuity`, `continuity_class`, `charge`, `cycles`, `start_time`, `end_time`.
- **Note:** hypnogram/HR are time-keyed maps — store as JSON, not normalized rows.

### 2. `GET /v3/users/sleep/available` → (sync planning, no table) ✅
- **Model:** `SleepAvailability` · envelope `{ available: [...] }`
- **Wire shape:** `date`, `start_time`, `end_time` (zoned). Feeds Epic 5 night-skipping.

### 3. `GET /v3/users/nightly-recharge` → table `recharge` ✅
- **Model:** `NightlyRecharge` · envelope `{ recharges: [...] }`
- **Wire shape:** `date`, **`ans_charge` (Double, signed e.g. `-1.5`)**, `ans_charge_status` (Int), `nightly_recharge_status` (Int), `heart_rate_avg`, `heart_rate_variability_avg`, `breathing_rate_avg`, `beat_to_beat_avg`, `hrv_samples` **`{"HH:MM": n}`**, `breathing_samples` **`{"HH:MM": n}`**.
- **Columns:** `date` PK · `ans_charge` REAL · `ans_charge_status`, `nightly_recharge_status` INT · avg columns · `hrv_json`, `breathing_json` ← the time-keyed maps.

### 4. `GET /v3/users/cardio-load` → table `cardio_load` ✅
- **Model:** `CardioLoad` · **top-level array** (28 days), no envelope
- **Wire shape:** `date`, `strain`, `tolerance`, `cardio_load_ratio`, `cardio_load` (value), `cardio_load_status` (`MAINTAINING`/`PRODUCTIVE`/…), `cardio_load_level{very_low,low,medium,high,very_high}`.
- **Columns:** `date` PK · `strain`, `tolerance`, `ratio` ← `cardio_load_ratio` · `cardio_load` · `status` · `level_json` ← `cardio_load_level`.

### 5. `GET /v3/users/continuous-heart-rate?from=&to=` → table `hr_minute` ✅
- **Model:** envelope `{ heart_rates: [{ date, heart_rate_samples: [{ heart_rate, sample_time:"HH:mm:ss" }] }] }` → client pairs `date`+`sample_time` → `Downsampler` → `HeartRateMinute`.
- **Verified:** 3 days / 24 980 raw samples → **985 minute buckets** (min/avg/max).
- **Columns:** `date`, `minute_ts` (PK with date), `min`, `avg`, `max`. Raw never persisted.

### 6. `GET /v3/users/activities?from=&to=` and `/activities/{date}` → table `activity_day` ✅
- **Model:** `ActivityDay` · range = **top-level array**; single = bare object
- **Wire shape:** **no `date`** — `start_time`/`end_time` (naive-minute; date derived from `start_time`), `steps`, `calories`, `active_calories`, `active_duration`/`inactive_duration` (ISO-8601 dur → seconds), `daily_activity`, `distance_from_steps`, `inactivity_alert_count`.
- **Columns:** `date` PK (from start_time) · `steps`, `calories`, `active_calories`, `active_dur`, `inactive_dur`, `daily_activity`, `distance`, `inactivity_alerts` · `zones_json` (from §7).

### 7. `GET /v3/users/activities/samples/{date}` → table `activity_minute` (+ `activity_day.zones_json`) ✅
- **Model:** `ActivitySamples` — `steps.samples[]{steps,timestamp}` → `Downsampler` → `StepMinute`; `activity_zones.samples[]{timestamp,zone}` → `ActivityZoneSample`; `inactivity_stamps.samples[]{stamp}`.
- **Verified:** 148 step minutes (total 6488), 154 zone samples, 1 stamp.
- **Zone labels:** `SEDENTARY`, `SLEEP`, `LIGHT`, `MODERATE`, `VIGOROUS`, `NON_WEAR`.
- **Columns:** `activity_minute`(`date`, `minute_ts`, `steps`); zones → `activity_day.zones_json` (per-minute label series); stamps → optional `inactivity_json`.

---

## v4 — Epic 3

### 8. `GET /v4/data/training-sessions/list?from=&to=` → table `training_session` ✅
- **Model:** `TrainingSession` · envelope `{ trainingSessions: [...] }` · naive-datetime window, **no `features`**
- **Wire shape:** `identifier.id` (uuid string) → `id`; `startTime`/`stopTime` (naive-seconds); **`sport.id` is a STRING** (`"15"`) → Int; `calories`, `hrAvg`, `hrMax`, `trainingBenefit`, **`recoveryTimeMillis` is a STRING** → Int, `durationMillis`, `distanceMeters`, `deviceId`, `note`, `startTrigger` (`TRAINING_START_AUTOMATIC_TRAINING_DETECTION` = auto), `exercises[]{fat/carbo/proteinPercentage, calories, durationMillis}`.
- **Verified:** 97 sessions; s0 sport=15, recovery=32060568, auto-detected=true.
- **Columns:** `id` PK · `start`, `stop`, `sport_id`, `calories`, `hr_avg`, `hr_max`, `benefit`, `recovery_ms`, `duration_ms`, `distance_m`, `note`, `trigger`, `macros_json` ← exercises.

### 9. `GET /v4/data/sports/list` → table `sport_ref` ✅
- **Model:** `Sport` · **top-level array**
- **Wire shape:** `id.id` (Int), `name` (`"RUNNING"`), `localizedNames.{lang}.longName` (ignored).
- **Verified:** 175 sports; RUNNING = id 1.
- **Columns:** `id` PK ← `id.id` · `name`.

### 10. `GET /v4/data/user-devices` → table `device` ✅
- **Model:** `Device` — joins `devicesData[]` (firmware/color/hardware) with `userDevicesData.activeDevices[]` (registered + `deviceSettings[]{name,value}`) by `deviceReference.uuid`.
- **Wire shape:** firmware `firmwareVersion`, color `productVariant.productColor`, desc `productVariant.productDescription`, `registered` (zoned-Z), `automaticTrainingDetection` ← settings name/value (`"ON"`→true). **No battery field** (expected, BLE phase 2).
- **Verified:** 1 device; fw 5.0.55, Black, auto-train true.
- **Columns:** `uuid` PK · `firmware`, `color`, `description`, `hardware_id`, `registered`, `settings_json`.
