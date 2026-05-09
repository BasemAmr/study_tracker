# SYNC ARCHITECTURE

## Philosophy

Device-first, cloud-last. Every transport is independent. Any one working is enough to sync.
No mandatory cloud account. No data leaves the device unless the user explicitly enables cloud sync.

## Transport Priority Order

| Priority | Transport   | Status on Desktop | Status on Android |
|----------|-------------|-------------------|-------------------|
| 1        | Local WiFi  | ✅ Full           | ✅ Full           |
| 2        | Bluetooth   | ⚠️ Limited (no peripheral mode on Win10) | ✅ Full |
| 3        | USB         | ✅ Guided via file | ✅ Guided via file |
| 4        | File Export | ✅ Full (AES-256-GCM encrypted) | ✅ Full |
| 5        | Cloud       | ✅ Optional (Supabase / custom) | ✅ Optional |

## Device Identity

Each device generates a UUID on first launch, stored permanently in `app_settings` as `syncDeviceId`.
This ID never changes and uniquely identifies the device across all sync sessions.

## Sync Payload

A single JSON structure used by every transport:
```
{
  payload_version: 1,
  device_id: string,
  device_name: string,
  profile_sync_id: string | null,
  exported_at: ISO timestamp,
  since_timestamp: ISO timestamp,
  tables: {
    profiles: [...],
    study_sessions: [...],
    subjects: [...],
    subject_groups: [...],
    session_tasks: [...],
    goals: [...],
    mood_logs: [...]
  }
}
```

## Conflict Resolution

**Last-write-wins** using `updated_at` UTC timestamp.

- `sync_id` is the global unique identifier for each row (set at creation, never changes)
- On upsert: if incoming `updated_at` > local `updated_at` → overwrite; otherwise keep local
- Idempotent: applying the same payload twice produces the same result
- Deletions are not synced in v1 (soft-delete with a `deleted_at` flag is planned for v2)

## High-Water Mark

Each device tracks `last_synced_at` per `(peer_device_id, transport)` pair in `sync_state`.
On next sync: only rows with `updated_at > last_synced_at` are sent.
Full sync: `since_timestamp = epoch (1970-01-01T00:00:00.000Z)`.

## Transport Implementations

### WiFi LAN (axum + mdns-sd)
- **Rust**: axum HTTP server on port 47821 (configurable), mdns-sd registers `_studysync._tcp`
- **Frontend**: Svelte calls Tauri commands for start/stop/discover/exchange
- **Pairing**: 6-digit code shown on host, entered on client once; stored in `paired_devices` set
- **Exchange**: `POST /sync/exchange` — sends payload, receives host's payload in response

### File (AES-256-GCM)
- **Encryption**: PBKDF2-HMAC-SHA256 (100k rounds) → AES-256-GCM key; nonce prepended to ciphertext
- **Format**: base64(nonce + ciphertext) written to `.studysync` file
- **Desktop**: Tauri `dialog.save/pick_file` → Rust crypto commands
- **Android**: share_plus (export) + file_picker (import) → Dart crypto

### Cloud (HTTP REST)
- **Protocol**: `POST {url}/sync/push` with Authorization header; body/response are SyncPayload JSON
- **Providers**: Supabase (use their Edge Functions endpoint), or any custom URL
- **Background**: disabled by default; user opts in and configures per-device

## Schema Additions (Migration v6)

```sql
sync_state   (peer_device_id, transport, last_synced_at, last_sync_direction, last_row_count)
sync_history (id, peer_device_id, peer_device_name, transport, direction, rows_sent, rows_received, success, error_message, synced_at)
```

New `app_settings` keys: `syncDeviceId`, `syncDeviceName`, `syncPassphrase`,
`wifiSyncEnabled`, `wifiSyncPort`, `wifiSyncPairingCode`,
`cloudSyncEnabled`, `cloudSyncProvider`, `cloudSyncUrl`, `cloudSyncAnonKey`

## Files Created

### TypeScript (Svelte app)
- `src/core/sync/syncEngine.ts` — transport-agnostic core (build/apply payload, sync state)
- `src/core/sync/syncUtils.ts` — shared helpers (timestamps, formatters, pairing codes)
- `src/core/sync/fileTransport.ts` — file export/import via Tauri commands
- `src/core/sync/wifiTransport.ts` — WiFi server control and peer sync via Tauri commands
- `src/core/sync/cloudTransport.ts` — optional cloud sync (Supabase / custom endpoint)
- `src/features/sync/Sync.svelte` — sync management UI screen
- `src/core/stores/router.ts` — added 'sync' route
- `src/ui/components/Sidebar.svelte` — added Sync nav item

### Rust (Tauri)
- `src-tauri/src/crypto.rs` — AES-256-GCM + PBKDF2 encrypt/decrypt
- `src-tauri/src/sync_server.rs` — axum HTTP server + mDNS registration + discovery
- `src-tauri/src/sync_client.rs` — HTTP client for WiFi exchange + file I/O helpers
- `src-tauri/src/lib.rs` — Tauri commands wired (sync_export_file, sync_import_file, sync_wifi_*)
