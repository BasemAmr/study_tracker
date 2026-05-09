<script lang="ts">
  import { onMount } from 'svelte';
  import { currentRoute } from '@/core/stores/router';
  import { settings } from '@/core/stores/settingsStore';
  import { getDatabase } from '@/core/data/database';
  import Sidebar from '@/ui/components/Sidebar.svelte';
  import Toast from '@/ui/components/Toast.svelte';
  import MediaPlayer from '@/ui/components/MediaPlayer.svelte';
  import Dashboard from '@/features/dashboard/Dashboard.svelte';
  import Sessions from '@/features/sessions/Sessions.svelte';
  import Analytics from '@/features/analytics/Analytics.svelte';
  import Settings from '@/features/settings/Settings.svelte';
  import Achievements from '@/features/achievements/Achievements.svelte';
  import Sync from '@/features/sync/Sync.svelte';
  import { AlertTriangle, Loader2 } from 'lucide-svelte';
  import AIDebriefCard from '@/ui/components/AIDebriefCard.svelte';
  import { aiChallengeService } from '@/core/services/aiChallengeService';
  import { initPayloadPump, stopWifiServer } from '@/core/sync/wifiTransport';
  import { getSettingByKey, setSettingByKey } from '@/core/data/repositories/appSettingsRepository';
  import { setSyncEnabled } from '@/core/stores/syncStore';
  import { profileStore } from '@/core/stores/profileStore';

  let dbReady = $state(false);
  let dbError = $state('');

  onMount(async () => {
    try {
      await getDatabase();
    } catch (err: any) {
      dbError = 'DB failed: ' + JSON.stringify(err) + ' | ' + String(err);
      return;
    }

    try {
      await settings.load();
      await profileStore.init();
      const { initializeOwnership } = await import('@/core/sync/syncIdentity');
      await initializeOwnership();

      // Always reset sync to "off" on boot as per user requirement for non-persistence across restarts.
      await setSettingByKey('wifiSyncEnabled', 'false');
      setSyncEnabled(false);
      void stopWifiServer().catch(() => {});

      /** Never block core boot on OS notification backend limits (see notify‑rust vs native toast). */
      try {
        const { bootstrapStudyNotifications } = await import('@/core/notifications/notificationBootstrap');
        await bootstrapStudyNotifications();

        /** BEHAVIOR-N7 — refresh OS alarm handles after SQLite + persisted profile id hydrate. */
        const { rescheduleAllNotifications } = await import('@/core/notifications/notificationReschedule');
        const { getStructuredSettings } = await import('@/core/data/repositories/appSettingsRepository');
        const structuredForNotifications = await getStructuredSettings();
        await rescheduleAllNotifications(structuredForNotifications.currentProfileId ?? 1);
      } catch (e) {
        console.warn('[StudyTracker] Notification subsystem degraded — app continues:', e);
      }

      dbReady = true;
      initPayloadPump();

      const { getStructuredSettings: getStructuredBoot } = await import(
        '@/core/data/repositories/appSettingsRepository'
      );
      const bootProfileId = (await getStructuredBoot()).currentProfileId ?? 1;

      void import('@/core/services/aiCoachService').then((m) =>
        void m.ensureTodaysMessage(bootProfileId).catch(() => {}),
      );
      void import('@/core/services/aiSubjectDifficultyService').then((m) =>
        void m.maybeAutoRunWeeklyDifficulty(bootProfileId).catch(() => {}),
      );

      aiChallengeService.checkAndRefreshChallenges().catch(console.error);
    } catch (err: any) {
      dbError = 'Settings failed: ' + JSON.stringify(err) + ' | ' + String(err);
      console.error('Database init error:', err);
      dbReady = false;
    }
  });
</script>

<svelte:head>
  <title>StudyTracker</title>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous" />
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet" />
</svelte:head>

<main class="box-border flex h-[100dvh] min-h-0 flex-col overflow-hidden px-4 py-4 text-ink-900 sm:px-6">
  {#if dbError}
    <div class="flex min-h-0 flex-1 items-center justify-center">
      <div class="max-w-md rounded-[2rem] border border-red-200 bg-white p-8 text-center shadow-soft">
        <div class="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-2xl bg-red-50 text-red-500">
          <AlertTriangle size={28} />
        </div>
        <h2 class="text-xl font-semibold text-ink-900">Database Error</h2>
        <p class="mt-2 text-sm text-ink-500">{dbError}</p>
        <p class="mt-4 text-xs text-ink-500">Please restart the app. If the issue persists, check the database file.</p>
      </div>
    </div>
  {:else if !dbReady}
    <div class="flex min-h-0 flex-1 items-center justify-center">
      <div class="flex flex-col items-center gap-4">
        <Loader2 size={32} class="animate-spin text-moss-600" />
        <p class="text-sm text-ink-500">Initializing StudyTracker...</p>
      </div>
    </div>
  {:else}
    <div class="mx-auto flex min-h-0 w-full max-w-[1440px] flex-1 gap-5 rounded-[2rem] border border-white/70 bg-white/70 p-4 shadow-soft backdrop-blur-sm">
      <!-- Sidebar -->
      <Sidebar />

      <section class="min-h-0 flex-1 overflow-y-auto overscroll-y-contain rounded-[1.75rem] border border-ink-200 bg-[#fcfcf9] p-5 shadow-card sm:p-6">
        {#if $currentRoute === 'dashboard'}
          <Dashboard />
        {:else if $currentRoute === 'sessions'}
          <Sessions />
        {:else if $currentRoute === 'analytics'}
          <Analytics />
        {:else if $currentRoute === 'settings'}
          <Settings />
        {:else if $currentRoute === 'achievements'}
          <Achievements />
        {:else if $currentRoute === 'sync'}
          <Sync />
        {/if}
      </section>
    </div>
  {/if}
</main>

<AIDebriefCard />

<!-- Global floating media player — persists across all pages -->
<MediaPlayer />

<Toast />
