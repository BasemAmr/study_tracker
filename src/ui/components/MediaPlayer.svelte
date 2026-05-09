<script lang="ts">
  /**
   * Floating mini player — always rendered in App.svelte.
   * Shows as a pill bar at bottom-left when tracks are loaded.
   * Expands to a full panel on demand.
   */
  import {
    mediaPlayer, isPlayerActive, currentTrackName, formatPlayerTime,
    type Track
  } from '@/core/stores/mediaPlayerStore';
  import {
    Play, Pause, SkipBack, SkipForward, Volume2, VolumeX,
    ChevronDown, Music, RotateCcw, FastForward
  } from 'lucide-svelte';

  let showPanel = $state(false);
  let seeking = $state(false);          // whether user is dragging the scrub bar

  function handleFiles(e: Event) {
    const input = e.target as HTMLInputElement;
    if (input.files && input.files.length > 0) {
      mediaPlayer.loadFiles(Array.from(input.files));
    }
  }

  // ── Scrub bar helpers ────────────────────────────────────────
  function scrubStart(e: PointerEvent) {
    if ($mediaPlayer.duration <= 0) return;
    seeking = true;
    scrubMove(e);
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
  }

  function scrubMove(e: PointerEvent) {
    if (!seeking || $mediaPlayer.duration <= 0) return;
    const bar = e.currentTarget as HTMLElement;
    const rect = bar.getBoundingClientRect();
    const ratio = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
    mediaPlayer.seek(ratio * $mediaPlayer.duration);
  }

  function scrubEnd() {
    seeking = false;
  }

  const progressPct = $derived(
    $mediaPlayer.duration > 0
      ? ($mediaPlayer.currentTime / $mediaPlayer.duration) * 100
      : 0
  );
</script>

