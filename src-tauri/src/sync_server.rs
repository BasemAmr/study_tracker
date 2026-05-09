use axum::{
    extract::State,
    http::StatusCode,
    routing::{get, post},
    Json, Router,
};
use mdns_sd::{ServiceDaemon, ServiceEvent, ServiceInfo};
use mdns_sd::TxtProperties;
use once_cell::sync::OnceCell;
use serde::{Deserialize, Serialize};
use std::{
    collections::VecDeque,
    net::SocketAddr,
    sync::{Arc, Mutex},
    time::{Duration, Instant},
};
use tokio::sync::oneshot;
use tower_http::cors::{Any, CorsLayer};

// ─── Shared server state ──────────────────────────────────────────────────────

#[derive(Clone)]
pub struct SyncServerState {
    pub pairing_code: Arc<Mutex<String>>,
    pub passphrase: Arc<Mutex<String>>,
    pub device_id: Arc<Mutex<String>>,
    pub device_name: Arc<Mutex<String>>,
}

// Global server handle (shutdown sender)
static SERVER_SHUTDOWN: OnceCell<Mutex<Option<oneshot::Sender<()>>>> = OnceCell::new();
static GLOBAL_STATE: OnceCell<Mutex<Option<SyncServerState>>> = OnceCell::new();

// ─── Request / Response types ─────────────────────────────────────────────────

#[derive(Deserialize)]
pub struct HandshakeRequest {
    pub device_id: String,
    pub device_name: String,
    #[serde(alias = "pairingCode", alias = "pairing_code")]
    pub pairing_code: String,
    pub payload: String, // their outgoing payload
    #[serde(default)]
    pub timestamp: Option<i64>,
}

#[derive(Serialize)]
pub struct HandshakeResponse {
    pub accepted: bool,
    pub device_id: String,
    pub device_name: String,
    pub version: i32,
    pub payload_version: i32,
    pub payload: Option<String>, // our outgoing payload for them
    pub error: Option<String>,
    /// Unix time in ms (this host) for clock-skew logging on clients
    pub timestamp: i64,
}

#[derive(Serialize)]
pub struct StatusResponse {
    pub device_id: String,
    pub device_name: String,
    pub service: &'static str,
}

// ─── Global Sync Queues ───────────────────────────────────────────────────────
// FIFO: payloads must apply in receipt order. Using Vec::push + Vec::pop() was LIFO
// (last exchange processed first); a stale older payload could overwrite a newer good merge.
static INCOMING_QUEUE: OnceCell<Mutex<VecDeque<String>>> = OnceCell::new();
static OUTGOING_PAYLOAD: OnceCell<Mutex<Option<String>>> = OnceCell::new();

pub fn set_outgoing_payload(payload: Option<String>) {
    let mut guard = OUTGOING_PAYLOAD
        .get_or_init(|| Mutex::new(None))
        .lock()
        .unwrap();
    *guard = payload;
}

pub fn pop_incoming_payload() -> Option<String> {
    INCOMING_QUEUE
        .get_or_init(|| Mutex::new(VecDeque::new()))
        .lock()
        .unwrap()
        .pop_front()
}

// ─── Route handlers ───────────────────────────────────────────────────────────

async fn handle_status(State(state): State<SyncServerState>) -> Json<StatusResponse> {
    Json(StatusResponse {
        device_id: state.device_id.lock().unwrap().clone(),
        device_name: state.device_name.lock().unwrap().clone(),
        service: "studysync-v1",
    })
}

