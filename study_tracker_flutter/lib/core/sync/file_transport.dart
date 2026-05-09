// lib/core/sync/file_transport.dart
//
// File transport: export/import encrypted .studysync files.
// Encryption: AES-256-GCM with PBKDF2-HMAC-SHA256 key derivation.
// Export: build payload → encrypt → share via share_plus.
// Import: file_picker → read → decrypt → apply payload.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import 'sync_engine.dart';

class FileTransportResult {
  final bool success;
  final int? rowsExported;
  final int? rowsImported;
  final String? errorMessage;

  const FileTransportResult({
    required this.success,
    this.rowsExported,
    this.rowsImported,
    this.errorMessage,
  });
}

// ─── Crypto helpers ───────────────────────────────────────────────────────────

const _salt = 'studytracker-sync-salt-v1';
const _pbkdf2Rounds = 100000;

Uint8List _deriveKey(String passphrase) {
  if (passphrase.isEmpty) return Uint8List(32); // zero key = no encryption

  final params = pc.Pbkdf2Parameters(
    Uint8List.fromList(utf8.encode(_salt)),
    _pbkdf2Rounds,
    32,
  );
  final pbkdf2 = pc.PBKDF2KeyDerivator(pc.HMac(pc.SHA256Digest(), 64));
  pbkdf2.init(params);
  return pbkdf2.process(Uint8List.fromList(utf8.encode(passphrase)));
}

/// Encrypt plaintext using AES-256-GCM.
/// Returns base64(IV + ciphertext).
String encryptPayload(String plaintext, String passphrase) {
  final keyBytes = _deriveKey(passphrase);
  final key = enc.Key(keyBytes);
  final iv = enc.IV.fromSecureRandom(12);
  final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
  final encrypted = encrypter.encrypt(plaintext, iv: iv);

  // Combine IV + ciphertext
  final combined = Uint8List(12 + encrypted.bytes.length);
  combined.setAll(0, iv.bytes);
  combined.setAll(12, encrypted.bytes);
  return base64.encode(combined);
}

/// Decrypt base64(IV + ciphertext) using AES-256-GCM.
String decryptPayload(String encoded, String passphrase) {
  final combined = base64.decode(encoded);
  if (combined.length < 12) throw Exception('File too short to be valid');

  final iv = enc.IV(combined.sublist(0, 12));
  final ciphertext = enc.Encrypted(combined.sublist(12));
  final keyBytes = _deriveKey(passphrase);
  final key = enc.Key(keyBytes);
  final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));

  try {
    return encrypter.decrypt(ciphertext, iv: iv);
  } catch (_) {
    throw Exception('Decryption failed — wrong passphrase or corrupted file');
  }
}

// ─── Export ───────────────────────────────────────────────────────────────────

class FileTransport {
  final SyncEngine _engine;

  FileTransport(this._engine);

  /// Build a sync payload, encrypt it, and share via share_plus.
  Future<FileTransportResult> export({String passphrase = ''}) async {
    debugPrint('SYNC: [File] Starting export...');
    try {
      final payload = await _engine.buildPayload();
      final json = payload.serialize();
      debugPrint('SYNC: [File] Payload serialized, length: ${json.length}. Encrypting...');
      final encrypted = encryptPayload(json, passphrase);

      final timestamp = DateTime.now()
          .toUtc()
          .toIso8601String()
          .replaceAll(':', '-')
          .substring(0, 19);
      final fileName = 'studysync-$timestamp.studysync';

      // Write to temp file
      final tempDir = await getTemporaryDirectory();
      final file = File(p.join(tempDir.path, fileName));
      await file.writeAsString(encrypted, encoding: utf8);
      debugPrint('SYNC: [File] Saved to temporary file: ${file.path}. Sharing...');

      // Share
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/octet-stream')],
        subject: 'StudyTracker Sync File',
      );

      final rowCount = SyncEngine.countRows(payload);
      debugPrint('SYNC: [File] Export shared successfully. Rows exported: $rowCount');

      await _engine.recordHistory(SyncHistoryEntry(
        peerDeviceId: null,
        peerDeviceName: 'File Export',
        transport: 'file',
        direction: 'push',
        rowsSent: rowCount,
        rowsReceived: 0,
        success: true,
      ));

      return FileTransportResult(success: true, rowsExported: rowCount);
    } catch (e) {
      debugPrint('SYNC: [File] Export failed: $e');
      return FileTransportResult(success: false, errorMessage: e.toString());
    }
  }

  /// Pick a .studysync file, decrypt, and apply the payload.
  Future<FileTransportResult> import({String passphrase = ''}) async {
    debugPrint('SYNC: [File] Starting import...');
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.single.path == null) {
        debugPrint('SYNC: [File] Import cancelled or no file selected.');
        return const FileTransportResult(success: false, errorMessage: 'No file selected');
      }

      final file = File(result.files.single.path!);
      debugPrint('SYNC: [File] Picked file: ${file.path}. Reading...');
      final encoded = await file.readAsString(encoding: utf8);
      debugPrint('SYNC: [File] Decrypting...');
      final json = decryptPayload(encoded, passphrase);
      debugPrint('SYNC: [File] Deserializing and applying payload...');
      final payload = SyncEngine.deserializePayload(json);
      final applyResult = await _engine.applyPayload(payload);
      final rowsReceived = applyResult.total;

      await _engine.updateSyncState(
        peerDeviceId: payload.deviceId.isNotEmpty ? payload.deviceId : 'file-import',
        transport: 'file',
        direction: 'pull',
        rowCount: rowsReceived,
      );

      await _engine.recordHistory(SyncHistoryEntry(
        peerDeviceId: payload.deviceId.isNotEmpty ? payload.deviceId : null,
        peerDeviceName: payload.deviceName.isNotEmpty ? payload.deviceName : 'File Import',
        transport: 'file',
        direction: 'pull',
        rowsSent: 0,
        rowsReceived: rowsReceived,
        success: applyResult.errors.isEmpty,
        errorMessage: applyResult.errors.isNotEmpty
            ? applyResult.errors.take(3).join('; ')
            : null,
      ));

      debugPrint('SYNC: [File] Import complete. Rows imported: $rowsReceived');
      return FileTransportResult(success: true, rowsImported: rowsReceived);
    } catch (e) {
      debugPrint('SYNC: [File] Import failed: $e');
      return FileTransportResult(success: false, errorMessage: e.toString());
    }
  }
}
