<script lang="ts">
  import { onMount, onDestroy } from 'svelte';

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

  let canvas: HTMLCanvasElement;
  let rafId: number;

  const cx = size / 2;
  const cy = size / 2;
  const r = (size - strokeWidth) / 2;
  const startAngle = -Math.PI / 2;

  function easeInOut(t: number): number {
    return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
  }

  onMount(() => {
    const ctx = canvas.getContext('2d')!;
    const percentage = max > 0 ? Math.min(value / max, 1) : 0;
    const arcSpan = Math.PI * 2 * percentage;
    const endAngle = startAngle + arcSpan;

    let progress = 0;
    let lastTime: number | null = null;
    const duration = 5500;

    function draw(ts: number) {
      if (!lastTime) lastTime = ts;
      const dt = ts - lastTime;
      lastTime = ts;
      progress = (progress + dt / duration) % 1;

      ctx.clearRect(0, 0, size, size);

      // track
      ctx.beginPath();
      ctx.arc(cx, cy, r, startAngle, startAngle + Math.PI * 2);
      ctx.strokeStyle = 'rgba(245,158,11,0.1)';
      ctx.lineWidth = strokeWidth;
      ctx.lineCap = 'round';
      ctx.stroke();

      // base filled arc
      if (percentage > 0) {
        // Fix for 100% fill where start/end points coincide
        const gradEndAngle = percentage === 1 ? startAngle + Math.PI : endAngle;
        const grad = ctx.createLinearGradient(
          cx + r * Math.cos(startAngle),
          cy + r * Math.sin(startAngle),
          cx + r * Math.cos(gradEndAngle),
          cy + r * Math.sin(gradEndAngle)
        );
        grad.addColorStop(0, '#F59E0B');
        grad.addColorStop(1, '#EF4444');

        ctx.beginPath();
        ctx.arc(cx, cy, r, startAngle, endAngle);
        ctx.strokeStyle = grad;
        ctx.lineWidth = strokeWidth;
        ctx.lineCap = 'round';
        ctx.shadowColor = 'rgba(239,68,68,0.35)';
        ctx.shadowBlur = 6;
        ctx.stroke();
        ctx.shadowBlur = 0;

        // specular highlight sweep
        const eased = easeInOut(progress);
        const sheenCenter = startAngle + arcSpan * eased;
        const sheenWidth = arcSpan * 0.135;
        const sheenStart = Math.max(sheenCenter - sheenWidth / 2, startAngle) -1 ;
        const sheenEnd = Math.min(sheenCenter + sheenWidth / 2, endAngle) + 1;

        if (sheenEnd > sheenStart) {
          const isFull = percentage >= 1;
          const fadeOut = isFull ? 1 : Math.min((1 - eased) / 0.04, 1);
          const tx = cx + r * Math.cos(sheenCenter);
          const ty = cy + r * Math.sin(sheenCenter);
          const tangentX = -Math.sin(sheenCenter);
          const tangentY = Math.cos(sheenCenter);
          const spread = r * sheenWidth * 0.75;

          const sg = ctx.createLinearGradient(
            tx - tangentX * spread, ty - tangentY * spread,
            tx + tangentX * spread, ty + tangentY * spread
          );
          const alpha = 0.92 * fadeOut;
          sg.addColorStop(0, `rgba(255,252,220,0)`);
          sg.addColorStop(0.5, `rgba(255,252,220,${alpha})`);
          sg.addColorStop(1, `rgba(255,252,220,0)`);

          ctx.beginPath();
          ctx.arc(cx, cy, r, sheenStart, sheenEnd);
          ctx.strokeStyle = sg;
          ctx.lineWidth = strokeWidth;
          ctx.lineCap = 'round';
          ctx.stroke();
        }
      }

      rafId = requestAnimationFrame(draw);
    }

    rafId = requestAnimationFrame(draw);
  });

  onDestroy(() => {
    cancelAnimationFrame(rafId);
  });
</script>

<div class="ring-wrap">
  <canvas bind:this={canvas} width={size} height={size} />
  {#if label}
    <span class="label">{label}</span>
  {/if}
</div>

<style>
  .ring-wrap {
    display: inline-flex;
    flex-direction: column;
    align-items: center;
    gap: 6px;
  }

  canvas {
    display: block;
  }

  .label {
    font-size: 11px;
    font-weight: 600;
    color: #D97706;
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }
</style>