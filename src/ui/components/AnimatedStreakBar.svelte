<script lang="ts">
  import { onMount } from 'svelte';
  
  export let progress: number = 0; // 0 to 1
  
  let currentProgress = 0;

  onMount(() => {
    // Fill Animation on Load
    // We start at 0, and animate to the target progress using a CSS transition
    setTimeout(() => {
      currentProgress = progress;
    }, 50); // tiny delay to allow DOM to render 0% first
  });

  // Watch for progress prop changes (if updated dynamically later)
  $: {
    if (typeof window !== 'undefined') {
      currentProgress = progress;
    }
  }
</script>

<div class="relative w-full h-2 bg-moss-50/50 rounded-full overflow-hidden border border-moss-100/30">
  <!-- The Base Fill -->
  <div 
    class="absolute left-0 top-0 h-full rounded-full transition-all duration-1000 ease-out shadow-[0_0_12px_rgba(34,197,94,0.3)]"
    style={`width: ${currentProgress * 100}%; background: linear-gradient(90deg, #4ADE80 0%, #22C55E 100%);`}
  >
    <!-- Glistening Overlay -->
    <div class="absolute inset-0 glistening-overlay"></div>
    
    <!-- Infinite Shimmer -->
    <div class="absolute inset-0 w-[200%] shimmer-animation"></div>
  </div>
</div>

<style>
  .glistening-overlay {
    background: linear-gradient(
      90deg,
      rgba(255, 255, 255, 0) 0%,
      rgba(255, 255, 255, 0.3) 50%,
      rgba(255, 255, 255, 0) 100%
    );
    animation: glisten 3s infinite ease-in-out;
  }

  .shimmer-animation {
    background: linear-gradient(
      90deg,
      transparent 0%,
      rgba(255, 255, 255, 0) 40%,
      rgba(255, 255, 255, 0.6) 50%,
      rgba(255, 255, 255, 0) 60%,
      transparent 100%
    );
    animation: shimmer 4s infinite linear;
    transform: skewX(-20deg);
  }

  @keyframes shimmer {
    0% { transform: translateX(-100%) skewX(-20deg); }
    100% { transform: translateX(100%) skewX(-20deg); }
  }

  @keyframes glisten {
    0%, 100% { opacity: 0.4; transform: scaleX(0.9); }
    50% { opacity: 0.9; transform: scaleX(1.1); }
  }
</style>
