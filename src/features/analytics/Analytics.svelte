<script lang="ts">
  import { onMount, tick } from 'svelte';
  import { Chart, registerables } from 'chart.js';
  import { fetchStudySessions } from '@/core/services/sessionService';
  import {
    computeDailyTotals,
    computeWeeklyTotals,
    computeSubjectBreakdown,
    computeHourlyDistribution,
    computeMoodDistribution,
    computeStudyBreakRatio,
    findPeakHour
  } from '@/core/utils/analyticsUtils';
  import { formatMinutes, formatHour } from '@/core/utils/formatUtils';
  import type { StudySession } from '@/core/domain';
  import Card from '@/ui/components/Card.svelte';
  import EmptyState from '@/ui/components/EmptyState.svelte';
  import Button from '@/ui/components/Button.svelte';
  import {
    Scale, CalendarRange, ChevronDown, BarChart3, TrendingUp, BookOpen, Smile, Clock, Loader2, Sparkles
  } from 'lucide-svelte';
  import { untrack } from 'svelte';
  import { activeProfileId } from '@/core/stores/profileStore';
  import {
    defaultAiFeaturesForProfile,
    getAiFeaturesOrDefault,
    getForProfile as getAiFeatRowForProfile,
  } from '@/core/data/repositories/aiFeatureSettingsRepository';
  import { isoWeekKey, localCalendarDateKey } from '@/core/utils/aiDateKeys';
  import {
    generateForWeek,
    getCachedNarrative,
    type WeeklyNarrativePayload,
  } from '@/core/services/aiWeeklyNarrativeService';
  import {
    analyze as analyzeSubjectDifficulty,
    getCachedDifficultyToday,
    type SubjectDifficultyOk,
  } from '@/core/services/aiSubjectDifficultyService';

  Chart.register(...registerables);

  // ─── Types ───────────────────────────────────────────────────
  type Granularity = 'hourly' | 'daily' | 'weekly' | 'monthly';
  type QuickRange = '7d' | '14d' | '30d' | '90d' | '365d' | 'custom';

  // ─── State ───────────────────────────────────────────────────
  let sessions: StudySession[] = $state([]);
  let loading = $state(true);

  let granularity: Granularity = $state('daily');
  let quickRange: QuickRange = $state('30d');

  // Custom date range
  const todayStr = localDateStr(new Date());
  let customFrom = $state(localDateStr(offsetDate(new Date(), -30)));
  let customTo   = $state(todayStr);
  let showCustom = $state(false);

  // Chart canvas refs
  let mainChartCanvas: HTMLCanvasElement | undefined = $state(undefined);
  let subjectChartCanvas: HTMLCanvasElement | undefined = $state(undefined);
  let hourlyChartCanvas: HTMLCanvasElement | undefined = $state(undefined);

  let mainChart:    Chart | null = null;
  let subjectChart: Chart | null = null;
  let hourlyChart:  Chart | null = null;

  // Summary stats
  let totalMinutes = $state(0);
  let avgValue     = $state(0);
  let bestLabel    = $state('');
  let bestMinutes  = $state(0);
  let peakHour     = $state(0);
  let studyBreakRatio = $state({ studyMinutes: 0, breakMinutes: 0, ratio: '0:0' });
  let moodDist: Array<{ mood: string; count: number; percentage: number }> = $state([]);
  let subjectBreakdown: Array<{ name: string; minutes: number; percentage: number }> = $state([]);

  let aiFeatures = $state(defaultAiFeaturesForProfile(1));
  let narrativeWeekKey = $state(`rolling-7d-${localCalendarDateKey(new Date())}`);
  let narrativeBody = $state('');
  let narrativeMeta = $state<WeeklyNarrativePayload | null>(null);
  let narrativeBusy = $state(false);

  let difficultyCached = $state<SubjectDifficultyOk | null>(null);
  let difficultyBusy = $state(false);
  let difficultyInsufficient = $state(false);

  // ─── Helpers ─────────────────────────────────────────────────
  function localDateStr(d: Date): string {
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${y}-${m}-${day}`;
  }

  function getRollingRangeLabel(): string {
    const end = new Date();
    const start = new Date(end);
    start.setDate(start.getDate() - 7);
    return `${localDateStr(start)} → ${localDateStr(end)}`;
  }

  function offsetDate(d: Date, days: number): Date {
    const copy = new Date(d);
    copy.setDate(copy.getDate() + days);
    return copy;
  }

  function parseLocalDate(str: string): Date {
    const [y, m, d] = str.split('-').map(Number);
    return new Date(y, m - 1, d, 0, 0, 0, 0);
  }

  /** Returns [fromDate, toDate] based on current controls */
  function getRange(): [Date, Date] {
    const now = new Date();
    if (quickRange === 'custom') {
      return [parseLocalDate(customFrom), parseLocalDate(customTo)];
    }
    const days = { '7d': 7, '14d': 14, '30d': 30, '90d': 90, '365d': 365 }[quickRange] ?? 30;
    const from = new Date(now);
    from.setDate(from.getDate() - days);
    from.setHours(0, 0, 0, 0);
    return [from, now];
  }

  function filterSessions(from: Date, to: Date): StudySession[] {
    return sessions.filter((s) => {
      const d = new Date(s.startAt);
      return d >= from && d <= to;
    });
  }

  // ─── Granularity aggregation ─────────────────────────────────
  type ChartPoint = { label: string; minutes: number };

  function aggregateHourly(ss: StudySession[]): ChartPoint[] {
    const map = new Map<number, number>();
    for (let h = 0; h < 24; h++) map.set(h, 0);
    for (const s of ss) {
      const h = new Date(s.startAt).getHours();
      map.set(h, (map.get(h) ?? 0) + s.durationMinutes);
    }
    return Array.from(map.entries()).map(([h, m]) => ({ label: formatHour(h), minutes: m }));
  }

  function aggregateDaily(ss: StudySession[], from: Date, to: Date): ChartPoint[] {
    const map = new Map<string, number>();
    // Pre-fill every day in range
    const cur = new Date(from);
    while (cur <= to) {
      map.set(localDateStr(cur), 0);
      cur.setDate(cur.getDate() + 1);
    }
    for (const s of ss) {
      const key = localDateStr(new Date(s.startAt));
      map.set(key, (map.get(key) ?? 0) + s.durationMinutes);
    }
    return Array.from(map.entries()).map(([date, minutes]) => ({
      label: date.slice(5), // MM-DD
      minutes
    }));
  }

  function aggregateWeekly(ss: StudySession[], from: Date, to: Date): ChartPoint[] {
    // Build minute map keyed by Monday date string
    const map = new Map<string, number>();

    // Pre-fill every Monday week in range
    const monday = new Date(from);
    const startDay = monday.getDay();
    const diff = startDay === 0 ? -6 : 1 - startDay;
    monday.setDate(monday.getDate() + diff);
    monday.setHours(0, 0, 0, 0);

    const cursor = new Date(monday);
    while (cursor <= to) {
      map.set(localDateStr(cursor), 0);
      cursor.setDate(cursor.getDate() + 7);
    }

    // Accumulate session minutes
    for (const s of ss) {
      const d = new Date(s.startAt);
      const m = new Date(d);
      const day = d.getDay();
      const dff = day === 0 ? -6 : 1 - day;
      m.setDate(m.getDate() + dff);
      m.setHours(0, 0, 0, 0);
      const key = localDateStr(m);
      if (map.has(key)) map.set(key, (map.get(key) ?? 0) + s.durationMinutes);
    }

    return Array.from(map.entries())
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([date, minutes]) => ({ label: `W ${date.slice(5)}`, minutes }));
  }

  function aggregateMonthly(ss: StudySession[], from: Date, to: Date): ChartPoint[] {
    // Pre-fill all months in range
    const map = new Map<string, number>();
    const cur = new Date(from.getFullYear(), from.getMonth(), 1);
    const end = new Date(to.getFullYear(), to.getMonth(), 1);
    while (cur <= end) {
      const key = `${cur.getFullYear()}-${String(cur.getMonth() + 1).padStart(2, '0')}`;
      map.set(key, 0);
      cur.setMonth(cur.getMonth() + 1);
    }

    for (const s of ss) {
      const d = new Date(s.startAt);
      const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
      if (map.has(key)) map.set(key, (map.get(key) ?? 0) + s.durationMinutes);
    }

    return Array.from(map.entries())
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([key, minutes]) => ({
        label: new Date(key + '-01').toLocaleDateString('en-US', { month: 'short', year: '2-digit' }),
        minutes
      }));
  }

  function getChartData(ss: StudySession[], from: Date, to: Date): ChartPoint[] {
    switch (granularity) {
      case 'hourly':  return aggregateHourly(ss);
      case 'daily':   return aggregateDaily(ss, from, to);
      case 'weekly':  return aggregateWeekly(ss, from, to);
      case 'monthly': return aggregateMonthly(ss, from, to);
    }
  }

  // ─── Render ──────────────────────────────────────────────────
  async function renderCharts() {
    await tick();
    const [from, to] = getRange();
    const rs = filterSessions(from, to);

    totalMinutes = rs.reduce((sum, s) => sum + s.durationMinutes, 0);
    peakHour = findPeakHour(rs);
    studyBreakRatio = computeStudyBreakRatio(rs);
    moodDist = computeMoodDistribution(rs);
    subjectBreakdown = computeSubjectBreakdown(rs);

    const points = getChartData(rs, from, to);
    const nonZero = points.filter((p) => p.minutes > 0);
    const activeDays = Math.max(1, nonZero.length);
    avgValue = Math.round(totalMinutes / activeDays);

    if (nonZero.length > 0) {
      const best = [...points].sort((a, b) => b.minutes - a.minutes)[0];
      bestLabel = best.label;
      bestMinutes = best.minutes;
    } else {
      bestLabel = '—'; bestMinutes = 0;
    }

    // ── Main chart (granularity view) ──
    if (mainChartCanvas) {
      mainChart?.destroy();
      const isLine = granularity === 'weekly' || granularity === 'monthly';
      mainChart = new Chart(mainChartCanvas, {
        type: isLine ? 'line' : 'bar',
        data: {
          labels: points.map((p) => p.label),
          datasets: [{
            label: granulityLabel(granularity),
            data: points.map((p) => p.minutes),
            backgroundColor: isLine ? 'rgba(99,148,109,0.12)' : 'rgba(99,148,109,0.55)',
            borderColor: 'rgba(99,148,109,0.9)',
            borderWidth: isLine ? 2 : 1,
            borderRadius: isLine ? 0 : 6,
            barPercentage: 0.6,
            fill: isLine,
            tension: 0.4,
            pointRadius: isLine ? 4 : 0,
            pointBackgroundColor: '#63946d'
          }]
        },
        options: chartOptions(granularity === 'hourly' ? 'Minutes at this hour' : 'Minutes')
      });
    }

    // ── Subject doughnut ──
    const breakdown = subjectBreakdown;
    if (subjectChartCanvas && breakdown.length > 0) {
      subjectChart?.destroy();
      const colors = ['#63946d','#7cab84','#b8d7be','#e5f2e6','#dbe2dc','#6c766d','#465147'];
      subjectChart = new Chart(subjectChartCanvas, {
        type: 'doughnut',
        data: {
          labels: breakdown.map((b) => b.name),
          datasets: [{
            data: breakdown.map((b) => b.minutes),
            backgroundColor: colors.slice(0, breakdown.length),
            borderWidth: 2,
            borderColor: '#fff'
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: {
              position: 'bottom',
              labels: { padding: 16, font: { family: 'Inter', size: 12 }, color: '#465147' }
            }
          }
        }
      });
    }

    // ── Hourly peaks (always shown regardless of granularity) ──
    if (hourlyChartCanvas) {
      const hourly = computeHourlyDistribution(rs);
      hourlyChart?.destroy();
      hourlyChart = new Chart(hourlyChartCanvas, {
        type: 'bar',
        data: {
          labels: hourly.map((h) => formatHour(h.hour)),
          datasets: [{
            label: 'Minutes',
            data: hourly.map((h) => h.minutes),
            backgroundColor: 'rgba(99,148,109,0.45)',
            borderRadius: 4,
            barPercentage: 0.5
          }]
        },
        options: {
          ...chartOptions('Minutes'),
          scales: {
            ...chartOptions('Minutes').scales,
            x: { grid: { display: false }, ticks: { font: { size: 9 }, color: '#6c766d', maxRotation: 45 } }
          }
        }
      });
    }
  }

  function granulityLabel(g: Granularity): string {
    return { hourly: 'Minutes per hour', daily: 'Minutes per day', weekly: 'Minutes per week', monthly: 'Minutes per month' }[g];
  }

  function chartOptions(yLabel: string): any {
    return {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        x: { grid: { display: false }, ticks: { font: { family: 'Inter', size: 11 }, color: '#6c766d' } },
        y: {
          beginAtZero: true,
          grid: { color: 'rgba(0,0,0,0.04)' },
          ticks: { font: { family: 'Inter', size: 11 }, color: '#6c766d' },
          title: { display: true, text: yLabel, font: { family: 'Inter', size: 11 }, color: '#6c766d' }
        }
      }
    };
  }

  async function refreshAiPanels() {
    const pid = Number($activeProfileId);
    if (!pid) return;
    const row = await getAiFeatRowForProfile(pid);
    aiFeatures = getAiFeaturesOrDefault(pid, row);
    narrativeWeekKey = `rolling-7d-${localCalendarDateKey(new Date())}`;
    narrativeMeta = await getCachedNarrative(pid, narrativeWeekKey);
    narrativeBody = narrativeMeta?.text ?? '';
    difficultyCached = await getCachedDifficultyToday(pid);
    difficultyInsufficient = false;
  }

  async function onGenerateWeeklyNarrative() {
    const pid = Number($activeProfileId);
    if (!pid || narrativeBusy) return;
    narrativeBusy = true;
    try {
      const res = await generateForWeek(pid, new Date(), true);
      if (!res?.text?.trim()) {
        narrativeMeta = null;
        narrativeBody = '';
        return;
      }
      narrativeMeta = res;
      narrativeBody = res.text.trim();
    } finally {
      narrativeBusy = false;
    }
  }

  async function onAnalyzeSubjects() {
    const pid = Number($activeProfileId);
    if (!pid || difficultyBusy) return;
    difficultyBusy = true;
    difficultyInsufficient = false;
    try {
      const res = await analyzeSubjectDifficulty(pid, true);
      if (!res.ok) {
        difficultyCached = null;
        difficultyInsufficient = res.error === 'not_enough_data';
        return;
      }
      difficultyCached = res.data;
    } finally {
      difficultyBusy = false;
    }
  }

  /** Called when any control changes */
  function applyFilters() {
    showCustom = quickRange === 'custom';
    renderCharts();
  }


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
    sessions = await fetchStudySessions({ limit: 10000 });
    loading = false;
    await refreshAiPanels();
    renderCharts();
  }

  const QUICK_RANGES: { value: QuickRange; label: string }[] = [
    { value: '7d',    label: 'Last 7 days' },
    { value: '14d',   label: 'Last 14 days' },
    { value: '30d',   label: 'Last 30 days' },
    { value: '90d',   label: 'Last 3 months' },
    { value: '365d',  label: 'Last year' },
    { value: 'custom',label: 'Custom range' }
  ];

  const GRANULARITIES: { value: Granularity; label: string }[] = [
    { value: 'hourly',  label: 'Hourly' },
    { value: 'daily',   label: 'Daily' },
    { value: 'weekly',  label: 'Weekly' },
    { value: 'monthly', label: 'Monthly' }
  ];

  // Reactive: re-render whenever controls change
  $effect(() => {
    if (!loading && sessions.length > 0) {
      void granularity; void quickRange; void customFrom; void customTo;
      renderCharts();
    }
  });
</script>

<div class="space-y-6">
  <!-- ─────────── Header ─────────── -->
  <header>
    <p class="text-sm font-medium text-moss-600">Analytics</p>
    <h2 class="mt-1 flex items-center gap-2 text-3xl font-semibold tracking-tight text-ink-900">
      <BarChart3 size={28} /> Analytics
    </h2>
  </header>

  {#if aiFeatures.weeklyNarrativeEnabled || aiFeatures.subjectDifficultyEnabled}
    <section class="grid gap-6 lg:grid-cols-2">
      {#if aiFeatures.weeklyNarrativeEnabled}
        <Card>
          <div class="flex items-start justify-between gap-3 mb-4">
            <div>
              <div class="flex items-center gap-2 text-xs font-semibold uppercase tracking-wide text-moss-600">
                <Sparkles size={14} /> Weekly narrative (Past 7 days)
              </div>
              <p class="mt-1 text-sm text-ink-500">
                {getRollingRangeLabel()} · On-demand recap (cached daily).
              </p>
            </div>
            <Button variant="secondary" onclick={onGenerateWeeklyNarrative} disabled={narrativeBusy}>
              {#if narrativeBusy}
                <Loader2 size={14} class="inline animate-spin" /> Generating…
              {:else}
                Generate this week's report
              {/if}
            </Button>
          </div>
          {#if narrativeBody.trim()}
            <div class="rounded-2xl border border-ink-100 bg-[#fcfcfa] p-4 text-sm text-ink-800 whitespace-pre-wrap">
              {narrativeBody}
            </div>
            {#if narrativeMeta?.generatedAt}
              <p class="mt-3 text-[11px] text-ink-400">
                Cached snapshot · rendered {new Date(narrativeMeta.generatedAt).toLocaleString()}
              </p>
            {/if}
          {:else}
            <p class="text-sm text-ink-500">
              {#if narrativeBusy}
                Composing reflections…
              {:else}
                Tap generate to summarize this week's numbers with honest, observational wording.
              {/if}
            </p>
          {/if}
        </Card>
      {/if}

      {#if aiFeatures.subjectDifficultyEnabled}
        <Card>
          <div class="flex items-start justify-between gap-3 mb-4">
            <div>
              <div class="flex items-center gap-2 text-xs font-semibold uppercase tracking-wide text-moss-600">
                <BookOpen size={14} /> Subject signals
              </div>
              <p class="mt-1 text-sm text-ink-500">
                Needs ≥30-day subjects with ≥3 sessions each — otherwise Groq stays dark.
              </p>
            </div>
            <Button variant="secondary" onclick={onAnalyzeSubjects} disabled={difficultyBusy}>
              {#if difficultyBusy}
                <Loader2 size={14} class="inline animate-spin" /> Thinking…
              {:else}
                Analyze my subjects
              {/if}
            </Button>
          </div>

          {#if difficultyCached && !difficultyBusy}
            <div class="space-y-2 rounded-2xl border border-ink-100 bg-[#fcfcfa] p-4 text-sm text-ink-800">
              <p class="font-semibold">{difficultyCached.hardest_subject}</p>
              <p>{difficultyCached.reason}</p>
              <p class="text-ink-600">{difficultyCached.suggestion}</p>
            </div>
          {:else if difficultyInsufficient && !difficultyBusy}
            <p class="text-sm text-ink-600">Not enough data yet — log a few broader sessions across subjects.</p>
          {:else if !difficultyBusy}
            <p class="text-sm text-ink-500">Run analyzer or revisit later (cached daily per snapshot).</p>
          {/if}
        </Card>
      {/if}
    </section>
  {/if}

  <!-- ─────────── Control Bar ─────────── -->
  <div class="rounded-[1.5rem] border border-ink-200 bg-white p-4 shadow-sm">
    <div class="flex flex-col gap-4 sm:flex-row sm:items-end sm:flex-wrap">

      <!-- Period selector -->
      <div class="flex-1 min-w-[200px]">
        <label class="block text-xs font-medium text-ink-500 mb-1.5">
          <CalendarRange size={12} class="inline mr-1" /> Period
        </label>
        <div class="flex flex-wrap gap-1">
          {#each QUICK_RANGES as r}
            <button
              class="rounded-xl border px-3 py-1.5 text-xs font-medium transition-all
                     {quickRange === r.value
                       ? 'border-moss-400 bg-moss-50 text-moss-700'
                       : 'border-ink-200 text-ink-500 hover:border-moss-300 hover:text-moss-600'}"
              onclick={() => { quickRange = r.value; applyFilters(); }}
            >
              {r.label}
            </button>
          {/each}
        </div>
      </div>

      <!-- Granularity selector -->
      <div>
        <label class="block text-xs font-medium text-ink-500 mb-1.5">
          <BarChart3 size={12} class="inline mr-1" /> Data grouping
        </label>
        <div class="flex gap-1 rounded-2xl border border-ink-200 bg-ink-50 p-1">
          {#each GRANULARITIES as g}
            <button
              class="rounded-xl px-3 py-1.5 text-xs font-medium transition-all
                     {granularity === g.value
                       ? 'bg-white text-moss-600 shadow-sm'
                       : 'text-ink-500 hover:text-ink-900'}"
              onclick={() => { granularity = g.value; applyFilters(); }}
            >
              {g.label}
            </button>
          {/each}
        </div>
      </div>
    </div>

    <!-- Custom date range inputs -->
    {#if quickRange === 'custom'}
      <div class="mt-4 flex flex-wrap items-end gap-3 border-t border-ink-100 pt-4">
        <div>
          <label for="date-from" class="block text-xs font-medium text-ink-500 mb-1">From</label>
          <input
            id="date-from"
            type="date"
            bind:value={customFrom}
            max={customTo}
            onchange={applyFilters}
            class="rounded-xl border border-ink-200 bg-white px-3 py-2 text-sm text-ink-900 focus:border-moss-400 focus:outline-none"
          />
        </div>
        <div>
          <label for="date-to" class="block text-xs font-medium text-ink-500 mb-1">To</label>
          <input
            id="date-to"
            type="date"
            bind:value={customTo}
            min={customFrom}
            max={todayStr}
            onchange={applyFilters}
            class="rounded-xl border border-ink-200 bg-white px-3 py-2 text-sm text-ink-900 focus:border-moss-400 focus:outline-none"
          />
        </div>
        <p class="text-xs text-ink-400">
          Showing {granularity} data between {customFrom} and {customTo}
        </p>
      </div>
    {/if}
  </div>

  {#if loading}
    <div class="flex items-center justify-center py-20">
      <div class="h-8 w-8 animate-spin rounded-full border-2 border-moss-200 border-t-moss-600"></div>
    </div>
  {:else if sessions.length === 0}
    <Card>
      <EmptyState IconComponent={BarChart3} title="No data yet" description="Complete some study sessions to see analytics." />
    </Card>
  {:else}

    <!-- ─────────── Summary Cards ─────────── -->
    <section class="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
      <div class="rounded-[1.25rem] border border-ink-100 bg-white p-4 shadow-sm">
        <p class="text-xs font-medium text-ink-400">Total in period</p>
        <p class="mt-1 text-xl font-semibold text-ink-900">{formatMinutes(totalMinutes)}</p>
      </div>
      <div class="rounded-[1.25rem] border border-ink-100 bg-white p-4 shadow-sm">
        <p class="text-xs font-medium text-ink-400">Avg per active {granularity === 'hourly' ? 'hour' : granularity === 'daily' ? 'day' : granularity === 'weekly' ? 'week' : 'month'}</p>
        <p class="mt-1 text-xl font-semibold text-ink-900">{formatMinutes(avgValue)}</p>
      </div>
      <div class="rounded-[1.25rem] border border-ink-100 bg-white p-4 shadow-sm">
        <p class="text-xs font-medium text-ink-400">Peak {granularity === 'hourly' ? 'hour' : granularity === 'daily' ? 'day' : granularity === 'weekly' ? 'week' : 'month'}</p>
        <p class="mt-1 text-xl font-semibold text-ink-900">{formatMinutes(bestMinutes)}</p>
        <p class="mt-0.5 text-xs text-ink-400">{bestLabel}</p>
      </div>
      <div class="rounded-[1.25rem] border border-ink-100 bg-white p-4 shadow-sm">
        <p class="text-xs font-medium text-ink-400">Peak study hour</p>
        <p class="mt-1 text-xl font-semibold text-ink-900">{formatHour(peakHour)}</p>
      </div>
    </section>

    <!-- ─────────── Main Trend Chart ─────────── -->
    <Card>
      <div class="mb-4 flex items-center justify-between">
        <div class="flex items-center gap-2 text-sm font-medium text-ink-700">
          <TrendingUp size={15} />
          <span class="capitalize">{granularity}</span> trend
        </div>
        <span class="rounded-full bg-moss-50 px-2.5 py-1 text-xs text-moss-600">
          {quickRange === 'custom' ? `${customFrom} → ${customTo}` : QUICK_RANGES.find(r => r.value === quickRange)?.label}
        </span>
      </div>
      <div class="h-64">
        <canvas bind:this={mainChartCanvas}></canvas>
      </div>
    </Card>

    <!-- ─────────── Subject + Mood row ─────────── -->
    <section class="grid gap-4 lg:grid-cols-3">
      <!-- Subject doughnut -->
      <Card>
        <div class="mb-4 flex items-center gap-2 text-sm font-medium text-ink-700">
          <BookOpen size={15} /> Subject breakdown
        </div>
        {#if subjectBreakdown.length > 0}
          <div class="h-52">
            <canvas bind:this={subjectChartCanvas}></canvas>
          </div>
        {:else}
          <EmptyState IconComponent={BookOpen} title="No subjects tagged" description="Tag subjects in your sessions." />
        {/if}
      </Card>

      <!-- Mood bars -->
      <Card>
        <div class="mb-4 flex items-center gap-2 text-sm font-medium text-ink-700">
          <Smile size={15} /> Mood distribution
        </div>
        {#if moodDist.length > 0}
          <div class="space-y-3">
            {#each moodDist as m}
              <div>
                <div class="flex items-center justify-between mb-1">
                  <span class="text-sm capitalize text-ink-700">{m.mood}</span>
                  <span class="text-xs text-ink-400">{m.percentage}% · {m.count} sessions</span>
                </div>
                <div class="h-1.5 rounded-full bg-ink-100 overflow-hidden">
                  <div class="h-full rounded-full bg-moss-500 transition-all duration-500" style="width: {m.percentage}%"></div>
                </div>
              </div>
            {/each}
          </div>
        {:else}
          <EmptyState IconComponent={Smile} title="No mood data" description="Log your mood during sessions." />
        {/if}
      </Card>

      <!-- Study/Break ratio -->
      <Card>
        <div class="mb-4 flex items-center gap-2 text-sm font-medium text-ink-700">
          <Scale size={15} /> Study / Break ratio
        </div>
        <div class="flex flex-col items-center justify-center py-4 gap-3">
          <p class="text-4xl font-light text-ink-900">{studyBreakRatio.ratio}</p>
          <div class="w-full space-y-2">
            <div>
              <div class="flex justify-between text-xs text-ink-400 mb-1">
                <span>Study</span>
                <span>{formatMinutes(studyBreakRatio.studyMinutes)}</span>
              </div>
            <div class="h-2 rounded-full bg-ink-100">
                <div class="h-full rounded-full bg-moss-500" style="width: {Math.round(studyBreakRatio.studyMinutes / (studyBreakRatio.studyMinutes + studyBreakRatio.breakMinutes || 1) * 100)}%"></div>
              </div>
            </div>
            <div>
              <div class="flex justify-between text-xs text-ink-400 mb-1">
                <span>Break</span>
                <span>{formatMinutes(studyBreakRatio.breakMinutes)}</span>
              </div>
            <div class="h-2 rounded-full bg-ink-100">
                <div class="h-full rounded-full bg-moss-200" style="width: {Math.round(studyBreakRatio.breakMinutes / (studyBreakRatio.studyMinutes + studyBreakRatio.breakMinutes || 1) * 100)}%"></div>
              </div>
            </div>
          </div>
        </div>
      </Card>
    </section>

    <!-- ─────────── Hourly distribution (always) ─────────── -->
    <Card>
      <div class="mb-4 flex items-center gap-2 text-sm font-medium text-ink-700">
        <Clock size={15} /> Peak study hours (by time of day)
      </div>
      <div class="h-52">
        <canvas bind:this={hourlyChartCanvas}></canvas>
      </div>
    </Card>

  {/if}
</div>
