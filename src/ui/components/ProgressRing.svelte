<script lang="ts">
  import { onMount } from 'svelte';
  import { tweened } from 'svelte/motion';
  import { cubicIn } from 'svelte/easing';

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

  // Motion: Slow at first, fast at finish (Ease-In)
  const animatedValue = tweened(0, {
    duration: 3500,
    easing: cubicIn
  });

  onMount(() => {
    animatedValue.set(0, { duration: 0 });
    setTimeout(() => {
      animatedValue.set(value);
    }, 150);
  });

  $effect(() => {
    animatedValue.set(value);
  });

  const radius = $derived((size - strokeWidth) / 2);
  const circumference = $derived(2 * Math.PI * radius);
  const percentage = $derived(max > 0 ? Math.min($animatedValue / max, 1) : 0);
  const offset = $derived(circumference * (1 - percentage));
  
  const gradientId = `ring-gradient-${Math.random().toString(36).substring(2, 9)}`;
</script>

<div class="inline-flex flex-col items-center gap-2">
  <div class="relative">
    <svg width={size} height={size} class="-rotate-90 drop-shadow-2xl overflow-visible">
      <defs>
        <linearGradient id={gradientId} x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#F59E0B" />
          <stop offset="100%" stop-color="#EF4444" />
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

      <!-- Shimmer "Traveler" -->
      <!-- We use a small dash that travels from 0 to the current progress point -->
      <circle
        cx={size / 2}
        cy={size / 2}
        r={radius}
        fill="none"
        stroke="white"
        class="shimmer-traveler"
        stroke-width={strokeWidth - 1}
        stroke-dasharray={`${circumference * 0.15} ${circumference}`}
        stroke-linecap="round"
        style={`--circumference: ${circumference}; --offset: ${offset}; visibility: ${percentage > 0.05 ? 'visible' : 'hidden'};`}
      />
    </svg>
    
    <!-- High-Intensity Inner Glow -->
    <div class="absolute inset-0 pointer-events-none rounded-full flex items-center justify-center">
       <div 
         class="w-full h-full rounded-full animate-pulse opacity-50" 
         style="background: radial-gradient(circle, rgba(239,68,68,0.3) 0%, transparent 85%); filter: blur(14px);"
       ></div>
    </div>
  </div>
  
  {#if label}
    <span class="text-[10px] font-black text-orange-600/90 tracking-[0.15em] uppercase">{label}</span>
  {/if}
</div>

<style>
  .progress-ring-stroke {
    filter: drop-shadow(0 0 12px rgba(239, 68, 68, 0.4));
  }

  .shimmer-traveler {
    opacity: 0.8;
    filter: blur(1px);
    animation: travel 2.5s infinite ease-in-out;
  }

  @keyframes travel {
    0% {
      stroke-dashoffset: var(--circumference);
      opacity: 0;
    }
    10%, 90% {
      opacity: 1;
    }
    100% {
      /* Ends at the current progress offset */
      stroke-dashoffset: var(--offset);
      opacity: 0;
    }
  }
</style>
