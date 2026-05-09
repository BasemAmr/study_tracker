<script lang="ts">
  import { ArrowUp, ArrowDown } from 'lucide-svelte';

  export let deepWorkVolume = '0h 0m';
  export let deepWorkComparison = '+0h 0m';
  export let avgSession = '0m';
  export let avgSessionComparison = '+0m';
  export let completionRate = '0%';
  export let completionStatus = 'SOLID';

  $: dwVolumePositive = deepWorkComparison.startsWith('+');
  $: avgSessionPositive = avgSessionComparison.startsWith('+');
  $: avgSessionNeutral = avgSessionComparison.startsWith('-');
  $: completionPositive = completionStatus === 'SOLID' || completionStatus === 'EXCELLENT';
</script>

<div class="rounded-2xl border-2 border-ink-900 bg-white p-6 shadow-[0_4px_0_0_#2c352c] w-full">
  <div class="mb-6 flex items-center justify-between">
    <h4 class="font-headline text-xl font-bold text-ink-900">Me vs. Past Self</h4>
    <span class="rounded bg-ink-50 px-2 py-1 border-2 border-ink-900 font-mono text-[10px] font-bold text-ink-900">THIS WEEK</span>
  </div>

  <div class="space-y-6">
    <!-- Deep Work -->
    <div class="flex items-end justify-between border-b-2 border-ink-900 pb-4">
      <div>
        <p class="mb-1 font-mono text-[10px] text-ink-500">DEEP WORK VOLUME</p>
        <p class="font-headline text-2xl font-bold text-ink-900">{deepWorkVolume}</p>
      </div>
      <div class="text-right">
        <p class="mb-1 font-mono text-[10px] text-ink-500">LAST WEEK</p>
        <p class="font-mono text-sm font-bold {dwVolumePositive ? 'text-moss-600' : 'text-amber-600'}">
          {deepWorkComparison}
        </p>
      </div>
    </div>

    <!-- Avg Session -->
    <div class="flex items-end justify-between border-b-2 border-ink-900 pb-4">
      <div>
        <p class="mb-1 font-mono text-[10px] text-ink-500">AVERAGE FOCUS SESSION</p>
        <p class="font-headline text-2xl font-bold text-ink-900">{avgSession}</p>
      </div>
      <div class="text-right">
        <p class="mb-1 font-mono text-[10px] text-ink-500">LAST WEEK</p>
        <p class="font-mono text-sm font-bold {avgSessionPositive ? 'text-moss-600' : (avgSessionNeutral ? 'text-ink-400' : 'text-amber-600')}">
          {avgSessionComparison}
        </p>
      </div>
    </div>

    <!-- Completion -->
    <div class="flex items-end justify-between">
      <div>
        <p class="mb-1 font-mono text-[10px] text-ink-500">COMPLETION RATE</p>
        <p class="font-headline text-2xl font-bold text-ink-900">{completionRate}</p>
      </div>
      <div class="flex items-center gap-1">
        {#if completionPositive}
          <ArrowUp size={16} class="text-moss-600" />
        {:else}
          <ArrowDown size={16} class="text-amber-600" />
        {/if}
        <p class="font-mono text-sm font-bold {completionPositive ? 'text-moss-600' : 'text-amber-600'}">
          {completionStatus}
        </p>
      </div>
    </div>
  </div>
</div>
