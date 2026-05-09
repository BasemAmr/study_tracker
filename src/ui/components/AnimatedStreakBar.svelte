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

<div class="relative w-full h-2 bg-orange-100/30 rounded-full overflow-hidden border border-orange-200/20">
  <!-- The Base Fill -->
  <div 
    class="absolute left-0 top-0 h-full rounded-full transition-all duration-[2000ms] ease-out shadow-[0_0_15px_rgba(239,68,68,0.4)]"
    style={`width: ${currentProgress * 100}%; background: linear-gradient(90deg, #F59E0B 0%, #EF4444 100%);`}
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
      rgba(255, 255, 255, 0.4) 50%,
      rgba(255, 255, 255, 0) 100%
    );
    animation: glisten 2.5s infinite ease-in-out;
  }

  .shimmer-animation {
    background: linear-gradient(
      90deg,
      transparent 0%,
      rgba(255, 255, 255, 0) 30%,
      rgba(255, 255, 255, 0.8) 50%,
      rgba(255, 255, 255, 0) 70%,
      transparent 100%
    );
    animation: shimmer 3s infinite linear;
    transform: skewX(-30deg);
  }

  @keyframes shimmer {
    0% { transform: translateX(-150%) skewX(-30deg); }
    100% { transform: translateX(150%) skewX(-30deg); }
  }

  @keyframes glisten {
    0%, 100% { opacity: 0.3; transform: scaleX(0.8); }
    50% { opacity: 1.0; transform: scaleX(1.2); }
  }
</style>
