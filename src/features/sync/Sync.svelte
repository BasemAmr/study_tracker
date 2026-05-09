<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { ask } from '@tauri-apps/plugin-dialog';
  import { toasts } from '@/core/stores/toastStore';
  import Card from '@/ui/components/Card.svelte';
  import Button from '@/ui/components/Button.svelte';
  import Input from '@/ui/components/Input.svelte';
  import Select from '@/ui/components/Select.svelte';
  import {
    Wifi, WifiOff, FileDown, FileUp, Cloud, CloudOff, RefreshCw,
    Radio, CheckCircle2, XCircle, Clock, ArrowUpDown, Settings2,
    Bluetooth, Usb, Loader2, Shield, ChevronDown, ChevronRight, Trash2
  } from 'lucide-svelte';
  import { getSettingByKey, setSettingByKey } from '@/core/data/repositories/appSettingsRepository';
  import { getSyncHistory, getUnsyncedCount } from '@/core/sync/syncEngine';
  import { getDeviceId, getDeviceName, setDeviceName } from '@/core/sync/syncIdentity';
  import { exportSyncFile, importSyncFile } from '@/core/sync/fileTransport';
  import {
    startWifiServer, stopWifiServer, discoverPeers,
    syncWithPeer, regeneratePairingCode, resetPairingCode, resetSyncState,
    refreshServerPayload, addLanBookmarkPeer, removeLanBookmarkPeer,
    type WifiPeer
  } from '@/core/sync/wifiTransport';
  import { runCloudSync, checkOnline } from '@/core/sync/cloudTransport';
  import { formatSyncTime, formatRowCount } from '@/core/sync/syncUtils';
  import { syncStore, setUnsyncedCount, setSyncEnabled } from '@/core/stores/syncStore';

  import { activeProfileId } from '@/core/stores/profileStore';

  // ── Device identity ─────────────────────────────────────────────────────────
  let deviceId = $state('');
  let deviceName = $state('My Device');
  let editingName = $state(false);
  let tempName = $state('');

  // ── WiFi section ────────────────────────────────────────────────────────────
  let wifiEnabled = $state(true);
  let wifiPort = $state(47821);
  /** Our own LAN IPv4 — shown at the top of the Sync tab so the user can type
   * it verbatim on the other device when mDNS discovery fails. Loaded once on mount. */
  let localIp = $state<string | null>(null);
  let discoveringPeers = $state(false);
  let syncingPeer = $state<string | null>(null);
  let pairingCodeForPeer = $state('');
  let selectedPeer = $state<WifiPeer | null>(null);
  let showPairingInput = $state(false);
  /** When mDNS finds nothing (common on Windows ↔ Android), probe /sync/status directly. */
  let lanPeerHost = $state('');
  let lanPeerPortInput = $state('47821');
  let lanBookmarkSaving = $state(false);

  // ── File section ────────────────────────────────────────────────────────────
  let passphrase = $state('');
  let fileExporting = $state(false);
  let fileImporting = $state(false);
  let lastFileExport = $state<string | null>(null);
  let lastFileImport = $state<string | null>(null);

  // ── Cloud section ───────────────────────────────────────────────────────────
  let cloudEnabled = $state(false);
  let cloudProvider = $state('supabase');
  let cloudUrl = $state('');
  let cloudAnonKey = $state('');
  let cloudSyncing = $state(false);
  let cloudOnline = $state(false);
  let lastCloudSync = $state<string | null>(null);

  // ── Sync history ────────────────────────────────────────────────────────────
  let historyExpanded = $state(false);

  // ── Polling ─────────────────────────────────────────────────────────────────
  let peerPollInterval: ReturnType<typeof setInterval> | null = null;

  import { untrack } from 'svelte';

  $effect(() => {
    if ($activeProfileId) {
      untrack(() => loadSyncData());
    }
  });

  async function loadSyncData() {
    // Load identity
    deviceId = await getDeviceId();
    deviceName = await getDeviceName();

    // Load settings
    const [wifiEn, port, pairingCode, pass, cloudEn, provider, url, anonKey] = await Promise.all([
      getSettingByKey('wifiSyncEnabled'),
      getSettingByKey('wifiSyncPort'),
      getSettingByKey('wifiSyncPairingCode'),
      getSettingByKey('syncPassphrase'),
      getSettingByKey('cloudSyncEnabled'),
      getSettingByKey('cloudSyncProvider'),
      getSettingByKey('cloudSyncUrl'),
      getSettingByKey('cloudSyncAnonKey'),
    ]);

    // Opt-in flag: absent OR 'false' → off, explicit 'true' → on. Mirror into the
    // global store so the persistent indicator can react without re-reading settings.
    wifiEnabled = wifiEn?.value === 'true';
    setSyncEnabled(wifiEnabled);
    wifiPort = Number(port?.value ?? 47821);
    let initialPairingCode = pairingCode?.value ?? '';

    passphrase = pass?.value ?? '';
    cloudEnabled = cloudEn?.value === 'true';
    cloudProvider = provider?.value ?? 'supabase';
    cloudUrl = url?.value ?? '';
    cloudAnonKey = anonKey?.value ?? '';

    // WiFi server is no longer auto-started on boot/load to ensure sync remains manual.
    // if (wifiEnabled) await handleStartWifiServer();

    // Check online status
    cloudOnline = await checkOnline();

    // Load history and unsynced count
    await refreshHistory();
    await refreshUnsyncedCount();

    // Initial server payload pre-load
    if (wifiEnabled) {
      setTimeout(() => refreshServerPayload(), 2000);
    }
  }

  onMount(async () => {
    // Fetch our own LAN IPv4 once so users can read/write it onto the other device
    // manually when mDNS fails (guest Wi-Fi, Windows↔Android, etc).
    try {
      const { invoke } = await import('@tauri-apps/api/core');
      localIp = await invoke<string | null>('sync_wifi_get_local_ip');
    } catch (err) {
      console.warn('[Sync] sync_wifi_get_local_ip failed:', err);
      localIp = null;
    }

    // Poll for peers every 15s while screen is open
    peerPollInterval = setInterval(async () => {
      if ($syncStore.serverRunning && !discoveringPeers) {
        await discoverPeers();
      }
      await refreshUnsyncedCount();
    }, 15000);
  });

  onDestroy(() => {
    if (peerPollInterval) clearInterval(peerPollInterval);
  });

  async function refreshHistory() {
    const history = await getSyncHistory(20);
    // history is already updated via store in wifiTransport, but we can do an initial fetch
    // actually, let's keep it in store
    $syncStore.history = history;
  }

  async function refreshUnsyncedCount() {
    const count = await getUnsyncedCount();
    setUnsyncedCount(count);
  }


  // ── Device name ──────────────────────────────────────────────────────────────
  async function saveDeviceName() {
    await setDeviceName(tempName);
    deviceName = tempName;
    editingName = false;
    toasts.success('Device name updated.');
  }

  // ── WiFi ────────────────────────────────────────────────────────────────────
  async function handleStartWifiServer() {
    try {
      const { port, pairingCode } = await startWifiServer();
      wifiPort = port;
      // Persist the user's intent so the indicator stays visible across restarts and
      // background auto-sync remains enabled even before the server is back up.
      await setSettingByKey('wifiSyncEnabled', 'true');
      wifiEnabled = true;
      setSyncEnabled(true);
      await discoverPeers();
    } catch (err: any) {

      toasts.error('Failed to start WiFi server: ' + (err?.message ?? err));
    }
  }

  async function handleStopWifiServer() {
    try {
      await stopWifiServer();
      await setSettingByKey('wifiSyncEnabled', 'false');
      wifiEnabled = false;
      setSyncEnabled(false);
    } catch (err: any) {

      toasts.error('Failed to stop WiFi server: ' + (err?.message ?? err));
    }
  }

  async function handleDiscoverPeers() {
    discoveringPeers = true;
    try {
      await discoverPeers();
    } finally {

      discoveringPeers = false;
    }
  }

  async function handleAddLanBookmark() {
    const port = Number.parseInt(lanPeerPortInput.trim(), 10);
    if (!lanPeerHost.trim() || !Number.isFinite(port) || port < 1 || port > 65535) {
      toasts.error('Enter a host/IP and valid port.');
      return;
    }
    lanBookmarkSaving = true;
    try {
      const result = await addLanBookmarkPeer(lanPeerHost, port);
      if (!result.ok) {
        toasts.error(result.detail);
        return;
      }
      await discoverPeers();
      lanPeerHost = '';
      const b = result.bookmark;
      toasts.success(`${b.deviceName} added (${b.host}:${b.port}).`);
    } finally {
      lanBookmarkSaving = false;
    }
  }

  async function handleForgetLanBookmark(peer: WifiPeer) {
    await removeLanBookmarkPeer(peer.deviceId);
    await discoverPeers();
    toasts.info('Forgot LAN shortcut for this device.');
  }

  async function handleRegeneratePairingCode() {
    await regeneratePairingCode();
    toasts.success('New pairing code generated.');
  }

  async function handleResetPairingCode() {
    const confirmed = await ask('Reset pairing code? Connected devices will need the new code once.', {
      title: 'Reset Pairing Code',
      kind: 'warning'
    });
    if (!confirmed) return;
    await resetPairingCode();
    toasts.success('Pairing code reset. Share the new code to pair again.');
  }


  async function handleResetSyncState(peer: WifiPeer) {
    // BEHAVIOR-B2 "Force full sync": nulling lastSyncedAt makes buildPayload() send ALL rows,
    // then kicking off a sync immediately so the user sees the full-sync progress instead of
    // having to tap Sync manually.
    const confirmed = await ask(`Force a full sync with ${peer.deviceName}? All rows will be re-sent.`, {
      title: 'Force full sync',
      kind: 'warning'
    });
    if (!confirmed) return;

    await resetSyncState(peer);
    toasts.info(`Full sync starting with ${peer.deviceName}…`);
    await handleDiscoverPeers();
    await handleSyncWithPeer(peer);
  }

  async function handleSyncWithPeer(peer: WifiPeer, code?: string) {
    syncingPeer = peer.deviceId;
    try {
      const result = await syncWithPeer(peer, code);
      if (result.success) {
        toasts.success(`Synced with ${peer.deviceName}: ${formatRowCount((result.rowsReceived ?? 0) + (result.rowsSent ?? 0))} exchanged.`);
        showPairingInput = false;
        selectedPeer = null;
      } else {
        toasts.error(result.errorMessage ?? 'Sync failed');
      }
    } finally {
      syncingPeer = null;
      await refreshHistory();
      await refreshUnsyncedCount();
    }

  }

  // ── File ─────────────────────────────────────────────────────────────────────
  async function savePassphrase() {
    await setSettingByKey('syncPassphrase', passphrase);
    toasts.success('Passphrase saved.');
  }

  async function handleExportFile() {
    fileExporting = true;
    try {
      const result = await exportSyncFile();
      if (result.success) {
        lastFileExport = new Date().toISOString();
        toasts.success(`Exported ${formatRowCount(result.rowsExported ?? 0)}.`);
        await refreshHistory();
      } else {
        toasts.error(result.errorMessage ?? 'Export failed');
      }
    } finally {
      fileExporting = false;
    }
  }

  async function handleImportFile() {
    fileImporting = true;
    try {
      const result = await importSyncFile();
      if (result.success) {
        lastFileImport = new Date().toISOString();
        toasts.success(`Imported ${formatRowCount(result.rowsImported ?? 0)}.`);
        await refreshHistory();
        window.dispatchEvent(new CustomEvent('sync-data-changed'));
      } else {
        toasts.error(result.errorMessage ?? 'Import failed');
      }
    } finally {
      fileImporting = false;
    }
  }

  // ── Cloud ─────────────────────────────────────────────────────────────────────
  async function saveCloudSettings() {
    await Promise.all([
      setSettingByKey('cloudSyncEnabled', String(cloudEnabled)),
      setSettingByKey('cloudSyncProvider', cloudProvider),
      setSettingByKey('cloudSyncUrl', cloudUrl),
      setSettingByKey('cloudSyncAnonKey', cloudAnonKey),
    ]);
    toasts.success('Cloud settings saved.');
  }

  async function handleCloudSync() {
    cloudSyncing = true;
    try {
      const result = await runCloudSync();
      if (result.success) {
        lastCloudSync = new Date().toISOString();
        toasts.success(`Cloud sync: ${formatRowCount((result.rowsSent ?? 0) + (result.rowsReceived ?? 0))} exchanged.`);
        await refreshHistory();
      } else {
        toasts.error(result.errorMessage ?? 'Cloud sync failed');
      }
    } finally {
      cloudSyncing = false;
    }
  }

  // ── Transport icon helpers ───────────────────────────────────────────────────
  function transportIcon(transport: string) {
    if (transport === 'wifi') return '📶';
    if (transport === 'file') return '📁';
    if (transport === 'cloud') return '☁️';
    if (transport === 'bluetooth') return '🔵';
    return '🔄';
  }
