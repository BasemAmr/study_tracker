/**
 * Svelte action: teleports an element to document.body.
 * Fixes position:fixed being clipped by ancestor backdrop-filter/transform.
 */
export function portal(node: HTMLElement) {
  // Move the node to the body so it escapes any stacking context
  document.body.appendChild(node);

  return {
    destroy() {
      if (document.body.contains(node)) {
        document.body.removeChild(node);
      }
    }
  };
}
