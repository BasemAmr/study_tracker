<script lang="ts">
  import type { Snippet } from 'svelte';

  type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger';
  type ButtonSize = 'sm' | 'md' | 'lg';

  let {
    variant = 'primary',
    size = 'md',
    disabled = false,
    onclick,
    children
  }: {
    variant?: ButtonVariant;
    size?: ButtonSize;
    disabled?: boolean;
    onclick?: (e: MouseEvent) => void;
    children: Snippet;
  } = $props();

  const baseClasses =
    'inline-flex items-center justify-center font-medium transition-all duration-200 rounded-2xl focus:outline-none focus:ring-2 focus:ring-moss-300 focus:ring-offset-2 active:scale-[0.97]';

  const variantClasses: Record<ButtonVariant, string> = {
    primary: 'bg-moss-600 text-white shadow-sm hover:bg-moss-500 hover:-translate-y-0.5',
    secondary: 'bg-white text-ink-700 border border-ink-200 shadow-sm hover:bg-ink-100/60 hover:-translate-y-0.5',
    ghost: 'text-ink-500 hover:text-ink-900 hover:bg-ink-100/60',
    danger: 'bg-red-50 text-red-600 border border-red-200 hover:bg-red-100'
  };

  const sizeClasses: Record<ButtonSize, string> = {
    sm: 'px-3 py-1.5 text-xs gap-1.5',
    md: 'px-4 py-2.5 text-sm gap-2',
    lg: 'px-6 py-3 text-base gap-2.5'
  };

  const classes = $derived(`${baseClasses} ${variantClasses[variant]} ${sizeClasses[size]} ${disabled ? 'opacity-50 pointer-events-none' : ''}`);
</script>

<button class={classes} {disabled} onclick={onclick}>
  {@render children()}
</button>
