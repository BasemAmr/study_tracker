<script lang="ts">
  import { dateRange, daysAgo } from '@/core/utils/dateUtils';

  let {
    dailyMinutes = new Map<string, number>()
  }: {
    dailyMinutes?: Map<string, number>;
  } = $props();

  const days = 364;
  const startDate = daysAgo(days);
  const endDate = new Date();
  const allDates = dateRange(startDate, endDate);

  // Group by week (columns), days of week (rows)
  function buildGrid() {
    const weeks: Array<Array<{ date: string; minutes: number; level: number }>> = [];
    let currentWeek: Array<{ date: string; minutes: number; level: number }> = [];

    for (const date of allDates) {
      const year = date.getFullYear();
      const month = String(date.getMonth() + 1).padStart(2, '0');
      const day = String(date.getDate()).padStart(2, '0');
      const dateStr = `${year}-${month}-${day}`;
      const minutes = dailyMinutes.get(dateStr) ?? 0;
      const level = getLevel(minutes);

      if (date.getDay() === 0 && currentWeek.length > 0) {
        weeks.push(currentWeek);
        currentWeek = [];
      }

      currentWeek.push({ date: dateStr, minutes, level });
    }

    if (currentWeek.length > 0) {
      weeks.push(currentWeek);
    }

    return weeks;
  }

  function getLevel(minutes: number): number {
    if (minutes === 0) return 0;
    if (minutes < 30) return 1;
    if (minutes < 60) return 2;
    if (minutes < 120) return 3;
    return 4;
  }

  const levelColors = [
    'bg-ink-100',
    'bg-moss-100',
    'bg-moss-300',
    'bg-moss-500',
    'bg-moss-600'
  ];

  const weeks = buildGrid();

  const monthLabels: Array<{ label: string; weekIndex: number }> = [];
  let lastMonthLabel = '';
  for (let w = 0; w < weeks.length; w++) {
    const firstDate = weeks[w][0];
    if (firstDate) {
      const date = new Date(firstDate.date);
      const monthStr = date.toLocaleDateString('en-US', { month: 'short' });
      if (monthStr !== lastMonthLabel) {
        monthLabels.push({ label: monthStr, weekIndex: w });
        lastMonthLabel = monthStr;
      }
    }
  }
</script>

<div class="space-y-3">
  <!-- Month labels -->
  <div class="flex gap-[3px] pl-8 text-[10px] text-ink-500">
    {#each monthLabels as m}
      <span style="margin-left: {m.weekIndex * 13}px; position: absolute;">{m.label}</span>
    {/each}
  </div>

  <div class="flex gap-[3px] mt-5">
    <!-- Day labels -->
    <div class="flex flex-col gap-[3px] text-[10px] text-ink-500 pr-1.5 pt-0">
      <span class="h-[11px]"></span>
      <span class="h-[11px] leading-[11px]">Mon</span>
      <span class="h-[11px]"></span>
      <span class="h-[11px] leading-[11px]">Wed</span>
      <span class="h-[11px]"></span>
      <span class="h-[11px] leading-[11px]">Fri</span>
      <span class="h-[11px]"></span>
    </div>

    <!-- Grid -->
    <div class="flex gap-[3px] overflow-x-auto">
      {#each weeks as week}
        <div class="flex flex-col gap-[3px]">
          {#each week as day}
            <div
              class="h-[11px] w-[11px] rounded-[2px] {levelColors[day.level]} transition-colors duration-150"
              title="{day.date}: {day.minutes}m"
            ></div>
          {/each}
        </div>
      {/each}
    </div>
  </div>

  <!-- Legend -->
  <div class="flex items-center gap-1.5 text-[10px] text-ink-500">
    <span>Less</span>
    {#each levelColors as color}
      <div class="h-[11px] w-[11px] rounded-[2px] {color}"></div>
    {/each}
    <span>More</span>
  </div>
</div>
