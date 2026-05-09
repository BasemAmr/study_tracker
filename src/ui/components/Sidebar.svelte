<script lang="ts">
  import { currentRoute, navigate, type Route } from '@/core/stores/router';
  import { isTimerActive } from '@/core/stores/timerStore';
  import { LayoutDashboard, Timer, BarChart3, Trophy, Settings2, Radio, Wifi, ArrowUpDown } from 'lucide-svelte';
  import ProfileSwitcher from './ProfileSwitcher.svelte';
  import SyncStatusIndicator from './SyncStatusIndicator.svelte';

  type NavItem = {
    route: Route;
    label: string;
    icon: typeof LayoutDashboard;
  };

  const mainNav: NavItem[] = [
    { route: 'dashboard', label: 'Dashboard', icon: LayoutDashboard },
    { route: 'sessions', label: 'Sessions', icon: Timer },
    { route: 'analytics', label: 'Analytics', icon: BarChart3 },
    { route: 'achievements', label: 'Achievements', icon: Trophy },
    { route: 'sync', label: 'Sync', icon: ArrowUpDown },
    { route: 'settings', label: 'Settings', icon: Settings2 }
  ];
</script>

<aside class="hidden h-full min-h-0 w-64 shrink-0 overflow-y-auto overscroll-y-contain rounded-[1.75rem] border border-ink-200 bg-mist/90 p-5 shadow-card lg:flex lg:flex-col">
  <!-- Brand -->
  <div class="mb-6 flex flex-col gap-4">
    <div>
      <p class="text-xs font-semibold uppercase tracking-[0.3em] text-moss-600">StudyTracker</p>
      <p class="mt-2 text-sm leading-6 text-ink-500">Track your growth</p>
    </div>
    
    <ProfileSwitcher />
  </div>

  <!-- Navigation -->
  <nav class="mt-8 space-y-1 text-sm">
    {#each mainNav as item}
      <button
        class="flex w-full items-center gap-3 rounded-2xl px-4 py-3 text-left transition-all duration-150 {$currentRoute === item.route
          ? 'bg-moss-100 font-medium text-moss-600'
          : 'text-ink-700 hover:bg-ink-100/80'}"
        onclick={() => navigate(item.route)}
      >
        <item.icon size={18} strokeWidth={1.8} />
        <span>{item.label}</span>
      </button>
    {/each}
  </nav>

  <!-- Footer -->
  <div class="mt-auto space-y-3">
    {#if $isTimerActive}
      <div class="rounded-[1.5rem] border border-moss-300 bg-moss-50 p-4">
        <div class="flex items-center gap-2">
          <Radio size={14} class="text-moss-600 animate-pulse" />
          <p class="text-xs uppercase tracking-[0.25em] text-moss-600">Timer active</p>
        </div>
        <button
          class="mt-2 text-sm font-medium text-moss-600 hover:underline"
          onclick={() => navigate('sessions')}
        >
          Go to session →
        </button>
      </div>
    {/if}

    <SyncStatusIndicator />
  </div>
</aside>
