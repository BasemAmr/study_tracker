<script lang="ts">
  import { onMount } from 'svelte';
  import { fetchStudySessions, removeStudySession } from '@/core/services/sessionService';
  import { listSubjects } from '@/core/services/subjectService';
  import { formatMinutes, formatDate, formatTime, formatRelativeDate, modeLabel } from '@/core/utils/formatUtils';
  import { toasts } from '@/core/stores/toastStore';
  import type { StudySession, Subject } from '@/core/domain';
  import Card from '@/ui/components/Card.svelte';
  import EmptyState from '@/ui/components/EmptyState.svelte';
  import Button from '@/ui/components/Button.svelte';
  import Select from '@/ui/components/Select.svelte';
  import Input from '@/ui/components/Input.svelte';
  import {
    Search, Clock, CalendarDays, Timer, Coffee, BookOpen, Trash2,
    Target, Zap, Smile, Frown, Meh, Brain, FileText
  } from 'lucide-svelte';

  let {
    refreshKey = 0,
    compact = false
  }: {
    refreshKey?: number;
    compact?: boolean;
  } = $props();

  let sessions: StudySession[] = $state([]);
  let subjects: Subject[] = $state([]);
  let loading = $state(true);

  // Filters
  let filterSubject = $state('');
  let filterMode = $state('');
  let filterQuery = $state('');

  const modeOptions = [
    { value: '', label: 'All modes' },
    { value: 'pomodoro', label: 'Pomodoro' },
    { value: 'long_session', label: 'Long Session' },
    { value: 'manual', label: 'Manual Log' }
  ];

  onMount(async () => {
    subjects = await listSubjects();
    await loadSessions();
  });

  $effect(() => {
    if (refreshKey > 0) {
      loadSessions();
    }
  });

  async function loadSessions() {
    loading = true;
    try {
      sessions = await fetchStudySessions({
        subjectId: filterSubject ? parseInt(filterSubject) : undefined,
        mode: filterMode ? (filterMode as StudySession['mode']) : undefined,
        query: filterQuery || undefined,
        limit: 100
      });
    } catch (err) {
      toasts.error('Failed to load sessions.');
      console.error(err);
    } finally {
      loading = false;
    }
  }

  async function handleDelete(id: number) {
    if (!confirm('Delete this session? This cannot be undone.')) return;

    try {
      await removeStudySession(id);
      toasts.success('Session deleted.');
      await loadSessions();
    } catch (err) {
      toasts.error('Failed to delete session.');
    }
  }

  function applyFilters() {
    loadSessions();
  }

  const moodIcons: Record<string, typeof Target> = {
    focused: Target,
    productive: Zap,
    calm: Smile,
    tired: Frown,
    stressed: Meh,
    distracted: Brain
  };
</script>