async fn handle_sync(
    State(state): State<SyncServerState>,
    Json(req): Json<HandshakeRequest>,
) -> (StatusCode, Json<HandshakeResponse>) {
    let now_ms: i64 = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0);
    if let Some(remote_ms) = req.timestamp {
        let skew = remote_ms - now_ms;
        if skew.abs() > 60_000 {
            eprintln!("[Sync] Clock skew detected: {skew}ms from client {}", req.device_name);
        }
    }
    let expected_code = state.pairing_code.lock().unwrap().clone();

    // Validate pairing - the code is the credential
    if req.pairing_code.is_empty() || req.pairing_code != expected_code {
        return (
            StatusCode::UNAUTHORIZED,
            Json(HandshakeResponse {
                accepted: false,
                device_id: state.device_id.lock().unwrap().clone(),
                device_name: state.device_name.lock().unwrap().clone(),
                version: 1,
                payload_version: 1,
                payload: None,
                error: Some("Invalid pairing code".into()),
                timestamp: now_ms,
            }),
        );
    }

    // Store their incoming payload for the frontend to consume (global queue)
    INCOMING_QUEUE
        .get_or_init(|| Mutex::new(VecDeque::new()))
        .lock()
        .unwrap()
        .push_back(req.payload);

    // Get our outgoing payload (set by global state)
    let out_payload = OUTGOING_PAYLOAD
        .get_or_init(|| Mutex::new(None))
        .lock()
        .unwrap()
        .clone();

    (
        StatusCode::OK,
        Json(HandshakeResponse {
            accepted: true,
            device_id: state.device_id.lock().unwrap().clone(),
            device_name: state.device_name.lock().unwrap().clone(),
            version: 1,
            payload_version: 1,
            payload: out_payload,
            error: None,
            timestamp: now_ms,
        }),
    )
}

async fn handle_pop_incoming() -> Json<Option<String>> {
    Json(pop_incoming_payload())
}

// ─── Server start/stop ────────────────────────────────────────────────────────

pub fn start_server(
    port: u16,
    pairing_code: String,
    passphrase: String,
    device_id: String,
    device_name: String,
) -> Result<(), String> {
    // Shut down any existing server
    stop_server();

    let state = SyncServerState {
        pairing_code: Arc::new(Mutex::new(pairing_code.clone())),
        passphrase: Arc::new(Mutex::new(passphrase)),
        device_id: Arc::new(Mutex::new(device_id.clone())),
        device_name: Arc::new(Mutex::new(device_name.clone())),
    };

    GLOBAL_STATE
        .get_or_init(|| Mutex::new(None))
        .lock()
        .unwrap()
        .replace(state.clone());

    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    let app = Router::new()
        .route("/sync/status", get(handle_status))
        .route("/sync/exchange", post(handle_sync))
        .route("/sync/pop", get(handle_pop_incoming))
        .with_state(state)
        .layer(cors);

    let (tx, rx) = oneshot::channel::<()>();

    SERVER_SHUTDOWN
        .get_or_init(|| Mutex::new(None))
        .lock()
        .unwrap()
        .replace(tx);

    let state_clone_for_mdns = device_id.clone();
    let device_name_clone = device_name.clone();

    tauri::async_runtime::spawn(async move {
        let addr = SocketAddr::from(([0, 0, 0, 0], port));
        let listener = match tokio::net::TcpListener::bind(addr).await {
            Ok(l) => l,
            Err(e) => {
                eprintln!("[SyncServer] Failed to bind port {port}: {e}");
                return;
            }
        };
        eprintln!("[SyncServer] Listening on :{port}");

        axum::serve(listener, app)
            .with_graceful_shutdown(async { rx.await.ok(); })
            .await
            .ok();

        eprintln!("[SyncServer] Server stopped.");
    });

    // Register mDNS service
    register_mdns(port, &state_clone_for_mdns, &device_name_clone);

    Ok(())
}

pub fn stop_server() {
    if let Some(cell) = SERVER_SHUTDOWN.get() {
        if let Some(tx) = cell.lock().unwrap().take() {
            let _ = tx.send(());
        }
    }
    unregister_mdns();
}

pub fn update_pairing_code(code: &str) {
    if let Some(guard) = GLOBAL_STATE.get() {
        if let Some(state) = guard.lock().unwrap().as_ref() {
            let mut pairing_code = state.pairing_code.lock().unwrap();
            *pairing_code = code.to_string();
            eprintln!("[SyncServer] Pairing code updated successfully.");
        }
    }
}

// ─── mDNS ─────────────────────────────────────────────────────────────────────

