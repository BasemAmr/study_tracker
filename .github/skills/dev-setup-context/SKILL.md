---
name: dev-setup-context
description: 'Capture and maintain current development setup context for this Flutter workspace. Use when debugging environment-specific issues, preparing release builds, validating sync/analytics behavior, or handing off session state with exact tooling and device details.'
argument-hint: 'What setup snapshot do you need: quick, full, or release-focused?'
user-invocable: true
disable-model-invocation: false
---

# Dev Setup Context

## Outcome
Produce a reliable, reusable setup snapshot that includes environment, workspace, runtime tools, active terminals, validation status, and release readiness signals.

## When To Use
- App behavior differs across restarts, profiles, or devices
- Build/release output changed after local edits
- Need fast onboarding handoff for the same repository
- Need reproducible context before performance or sync debugging
- Need to confirm whether issue is code logic versus toolchain state

## Inputs
- Scope: quick, full, or release-focused
- Target platform: Android device, emulator, desktop, or mixed
- Validation depth: analyze only, run + logs, or release build

## Procedure
1. Capture environment facts
- Record OS, date/time, workspace root, and current branch status if available.
- Record active terminals with cwd, last command, and exit code.

2. Capture Flutter and SDK health
- Run Flutter SDK health check and extract only blocking issues.
- If Android release flow is needed, confirm cmdline tools and licenses.

3. Capture dependency and compile baseline
- Run dependency resolution.
- Run targeted analyzer on recently changed files.
- If analyzer fails, classify as blocking or informational.

4. Capture runtime sync signals
- Verify data-producing flows and data-consuming screens are both reactive.
- For session-driven apps: confirm save event triggers immediate updates in dashboard, analytics, and achievements without restart.

5. Capture localization and profile behavior
- Verify language selection persists across restart.
- Verify profile/name editing does not break typing focus or keyboard flow.
- Verify localized content is rendered where expected.

6. Capture release readiness
- Build split APKs for smallest install artifacts.
- Optionally build AAB and diagnose toolchain blockers if it fails.
- Record artifact paths and exact sizes.

7. Publish summary
- Provide findings ordered by severity: blockers, risks, pass checks.
- Include exact reproduction commands and next action list.

## Decision Logic
- If issue reproduces only until restart:
  - prioritize stream/watch wiring and provider refresh paths.
- If UI updates only after navigation:
  - verify subscriptions are tied to data tables/events, not one-time fetches.
- If language resets after restart:
  - verify persistence write timing and profile-scoping rules.
- If keyboard collapses during typing:
  - check for widget key recreation and field rebuild patterns.
- If AAB fails but APK succeeds:
  - treat as toolchain/licensing blocker unless analyzer indicates code failure.

## Completion Checks
A setup snapshot is complete only if all are true:
- Environment and terminal context captured
- Flutter health captured with blockers clearly called out
- Analyzer status captured for changed files
- Runtime sync behavior verified from producer to all consumer screens
- Localization persistence verified
- Profile input behavior verified
- Release artifact status and sizes captured
- Clear next actions listed

## Output Format
- Setup snapshot title with date/time
- Environment summary
- Toolchain summary
- Runtime reactivity summary
- Localization/profile summary
- Release summary
- Action plan

## Suggested Invocation Prompts
- /dev-setup-context full snapshot for Android release readiness
- /dev-setup-context quick snapshot before debugging sync delays
- /dev-setup-context release-focused with artifact size report
- /dev-setup-context full handoff summary for this workspace
