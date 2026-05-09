---
trigger: always_on
---

---
description: Describe when these instructions should be loaded by the agent based on task context
# applyTo: 'D:/bassem/_2Aesthetic Tracking App/*'
---

<!-- Tip: Use /create-instructions in chat to generate content with agent assistance -->
# StudyTracker — Project Instructions for the AI Developer

Build a **local-first**, **offline**, **personal study tracking desktop app for Windows 10** with a **very aesthetic, soft, minimal interface** inspired by the attached design: light backgrounds, gentle green accents, rounded cards, subtle borders, soft shadows, and spacious layouts.

This is **for one user only**. Do **not** implement email, social, public profiles, groups, invitations, leaderboards, cloud sync, or server dependencies.

---

## 1) Product goal

Create a polished desktop application that helps one person track study sessions, analyze habits, and stay consistent.

The app must feel:

* calm
* premium
* lightweight
* visually refined
* fast to open
* easy to use daily

The app is not a web app wrapper with random pages. It must feel like a real desktop productivity product.

---

## 2) Scope

### Keep

* Dashboard
* Sessions
* Analytics
* Account / Settings
* Achievements

### Remove

* Email delivery
* Social/community features
* Groups
* Public profile
* Invite codes
* Leaderboards
* Messages/inbox
* Any online authentication
* Any backend server
* Any external account dependency

### Local-only features

* local database
* local file export
* local settings
* local theme persistence
* local timer state
* local analytics calculations

---

## 3) Recommended tech stack

Use a lightweight desktop stack:

* **Tauri**
* **Svelte** or **SolidJS**
* **TypeScript**
* **TailwindCSS**
* **SQLite** for local storage
* **Charting library** for analytics graphs
* **Lucide icons** or similar minimal icon set

Prefer Tauri because it keeps the app small and fast while still allowing a modern UI.

---

## 4) Architecture rules

Use a **modular monolith** with clean boundaries.

### Suggested structure

* `app-shell` → window layout, navigation, theming
* `features/dashboard` → stats cards, heatmap, quick actions
* `features/sessions` → timer, manual session entry, history
* `features/analytics` → charts, breakdowns, trends
* `features/achievements` → badges and unlock logic
* `features/settings` → goals, theme, language, timer settings
* `core/domain` → business rules, types, validation
* `core/data` → SQLite access, repositories, migrations
* `core/utils` → date helpers, formatting, calculations
* `ui/components` → reusable cards, buttons, inputs, tabs, modals

### Hard rules

* UI must not contain business logic.
* Business logic must not depend on UI components.
* Data access must go through repositories/services.
* Calculations like streaks, total time, weekly summaries, and charts must be pure functions where possible.

---

## 5) Data model

Store everything locally in SQLite.

### Main entities

* `study_sessions`
* `session_tasks`
* `subjects`
* `goals`
* `daily_settings`
* `achievements`
* `app_settings`
* `mood_logs`

### Session fields

* id
* date/time start
* date/time end
* duration
* subject
* topic
* chapter/unit tag
* tasks completed
* mood
* notes
* mode (`pomodoro`, `long_session`, `manual`)
* break schedule data if applicable

### Settings fields

* daily study goal
* focus duration
* break duration
* theme mode
* accent style
* language
* default session mode

---

## 6) App pages and responsibilities

### Dashboard

The home screen must show:

* today / week / streak stat cards
* recent sessions
* activity heatmap for 365 days
* quick actions
* upcoming exams or deadlines
* daily progress ring or bar
* current streak highlight

Keep the dashboard clean. Do not overcrowd it.

### Sessions

This is the core of the app.

Must support:

* start now timer
* manual log entry
* pomodoro cycles
* long-session mode
* subject/topic selection
* task list per session
* mood logging
* notes field
* session history
* filters and search

### Analytics

Must show:

* daily study time
* 7 / 14 / 30 day charts
* weekly trend
* subject breakdown
* peak study hours
* mood trend
* study vs break ratio
* rolling averages
* export summary

### Account / Settings

Must include:

* name
* username or display label
* daily goal
* focus/break duration sliders
* theme toggle
* language toggle
* backup/export options
* delete all data option with confirmation

### Achievements

Local gamification only.

Show badges such as:

* first session
* first hour
* first week streak
* consistent habit
* milestone hours
* milestone sessions

Unlock logic must be deterministic and stored locally.

---

## 7) Aesthetic direction

Match the attached look and feel as closely as practical.

### Visual language

* off-white or very light gray background
* soft green accent color
* rounded large cards
* thin light borders
* subtle shadows
* low contrast, calm palette
* gentle spacing
* generous empty space
* minimal icons
* clean typography
* visually calm dashboard cards

### UI style rules

* no harsh neon colors
* no heavy gradients
* no cluttered chrome
* no dense tables unless necessary
* no busy background patterns
* use soft surfaces and clear hierarchy

### Layout rules

* use card-based layout
* keep primary content centered and readable
* prefer spacious grids
* keep sidebar narrow and clean
* use sticky navigation only when useful
* make the app feel like a premium productivity tool, not an admin panel

### Motion rules

* transitions should be subtle
* animate card hover, page switch, and modal open/close lightly
* avoid flashy motion
* keep interactions fast and understated

---

## 8) Design system rules

Create a reusable design system before building features.

### Tokens

Define:

* background colors
* surface colors
* border colors
* accent colors
* success / warning / danger colors
* spacing scale
* radius scale
* shadow scale
* typography scale

