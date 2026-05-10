<script lang="ts">
  import { onMount } from 'svelte';
  import { tweened } from 'svelte/motion';
  import { cubicOut } from 'svelte/easing';

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

  // Motion: Start from 0 and fill slowly to value
  const animatedValue = tweened(0, {
    duration: 3000,
    easing: cubicOut
  });

  onMount(() => {
    // Force reset to 0 before filling to ensure the "fill from start" effect on every reload
    animatedValue.set(0, { duration: 0 });
    setTimeout(() => {
      animatedValue.set(value);
    }, 100);
  });

  // Keep in sync if value changes later
  $effect(() => {
    animatedValue.set(value);
  });

  const radius = $derived((size - strokeWidth) / 2);
  const circumference = $derived(2 * Math.PI * radius);
  const percentage = $derived(max > 0 ? Math.min($animatedValue / max, 1) : 0);
  const offset = $derived(circumference * (1 - percentage));
  
  const gradientId = `ring-gradient-${Math.random().toString(36).substring(2, 9)}`;
  const shimmerId = `shimmer-gradient-${Math.random().toString(36).substring(2, 9)}`;
</script>

<div class="inline-flex flex-col items-center gap-2">
  <div class="relative">
    <svg width={size} height={size} class="-rotate-90 drop-shadow-xl overflow-visible">
      <defs>
        <!-- Main Progress Gradient -->
        <linearGradient id={gradientId} x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#F59E0B" />
          <stop offset="100%" stop-color="#EF4444" />
        </linearGradient>

        <!-- Shimmer Moving Gradient -->
        <linearGradient id={shimmerId} x1="0%" y1="0%" x2="100%" y2="0%">
          <stop offset="0%" stop-color="rgba(255, 255, 255, 0)" />
          <stop offset="50%" stop-color="rgba(255, 255, 255, 0.8)" />
          <stop offset="100%" stop-color="rgba(255, 255, 255, 0)" />
        </linearGradient>
      </defs>

      <!-- Track -->
      <circle
        cx={size / 2}
        cy={size / 2}
        r={radius}
        fill="none"
        stroke="currentColor"
        class="text-orange-100/10"
        stroke-width={strokeWidth}
      />

      <!-- Progress Fill -->
      <circle
        cx={size / 2}
        cy={size / 2}
        r={radius}
        fill="none"
        stroke="url(#{gradientId})"
        class="progress-ring-stroke"
        stroke-width={strokeWidth}
        stroke-dasharray={circumference}
        stroke-dashoffset={offset}
        stroke-linecap="round"
      />

      <!-- Shimmer Layer (Animated via CSS Background) -->
      <circle
        cx={size / 2}
        cy={size / 2}
        r={radius}
        fill="none"
        stroke="url(#{shimmerId})"
        class="shimmer-ring"
        stroke-width={strokeWidth + 1}
        stroke-dasharray={circumference}
        stroke-dashoffset={offset}
        stroke-linecap="round"
        style={`visibility: ${percentage > 0.05 ? 'visible' : 'hidden'};`}
      />
    </svg>
    
    <!-- High-Intensity Inner Glow -->
    <div class="absolute inset-0 pointer-events-none rounded-full flex items-center justify-center">
       <div 
         class="w-full h-full rounded-full animate-pulse opacity-60" 
         style="background: radial-gradient(circle, rgba(239,68,68,0.25) 0%, transparent 80%); filter: blur(12px);"
       ></div>
    </div>
  </div>
  
  {#if label}
    <span class="text-[10px] font-bold text-orange-600/80 tracking-[0.1em] uppercase">{label}</span>
  {/if}
</div>

<style>
  .progress-ring-stroke {
    filter: drop-shadow(0 0 10px rgba(239, 68, 68, 0.5));
    transition: none; /* Handled by Svelte motion */
  }

  .shimmer-ring {
    animation: shimmer-move 3s infinite linear;
    filter: blur(1px) brightness(1.2);
  }

  @keyframes shimmer-move {
    0% { opacity: 0; stroke-width: 0; }
    10% { opacity: 1; stroke-width: inherit; }
    90% { opacity: 1; stroke-width: inherit; }
    100% { opacity: 0; stroke-width: 0; }
  }
</style>