<!-- Always rendered; only visible when tracks are loaded OR panel is open -->
<div class="fixed bottom-4 left-4 z-[200]">

  <!-- ═══ Expanded panel ═══ -->
  {#if showPanel}
    <div class="mb-2 w-80 rounded-2xl border border-white/10 bg-neutral-900/95 backdrop-blur-xl shadow-2xl overflow-hidden">

      <!-- Panel header -->
      <div class="flex items-center justify-between px-4 py-3 border-b border-white/5">
        <div class="flex items-center gap-2 text-white/80">
          <Music size={14} />
          <span class="text-xs font-semibold uppercase tracking-widest">Media Player</span>
        </div>
        <button
          onclick={() => (showPanel = false)}
          class="rounded-lg p-1 text-white/40 hover:text-white transition-colors"
          aria-label="Collapse"
        >
          <ChevronDown size={16} />
        </button>
      </div>

      <!-- Track list / empty state -->
      {#if $mediaPlayer.tracks.length === 0}
        <label class="flex cursor-pointer flex-col items-center justify-center gap-2 py-8 text-white/40 hover:text-white/60 transition-colors">
          <input type="file" accept="audio/*,video/*" multiple onchange={handleFiles} class="hidden" />
          <Music size={24} strokeWidth={1.5} />
          <span class="text-xs">Click to add audio files</span>
          <span class="text-[10px] text-white/30">mp3, m4a, wav, ogg, mp4…</span>
        </label>
      {:else}
        <!-- Track list -->
        <div class="max-h-40 overflow-y-auto py-1 scrollbar-thin">
          {#each $mediaPlayer.tracks as track, i}
            <button
              class="flex w-full items-center gap-3 px-4 py-2.5 text-left text-xs transition-colors {i === $mediaPlayer.currentIndex
                ? 'bg-white/10 text-white font-medium'
                : 'text-white/50 hover:bg-white/5 hover:text-white/80'}"
              onclick={() => mediaPlayer.jumpTo(i)}
            >
              <div class="h-4 w-4 shrink-0 flex items-center justify-center">
                {#if i === $mediaPlayer.currentIndex && $mediaPlayer.state === 'playing'}
                  <div class="flex gap-0.5 items-end h-3">
                    <div class="w-0.5 rounded-full bg-green-400 animate-bar1"></div>
                    <div class="w-0.5 rounded-full bg-green-400 animate-bar2"></div>
                    <div class="w-0.5 rounded-full bg-green-400 animate-bar3"></div>
                  </div>
                {:else}
                  <span class="text-[10px] text-white/30">{i + 1}</span>
                {/if}
              </div>
              <span class="truncate">{track.name}</span>
            </button>
          {/each}
        </div>

        <!-- Add more -->
        <label class="flex cursor-pointer items-center justify-center gap-1.5 border-t border-white/5 py-2 text-[10px] text-white/30 hover:text-white/50 transition-colors">
          <input type="file" accept="audio/*,video/*" multiple onchange={handleFiles} class="hidden" />
          + Add more files
        </label>
      {/if}

      <!-- ── Full controls (only when tracks loaded) ── -->
      {#if $mediaPlayer.tracks.length > 0}

        <!-- Current track name -->
        <div class="px-4 pt-3 pb-1">
          <p class="truncate text-xs font-medium text-white/80">{$currentTrackName}</p>
        </div>

        <!-- ── Scrubable progress bar ── -->
        <div class="px-4 py-2">
          <div class="flex items-center gap-2">
            <span class="text-[10px] tabular-nums text-white/40 w-8 shrink-0">
              {formatPlayerTime($mediaPlayer.currentTime)}
            </span>

            <!-- Scrub track -->
            <div
              role="slider"
              aria-valuemin={0}
              aria-valuemax={$mediaPlayer.duration}
              aria-valuenow={$mediaPlayer.currentTime}
              tabindex="0"
              class="relative flex-1 h-2 rounded-full bg-white/10 cursor-pointer group"
              onpointerdown={scrubStart}
              onpointermove={scrubMove}
              onpointerup={scrubEnd}
              onpointercancel={scrubEnd}
              onkeydown={(e) => {
                if (e.key === 'ArrowLeft') mediaPlayer.rewind10();
                if (e.key === 'ArrowRight') mediaPlayer.skip10();
              }}
            >
              <!-- Filled portion -->
              <div
                class="absolute inset-y-0 left-0 rounded-full bg-white/60 transition-none"
                style="width: {progressPct}%"
              ></div>
              <!-- Thumb knob -->
              <div
                class="absolute top-1/2 -translate-y-1/2 h-3 w-3 rounded-full bg-white shadow opacity-0 group-hover:opacity-100 transition-opacity"
                style="left: calc({progressPct}% - 6px)"
              ></div>
            </div>

            <span class="text-[10px] tabular-nums text-white/40 w-8 shrink-0 text-right">
              {formatPlayerTime($mediaPlayer.duration)}
            </span>
          </div>
        </div>

        <!-- ── Transport controls ── -->
        <div class="flex items-center justify-between px-4 pb-3">
          <!-- Prev track -->
          <button
            onclick={() => mediaPlayer.prev()}
            class="rounded-lg p-1.5 text-white/40 hover:text-white transition-colors"
            title="Previous track"
          >
            <SkipBack size={14} />
          </button>

          <!-- Rewind 10 s -->
          <button
            onclick={() => mediaPlayer.rewind10()}
            class="flex flex-col items-center gap-0.5 rounded-lg px-1.5 py-1 text-white/50 hover:text-white transition-colors"
            title="Rewind 10 seconds"
          >
            <RotateCcw size={14} />
            <span class="text-[8px] leading-none">10</span>
          </button>

          <!-- Play / Pause -->
          <button
            onclick={() => mediaPlayer.toggle()}
            class="flex h-9 w-9 items-center justify-center rounded-full bg-white text-neutral-900 shadow hover:scale-105 transition-transform"
            aria-label="{$mediaPlayer.state === 'playing' ? 'Pause' : 'Play'}"
          >
            {#if $mediaPlayer.state === 'playing'}
              <Pause size={16} />
            {:else}
              <Play size={16} class="translate-x-px" />
            {/if}
          </button>

          <!-- Skip 10 s -->
          <button
            onclick={() => mediaPlayer.skip10()}
            class="flex flex-col items-center gap-0.5 rounded-lg px-1.5 py-1 text-white/50 hover:text-white transition-colors"
            title="Skip 10 seconds"
          >
            <FastForward size={14} />
            <span class="text-[8px] leading-none">10</span>
          </button>

          <!-- Next track -->
          <button
            onclick={() => mediaPlayer.next()}
            class="rounded-lg p-1.5 text-white/40 hover:text-white transition-colors"
            title="Next track"
          >
            <SkipForward size={14} />
          </button>
        </div>

        <!-- ── Volume row ── -->
        <div class="flex items-center gap-2 border-t border-white/5 px-4 py-2.5">
          <button
            onclick={() => mediaPlayer.toggleMute()}
            class="shrink-0 text-white/40 hover:text-white transition-colors"
            aria-label="Mute"
          >
            {#if $mediaPlayer.muted || $mediaPlayer.volume === 0}
              <VolumeX size={13} />
            {:else}
              <Volume2 size={13} />
            {/if}
          </button>
          <input
            type="range" min="0" max="1" step="0.02"
            value={$mediaPlayer.volume}
            oninput={(e) => mediaPlayer.setVolume(parseFloat((e.target as HTMLInputElement).value))}
            class="flex-1 h-1 accent-white/60 cursor-pointer"
          />
          <span class="text-[10px] text-white/30 w-6 text-right">
            {Math.round($mediaPlayer.volume * 100)}
          </span>
        </div>

      {/if}
    </div>
  {/if}

  <!-- ═══ Floating pill bar ═══ -->
  <div
    class="flex items-center gap-1 rounded-2xl border border-white/10 bg-neutral-900/95 backdrop-blur-xl px-3 py-2 shadow-2xl
           {$isPlayerActive ? 'opacity-100' : 'opacity-60 hover:opacity-100'}"
  >
    <!-- Toggle panel -->
    <button
      onclick={() => (showPanel = !showPanel)}
      class="flex items-center gap-2 text-white/70 hover:text-white transition-colors group"
      aria-label="Toggle playlist"
    >
      <Music size={14} class="shrink-0" />
      {#if $isPlayerActive}
        <span class="max-w-[100px] truncate text-xs text-white/60 group-hover:text-white/80">
          {$currentTrackName || 'No track'}
        </span>
      {:else}
        <span class="text-xs text-white/40">No media</span>
      {/if}
    </button>

    {#if $isPlayerActive}
      <div class="mx-1 h-4 border-l border-white/10"></div>

      <!-- Pill: tiny scrub bar -->
      <div
        role="slider"
        aria-valuemin={0}
        aria-valuemax={$mediaPlayer.duration}
        aria-valuenow={$mediaPlayer.currentTime}
        tabindex="0"
        class="relative w-16 h-1 rounded-full bg-white/10 cursor-pointer group/pill"
        onpointerdown={scrubStart}
        onpointermove={scrubMove}
        onpointerup={scrubEnd}
        onpointercancel={scrubEnd}
        title="{formatPlayerTime($mediaPlayer.currentTime)} / {formatPlayerTime($mediaPlayer.duration)}"
      >
        <div
          class="absolute inset-y-0 left-0 rounded-full bg-white/50 transition-none"
          style="width: {progressPct}%"
        ></div>
      </div>

      <div class="mx-1 h-4 border-l border-white/10"></div>

      <button onclick={() => mediaPlayer.prev()} class="rounded-lg p-1.5 text-white/50 hover:text-white transition-colors" aria-label="Previous">
        <SkipBack size={13} />
      </button>

      <button
        onclick={() => mediaPlayer.toggle()}
        class="flex h-7 w-7 items-center justify-center rounded-full bg-white/15 text-white hover:bg-white/25 transition-colors"
        aria-label="{$mediaPlayer.state === 'playing' ? 'Pause' : 'Play'}"
      >
        {#if $mediaPlayer.state === 'playing'}
          <Pause size={14} />
        {:else}
          <Play size={14} class="translate-x-px" />
        {/if}
      </button>

      <button onclick={() => mediaPlayer.next()} class="rounded-lg p-1.5 text-white/50 hover:text-white transition-colors" aria-label="Next">
        <SkipForward size={13} />
      </button>

      <div class="mx-1 h-4 border-l border-white/10"></div>

      <button onclick={() => mediaPlayer.toggleMute()} class="rounded-lg p-1 text-white/40 hover:text-white transition-colors" aria-label="Mute">
        {#if $mediaPlayer.muted || $mediaPlayer.volume === 0}
          <VolumeX size={13} />
        {:else}
          <Volume2 size={13} />
        {/if}
      </button>

      <input
        type="range" min="0" max="1" step="0.05"
        value={$mediaPlayer.volume}
        oninput={(e) => mediaPlayer.setVolume(parseFloat((e.target as HTMLInputElement).value))}
        class="w-12 h-1 accent-white/60 cursor-pointer"
      />
    {:else}
      <label class="cursor-pointer rounded-lg px-2 py-1 text-xs text-white/40 hover:text-white/60 transition-colors">
        <input type="file" accept="audio/*,video/*" multiple onchange={handleFiles} class="hidden" />
        Add files
      </label>
    {/if}
  </div>
</div>

<style>
  .animate-bar1 { animation: bar 0.9s ease-in-out infinite; height: 6px; }
  .animate-bar2 { animation: bar 0.9s ease-in-out infinite 0.2s; height: 10px; }
  .animate-bar3 { animation: bar 0.9s ease-in-out infinite 0.4s; height: 7px; }

  @keyframes bar {
    0%, 100% { transform: scaleY(0.4); }
    50% { transform: scaleY(1); }
  }

  .scrollbar-thin {
    scrollbar-width: thin;
    scrollbar-color: rgba(255,255,255,0.1) transparent;
  }
</style>
