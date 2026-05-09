<script lang="ts">
  import type { Snippet } from 'svelte';

  let {
    open = $bindable(false),
    title = '',
    children,
    onclose
  }: {
    open?: boolean;
    title?: string;
    children: Snippet;
    onclose?: () => void;
  } = $props();

  function handleClose() {
    open = false;
    onclose?.();
  }

  function handleBackdrop(e: MouseEvent) {
    if (e.target === e.currentTarget) {
      handleClose();
    }
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      handleClose();
    }
  }
</script>

<svelte:window onkeydown={handleKeydown} />

{#if open}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/20 backdrop-blur-sm transition-opacity duration-200"
    onclick={handleBackdrop}
  >
    <div
      class="mx-4 w-full max-w-lg rounded-[1.75rem] border border-ink-100 bg-white p-6 shadow-soft animate-in"
    >
      {#if title}
        <div class="mb-5 flex items-center justify-between">
          <h3 class="text-lg font-semibold text-ink-900">{title}</h3>
          <button
            class="rounded-xl p-1.5 text-ink-500 transition-colors hover:bg-ink-100 hover:text-ink-900"
            onclick={handleClose}
            aria-label="Close"
          >
            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </button>
        </div>
      {/if}

      {@render children()}
    </div>
  </div>
{/if}

<style>
  .animate-in {
    animation: modalIn 0.2s ease-out;
  }

  @keyframes modalIn {
    from {
      opacity: 0;
      transform: scale(0.95) translateY(8px);
    }
    to {
      opacity: 1;
      transform: scale(1) translateY(0);
    }
  }
</style>
