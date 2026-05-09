use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::io::Write;

/// Result of probing GET `/sync/status` on a LAN peer (desktop axum / Flutter shelf, etc.).
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ProbeStatusOutcome {
    pub ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub device_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub device_name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub diagnostic: Option<String>,
}

fn trim_nonempty(s: &str) -> Option<String> {
    let t = s.trim();
    if t.is_empty() {
        None
    } else {
        Some(t.to_string())
    }
}

fn json_value_as_id(v: &Value) -> Option<String> {
    match v {
        Value::String(s) => trim_nonempty(s),
        Value::Number(n) => Some(n.to_string()),
        _ => None,
    }
}

/// Flutter / Dart or other stacks may expose the device UUID under several keys.
fn pick_device_id(json: &Value) -> Option<String> {
    for key in ["device_id", "deviceId", "id", "peer_id", "peerId"] {
        if let Some(v) = json.get(key) {
            if let Some(s) = json_value_as_id(v) {
                return Some(s);
            }
        }
    }
    None
}

fn pick_device_name(json: &Value) -> String {
    for key in ["device_name", "deviceName", "name"] {
        if let Some(v) = json.get(key) {
            if let Some(s) = v.as_str() {
                if let Some(t) = trim_nonempty(s) {
                    return t;
                }
            }
        }
    }
    "Device".to_string()
}

/// Canonical path matches desktop `sync_server.rs` and Flutter `lib/core/sync/wifi_transport.dart`.
const PROBE_STATUS_PATHS: &[&str] = &[
    "/sync/status",
    "/sync/status/",
];

fn parse_probe_response_body(trimmed: &str, path_hint: &str) -> Result<(String, String), String> {
    if trimmed.is_empty() {
        return Err(format!(
            "{path_hint}: HTTP 200 but empty body (expected JSON with device id)"
        ));
    }

    let json: Value = match serde_json::from_str(trimmed) {
        Ok(v) => v,
        Err(e) => {
            let preview: String = trimmed.chars().take(100).collect();
            return Err(format!(
                "{path_hint}: invalid JSON ({e}). First bytes: {preview}"
            ));
        }
    };

    let Some(device_id) = pick_device_id(&json) else {
        let preview: String = trimmed.chars().take(120).collect();
        return Err(format!(
            "{path_hint}: JSON has no device id field. Snippet: {preview}"
        ));
    };

    let device_name = pick_device_name(&json);
    Ok((device_id, device_name))
}

/// GET status from the native HTTP stack (no browser CORS — required for LAN probes from Tauri UI).
/// Tries several URL paths — mobile hosts sometimes diverge vs desktop Axum routing.
pub async fn probe_sync_status(host: &str, port: u16) -> ProbeStatusOutcome {
    let host = host.to_string();
    let res = tokio::task::spawn_blocking(move || {
        let client = match reqwest::blocking::Client::builder()
            .timeout(std::time::Duration::from_secs(6))
            .build()
        {
            Ok(c) => c,
            Err(e) => {
                return ProbeStatusOutcome {
                    ok: false,
                    device_id: None,
                    device_name: None,
                    diagnostic: Some(format!("Could not build HTTP client: {e}")),
                };
            }
        };

        let mut attempts: Vec<String> = Vec::new();

        for path in PROBE_STATUS_PATHS {
            let url = format!("http://{host}:{port}{path}");
            let resp = match client
                .get(&url)
                .header("Accept", "application/json")
                .send()
            {
                Ok(r) => r,
                Err(e) => {
                    attempts.push(format!("{path}: request error ({e})"));
                    continue;
                }
            };

            let status = resp.status();
            let body = match resp.text() {
                Ok(t) => t,
                Err(e) => {
                    attempts.push(format!("{path}: could not read body ({e})"));
                    continue;
                }
            };

            let trimmed = body.trim();

            if !status.is_success() {
                let preview: String = trimmed.chars().take(80).collect();
                let tail = if preview.is_empty() {
                    "(empty body)".into()
                } else {
                    preview
                };
                attempts.push(format!("{path}: HTTP {} — {}", status.as_u16(), tail));
                continue;
            }

            match parse_probe_response_body(trimmed, path) {
                Ok((device_id, device_name)) => {
                    return ProbeStatusOutcome {
                        ok: true,
                        device_id: Some(device_id),
                        device_name: Some(device_name),
                        diagnostic: None,
                    };
                }
                Err(err) => {
                    attempts.push(err);
                }
            }
        }

        let summary = attempts.join(" | ");
        ProbeStatusOutcome {
            ok: false,
            device_id: None,
            device_name: None,
            diagnostic: Some(if summary.len() > 600 {
                format!("{} …", summary.chars().take(597).collect::<String>())
            } else {
                summary
            }),
        }
    })
    .await;

    match res {
        Ok(outcome) => outcome,
        Err(e) => ProbeStatusOutcome {
            ok: false,
            device_id: None,
            device_name: None,
            diagnostic: Some(format!("probe task: {e}")),
        },
    }
}

