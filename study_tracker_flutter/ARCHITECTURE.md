# StudyTracker Flutter — Architecture Overview

## Folder structure

```
study_tracker_flutter/
├── pubspec.yaml                   ← Dependencies (Riverpod, Drift, go_router, fl_chart…)
├── analysis_options.yaml          ← Strict Dart linting
├── assets/
│   └── backgrounds/               ← Session timer background images
│       └── README.txt             ← Copy city_twilight.jpg / cozy_cafe.jpg here
└── lib/
    ├── main.dart                  ← Entry point — ProviderScope mount
    ├── app/
    │   ├── app.dart               ← Root MaterialApp.router + theme wiring
    │   ├── router.dart            ← GoRouter with ShellRoute + 5 named routes
    │   ├── shell/
    │   │   ├── app_shell.dart     ← Responsive shell: bottom nav / rail / sidebar
    │   │   └── responsive.dart    ← Breakpoint helpers (compact/medium/expanded/large)
    │   └── theme/
    │       ├── app_colors.dart    ← Ink / Moss / Sand / Mist color tokens
    │       ├── app_text_styles.dart ← Inter-based typography scale
    │       ├── app_spacing.dart   ← Spacing + radius constants
    │       ├── app_shadows.dart   ← Soft/card/subtle shadow tokens
    │       └── app_theme.dart     ← Builds MaterialTheme (light + dark)
    ├── domain/
    │   ├── enums.dart             ← StudySessionMode, AppThemeMode, AiChallenge*
    │   ├── entities.dart          ← Domain entities (StudySession, Subject, Goal…)
    │   └── domain.dart            ← Barrel export
    ├── data/
    │   ├── db/
    │   │   ├── tables.dart        ← Drift table definitions (exact port of schema.ts)
    │   │   ├── database.dart      ← AppDatabase + migration strategy
    │   │   └── database_provider.dart ← Riverpod singleton provider
    │   └── repositories/
    │       ├── session_repository.dart  ← CRUD + filter + summary for study_sessions
    │       ├── settings_repository.dart ← Key-value + batch + structured settings
    │       └── subject_repository.dart  ← Subjects + groups CRUD
    ├── core/
    │   ├── utils/
    │   │   ├── utils.dart          ← Date, streak, format utils (port of .ts utils)
    │   │   └── analytics_utils.dart ← Daily/weekly/hourly/subject/mood analytics
    │   ├── providers/
    │   │   ├── settings_provider.dart ← AsyncNotifier for StructuredSettings
    │   │   ├── session_provider.dart  ← FutureProviders for sessions/summary/recents
    │   │   └── timer_provider.dart    ← StateNotifier for timer + stopwatch
    │   └── widgets/
    │       ├── study_card.dart     ← StudyCard, StatCard, SectionHeader, EmptyState,
    │       │                          ModeBadge, StudyProgressBar, ScreenWrapper
    │       ├── activity_heatmap.dart ← 52-week calendar heatmap
    │       └── progress_ring.dart  ← Circular progress ring (CustomPainter)
    └── features/
        ├── dashboard/presentation/dashboard_screen.dart
        ├── sessions/presentation/sessions_screen.dart
        ├── analytics/presentation/analytics_screen.dart
        ├── achievements/presentation/achievements_screen.dart
        └── settings/presentation/settings_screen.dart
```

## Responsive layout

| Width       | Shell layout        | Content          |
|-------------|---------------------|------------------|
| < 600 px    | Bottom nav bar      | 1-column         |
| 600–899 px  | Navigation rail     | 2-column grids   |
| 900–1199 px | Full sidebar        | 2–3 col grids    |
| 1200 px+    | Wide sidebar        | 3–4 col grids    |

## State management

- **Riverpod AsyncNotifier** → settingsProvider (loads + persists StructuredSettings)
- **Riverpod FutureProvider** → allSessionsProvider, sessionSummaryProvider, recentSessionsProvider
- **Riverpod StateNotifier** → timerProvider, stopwatchProvider

## Database

- **Drift** (SQLite) compiles `tables.dart` into raw SQLite via code generation.
- Run `dart run build_runner build` to generate `database.g.dart` after Flutter SDK is installed.
- Single DB file at `{documentsDir}/study_tracker.sqlite`.

## Getting started

1. Install Flutter SDK ≥ 3.16 (https://flutter.dev/docs/get-started)
2. Add Flutter to PATH
3. From `study_tracker_flutter/`:
   ```bash
   flutter pub get
   dart run build_runner build --delete-conflicting-outputs
   flutter run
   ```
4. Copy background images from `../public/backgrounds/` to `assets/backgrounds/`

## Color palette (from Tauri app)

| Token        | Hex       | Usage                    |
|--------------|-----------|--------------------------|
| ink900       | #1C241D   | Primary text             |
| ink500       | #6C766D   | Secondary text           |
| ink200       | #DBE2DC   | Borders                  |
| moss500      | #7CAB84   | Accent (primary green)   |
| moss600      | #63946D   | Accent dark              |
| moss100      | #E5F2E6   | Accent light bg          |
| sand         | #F7F5EF   | Surface variant          |
| mist         | #FBFBF8   | App background           |
