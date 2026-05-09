<script lang="ts">
  import { navigate } from '@/core/stores/router';
  import { syncStore, type GlobalSyncStatus } from '@/core/stores/syncStore';
  import { Wifi, WifiOff, CheckCircle, AlertCircle, Loader2 } from 'lucide-svelte';

  // Hide entirely when the user hasn't enabled sync — an opt-in config gate, not
  // inferred from server state. Keeps the shell quiet for users who never configure sync.
  $: globalStatus = $syncStore.globalStatus;
  $: syncEnabled = $syncStore.syncEnabled;

  function getStatusColor(status: GlobalSyncStatus): string {
    switch (status) {
      case 'idle': return 'text-ink-500';
      case 'syncing': return 'text-moss-500 animate-pulse';
      case 'success': return 'text-emerald-500';
      case 'error': return 'text-red-500';
      case 'no_peers': return 'text-ink-400';
      default: return 'text-ink-500';
    }
  }

  function getStatusIcon(status: GlobalSyncStatus) {
    switch (status) {
      case 'idle': return Wifi;
      case 'syncing': return Loader2;
      case 'success': return CheckCircle;
      case 'error': return AlertCircle;
      case 'no_peers': return WifiOff;
      default: return Wifi;
    }
  }

  function getStatusLabel(status: GlobalSyncStatus): string {
    switch (status) {
      case 'idle': return 'Synced';
      case 'syncing': return 'Syncing...';
      case 'success': return 'Just synced';
      case 'error': return 'Sync failed';
      case 'no_peers': return 'No devices found';
      default: return 'Synced';
    }
  }

  function handleClick() {
    navigate('sync');
  }
</script>

{#if syncEnabled}
<button
  class="w-full rounded-[1.5rem] border border-ink-100 bg-white p-4 text-left transition-all duration-200 hover:border-moss-200 hover:bg-moss-50/50"
  onclick={handleClick}
>
  <div class="flex items-center gap-2">
    <svelte:component
      this={getStatusIcon(globalStatus.status)}
      size={14}
      class={getStatusColor(globalStatus.status)}
    />
    <p class="text-xs uppercase tracking-[0.25em] {getStatusColor(globalStatus.status)}">
      Sync status
    </p>
  </div>
  <p class="mt-2 text-sm font-medium text-ink-900">
    {getStatusLabel(globalStatus.status)}
  </p>
  {#if globalStatus.lastError && globalStatus.status === 'error'}
    <p class="mt-1 text-xs text-red-600 line-clamp-1">
      {globalStatus.lastError}
    </p>
  {/if}
</button>
{/if}