</script>

<div class="space-y-6">
  <!-- Header -->
  <header>
    <p class="text-sm font-medium text-moss-600">Settings</p>
    <h2 class="mt-1 flex items-center gap-2 text-3xl font-semibold tracking-tight text-ink-900">
      <ArrowUpDown size={28} /> Device Sync
    </h2>
    <p class="mt-1 text-sm text-ink-500">
      Transfer your study data between devices — no cloud account required.
      Uses WiFi first, then file export as fallback.
    </p>
  </header>

  <!-- Device Identity -->
  <Card>
    <div class="flex items-start justify-between gap-4">
      <div class="flex-1">
        <h3 class="flex items-center gap-2 text-base font-semibold text-ink-900 mb-1">
          <Settings2 size={16} /> This Device
        </h3>
        <p class="text-xs text-ink-400 font-mono mb-2">ID: {deviceId.slice(0, 16)}…</p>

        <!-- Own LAN IPv4 : port — shown prominently so the user can type it onto the
             other device when mDNS discovery fails. Copy-to-clipboard on click. -->
        <div class="mb-3 flex flex-wrap items-center gap-2">
          <span class="text-[10px] uppercase tracking-[0.2em] text-ink-400">On this LAN</span>
          {#if localIp}
            <button
              class="group inline-flex items-center gap-1.5 rounded-lg border border-ink-100 bg-[#fafaf8] px-2.5 py-1 font-mono text-xs text-ink-700 hover:border-moss-200 hover:bg-moss-50"
              onclick={() => {
                navigator.clipboard.writeText(`${localIp}:${wifiPort}`);
                toasts.success(`Copied ${localIp}:${wifiPort}`);
              }}
              title="Click to copy — type this on the other device"
            >
              <Wifi size={11} class="text-moss-500" />
              {localIp}:{wifiPort}
            </button>
          {:else}
            <span class="text-xs text-ink-300 italic">offline</span>
          {/if}
        </div>

        {#if editingName}
          <div class="flex gap-2 items-center max-w-xs">
            <Input bind:value={tempName} placeholder="Device name" />
            <Button onclick={saveDeviceName}>Save</Button>
            <Button variant="secondary" onclick={() => (editingName = false)}>Cancel</Button>
          </div>
        {:else}
          <div class="flex items-center gap-3">
            <span class="text-base font-medium text-ink-800">{deviceName}</span>
            <button
              onclick={() => { tempName = deviceName; editingName = true; }}
              class="text-xs text-moss-600 hover:underline"
            >Edit</button>
          </div>
        {/if}
      </div>

      <div class="flex items-center gap-2 text-xs px-3 py-1.5 rounded-full bg-moss-50 text-moss-700 font-medium border border-moss-200">
        <Shield size={12} /> Local Only
      </div>
    </div>
  </Card>

  <!-- Transport 1: Local WiFi (priority) -->
  <Card>
    <div class="flex items-center justify-between mb-4">
      <h3 class="flex items-center gap-2 text-base font-semibold text-ink-900">
        <Wifi size={16} />
        Local WiFi
        <span class="ml-1 text-[10px] font-semibold uppercase tracking-wide px-2 py-0.5 rounded-full bg-moss-100 text-moss-700">Priority 1</span>
        {#if $syncStore.unsyncedCount > 0}
          <div class="ml-2 inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-amber-100 border border-amber-200">
            <CheckCircle2 size={10} class="text-amber-600" />
            <span class="text-[10px] font-bold text-amber-600">{$syncStore.unsyncedCount} unsynced</span>
          </div>
        {/if}
      </h3>
      <div class="flex items-center gap-2">
        {#if $syncStore.serverRunning}
          <span class="flex items-center gap-1.5 text-xs text-emerald-600 font-medium">
            <span class="h-2 w-2 rounded-full bg-emerald-400 animate-pulse"></span> Hosting on :{wifiPort}
          </span>
        {:else}

          <span class="flex items-center gap-1.5 text-xs text-ink-400">
            <WifiOff size={12} /> Server stopped
          </span>
        {/if}
      </div>
    </div>

    <p class="text-sm text-ink-500 mb-4">
      Both sides need hosting on the same LAN. On <span class="font-medium text-ink-600">Windows</span>, multicast scan often finds <span class="font-medium text-ink-600">zero</span> peers even when the phone is reachable — that is normal. Use <span class="font-medium text-ink-600">Add peer by LAN address</span> below with the other device’s Wi‑Fi IPv4 (e.g. the phone at 192.168.1.x). Guest Wi‑Fi and some routers block LAN traffic; disable VPN on both.
    </p>

    <!-- Pairing code display -->
    {#if $syncStore.serverRunning && $syncStore.pairingCode}
      <div class="mb-4 flex items-center gap-4 rounded-2xl border border-moss-200 bg-moss-50 p-4">
        <div>
          <p class="text-xs text-ink-500 mb-1">Pairing code (share with other device)</p>
          <p class="text-3xl font-bold tracking-[0.3em] text-moss-700 font-mono">{$syncStore.pairingCode}</p>
        </div>

        <button
          onclick={handleRegeneratePairingCode}
          class="ml-auto text-xs text-ink-400 hover:text-ink-700 flex items-center gap-1"
        >
          <RefreshCw size={12} /> New code
        </button>

        <button
          onclick={handleResetPairingCode}
          class="text-xs text-red-500 hover:text-red-700 flex items-center gap-1"
        >
          <Trash2 size={12} /> Reset code
        </button>
      </div>
    {/if}

    <!-- Server controls -->
    <div class="flex gap-3 flex-wrap mb-5">
      {#if !$syncStore.serverRunning}
        <Button onclick={handleStartWifiServer}>
          <Wifi size={14} /> Start hosting
        </Button>
      {:else}
        <Button variant="secondary" onclick={handleStopWifiServer}>
          <WifiOff size={14} /> Stop server
        </Button>

        <Button variant="secondary" onclick={handleDiscoverPeers} disabled={discoveringPeers}>
          {#if discoveringPeers}
            <Loader2 size={14} class="animate-spin" /> Scanning…
          {:else}
            <Radio size={14} /> Scan for peers
          {/if}
        </Button>
      {/if}
    </div>

    <!-- Manual LAN bookmarks (bypass mDNS when Scan finds 0, e.g. Windows → Android).
         Compact layout: saved entries show as inline chips with × removal; the
         add form is a single row below so the whole block stays under ~120px tall. -->
    {#if $syncStore.serverRunning}
      {@const bookmarks = $syncStore.peers.filter((p) => p.fromLanBookmark)}
      <div class="mb-5 rounded-2xl border border-ink-100 bg-[#fafaf8] p-3">
        <div class="flex items-center justify-between mb-2">
          <p class="text-xs font-medium text-ink-600">Saved peers</p>
          <p class="text-[11px] text-ink-400">
            {bookmarks.length === 0 ? 'none yet' : `${bookmarks.length} saved`}
          </p>
        </div>

        {#if bookmarks.length > 0}
          <div class="flex flex-wrap gap-1.5 mb-2">
            {#each bookmarks as bm (bm.deviceId)}
              <div class="inline-flex items-center gap-1.5 rounded-full border border-ink-200 bg-white px-2 py-0.5 text-xs">
                <span class="font-medium text-ink-700">{bm.deviceName}</span>
                <span class="font-mono text-[10px] text-ink-400">{bm.host}:{bm.port}</span>
                <button
                  class="text-ink-300 hover:text-red-500"
                  onclick={() => handleForgetLanBookmark(bm)}
                  title="Remove this saved peer"
                  aria-label="Remove saved peer"
                >
                  <Trash2 size={11} />
                </button>
              </div>
            {/each}
          </div>
        {/if}

        <div class="flex flex-wrap gap-2 items-center">
          <div class="flex-1 min-w-[140px]">
            <Input placeholder="192.168.1.4" bind:value={lanPeerHost} disabled={lanBookmarkSaving} />
          </div>
          <div class="w-20">
            <Input placeholder="47821" bind:value={lanPeerPortInput} disabled={lanBookmarkSaving} />
          </div>
          <Button onclick={handleAddLanBookmark} disabled={lanBookmarkSaving}>
            {#if lanBookmarkSaving}
              <Loader2 size={13} class="animate-spin" />
            {:else}
              Add
            {/if}
          </Button>
        </div>
      </div>
    {/if}

    <!-- Peers -->
    {#if $syncStore.serverRunning}
      {#if $syncStore.peers.length === 0}
        <div class="rounded-xl border border-dashed border-ink-200 p-6 text-center">
          <Radio size={20} class="mx-auto mb-2 text-ink-300" />
          <p class="text-sm text-ink-400">No devices found nearby.</p>
          <p class="text-xs text-ink-300 mt-1 max-w-md mx-auto">
            If you are on desktop, do not rely on Scan alone — add the phone’s LAN IPv4 above. Peers saved earlier reappear here after hosting starts.
          </p>
        </div>
      {:else}
        <div class="space-y-2">
          {#each $syncStore.peers as peer}
            {@const status = $syncStore.peerStatus[peer.deviceId]}
            {@const isSyncing = status?.kind === 'syncing' || syncingPeer === peer.deviceId}
            {@const statusColor = isSyncing ? 'bg-amber-500' : (status?.kind === 'synced' ? 'bg-emerald-500' : (status?.kind === 'failed' ? 'bg-red-500' : 'bg-ink-300'))}
            {@const statusText = isSyncing ? 'Syncing...' : (status?.kind === 'synced' ? `Synced just now · ↑${status.rowsSent} ↓${status.rowsReceived}` : (status?.kind === 'failed' ? `Failed: ${status.lastError}` : (peer.lastSyncedAt ? `Last sync: ${formatSyncTime(peer.lastSyncedAt)}` : 'Available')))}
            <div class="flex items-center justify-between rounded-xl border {isSyncing ? 'border-amber-300 bg-amber-50/30' : 'border-ink-100 bg-[#fcfcf9]'} p-4">
              <div class="flex items-center gap-3">
                <div class="h-2.5 w-2.5 rounded-full {statusColor}"></div>
                <div>
                  <p class="text-sm font-medium text-ink-900">{peer.deviceName}</p>
                  <p class="text-xs font-mono text-ink-300">{peer.host}:{peer.port}</p>
                  <p class="text-xs text-ink-400">{statusText}</p>
                </div>
              </div>
              <div class="flex gap-2">

                {#if selectedPeer?.deviceId === peer.deviceId && showPairingInput}
                  <div class="flex gap-2 items-center">
                    <input
                      type="text"
                      bind:value={pairingCodeForPeer}
                      placeholder="6-digit code"
                      maxlength="6"
                      class="w-28 rounded-xl border border-ink-200 px-3 py-1.5 text-sm font-mono text-center focus:outline-none focus:border-moss-400"
                    />
                    <Button
                      onclick={() => handleSyncWithPeer(peer, pairingCodeForPeer)}
                      disabled={syncingPeer === peer.deviceId}
                    >
                      {#if syncingPeer === peer.deviceId}
                        <Loader2 size={13} class="animate-spin" />
                      {:else}
                        Pair & Sync
                      {/if}
                    </Button>
                    <Button variant="secondary" onclick={() => { showPairingInput = false; selectedPeer = null; }}>
                      Cancel
                    </Button>
                  </div>
                {:else}
                    <Button
                      variant="secondary"
                      title="Reset sync memory"
                      onclick={() => handleResetSyncState(peer)}
                      disabled={isSyncing}
                    >
                      <Trash2 size={14} class="text-red-500" />
                    </Button>
                    {#if peer.fromLanBookmark}
                      <Button
                        variant="secondary"
                        title="Remove saved LAN shortcut"
                        onclick={() => handleForgetLanBookmark(peer)}
                        disabled={isSyncing}
                      >
                        Forget IP
                      </Button>
                    {/if}
                    <Button
                      variant="secondary"
                      onclick={() => {
                      if (peer.lastSyncedAt) {
                        handleSyncWithPeer(peer);
                      } else {
                        selectedPeer = peer;
                        showPairingInput = true;
                        pairingCodeForPeer = '';
                      }
                    }}
                    disabled={isSyncing}
                  >
                    {#if isSyncing}
                      <Loader2 size={13} class="animate-spin" /> Syncing…
                    {:else}
                      <ArrowUpDown size={13} />
                      {peer.lastSyncedAt ? 'Sync' : 'Pair'}
                    {/if}
                  </Button>
                  
                  {#if peer.lastSyncedAt}
                    <button
                      onclick={() => handleResetSyncState(peer)}
                      class="p-2 text-red-400 hover:text-red-600 hover:bg-red-50 rounded-xl transition-colors"
                      title="Reset sync memory (Force full sync)"
                    >
                      <Trash2 size={14} />
                    </button>
                  {/if}
                {/if}
              </div>
            </div>
          {/each}
        </div>
      {/if}
    {/if}
    <!-- BEHAVIOR-B3: desktop has no fixed interval — it pushes on data change. -->
    <p class="mt-4 text-[11px] text-ink-300">
      Auto-sync: runs automatically when you change data on this device.
    </p>
  </Card>

  <!-- Transport 2: Bluetooth (honest unavailable notice) -->
  <Card>
    <div class="flex items-center justify-between mb-2">
      <h3 class="flex items-center gap-2 text-base font-semibold text-ink-400">
        <Bluetooth size={16} />
        Bluetooth
        <span class="ml-1 text-[10px] font-semibold uppercase tracking-wide px-2 py-0.5 rounded-full bg-ink-100 text-ink-400">Priority 2</span>
      </h3>
      <span class="text-xs text-ink-300 border border-ink-200 rounded-full px-2 py-0.5">Desktop limited</span>
    </div>
    <p class="text-sm text-ink-400">
      Bluetooth sync is available on the Android app. 
      Windows 10 does not reliably support acting as a Bluetooth peripheral without custom drivers.
      Use WiFi or File sync on desktop.
    </p>
  </Card>

  <!-- Transport 3: USB → merged with File -->
  <Card>
    <div class="flex items-center justify-between mb-2">
      <h3 class="flex items-center gap-2 text-base font-semibold text-ink-400">
        <Usb size={16} />
        USB
        <span class="ml-1 text-[10px] font-semibold uppercase tracking-wide px-2 py-0.5 rounded-full bg-ink-100 text-ink-400">Priority 3</span>
      </h3>
      <span class="text-xs text-ink-300 border border-ink-200 rounded-full px-2 py-0.5">Guided via File</span>
    </div>
    <p class="text-sm text-ink-400">
      USB sync works as guided file transfer: export a .studysync file on one device,
      connect via USB cable, copy the file, then import on the other device.
      Use the File section below for export and import.
    </p>
  </Card>

  <!-- Transport 4: File Export/Import -->
  <Card>
    <div class="flex items-center justify-between mb-4">
      <h3 class="flex items-center gap-2 text-base font-semibold text-ink-900">
        <FileDown size={16} />
        File Export / Import
        <span class="ml-1 text-[10px] font-semibold uppercase tracking-wide px-2 py-0.5 rounded-full bg-amber-100 text-amber-700">Priority 4</span>
      </h3>
      <div class="flex items-center gap-1.5 text-xs text-emerald-600 font-medium">
        <CheckCircle2 size={12} /> Always available
      </div>
    </div>

    <p class="text-sm text-ink-500 mb-4">
      Export your data as an encrypted <code class="text-xs bg-ink-100 px-1 rounded">.studysync</code> file.
      Send it via USB, email, messaging app, or cloud storage. Import on the other device to sync.
    </p>

    <!-- Passphrase -->
    <div class="mb-4 max-w-sm">
      <label for="sync-passphrase" class="block text-sm font-medium text-ink-700 mb-1.5">
        Encryption passphrase
      </label>
      <div class="flex gap-2">
        <input
          id="sync-passphrase"
          type="password"
          bind:value={passphrase}
          placeholder="Leave blank for no encryption"
          class="flex-1 rounded-xl border border-ink-100 bg-white px-4 py-2.5 text-sm focus:border-moss-500 focus:outline-none focus:ring-4 focus:ring-moss-500/10 placeholder:text-ink-300"
        />
        <Button variant="secondary" onclick={savePassphrase}>Save</Button>
      </div>
      <p class="mt-1 text-xs text-ink-400">Must match on both devices to decrypt the file.</p>
    </div>

    <!-- Export/Import buttons -->
    <div class="flex flex-wrap gap-3">
      <Button onclick={handleExportFile} disabled={fileExporting}>
        {#if fileExporting}
          <Loader2 size={14} class="animate-spin" /> Exporting…
        {:else}
          <FileDown size={14} /> Export sync file
        {/if}
      </Button>
      <Button variant="secondary" onclick={handleImportFile} disabled={fileImporting}>
        {#if fileImporting}
          <Loader2 size={14} class="animate-spin" /> Importing…
        {:else}
          <FileUp size={14} /> Import sync file
        {/if}
      </Button>
    </div>

    {#if lastFileExport || lastFileImport}
      <div class="mt-3 flex gap-6 text-xs text-ink-400">
        {#if lastFileExport}<span>Last export: {formatSyncTime(lastFileExport)}</span>{/if}
        {#if lastFileImport}<span>Last import: {formatSyncTime(lastFileImport)}</span>{/if}
      </div>
    {/if}
  </Card>

  <!-- Transport 5: Cloud (optional) -->
  <Card>
    <div class="flex items-center justify-between mb-4">
      <h3 class="flex items-center gap-2 text-base font-semibold text-ink-900">
        {#if cloudOnline}
          <Cloud size={16} />
        {:else}
          <CloudOff size={16} class="text-ink-400" />
        {/if}
        Cloud Sync
        <span class="ml-1 text-[10px] font-semibold uppercase tracking-wide px-2 py-0.5 rounded-full bg-blue-100 text-blue-600">Priority 5 · Optional</span>
      </h3>
      <label class="relative inline-flex items-center cursor-pointer">
        <input type="checkbox" bind:checked={cloudEnabled} class="sr-only peer">
        <div class="w-10 h-5 bg-ink-100 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-moss-500"></div>
        <span class="ml-2 text-sm text-ink-600">{cloudEnabled ? 'Enabled' : 'Disabled'}</span>
      </label>
    </div>

    <p class="text-sm text-ink-500 mb-4">
      Background sync over the internet. Disabled by default.
      Supports Supabase (free), or any custom endpoint that accepts the sync payload.
      <strong class="text-ink-700">No data leaves this device when disabled.</strong>
    </p>

    {#if cloudEnabled}
      <div class="space-y-3 max-w-md mb-4">
        <Select
          label="Cloud provider"
          bind:value={cloudProvider}
          options={[
            { value: 'supabase', label: 'Supabase (free tier)' },
            { value: 'custom', label: 'Custom endpoint' },
          ]}
        />
        <Input label="Endpoint URL" bind:value={cloudUrl} placeholder="https://your-project.supabase.co" />
        <Input label="API key / anon key" bind:value={cloudAnonKey} placeholder="eyJ..." />
      </div>

      <div class="flex gap-3 flex-wrap">
        <Button onclick={saveCloudSettings} variant="secondary">
          Save cloud settings
        </Button>
        <Button onclick={handleCloudSync} disabled={cloudSyncing || !cloudUrl}>
          {#if cloudSyncing}
            <Loader2 size={14} class="animate-spin" /> Syncing…
          {:else}
            <RefreshCw size={14} /> Sync now
          {/if}
        </Button>
      </div>

      {#if lastCloudSync}
        <p class="mt-2 text-xs text-ink-400">Last cloud sync: {formatSyncTime(lastCloudSync)}</p>
      {/if}

      {#if !cloudOnline}
        <div class="mt-3 flex items-center gap-2 text-xs text-amber-600 bg-amber-50 border border-amber-200 rounded-xl px-3 py-2">
          <CloudOff size={12} /> No internet connection detected. Cloud sync will retry automatically.
        </div>
      {/if}
    {/if}
  </Card>

  <!-- Sync History -->
  <Card>
    <button
      class="flex w-full items-center justify-between"
      onclick={() => (historyExpanded = !historyExpanded)}
    >
      <h3 class="flex items-center gap-2 text-base font-semibold text-ink-900">
        <Clock size={16} /> Sync History
        <span class="text-xs text-ink-400 font-normal">({$syncStore.history.length} events)</span>
      </h3>
      {#if historyExpanded}
        <ChevronDown size={16} class="text-ink-400" />
      {:else}
        <ChevronRight size={16} class="text-ink-400" />
      {/if}
    </button>

    {#if historyExpanded}
      <div class="mt-4 space-y-2">
        {#if $syncStore.history.length === 0}
          <p class="text-sm text-ink-400 text-center py-4">No sync events yet.</p>
        {:else}
          {#each $syncStore.history as entry}
            <div class="flex items-center gap-3 rounded-xl border border-ink-100 bg-[#fcfcf9] px-3 py-2.5">

              <span class="text-base">{transportIcon(entry.transport)}</span>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium text-ink-800 truncate">
                  {entry.peerDeviceName ?? 'Unknown device'}
                </p>
                <p class="text-xs text-ink-400">
                  ↑ {entry.rowsSent} sent · ↓ {entry.rowsReceived} received · {formatSyncTime(entry.syncedAt)}
                </p>
              </div>
              {#if entry.success}
                <CheckCircle2 size={14} class="text-emerald-500 shrink-0" />
              {:else}
                <span title={entry.errorMessage ?? 'Failed'}><XCircle size={14} class="text-red-400 shrink-0" /></span>
              {/if}
            </div>
          {/each}
        {/if}
      </div>
    {/if}
  </Card>
</div>
