# PERT Daily Planner 📋⏱

A daily tracker / planner mobile app (Android, built with **Flutter**) where task
durations are never guessed by hand — they are **auto-calculated with PERT
three-point estimation**, and the whole day's timeline, countdowns and alarms
follow from that.

## Why PERT?

For every task you enter three estimates (in minutes):

| Input | Meaning |
|---|---|
| **O** — Optimistic | Best case, everything goes right |
| **M** — Most likely | Realistic estimate |
| **P** — Pessimistic | Worst case, everything goes wrong |

The app then applies the PERT formulas:

```
Expected time      TE = (O + 4M + P) / 6
Standard deviation σ  = (P − O) / 6
Variance           σ² = ((P − O) / 6)²
```

- **End time is auto-calculated:** `end = start + TE`. You never type an end time.
- **Chained timeline:** the tasks of a day form a chain — each task starts when
  the previous one's expected time ends. Along a chain, expected times **and
  variances add** (standard PERT chain rule), so the day summary shows an
  expected finish time plus a **95% confidence window (±2σ)**.
- **Subtasks:** break a big task into subtasks; the parent's duration becomes
  the **sum of its subtasks' TE values** (and the sum of their variances) —
  exactly how PERT rolls up a network path.

## Features

- ✅ Quick **create / edit / delete** of tasks and subtasks (actions, appointments,
  small and large tasks) with live PERT calculation shown while you type.
- ⏳ **Live countdown labels** on every task: *Starts in…*, *time left* while
  running, *over by…* when the expected time has elapsed.
- 🔔 **Alarm reminders at start and end times**, scheduled through Android's
  `AlarmManager` (exact alarms). The OS wakes the phone at the right moment —
  the app keeps **no background service running, so battery drain is minimal**.
  Alarms survive reboots (boot receiver re-registers them).
- ↕️ **Drag a task down to postpone it** within the day — the entire timeline
  re-chains automatically from the PERT durations (start/end of every following
  task shifts). One-off tasks can also be pushed to tomorrow from the menu.
- 🔁 **Repeating tasks** — daily, weekly (pick weekdays) or monthly — placed on
  the calendar automatically.
- 🔥 **Streaks** for repeating habits: current streak, best streak and a
  last-7-days dot row.
- 📅 **Calendar views**: month / 2-week / week grid with task markers, plus the
  daily timeline view.
- 🎉 Day summary bar: total remaining expected work, projected finish time and
  the 95% (±2σ) window.

## Project layout

```
pert_daily_planner/
├── lib/
│   ├── main.dart                    # App shell: Today / Calendar / Streaks tabs
│   ├── models/task.dart             # PertTask + PERT formulas + recurrence
│   ├── providers/task_provider.dart # CRUD, timeline re-flow, streaks, alarm scheduling
│   ├── services/db.dart             # SQLite persistence (sqflite)
│   ├── services/notification_service.dart # Exact-alarm notifications
│   ├── screens/                     # Today, Calendar, Streaks, Task editor
│   ├── widgets/task_card.dart       # Task row with countdown + PERT chips
│   └── util/fmt.dart                # Time/duration formatting
├── android_config/                  # Manifest + Gradle overrides applied in CI
└── pubspec.yaml
```

The `android/` folder is intentionally **not** committed: the CI workflow
generates it from the pinned Flutter 3.24.5 template and overlays
`android_config/` (alarm permissions, boot receiver, core-library desugaring).
This keeps the repo clean and the build reproducible.

## Download the APK 📲

Every push that touches `pert_daily_planner/` triggers the
**Build APK** GitHub Actions workflow:

1. Open the repo's **Actions** tab → latest **Build APK** run.
2. Download the **PERT-Daily-Planner-APK** artifact (a zip containing
   `PERT-Daily-Planner.apk`).
3. Copy the APK to your phone and open it. Allow *Install from unknown
   sources* when prompted.
4. On first launch, grant the **notifications** and **alarms & reminders**
   permissions so start/end alarms can fire exactly on time.

You can also trigger a build manually: Actions → Build APK → *Run workflow*.

> The APK is signed with debug keys — perfect for personal installation.
> Generate a release keystore before publishing to the Play Store.

## Build locally (optional)

```bash
cd pert_daily_planner
flutter create --platforms=android --org com.vsreeni --project-name pert_daily_planner .
cp android_config/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
cp android_config/app_build.gradle android/app/build.gradle
flutter pub get
flutter run          # or: flutter build apk --release
```

## Moving this app to its own repository

This folder is fully self-contained. To give the app its own repo:

1. On GitHub click **New repository** → name it (e.g. `pert-daily-planner`),
   set it **Public**, tick *Add a README* → **Create**.
2. Locally:
   ```bash
   git clone https://github.com/<you>/pert-daily-planner
   cp -r Ramesh-Krishnaiyer-Consultancy/pert_daily_planner/* pert-daily-planner/
   mkdir -p pert-daily-planner/.github/workflows
   cp Ramesh-Krishnaiyer-Consultancy/.github/workflows/build-apk.yml \
      pert-daily-planner/.github/workflows/
   cd pert-daily-planner && git add -A && git commit -m "Import PERT Daily Planner" && git push
   ```
3. In the copied workflow, change the two `pert_daily_planner/**` path filters
   and directories if you put the app at the repo root.

## Roadmap ideas

- Per-task actual-vs-expected history to refine your estimating skill
- Critical-path highlighting across a day's chain
- iOS build target (the Dart code is already cross-platform)
- Cloud sync / backup
