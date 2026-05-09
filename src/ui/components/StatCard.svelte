<script lang="ts">
  import { CalendarDays, TrendingUp, Flame, Clock, FileText, Target, ClipboardList } from 'lucide-svelte';
  import type { Component } from 'svelte';

  let {
    label,
    value,
    detail,
    icon
  }: {
    label: string;
    value: string;
    detail?: string;
    icon?: string;
  } = $props();

  const iconMap: Record<string, any> = {
    today: CalendarDays,
    week: TrendingUp,
    streak: Flame,
    total: Clock,
    sessions: FileText,
    goal: Target
  };

  const IconComponent = icon ? (iconMap[icon] ?? ClipboardList) : null;
</script>

<article class="rounded-[1.5rem] border border-ink-100 bg-white p-5 shadow-sm transition-all duration-200 hover:-translate-y-0.5 hover:shadow-card">
  <div class="flex items-start justify-between">
    <p class="text-sm text-ink-500">{label}</p>
    {#if IconComponent}
      <div class="rounded-xl bg-moss-50 p-2 text-moss-600">
        <IconComponent size={18} strokeWidth={1.8} />
      </div>
    {/if}
  </div>
  <p class="mt-3 text-3xl font-semibold tracking-tight text-ink-900">{value}</p>
  {#if detail}
    <p class="mt-2 text-sm text-moss-600">{detail}</p>
  {/if}
</article>
