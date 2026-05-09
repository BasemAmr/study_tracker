<script lang="ts">
  import { onMount, tick } from 'svelte';
  import { fetchStudySessions } from '@/core/services/sessionService';
  import { aiChallengeRepository } from '@/core/data/repositories/aiChallengeRepository';
  import { aiChallengeHistoryRepository } from '@/core/data/repositories/aiChallengeHistoryRepository';
  import {
    aiChallengeService,
    type ChallengeProgress,
    type AiChallengeError,
    formatAiChallengeErrorToast
  } from '@/core/services/aiChallengeService';
  import { toasts } from '@/core/stores/toastStore';
  import { badgeDefinitions, type AchievementCategory, type AchievementTier } from './achievementDefinitions';
  import Card from '@/ui/components/Card.svelte';
  import Button from '@/ui/components/Button.svelte';
  import type { StudySession, AiChallenge, AiChallengeTier, AiChallengeHistoryEntry } from '@/core/domain';
  import {
    Trophy, Sprout, BookOpen, GraduationCap, Medal, Award, Crown,
    Clock, Timer, Hourglass, Star, TrendingUp, Flame, CalendarDays,
    CalendarCheck, Zap, Brain, Sunrise, Moon, Target, Sparkles,
    Cpu, RefreshCw, Lock, CheckCircle2, Layout, Layers, ShieldCheck,
    AlertCircle, TimerIcon, History, Pin, PinOff
  } from 'lucide-svelte';
  import * as Lucide from 'lucide-svelte';

  import { untrack } from 'svelte';
  import { activeProfileId } from '@/core/stores/profileStore';
  import { getCurrentProfileId } from '@/core/data/repositories/profileRepository';

  let activeTab = $state<'static' | 'ai'>('static');
  let sessions: StudySession[] = $state([]);
  let aiChallenges: AiChallenge[] = $state([]);
  let aiProgress: Record<string, ChallengeProgress> = $state({});
  let activePinnedMissionId = $state<string | null>(null);
  let loading = $state(true);
  let tierFailures: Partial<Record<AiChallengeTier, AiChallengeError | null>> = $state({});
  let missionHistory: AiChallengeHistoryEntry[] = $state([]);
  let pastMissionsOpen = $state(false);

  const tierOrder: AiChallengeTier[] = ['daily', 'weekly', 'monthly', 'surprise'];

  $effect(() => {
    if (activeTab === 'ai' && $activeProfileId) {
      void runAiTabOpenedLifecycle();
    }
  });

  $effect(() => {
    if ($activeProfileId) {
      untrack(() => initialize());
    }
  });

  async function loadAiTabAuxiliary() {
    const profileId = await getCurrentProfileId();
    const failures: Partial<Record<AiChallengeTier, AiChallengeError | null>> = {};
    for (const t of tierOrder) {
      failures[t] = await aiChallengeService.getTierFailure(profileId, t);
    }
    tierFailures = failures;
    const rows: AiChallengeHistoryEntry[] = [];
    for (const t of tierOrder) {
      rows.push(...(await aiChallengeHistoryRepository.getRecent(t, 50)));
    }
    rows.sort((a, b) => (a.closedAt < b.closedAt ? 1 : -1));
    missionHistory = rows;
  }

  async function refreshAiData() {
    aiChallenges = await aiChallengeRepository.getAll();
    aiProgress = {};
    for (const challenge of aiChallenges) {
      if (!challenge.completed) {
        aiProgress[challenge.id] = await aiChallengeService.calculateProgress(challenge);
      }
    }
    await loadAiTabAuxiliary();
    const profileId = await getCurrentProfileId();
    activePinnedMissionId = await aiChallengeService.getActiveAiMissionId(profileId);
  }

  async function runAiTabOpenedLifecycle() {
    await aiChallengeService.processExpiredMissionsOnTabOpen();
    await refreshAiData();
  }

  function slotChallenge(tier: AiChallengeTier): AiChallenge | null {
    const candidates = aiChallenges.filter(
      (c) => c.tier === tier && !c.completed && c.status === 'active'
    );
    candidates.sort(
      (a, b) =>
        new Date(b.createdAt ?? 0).getTime() - new Date(a.createdAt ?? 0).getTime()
    );
    return candidates[0] ?? null;
  }

  function formatMissionExpiry(challenge: AiChallenge): { line1: string; line2: string; surprise: boolean } {
    const exp = new Date(challenge.expiresAt);
    const now = new Date();
    const ms = exp.getTime() - now.getTime();
    const surprise = challenge.tier === 'surprise';
    const timeStr = exp.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    if (ms <= 0) {
      return { line1: 'Expired', line2: `Was due at ${timeStr}`, surprise };
    }
    const totalM = Math.ceil(ms / 60000);
    const d = Math.floor(totalM / (60 * 24));
    const h = Math.floor((totalM % (60 * 24)) / 60);
    const m = totalM % 60;
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const expDay = new Date(exp.getFullYear(), exp.getMonth(), exp.getDate());
    const sameDay = today.getTime() === expDay.getTime();
    const line1 = d > 0 ? `${d}d ${h}h left` : `${h}h ${m}m left`;
    const line2 = sameDay ? `expires ${timeStr} today` : `expires at ${timeStr}`;
    return { line1, line2, surprise };
  }

  function historyProgressLabel(metric: string, progress: number, target: number): string {
    switch (metric) {
      case 'minutes':
        return `progress ${progress}/${target} minutes`;
      case 'sessions':
        return `progress ${progress}/${target} sessions`;
      case 'pomodoros':
        return `progress ${progress}/${target} pomodoros`;
      case 'subjects':
        return `progress ${progress}/${target} subjects`;
      case 'streak':
        return `progress ${progress}/${target} streak days`;
      default:
        return `progress ${progress}/${target}`;
    }
  }

  function metricLabel(metric: AiChallenge['metric']): string {
    switch (metric) {
      case 'minutes':
        return 'minutes';
      case 'sessions':
        return 'sessions';
      case 'pomodoros':
        return 'pomodoros';
      case 'subjects':
        return 'subjects';
      case 'streak':
        return 'streak days';
      default:
        return metric;
    }
  }

  async function refreshTierWithConfirm(tier: AiChallengeTier, isExpired: boolean) {
    const msg = isExpired
      ? 'This mission expired. Refreshing replaces it and starts progress from zero. Continue?'
      : 'Refreshing will start progress from zero. Continue?';
    if (!window.confirm(msg)) return;
    const res = await aiChallengeService.refreshTierNow(tier);
    if (!res.ok) {
      toasts.error(formatAiChallengeErrorToast(res.error));
    }
    await refreshAiData();
    window.dispatchEvent(new CustomEvent('ai-challenges-updated'));
  }

  async function refreshSurpriseOnly() {
    const res = await aiChallengeService.refreshTierNow('surprise');
    if (!res.ok) {
      toasts.error(formatAiChallengeErrorToast(res.error));
    }
    await refreshAiData();
    window.dispatchEvent(new CustomEvent('ai-challenges-updated'));
  }

  const handleAiChallengesUpdated = async () => {
    await refreshAiData();
  };

  const initialize = async () => {
    loading = true;
    try {
      sessions = await fetchStudySessions({ limit: 10000 });
      await aiChallengeService.checkAndRefreshChallenges();
      await refreshAiData();
    } finally {
      loading = false;
    }
  };

  async function togglePin(missionId: string) {
    const profileId = await getCurrentProfileId();
    if (activePinnedMissionId === missionId) {
      await aiChallengeService.clearActiveAiMissionId(profileId);
      activePinnedMissionId = null;
    } else {
      await aiChallengeService.setActiveAiMissionId(profileId, missionId);
      activePinnedMissionId = missionId;
    }
    window.dispatchEvent(new CustomEvent('ai-challenges-updated'));
  }

  onMount(() => {
    window.addEventListener('ai-challenges-updated', handleAiChallengesUpdated);
    return () => {
      window.removeEventListener('ai-challenges-updated', handleAiChallengesUpdated);
    };
  });

  function tierLabel(tier: AiChallengeTier): string {
    switch (tier) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      case 'surprise':
        return 'Surprise';
    }
  }

  const processedAchievements = $derived(
    badgeDefinitions.map(def => {
      const result = def.check(sessions);
      return {
        ...def,
        unlocked: result.unlocked,
        progress: result.progress,
        completions: result.completions
      };
    })
  );

  const stats = $derived({
    total: processedAchievements.length,
    unlocked: processedAchievements.filter(a => a.unlocked).length,
    percent: Math.round((processedAchievements.filter(a => a.unlocked).length / processedAchievements.length) * 100)
  });

  function getTierStyles(tier?: AchievementTier) {
    switch (tier) {
      case 'bronze': return 'border-amber-700/20 bg-amber-50/30 text-amber-700';
      case 'silver': return 'border-slate-400/30 bg-slate-50/50 text-slate-600';
      case 'gold': return 'border-yellow-500/30 bg-yellow-50/50 text-yellow-700 shadow-sm shadow-yellow-200/50';
      case 'legend': return 'border-purple-500/40 bg-purple-50/50 text-purple-700 shadow-md shadow-purple-200/50 ring-1 ring-purple-500/20';
      default: return 'border-moss-200 bg-moss-50/50 text-moss-700';
    }
  }

  function getCategoryAchievements(catId: AchievementCategory) {
    return processedAchievements.filter(a => a.category === catId);
  }

  const completedAiChallenges = $derived(aiChallenges.filter((c) => c.completed));
  const activeAiChallenges = $derived(aiChallenges.filter((c) => !c.completed));

  const categories: Array<{ id: AchievementCategory; label: string; icon: any }> = [
    { id: 'daily', label: 'Daily Loops', icon: RefreshCw },
    { id: 'weekly', label: 'Weekly Quests', icon: CalendarDays },
    { id: 'monthly', label: 'Monthly Milestones', icon: CalendarCheck },
    { id: 'all_time', label: 'All-Time Tiers', icon: Trophy },
    { id: 'secret', label: 'Hidden Feats', icon: Sparkles }
  ];