/// Must use `._tcp.local.` / `._udp.local.` suffix (`browse` rejects bare `._tcp`).
const STUDYSYNC_SERVICE_TYPE: &str = "_studysync._tcp.local.";

static MDNS_DAEMON: OnceCell<Mutex<Option<ServiceDaemon>>> = OnceCell::new();
static CURRENT_DEVICE_ID: OnceCell<Mutex<String>> = OnceCell::new();

/// Serialized `discover_peers_sync`; concurrent browse/stop/browse calls raced.
static DISCOVER_MUTEX: Mutex<()> = Mutex::new(());

fn detect_primary_ipv4() -> Option<String> {
    let socket = std::net::UdpSocket::bind("0.0.0.0:0").ok()?;
    // No traffic is sent; this only selects the outbound interface.
    socket.connect("8.8.8.8:80").ok()?;
    match socket.local_addr().ok()?.ip() {
        std::net::IpAddr::V4(ipv4) => Some(ipv4.to_string()),
        _ => None,
    }
}

/// Public wrapper so `lib.rs` can expose this to the Svelte frontend as a Tauri command.
pub fn detect_primary_ipv4_public() -> Option<String> {
    detect_primary_ipv4()
}

fn register_mdns(port: u16, device_id: &str, device_name: &str) {
    let daemon = match ServiceDaemon::new() {
        Ok(d) => d,
        Err(e) => {
            eprintln!("[mDNS] Failed to create daemon: {e}");
            return;
        }
    };

    let service_type = STUDYSYNC_SERVICE_TYPE;
    let instance_name = format!("studytracker-{}", &device_id[..8.min(device_id.len())]);

    let mut properties = std::collections::HashMap::new();
    properties.insert("id".into(), device_id.to_string());
    properties.insert("name".into(), device_name.to_string());
    properties.insert("v".into(), "1".into());
    // Compatibility for older clients that still read long keys.
    properties.insert("device_id".into(), device_id.to_string());
    properties.insert("device_name".into(), device_name.to_string());

    let advertise_ip = detect_primary_ipv4().unwrap_or_else(|| "127.0.0.1".to_string());
    if advertise_ip == "127.0.0.1" {
        eprintln!(
            "[mDNS] Warning: advertising 127.0.0.1 (LAN IP probe failed); peers cannot reach this host over Wi‑Fi."
        );
    }
    let host_name = format!(
        "{}.local.",
        hostname::get().unwrap_or("localhost".into()).to_string_lossy()
    );

    let service = match ServiceInfo::new(
        service_type,
        &instance_name,
        &host_name,
        advertise_ip.as_str(),
        port,
        properties,
    ) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("[mDNS] Failed to create service info: {e}");
            return;
        }
    };

    if let Err(e) = daemon.register(service) {
        eprintln!("[mDNS] Failed to register service: {e}");
        return;
    }

    eprintln!("[mDNS] Registered {instance_name} on port {port} @ {advertise_ip}");

    CURRENT_DEVICE_ID
        .get_or_init(|| Mutex::new(String::new()))
        .lock()
        .unwrap()
        .clone_from(&device_id.to_string());

    MDNS_DAEMON
        .get_or_init(|| Mutex::new(None))
        .lock()
        .unwrap()
        .replace(daemon);
}

fn unregister_mdns() {
    if let Some(cell) = MDNS_DAEMON.get() {
        if let Some(daemon) = cell.lock().unwrap().take() {
            let _ = daemon.shutdown();
        }
    }
}

fn txt_prop_lossy(props: &TxtProperties, key: &str) -> Option<String> {
    let p = props.get(key)?;
    if let Some(raw) = p.val() {
        if raw.is_empty() {
            None
        } else {
            Some(String::from_utf8_lossy(raw).trim().to_string())
        }
    } else {
        let s = p.val_str().trim();
        if s.is_empty() {
            None
        } else {
            Some(s.to_string())
        }
    }
}

fn txt_device_and_name(props: &TxtProperties) -> (String, String) {
    let device_id = txt_prop_lossy(props, "device_id")
        .or_else(|| txt_prop_lossy(props, "id"))
        .unwrap_or_default();
    let device_name = txt_prop_lossy(props, "device_name")
        .or_else(|| txt_prop_lossy(props, "name"))
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "Unknown".to_string());
    (device_id, device_name)
}

