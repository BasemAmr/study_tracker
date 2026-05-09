<script lang="ts">
  import { onMount } from 'svelte';
  import { settings } from '@/core/stores/settingsStore';
  import { toasts } from '@/core/stores/toastStore';
  import {
    listProfiles, saveProfile, setCurrentProfileId as setActiveProfileId,
    getCurrentProfileId, getProfileDeletionStats
  } from '@/core/services/profileService';
  import { activeProfileId, profileStore, profiles as profilesStore } from '@/core/stores/profileStore';
  import { fetchStudySessions } from '@/core/services/sessionService';
  import type { StructuredSettings, Profile } from '@/core/domain';
  import Card from '@/ui/components/Card.svelte';
  import Button from '@/ui/components/Button.svelte';
  import Input from '@/ui/components/Input.svelte';
  import Select from '@/ui/components/Select.svelte';
  import Modal from '@/ui/components/Modal.svelte';
  import {
    Settings2, User, Target, Save, Plus, Trash2, Download,
    Sparkles, RefreshCw, Image, Music, FileText, FileJson, AlertTriangle, Bell
  } from 'lucide-svelte';
  import { aiChallengeService } from '@/core/services/aiChallengeService';
  import { wipeDatabase } from '@/core/data/database';
  import { getDeviceId } from '@/core/sync/syncIdentity';
  import { getProfileOwnershipBadge } from '@/core/sync/profileOwnership';
  import { isPristineDbForSyncSeed, seedSyncTestScenario } from '@/core/dev/syncTestSeed';
  import {
    getForProfile as getNotificationSettingsRow,
    upsert as upsertNotificationSettings,
    getOrDefault,
    type NotificationSettingsRow
  } from '@/core/data/repositories/notificationSettingsRepository';
  import {
    getForProfile as getAiFeatRow,
    getAiFeaturesOrDefault,
    upsert as upsertAiFeaturesRow,
    type AiFeatureSettingsRow,
  } from '@/core/data/repositories/aiFeatureSettingsRepository';
  import { open } from '@tauri-apps/plugin-shell';
  import { rescheduleAll } from '@/core/notifications/notificationDispatcher';
  import type { NotificationKind } from '@/core/notifications/notificationScheduler';

  let dailyGoal = $state('120');
  let focusDuration = $state('25');
  let breakDuration = $state('5');
  let defaultMode = $state('pomodoro');
  let displayName = $state('Bassem');
  let defaultBackground = $state('/backgrounds/city-twilight.png');
  let overlayOpacity = $state('0.4');
  let mediaPlaylistPath = $state('');
  let myDeviceId = $state('');
  let groqApiKey = $state('');
  let aiChallengesEnabled = $state(false);
  let groqKeyVisible = $state(false);
  /** A‑T‑6 granular toggles persisted per-profile (mirrors SQLite `*_enabled` cols). */
  let aiCoachOn = $state(false);
  let aiSmartChallengesOn = $state(false);
  let aiDebriefOn = $state(false);
  let aiWeeklyNarrativeOn = $state(false);
  let aiSubjectDifficultyOn = $state(false);
  let aiFeatureSaving = $state(false);
  /** T6: Surprise mission notification settings */
  let aiSurpriseNotificationsOn = $state(false);
  let aiSurpriseCheckInterval = $state('3');

  /** BEHAVIOR-N3 — notification panel (persists to `notification_settings`, reschedules in-process timers). */
  let notifPreStudy = $state(false);
  let notifStreak = $state(false);
  let notifWeekly = $state(false);
  let notifGoal = $state(false);
  let notifReengage = $state(false);
  let notifPreStudyTime = $state('14:00');
  let notifWeeklyTime = $state('19:00');
  let notifQuietStart = $state('22:00');
  let notifQuietEnd = $state('08:00');
  let notifReengageDays = $state('3');
  let notifReengageTime = $state('14:00');
  let notifWeeklyDow = $state('7');
  let notifGoalDow = $state('3');
  let notifGoalTime = $state('19:00');
  let notifSaving = $state(false);

  const timeInputClass =
    'rounded-xl border border-ink-200 bg-white px-3 py-2 text-sm text-ink-900 focus:border-moss-300 focus:outline-none focus:ring-2 focus:ring-moss-100';

  let profiles: Profile[] = $state([]);
  let selectedProfileId = $state('1');
  let newProfileName = $state('');
  let editingProfileId = $state<number | null>(null);
  let editingProfileName = $state('');
  let editingAcademicLevel = $state('Undergraduate');

  let showDeleteConfirm = $state(false);
  let saving = $state(false);

  let profileDeleteModalOpen = $state(false);
  let profileDeleteTarget = $state<{ id: number; name: string } | null>(null);
  let profileDeleteStats = $state<{
    studySessions: number;
    subjects: number;
    goals: number;
    moodLogs: number;
  } | null>(null);
  let profileDeleteEnabled = $state(false);
  let profileDeleteTimer: ReturnType<typeof setTimeout> | null = null;

  let devSeedPristine = $state(false);
  let devSeedBusy = $state(false);

  const backgrounds = [
    { value: '/backgrounds/city-twilight.png', label: 'City Twilight' },
    { value: '/backgrounds/cozy-cafe.png', label: 'Cozy Café' }
  ];

  import { untrack } from 'svelte';

  $effect(() => {
    if ($activeProfileId) {
      untrack(() => loadSettingsData());
    }
  });

  async function loadSettingsData() {
    await settings.load();
    myDeviceId = await getDeviceId();
    const s = settings.get();
    dailyGoal = String(s.dailyGoalMinutes);
    focusDuration = String(s.focusMinutes);
    breakDuration = String(s.breakMinutes);
    defaultMode = s.defaultSessionMode;
    displayName = s.displayName ?? 'Bassem';
    defaultBackground = s.defaultBackground ?? '';
    overlayOpacity = String(s.overlayOpacity ?? 0.4);
    mediaPlaylistPath = s.mediaPlaylistPath ?? '';
    groqApiKey = s.groqApiKey ?? '';
    aiChallengesEnabled = !!s.aiChallengesEnabled;
    selectedProfileId = String($activeProfileId);
    await refreshProfiles();
    await loadNotificationPrefs(Number($activeProfileId));
    await loadAiFeaturePrefs(Number($activeProfileId));
  }

  async function loadAiFeaturePrefs(profileId: number) {
    try {
      const row = await getAiFeatRow(profileId);
      const s = getAiFeaturesOrDefault(profileId, row);
      aiCoachOn = s.coachEnabled;
      aiSmartChallengesOn = s.smartChallengesEnabled;
      aiDebriefOn = s.debriefEnabled;
      aiWeeklyNarrativeOn = s.weeklyNarrativeEnabled;
      aiSubjectDifficultyOn = s.subjectDifficultyEnabled;
      aiSurpriseNotificationsOn = s.surpriseNotificationsEnabled ?? false;
      aiSurpriseCheckInterval = String(s.surpriseCheckIntervalHours ?? 3);
    } catch (e) {
      console.warn('[settings] ai feature prefs load:', e);
    }
  }

  async function persistAiFeatureFlags() {
    const pid = Number($activeProfileId);
    if (!pid || aiFeatureSaving) return;
    aiFeatureSaving = true;
    try {
      const existingRow = await getAiFeatRow(pid);
      const prior = getAiFeaturesOrDefault(pid, existingRow);
      const row: AiFeatureSettingsRow = {
        ...prior,
        coachEnabled: aiCoachOn,
        smartChallengesEnabled: aiSmartChallengesOn,
        debriefEnabled: aiDebriefOn,
        weeklyNarrativeEnabled: aiWeeklyNarrativeOn,
        subjectDifficultyEnabled: aiSubjectDifficultyOn,
        surpriseNotificationsEnabled: aiSurpriseNotificationsOn,
        surpriseCheckIntervalHours: parseInt(aiSurpriseCheckInterval, 10) || 3,
        featChallengeAi: aiSmartChallengesOn,
        featSessionInsights: aiDebriefOn,
        featStudyPlanner: aiSubjectDifficultyOn,
        featMotivation: aiCoachOn,
        featWeeklyReview: aiWeeklyNarrativeOn,
        updatedAt: new Date().toISOString(),
      };
      await upsertAiFeaturesRow(row);
      toasts.success('AI preferences saved');
      
      // T6: After saving surprise settings, reschedule the surprise mission check
      await rescheduleAll(pid);
    } catch (e: any) {
      toasts.error(e?.message ?? 'Could not persist AI preferences');
    } finally {
      aiFeatureSaving = false;
    }
  }

  async function openGroqSignup() {
    try {
      await open('https://console.groq.com/keys');
    } catch (e: any) {
      toasts.error(e?.message ?? 'Could not open Groq signup');
    }
  }

  async function persistGroqKeyFromUi() {
    try {
      await settings.update({ groqApiKey });
      toasts.success('API key stored locally');
      
      // T6: Reactive disable — if key was cleared, disable surprise notifications
      if (groqApiKey.trim().length === 0 && aiSurpriseNotificationsOn) {
        aiSurpriseNotificationsOn = false;
        await persistAiFeatureFlags();
      }
    } catch {
      toasts.error('Could not persist API key.');
    }
  }

  async function loadNotificationPrefs(profileId: number) {
    try {
      const raw = await getNotificationSettingsRow(profileId);
      const s = getOrDefault(profileId, raw);
      notifPreStudy = s.preStudyEnabled;
      notifStreak = s.streakEnabled;
      notifWeekly = s.weeklyEnabled;
      notifGoal = s.goalEnabled;
      notifReengage = s.reengage3Enabled || s.reengage7Enabled;
      notifPreStudyTime = s.preStudyTime;
      notifWeeklyTime = s.weeklySummaryTime;
      notifQuietStart = s.quietHoursStart;
      notifQuietEnd = s.quietHoursEnd;
      notifReengageDays = String(s.reengageIntervalDays);
      notifReengageTime =
        s.reengageTime && s.reengageTime.includes(':')
          ? s.reengageTime
          : `${String(s.reengageHour).padStart(2, '0')}:00`;
      notifWeeklyDow = String(s.weeklySummaryDow ?? 7);
      notifGoalDow = String(s.goalDow ?? 3);
      notifGoalTime = s.goalTime ?? '19:00';
    } catch (e) {
      console.warn('[settings] notification prefs load failed:', e);
    }
  }

  async function persistNotifications() {
    const pid = Number($activeProfileId);
    if (!pid || notifSaving) return;
    notifSaving = true;
    try {
      const reengageHour = parseInt(notifReengageTime.split(':')[0] ?? '14', 10);
      const row: NotificationSettingsRow = {
        profileId: pid,
        preStudyEnabled: notifPreStudy,
        streakEnabled: notifStreak,
        weeklyEnabled: notifWeekly,
        goalEnabled: notifGoal,
        reengage3Enabled: notifReengage,
        reengage7Enabled: notifReengage,
        slotATime: notifPreStudyTime,
        slotBTime: notifWeeklyTime,
        preStudyTime: notifPreStudyTime,
        weeklySummaryTime: notifWeeklyTime,
        reengageTime: notifReengageTime,
        quietHoursStart: notifQuietStart,
        quietHoursEnd: notifQuietEnd,
        reengageIntervalDays: Math.min(14, Math.max(1, Number(notifReengageDays) || 3)),
        reengageHour: Number.isFinite(reengageHour) ? reengageHour : 14,
        weeklySummaryDow: parseInt(notifWeeklyDow, 10) || 7,
        goalDow: parseInt(notifGoalDow, 10) || 3,
        goalTime: notifGoalTime,
        updatedAt: new Date().toISOString()
      };
      await upsertNotificationSettings(row);
      await rescheduleAll(pid);
      toasts.success('Notifications updated');
    } catch (e) {
      const message = e instanceof Error ? e.message : String(e);
      toasts.error(`Could not save notifications: ${message}`);
    } finally {
      notifSaving = false;
    }
  }

  onMount(async () => {
    // Initial load handled by $effect
  });

  async function refreshProfiles() {
    await profilesStore.refresh();
    profiles = $profilesStore;
    selectedProfileId = String($activeProfileId);
  }

 


  function ownershipBadge(profile: Profile) {
    return getProfileOwnershipBadge(profile.ownerDeviceId, myDeviceId, profile.syncId);
  }

  async function addProfile() {
    if (!newProfileName.trim()) {
      toasts.error('Profile name is required.');
      return;
    }

    try {
      await profileStore.createNewProfile(newProfileName.trim());
      newProfileName = '';
      toasts.success('Profile created.');
    } catch (error: any) {
      toasts.error(error?.message ?? 'Failed to create profile.');
    }
  }

  async function switchProfile(profileId: string) {
    try {
      const id = Number(profileId);
      if (!Number.isFinite(id) || id <= 0) return;
      await profileStore.switchProfile(id);
      toasts.success('Active profile updated.');
    } catch {
      toasts.error('Failed to switch profile.');
    }
  }

  async function openProfileDeleteModal(profile: Profile) {
    if (!profile.id) return;
    if (profile.syncId === 'profile-default') {
      toasts.error('The default profile cannot be deleted.');
      return;
    }
    if (profiles.length <= 1) {
      toasts.error('At least one profile is required.');
      return;
    }
    if (profileDeleteTimer) {
      clearTimeout(profileDeleteTimer);
      profileDeleteTimer = null;
    }
    profileDeleteEnabled = false;
    profileDeleteTarget = { id: profile.id, name: profile.name };
    profileDeleteModalOpen = true;
    try {
      profileDeleteStats = await getProfileDeletionStats(profile.id);
    } catch {
      profileDeleteStats = null;
    }
    profileDeleteTimer = setTimeout(() => {
      profileDeleteEnabled = true;
      profileDeleteTimer = null;
    }, 2000);
  }

  function closeProfileDeleteModal() {
    if (profileDeleteTimer) {
      clearTimeout(profileDeleteTimer);
      profileDeleteTimer = null;
    }
    profileDeleteModalOpen = false;
    profileDeleteTarget = null;
    profileDeleteStats = null;
    profileDeleteEnabled = false;
  }

  async function confirmProfileDelete() {
    if (!profileDeleteTarget || !profileDeleteEnabled) return;
    try {
      await profileStore.deleteProfile(profileDeleteTarget.id);
      toasts.success('Profile deleted.');
      closeProfileDeleteModal();
      await refreshProfiles();
    } catch (err: any) {
      toasts.error(err?.message || 'Failed to delete profile.');
    }
  }

  function startEditProfile(profile: Profile) {
    if (!profile.id) return;
    editingProfileId = profile.id;
    editingProfileName = profile.name;
    editingAcademicLevel = profile.academicLevel ?? 'Undergraduate';
  }

  function cancelEditProfile() {
    editingProfileId = null;
    editingProfileName = '';
    editingAcademicLevel = 'Undergraduate';
  }

  async function saveEditedProfile(profile: Profile) {
    if (!profile.id) return;
    const trimmedName = editingProfileName.trim();
    if (!trimmedName) {
      toasts.error('Profile name is required.');
      return;
    }

    try {
      await saveProfile({
        ...profile,
        name: trimmedName,
        academicLevel: editingAcademicLevel,
      });
      await refreshProfiles();
      cancelEditProfile();
      toasts.success('Profile updated.');
    } catch (error: any) {
      toasts.error(error?.message ?? 'Failed to update profile.');
    }
  }

  async function saveGeneralSettings() {
    saving = true;
    try {
      await settings.update({
        dailyGoalMinutes: parseInt(dailyGoal) || 120,
        focusMinutes: parseInt(focusDuration) || 25,
        breakMinutes: parseInt(breakDuration) || 5,
        defaultSessionMode: defaultMode as any,
        displayName,
        defaultBackground,
        overlayOpacity: parseFloat(overlayOpacity) || 0.4,
        mediaPlaylistPath,
        groqApiKey,
        aiChallengesEnabled
      });
      toasts.success('Settings saved!');
    } catch {
      toasts.error('Failed to save settings.');
    } finally {
      saving = false;
    }
  }

  async function handleExportJSON() {
    try {
      const sessions = await fetchStudySessions({ limit: 10000 });
      const data = JSON.stringify({ sessions, exportedAt: new Date().toISOString() }, null, 2);
      const blob = new Blob([data], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `studytracker-export-${new Date().toISOString().split('T')[0]}.json`;
      a.click();
      URL.revokeObjectURL(url);
      toasts.success('Data exported as JSON!');
    } catch {
      toasts.error('Export failed.');
    }
  }

  async function handleExportCSV() {
    try {
      const sessions = await fetchStudySessions({ limit: 10000 });
      const headers = ['Date', 'Start', 'End', 'Duration (min)', 'Subject', 'Topic', 'Mode', 'Mood', 'Notes'];
      const rows = sessions.map((s) => [
        s.startAt.split('T')[0], s.startAt, s.endAt, s.durationMinutes,
        s.subjectName ?? '', s.topic ?? '', s.mode, s.mood ?? '', (s.notes ?? '').replace(/"/g, '""')
      ]);
      const csv = [headers.join(','), ...rows.map((r) => r.map((v) => `"${v}"`).join(','))].join('\n');
      const blob = new Blob([csv], { type: 'text/csv' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `studytracker-export-${new Date().toISOString().split('T')[0]}.csv`;
      a.click();
      URL.revokeObjectURL(url);
      toasts.success('Data exported as CSV!');
    } catch {
      toasts.error('Export failed.');
    }
  }

  async function triggerAiRefresh() {
    try {
      await aiChallengeService.checkAndRefreshChallenges();
      window.dispatchEvent(new CustomEvent('ai-challenges-updated'));
      toasts.success('AI challenges refreshed!');
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      toasts.error(`Failed to refresh AI challenges: ${message}`);
    }
  }

  async function handleWipeData() {
    try {
      await wipeDatabase();
      toasts.success('Database wiped. Reloading...');
      setTimeout(() => {
        window.location.reload();
      }, 1500);
    } catch (err) {
      toasts.error('Failed to wipe database.');
      console.error(err);
    }
  }
</script>

<div class="space-y-6">
  <header>
    <p class="text-sm font-medium text-moss-600">Settings</p>
    <h2 class="mt-1 flex items-center gap-2 text-3xl font-semibold tracking-tight text-ink-900">
      <Settings2 size={28} /> Settings
    </h2>
  </header>

  <!-- Profile & Study Goals — Compact 2-column layout with Save button -->
  <div class="flex flex-col gap-5">
    <div class="flex justify-between items-center gap-4 lg:flex-row flex-col lg:items-start">
      <div class="flex-1 min-w-0">
        <div class="grid gap-5 lg:grid-cols-2">
          <!-- Profile -->
          <Card>
            <h3 class="flex items-center gap-2 text-base font-semibold text-ink-900 mb-3">
              <User size={16} /> Profile
            </h3>

            <!-- Switch/Create profiles (compact) -->
            <div class="space-y-2 mb-4 pb-4 border-b border-ink-100">
              <div class="flex gap-2">
                <div class="flex-1 min-w-0">
                  <Select
                    label="Active"
                    bind:value={selectedProfileId}
                    options={profiles.map((p) => ({ value: String(p.id), label: p.name }))}
                    placeholder="Select..."
                  />
                </div>
                <div class="pt-6">
                  <Button variant="secondary" onclick={() => switchProfile(selectedProfileId)}>
                    <User size={12} />
                  </Button>
                </div>
              </div>

              <div class="flex gap-2">
                <Input label="New" bind:value={newProfileName} placeholder="Profile name" />
                <div class="pt-6">
                  <Button variant="secondary" onclick={addProfile}>
                    <Plus size={12} />
                  </Button>
                </div>
              </div>
            </div>

            <!-- Profile list (compact) -->
            {#if profiles.length > 0}
              <div class="space-y-1.5 mb-4 max-h-32 overflow-y-auto">
                {#each profiles as profile}
                  {@const badge = ownershipBadge(profile)}
                  <div class="flex items-center justify-between rounded-lg border border-ink-100 bg-[#fcfcfa] px-2.5 py-2">
                    {#if editingProfileId === profile.id}
                      <div class="flex-1 flex gap-1 items-end min-w-0">
                        <Input bind:value={editingProfileName} placeholder="Name" />
                        <Select
                          bind:value={editingAcademicLevel}
                          options={[
                            { value: 'Undergraduate', label: 'U' },
                            { value: 'Postgraduate', label: 'P' },
                            { value: 'High School', label: 'H' },
                          ]}
                        />
                      </div>
                      <div class="flex gap-1 ml-1 shrink-0">
                        <Button variant="secondary" onclick={cancelEditProfile}>✕</Button>
                        <Button onclick={() => saveEditedProfile(profile)}>✓</Button>
                      </div>
                    {:else}
                      <div class="min-w-0 flex-1">
                        <div class="flex items-center gap-1.5 min-w-0">
                          <p class="text-xs font-medium text-ink-900 truncate">{profile.name}</p>
                          <span class="text-[9px] px-1 py-0.5 rounded font-semibold shrink-0 {badge === 'SYNCED' ? 'bg-ink-100 text-ink-500' : 'bg-moss-100 text-moss-600'}">{badge}</span>
                        </div>
                        <p class="text-[11px] text-ink-400">{profile.id === Number(selectedProfileId) ? 'Active' : 'Local'}</p>
                      </div>
                      <div class="flex gap-1 ml-1 shrink-0">
                        <Button variant="secondary" onclick={() => startEditProfile(profile)}>Edit</Button>
                        {#if profile.id !== Number(selectedProfileId) && profile.syncId !== 'profile-default'}
                          <button
                            class="text-ink-200 hover:text-red-500 transition-colors p-1"
                            type="button"
                            onclick={() => openProfileDeleteModal(profile)}
                            aria-label="Delete profile"
                          >
                            <Trash2 size={12} />
                          </button>
                        {/if}
                      </div>
                    {/if}
                  </div>
                {/each}
              </div>
            {/if}

            <Input label="Display name" bind:value={displayName} placeholder="Your name" />
          </Card>

          <!-- Study Goals -->
          <Card>
            <h3 class="flex items-center gap-2 text-base font-semibold text-ink-900 mb-3">
              <Target size={16} /> Study Goals
            </h3>
            <div class="grid gap-2 grid-cols-2 mb-3">
              <Input label="Daily (min)" type="number" bind:value={dailyGoal} placeholder="120" />
              <Input label="Focus (min)" type="number" bind:value={focusDuration} placeholder="25" />
            </div>
            <div class="grid gap-2 grid-cols-2">
              <Input label="Break (min)" type="number" bind:value={breakDuration} placeholder="5" />
              <Select
                label="Mode"
                bind:value={defaultMode}
                options={[
                  { value: 'pomodoro', label: 'Pomodoro' },
                  { value: 'long_session', label: 'Long' },
                  { value: 'manual', label: 'Manual' }
                ]}
              />
            </div>
          </Card>
        </div>
      </div>

      <!-- Save button (sticky on desktop) -->
      <div class="lg:sticky lg:top-6">
        <Button onclick={saveGeneralSettings} disabled={saving} size="lg">
          <Save size={16} /> {saving ? 'Saving...' : 'Save'}
        </Button>
      </div>
    </div>
  </div>

  <!-- Notifications — BEHAVIOR-N3 (persists immediately; rescheduleAll refreshes timers) -->
  <Card>
    <h3 class="flex items-center gap-2 text-base font-semibold text-ink-900 mb-4">
      <Bell size={18} /> Notifications
    </h3>
    <p class="text-sm text-ink-500 mb-4">
      Changes save right away and refresh background schedules. Quiet hours defer non-urgent reminders until the window ends.
    </p>

    <div class="space-y-4 max-w-xl">
      <div class="rounded-xl border border-ink-100 bg-[#fcfcfa] p-4 space-y-3">
        <label class="flex items-center gap-2 cursor-pointer">
          <input
            type="checkbox"
            bind:checked={notifPreStudy}
            onchange={() => void persistNotifications()}
            class="rounded border-ink-300 text-moss-600 focus:ring-moss-500"
          />
          <span class="text-sm font-medium text-ink-900">Pre-Study Reminder</span>
        </label>
        <div class="pl-7 text-xs text-ink-500 flex flex-wrap items-center gap-2">
          <span>Fire at</span>
          <input
            type="time"
            bind:value={notifPreStudyTime}
            onchange={() => void persistNotifications()}
            disabled={!notifPreStudy}
            class={`${timeInputClass} shrink-0 disabled:opacity-50`}
          />
          <span>· every day</span>
        </div>
      </div>

      <div class="rounded-xl border border-ink-100 bg-[#fcfcfa] p-4 space-y-3">
        <label class="flex items-center gap-2 cursor-pointer">
          <input
            type="checkbox"
            bind:checked={notifStreak}
            onchange={() => void persistNotifications()}
            class="rounded border-ink-300 text-moss-600 focus:ring-moss-500"
          />
          <span class="text-sm font-medium text-ink-900">Streak Protection</span>
        </label>
        <p class="pl-7 text-xs text-ink-500">Fires at 22:00 local (two hours before midnight) when eligible.</p>
      </div>

      <div class="rounded-xl border border-ink-100 bg-[#fcfcfa] p-4 space-y-3">
        <label class="flex items-center gap-2 cursor-pointer">
          <input
            type="checkbox"
            bind:checked={notifWeekly}
            onchange={() => void persistNotifications()}
            class="rounded border-ink-300 text-moss-600 focus:ring-moss-500"
          />
          <span class="text-sm font-medium text-ink-900">Weekly Summary</span>
        </label>
        <div class="pl-7 text-xs text-ink-500 flex flex-wrap items-center gap-2">
          <span>Every</span>
          <select
            bind:value={notifWeeklyDow}
            onchange={() => void persistNotifications()}
            disabled={!notifWeekly}
            class="rounded-xl border border-ink-200 bg-white px-2 py-1 text-sm text-ink-900 focus:border-moss-300 focus:outline-none focus:ring-2 focus:ring-moss-100 disabled:opacity-50"
          >
            <option value="1">Sunday</option>
            <option value="2">Monday</option>
            <option value="3">Tuesday</option>
            <option value="4">Wednesday</option>
            <option value="5">Thursday</option>
            <option value="6">Friday</option>
            <option value="7">Saturday</option>
          </select>
          <span>at</span>
          <input
            type="time"
            bind:value={notifWeeklyTime}
            onchange={() => void persistNotifications()}
            disabled={!notifWeekly}
            class={`${timeInputClass} shrink-0 disabled:opacity-50`}
          />
        </div>
      </div>

      <div class="rounded-xl border border-ink-100 bg-[#fcfcfa] p-4 space-y-3">
        <label class="flex items-center gap-2 cursor-pointer">
          <input
            type="checkbox"
            bind:checked={notifGoal}
            onchange={() => void persistNotifications()}
            class="rounded border-ink-300 text-moss-600 focus:ring-moss-500"
          />
          <span class="text-sm font-medium text-ink-900">Goal Progress Reminder</span>
        </label>
        <div class="pl-7 text-xs text-ink-500 flex flex-wrap items-center gap-2">
          <span>Every</span>
          <select
            bind:value={notifGoalDow}
            onchange={() => void persistNotifications()}
            disabled={!notifGoal}
            class="rounded-xl border border-ink-200 bg-white px-2 py-1 text-sm text-ink-900 focus:border-moss-300 focus:outline-none focus:ring-2 focus:ring-moss-100 disabled:opacity-50"
          >
            <option value="1">Sunday</option>
            <option value="2">Monday</option>
            <option value="3">Tuesday</option>
            <option value="4">Wednesday</option>
            <option value="5">Thursday</option>
            <option value="6">Friday</option>
            <option value="7">Saturday</option>
          </select>
          <span>at</span>
          <input
            type="time"
            bind:value={notifGoalTime}
            onchange={() => void persistNotifications()}
            disabled={!notifGoal}
            class={`${timeInputClass} shrink-0 disabled:opacity-50`}
          />
          <span>(if behind pace)</span>
        </div>
      </div>

      <div class="rounded-xl border border-ink-100 bg-[#fcfcfa] p-4 space-y-3">
        <label class="flex items-center gap-2 cursor-pointer">
          <input
            type="checkbox"
            bind:checked={notifReengage}
            onchange={() => void persistNotifications()}
            class="rounded border-ink-300 text-moss-600 focus:ring-moss-500"
          />
          <span class="text-sm font-medium text-ink-900">Re-engagement Reminder</span>
        </label>
        <div class="pl-7 flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:items-end">
          <div class="flex-1 min-w-[140px]">
            <label for="reengage-days" class="block text-sm font-medium text-ink-700 mb-1.5">After inactive for (days)</label>
            <select
              id="reengage-days"
              bind:value={notifReengageDays}
              onchange={() => void persistNotifications()}
              disabled={!notifReengage}
              class="w-full appearance-none rounded-xl border border-ink-200 bg-white px-4 py-2.5 pe-8 text-sm text-ink-900 transition-colors duration-150 focus:border-moss-300 focus:outline-none focus:ring-2 focus:ring-moss-100 disabled:opacity-50"
            >
              {#each [3, 4, 5, 6, 7] as d}
                <option value={String(d)}>{d}</option>
              {/each}
            </select>
          </div>
          <div>
            <span class="block text-sm font-medium text-ink-700 mb-1.5">At</span>
            <input
              type="time"
              bind:value={notifReengageTime}
              onchange={() => void persistNotifications()}
              disabled={!notifReengage}
              class={`${timeInputClass} w-full disabled:opacity-50`}
            />
          </div>
        </div>
      </div>

      <div>
        <h4 class="text-sm font-semibold text-ink-800 mb-2">Do Not Disturb</h4>
        <div class="rounded-xl border border-ink-100 bg-[#fcfcfa] p-4 flex flex-wrap items-center gap-3 text-sm text-ink-600">
          <span>Quiet hours</span>
          <input type="time" bind:value={notifQuietStart} onchange={() => void persistNotifications()} class={`${timeInputClass} shrink-0`} />
          <span>to</span>
          <input type="time" bind:value={notifQuietEnd} onchange={() => void persistNotifications()} class={`${timeInputClass} shrink-0`} />
        </div>
      </div>

      {#if notifSaving}
        <p class="text-xs text-ink-400">Updating schedules…</p>
      {/if}
    </div>
  </Card>

  <!-- Session Backgrounds -->
  <Card>
    <h3 class="flex items-center gap-2 text-base font-semibold text-ink-900 mb-4">
      <Image size={18} /> Session Backgrounds
    </h3>
    <div class="grid gap-4 md:grid-cols-2 max-w-lg">
      <Select
        label="Default background"
        bind:value={defaultBackground}
        options={backgrounds}
        placeholder="Choose background..."
      />
      <div>
        <label for="overlay-opacity" class="block text-sm font-medium text-ink-700 mb-1.5">Overlay opacity</label>
        <div class="flex items-center gap-3">
          <input
            id="overlay-opacity"
            type="range"
            min="0"
            max="0.8"
            step="0.05"
            bind:value={overlayOpacity}
            class="flex-1 h-2 accent-moss-600 cursor-pointer"
          />
          <span class="text-sm text-ink-500 w-10 text-right">{Math.round(parseFloat(overlayOpacity) * 100)}%</span>
        </div>
      </div>
    </div>
    <!-- Background previews -->
    <div class="mt-4 flex gap-3">
      {#each backgrounds as bg}
        <button
          class="relative h-20 w-32 overflow-hidden rounded-xl border-2 transition-all {defaultBackground === bg.value
            ? 'border-moss-500 shadow-card'
            : 'border-ink-200 opacity-70 hover:opacity-100'}"
          onclick={() => (defaultBackground = bg.value)}
        >
          <img src={bg.value} alt={bg.label} class="h-full w-full object-cover" />
          <div class="absolute inset-0 bg-black" style="opacity: {overlayOpacity}"></div>
          <span class="absolute bottom-1 left-2 text-[10px] font-medium text-white">{bg.label}</span>
        </button>
      {/each}
    </div>
  </Card>

  <!-- Media Player -->
  <Card>
    <h3 class="flex items-center gap-2 text-base font-semibold text-ink-900 mb-4">
      <Music size={18} /> Media Player
    </h3>
    <p class="text-sm text-ink-500 mb-4">
      Add audio files directly in the session timer. The media player appears during active sessions.
    </p>
    <div class="max-w-md">
      <Input label="Default playlist folder path (optional)" bind:value={mediaPlaylistPath} placeholder="C:\Music\StudyPlaylist" />
    </div>
  </Card>

  <!-- AI Features (Groq powered) - A-T-6 -->
  <Card>
    <div class="mb-4 flex flex-wrap items-start justify-between gap-3">
      <div>
        <h3 class="flex flex-wrap items-center gap-2 text-base font-semibold text-ink-900">
          <Sparkles size={18} /> AI Features
          <span class="text-xs font-normal text-ink-500">powered by Groq</span>
        </h3>
        <p class="mt-2 text-sm text-ink-500 max-w-xl">
          Enter your Groq API key locally (plaintext storage). Toggle each surface independently -- empty key freezes AI toggles until you reconnect.
        </p>
      </div>
      {#if groqApiKey.trim()}
        <span class="rounded-full bg-moss-50 px-3 py-1 text-xs font-semibold text-moss-700 border border-moss-200">
          Connected
        </span>
      {:else}
        <span class="rounded-full bg-ink-100 px-3 py-1 text-xs font-medium text-ink-500">Disconnected</span>
      {/if}
    </div>

    <div class="rounded-2xl border border-ink-100 bg-[#fcfcfa] p-4 mb-6 max-w-xl">
      <label for="groq-api-key" class="block text-xs font-semibold uppercase tracking-wide text-ink-500 mb-2">API Key</label>
      <div class="flex flex-col gap-2 sm:flex-row sm:items-center">
        <input
          id="groq-api-key"
          type={groqKeyVisible ? 'text' : 'password'}
          bind:value={groqApiKey}
          onblur={persistGroqKeyFromUi}
          placeholder="gsk..."
          class="flex-1 rounded-xl border border-ink-100 bg-white px-4 py-2.5 text-sm transition-all focus:border-moss-500 focus:outline-none focus:ring-4 focus:ring-moss-500/10 placeholder:text-ink-300"
        />
        <div class="flex gap-2">
          <button
            type="button"
            class="rounded-xl border border-ink-200 bg-white px-3 py-2 text-xs font-medium text-ink-700 hover:bg-ink-50"
            onclick={() => (groqKeyVisible = !groqKeyVisible)}
          >
            {groqKeyVisible ? 'Hide' : 'Show'}
          </button>
          <button
            type="button"
            class="rounded-xl border border-moss-200 bg-moss-600 px-3 py-2 text-xs font-semibold text-white hover:bg-moss-500"
            onclick={() => persistGroqKeyFromUi()}
          >
            Save key
          </button>
        </div>
      </div>
      <button
        type="button"
        class="mt-3 text-xs font-medium text-moss-600 underline-offset-4 hover:underline"
        onclick={openGroqSignup}
      >
        Get a free Groq API key -&gt;
      </button>
    </div>

    <div
      class={`space-y-3 max-w-xl ${groqApiKey.trim().length === 0 ? 'pointer-events-none opacity-45 saturate-75' : ''}`}
    >
      <div class="flex items-center gap-3 rounded-xl border border-ink-100 bg-white px-4 py-3">
        <input
          id="ai-ch-master"
          type="checkbox"
          bind:checked={aiChallengesEnabled}
          disabled={groqApiKey.trim().length === 0}
          onchange={(e) => {
            if (!aiChallengesEnabled && aiSurpriseNotificationsOn) {
              aiSurpriseNotificationsOn = false;
            }
          }}
          class="h-4 w-4 accent-moss-600"
        />
        <label for="ai-ch-master" class="flex-1 text-sm text-ink-800">
          <span class="font-medium">Poll for challenge cards</span>
          <span class="block text-xs text-ink-500 mt-1">Background timer seeds achievements (Groq fires only when smart challenges are enabled).</span>
        </label>
      </div>

      <label class="flex gap-3 items-start rounded-xl border border-ink-100 bg-white px-4 py-3">
        <input type="checkbox" bind:checked={aiSmartChallengesOn} disabled={groqApiKey.trim().length === 0} onchange={() => void persistAiFeatureFlags()} class="mt-0.5 h-4 w-4 accent-moss-600" />
        <span class="text-sm"><span class="font-medium block">Personalized Challenges</span><span class="text-xs text-ink-500">Smart prompts with deterministic safety net.</span></span>
      </label>

      <label class="flex gap-3 items-start rounded-xl border border-ink-100 bg-white px-4 py-3">
        <input type="checkbox" bind:checked={aiCoachOn} disabled={groqApiKey.trim().length === 0} onchange={() => void persistAiFeatureFlags()} class="mt-0.5 h-4 w-4 accent-moss-600" />
        <span class="text-sm"><span class="font-medium block">Daily Coach Message</span><span class="text-xs text-ink-500">Dashboard card, cached daily.</span></span>
      </label>

      <label class="flex gap-3 items-start rounded-xl border border-ink-100 bg-white px-4 py-3">
        <input type="checkbox" bind:checked={aiDebriefOn} disabled={groqApiKey.trim().length === 0} onchange={() => void persistAiFeatureFlags()} class="mt-0.5 h-4 w-4 accent-moss-600" />
        <span class="text-sm"><span class="font-medium block">Session Debrief</span><span class="text-xs text-ink-500">Brief toast after timed saves.</span></span>
      </label>

      <label class="flex gap-3 items-start rounded-xl border border-ink-100 bg-white px-4 py-3">
        <input type="checkbox" bind:checked={aiWeeklyNarrativeOn} disabled={groqApiKey.trim().length === 0} onchange={() => void persistAiFeatureFlags()} class="mt-0.5 h-4 w-4 accent-moss-600" />
        <span class="text-sm"><span class="font-medium block">Weekly Narrative Report</span><span class="text-xs text-ink-500">Analytics generator.</span></span>
      </label>

      <label class="flex gap-3 items-start rounded-xl border border-ink-100 bg-white px-4 py-3">
        <input type="checkbox" bind:checked={aiSubjectDifficultyOn} disabled={groqApiKey.trim().length === 0} onchange={() => void persistAiFeatureFlags()} class="mt-0.5 h-4 w-4 accent-moss-600" />
        <span class="text-sm"><span class="font-medium block">Subject Difficulty Analysis</span><span class="text-xs text-ink-500">Weekly Sunday snapshot when telemetry allows.</span></span>
      </label>

      <!-- T6: Surprise notification controls -->
      <label class="flex gap-3 items-start rounded-xl border border-ink-100 bg-white px-4 py-3">
        <input 
          type="checkbox" 
          bind:checked={aiSurpriseNotificationsOn} 
          disabled={groqApiKey.trim().length === 0 || !aiChallengesEnabled}
          onchange={() => void persistAiFeatureFlags()}
          class="mt-0.5 h-4 w-4 accent-moss-600" 
        />
        <span class="text-sm"><span class="font-medium block">Auto-check Surprise Missions</span><span class="text-xs text-ink-500">Background timer to check for new surprise challenges.</span></span>
      </label>

      <!-- T6: Interval picker (only enabled when surprise notifications ON) -->
      {#if aiSurpriseNotificationsOn}
        <div class="flex gap-3 items-center rounded-xl border border-ink-100 bg-white px-4 py-3">
          <label for="surprise-interval" class="text-sm font-medium text-ink-800">Check every</label>
          <select 
            id="surprise-interval"
            bind:value={aiSurpriseCheckInterval}
            disabled={!aiSurpriseNotificationsOn}
            onchange={() => void persistAiFeatureFlags()}
            class="text-sm px-2 py-1 rounded border border-ink-200 accent-moss-600"
          >
            <option value="1">1 hour</option>
            <option value="3">3 hours</option>
            <option value="6">6 hours</option>
            <option value="12">12 hours</option>
            <option value="24">24 hours</option>
          </select>
        </div>
      {/if}
    </div>

    <div class="mt-6 flex flex-wrap gap-3 items-center">
      {#if aiFeatureSaving}
        <span class="text-[11px] text-ink-400">Saving AI toggles...</span>
      {/if}
    </div>
  </Card>

  <!-- Export & Danger Zone (Compact row) -->
  <div class="grid gap-5 lg:grid-cols-2">
    <!-- Export -->
    <Card>
      <h3 class="flex items-center gap-2 text-base font-semibold text-ink-900 mb-3">
        <Download size={16} /> Export
      </h3>
      <div class="flex gap-2">
        <Button variant="secondary" onclick={handleExportCSV}>
          <FileText size={14} /> CSV
        </Button>
        <Button variant="secondary" onclick={handleExportJSON}>
          <FileJson size={14} /> JSON
        </Button>
      </div>
    </Card>

    <!-- Danger Zone -->
    <Card>
      <h3 class="flex items-center gap-2 text-base font-semibold text-red-600 mb-3">
        <AlertTriangle size={16} /> Danger Zone
      </h3>
      <Button variant="danger" onclick={() => (showDeleteConfirm = true)}>
        <Trash2 size={14} /> Delete all data
      </Button>
    </Card>
  </div>

  <Modal bind:open={showDeleteConfirm} title="Delete all data?">
    <p class="text-sm text-ink-700 mb-4">
      This will permanently delete all study sessions, subjects, goals, and settings. This action cannot be undone.
    </p>
    <div class="flex justify-end gap-3">
      <Button variant="secondary" onclick={() => (showDeleteConfirm = false)}>Cancel</Button>
      <Button variant="danger" onclick={() => { showDeleteConfirm = false; handleWipeData(); }}>
        Yes, delete everything
      </Button>
    </div>
  </Modal>

  <Modal bind:open={profileDeleteModalOpen} title={profileDeleteTarget ? `Delete ${profileDeleteTarget.name}?` : 'Delete profile?'} onclose={closeProfileDeleteModal}>
    <p class="text-sm text-ink-700 mb-3">
      This will permanently delete this profile and <strong>all</strong> its data:
    </p>
    <ul class="text-sm text-ink-800 mb-4 list-disc pl-5 space-y-1">
      <li>
        {profileDeleteStats?.studySessions ?? 0} study session{(profileDeleteStats?.studySessions ?? 0) === 1 ? '' : 's'}
      </li>
      <li>
        {profileDeleteStats?.subjects ?? 0} subject{(profileDeleteStats?.subjects ?? 0) === 1 ? '' : 's'}
      </li>
      <li>All tasks, goals, and mood logs for this profile</li>
    </ul>
    <p class="text-sm text-ink-500 mb-4">This cannot be undone.</p>
    <div class="flex justify-end gap-3">
      <Button variant="secondary" onclick={closeProfileDeleteModal}>Cancel</Button>
      <Button
        variant="danger"
        disabled={!profileDeleteEnabled}
        onclick={confirmProfileDelete}
      >
        {profileDeleteEnabled ? 'Delete everything' : 'Please wait…'}
      </Button>
    </div>
  </Modal>
</div>
