mod crypto;
mod sync_client;
mod sync_server;

use std::fs;
use std::path::PathBuf;
use tauri::Manager;

// ─── File sync Tauri commands ─────────────────────────────────────────────────

/// Export a sync payload as an encrypted .studysync file.
/// Opens a native save dialog. Returns the file path on success.
#[tauri::command]
async fn sync_export_file(
    app: tauri::AppHandle,
    json: String,
    passphrase: String,
    suggested_name: String,
) -> Result<String, String> {
    use tauri_plugin_dialog::DialogExt;

    let encrypted = crypto::encrypt(&json, &passphrase)?;

    let path = app
        .dialog()
        .file()
        .set_title("Export Sync File")
        .set_file_name(&suggested_name)
        .add_filter("StudySync File", &["studysync"])
        .blocking_save_file()
        .ok_or("Save dialog cancelled")?;

    let path_buf = path.as_path().ok_or("Invalid path")?;
    sync_client::write_file_bytes(path_buf, encrypted.as_bytes())?;

    Ok(path_buf.to_string_lossy().to_string())
}

/// Import an encrypted .studysync file and return the decrypted JSON payload.
/// Opens a native open dialog.
#[tauri::command]
async fn sync_import_file(app: tauri::AppHandle, passphrase: String) -> Result<String, String> {
    use tauri_plugin_dialog::DialogExt;

    let path = app
        .dialog()
        .file()
        .set_title("Import Sync File")
        .add_filter("StudySync File", &["studysync"])
        .blocking_pick_file()
        .ok_or("Open dialog cancelled")?;

    let path_buf = path.as_path().ok_or("Invalid path")?;
    let bytes = sync_client::read_file_bytes(path_buf)?;
    let encoded = String::from_utf8(bytes).map_err(|e| e.to_string())?;

    crypto::decrypt(&encoded, &passphrase)
}

// ─── Notifications (scheduler worker → immediate OS toast) ─────────────────────

#[cfg(not(any(target_os = "android", target_os = "ios")))]
#[tauri::command]
async fn fire_notification(
    app: tauri::AppHandle,
    id: i32,
    title: String,
    body: String,
    payload: serde_json::Value,
) -> Result<(), String> {
    use tauri_plugin_notification::NotificationExt;

    let mut extra = serde_json::Map::new();
    extra.insert("payload".to_string(), payload);
    let extra_js = serde_json::Value::Object(extra);

    app.notification()
        .builder()
        .id(id)
        .title(title)
        .body(body)
        .extra("studytracker_notification", extra_js)
        .show()
        .map_err(|e| e.to_string())
}

#[cfg(any(target_os = "android", target_os = "ios"))]
#[tauri::command]
async fn fire_notification(
    _app: tauri::AppHandle,
    _id: i32,
    _title: String,
    _body: String,
    _payload: serde_json::Value,
) -> Result<(), String> {
    Ok(())
}

// ─── WiFi sync Tauri commands ─────────────────────────────────────────────────

/// Start the local HTTP sync server and register mDNS service.
#[tauri::command]
async fn sync_wifi_start_server(
    port: u16,
    pairing_code: String,
    passphrase: String,
    device_id: String,
    device_name: String,
) -> Result<(), String> {
    sync_server::start_server(port, pairing_code, passphrase, device_id, device_name)
}

/// Stop the local HTTP sync server and unregister mDNS service.
#[tauri::command]
async fn sync_wifi_stop_server() -> Result<(), String> {
    sync_server::stop_server();
    Ok(())
}

/// Report the primary LAN IPv4 the OS would use to reach the outside world.
/// Used by the Sync tab to show "write this IP on the other device" when
/// auto-discovery (mDNS) fails on guest Wi-Fi or hotspot subnets.
#[tauri::command]
async fn sync_wifi_get_local_ip() -> Result<Option<String>, String> {
    Ok(sync_server::detect_primary_ipv4_public())
}

/// Update the pairing code without restarting the server.
#[tauri::command]
async fn sync_wifi_update_pairing_code(code: String) -> Result<(), String> {
    sync_server::update_pairing_code(&code);
    Ok(())
}

/// Discover nearby StudyTracker devices on the LAN via mDNS.
/// Blocks for ~12 seconds while browsing.
#[tauri::command]
async fn sync_wifi_discover_peers() -> Result<Vec<serde_json::Value>, String> {
    let peers = tokio::task::spawn_blocking(sync_server::discover_peers_sync)
        .await
        .map_err(|e| e.to_string())?;
    Ok(peers)
}

/// Set the outgoing payload for the next WiFi sync exchange.
#[tauri::command]
async fn sync_wifi_set_outgoing_payload(payload: Option<String>) -> Result<(), String> {
    sync_server::set_outgoing_payload(payload);
    Ok(())
}

/// Pop the next incoming payload received from a peer.
#[tauri::command]
async fn sync_wifi_pop_incoming_payload() -> Result<Option<String>, String> {
    Ok(sync_server::pop_incoming_payload())
}

