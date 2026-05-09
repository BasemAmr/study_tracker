<script lang="ts">
  import { timer, timerDisplay, isTimerActive } from '@/core/stores/timerStore';
  import { settings } from '@/core/stores/settingsStore';
  import { toasts } from '@/core/stores/toastStore';
  import { createStudySession } from '@/core/services/sessionService';
  import { listSubjects } from '@/core/services/subjectService';
  import { formatMinutes, modeLabel } from '@/core/utils/formatUtils';
  import { nowISO } from '@/core/utils/dateUtils';
  import type { StudySessionMode, Subject } from '@/core/domain';
  import Select from '@/ui/components/Select.svelte';
  import Input from '@/ui/components/Input.svelte';
  import {
    Play, Pause, Square, Timer as TimerIcon, Clock,
    Coffee, Target, ChevronDown, ChevronUp,
    Maximize2, Minimize2, Image as ImageIcon
  } from 'lucide-svelte';
  import { portal } from '@/core/utils/portal';
  import { onMount } from 'svelte';

  let {
    onsessionsaved
  }: {
    onsessionsaved?: () => void;
  } = $props();

  let subjects: Subject[] = $state([]);
  let selectedSubjectId = $state('');
  let topic = $state('');
  let notes = $state('');
  let mood = $state('');
  let selectedMode: StudySessionMode = $state('long_session');
  let showDetails = $state(false);
  let isFullscreen = $state(false);
  let backgroundImage = $state('/backgrounds/city-twilight.png');
  let overlayOpacity = $state(0.4);
  let customBgFile: string | null = $state(null);

  const moods = [
    { value: 'focused', label: 'Focused' },
    { value: 'productive', label: 'Productive' },
    { value: 'calm', label: 'Calm' },
    { value: 'tired', label: 'Tired' },
    { value: 'stressed', label: 'Stressed' },
    { value: 'distracted', label: 'Distracted' }
  ];

  const backgrounds = [
    { value: '/backgrounds/city-twilight.png', label: 'City Twilight' },
    { value: '/backgrounds/cozy-cafe.png', label: 'Cozy Café' }
  ];

  onMount(async () => {
    await settings.load();
    subjects = await listSubjects();
    const s = settings.get();
    selectedMode = s.defaultSessionMode;
    backgroundImage = s.defaultBackground || '/backgrounds/city-twilight.png';
    overlayOpacity = s.overlayOpacity ?? 0.4;
  });

  function startTimer() {
    const s = settings.get();
    const subject = subjects.find((s) => String(s.id) === selectedSubjectId);
    
    timer.start(selectedMode, s.focusMinutes, s.breakMinutes, {
      subjectId: subject?.id ?? null,
      subjectName: subject?.name ?? null,
      topic: topic || null,
      mood: mood || null,
      notes: notes || null,
      backgroundImage: customBgFile || backgroundImage
    });
    toasts.success('Session started!');
  }

  function pauseTimer() { timer.pause(); }
  function resumeTimer() { timer.resume(); }

  async function stopAndSave() {
    const snapshot = timer.stop();
    if (snapshot.elapsedSeconds < 10) {
      toasts.error('Session too short to save (minimum 10 seconds).');
      return;
    }
    const durationMinutes = Math.max(1, Math.round(snapshot.elapsedSeconds / 60));
    const breakMins = Math.round(snapshot.breakSeconds / 60);
    const subject = subjects.find((s) => String(s.id) === selectedSubjectId);
    try {
      await createStudySession({
        startAt: snapshot.startedAt ?? nowISO(),
        endAt: nowISO(),
        durationMinutes,
        subjectId: subject?.id ?? null,
        subjectName: subject?.name ?? null,
        topic: topic || null,
        mood: mood || null,
        notes: notes || null,
        mode: snapshot.mode,
        breakMinutes: breakMins,
        backgroundImage: customBgFile || backgroundImage
      });
      toasts.success(`Session saved! ${formatMinutes(durationMinutes)} studied.`);
      isFullscreen = false;
      resetForm();
      onsessionsaved?.();
    } catch (err) {
      toasts.error('Failed to save session.');
      console.error(err);
    }
  }

  function resetForm() {
    topic = '';
    notes = '';
    mood = '';
    customBgFile = null;
  }

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

