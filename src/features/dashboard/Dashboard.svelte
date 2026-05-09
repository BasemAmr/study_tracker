<script lang="ts">
  import { onMount } from 'svelte';
  import Card from '@/ui/components/Card.svelte';
  import Button from '@/ui/components/Button.svelte';
  import ProgressRing from '@/ui/components/ProgressRing.svelte';
  import AICoachCard from '@/ui/components/AICoachCard.svelte';
  import HistoricalContextCard from '@/ui/components/HistoricalContextCard.svelte';
  import AnimatedStreakBar from '@/ui/components/AnimatedStreakBar.svelte';
  import Heatmap from '@/ui/components/Heatmap.svelte';
  import { navigate } from '@/core/stores/router';
  import { settings } from '@/core/stores/settingsStore';
  import { untrack } from 'svelte';
  import { activeProfileId } from '@/core/stores/profileStore';
  import { fetchStudySessions } from '@/core/services/sessionService';
  import { aiChallengeRepository } from '@/core/data/repositories/aiChallengeRepository';
  import { aiChallengeService } from '@/core/services/aiChallengeService';
  import { getCurrentProfileId } from '@/core/data/repositories/profileRepository';
  import { formatMinutes, formatRelativeDate, formatTime, modeLabel } from '@/core/utils/formatUtils';
  import { calculateStreaks, buildDailyMinutesMap } from '@/core/utils/streakUtils';
  import {
    computeStreakMilestoneHud,
    type StreakMilestoneHudModel
  } from '@/core/utils/streakMilestoneHud';
  import { startOfDay, daysAgo } from '@/core/utils/dateUtils';
  import type { StudySession } from '@/core/domain';
  import {
    BarChart3, Play, Settings2, CalendarDays, BookOpen, ArrowRight,
    Clock, Timer, Zap, Sparkles
  } from 'lucide-svelte';

  let recentSessions: StudySession[] = $state([]);
  let todayMinutes = $state(0);
  let weekMinutes = $state(0);
  let totalMinutes = $state(0);
  let totalSessions = $state(0);
  let currentStreak = $state(0);
  let longestStreak = $state(0);
  let dailyMinutes = $state(new Map<string, number>());
  let dailyGoal = $state(120);
  let displayName = $state('');
  let activeMissionTitle = $state('No Active Mission');
  let loading = $state(true);

  // Wellbeing States
  let wellbeingState: 'proud' | 'flow' | 'burnout' | 'idle' = $state('flow');
  let deepWorkVolume = $state('0h 0m');
  let avgSession = $state('0m');
  let completionRate = $state('0%');
  let deepWorkComparison = $state('+0m');
  let avgSessionComparison = $state('+0m');
  let completionStatus = $state('SOLID');
  let streakHud: StreakMilestoneHudModel = $state(computeStreakMilestoneHud(0, 0));

  $effect(() => {
    if ($activeProfileId) {
      untrack(() => handleProfileChange());
    }
  });

  onMount(async () => {
    // Initial load handled by $effect
  });

  async function handleProfileChange() {
    loading = true;
    await settings.load();
    const s = settings.get();
    dailyGoal = s.dailyGoalMinutes;
    displayName = s.displayName || '';
    await loadDashboardData();
    loading = false;
  }

  async function loadDashboardData() {
    const allSessions = await fetchStudySessions({ limit: 5000 });
    recentSessions = allSessions.slice(0, 5);

    const today = startOfDay(new Date());
    const todaySessions = allSessions.filter(
      (s) => new Date(s.startAt) >= today
    );
    todayMinutes = todaySessions.reduce((sum, s) => sum + s.durationMinutes, 0);

    const weekStart = daysAgo(7);
    const weekSessions = allSessions.filter(
      (s) => new Date(s.startAt) >= weekStart
    );
    weekMinutes = weekSessions.reduce((sum, s) => sum + s.durationMinutes, 0);

    totalMinutes = allSessions.reduce((sum, s) => sum + s.durationMinutes, 0);
    totalSessions = allSessions.length;

    const studyDates = allSessions
      .map((s) => new Date(s.startAt))
      .sort((a, b) => a.getTime() - b.getTime());
    const streaks = calculateStreaks(studyDates);
    currentStreak = streaks.currentStreak;
    longestStreak = streaks.longestStreak;
    streakHud = computeStreakMilestoneHud(currentStreak, longestStreak);

    dailyMinutes = buildDailyMinutesMap(allSessions);

    const profileId = await getCurrentProfileId();
    const pinnedMission = await aiChallengeService.resolveActiveMission(profileId);
    activeMissionTitle = pinnedMission ? pinnedMission.title : '';

    // Derived Wellbeing Mock Math
    const totalDeep = allSessions.filter(s => s.mode === 'pomodoro' || s.mode === 'long_session')
                                 .reduce((sum, s) => sum + s.durationMinutes, 0);
    deepWorkVolume = `${Math.floor(totalDeep / 60)}h ${totalDeep % 60}m`;
    const avgMins = allSessions.length > 0 ? Math.round(totalMinutes / allSessions.length) : 0;
    avgSession = `${avgMins}m`;
    const completedTasksCount = allSessions.reduce((sum, s) => sum + (s.tasks?.filter((t) => t.completed).length ?? 0), 0);
    const totalTasksCount = allSessions.reduce((sum, s) => sum + (s.tasks?.length ?? 0), 0);
    completionRate = totalTasksCount > 0 ? `${Math.round((completedTasksCount / totalTasksCount) * 100)}%` : '100%';
    completionStatus = (() => {
      const pct = totalTasksCount > 0 ? Math.round((completedTasksCount / totalTasksCount) * 100) : 100;
      return pct >= 85 ? 'EXCELLENT' : pct >= 60 ? 'SOLID' : 'DROPPING';
    })();

    // Week-over-week "Me vs past self" deltas
    const prevWeekStart = daysAgo(14);
    const currWeekStart = daysAgo(7);
    const prevWeekSessions = allSessions.filter(
      (s) => new Date(s.startAt) >= prevWeekStart && new Date(s.startAt) < currWeekStart
    );
    const prevWeekDeep = prevWeekSessions.filter(s => s.mode === 'pomodoro' || s.mode === 'long_session')
                                         .reduce((sum, s) => sum + s.durationMinutes, 0);
    const prevAvgMins = prevWeekSessions.length > 0 ? Math.round(
      prevWeekSessions.reduce((sum, s) => sum + s.durationMinutes, 0) / prevWeekSessions.length
    ) : 0;
    const currWeekSessions = allSessions.filter(
      (s) => new Date(s.startAt) >= currWeekStart
    );
    const currWeekDeep = currWeekSessions.filter(s => s.mode === 'pomodoro' || s.mode === 'long_session')
                                          .reduce((sum, s) => sum + s.durationMinutes, 0);
    const currAvgMins = currWeekSessions.length > 0 ? Math.round(
      currWeekSessions.reduce((sum, s) => sum + s.durationMinutes, 0) / currWeekSessions.length
    ) : 0;

    const fmtDelta = (mins: number) => {
      if (mins === 0) return '0m';
      const sign = mins > 0 ? '+' : '-';
      const abs = Math.abs(mins);
      return abs >= 60 ? `${sign}${Math.floor(abs / 60)}h ${abs % 60}m` : `${sign}${abs}m`;
    };
    const deepWorkComparisonVal = fmtDelta(currWeekDeep - prevWeekDeep);
    const avgSessionComparisonVal = fmtDelta(currAvgMins - prevAvgMins);
    deepWorkComparison = deepWorkComparisonVal;
    avgSessionComparison = avgSessionComparisonVal;

    // Wellbeing: idle → engaged → flow → proud, with burnout as a separate concern
    // burnout replaces flow when today's minutes exceed a fatigue threshold
    if (todayMinutes === 0 && currentStreak === 0) {
      wellbeingState = 'idle';
    } else if (todayMinutes > 360) {
      wellbeingState = 'burnout';
    } else if (currentStreak >= 7) {
      wellbeingState = 'proud';
    } else if (todayMinutes >= 120) {
      wellbeingState = 'flow';
    } else {
      wellbeingState = 'idle';
    }
  }

  function getGreeting(): string {
    const hour = new Date().getHours();
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
</script>

<div class="space-y-6">
  <!-- Header -->
  <header class="flex items-center justify-between">
    <div>
      <h2 class="text-2xl font-semibold tracking-tight text-ink-900">
        {getGreeting()}{displayName ? `, ${displayName}` : ''}
      </h2>
    </div>
    <div class="flex items-center gap-3">
      <button 
        class="flex items-center justify-center h-10 w-10 rounded-full text-ink-500 transition-colors hover:bg-moss-50 hover:text-moss-600"
        onclick={() => navigate('analytics')}
        aria-label="Analytics"
      >
        <BarChart3 size={20} />
      </button>
      <Button onclick={() => navigate('sessions')}>
        <Play size={16} /> Start session
      </Button>
    </div>
  </header>

  {#if loading}
    <div class="flex items-center justify-center py-20">
      <div class="h-8 w-8 animate-spin rounded-full border-2 border-moss-200 border-t-moss-600"></div>
    </div>
  {:else}
    <!-- Stats Row (Compact Pills) -->
    <section class="grid grid-cols-2 gap-3 lg:grid-cols-4">
      <div class="rounded-2xl bg-moss-50/50 px-4 py-3">
        <p class="text-xs font-medium text-moss-600">Today</p>
        <p class="mt-0.5 text-lg font-semibold text-ink-900">{formatMinutes(todayMinutes)}</p>
      </div>
      <div class="rounded-2xl bg-moss-50/50 px-4 py-3">
        <p class="text-xs font-medium text-moss-600">Last 7 days</p>
        <p class="mt-0.5 text-lg font-semibold text-ink-900">{formatMinutes(weekMinutes)}</p>
      </div>
      <div class="rounded-2xl bg-moss-50/50 px-4 py-3">
        <p class="text-xs font-medium text-moss-600">Streak</p>
        <p class="mt-0.5 text-lg font-semibold text-ink-900">{currentStreak} {currentStreak === 1 ? 'day' : 'days'}</p>
      </div>
      <div class="rounded-2xl bg-moss-50/50 px-4 py-3">
        <p class="text-xs font-medium text-moss-600">All time</p>
        <p class="mt-0.5 text-lg font-semibold text-ink-900">{formatMinutes(totalMinutes)}</p>
      </div>
    </section>

    <!-- Daily Progress + Streak Card -->
    <section>
      <Card>
        <div class="flex flex-col sm:flex-row sm:items-center justify-evenly gap-6">
          <div class="flex items-center gap-6">
            <ProgressRing value={todayMinutes} max={dailyGoal} size={80} strokeWidth={8} />
            <div>
              <p class="text-sm font-medium text-ink-500">Daily progress</p>
              <p class="mt-1 text-2xl font-semibold text-ink-900">
                {formatMinutes(todayMinutes)}
                <span class="text-base font-normal text-ink-500">/ {formatMinutes(dailyGoal)}</span>
              </p>
              <p class="mt-1 text-sm text-moss-600">
                {#if todayMinutes >= dailyGoal}
                  Goal reached!
                {:else}
                  {formatMinutes(dailyGoal - todayMinutes)} remaining
                {/if}
              </p>
            </div>
          </div>
          <div class="hidden sm:block border-l border-ink-100 pl-8 ml-2 flex-1 max-w-[300px]">
            <p class="text-sm font-medium text-ink-500 mb-2">
              {currentStreak} days · {streakHud.daysToNext !== null ? `${streakHud.daysToNext} days to next crest` : 'Max level'}
            </p>
            <AnimatedStreakBar progress={streakHud.progress01} />
          </div>
        </div>
      </Card>
      
      <!-- Energy Badge -->
      <div class="flex items-center gap-2 mt-3 px-2 text-sm font-medium text-ink-600">
        <Sparkles size={14} class="text-moss-500" />
        <span>
          {#if wellbeingState === 'burnout'}
            Needs rest · High fatigue
          {:else if wellbeingState === 'flow'}
            In the zone · Optimal focus
          {:else if wellbeingState === 'proud'}
            Consistent · Strong momentum
          {:else}
            Gentle nudge · Ready to ignite
          {/if}
        </span>
      </div>
    </section>

    <!-- Coach Note (Collapsible inside AICoachCard) -->
    <section class="space-y-4">
      <AICoachCard />
    </section>

    <!-- Secondary Layout (Desktop: 2 cols) -->
    <section class="grid gap-6 xl:grid-cols-2">
      <!-- Me vs Past Self & Active Mission -->
      <div class="space-y-6">
        <HistoricalContextCard
          {deepWorkVolume}
          {deepWorkComparison}
          {avgSession}
          {avgSessionComparison}
          {completionRate}
          {completionStatus}
        />
        {#if activeMissionTitle}
          <button
            class="flex items-center w-full gap-3 rounded-2xl bg-moss-50/50 p-4 transition-colors hover:bg-moss-100/50 text-left"
            onclick={() => navigate('sessions')}
          >
            <span class="text-base">⚡</span>
            <span class="flex-1 text-sm font-medium text-moss-800 truncate">
              Active mission: {activeMissionTitle}
            </span>
            <ArrowRight size={16} class="text-moss-600 shrink-0" />
          </button>
        {:else}
          <button
            class="flex items-center w-full gap-3 rounded-2xl border border-dashed border-ink-200 p-4 transition-colors hover:bg-ink-50 text-left"
            onclick={() => navigate('achievements')}
          >
            <span class="text-base">📌</span>
            <span class="flex-1 text-sm text-ink-400">
              Pick an active mission from AI Missions
            </span>
            <ArrowRight size={16} class="text-ink-400 shrink-0" />
          </button>
        {/if}
      </div>
      
      <!-- Recent Sessions (Last 3) -->
      <Card>
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2 text-sm font-medium text-ink-500">
            <Clock size={15} /> Recent sessions
          </div>
          <button
            class="flex items-center gap-1 text-xs font-medium text-moss-600 hover:underline"
            onclick={() => navigate('sessions')}
          >
            View all <ArrowRight size={12} />
          </button>
        </div>

        <div class="mt-4 space-y-3">
          {#if recentSessions.length === 0}
            <p class="text-sm text-ink-500">No sessions yet.</p>
          {:else}
            {#each recentSessions.slice(0, 3) as session}
              <div class="rounded-xl border border-ink-100 bg-[#fcfcfa] p-3 transition-all duration-150 hover:border-moss-200 flex justify-between items-center">
                <div>
                  <p class="font-medium text-ink-900 text-sm">
                    {session.subjectName ?? 'General study'}
                  </p>
                  <p class="mt-0.5 text-xs text-ink-500">
                    {modeLabel(session.mode)} · {formatMinutes(session.durationMinutes)}
                  </p>
                </div>
                <div class="text-xs text-ink-400">
                  {formatRelativeDate(session.startAt)}
                </div>
              </div>
            {/each}
          {/if}
        </div>
      </Card>
    </section>

    <!-- Consistency Heatmap -->
    <section>
      <Card>
        <Heatmap {dailyMinutes} />
      </Card>
    </section>
  {/if}
</div>