/// Probe a peer hosting StudyTracker on the LAN (GET `/sync/status`). Runs in Rust so LAN IPs are not blocked by browser CORS.
#[tauri::command]
async fn sync_wifi_probe_status(host: String, port: u16) -> Result<sync_client::ProbeStatusOutcome, String> {
    Ok(sync_client::probe_sync_status(&host, port).await)
}

/// Exchange sync payloads with a peer over HTTP.
#[tauri::command]
async fn sync_wifi_exchange(
    host: String,
    port: u16,
    my_device_id: String,
    my_device_name: String,
    pairing_code: String,
    payload: String,
) -> Result<sync_client::ExchangeResult, String> {
    Ok(
        sync_client::exchange_with_peer(&host, port, &my_device_id, &my_device_name, &pairing_code, &payload)
            .await,
    )
}

// ─── App entry ────────────────────────────────────────────────────────────────

#[cfg(not(any(target_os = "android", target_os = "ios")))]
fn solid_tray_placeholder_icon() -> tauri::image::Image<'static> {
    use tauri::image::Image;
    const W: u32 = 32;
    const H: u32 = 32;
    let mut rgba = Vec::with_capacity((W * H * 4) as usize);
    for _ in 0..(W * H) {
        rgba.extend_from_slice(&[90, 127, 74, 255]);
    }
    Image::new_owned(rgba, W, H)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let tray_start_requested = std::env::args().any(|arg| arg == "--studytracker-tray-start");

    let mut builder = tauri::Builder::default();

    builder = builder
        .plugin(tauri_plugin_single_instance::init(|app, _args, _cwd| {
            let _ = app
                .get_webview_window("main")
                .map(|w| {
                    let _ = w.show();
                    let _ = w.set_focus();
                });
        }));

    #[cfg(not(any(target_os = "android", target_os = "ios")))]
    {
        builder = builder
            .plugin(
                tauri_plugin_autostart::Builder::new()
                    .args(["--studytracker-tray-start"])
                    .build(),
            )
            .plugin(tauri_plugin_notification::init());

        builder = builder.on_window_event(|window, event| {
            // Keep the Rust process alive: closing the chrome hides instead of quitting (tray timers).
            if let tauri::WindowEvent::CloseRequested { api, .. } = event {
                api.prevent_close();
                let _ = window.hide();
            }
        });
    }

    builder
        .plugin(tauri_plugin_sql::Builder::default().build())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_shell::init())
        .setup(move |app| {
            #[cfg(not(any(target_os = "android", target_os = "ios")))]
            {
                use tauri::image::Image;
                use tauri::menu::{Menu, MenuItemBuilder};
                use tauri::tray::{TrayIconBuilder, TrayIconEvent};
                use tauri_plugin_autostart::ManagerExt as _;

                // Best-effort: register autostart immediately (silent on failure in dev/perms scenarios).
                if let Err(e) = app.autolaunch().enable() {
                    eprintln!("[StudyTracker] autostart enable skipped: {:?}", e);
                }

                let open_action = MenuItemBuilder::with_id("tray_open", "Open").build(app)?;
                let quit_action = MenuItemBuilder::with_id("tray_quit", "Quit").build(app)?;
                let menu = Menu::with_items(app, &[&open_action, &quit_action])?;

                let icon_img = match Image::from_bytes(include_bytes!("../icons/icon.ico")) {
                    Ok(img) => img.to_owned(),
                    Err(_) => {
                        // Fallback for Mac or if .ico fails - try to load from window icon or fallback
                        match app.default_window_icon() {
                            Some(ic) => ic.to_owned(),
                            None => solid_tray_placeholder_icon()
                        }
                    }
                };

                TrayIconBuilder::new()
                    .menu(&menu)
                    .tooltip("StudyTracker — running reminders in the tray")
                    .icon(icon_img)
                    .show_menu_on_left_click(true)
                    .on_menu_event(|app, ev| match ev.id().as_ref() {
                        "tray_open" => {
                            if let Some(w) = app.get_webview_window("main") {
                                let _ = w.show();
                                let _ = w.set_focus();
                            }
                        }
                        "tray_quit" => {
                            app.exit(0);
                        }
                        _ => {}
                    })
                    .on_tray_icon_event(|icon, evt| {
                        if let TrayIconEvent::DoubleClick {
                            button: tauri::tray::MouseButton::Left,
                            ..
                        } = evt
                        {
                            let app = icon.app_handle();
                            if let Some(w) = app.get_webview_window("main") {
                                let _ = w.show();
                                let _ = w.set_focus();
                            }
                        }
                    })
                    .build(app)?;

                if tray_start_requested {
                    if let Some(win) = app.get_webview_window("main") {
                        let _ = win.hide();
                    }
                }


            }

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            sync_export_file,
            sync_import_file,
            fire_notification,
            sync_wifi_start_server,
            sync_wifi_stop_server,
            sync_wifi_get_local_ip,
            sync_wifi_update_pairing_code,
            sync_wifi_discover_peers,
            sync_wifi_probe_status,
            sync_wifi_exchange,
            sync_wifi_set_outgoing_payload,
            sync_wifi_pop_incoming_payload,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
