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
    <svg width={size} height={size} class="-rotate-90 drop-shadow-lg">
      <defs>
        <linearGradient id={gradientId} x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#F59E0B" />
          <stop offset="100%" stop-color="#EF4444" />
        </linearGradient>
      </defs>
      <!-- Background circle -->
      <circle
        cx={size / 2}
        cy={size / 2}
        r={radius}
        fill="none"
        stroke="currentColor"
        class="text-orange-100/10"
        stroke-width={strokeWidth}
      />
      <!-- Progress arc -->
      <circle
        cx={size / 2}
        cy={size / 2}
        r={radius}
        fill="none"
        stroke="url(#{gradientId})"
        class="transition-all duration-[2000ms] ease-out progress-ring-stroke"
        stroke-width={strokeWidth}
        stroke-dasharray={circumference}
        stroke-dashoffset={offset}
        stroke-linecap="round"
      />
      
      <!-- Shimmer Arc Overlay -->
      <circle
        cx={size / 2}
        cy={size / 2}
        r={radius}
        fill="none"
        stroke="rgba(255, 255, 255, 0.75)"
        class="shimmer-arc"
        stroke-width={strokeWidth - 2}
        stroke-dasharray={`${circumference * 0.15} ${circumference * 0.85}`}
        stroke-linecap="round"
        style={`--circumference: ${circumference}; visibility: ${percentage > 0 ? 'visible' : 'hidden'};`}
      />
    </svg>
    
    <!-- Inner Fire Glow -->
    <div class="absolute inset-0 pointer-events-none rounded-full flex items-center justify-center">
       <div class="w-full h-full rounded-full animate-pulse" style="background: radial-gradient(circle, rgba(239,68,68,0.18) 0%, transparent 70%); filter: blur(8px);"></div>
    </div>
  </div>
  
  {#if label}
    <span class="text-xs font-semibold text-orange-600 tracking-wide uppercase">{label}</span>
  {/if}
</div>

<style>
  .progress-ring-stroke {
    filter: drop-shadow(0 0 8px rgba(239, 68, 68, 0.6)) drop-shadow(0 0 16px rgba(245, 158, 11, 0.3));
  }

  .shimmer-arc {
    transform-box: fill-box;
    transform-origin: 50% 50%;
    animation: rotate-shimmer 2.5s infinite linear;
  }

  @keyframes rotate-shimmer {
    from { stroke-dashoffset: 0; }
    to { stroke-dashoffset: calc(var(--circumference) * -1); }
  }
</style>