/// Exchange a sync payload with a peer over HTTP.
#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ExchangeResult {
    pub incoming_json: Option<String>,
    pub error: Option<String>,
    /// Host-reported time from the last exchange (Unix ms), if present in the response body.
    pub remote_timestamp: Option<i64>,
}

/// Perform HTTP POST to the peer's /sync/exchange endpoint.
pub async fn exchange_with_peer(
    host: &str,
    port: u16,
    my_device_id: &str,
    my_device_name: &str,
    pairing_code: &str,
    payload: &str,
) -> ExchangeResult {
    let url = format!("http://{host}:{port}/sync/exchange");

    let now_ms: i64 = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0);

    let body = serde_json::json!({
        "device_id": my_device_id,
        "device_name": my_device_name,
        "pairing_code": pairing_code,
        "payload": payload,
        "timestamp": now_ms
    });

    // Use reqwest (blocking via spawn_blocking to avoid issues in Tauri runtime)
    let body_str = body.to_string();
    let pairing_code_clone = pairing_code.to_string();
    let result = tokio::task::spawn_blocking(move || {
        let client = reqwest::blocking::Client::builder()
            .timeout(std::time::Duration::from_secs(30))
            .build()
            .map_err(|e| e.to_string())?;

        let resp = client
            .post(&url)
            .header("Content-Type", "application/json")
            .header("Authorization", format!("Bearer {}", pairing_code_clone))
            .body(body_str)
            .send()
            .map_err(|e| e.to_string())?;

        if !resp.status().is_success() {
            let status = resp.status().as_u16();
            let text = resp.text().unwrap_or_default();
            return Err(format!("HTTP {status}: {text}"));
        }

        let json: serde_json::Value = resp.json().map_err(|e| e.to_string())?;
        Ok(json)
    })
    .await;

    match result {
        Ok(Ok(json)) => {
            let mut remote_ts: Option<i64> = None;
            if let Some(v) = json.get("timestamp") {
                if let Some(n) = v.as_i64() {
                    remote_ts = Some(n);
                } else if let Some(n) = v.as_f64() {
                    remote_ts = Some(n as i64);
                }
            }
            if json.get("accepted").is_some() {
                // Wrapper format
                let accepted = json.get("accepted").and_then(|v| v.as_bool()).unwrap_or(false);
                if !accepted {
                    let error = json.get("error")
                        .and_then(|v| v.as_str())
                        .unwrap_or("Peer rejected sync")
                        .to_string();
                    return ExchangeResult { incoming_json: None, error: Some(error), remote_timestamp: None };
                }
                let incoming = json.get("payload").and_then(|v| v.as_str()).map(|s| s.to_string());
                return ExchangeResult { incoming_json: incoming, error: None, remote_timestamp: remote_ts };
            }
            // Raw SyncPayload or legacy JSON
            return ExchangeResult { incoming_json: Some(json.to_string()), error: None, remote_timestamp: remote_ts };
        }
        Ok(Err(e)) => ExchangeResult { incoming_json: None, error: Some(e), remote_timestamp: None },
        Err(e) => ExchangeResult { incoming_json: None, error: Some(e.to_string()), remote_timestamp: None },
    }
}

/// Write bytes to a file, creating parent directories if needed.
pub fn write_file_bytes(path: &std::path::Path, data: &[u8]) -> Result<(), String> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).map_err(|e| e.to_string())?;
    }
    let mut file = std::fs::File::create(path).map_err(|e| e.to_string())?;
    file.write_all(data).map_err(|e| e.to_string())
}

/// Read bytes from a file.
pub fn read_file_bytes(path: &std::path::Path) -> Result<Vec<u8>, String> {
    std::fs::read(path).map_err(|e| e.to_string())
}
