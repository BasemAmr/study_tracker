use aes_gcm::{
    aead::{Aead, KeyInit, OsRng},
    Aes256Gcm, Key, Nonce,
};
use base64::{engine::general_purpose::STANDARD as BASE64, Engine};
use pbkdf2::pbkdf2_hmac;
use rand::RngCore;
use sha2::Sha256;

const SALT: &[u8] = b"studytracker-sync-salt-v1";
const PBKDF2_ROUNDS: u32 = 100_000;

/// Derive a 32-byte AES key from a passphrase using PBKDF2-HMAC-SHA256.
/// If passphrase is empty, returns a fixed all-zeros key (no encryption effectively).
fn derive_key(passphrase: &str) -> [u8; 32] {
    let mut key = [0u8; 32];
    if passphrase.is_empty() {
        return key;
    }
    pbkdf2_hmac::<Sha256>(passphrase.as_bytes(), SALT, PBKDF2_ROUNDS, &mut key);
    key
}

/// Encrypt plaintext JSON with AES-256-GCM.
/// Returns base64(nonce || ciphertext).
pub fn encrypt(plaintext: &str, passphrase: &str) -> Result<String, String> {
    let key_bytes = derive_key(passphrase);
    let key = Key::<Aes256Gcm>::from_slice(&key_bytes);
    let cipher = Aes256Gcm::new(key);

    let mut nonce_bytes = [0u8; 12];
    OsRng.fill_bytes(&mut nonce_bytes);
    let nonce = Nonce::from_slice(&nonce_bytes);

    let ciphertext = cipher
        .encrypt(nonce, plaintext.as_bytes())
        .map_err(|e| format!("Encryption failed: {e}"))?;

    let mut combined = Vec::with_capacity(12 + ciphertext.len());
    combined.extend_from_slice(&nonce_bytes);
    combined.extend_from_slice(&ciphertext);

    Ok(BASE64.encode(&combined))
}

/// Decrypt base64(nonce || ciphertext) with AES-256-GCM.
pub fn decrypt(encoded: &str, passphrase: &str) -> Result<String, String> {
    let combined = BASE64
        .decode(encoded)
        .map_err(|e| format!("Base64 decode failed: {e}"))?;

    if combined.len() < 12 {
        return Err("Ciphertext too short".into());
    }

    let (nonce_bytes, ciphertext) = combined.split_at(12);
    let key_bytes = derive_key(passphrase);
    let key = Key::<Aes256Gcm>::from_slice(&key_bytes);
    let cipher = Aes256Gcm::new(key);
    let nonce = Nonce::from_slice(nonce_bytes);

    let plaintext = cipher
        .decrypt(nonce, ciphertext)
        .map_err(|_| "Decryption failed — wrong passphrase or corrupted file".to_string())?;

    String::from_utf8(plaintext).map_err(|e| format!("UTF-8 decode failed: {e}"))
}
