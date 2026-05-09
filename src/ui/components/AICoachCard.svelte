<script lang="ts">
  import { Sparkles, X, ChevronDown, ChevronUp } from 'lucide-svelte';
  import Card from '@/ui/components/Card.svelte';
  import Button from '@/ui/components/Button.svelte';
  import { activeProfileId } from '@/core/stores/profileStore';
  import { navigate } from '@/core/stores/router';
  import {
    getAiFeaturesOrDefault,
    getForProfile
  } from '@/core/data/repositories/aiFeatureSettingsRepository';
  import { getSettingByKey } from '@/core/data/repositories/appSettingsRepository';
  import { ensureTodaysMessage } from '@/core/services/aiCoachService';
  import type { CoachCachePayload } from '@/core/services/aiCoachService';
  import { localCalendarDateKey } from '@/core/utils/aiDateKeys';

  let loading = $state(false);
  let payload = $state<CoachCachePayload | null>(null);
  /** When coach is enabled and key absent — BEHAVIOR encourages connect, never hard-fails loudly. */
  let connectPrompt = $state(false);
  let dismissed = $state(false);
  /** Feature-flag off ⇒ render nothing — spec. */
  let featureOn = $state(false);
  let expanded = $state(false);

  function dismissKey(pid: number) {
    return `coach-dismiss-${pid}-${localCalendarDateKey(new Date())}`;
  }

  async function refresh() {
    const pid = Number($activeProfileId);
    if (!pid) return;
    dismissed = typeof sessionStorage !== 'undefined' && sessionStorage.getItem(dismissKey(pid)) === '1';
    loading = true;

    try {
      const featsRow = await getForProfile(pid);
      const feats = getAiFeaturesOrDefault(pid, featsRow);
      featureOn = feats.coachEnabled;
      connectPrompt = false;
      payload = null;

      if (!feats.coachEnabled) {
        loading = false;
        return;
      }

      const keyRow = await getSettingByKey('groqApiKey');
      const hasKey = (keyRow?.value ?? '').trim().length > 0;
      if (!hasKey) {
        connectPrompt = true;
        loading = false;
        return;
      }

      payload = await ensureTodaysMessage(pid);
      if (!payload?.message?.trim()) {
        payload = null;
      }
    } finally {
      loading = false;
    }
  }

  function dismissCard() {
    const pid = Number($activeProfileId);
    dismissed = true;
    try {
      sessionStorage.setItem(dismissKey(pid), '1');
    } catch {
      /* private mode etc. — ignore */
    }
  }

  $effect(() => {
    void $activeProfileId;
    void refresh();
  });
</script>

{#if featureOn}
  {#if loading}
    <Card>
      <div class="flex items-center gap-2 text-sm text-ink-500">
        <div class="h-5 w-5 animate-spin rounded-full border-2 border-moss-200 border-t-moss-700"></div>
        Preparing today's coaching note…
      </div>
    </Card>
  {:else if connectPrompt}
    <Card>
      <div class="flex gap-4">
        <div class="rounded-2xl bg-moss-600/90 p-3 text-white shrink-0">
          <Sparkles size={22} />
        </div>
        <div class="flex-1">
          <h3 class="text-base font-semibold text-ink-900 mb-2">Daily coach ready</h3>
          <p class="text-sm text-ink-600 leading-relaxed mb-4">
            Connect AI for personalized coaching — add your Groq API key in Settings. Your summaries stay cached per day once generated.
          </p>
          <Button variant="secondary" onclick={() => navigate('settings')}>
            Open Settings
          </Button>
        </div>
      </div>
    </Card>
  {:else if payload && !dismissed}
    <Card>
      <div class="flex items-start gap-3">
        <div class="flex gap-4 flex-1 min-w-0">
          <div class="rounded-2xl bg-moss-100 p-3 text-moss-700 shrink-0 self-start">
            <Sparkles size={22} />
          </div>
          <div class="flex-1 min-w-0">
            <button
              class="flex items-center justify-between w-full text-left"
              onclick={() => expanded = !expanded}
            >
              <h3 class="text-base font-semibold text-ink-900 truncate">Today's coach note</h3>
              <div class="text-moss-600 px-2 shrink-0">
                {#if expanded}
                  <ChevronUp size={18} />
                {:else}
                  <ChevronDown size={18} />
                {/if}
              </div>
            </button>
            {#if expanded}
              <p class="mt-2 text-sm text-ink-700 leading-relaxed whitespace-pre-wrap">{payload.message}</p>
            {:else}
              <p class="mt-1 text-sm text-ink-700 truncate">{payload.message.split('\n')[0]}</p>
            {/if}
          </div>
        </div>
        <button
          type="button"
          class="text-ink-300 hover:text-ink-700 self-start shrink-0 p-1"
          onclick={dismissCard}
          aria-label="Dismiss coach card"
        >
          <X size={18} />
        </button>
      </div>
    </Card>
  {/if}
{/if}