<!-- ═══════════════════ FULLSCREEN OVERLAY ═══════════════════ -->
{#if isFullscreen}
  <div
    use:portal
    class="fixed inset-0 z-[9999] flex flex-col"
    style="background-image: url('{effectiveBg}'); background-size: cover; background-position: center;"
  >
    <!-- dark overlay -->
    <div class="absolute inset-0 bg-black" style="opacity: {overlayOpacity};"></div>

    <!-- Top bar -->
    <div class="relative z-10 flex items-center justify-between px-6 pt-5">
      <!-- Mode badge -->
      <div class="flex items-center gap-2 rounded-full border border-white/15 bg-black/30 px-4 py-2 text-sm text-white backdrop-blur-md">
        {#if $timer.state === 'break'}
          <Coffee size={14} /> Break time
        {:else if $timer.state === 'paused'}
          <Pause size={14} /> Paused
        {:else if $isTimerActive}
          <Target size={14} /> Focusing
        {:else}
          <TimerIcon size={14} /> Ready
        {/if}
        {#if $isTimerActive}
          <span class="rounded-full bg-white/15 px-2.5 py-0.5 text-xs">{modeLabel($timer.mode)}</span>
        {/if}
      </div>

      <!-- Exit btn -->
      <button
        onclick={() => (isFullscreen = false)}
        class="flex items-center gap-1.5 rounded-full border border-white/20 bg-black/30 px-4 py-2 text-sm text-white/80 backdrop-blur-md hover:bg-black/50 transition-colors"
      >
        <Minimize2 size={14} /> Exit fullscreen
      </button>
    </div>

    <!-- Centre: giant clock -->
    <div class="relative z-10 flex flex-1 flex-col items-center justify-center gap-4 px-6 text-white">
      <!-- Mode tabs (only pre-start) -->
      {#if !$isTimerActive}
        <div class="flex gap-1 rounded-full border border-white/20 bg-black/30 p-1.5 backdrop-blur-md">
          <button
            class="flex items-center gap-1.5 rounded-full px-5 py-2 text-sm font-medium transition-all
                   {selectedMode === 'pomodoro' ? 'bg-white text-neutral-900' : 'text-white/70 hover:text-white'}"
            onclick={() => (selectedMode = 'pomodoro')}
          >
            <TimerIcon size={14} /> Pomodoro
          </button>
          <button
            class="flex items-center gap-1.5 rounded-full px-5 py-2 text-sm font-medium transition-all
                   {selectedMode === 'long_session' ? 'bg-white text-neutral-900' : 'text-white/70 hover:text-white'}"
            onclick={() => (selectedMode = 'long_session')}
          >
            <Clock size={14} /> Long Session
          </button>
        </div>
      {/if}

      <!-- Giant digits -->
      <p class="text-[clamp(6rem,16vw,12rem)] font-thin leading-none tabular-nums drop-shadow-2xl">
        {$timerDisplay}
      </p>

      <!-- Sub-label -->
      <p class="text-lg text-white/60">
        {#if $isTimerActive}
          {formatMinutes(Math.floor($timer.elapsedSeconds / 60))} focused
          {#if $timer.mode === 'pomodoro'}· Pomodoro #{$timer.pomodoroCount + 1}{/if}
        {:else}
          {selectedMode === 'pomodoro'
            ? `${settings.get().focusMinutes}m focus · ${settings.get().breakMinutes}m break`
            : 'Continuous focus mode'}
        {/if}
      </p>

      <!-- Controls -->
      <div class="mt-6 flex flex-wrap items-center justify-center gap-4">
        {#if !$isTimerActive}
          <button
            onclick={startTimer}
            class="flex items-center gap-2 rounded-full bg-white px-10 py-4 text-base font-semibold text-neutral-900 shadow-xl hover:bg-white/90 transition-all hover:scale-105"
          >
            <Play size={18} /> Start session
          </button>
        {:else if $timer.state === 'break'}
          <p class="mb-2 w-full text-center text-sm text-white/60">
            Break ends · relax 🌿
          </p>
          <button
            onclick={() => timer.skipBreak?.()}
            class="flex items-center gap-2 rounded-full border border-white/20 bg-black/30 px-8 py-3.5 text-sm text-white backdrop-blur-md hover:bg-black/50"
          >
            Skip break
          </button>
          <button
            onclick={stopAndSave}
            class="flex items-center gap-2 rounded-full border border-red-400/30 bg-red-500/20 px-8 py-3.5 text-sm text-red-200 hover:bg-red-500/30"
          >
            <Square size={16} /> Stop & Save
          </button>
        {:else if $timer.state === 'paused'}
          <button
            onclick={resumeTimer}
            class="flex items-center gap-2 rounded-full bg-white px-10 py-4 text-base font-semibold text-neutral-900 shadow-xl hover:bg-white/90 transition-all"
          >
            <Play size={18} /> Resume
          </button>
          <button
            onclick={stopAndSave}
            class="flex items-center gap-2 rounded-full border border-red-400/30 bg-red-500/20 px-8 py-3.5 text-sm text-red-200 hover:bg-red-500/30"
          >
            <Square size={16} /> Stop & Save
          </button>
        {:else}
          <!-- Running -->
          <button
            onclick={pauseTimer}
            class="flex items-center gap-2 rounded-full border border-white/20 bg-black/30 px-10 py-4 text-base text-white backdrop-blur-md hover:bg-black/50 transition-all"
          >
            <Pause size={18} /> Pause
          </button>
          <button
            onclick={stopAndSave}
            class="flex items-center gap-2 rounded-full border border-red-400/30 bg-red-500/20 px-10 py-4 text-base text-red-200 hover:bg-red-500/30 transition-all"
          >
            <Square size={18} /> Stop & Save
          </button>
        {/if}
      </div>
    </div>

    <!-- Bottom: background picker (subtle) -->
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
    <div class="relative overflow-hidden" style="height: 230px;">
      <img src={effectiveBg} alt="" class="absolute inset-0 h-full w-full object-cover" />
      <div class="absolute inset-0 bg-black" style="opacity: {overlayOpacity};"></div>

      <!-- Fullscreen button (top-right) — z-20 so it sits above the z-10 content layer -->
      <button
        onclick={() => (isFullscreen = true)}
        class="absolute right-3 top-3 z-20 flex items-center gap-1.5 rounded-full border border-white/20 bg-black/30 px-3 py-1.5 text-xs text-white/70 backdrop-blur-sm hover:bg-black/50 transition-colors"
      >
        <Maximize2 size={12} /> Fullscreen
      </button>

      <!-- Timer content (centered in strip) -->
      <div class="absolute inset-0 z-10 flex flex-col items-center justify-center gap-3 text-white">

        <!-- Mode selector / state badge -->
        {#if !$isTimerActive}
          <div class="flex gap-1 rounded-full border border-white/20 bg-black/30 p-1 backdrop-blur-sm">
            <button
              class="flex items-center gap-1.5 rounded-full px-4 py-1.5 text-xs font-medium transition-all
                     {selectedMode === 'pomodoro' ? 'bg-white text-neutral-900' : 'text-white/70 hover:text-white'}"
              onclick={() => (selectedMode = 'pomodoro')}
            >
              <TimerIcon size={12} /> Pomodoro
            </button>
            <button
              class="flex items-center gap-1.5 rounded-full px-4 py-1.5 text-xs font-medium transition-all
                     {selectedMode === 'long_session' ? 'bg-white text-neutral-900' : 'text-white/70 hover:text-white'}"
              onclick={() => (selectedMode = 'long_session')}
            >
              <Clock size={12} /> Long Session
            </button>
          </div>
        {:else}
          <div class="flex items-center gap-2 rounded-full border border-white/15 bg-black/30 px-3 py-1.5 text-xs backdrop-blur-sm">
            {#if $timer.state === 'break'}
              <Coffee size={12} /> Break time
            {:else if $timer.state === 'paused'}
              <Pause size={12} /> Paused
            {:else}
              <Target size={12} /> Focusing
            {/if}
            <span class="text-white/60">· {modeLabel($timer.mode)}</span>
          </div>
        {/if}

        <!-- Clock digits -->
        <p class="text-6xl font-thin tabular-nums drop-shadow-lg">{$timerDisplay}</p>

        <!-- Sub-label -->
        <p class="text-xs text-white/55">
          {#if $isTimerActive}
            {formatMinutes(Math.floor($timer.elapsedSeconds / 60))} focused
          {:else if selectedMode === 'pomodoro'}
            {settings.get().focusMinutes}m focus · {settings.get().breakMinutes}m break
          {:else}
            Continuous focus mode
          {/if}
        </p>
      </div>
    </div>

    <!-- Controls panel -->
    <div class="p-4 space-y-3">

      <!-- Buttons -->
      <div class="flex flex-wrap items-center gap-2">
        {#if !$isTimerActive}
          <button
            onclick={startTimer}
            class="flex items-center gap-2 rounded-2xl bg-moss-600 px-6 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-moss-500 transition-all hover:-translate-y-px"
          >
            <Play size={15} /> Start session
          </button>
        {:else if $timer.state === 'break'}
          <button onclick={() => timer.skipBreak?.()} class="flex items-center gap-2 rounded-2xl border border-ink-200 px-5 py-2.5 text-sm text-ink-600 hover:bg-ink-100">
            Skip break
          </button>
          <button onclick={stopAndSave} class="flex items-center gap-2 rounded-2xl border border-red-200 bg-red-50 px-5 py-2.5 text-sm text-red-600 hover:bg-red-100">
            <Square size={14} /> Stop & Save
          </button>
        {:else if $timer.state === 'paused'}
          <button onclick={resumeTimer} class="flex items-center gap-2 rounded-2xl bg-moss-600 px-6 py-2.5 text-sm font-semibold text-white hover:bg-moss-500">
            <Play size={15} /> Resume
          </button>
          <button onclick={stopAndSave} class="flex items-center gap-2 rounded-2xl border border-red-200 bg-red-50 px-5 py-2.5 text-sm text-red-600 hover:bg-red-100">
            <Square size={14} /> Stop & Save
          </button>
        {:else}
          <!-- Running -->
          <button onclick={pauseTimer} class="flex items-center gap-2 rounded-2xl border border-ink-200 px-5 py-2.5 text-sm font-medium text-ink-700 hover:bg-ink-100">
            <Pause size={15} /> Pause
          </button>
          <button onclick={stopAndSave} class="flex items-center gap-2 rounded-2xl border border-red-200 bg-red-50 px-5 py-2.5 text-sm font-medium text-red-600 hover:bg-red-100">
            <Square size={15} /> Stop & Save
          </button>
        {/if}
      </div>

      <!-- Details toggle -->
      <button
        onclick={() => (showDetails = !showDetails)}
        class="flex items-center gap-1 text-xs text-ink-400 hover:text-ink-700 transition-colors"
      >
        {#if showDetails}<ChevronUp size={13} />{:else}<ChevronDown size={13} />{/if}
        {showDetails ? 'Hide' : 'Session'} details
      </button>

      {#if showDetails}
        <div class="grid gap-3 border-t border-ink-100 pt-3 sm:grid-cols-2">
          <Select
            label="Subject"
            bind:value={selectedSubjectId}
            options={subjects.map((s) => ({ value: String(s.id), label: s.name }))}
            placeholder="Select subject..."
          />
          <Input label="Topic" bind:value={topic} placeholder="e.g., Chapter 5" />
          <Select label="Mood" bind:value={mood} options={moods} placeholder="How are you feeling?" />
          <Input label="Notes" type="textarea" bind:value={notes} placeholder="Session notes..." />
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
