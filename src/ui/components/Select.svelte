<script lang="ts">
  type Option = { value: string; label: string };

  let {
    label = '',
    value = $bindable(''),
    options = [],
    placeholder = 'Select...',
    disabled = false
  }: {
    label?: string;
    value?: string;
    options?: Option[];
    placeholder?: string;
    disabled?: boolean;
  } = $props();
  const id = `select-${Math.random().toString(36).substring(2, 9)}`;
</script>

<div class="space-y-1.5">
  {#if label}
    <label for={id} class="block text-sm font-medium text-ink-700">{label}</label>
  {/if}

  <select
    {id}
    bind:value
    {disabled}
    class="w-full appearance-none rounded-xl border border-ink-200 bg-white px-4 py-2.5 pe-8 text-sm text-ink-900 transition-colors duration-150 focus:border-moss-300 focus:outline-none focus:ring-2 focus:ring-moss-100 disabled:opacity-50"
  >
    <option value="" disabled>{placeholder}</option>
    {#each options as option}
      <option value={option.value}>{option.label}</option>
    {/each}
  </select>
</div>
