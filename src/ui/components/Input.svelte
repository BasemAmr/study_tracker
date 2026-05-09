<script lang="ts">
  let {
    label = '',
    placeholder = '',
    value = $bindable(''),
    type = 'text',
    disabled = false,
    error = ''
  }: {
    label?: string;
    placeholder?: string;
    value?: string;
    type?: 'text' | 'number' | 'date' | 'time' | 'datetime-local' | 'textarea';
    disabled?: boolean;
    error?: string;
  } = $props();
  const id = `input-${Math.random().toString(36).substring(2, 9)}`;
</script>

<div class="space-y-1.5">
  {#if label}
    <label for={id} class="block text-sm font-medium text-ink-700">{label}</label>
  {/if}

  {#if type === 'textarea'}
    <textarea
      {id}
      bind:value
      {placeholder}
      {disabled}
      rows="3"
      class="w-full rounded-xl border border-ink-200 bg-white px-4 py-2.5 text-sm text-ink-900 placeholder-ink-200 transition-colors duration-150 focus:border-moss-300 focus:outline-none focus:ring-2 focus:ring-moss-100 disabled:opacity-50 {error ? 'border-red-300' : ''}"
    ></textarea>
  {:else}
    <input
      {id}
      {type}
      bind:value
      {placeholder}
      {disabled}
      class="w-full rounded-xl border border-ink-200 bg-white px-4 py-2.5 text-sm text-ink-900 placeholder-ink-200 transition-colors duration-150 focus:border-moss-300 focus:outline-none focus:ring-2 focus:ring-moss-100 disabled:opacity-50 {error ? 'border-red-300' : ''}"
    />
  {/if}

  {#if error}
    <p class="text-xs text-red-500">{error}</p>
  {/if}
</div>
