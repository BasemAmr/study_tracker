<script lang="ts">
  import { onDestroy } from 'svelte';
  import { MessageCircle, X } from 'lucide-svelte';
  import { debriefSignal, type AiDebriefPayload } from '@/core/stores/aiDebriefStore';

  let toast = $state<AiDebriefPayload | null>(null);
  let hideTimer = 0;

  const unsub = debriefSignal.subscribe((v) => {
    if (hideTimer) {
      window.clearTimeout(hideTimer);
      hideTimer = 0;
    }
    toast = v;
    if (v) {
      hideTimer = window.setTimeout(() => {
        debriefSignal.set(null);
        toast = null;
      }, 6000);
    }
  });

  function dismissNow() {
    if (hideTimer) window.clearTimeout(hideTimer);
    debriefSignal.set(null);
    toast = null;
  }

  onDestroy(() => {
    unsub();
    if (hideTimer) window.clearTimeout(hideTimer);
  });
</script>

{#if toast?.sentence?.trim()}
  <button
    type="button"
    class="fixed bottom-28 right-6 z-[60] flex max-w-sm items-start gap-3 rounded-2xl border border-moss-200 bg-white px-5 py-4 text-left shadow-2xl transition hover:border-moss-400 sm:right-10"
    onclick={dismissNow}
  >
    <MessageCircle size={22} class="mt-0.5 shrink-0 text-moss-600" aria-hidden="true" />
    <span class="text-sm text-ink-800 leading-relaxed">{toast.sentence.trim()}</span>
    <X size={18} class="mt-1 shrink-0 text-ink-300" aria-hidden="true" />
  </button>
{/if}
