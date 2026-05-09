<script lang="ts">
  import { toasts, type Toast } from '@/core/stores/toastStore';
  import { Check, X, AlertTriangle, Info } from 'lucide-svelte';
  import type { Component } from 'svelte';

  const typeStyles: Record<string, string> = {
    success: 'bg-moss-50 border-moss-200 text-moss-600',
    error: 'bg-red-50 border-red-200 text-red-600',
    warning: 'bg-amber-50 border-amber-200 text-amber-600',
    info: 'bg-blue-50 border-blue-200 text-blue-600'
  };

  const typeIcons: Record<string, any> = {
    success: Check,
    error: X,
    warning: AlertTriangle,
    info: Info
  };
</script>

<div class="fixed bottom-6 right-6 z-[100] flex flex-col gap-3">
  {#each $toasts as toast (toast.id)}
    {@const IconComp = typeIcons[toast.type] ?? Info}
    <div
      class="flex items-center gap-3 rounded-2xl border px-4 py-3 shadow-card animate-toast {typeStyles[toast.type] ?? typeStyles.info}"
    >
      <div class="flex h-6 w-6 items-center justify-center rounded-full bg-white/60">
        <IconComp size={14} strokeWidth={2.5} />
      </div>
      <span class="text-sm font-medium">{toast.message}</span>
      <button
        class="ml-2 rounded-lg p-1 opacity-60 transition-opacity hover:opacity-100"
        onclick={() => toasts.dismiss(toast.id)}
        aria-label="Dismiss"
      >
        <X size={14} strokeWidth={2} />
      </button>
    </div>
  {/each}
</div>

<style>
  .animate-toast {
    animation: toastIn 0.3s ease-out;
  }

  @keyframes toastIn {
    from {
      opacity: 0;
      transform: translateX(20px);
    }
    to {
      opacity: 1;
      transform: translateX(0);
    }
  }
</style>
