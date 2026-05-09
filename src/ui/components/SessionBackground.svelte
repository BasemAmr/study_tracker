<script lang="ts">
  let {
    imageUrl = '/backgrounds/city-twilight.png',
    overlayOpacity = 0.4
  }: {
    imageUrl?: string;
    overlayOpacity?: number;
  } = $props();
</script>

<!--
  Uses position:absolute — must live inside a parent that has
  position:relative + overflow:hidden + explicit height.
  The fullscreen overlay in SessionTimer/Stopwatch wraps this
  in a position:fixed div itself, so it fills the screen there.
-->
<img
  src={imageUrl}
  alt=""
  class="absolute inset-0 h-full w-full object-cover"
  loading="eager"
/>
<div
  class="absolute inset-0 bg-black"
  style="opacity: {overlayOpacity}"
></div>
