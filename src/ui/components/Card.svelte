<script lang="ts">
  import type { Snippet } from 'svelte';

  let {
    padding = 'p-5',
    hover = false,
    children
  }: {
    padding?: string;
    hover?: boolean;
    children: Snippet;
  } = $props();
</script>

<div
  class="rounded-[1.5rem] border border-ink-100 bg-white shadow-sm {padding} {hover
    ? 'transition-all duration-200 hover:-translate-y-0.5 hover:shadow-card cursor-pointer'
    : ''}"
>
  {@render children()}
</div>
