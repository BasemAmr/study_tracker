# SYNC SETUP GUIDE

## First-Time Setup (Both Devices)

1. Open StudyTracker → click **Sync** in the sidebar
2. Edit your device name (tap the **Edit** button next to "This Device")
3. Set an encryption passphrase under **File Export / Import → Encryption passphrase**
   - Must match on both devices for file sync to work
   - Leave blank to skip file encryption

---

## Transport 1 — Local WiFi (Recommended)

**Requirements**: Both devices on the same WiFi network

**Desktop (Host)**:
1. Open Sync screen → WiFi section → click **Start hosting**
2. A 6-digit pairing code appears — share it with the other device once

**Android (Client)**:
1. Open Sync screen → WiFi section → tap **Scan for peers**
2. Your desktop appears in the list → tap **Pair & Sync**
3. Enter the 6-digit code from the desktop (first time only)

**After first pair**: Sync is one-tap — no code needed again.

---

## Transport 2 — Bluetooth

Available on Android-to-Android only. Windows does not support Bluetooth peripheral mode reliably.
- Android: open Sync → Bluetooth section → scan and pair

---

## Transport 3 — USB / File (Universal Fallback)

Works on any platform without any network.

**Step 1 — Export** (source device):
1. Open Sync screen → **File Export / Import** → click **Export sync file**
2. Save the `.studysync` file

**Step 2 — Transfer**:
- USB cable: plug in, copy the file to the other device
- Or: email it, send via WhatsApp/Telegram, save to shared cloud drive

**Step 3 — Import** (destination device):
1. Open Sync screen → **File Export / Import** → click **Import sync file**
2. Select the `.studysync` file
3. Data merges automatically — no duplicates created

---

## Transport 5 — Cloud Sync (Optional)

**Requirements**: Internet connection + a free Supabase account

1. Create a free project at [supabase.com](https://supabase.com)
2. Copy your project URL and anon key from Project Settings → API
3. Open Sync screen → **Cloud Sync** → enable the toggle
4. Enter your URL and anon key → click **Save cloud settings**
5. Click **Sync now** to test

Cloud sync runs automatically in the background when online.

**To disable**: toggle Cloud Sync off → no data leaves the device.

---

## Limitations

- **Bluetooth on desktop**: Not supported on Windows 10 without custom drivers
- **USB auto-detect**: Not supported — use the file method instead
- **Deletions**: Deleting a record on one device does not delete it on others (v1 limitation)
- **Active timers**: Sync does not interrupt an active session timer