/// Discover StudyTracker peers on the LAN via mDNS.
/// Returns after a short browse timeout.
pub fn discover_peers_sync() -> Vec<serde_json::Value> {
    let _discover_lock = match DISCOVER_MUTEX.lock() {
        Ok(g) => g,
        Err(e) => {
            eprintln!("[mDNS discover] mutex poisoned: {}", e);
            return vec![];
        }
    };

    // Windows + Wi-Fi: opening a second `ServiceDaemon` (second UDP/multicast bindings) commonly
    // receives ZERO browse results while `_studysync` is hosted on daemon #1. Clone the responder
    // handle so PTR/SRV replies share the active socket with `register()` (RFC stack same thread).
    let (daemon, ephemeral_browse_daemon) =
        match MDNS_DAEMON
            .get()
            .and_then(|cell| cell.lock().ok())
            .and_then(|guard| guard.as_ref().map(|d| (d.clone(), false)))
        {
            Some(pair) => {
                eprintln!("[mDNS discover] browsing on shared responder daemon (StudyTracker Wi-Fi host)");
                pair
            }
            None => {
                let daemon = match ServiceDaemon::new() {
                    Ok(d) => d,
                    Err(e) => {
                        eprintln!("[mDNS discover] ServiceDaemon::new failed: {e}");
                        return vec![];
                    }
                };
                eprintln!("[mDNS discover] browsing on ephemeral querier daemon (Wi-Fi host stopped)");
                (daemon, true)
            }
        };

    let receiver = match daemon.browse(STUDYSYNC_SERVICE_TYPE) {
        Ok(r) => r,
        Err(e) => {
            eprintln!("[mDNS discover] browse(\"{STUDYSYNC_SERVICE_TYPE}\") failed: {e}");
            if ephemeral_browse_daemon {
                let _ = daemon.shutdown();
            }
            return vec![];
        }
    };

    let mut peers = Vec::new();
    let deadline = Instant::now() + Duration::from_secs(12);

    while Instant::now() < deadline {
        match receiver.recv_timeout(Duration::from_millis(220)) {
            Ok(ServiceEvent::ServiceResolved(info)) => {
                let props = info.get_properties();
                let (device_id, device_name) = txt_device_and_name(props);
                if device_id.is_empty() {
                    eprintln!(
                        "[mDNS discover] resolved {} TXT missing device_id/id (keys: {:?})",
                        info.get_fullname(),
                        props.iter().map(|p| p.key().to_string()).collect::<Vec<_>>()
                    );
                    continue;
                }
                let host = info
                    .get_addresses()
                    .iter()
                    .find(|ip| ip.is_ipv4())
                    .or_else(|| info.get_addresses().iter().find(|ip| ip.is_ipv6()))
                    .map(|ip| ip.to_string())
                    .unwrap_or_else(|| info.get_hostname().trim_end_matches('.').to_string());

                let port = info.get_port();
                let current_device_id = CURRENT_DEVICE_ID
                    .get_or_init(|| Mutex::new(String::new()))
                    .lock()
                    .unwrap()
                    .clone();
                if !current_device_id.is_empty() && device_id == current_device_id {
                    continue;
                }
                peers.push(serde_json::json!({
                    "device_id": device_id,
                    "device_name": device_name,
                    "host": host,
                    "port": port
                }));
            }
            Ok(ServiceEvent::ServiceFound(ty, full)) => {
                eprintln!("[mDNS discover] service found (resolving…): ty={ty} full={full}");
            }
            Ok(_) => {}
            Err(_) => {}
        }
    }

    if let Err(e) = daemon.stop_browse(STUDYSYNC_SERVICE_TYPE) {
        eprintln!("[mDNS discover] stop_browse: {e}");
    }

    // Never shutdown shared responder — it would kill Wi-Fi sync hosting.
    if ephemeral_browse_daemon {
        let _ = daemon.shutdown();
    }

    peers
}
