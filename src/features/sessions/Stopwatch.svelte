<script lang="ts">
  import { stopwatch, stopwatchDisplay, formatLapTime } from '@/core/stores/stopwatchStore';
  import { settings } from '@/core/stores/settingsStore';
  import { Play, Pause, RotateCcw, Flag, Maximize2, Minimize2, Image as ImageIcon } from 'lucide-svelte';
  import { portal } from '@/core/utils/portal';
  import { onMount } from 'svelte';

  let backgroundImage = $state('/backgrounds/cozy-cafe.png');
  let overlayOpacity = $state(0.45);
  let customBgFile: string | null = $state(null);
  let isFullscreen = $state(false);

  const backgrounds = [
    { value: '/backgrounds/city-twilight.png', label: 'City Twilight' },
    { value: '/backgrounds/cozy-cafe.png', label: 'Cozy Café' }
  ];

  onMount(async () => {
    await settings.load();
    overlayOpacity = settings.get().overlayOpacity ?? 0.45;
  });

  function handleCustomBg(e: Event) {
    const input = e.target as HTMLInputElement;
    if (input.files && input.files[0]) {
      const reader = new FileReader();
      reader.onload = () => { customBgFile = reader.result as string; };
      reader.readAsDataURL(input.files[0]);
    }
  }

  const effectiveBg = $derived(customBgFile || backgroundImage);
</script>

<svelte:window
  onkeydown={(e) => { if (e.key === 'Escape' && isFullscreen) isFullscreen = false; }}
/>