{#if compact}
  <!-- Compact mode: slim cards, no filter bar, max 8 recent sessions -->
  <div class="space-y-2">
    {#if loading}
      <div class="flex items-center justify-center py-8">
        <div class="h-6 w-6 animate-spin rounded-full border-2 border-moss-200 border-t-moss-600"></div>
      </div>
    {:else if sessions.length === 0}
      <div class="flex flex-col items-center gap-2 rounded-2xl border border-ink-100 bg-white py-8 text-center">
        <BookOpen size={22} class="text-ink-300" />
        <p class="text-sm text-ink-400">No sessions yet</p>
      </div>
    {:else}
      {#each sessions.slice(0, 8) as session}
        <div class="rounded-2xl border border-ink-100 bg-white px-4 py-3 shadow-sm transition-all hover:border-moss-200 group">
          <div class="flex items-center justify-between gap-2">
            <div class="min-w-0 flex-1">
              <p class="truncate text-sm font-medium text-ink-900">{session.subjectName ?? 'General study'}</p>
              <p class="mt-0.5 flex items-center gap-2 text-xs text-ink-400">
                <Clock size={11} /> {formatMinutes(session.durationMinutes)}
                <span class="text-ink-200">·</span>
                {formatRelativeDate(session.startAt)}
              </p>
            </div>
            <span class="shrink-0 rounded-full bg-moss-50 px-2 py-0.5 text-[10px] font-medium text-moss-600">
              {modeLabel(session.mode)}
            </span>
            <button
              class="shrink-0 rounded-lg p-1.5 text-ink-200 opacity-0 hover:bg-red-50 hover:text-red-400 group-hover:opacity-100 transition-all"
              onclick={() => session.id && handleDelete(session.id)}
              aria-label="Delete"
            >
              <Trash2 size={13} />
            </button>
          </div>
        </div>
      {/each}
    {/if}
  </div>
{:else}
  <!-- Full mode with filters -->
  <div class="space-y-4">
    <Card padding="p-4">
      <div class="flex flex-wrap items-end gap-4">
        <div class="flex-1 min-w-[200px]">
          <Input label="Search" bind:value={filterQuery} placeholder="Search sessions..." />
        </div>
        <div class="w-40">
          <Select
            label="Subject"
            bind:value={filterSubject}
            options={[{ value: '', label: 'All subjects' }, ...subjects.map((s) => ({ value: String(s.id), label: s.name }))]}
          />
        </div>
        <div class="w-40">
          <Select label="Mode" bind:value={filterMode} options={modeOptions} />
        </div>
        <Button variant="secondary" onclick={applyFilters}>
          <Search size={15} /> Filter
        </Button>
      </div>
    </Card>

    {#if loading}
      <div class="flex items-center justify-center py-12">
        <div class="h-8 w-8 animate-spin rounded-full border-2 border-moss-200 border-t-moss-600"></div>
      </div>
    {:else if sessions.length === 0}
      <Card>
        <EmptyState IconComponent={BookOpen} title="No sessions found" description="Start a study session or adjust your filters." />
      </Card>
    {:else}
      <div class="space-y-3">
        {#each sessions as session}
          <div class="rounded-[1.5rem] border border-ink-100 bg-white p-5 shadow-sm transition-all duration-150 hover:shadow-card group">
            <div class="flex items-start justify-between">
              <div class="flex-1">
                <div class="flex items-center gap-3">
                  <h4 class="font-medium text-ink-900">{session.subjectName ?? 'General study'}</h4>
                  <span class="rounded-full bg-moss-100 px-2.5 py-0.5 text-xs font-medium text-moss-600">
                    {modeLabel(session.mode)}
                  </span>
                  {#if session.mood && moodIcons[session.mood]}
                    {@const MoodIcon = moodIcons[session.mood]}
                    <MoodIcon size={14} class="text-ink-400" />
                  {/if}
                </div>
                {#if session.topic}
                  <div class="mt-1 flex items-center gap-1.5 text-sm text-ink-500">
                    <BookOpen size={13} /> {session.topic}
                  </div>
                {/if}
                <div class="mt-2 flex items-center gap-4 text-sm text-ink-500">
                  <span class="flex items-center gap-1"><Clock size={13} /> {formatMinutes(session.durationMinutes)}</span>
                  <span class="flex items-center gap-1"><CalendarDays size={13} /> {formatDate(session.startAt)}</span>
                  <span class="flex items-center gap-1"><Timer size={13} /> {formatTime(session.startAt)}</span>
                  {#if session.breakMinutes && session.breakMinutes > 0}
                    <span class="flex items-center gap-1"><Coffee size={13} /> {session.breakMinutes}m break</span>
                  {/if}
                </div>
                {#if session.notes}
                  <div class="mt-2 flex items-start gap-1.5 text-sm text-ink-500 italic">
                    <FileText size={13} class="mt-0.5 shrink-0" /> "{session.notes}"
                  </div>
                {/if}
              </div>
              <button
                class="rounded-xl p-2 text-ink-200 opacity-0 transition-all duration-150 hover:bg-red-50 hover:text-red-500 group-hover:opacity-100"
                onclick={() => session.id && handleDelete(session.id)}
                aria-label="Delete session"
              >
                <Trash2 size={16} />
              </button>
            </div>
          </div>
        {/each}
      </div>
    {/if}
  </div>
{/if}
