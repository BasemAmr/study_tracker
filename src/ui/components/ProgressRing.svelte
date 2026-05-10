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

  // Motion: Slow start, fast finish (Ease-In)
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
  const shimmerId = `shimmer-gradient-${Math.random().toString(36).substring(2, 9)}`;
  const maskId = `ring-mask-${Math.random().toString(36).substring(2, 9)}`;
</script>

<div class="inline-flex flex-col items-center gap-2">
  <div class="relative">
    <svg width={size} height={size} class="-rotate-90 drop-shadow-2xl overflow-visible">
      <defs>
        <!-- Main Progress Gradient -->
        <linearGradient id={gradientId} x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#F59E0B" />
          <stop offset="100%" stop-color="#EF4444" />
        </linearGradient>

        <!-- Moving Shimmer Gradient (Soft & Faded) -->
        <linearGradient id={shimmerId} x1="0%" y1="0%" x2="100%" y2="0%">
          <stop offset="0%" stop-color="transparent" />
          <stop offset="45%" stop-color="transparent" />
          <stop offset="50%" stop-color="rgba(255, 255, 255, 0.9)" />
          <stop offset="55%" stop-color="transparent" />
          <stop offset="100%" stop-color="transparent" />
        </linearGradient>

        <!-- Mask to keep shimmer strictly on the progress fill -->
        <mask id={maskId}>
          <circle
            cx={size / 2}
            cy={size / 2}
            r={radius}
            fill="none"
            stroke="white"
            stroke-width={strokeWidth}
            stroke-dasharray={circumference}
            stroke-dashoffset={offset}
            stroke-linecap="round"
          />
        </mask>
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

      <!-- Alive Shimmer Overlay (Traveling Light) -->
      <g mask="url(#{maskId})">
        <rect
          x="-50%"
          y="0"
          width="200%"
          height="100%"
          fill="url(#{shimmerId})"
          class="shimmer-glint"
        />
      </g>
    </svg>
    
    <!-- High-Intensity Inner Glow -->
    <div class="absolute inset-0 pointer-events-none rounded-full flex items-center justify-center">
       <div 
         class="w-full h-full rounded-full animate-pulse opacity-40" 
         style="background: radial-gradient(circle, rgba(239,68,68,0.3) 0%, transparent 85%); filter: blur(16px);"
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

  .shimmer-glint {
    animation: glint-move 3s infinite ease-in-out;
    mix-blend-mode: overlay;
    filter: blur(2px);
  }

  @keyframes glint-move {
    0% { transform: translateX(-50%) rotate(0deg); }
    100% { transform: translateX(50%) rotate(360deg); }
  }
</style>