<!-- ═══════════════════ FULLSCREEN ═══════════════════ -->
{#if isFullscreen}
  <div
    use:portal
    class="fixed inset-0 z-[9999] flex flex-col"
    style="background-image: url('{effectiveBg}'); background-size: cover; background-position: center;"
  >
    <!-- Overlay -->
    <div class="absolute inset-0 bg-black" style="opacity: {overlayOpacity};"></div>

    <!-- Top bar -->
    <div class="relative z-10 flex items-center justify-between px-6 pt-5">
      <div class="flex items-center gap-2 rounded-full border border-white/15 bg-black/30 px-4 py-2 text-sm text-white backdrop-blur-md">
        <Flag size={14} /> Stopwatch
        {#if $stopwatch.laps.length > 0}
          <span class="rounded-full bg-white/15 px-2.5 py-0.5 text-xs">{$stopwatch.laps.length} laps</span>
        {/if}
      </div>

      <button
        onclick={() => (isFullscreen = false)}
        class="flex items-center gap-1.5 rounded-full border border-white/20 bg-black/30 px-4 py-2 text-sm text-white/80 backdrop-blur-md hover:bg-black/50 transition-colors"
      >
        <Minimize2 size={14} /> Exit fullscreen
      </button>
    </div>

    <!-- Giant clock -->
    <div class="relative z-10 flex flex-1 flex-col items-center justify-center gap-4 text-white">
      <p class="text-[clamp(6rem,16vw,12rem)] font-thin leading-none tabular-nums drop-shadow-2xl">
        {$stopwatchDisplay}
      </p>

      <!-- Controls — all states covered -->
      <div class="mt-6 flex flex-wrap items-center justify-center gap-4">
        {#if $stopwatch.state === 'idle'}
          <button
            onclick={() => stopwatch.start()}
            class="flex items-center gap-2 rounded-full bg-white px-10 py-4 text-base font-semibold text-neutral-900 shadow-xl hover:bg-white/90 transition-all hover:scale-105"
          >
            <Play size={18} /> Start
          </button>
        {:else if $stopwatch.state === 'running'}
          <button
            onclick={() => stopwatch.lap()}
            class="flex items-center gap-2 rounded-full border border-white/20 bg-black/30 px-10 py-4 text-base text-white backdrop-blur-md hover:bg-black/50 transition-all"
          >
            <Flag size={18} /> Lap
          </button>
          <button
            onclick={() => stopwatch.pause()}
            class="flex items-center gap-2 rounded-full bg-white px-10 py-4 text-base font-semibold text-neutral-900 shadow-xl hover:bg-white/90 transition-all"
          >
            <Pause size={18} /> Stop
          </button>
        {:else}
          <!-- Paused -->
          <button
            onclick={() => stopwatch.start()}
            class="flex items-center gap-2 rounded-full bg-white px-10 py-4 text-base font-semibold text-neutral-900 shadow-xl hover:bg-white/90 transition-all"
          >
            <Play size={18} /> Resume
          </button>
          <button
            onclick={() => stopwatch.reset()}
            class="flex items-center gap-2 rounded-full border border-white/20 bg-black/30 px-10 py-4 text-base text-white backdrop-blur-md hover:bg-black/50 transition-all"
          >
            <RotateCcw size={18} /> Reset
          </button>
        {/if}
      </div>

      <!-- Lap list (in fullscreen) -->
      {#if $stopwatch.laps.length > 0}
        <div class="mt-6 w-full max-w-xs max-h-40 overflow-y-auto rounded-2xl border border-white/10 bg-black/30 backdrop-blur-md">
          {#each [...$stopwatch.laps].reverse() as lap}
            <div class="flex justify-between px-5 py-3 text-sm border-b border-white/5 last:border-0">
              <span class="text-white/50">Lap {lap.number}</span>
              <span class="font-mono text-white/50">{formatLapTime(lap.splitMs)}</span>
              <span class="font-mono text-white">{formatLapTime(lap.totalMs)}</span>
            </div>
          {/each}
        </div>
      {/if}
    </div>

    <!-- Bottom: background picker -->
    <div class="relative z-10 flex items-center justify-center gap-3 pb-5">
      {#each backgrounds as bg}
        <button
          class="rounded-full px-3 py-1.5 text-xs transition-all
                 {effectiveBg === bg.value && !customBgFile
                   ? 'bg-white/20 text-white'
                   : 'text-white/30 hover:text-white/60'}"
          onclick={() => { backgroundImage = bg.value; customBgFile = null; }}
        >
          {bg.label}
        </button>
      {/each}
      <label class="flex cursor-pointer items-center gap-1 rounded-full px-3 py-1.5 text-xs text-white/30 hover:text-white/60">
        <ImageIcon size={11} /> Custom
        <input type="file" accept="image/*" onchange={handleCustomBg} class="hidden" />
      </label>
    </div>
  </div>

<!-- ═══════════════════ NORMAL CARD ═══════════════════ -->
{:else}
  <div class="rounded-[1.5rem] border border-ink-200 bg-white shadow-card overflow-hidden">

    <!-- Image strip -->
    <div class="relative overflow-hidden" style="height: 220px;">
      <img src={effectiveBg} alt="" class="absolute inset-0 h-full w-full object-cover" />
      <div class="absolute inset-0 bg-black" style="opacity: {overlayOpacity};"></div>

      <!-- Fullscreen toggle — z-20 above the z-10 content layer -->
      <button
        onclick={() => (isFullscreen = true)}
        class="absolute right-3 top-3 z-20 flex items-center gap-1.5 rounded-full border border-white/20 bg-black/30 px-3 py-1.5 text-xs text-white/70 backdrop-blur-sm hover:bg-black/50 transition-colors"
      >
        <Maximize2 size={12} /> Fullscreen
      </button>

      <!-- Stopwatch display -->
      <div class="absolute inset-0 z-10 flex flex-col items-center justify-center gap-2.5 text-white">
        <div class="flex items-center gap-2 rounded-full border border-white/15 bg-black/30 px-3 py-1.5 text-xs backdrop-blur-sm">
          <Flag size={12} /> Stopwatch
          {#if $stopwatch.laps.length > 0}
            <span class="text-white/60">· {$stopwatch.laps.length} laps</span>
          {/if}
        </div>
        <p class="text-6xl font-thin tabular-nums drop-shadow-lg">{$stopwatchDisplay}</p>
      </div>
    </div>

    <!-- Controls -->
    <div class="p-4 space-y-3">
      <div class="flex flex-wrap items-center gap-2">
        {#if $stopwatch.state === 'idle'}
          <button
            onclick={() => stopwatch.start()}
            class="flex items-center gap-2 rounded-2xl bg-moss-600 px-6 py-2.5 text-sm font-semibold text-white hover:bg-moss-500 transition-all hover:-translate-y-px"
          >
            <Play size={15} /> Start
          </button>
        {:else if $stopwatch.state === 'running'}
          <button
            onclick={() => stopwatch.lap()}
            class="flex items-center gap-2 rounded-2xl border border-ink-200 px-5 py-2.5 text-sm font-medium text-ink-700 hover:bg-ink-100"
          >
            <Flag size={14} /> Lap
          </button>
          <button
            onclick={() => stopwatch.pause()}
            class="flex items-center gap-2 rounded-2xl bg-moss-600 px-5 py-2.5 text-sm font-semibold text-white hover:bg-moss-500"
          >
            <Pause size={14} /> Stop
          </button>
        {:else}
          <button
            onclick={() => stopwatch.start()}
            class="flex items-center gap-2 rounded-2xl bg-moss-600 px-5 py-2.5 text-sm font-semibold text-white hover:bg-moss-500"
          >
            <Play size={14} /> Resume
          </button>
          <button
            onclick={() => stopwatch.reset()}
            class="flex items-center gap-2 rounded-2xl border border-ink-200 px-5 py-2.5 text-sm text-ink-700 hover:bg-ink-100"
          >
            <RotateCcw size={14} /> Reset
          </button>
        {/if}
      </div>

      <!-- Lap list -->
      {#if $stopwatch.laps.length > 0}
        <div class="max-h-36 overflow-y-auto rounded-2xl border border-ink-100">
          {#each [...$stopwatch.laps].reverse() as lap}
            <div class="flex justify-between border-b border-ink-50 px-4 py-2.5 text-sm last:border-0">
              <span class="text-ink-400">Lap {lap.number}</span>
              <span class="font-mono text-ink-500">{formatLapTime(lap.splitMs)}</span>
              <span class="font-mono font-medium text-ink-900">{formatLapTime(lap.totalMs)}</span>
            </div>
          {/each}
        </div>
      {/if}

      <!-- Background picker -->
      <div class="flex flex-wrap items-center gap-2 border-t border-ink-100 pt-3">
        <span class="text-xs text-ink-400">Background:</span>
        {#each backgrounds as bg}
          <button
            class="rounded-lg px-2.5 py-1 text-xs transition-all
                   {effectiveBg === bg.value && !customBgFile
                     ? 'bg-moss-100 text-moss-700 font-medium'
                     : 'text-ink-400 hover:bg-ink-100'}"
            onclick={() => { backgroundImage = bg.value; customBgFile = null; }}
          >
            {bg.label}
          </button>
        {/each}
        <label class="flex cursor-pointer items-center gap-1 rounded-lg px-2.5 py-1 text-xs text-ink-400 hover:bg-ink-100">
          <ImageIcon size={11} /> Custom
          <input type="file" accept="image/*" onchange={handleCustomBg} class="hidden" />
        </label>
      </div>
    </div>
  </div>
{/if}
