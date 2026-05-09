---
trigger: always_on
---

Your Situation Summary
Desktop App (Tauri + Svelte) ← source of truth for logic
└── study_tracker_flutter/   ← Flutter app, broken UI + mismatched logic
    └── lib/
        ├── app/             ✅ Good structure exists
        ├── core/            ✅ 
        ├── data/            ✅ DB + repos exist
        ├── domain/          ✅ entities/enums exist
        └── features/        ⚠️ 5 screens, all broken

Svelte UI wrapped in Tauri. The entry flow is simple: main.ts mounts the app, App.svelte initializes the SQLite database and settings, then renders one of the main feature screens through a custom route store in router.ts. **How The App Is Organized** The project is split into three main layers. - features contains the page-level screens. - Dashboard.svelte is the landing overview with stats, streaks, heatmap, and quick actions. - Sessions.svelte is the session workspace with timer, stopwatch, history, and manual logging. - Analytics.svelte builds chart-based reports from stored study data. - Settings.svelte manages profile, goals, appearance, exports, subjects, groups, and AI challenge settings. - Achievements.svelte shows badge progress and AI-generated challenges. - core holds the app logic and data layer. - domain.ts defines the shared types for sessions, subjects, goals, settings, achievements, and filters. - data contains persistence setup and schema migration logic. - database.ts opens the Tauri SQL database and applies migrations. - schema.ts defines the local SQLite tables for sessions, settings, goals, moods, subject groups, and AI challenges. - repositories exposes CRUD functions grouped by entity, with index.ts as the barrel export. - services contains business logic wrappers around repositories, such as sessionService.ts and settingsService.ts. - stores holds Svelte stores for route state, settings, timers, stopwatch, toast notifications, and media playback. - utils contains date, formatting, analytics, streak, and portal helpers. - components contains reusable UI building blocks. - Button.svelte, Card.svelte, Input.svelte, and Select.svelte are the basic form and layout primitives. - Sidebar.svelte, Toast.svelte, Modal.svelte, and MediaPlayer.svelte provide cross-app shell behavior. - Heatmap.svelte, ProgressRing.svelte, StatCard.svelte, EmptyState.svelte, and SessionBackground.svelte support the dashboard and session visuals. **What Else Matters** The desktop shell is in src-tauri, while backgrounds holds the background images used by the session UI. The presence of paired .ts and .js files in src suggests the codebase still carries compiled or transitional duplicates, but the active app wiring is clearly the TypeScript/Svelte side. If you want, I can next turn this into a visual folder-by-folder architecture map or a data-flow walkthrough from “start session” to SQLite persistence.



"Before writing any logic in the flutter Application, read the equivalent desktop file first"

BEFORE WRITRITNG ANY FEATURE TELL USER FIRST TO PASTE THE REFERECNCE DESIGN SCREENS FOR YOU AS IMAGES

TASK: Build [ScreenName]

1. READ desktop logic from: ./src/[equivalent_file]
2. READ design reference: PROMPT USER FOR IMAGES FIRST + EQUAVALENT CODE IN HTML CSS JS TO TRASNFORM INTO FLUTTER ND DART
3. USE ONLY components from SHARED UI COMPOENENT LIBRARY YOU MUST CREATE
4. Handle: portrait mobile, landscape mobile, portrait tablet, landscape tablet
5. Do NOT invent logic and copy it from the desktop source

First, we build a Design System / Widget Wrappers file once
This is the fast-paced development enabler you mentioned. Things like:

AppCard, AppBadge, AppProgressBar, AppButton, SectionHeader, StatCard
Color tokens, typography scale, spacing constants
Responsive helpers (mobile portrait/landscape, tablet portrait/landscape)
AdaptiveScaffold wrapper that handles layout switching automatically

This takes ~1 session, then every screen after is 3x faster.

Folder structure I'd recommend
lib/
├── core/
│   ├── theme/         # colors, typography, spacing
│   ├── widgets/       # all reusable wrappers
│   └── utils/         # responsive helpers
├── features/
│   ├── sessions/
│   ├── analytics/
│   ├── achievements/
│   ├── settings/
│   └── dashboard/
└── main.dart
Each feature folder gets: screen.dart, widgets/, logic/ (provider/bloc/whatever you use)

The order I recommend tackling screens:

Design system wrappers (foundation)
Sessions screen (most complex — Timer/Stopwatch/History + media player)
Dashboard
Analytics
Achievements + Badge Catalog + AI Challenges
Settings


① Read desktop source logic → ② Write/fix Flutter logic → ③ Apply new UI design


Layer 3 — Fix responsive.dart
Single source of truth:
dartclass R {
  static bool isTablet(context) => ...
  static bool isLandscape(context) => ...
  static bool isPhone(context) => ...
  static double get cardPadding => ...
}
Layer 4 — AppState audit
Verify these providers actually match desktop logic:

timer_provider.dart ← compare with Svelte timer store
session_provider.dart ← compare with Svelte session store
settings_provider.dart ← compare with Svelte settings store
Handle 3 layouts: phone portrait, phone landscape, tablet.

- ALWAYS clean old files of each feature on each iteration. Remove legacy duplicate files in the feature directory after porting the feature.
