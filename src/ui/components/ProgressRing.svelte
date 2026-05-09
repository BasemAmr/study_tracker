<script lang="ts">
  import { onMount } from 'svelte';

  let {
    value = 0,
    max = 100,
    size = 80,
    strokeWidth = 6,
    label = ''
  }: {
    value?: number;
    max?: number;
    size?: number;
    strokeWidth?: number;
    label?: string;
  } = $props();

  let animatedValue = $state(0);

  onMount(() => {
    setTimeout(() => {
      animatedValue = value;
    }, 100);
  });

  // Keep animatedValue in sync if value changes later
  $effect(() => {
    animatedValue = value;
  });

  const radius = $derived((size - strokeWidth) / 2);
  const circumference = $derived(2 * Math.PI * radius);
  const percentage = $derived(max > 0 ? Math.min(animatedValue / max, 1) : 0);
  const offset = $derived(circumference * (1 - percentage));
  
  // Unique ID for the gradient to avoid collisions if multiple rings exist
  const gradientId = `ring-gradient-${Math.random().toString(36).substr(2, 9)}`;
</script>

<div class="inline-flex flex-col items-center gap-2">
  <div class="relative">
    <svg width={size} height={size} class="-rotate-90 drop-shadow-sm">
      <defs>
        <linearGradient id={gradientId} x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#4ADE80" />
          <stop offset="100%" stop-color="#22C55E" />
        </linearGradient>
      </defs>
      <!-- Background circle -->
      <circle
        cx={size / 2}
        cy={size / 2}
        r={radius}
        fill="none"
        stroke="currentColor"
        class="text-ink-100/30"
        stroke-width={strokeWidth}
      />
      <!-- Progress arc -->
      <circle
        cx={size / 2}
        cy={size / 2}
        r={radius}
        fill="none"
        stroke="url(#{gradientId})"
        class="transition-all duration-1000 ease-out progress-ring-stroke"
        stroke-width={strokeWidth}
        stroke-dasharray={circumference}
        stroke-dashoffset={offset}
        stroke-linecap="round"
      />
    </svg>
    
    <!-- Inner Glisten Effect (Overlay) -->
    <div class="absolute inset-0 pointer-events-none rounded-full flex items-center justify-center">
       <div class="w-[80%] h-[80%] rounded-full bg-moss-200/5 blur-xl animate-pulse"></div>
    </div>
  </div>
  
  {#if label}
    <span class="text-xs font-medium text-moss-600">{label}</span>
  {/if}
</div>

<style>
  .progress-ring-stroke {
    filter: drop-shadow(0 0 4px rgba(34, 197, 94, 0.4));
  }
  
  /* Adding a subtle rotation/shimmer effect to the gradient via animation if possible, 
     but standard SVG filters are safer for performance. */
</style>
