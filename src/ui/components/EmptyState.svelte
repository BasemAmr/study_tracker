<script lang="ts">
  import { ClipboardList } from 'lucide-svelte';

  let {
    IconComponent = ClipboardList as any,
    title = 'Nothing here yet',
    description = ''
  }: {
    IconComponent?: any;
    title?: string;
    description?: string;
  } = $props();
</script>

<div class="flex flex-col items-center justify-center py-12 text-center">
  <div class="rounded-2xl bg-ink-100/60 p-4 text-ink-500">
    <IconComponent size={32} strokeWidth={1.5} />
  </div>
  <p class="mt-4 text-base font-medium text-ink-700">{title}</p>
  {#if description}
    <p class="mt-2 max-w-xs text-sm text-ink-500">{description}</p>
  {/if}
</div>
