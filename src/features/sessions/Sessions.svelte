<script lang="ts">
  import { onMount } from 'svelte';
  import SessionTimer from './SessionTimer.svelte';
  import SessionHistory from './SessionHistory.svelte';
  import SessionForm from './SessionForm.svelte';
  import Stopwatch from './Stopwatch.svelte';
  import SubjectsAndGroups from './SubjectsAndGroups.svelte';
  import Button from '@/ui/components/Button.svelte';
  import { Timer, Clock3, ClipboardList, FilePlus, BookOpen } from 'lucide-svelte';

  import { untrack } from 'svelte';
  import { activeProfileId } from '@/core/stores/profileStore';

  let activeTab: 'timer' | 'stopwatch' | 'history' | 'subjects' = $state('timer');
  let showManualForm = $state(false);
  let historyRefreshKey = $state(0);

  $effect(() => {
    if ($activeProfileId) {
      untrack(() => handleSessionSaved());
    }
  });

  onMount(() => {
    window.addEventListener('session-saved', handleSessionSaved);
    return () => window.removeEventListener('session-saved', handleSessionSaved);
  });

  function handleSessionSaved() {
    historyRefreshKey++;
  }
</script>

<div class="space-y-5">
  <!-- Header -->
  <header class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
    <div>
      <p class="text-sm font-medium text-moss-600">Sessions</p>
      <h2 class="mt-0.5 text-3xl font-semibold tracking-tight text-ink-900">Study sessions</h2>
    </div>
    <Button variant="secondary" onclick={() => (showManualForm = true)}>
      <FilePlus size={16} /> Log manually
    </Button>
  </header>

  <!-- Tabs -->
  <div class="flex gap-1 rounded-2xl border border-ink-200 bg-ink-100/40 p-1 w-fit">
    <button
      class="flex items-center gap-2 rounded-xl px-5 py-2 text-sm font-medium transition-all duration-150 {activeTab === 'timer'
        ? 'bg-white text-moss-600 shadow-sm'
        : 'text-ink-500 hover:text-ink-900'}"
      onclick={() => (activeTab = 'timer')}
    >
      <Timer size={15} /> Timer
    </button>
    <button
      class="flex items-center gap-2 rounded-xl px-5 py-2 text-sm font-medium transition-all duration-150 {activeTab === 'stopwatch'
        ? 'bg-white text-moss-600 shadow-sm'
        : 'text-ink-500 hover:text-ink-900'}"
      onclick={() => (activeTab = 'stopwatch')}
    >
      <Clock3 size={15} /> Stopwatch
    </button>
    <button
      class="flex items-center gap-2 rounded-xl px-5 py-2 text-sm font-medium transition-all duration-150 {activeTab === 'history'
        ? 'bg-white text-moss-600 shadow-sm'
        : 'text-ink-500 hover:text-ink-900'}"
      onclick={() => (activeTab = 'history')}
    >
      <ClipboardList size={15} /> History
    </button>
    <button
      class="flex items-center gap-2 rounded-xl px-5 py-2 text-sm font-medium transition-all duration-150 {activeTab === 'subjects'
        ? 'bg-white text-moss-600 shadow-sm'
        : 'text-ink-500 hover:text-ink-900'}"
      onclick={() => (activeTab = 'subjects')}
    >
      <BookOpen size={15} /> Subjects & Groups
    </button>
  </div>

  <!-- Content — timer & stopwatch show as 2-col with recent history alongside -->
  {#if activeTab === 'timer'}
    <div class="grid gap-5 xl:grid-cols-[minmax(0,1.2fr)_minmax(0,1fr)]">
      <SessionTimer onsessionsaved={handleSessionSaved} />
      <div class="space-y-3">
        <p class="text-sm font-medium text-ink-400">Recent sessions</p>
        <SessionHistory refreshKey={historyRefreshKey} compact={true} />
      </div>
    </div>
  {:else if activeTab === 'stopwatch'}
    <div class="grid gap-5 xl:grid-cols-[minmax(0,1.2fr)_minmax(0,1fr)]">
      <Stopwatch />
      <div class="space-y-3">
        <p class="text-sm font-medium text-ink-400">Recent sessions</p>
        <SessionHistory refreshKey={historyRefreshKey} compact={true} />
      </div>
    </div>
  {:else if activeTab === 'history'}
    <SessionHistory refreshKey={historyRefreshKey} />
  {:else if activeTab === 'subjects'}
    <SubjectsAndGroups />
  {/if}

  <SessionForm bind:open={showManualForm} onsaved={handleSessionSaved} />
</div>