ALL AS SEMANTIC TOKENS, NOT HARD-CODED VALUES.

### Components to build first

* button
* input
* select
* card
* stat card
* tab bar
* sidebar item
* modal
* toast
* dropdown menu
* empty state
* progress indicator
* chart wrapper

All pages must reuse these components.

---

## 9) Best practices for implementation

### Code quality

* use TypeScript strictly
* keep functions small and named clearly
* avoid duplication
* write reusable utilities for time, streaks, formatting, and chart data
* keep state predictable
* validate all inputs

### State management

* use local app state for UI
* use a store for shared app state
* persist only necessary settings
* derive analytics from stored session data rather than duplicating calculations

### Performance

* lazy load heavy pages if needed
* avoid unnecessary re-renders
* keep charts isolated
* cache derived analytics results when appropriate
* do not put huge arrays directly into component state if avoidable

---

## 10) AI agent workflow instructions

The AI agent must act like a careful senior engineer.

### Before coding

1. Read the current module structure.
2. Identify the affected files.
3. State the exact goal of the change.
4. List likely side effects.
5. Decide whether domain logic, UI, database, or settings are affected.

### During coding

* make the smallest correct change
* preserve existing patterns
* do not break unrelated features
* keep visual consistency
* update types, schema, and UI together when needed

### After each edit

Run checks in this order:

1. Type check
2. Lint
3. Build
4. Run unit tests if present
5. Verify UI state and routing
6. Verify no broken imports
7. Verify no console errors in the affected feature
8. Verify database migrations if schema changed
9. Verify theme and layout still match design system

If one check fails, fix it before continuing.

---

## 11) Error-prevention rules

The agent must check for:

* broken imports
* type mismatches
* missing props
* invalid date calculations
* timezone mistakes
* incorrect streak logic
* duplicate sessions
* invalid timer states
* layout overflow on Windows window sizes
* broken chart data
* empty-state crashes
* incorrect export format
* stale state after edits

Any feature touching session time, streaks, or analytics must be tested with edge cases:

* same-day sessions
* sessions spanning midnight
* zero-duration input
* manual edits
* deleted sessions
* missed days
* future-dated entries

---

## 12) Session logic rules

### Timer modes

* `Start now`: live timing
* `Manual log`: backfill past study time
* `Pomodoro`: focus/break cycle
* `Long session`: sustained work with optional breaks

### Session validation

* duration must be positive
* start time must not be invalid
* break logic must not corrupt total focus time
* manual entries must not overwrite active timers silently

### Streak logic

Define streaks clearly:

* study day counts if total study minutes meets a minimum threshold
* missed days reset streak unless a grace rule exists
* streak calculations must be deterministic

---

## 13) Analytics rules

Analytics must be computed locally from session data.

Generate:

* daily totals
* weekly totals
* rolling averages
* subject share
* mood distribution
* peak hours
* session count trend
* break ratio

Charts must be readable, minimal, and not overloaded.

---

## 14) Export rules

Support local export only:

* CSV
* JSON
* PDF if practical
* image export for charts if practical

Export must be one-click, reliable, and clearly labeled.

---

## 15) Deliverable quality bar

The app is only acceptable when it has:

* polished layout
* consistent spacing and typography
* no broken states
* smooth navigation
* clean local persistence
* stable timer behavior
* visually pleasing dashboard
* analytics that are actually useful
* no social/email/network clutter

---

## 16) Build order

Build in this order:

1. app shell
2. design system
3. local database and repositories
4. session creation and timer
5. session history
6. dashboard stats
7. analytics charts
8. settings
9. achievements
10. export
11. visual polish
12. final hardening and bug fixing

---

## 17) Final product definition

The final app should feel like:

* a calm personal productivity studio
* a clean study companion
* a premium desktop dashboard
* a lightweight local tool
* a visually refined app with soft green styling

Not a social network. Not a cloud SaaS. Not a general-purpose admin panel.

---

I can turn this into a tighter **AI-agent prompt**, a **folder structure**, or a **full PRD/spec** for the first build phase.


---
name: studytracker
description: "Use when building or modifying the StudyTracker desktop app: Tauri + Svelte + TypeScript + TailwindCSS, local-first SQLite persistence, session timer logic, analytics, settings, achievements, export flows, build verification, or repository/service work."
tools: [read, search, edit, execute, todo, agent]
user-invocable: true
---

# StudyTracker Agent

You are a careful senior engineer working on StudyTracker, a local-first, offline, single-user desktop app for Windows 10.

Your job is to keep the app fully functional at every stage. Do not leave TODOs, placeholders, mock-only screens, dead buttons, or incomplete flows in shipped code.

## Scope

- App shell, routing, theming, and navigation
- Feature modules under `features/*`
- Reusable UI primitives under `ui/components`
- Domain types and business rules under `core/domain`
- Services under `core/services`
- SQLite bootstrap, migrations, and repositories under `core/data`
- Study sessions, analytics, achievements, settings, and export flows

## Rules

- Preserve the calm, light, green-accent, desktop-first aesthetic.
- Keep UI, services, repositories, and domain logic separated.
- Keep all SQL parameterized and all DB rows typed.
- Keep timestamps ISO-compatible and booleans normalized for SQLite.
- Do not add cloud, email, social, auth, or server dependencies.
- Do not ship placeholder screens, fake buttons, or dead-end na