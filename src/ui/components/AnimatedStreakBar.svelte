<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  
  export let progress: number = 0; // 0 to 1 target
  
  let canvas: HTMLCanvasElement;
  let container: HTMLDivElement;
  let rafId: number;
  
  function easeInOut(t: number): number {
    return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
  }

  onMount(() => {
    const ctx = canvas.getContext('2d')!;
    let currentFill = 0;
    let animProgress = 0;
    let lastTime: number | null = null;
    const cycleDuration = 5500;
    const fillDuration = 2000;

    function draw(ts: number) {
      if (!lastTime) lastTime = ts;
      const dt = ts - lastTime;
      lastTime = ts;

      // Update progress for sheen cycle
      animProgress = (animProgress + dt / cycleDuration) % 1;
      
      // Update fill progress (slow fill on load)
      if (currentFill < progress) {
        currentFill = Math.min(currentFill + dt / fillDuration, progress);
      } else if (currentFill > progress) {
        currentFill = progress;
      }

      const w = container.clientWidth;
      const h = container.clientHeight;
      if (canvas.width !== w || canvas.height !== h) {
        canvas.width = w;
        canvas.height = h;
      }

      ctx.clearRect(0, 0, w, h);
      const radius = h / 2;

      // 1. Track
      ctx.beginPath();
      ctx.roundRect(0, 0, w, h, radius);
      ctx.fillStyle = 'rgba(255, 228, 225, 0.1)';
      ctx.fill();

      if (currentFill > 0) {
        const filledWidth = w * currentFill;
        
        // 2. Base Fill
        ctx.save();
        ctx.beginPath();
        ctx.roundRect(0, 0, filledWidth, h, radius);
        const grad = ctx.createLinearGradient(0, 0, filledWidth, 0);
        grad.addColorStop(0, '#F59E0B');
        grad.addColorStop(1, '#EF4444');
        ctx.fillStyle = grad;
        ctx.shadowColor = 'rgba(239, 68, 68, 0.4)';
        ctx.shadowBlur = 10;
        ctx.fill();
        ctx.restore();

        // 3. Specular highlight sweep ("sheen pass")
        const eased = easeInOut(animProgress);
        const sheenCenter = filledWidth * eased;
        const sheenWidth = filledWidth * 0.135;
        const sheenHalfWidth = sheenWidth / 2;
        const sheenStart = Math.max(sheenCenter - sheenHalfWidth, 0) - 1;
        const sheenEnd = Math.min(sheenCenter + sheenHalfWidth, filledWidth) + 1;

        if (sheenEnd > sheenStart) {
          const isFull = progress >= 1;
          const fadeOut = isFull ? 1 : Math.min((1 - eased) / 0.04, 1);
          const alpha = 0.92 * fadeOut;
          const spread = sheenHalfWidth * 0.75;

          const sg = ctx.createLinearGradient(
            sheenCenter - spread, 0,
            sheenCenter + spread, 0
          );
          sg.addColorStop(0, 'rgba(255, 252, 220, 0)');
          sg.addColorStop(0.5, `rgba(255, 252, 220, ${alpha})`);
          sg.addColorStop(1, 'rgba(255, 252, 220, 0)');

          ctx.save();
          // Clip to the filled region
          ctx.beginPath();
          ctx.roundRect(0, 0, filledWidth, h, radius);
          ctx.clip();
          
          ctx.fillStyle = sg;
          ctx.fillRect(sheenStart, 0, sheenEnd - sheenStart, h);
          ctx.restore();
        }
      }

      rafId = requestAnimationFrame(draw);
    }

    rafId = requestAnimationFrame(draw);
  });

  onDestroy(() => {
    if (typeof window !== 'undefined') {
      cancelAnimationFrame(rafId);
    }
  });
</script>

<div class="streak-bar-container" bind:this={container}>
  <canvas bind:this={canvas}></canvas>
</div>

<style>
  .streak-bar-container {
    position: relative;
    width: 100%;
    height: 8px;
    border-radius: 9999px;
    overflow: hidden;
  }

  canvas {
    display: block;
    width: 100%;
    height: 100%;
  }
</style>