</script>

<div class="space-y-6">
  <header class="flex flex-col md:flex-row md:items-end justify-between gap-4">
    <div>
      <p class="text-sm font-medium text-moss-600">Achievements</p>
      <h2 class="mt-1 flex items-center gap-2 text-3xl font-semibold tracking-tight text-ink-900">
        <Trophy size={28} /> Personal Growth
      </h2>
      <p class="mt-1 text-sm text-ink-500">Track your consistency and unlock various badges.</p>
    </div>

    <!-- Tab switcher -->
    <div class="flex p-1 bg-ink-50 rounded-2xl w-fit">
      <button
        onclick={() => activeTab = 'static'}
        class="px-4 py-2 text-sm font-medium rounded-xl transition-all {activeTab === 'static' ? 'bg-white text-moss-600 shadow-sm' : 'text-ink-500 hover:text-ink-900'}"
      >
        Badge Catalog
      </button>
      <button
        onclick={() => activeTab = 'ai'}
        class="px-4 py-2 text-sm font-medium rounded-xl transition-all {activeTab === 'ai' ? 'bg-white text-moss-600 shadow-sm' : 'text-ink-500 hover:text-ink-900'}"
      >
        AI Challenges
      </button>
    </div>
  </header>

  {#if loading}
    <div class="flex flex-col items-center justify-center py-24 gap-4">
      <div class="h-10 w-10 animate-spin rounded-full border-2 border-moss-200 border-t-moss-600"></div>
      <p class="text-sm text-ink-400 font-medium">Synchronizing your progress...</p>
    </div>
  {:else}
    
    {#if activeTab === 'static'}
      <!-- Overall Progress -->
      <Card padding="p-5">
        <div class="flex items-center justify-between mb-2">
          <div class="flex items-center gap-2">
            <Medal size={18} class="text-moss-600" />
            <span class="text-sm font-semibold text-ink-900">Overall Mastery</span>
          </div>
          <span class="text-sm font-bold text-moss-600">{stats.unlocked} / {stats.total}</span>
        </div>
        <div class="relative w-full h-3 rounded-full bg-ink-100 overflow-hidden">
          <div
            class="absolute inset-y-0 left-0 bg-moss-500 transition-all duration-1000 ease-out"
            style="width: {stats.percent}%"
          ></div>
        </div>
        <div class="mt-2 flex justify-between text-[11px] text-ink-400 font-medium">
          <span>{stats.percent}% Unlocked</span>
          <span>Keep studying to earn them all!</span>
        </div>
      </Card>

      <!-- Sections -->
      {#each categories as cat}
        {@const catAchievements = getCategoryAchievements(cat.id)}
        {#if cat.id !== 'secret' || catAchievements.some(a => a.unlocked)}
          <div class="space-y-4 pt-4">
            <h3 class="flex items-center gap-2 text-sm font-bold uppercase tracking-wider text-ink-400 px-1">
              <cat.icon size={16} /> {cat.label}
              <span class="ml-2 h-px flex-1 bg-ink-100"></span>
            </h3>

            <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
              {#each catAchievements as badge}
                <div class="group relative rounded-[1.5rem] border p-5 transition-all duration-300 {badge.unlocked ? getTierStyles(badge.tier) : 'border-ink-100 bg-white shadow-sm opacity-60'}">
                  
                  {#if !badge.unlocked}
                    <div class="absolute top-4 right-4 text-ink-300">
                      <Lock size={14} />
                    </div>
                  {:else}
                    <div class="absolute top-4 right-4 text-moss-500 animate-in fade-in zoom-in duration-500">
                      <CheckCircle2 size={16} />
                    </div>
                  {/if}

                  <div class="flex items-start gap-4">
                    <div class="rounded-2xl p-3 transition-transform group-hover:scale-110 {badge.unlocked ? 'bg-white/60 text-current' : 'bg-ink-50 text-ink-400'}">
                      <badge.icon size={28} strokeWidth={1.5} />
                    </div>
                    <div>
                      <h4 class="font-bold {badge.unlocked ? 'text-ink-900' : 'text-ink-700'}">
                        {badge.unlocked || cat.id !== 'secret' ? badge.title : '???'}
                      </h4>
                      <p class="mt-1 text-xs leading-relaxed {badge.unlocked ? 'text-ink-600' : 'text-ink-400'}">
                        {badge.unlocked || cat.id !== 'secret' ? badge.description : 'Keep studying to reveal this secret badge.'}
                      </p>
                      
                      {#if badge.unlocked && badge.repeatable && (badge.completions || 0) > 1}
                        <div class="mt-2 inline-flex items-center gap-1 rounded-full bg-white/40 px-2 py-0.5 text-[10px] font-bold text-moss-700 ring-1 ring-moss-200">
                          <Flame size={10} />
                          Earned {badge.completions} times
                        </div>
                      {/if}

                      {#if !badge.unlocked && badge.progress > 0}
                        <div class="mt-3 flex items-center gap-2">
                          <div class="h-1 flex-1 bg-ink-100 rounded-full overflow-hidden">
                            <div class="h-full bg-moss-400/40" style="width: {badge.progress * 100}%"></div>
                          </div>
                          <span class="text-[10px] text-ink-400 font-mono">{Math.round(badge.progress * 100)}%</span>
                        </div>
                      {/if}
                    </div>
                  </div>
                </div>
              {/each}
            </div>
          </div>
        {/if}
      {/each}

    {:else}
      <!-- AI CHALLENGES TAB -->
      <div class="space-y-8">
        <Card>
          <div class="flex items-start gap-4">
            <div class="bg-moss-100 p-3 rounded-2xl text-moss-600 ring-4 ring-moss-50 ring-offset-2 ring-offset-white">
              <Cpu size={24} />
            </div>
            <div>
              <h3 class="text-base font-bold text-ink-900">Smart Challenges</h3>
              <p class="text-sm text-ink-500 mt-1 max-w-xl leading-relaxed">
                Our AI coach analyzes your recent study sessions to generate personalized missions.
                Complete them within the time limit to earn special badges and improve your discipline.
              </p>
            </div>
          </div>
        </Card>

        <div>
          <div class="flex flex-col sm:flex-row sm:flex-wrap sm:items-center gap-3 px-1 mb-4">
            <h3 class="flex items-center gap-2 text-sm font-bold uppercase tracking-wider text-ink-400">
              <Zap size={16} class="text-yellow-500 shrink-0" />
              Current Missions
            </h3>
            <Button variant="secondary" size="sm" onclick={() => refreshSurpriseOnly()}>
              <RefreshCw size={14} class="shrink-0" />
              Refresh surprise
            </Button>
            <span class="hidden sm:block sm:ml-auto h-px flex-1 bg-ink-100 min-w-[2rem]"></span>
          </div>

          <div class="space-y-4">
            {#each tierOrder as tier}
              {@const challenge = slotChallenge(tier)}
              {@const failure = tierFailures[tier]}

              {#if challenge === null && failure}
                <div class="rounded-2xl border-2 border-ink-200 bg-ink-50/40 p-4">
                  <p class="text-xs font-bold text-ink-600">{tierLabel(tier)} · empty slot</p>
                  <p class="text-sm text-ink-500 mt-2">
                    Could not load a new mission. {formatAiChallengeErrorToast(failure)}
                  </p>
                  <Button variant="primary" size="sm" class="mt-3" onclick={() => refreshTierWithConfirm(tier, false)}>
                    Try again
                  </Button>
                </div>
              {:else if challenge === null}
                <div
                  class="rounded-2xl border border-dashed border-ink-200 bg-white/60 px-4 py-3 text-sm text-ink-500"
                >
                  {tierLabel(tier)} — no active mission
                </div>
              {:else}
                {@const prog = aiProgress[challenge.id] ?? {
                  percent: 0,
                  current: 0,
                  target: challenge.target
                }}
                {@const isPinned = activePinnedMissionId === challenge.id}
                {@const expLines = formatMissionExpiry(challenge)}
                {@const expiredWall = new Date(challenge.expiresAt).getTime() <= Date.now()}
                {@const sub = challenge.subTargets}
                {@const breakdown = prog.subjectBreakdown}
                {@const showMulti =
                  sub?.mode === 'any-subjects' && breakdown != null && breakdown.length > 0}
                {@const mps = sub?.minutesPerSubject ?? 1}
                {@const IconComp = (Lucide as Record<string, typeof Target>)[challenge.icon] ?? Target}

                <div
                  class="rounded-[2rem] border-2 {isPinned
                    ? 'border-moss-500/70 shadow-md shadow-moss-500/10'
                    : 'border-moss-500/15'} bg-white p-5 shadow-sm relative overflow-hidden group hover:border-moss-500/35 transition-all"
                >
                  {#if expiredWall}
                    <div
                      class="absolute inset-0 z-10 flex flex-col items-center justify-center gap-2 rounded-[inherit] bg-ink-900/10 backdrop-blur-[1px] px-4"
                    >
                      <span class="text-xs font-bold uppercase tracking-wide text-ink-700">Expired</span>
                      <Button variant="secondary" size="sm" onclick={() => refreshTierWithConfirm(tier, true)}>
                        <RefreshCw size={14} />
                        Refresh
                      </Button>
                    </div>
                  {/if}

                  <div class="flex gap-4">
                    <div
                      class="shrink-0 h-16 w-16 rounded-2xl bg-moss-50 flex items-center justify-center text-moss-600 border border-moss-100"
                    >
                      <IconComp size={32} strokeWidth={1.5} />
                    </div>
                    <div class="flex-1 min-w-0">
                      <div class="flex items-start justify-between gap-2">
                        <div class="min-w-0">
                          <div class="flex items-center gap-2 flex-wrap">
                            {#if isPinned}
                              <span
                                class="inline-flex items-center gap-0.5 rounded-full bg-moss-500 px-2 py-0.5 text-[10px] font-bold text-white"
                              >
                                <Pin size={10} /> Active
                              </span>
                            {/if}
                            <span
                              class="px-2 py-0.5 rounded-md bg-ink-100 text-[10px] font-bold text-ink-500 uppercase"
                              >{tierLabel(tier)}</span
                            >
                            <span
                              class="px-2 py-0.5 rounded-md text-[10px] font-bold uppercase {challenge.difficulty ===
                              'extreme'
                                ? 'bg-red-50 text-red-600'
                                : 'bg-moss-50 text-moss-600'}"
                            >
                              {challenge.difficulty}
                            </span>
                          </div>
                          <h4 class="font-bold text-lg text-ink-900 mt-1 leading-tight">{challenge.title}</h4>
                        </div>
                        <div class="flex items-center gap-0.5 shrink-0">
                          <button
                            type="button"
                            onclick={() => togglePin(challenge.id)}
                            class="p-2 rounded-xl text-ink-400 hover:bg-ink-50 hover:text-moss-600 transition-colors"
                            aria-label={isPinned ? 'Unpin mission' : 'Set active mission'}
                          >
                            {#if isPinned}
                              <PinOff size={18} />
                            {:else}
                              <Pin size={18} />
                            {/if}
                          </button>
                          {#if tier !== 'surprise'}
                            <button
                              type="button"
                              onclick={() => refreshTierWithConfirm(tier, expiredWall)}
                              class="p-2 rounded-xl text-ink-400 hover:bg-ink-50 hover:text-moss-600 transition-colors"
                              title="Refresh this mission"
                            >
                              <RefreshCw size={18} />
                            </button>
                          {/if}
                        </div>
                      </div>

                      <div class="mt-2 space-y-0.5">
                        <p
                          class={expLines.surprise
                            ? 'text-lg font-extrabold text-moss-700 leading-tight'
                            : 'text-sm font-bold text-ink-800'}
                        >
                          {expLines.line1}
                        </p>
                        <p
                          class={expLines.surprise
                            ? 'text-sm font-semibold text-ink-600'
                            : 'text-xs text-ink-500'}
                        >
                          {expLines.line2}
                        </p>
                      </div>

                      <p class="text-sm text-ink-500 leading-relaxed mt-3">{challenge.description}</p>

                      <div class="mt-4 space-y-3">
                        {#if showMulti}
                          {#each breakdown! as row}
                            <div class="space-y-1">
                              <div class="flex justify-between gap-2 text-[11px] font-semibold text-ink-600">
                                <span class="truncate">{row.subjectName ?? `Subject ${row.subjectId}`}</span>
                                <span class="shrink-0 font-mono">{row.minutes}/{mps} min</span>
                              </div>
                              <div class="h-2 w-full bg-ink-100 rounded-full overflow-hidden">
                                <div
                                  class="h-full rounded-full transition-all {row.completed
                                    ? 'bg-moss-500'
                                    : 'bg-moss-400/80'}"
                                  style="width: {Math.min(100, mps > 0 ? (row.minutes / mps) * 100 : 0)}%"
                                ></div>
                              </div>
                            </div>
                          {/each}
                          <p class="text-[11px] font-bold text-moss-700">
                            {prog.current} of {sub!.count} subjects complete
                          </p>
                          <div class="h-2.5 w-full bg-ink-100 rounded-full overflow-hidden">
                            <div
                              class="h-full bg-moss-500 rounded-full transition-all"
                              style="width: {prog.percent}%"
                            ></div>
                          </div>
                        {:else}
                          <div class="flex justify-between text-[11px] font-bold text-ink-600">
                            <span>Progress</span>
                            <span class="font-mono tracking-tight">
                              {prog.current} / {challenge.target}
                              {metricLabel(challenge.metric)} · {prog.percent}%
                            </span>
                          </div>
                          <div class="h-2.5 w-full bg-ink-100 rounded-full overflow-hidden">
                            <div
                              class="h-full bg-moss-500 rounded-full transition-all"
                              style="width: {prog.percent}%"
                            ></div>
                          </div>
                        {/if}
                      </div>

                      <p class="mt-4 text-xs font-bold text-ink-700 border-t border-ink-100 pt-3">
                        Reward: <span class="text-moss-700">{challenge.rewardBadgeName}</span>
                      </p>
                    </div>
                  </div>
                </div>
              {/if}
            {/each}
          </div>
        </div>

        {#if missionHistory.length > 0}
          <details
            class="rounded-2xl border border-ink-200 bg-ink-50/30 overflow-hidden group"
            bind:open={pastMissionsOpen}
          >
            <summary
              class="cursor-pointer list-none px-4 py-3 text-sm font-bold text-ink-700 flex items-center gap-2 select-none hover:bg-ink-50/50"
            >
              <History size={16} class="shrink-0 text-ink-400" />
              Past Missions ({missionHistory.length})
              <span class="ml-auto text-ink-400 text-xs font-medium group-open:hidden">Show</span>
              <span class="ml-auto text-ink-400 text-xs font-medium hidden group-open:inline">Hide</span>
            </summary>
            <div class="border-t border-ink-100 px-3 py-2 space-y-1 max-h-[min(24rem,50vh)] overflow-y-auto">
              {#each missionHistory as h}
                <div
                  class="flex flex-col sm:flex-row sm:items-center gap-2 sm:gap-3 py-2 px-1 border-b border-ink-100/80 last:border-0 text-sm"
                >
                  <span
                    class="inline-flex self-start px-2 py-0.5 rounded-md bg-ink-100 text-[10px] font-bold uppercase text-ink-600"
                    >{tierLabel(h.tier)}</span
                  >
                  <div class="flex-1 min-w-0">
                    <p class="font-bold text-ink-900 truncate">{h.title}</p>
                    <p class="text-[11px] text-ink-500">
                      {historyProgressLabel(h.metric, h.progressAtClose, h.target)}
                      · {new Date(h.closedAt).toLocaleString([], { dateStyle: 'medium', timeStyle: 'short' })}
                    </p>
                  </div>
                  <span
                    class="self-start text-[10px] font-bold uppercase px-2 py-0.5 rounded-full border {h.closeReason ===
                    'completed'
                      ? 'border-moss-200 bg-moss-50 text-moss-800'
                      : h.closeReason === 'expired'
                        ? 'border-ink-200 bg-white text-ink-600'
                        : 'border-amber-200 bg-amber-50 text-amber-800'}"
                  >
                    {h.closeReason}
                  </span>
                </div>
              {/each}
            </div>
          </details>
        {/if}

        {#if completedAiChallenges.length > 0}
          <div>
            <h3 class="flex items-center gap-2 text-sm font-bold uppercase tracking-wider text-ink-400 px-1 mb-4">
              <Award size={16} class="text-moss-500" /> Completed Challenges
              <span class="ml-2 h-px flex-1 bg-ink-100"></span>
            </h3>

            <div class="grid gap-3 md:grid-cols-3">
              {#each completedAiChallenges as challenge}
                <div class="rounded-2xl border border-moss-200 bg-moss-50 p-4 flex items-center gap-4">
                  <div class="bg-white p-2 rounded-xl text-moss-500">
                    <Award size={20} />
                  </div>
                  <div>
                    <p class="text-xs font-bold text-ink-900 leading-tight">{challenge.rewardBadgeName}</p>
                    <p class="text-[10px] text-ink-500 mt-0.5">{challenge.title}</p>
                  </div>
                </div>
              {/each}
            </div>
          </div>
        {/if}
      </div>
    {/if}

  {/if}
</div>
