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
        stroke="rgba(255, 255, 255, 0.6)"
        class="shimmer-arc"
        stroke-width={strokeWidth - 2}
        stroke-dasharray={`${circumference * 0.1} ${circumference * 0.9}`}
        stroke-linecap="round"
        style={`--circumference: ${circumference}; visibility: ${percentage > 0 ? 'visible' : 'hidden'};`}
      />
    </svg>
    
    <!-- Inner Fire Glow -->
    <div class="absolute inset-0 pointer-events-none rounded-full flex items-center justify-center">
       <div class="w-[85%] h-[85%] rounded-full bg-red-400/10 blur-2xl animate-pulse"></div>
    </div>
  </div>
  
  {#if label}
    <span class="text-xs font-semibold text-orange-600 tracking-wide uppercase">{label}</span>
  {/if}
</div>

<style>
  .progress-ring-stroke {
    filter: drop-shadow(0 0 6px rgba(239, 68, 68, 0.5));
  }
  
  .shimmer-arc {
    animation: rotate-shimmer 3s infinite linear;
    transform-origin: center;
  }

  @keyframes rotate-shimmer {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }
</style>
