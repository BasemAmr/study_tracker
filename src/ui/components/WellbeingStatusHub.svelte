<script lang="ts">
  import {
    Flame,
    Zap,
    Sparkles,
    BatteryWarning,
    Award
  } from 'lucide-svelte';

  import type { StreakMilestoneHudModel } from '@/core/utils/streakMilestoneHud';

  export let state: 'proud' | 'flow' | 'burnout' | 'idle' = 'flow';
  export let currentStreak = 0;
  export let streakHud: StreakMilestoneHudModel;

  /** Width % for progress strip (SSR-safe rounding). */
  $: streakBarPct = `${Math.round(streakHud.progress01 * 100)}%`;

  const energyConfigs = {
    flow: {
      title: 'The Flow State',
      micro: "Today's energy",
      pillMeta: 'Optimal focus',
      body: 'Long focus today — rides the edge of challenge without overwhelm.',
      icon: Zap,
      panel: 'bg-moss-600 text-white',
      iconWrap: 'bg-white text-moss-600 border-ink-900',
      bodyClass: 'text-moss-100'
    },
    proud: {
      title: 'Proud Scholar',
      micro: "Today's energy",
      pillMeta: 'Streak crest',
      body: 'Streak muscle is forged — savor the grind, shield your recovery windows.',
      icon: Award,
      panel: 'bg-amber-50 text-ink-900',
      iconWrap: 'bg-amber-100 text-amber-700 border-ink-900',
      bodyClass: 'text-ink-600'
    },
    burnout: {
      title: 'Recovery checkpoint',
      micro: "Today's energy",
      pillMeta: 'Rest guarded',
      body: 'High volume logged — hydrate, shorten the next sprint, defend sleep.',
      icon: BatteryWarning,
      panel: 'bg-ink-50 text-ink-900',
      iconWrap: 'bg-white text-ink-500 border-ink-900',
      bodyClass: 'text-ink-600'
    },
    idle: {
      title: 'Gentle nudge',
      micro: "Today's energy",
      pillMeta: 'Ready to ignite',
      body: 'No deep work tracked yet — a single focused block unlocks streak fuel.',
      icon: Sparkles,
      panel: 'bg-white text-ink-900',
      iconWrap: 'bg-moss-50 text-moss-700 border-ink-900',
      bodyClass: 'text-ink-600'
    }
  } as const;

  $: energy = energyConfigs[state];
</script>

<div
  class="rounded-3xl border-2 border-ink-900 bg-moss-50/40 p-4 shadow-[0_4px_0_0_#2c352c]"
>
  <div class="grid gap-3 md:grid-cols-2">
    <!-- Streak runway -->
    <div
      class="flex flex-col justify-between rounded-2xl border-2 border-ink-900 bg-white p-4 shadow-[0_3px_0_0_#2c352c]"
    >
      <div class="flex items-start justify-between gap-3">
        <div>
          <p
            class="font-mono text-[10px] font-bold tracking-[0.2em] text-moss-600"
          >
            STREAK RUNWAY
          </p>
          <div class="mt-2 flex items-baseline gap-2">
            <span class="font-headline text-4xl font-bold tabular-nums text-ink-900">
              {currentStreak}
            </span>
            <span class="text-sm font-medium text-ink-500">days hot</span>
          </div>
          <p class="mt-3 font-semibold leading-snug text-ink-900">
            {streakHud.tierTitle}
          </p>
        </div>
        <div
          class="flex h-14 w-14 shrink-0 items-center justify-center rounded-xl border-2 border-ink-900 bg-orange-50 text-orange-600"
        >
          <Flame size={28} strokeWidth={2.2} class="-translate-y-px" />
        </div>
      </div>
      <p class="mt-3 text-sm leading-snug text-ink-600">
        {streakHud.chaseLine}
      </p>
      {#if streakHud.nextCheckpointDays != null}
        <div class="mt-4">
          <div
            class="flex justify-between font-mono text-[10px] font-bold uppercase tracking-wider text-ink-400"
          >
            <span>Next crest</span>
            <span>
              {#if streakHud.daysToNext != null}
                {streakHud.daysToNext} day{streakHud.daysToNext === 1 ? '' : 's'} out
              {/if}
            </span>
          </div>
          <div
            class="mt-1 h-2.5 overflow-hidden rounded-full border-2 border-ink-900 bg-moss-100"
          >
            <div
              class="h-full rounded-full bg-gradient-to-r from-amber-400 to-orange-500 transition-[width] duration-500"
              style:width={streakBarPct}
            ></div>
          </div>
          <p class="mt-2 font-mono text-[11px] text-ink-500">
            Personal best streak · {streakHud.personalBest} days
          </p>
        </div>
      {:else}
        <div class="mt-4 rounded-xl bg-moss-50 px-3 py-2 border border-moss-200">
          <p class="font-mono text-[10px] font-bold uppercase tracking-wider text-moss-700">
            Ladder cleared
          </p>
          <p class="mt-1 text-sm text-ink-700">
            Personal best · <span class="font-semibold">{streakHud.personalBest} days</span>
          </p>
        </div>
      {/if}
    </div>

    <!-- Today's energy -->
    <div
      class="flex flex-col justify-between rounded-2xl border-2 border-ink-900 p-4 shadow-[0_3px_0_0_#2c352c] {energy.panel}"
    >
      <div class="flex gap-4">
        <div
          class="flex h-14 w-14 shrink-0 items-center justify-center rounded-xl border-2 border-ink-900 {energy.iconWrap}"
        >
          <svelte:component this={energy.icon} size={26} strokeWidth={2.3} />
        </div>
        <div class="min-w-0 flex-1">
          <p
            class={`font-mono text-[10px] font-bold tracking-[0.2em] ${state === 'flow' ? 'text-moss-200' : state === 'proud' ? 'text-amber-700/80' : state === 'burnout' ? 'text-ink-400' : 'text-moss-600'}`}
          >
            {energy.micro.toUpperCase()}
          </p>
          <h3 class="font-headline mt-1 text-xl font-bold leading-tight">
            {energy.title}
          </h3>
        </div>
      </div>
      <p class={`mt-3 text-sm leading-relaxed ${energy.bodyClass}`}>{energy.body}</p>
      <!-- Rule chips: readable “tutorialization” matching Flutter -->
      <div class="mt-4 flex flex-wrap gap-2">
        <span
          class={`rounded-full border-2 px-2.5 py-1 font-mono text-[10px] font-bold uppercase tracking-wide ${
            state === 'flow'
              ? 'border-white/35 bg-white/15 text-white'
              : 'border-ink-200 bg-moss-50/80 text-ink-700'
          }`}
        >
          {energy.pillMeta}
        </span>
        <span
          class={`rounded-full border px-2.5 py-1 text-[11px] font-semibold ${
            state === 'flow' ? 'border-white/35 text-moss-100' : 'border-ink-200 text-ink-600'
          }`}
        >
          Flow ≥120m today
        </span>
        <span
          class={`rounded-full border px-2.5 py-1 text-[11px] font-semibold ${
            state === 'flow' ? 'border-white/35 text-moss-100' : 'border-ink-200 text-ink-600'
          }`}
        >
          Fatigue watch &gt;360m
        </span>
      </div>
    </div>
  </div>
</div>
