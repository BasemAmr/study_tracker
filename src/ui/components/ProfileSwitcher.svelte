<script lang="ts">
  import { onMount } from 'svelte';
  import { User, Plus, Check } from 'lucide-svelte';
  import { activeProfileId, profiles, profileStore } from '@/core/stores/profileStore';
  import { toasts } from '@/core/stores/toastStore';

  let showDropdown = false;

  async function handleSwitch(id: number) {
    await profileStore.switchProfile(id);
    showDropdown = false;
    toasts.success('Switched profile');
  }

  async function handleCreate() {
    const name = prompt('Enter profile name:');
    if (name) {
      try {
        await profileStore.createNewProfile(name);
        toasts.success('Profile created');
        showDropdown = false;
      } catch (err: any) {
        toasts.error(err.message);
      }
    }
  }

  onMount(async () => {
    await profiles.refresh();
  });
</script>

<div class="relative">
  <button
    class="flex items-center gap-2 px-3 py-1.5 rounded-lg hover:bg-black/5 transition-colors text-sm font-medium"
    onclick={() => showDropdown = !showDropdown}
  >
    <User size={16} />
    <span>{$profiles.find(p => p.id === $activeProfileId)?.name || 'Loading...'}</span>
  </button>

  {#if showDropdown}
    <div class="absolute right-0 top-full mt-2 w-48 bg-white rounded-xl shadow-xl border border-black/5 py-2 z-50 animate-in fade-in slide-in-from-top-1">
      <div class="px-3 py-1 text-xs font-semibold text-gray-400 uppercase tracking-wider">
        Switch Profile
      </div>
      
      <div class="max-h-60 overflow-y-auto mt-1">
        {#each $profiles as profile}
          <button
            class="w-full flex items-center justify-between px-3 py-2 text-sm hover:bg-black/5 transition-colors"
            onclick={() => handleSwitch(profile.id!)}
          >
            <span class={profile.id === $activeProfileId ? 'font-semibold' : ''}>
              {profile.name}
            </span>
            {#if profile.id === $activeProfileId}
              <Check size={14} class="text-green-500" />
            {/if}
          </button>
        {/each}
      </div>

      <div class="border-t border-black/5 mt-2 pt-2">
        <button
          class="w-full flex items-center gap-2 px-3 py-2 text-sm text-blue-600 hover:bg-black/5 transition-colors"
          onclick={handleCreate}
        >
          <Plus size={14} />
          <span>New Profile</span>
        </button>
      </div>
    </div>
  {/if}
</div>

<style>
  /* Ensure it doesn't get cut off in layout containers */
</style>
