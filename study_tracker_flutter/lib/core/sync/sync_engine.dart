// lib/core/sync/sync_engine.dart
//
// Transport-agnostic sync core.
// Mirrors desktop syncEngine.ts exactly:
//   buildPayload() → reads SQLite, produces SyncPayload
//   applyPayload() → upserts rows using last-write-wins on updated_at
//
// All transports hand payloads in and out. The engine knows nothing
// about HTTP, Bluetooth, or files.

import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../data/db/database.dart';
import '../../data/repositories/settings_repository.dart';
import 'sync_debug_logger.dart';
import 'sync_trigger.dart';

const _uuid = Uuid();

class SyncPayload {
  final int payloadVersion;
  final String deviceId;
  final String deviceName;
  final String? profileSyncId;
  final String exportedAt;
  final String sinceTimestamp;
  final Map<String, List<Map<String, dynamic>>> tables;

  const SyncPayload({
    required this.payloadVersion,
    required this.deviceId,
    required this.deviceName,
    required this.profileSyncId,
    required this.exportedAt,
    required this.sinceTimestamp,
    required this.tables,
  });

  factory SyncPayload.fromJson(Map<String, dynamic> json) {
    final tablesRaw = (json['tables'] as Map<String, dynamic>?) ?? {};
    final tables = tablesRaw.map((k, v) => MapEntry(
          k,
          (v as List<dynamic>).cast<Map<String, dynamic>>(),
        ));
    
    // Robust version parsing: handle strings, numbers, or nulls
    final versionRaw = json['version'] ?? json['payload_version'] ?? 1;
    final version = versionRaw is num 
        ? versionRaw.toInt() 
        : (int.tryParse(versionRaw.toString()) ?? 1);

    return SyncPayload(
      payloadVersion: version,
      deviceId: json['device_id'] as String? ?? '',
      deviceName: json['device_name'] as String? ?? 'Unknown',
      profileSyncId: json['profile_sync_id'] as String?,
      exportedAt: json['exported_at'] as String? ?? '',
      sinceTimestamp: json['since_timestamp'] as String? ?? _epoch,
      tables: tables,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': payloadVersion,
        'payload_version': payloadVersion, // Desktop compatibility
        'device_id': deviceId,
        'device_name': deviceName,
        'deviceId': deviceId, // Mobile compatibility fallback
        'deviceName': deviceName,
        'profile_sync_id': profileSyncId,
        'exported_at': exportedAt,
        'since_timestamp': sinceTimestamp,
        'tables': tables,
      };

  String serialize() => jsonEncode(toJson());
}

class SyncResult {
  final int inserted;
  final int updated;
  final int skipped;
  final int deferred;
  final List<String> errors;

  const SyncResult({
    this.inserted = 0,
    this.updated = 0,
    this.skipped = 0,
    this.deferred = 0,
    this.errors = const [],
  });

  int get total => inserted + updated;
}

class SyncHistoryEntry {
  final String? peerDeviceId;
  final String? peerDeviceName;
  final String transport;
  final String direction;
  final int rowsSent;
  final int rowsReceived;
  final bool success;
  final String? errorMessage;

  const SyncHistoryEntry({
    this.peerDeviceId,
    this.peerDeviceName,
    required this.transport,
    required this.direction,
    this.rowsSent = 0,
    this.rowsReceived = 0,
    required this.success,
    this.errorMessage,
  });
}

// ─── Constants ────────────────────────────────────────────────────────────────

const _epoch = '1970-01-01T00:00:00.000Z';

enum _UpsertOutcome { skipped, applied, deferred }

enum _NameDupMerge { proceed, skipIncoming, mergedDone }

const _syncTables = [
  'profiles',
  'subject_groups',
  'subjects',
  'study_sessions',
  'session_tasks',
  'mood_logs',
  'goals',
  'ai_challenges',
];

// Note: device-local tables are intentionally excluded from sync.
// Do NOT add: notification_settings, notification_log, ai_feature_settings, ai_cache,
// ai_challenge_history

// ─── SyncEngine ───────────────────────────────────────────────────────────────

class SyncEngine {
  final AppDatabase _db;
  final SettingsRepository _settings;
  final SyncDebugLogger _logger = SyncDebugLogger.instance;

  SyncEngine(this._db, this._settings);

  // ── Device identity ──────────────────────────────────────────────────────────

  Future<String> getDeviceId() async {
    final current = await _settings.get('syncDeviceId');
    if (current != null && current.isNotEmpty) return current;

    final generated = _uuid.v4();
    await _settings.set('syncDeviceId', generated);
    _logger.log('Engine', 'Generated missing device id', data: generated);
    return generated;
  }

  Future<void> savePeerPairingCode(String peerDeviceId, String pairingCode) async {
    if (pairingCode.isNotEmpty) {
      // Root cause of the sync-every-5s storm: every successful sync re-wrote this key, which
      // fired SyncTrigger → SyncService → syncWithPairedPeers → new successful sync → re-write…
      // Comparing to the stored value turns this into a true no-op after the first save.
      final existing = await _settings.get('peer_code_$peerDeviceId');
      if (existing == pairingCode) return;
      await _settings.set('peer_code_$peerDeviceId', pairingCode);
      _logger.log('Engine', 'Saved pairing code for peer', data: peerDeviceId);
    }
  }

  Future<String?> getPeerPairingCode(String peerDeviceId) async {
    return await _settings.get('peer_code_$peerDeviceId');
  }

  Future<String?> getHostPairingCode() async {
    return await _settings.get('wifiSyncPairingCode');
  }

  Future<String> getDeviceName() async {
    return await _settings.get('syncDeviceName') ?? 'My Device';
  }

  Future<void> setDeviceName(String name) async {
    await _settings.set('syncDeviceName', name.trim().isEmpty ? 'My Device' : name.trim());
  }

  Future<String?> getCurrentProfileSyncId() async {
    final profileId = await _settings.getCurrentProfileId();
    final rows = await (_db.select(_db.profiles)
          ..where((t) => t.id.equals(profileId)))
        .get();
    return rows.firstOrNull?.syncId;
  }

  String _updatedAtMillisExpr(String column) {
    return '''
      CASE
        WHEN typeof($column) = 'integer' THEN
          CASE WHEN $column > 1000000000000 THEN $column ELSE $column * 1000 END
        WHEN typeof($column) = 'real' THEN
          CASE WHEN $column > 1000000000000 THEN CAST($column AS INTEGER) ELSE CAST($column * 1000 AS INTEGER) END
        WHEN CAST($column AS TEXT) GLOB '[0-9]*' THEN
          CASE WHEN CAST($column AS INTEGER) > 1000000000000 THEN CAST($column AS INTEGER) ELSE CAST($column AS INTEGER) * 1000 END
        ELSE CAST(strftime('%s', replace(replace(CAST($column AS TEXT), 'T', ' '), 'Z', '')) AS INTEGER) * 1000
      END
    ''';
  }

  // ── Build payload ──────────────────────────────────────────────────────────

  /// Build a sync payload containing all rows updated after [sinceTimestamp].
  /// Pass the epoch for a full sync.
  Future<SyncPayload> buildPayload({String? sinceTimestamp}) async {
    final since = sinceTimestamp ?? _epoch;
    final deviceId = await getDeviceId();
    final deviceName = await getDeviceName();
    final profileSyncId = await getCurrentProfileSyncId();
    final now = DateTime.now().toUtc().toIso8601String();

    // Get local profile id for filtering
    final profileId = await _settings.getCurrentProfileId();

    _logger.log('Engine', 'Building payload', data: {
      'since': since,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'profileId': profileId,
      'profileSyncId': profileSyncId,
    });
    final tables = <String, List<Map<String, dynamic>>>{};

    for (final table in _syncTables) {
      try {
        final rows = await _db.customSelect(
          _buildSelectSql(table, since, profileId, profileSyncId),
        ).get();
        if (rows.isNotEmpty) {
          tables[table] = rows.map((r) => r.data).toList();
          _logger.log('Engine', 'Selected rows for payload', data: {
            'table': table,
            'rows': rows.length,
          });
        }
      } catch (e) {
        _logger.log('Engine', 'Failed reading table for payload', data: {
          'table': table,
          'error': '$e',
        });
      }
    }

    _logger.log('Engine', 'Payload build complete', data: {
      'tablesWithData': tables.length,
      'totalRows': tables.values.fold<int>(0, (acc, rows) => acc + rows.length),
    });

    return SyncPayload(
      payloadVersion: 1,
      deviceId: deviceId,
      deviceName: deviceName,
      profileSyncId: profileSyncId,
      exportedAt: now,
      sinceTimestamp: since,
      tables: tables,
    );
  }

  String _buildSelectSql(
    String table,
    String since,
    int profileId,
    String? profileSyncId,
  ) {
    final bufferSince = since == _epoch
        ? _epoch
        : DateTime.parse(since).subtract(const Duration(seconds: 1)).toUtc().toIso8601String();
    final sinceMillis = DateTime.parse(bufferSince).toUtc().millisecondsSinceEpoch;

    final timeFilter = since == _epoch
        ? "1=1"
        : "${_updatedAtMillisExpr('updated_at')} > $sinceMillis";

    if (table == 'profiles') {
      return "SELECT * FROM profiles WHERE sync_id IS NOT NULL AND $timeFilter";
    }

    final tf = timeFilter.replaceAll('updated_at', 't.updated_at');

    switch (table) {
      case 'subject_groups':
      case 'goals':
        return "SELECT t.*, p.sync_id as profile_sync_id FROM $table t "
            "JOIN profiles p ON t.profile_id = p.id "
            "WHERE t.sync_id IS NOT NULL AND $tf";
      case 'subjects':
        return "SELECT t.*, p.sync_id as profile_sync_id, g.sync_id as group_sync_id "
            "FROM subjects t "
            "JOIN profiles p ON t.profile_id = p.id "
            "LEFT JOIN subject_groups g ON t.group_id = g.id "
            "WHERE t.sync_id IS NOT NULL AND $tf";
      case 'study_sessions':
        return "SELECT t.*, p.sync_id as profile_sync_id, s.sync_id as subject_sync_id "
            "FROM study_sessions t "
            "JOIN profiles p ON t.profile_id = p.id "
            "LEFT JOIN subjects s ON t.subject_id = s.id "
            "WHERE t.sync_id IS NOT NULL AND $tf";
      case 'session_tasks':
        return "SELECT t.*, p.sync_id as profile_sync_id, ss.sync_id as session_sync_id "
            "FROM session_tasks t "
            "JOIN profiles p ON t.profile_id = p.id "
            "JOIN study_sessions ss ON t.session_id = ss.id "
            "WHERE t.sync_id IS NOT NULL AND $tf";
      case 'mood_logs':
        return "SELECT t.*, p.sync_id as profile_sync_id, ss.sync_id as session_sync_id "
            "FROM mood_logs t "
            "JOIN profiles p ON t.profile_id = p.id "
            "LEFT JOIN study_sessions ss ON t.session_id = ss.id "
            "WHERE t.sync_id IS NOT NULL AND $tf";
      case 'ai_challenges':
        return "SELECT t.*, p.sync_id as profile_sync_id "
            "FROM ai_challenges t "
            "JOIN profiles p ON t.profile_id = p.id "
            "WHERE t.id IS NOT NULL AND $tf";
      default:
        return "SELECT t.*, p.sync_id as profile_sync_id FROM $table t "
            "JOIN profiles p ON t.profile_id = p.id "
            "WHERE t.sync_id IS NOT NULL AND $tf";
    }
  }

  // ── Apply payload ──────────────────────────────────────────────────────────

  static bool _isSyncing = false;
  static bool get isSyncing => _isSyncing;
  static set isSyncing(bool value) => _isSyncing = value;

  /// Apply an incoming sync payload idempotently.
  /// sync_id is the upsert key; updated_at is the conflict resolver.
  Future<SyncResult> applyPayload(SyncPayload payload, {String mergeMode = 'merge'}) async {
    _isSyncing = true;
    try {
      _logger.log('Engine', 'Applying payload', data: {
      'fromDevice': payload.deviceName,
      'fromDeviceId': payload.deviceId,
      'since': payload.sinceTimestamp,
      'tableCount': payload.tables.length,
    });
    int upserted = 0;
    int skipped = 0;
    int deferred = 0;
    final errors = <String>[];
    final myId = await getDeviceId();
    final legacyDefaultProfileSyncIds = <String>{};
    if (mergeMode == 'merge' && payload.deviceId != myId) {
      for (final profile in payload.tables['profiles'] ?? const <Map<String, dynamic>>[]) {
        final sourceId = int.tryParse('${profile['id']}');
        final syncId = (profile['sync_id'] as String?) ?? '';
        if (sourceId == 1 && syncId.isNotEmpty && syncId != 'profile-default') {
          legacyDefaultProfileSyncIds.add(syncId);
        }
      }
    }

    final updatedTables = <String>{};
    await _db.transaction(() async {
      for (final table in _syncTables) {
        final rows = payload.tables[table];
        if (rows == null || rows.isEmpty) continue;

        _logger.log('Engine', 'Applying table rows', data: {
          'table': table,
          'rows': rows.length,
        });
        var wroteInTable = false;
        for (final row in rows) {
          final rowKey = table == 'ai_challenges'
              ? row['id'] as String?
              : row['sync_id'] as String?;
          if (rowKey == null || rowKey.isEmpty) {
            skipped++;
            continue;
          }

          try {
            final r = await _upsertRow(table, row, payload, mergeMode, legacyDefaultProfileSyncIds);
            if (r == _UpsertOutcome.applied) {
              upserted++;
              wroteInTable = true;
            } else if (r == _UpsertOutcome.deferred) {
              deferred++;
            } else {
              skipped++;
            }
          } catch (e) {
            _logger.log('Engine', 'Row upsert failed', data: {
              'table': table,
              'syncId': rowKey,
              'error': '$e',
            });
            errors.add('$table/$rowKey: $e');
          }
        }

        if (wroteInTable) {
          updatedTables.add(table);
        }
      }
    });

    _logger.log('Engine', 'Payload apply complete', data: {
      'upserted': upserted,
      'skipped': skipped,
      'errors': errors.length,
    });

    // ── Stranded Profile Recovery ──
    // If a profile deletion was synced, the device's active profile might now be gone.
    // Find a fallback profile and update settings only. Never create profiles here.
    try {
      final activeProfileId = await _settings.getCurrentProfileId();
      final activeProfile = await (_db.select(_db.profiles)
            ..where((t) => t.id.equals(activeProfileId)))
          .getSingleOrNull();

      if (activeProfile == null || activeProfile.deletedAt != null) {
        _logger.log('Engine', 'Active profile is deleted or missing; attempting recovery', data: {
          'activeProfileId': activeProfileId,
        });

        final fallbackProfiles = await (_db.select(_db.profiles)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.id)])
              ..limit(1))
            .get();
        final fallbackProfile = fallbackProfiles.isNotEmpty ? fallbackProfiles.first : null;

        if (fallbackProfile != null) {
          await _settings.setCurrentProfileId(fallbackProfile.id);
          updatedTables.add('app_settings');
          updatedTables.add('profiles');
          _logger.log('Engine', 'Stranded profile recovery: adopted fallback', data: {
            'newProfileId': fallbackProfile.id,
            'newProfileName': fallbackProfile.name,
          });
        } else {
          _logger.log('Engine', 'Stranded profile recovery: no profiles exist', data: {
            'activeProfileId': activeProfileId,
          });
        }
      }
    } catch (e) {
      _logger.log('Engine', 'Stranded profile recovery failed', data: {
        'error': '$e',
      });
    }

    // Notify Drift of any recovery changes
    if (updatedTables.isNotEmpty) {
      _db.notifyUpdates(updatedTables.map((t) => TableUpdate(t)).toSet());
    }

    return SyncResult(
      inserted: upserted,
      updated: 0,
      skipped: skipped,
      deferred: deferred,
      errors: errors,
    );
    } finally {
      _isSyncing = false;
    }
  }

  /// Parses any timestamp (String ISO, String SQLite, Int seconds, Int millis) into Unix epoch milliseconds.
  int? _parseRowTimestamp(dynamic raw) {
    if (raw == null) return null;
    
    // Handle numeric types (SQLite integers)
    if (raw is num) {
      final val = raw.toInt();
      // If > 1e12, it's likely milliseconds. Otherwise, it's seconds.
      return val > 1000000000000 ? val : val * 1000;
    }
    
    final asString = raw.toString().trim();
    if (asString.isEmpty) return null;
    
    // Handle numeric strings
    final asNum = int.tryParse(asString);
    if (asNum != null) {
      return asNum > 1000000000000 ? asNum : asNum * 1000;
    }

    try {
      // Normalize SQLite "YYYY-MM-DD HH:MM:SS" to ISO "YYYY-MM-DDTHH:MM:SS"
      final normalized = asString.contains(' ') && !asString.contains('T')
          ? asString.replaceFirst(' ', 'T')
          : asString;
      
      return DateTime.parse(normalized).toUtc().millisecondsSinceEpoch;
    } catch (_) {
      return null;
    }
  }

  Future<void> initializeOwnership() async {
    final deviceId = await getDeviceId();
    await _db.customUpdate(
      "UPDATE profiles SET owner_device_id = ? "
      "WHERE (owner_device_id = '' OR owner_device_id IS NULL) AND sync_id != 'profile-default'",
      variables: [Variable<String>(deviceId)],
    );
    await _db.customUpdate(
      "UPDATE profiles SET owner_device_id = 'shared' WHERE sync_id = 'profile-default'",
    );
    _logger.log('Engine', 'Ownership initialized', data: {'deviceId': deviceId});
  }

  /// Parallel seeds / first sync can create the same display name under one profile with
  /// different sync_ids, tripping UNIQUE(profile_id, name). Merge by LWW into one row.
  Future<_NameDupMerge> _mergePerProfileNameDuplicate(String table, Map<String, dynamic> row) async {
    if (table != 'subjects' && table != 'subject_groups') return _NameDupMerge.proceed;
    final name = (row['name'] as String?)?.trim() ?? '';
    final incomingSyncId = row['sync_id'] as String? ?? '';
    final profileId = row['profile_id'] as int?;
    if (name.isEmpty || incomingSyncId.isEmpty || profileId == null) return _NameDupMerge.proceed;

    final rows = await _db.customSelect(
      'SELECT id, sync_id, updated_at FROM $table '
      'WHERE profile_id = ? AND name = ? AND (deleted_at IS NULL OR deleted_at = \'\')',
      variables: [Variable<int>(profileId), Variable<String>(name)],
    ).get();

    final others = rows.where((r) => r.data['sync_id']?.toString() != incomingSyncId).toList();
    if (others.isEmpty) return _NameDupMerge.proceed;

    final incomingMs = _parseRowTimestamp(row['updated_at']);
    var maxLocalMs = -9223372036854775808;
    for (final r in others) {
      final ms = _parseRowTimestamp(r.data['updated_at']);
      if (ms != null && ms > maxLocalMs) maxLocalMs = ms;
    }

    if (incomingMs == null || incomingMs <= maxLocalMs) {
      return _NameDupMerge.skipIncoming;
    }

    var winner = others.first;
    var winnerMs = _parseRowTimestamp(winner.data['updated_at']) ?? -9223372036854775808;
    for (final r in others) {
      final ms = _parseRowTimestamp(r.data['updated_at']) ?? -9223372036854775808;
      if (ms > winnerMs) {
        winnerMs = ms;
        winner = r;
      }
    }

    final winnerId = winner.data['id'] as int;
    final tomb = DateTime.now().toUtc().toIso8601String();

    final orphanRows = await _db.customSelect(
      'SELECT id FROM $table WHERE sync_id = ? AND id != ? LIMIT 1',
      variables: [Variable<String>(incomingSyncId), Variable<int>(winnerId)],
    ).get();
    if (orphanRows.isNotEmpty) {
      final oid = orphanRows.first.data['id'] as int;
      await _db.customStatement('UPDATE $table SET deleted_at = ? WHERE id = ?', [tomb, oid]);
    }

    for (final r in others) {
      final id = r.data['id'] as int;
      if (id != winnerId) {
        await _db.customStatement('UPDATE $table SET deleted_at = ? WHERE id = ?', [tomb, id]);
      }
    }

    if (table == 'subjects') {
      await _db.customStatement(
        'UPDATE subjects SET sync_id = ?, color = ?, group_id = ?, updated_at = ?, '
        'deleted_at = ?, created_at = COALESCE(?, created_at) WHERE id = ?',
        [
          incomingSyncId,
          row['color'],
          row['group_id'],
          row['updated_at'],
          row['deleted_at'],
          row['created_at'],
          winnerId,
        ],
      );
    } else {
      await _db.customStatement(
        'UPDATE subject_groups SET sync_id = ?, color = ?, updated_at = ?, '
        'deleted_at = ?, created_at = COALESCE(?, created_at) WHERE id = ?',
        [
          incomingSyncId,
          row['color'],
          row['updated_at'],
          row['deleted_at'],
          row['created_at'],
          winnerId,
        ],
      );
    }

    return _NameDupMerge.mergedDone;
  }

  Future<_UpsertOutcome> _upsertRow(
    String table,
    Map<String, dynamic> row,
    SyncPayload payload,
    String mergeMode,
    Set<String> legacyDefaultProfileSyncIds,
  ) async {
    final myId = await getDeviceId();
    final work = Map<String, dynamic>.from(row);
    final isAi = table == 'ai_challenges';

    if (table == 'profiles' && work['sync_id'] == 'profile-default' && work['deleted_at'] != null) {
      return _UpsertOutcome.skipped;
    }

    if (table == 'profiles' &&
        work['sync_id'] == 'profile-default' &&
        mergeMode == 'separate' &&
        payload.deviceId != myId) {
      work['sync_id'] = 'profile-default-${payload.deviceId}';
      work['name'] = "${payload.deviceName}'s Profile";
    }

    if (table == 'profiles' && mergeMode == 'merge') {
      final syncId = work['sync_id'] as String? ?? '';
      if (legacyDefaultProfileSyncIds.contains(syncId)) {
        work['sync_id'] = 'profile-default';
      }
    }

    // Offline add wins: suppress remote tombstone if local child data is newer
    // than our last Wi‑Fi sync with this peer (or newer than tombstone if no row).
    final pIncoming = work['sync_id'] as String? ?? '';
    if (table == 'profiles' &&
        work['deleted_at'] != null &&
        pIncoming != 'profile-default' &&
        payload.deviceId != myId) {
      final localProf = await (_db.select(_db.profiles)..where((t) => t.syncId.equals(pIncoming)))
          .getSingleOrNull();
      if (localProf != null) {
        final offline = await _profileHasOfflineAddsSincePeerBaseline(
          localProf.id,
          payload.deviceId,
          work['updated_at'],
        );
        if (offline) {
          _logger.log('Engine', 'Offline activity after last Wi‑Fi sync — resurrecting profile; remote delete suppressed', data: {
            'syncId': pIncoming,
            'peer': payload.deviceId,
          });
          work['deleted_at'] = null;
          work['updated_at'] = DateTime.now().millisecondsSinceEpoch;
        }
      }
    }

    final key = isAi
        ? (work['id'] as String? ?? '')
        : (work['sync_id'] as String? ?? '');
    if (key.isEmpty) return _UpsertOutcome.skipped;

    if (!isAi) {
      work.remove('id');
    }

    // --- LWW: existing row ---
    final existing = await _db.customSelect(
      isAi
          ? 'SELECT updated_at FROM $table WHERE id = ? LIMIT 1'
          : 'SELECT updated_at FROM $table WHERE sync_id = ? LIMIT 1',
      variables: [Variable<String>(key)],
    ).getSingleOrNull();

    if (existing != null) {
      final localMs = _parseRowTimestamp(existing.data['updated_at']);
      final incomingMs = _parseRowTimestamp(work['updated_at']);
      if (localMs != null && incomingMs != null) {
        if (incomingMs <= localMs) {
          return _UpsertOutcome.skipped;
        }
      }
    }

    var adoptedProfile = false;
    // Same rule as desktop: adopt empty singleton → `profile-default` only, never for other sync_ids.
    if (table == 'profiles' && existing == null && mergeMode == 'merge') {
      final pSync = work['sync_id'] as String? ?? '';
      if (pSync == 'profile-default' &&
          pSync.isNotEmpty &&
          pSync != 'profile-default-${payload.deviceId}') {
        final localProfiles = await (_db.select(_db.profiles)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.id)]))
            .get();
        if (localProfiles.length == 1) {
          final local = localProfiles.first;
          if (await _isLocalProfileEmptyForAdoption(local.id)) {
            await (_db.update(_db.profiles)..where((t) => t.id.equals(local.id)))
                .write(ProfilesCompanion(syncId: Value(pSync)));
            adoptedProfile = true;
            final adopted = await _db.customSelect(
              'SELECT updated_at FROM profiles WHERE sync_id = ? LIMIT 1',
              variables: [Variable<String>(pSync)],
            ).getSingleOrNull();
            if (adopted != null) {
              final a = _parseRowTimestamp(adopted.data['updated_at']);
              final b = _parseRowTimestamp(work['updated_at']);
              if (a != null && b != null && b <= a) {
                return _UpsertOutcome.skipped;
              }
            }
          }
        }
      }
    }

    if (table != 'profiles' && work.containsKey('profile_sync_id')) {
      var ps = work['profile_sync_id'] as String;
      if (mergeMode == 'merge' && legacyDefaultProfileSyncIds.contains(ps)) {
        ps = 'profile-default';
      }
      if (mergeMode == 'separate' && payload.deviceId != myId && ps == 'profile-default') {
        ps = 'profile-default-${payload.deviceId}';
      }
      final pr = await (_db.select(_db.profiles)..where((t) => t.syncId.equals(ps))).getSingleOrNull();
      if (pr == null) {
        return _UpsertOutcome.skipped;
      }
      work['profile_id'] = pr.id;
      work.remove('profile_sync_id');
    } else if (table != 'profiles') {
      work['profile_id'] = await _settings.getCurrentProfileId();
      work.remove('profile_sync_id');
    }

    if (table == 'study_sessions') {
      final ss = work['subject_sync_id'] as String?;
      if (ss != null && ss.isNotEmpty) {
        final sub = await (_db.select(_db.subjects)..where((t) => t.syncId.equals(ss))).getSingleOrNull();
        if (sub != null) {
          work['subject_id'] = sub.id;
        } else {
          work['subject_id'] = null;
        }
      }
      work.remove('subject_sync_id');
    } else {
      work.remove('subject_sync_id');
    }

    if (table == 'subjects') {
      final groupSyncId = work['group_sync_id'] as String?;
      if (groupSyncId != null && groupSyncId.isNotEmpty) {
        final group = await (_db.select(_db.subjectGroups)..where((t) => t.syncId.equals(groupSyncId)))
            .getSingleOrNull();
        work['group_id'] = group?.id;
      } else {
        work['group_id'] = null;
      }
      work.remove('group_sync_id');
    } else {
      work.remove('group_sync_id');
    }

    if (table == 'subjects' || table == 'subject_groups') {
      final dup = await _mergePerProfileNameDuplicate(table, work);
      if (dup == _NameDupMerge.skipIncoming) return _UpsertOutcome.skipped;
      if (dup == _NameDupMerge.mergedDone) return _UpsertOutcome.applied;
    }

    if (table == 'session_tasks' || table == 'mood_logs') {
      final sessId = work['session_sync_id'] as String?;
      if (sessId != null && sessId.isNotEmpty) {
        final ses = await (_db.select(_db.studySessions)..where((t) => t.syncId.equals(sessId)))
            .getSingleOrNull();
        if (ses == null) {
          return _UpsertOutcome.deferred;
        }
        work['session_id'] = ses.id;
      }
      work.remove('session_sync_id');
    } else {
      work.remove('session_sync_id');
    }

    if (table == 'profiles' && (existing != null || adoptedProfile)) {
      work.remove('owner_device_id');
    }

    final rowToUpsert = work;
    final cols = rowToUpsert.keys.toList();
    final placeholders = List.generate(cols.length, (i) => '?').join(', ');
    final values = cols.map((c) {
      var v = rowToUpsert[c];
      if ((c == 'created_at' || c == 'updated_at' || c == 'synced_at') && v is String) {
        try {
          final dt = DateTime.parse(v.toString().contains(' ') ? v.toString().replaceFirst(' ', 'T') : v.toString());
          v = dt.millisecondsSinceEpoch;
        } catch (_) {
          v = DateTime.now().millisecondsSinceEpoch;
        }
      }
      if (v is bool) return v ? 1 : 0;
      return v;
    }).toList();

    final updateCols = cols
        .where(
          (c) =>
              c != 'id' &&
              c != 'sync_id' &&
              c != 'created_at' &&
              (table != 'profiles' || c != 'owner_device_id') &&
              (table != 'ai_challenges' || c != 'id'),
        )
        .toList();
    final updateClause = updateCols.map((c) => "$c = excluded.$c").join(', ');

    final conflict = isAi ? 'id' : 'sync_id';
    await _db.customStatement(
      'INSERT INTO $table (${cols.join(', ')}) VALUES ($placeholders) '
      'ON CONFLICT($conflict) DO UPDATE SET $updateClause',
      values,
    );

    if (table == 'profiles' && work['deleted_at'] != null && (work['sync_id'] as String? ?? '') != 'profile-default') {
      final psid = work['sync_id'] as String;
      final pr = await (_db.select(_db.profiles)..where((t) => t.syncId.equals(psid))).getSingleOrNull();
      if (pr != null) {
        final pid = pr.id;
        await _db.customStatement(
          'DELETE FROM session_tasks WHERE session_id IN (SELECT id FROM study_sessions WHERE profile_id = ?)',
          [pid],
        );
        await _db.customStatement('DELETE FROM mood_logs WHERE profile_id = ?', [pid]);
        await _db.customStatement('DELETE FROM session_tasks WHERE profile_id = ?', [pid]);
        await _db.customStatement('DELETE FROM study_sessions WHERE profile_id = ?', [pid]);
        await _db.customStatement('DELETE FROM subjects WHERE profile_id = ?', [pid]);
        await _db.customStatement('DELETE FROM subject_groups WHERE profile_id = ?', [pid]);
        await _db.customStatement('DELETE FROM goals WHERE profile_id = ?', [pid]);
        await _db.customStatement('DELETE FROM ai_challenges WHERE profile_id = ?', [pid]);
      }
    }

    return _UpsertOutcome.applied;
  }

  Future<bool> _isLocalProfileEmptyForAdoption(int localProfileId) async {
    final a = (await _db.customSelect(
      'SELECT COUNT(*) as c FROM study_sessions WHERE profile_id = ?',
      variables: [Variable<int>(localProfileId)],
    ).getSingle()).data['c'] as int? ?? 0;
    final b = (await _db.customSelect(
      'SELECT COUNT(*) as c FROM subjects WHERE profile_id = ?',
      variables: [Variable<int>(localProfileId)],
    ).getSingle()).data['c'] as int? ?? 0;
    final c = (await _db.customSelect(
      'SELECT COUNT(*) as c FROM goals WHERE profile_id = ?',
      variables: [Variable<int>(localProfileId)],
    ).getSingle()).data['c'] as int? ?? 0;
    final d = (await _db.customSelect(
      'SELECT COUNT(*) as c FROM mood_logs WHERE profile_id = ?',
      variables: [Variable<int>(localProfileId)],
    ).getSingle()).data['c'] as int? ?? 0;
    return a + b + c + d == 0;
  }

  /// Max `updated_at` (epoch ms) among active child rows for a profile.
  Future<int?> _maxChildUpdatedMsForProfile(int profileId) async {
    const tablesWithDeletedAt = [
      'study_sessions',
      'subjects',
      'subject_groups',
      'goals',
      'mood_logs',
      'session_tasks',
    ];
    // ai_challenges has no deleted_at column (see tables.dart).
    const tablesWithoutDeletedAt = {'ai_challenges'};
    final tables = [...tablesWithDeletedAt, ...tablesWithoutDeletedAt];
    int? max;
    for (final t in tables) {
      final whereDeleted = tablesWithoutDeletedAt.contains(t)
          ? 'profile_id = ?'
          : 'profile_id = ? AND (deleted_at IS NULL OR deleted_at = \'\')';
      final row = await _db.customSelect(
        'SELECT MAX(updated_at) as m FROM $t WHERE $whereDeleted',
        variables: [Variable<int>(profileId)],
      ).getSingleOrNull();
      if (row == null) continue;
      final ms = _parseRowTimestamp(row.data['m']);
      if (ms != null && (max == null || ms > max)) max = ms;
    }
    return max;
  }

  /// Child data edited after last Wi‑Fi sync with peer, or after remote tombstone
  /// if we have no prior Wi‑Fi sync row for that peer.
  Future<bool> _profileHasOfflineAddsSincePeerBaseline(
    int localProfileId,
    String peerDeviceId,
    dynamic remoteTombstoneUpdatedAt,
  ) async {
    final maxChildMs = await _maxChildUpdatedMsForProfile(localProfileId);
    if (maxChildMs == null) return false;

    final lastWifi = await getLastSyncedAt(peerDeviceId, 'wifi');
    if (lastWifi != null && lastWifi.isNotEmpty) {
      final baselineMs = _parseRowTimestamp(lastWifi);
      if (baselineMs != null) {
        return maxChildMs > baselineMs;
      }
    }
    final tombMs = _parseRowTimestamp(remoteTombstoneUpdatedAt);
    if (tombMs != null) {
      return maxChildMs >= tombMs;
    }
    return false;
  }

  // ── Sync state tracking ────────────────────────────────────────────────────

  Future<String?> getLastSyncedAt(String peerDeviceId, String transport) async {
    final rows = await (_db.select(_db.syncState)
          ..where((t) =>
              t.peerDeviceId.equals(peerDeviceId) & t.transport.equals(transport)))
        .get();
    _logger.log('Engine', 'Read last synced state', data: {
      'peerDeviceId': peerDeviceId,
      'transport': transport,
      'found': rows.isNotEmpty,
      'lastSyncedAt': rows.firstOrNull?.lastSyncedAt,
    });
    return rows.firstOrNull?.lastSyncedAt;
  }

  Future<void> updateSyncState({
    required String peerDeviceId,
    required String transport,
    required String direction,
    required int rowCount,
    bool clear = false,
  }) async {
    SyncTrigger.instance.suppress();
    try {
      if (clear) {
        await (_db.delete(_db.syncState)
              ..where((t) => t.peerDeviceId.equals(peerDeviceId) & t.transport.equals(transport)))
            .go();
        _logger.log('Engine', 'Sync state cleared', data: {
          'peerDeviceId': peerDeviceId,
          'transport': transport,
        });
        return;
      }

      final now = DateTime.now().toUtc().toIso8601String();
      await _db.into(_db.syncState).insert(
            SyncStateCompanion.insert(
              peerDeviceId: peerDeviceId,
              transport: transport,
              lastSyncedAt: Value(now),
              lastSyncDirection: Value(direction),
              lastRowCount: Value(rowCount),
            ),
            mode: InsertMode.insertOrReplace,
          );
      _logger.log('Engine', 'Sync state updated', data: {
        'peerDeviceId': peerDeviceId,
        'transport': transport,
        'direction': direction,
        'rowCount': rowCount,
        'timestamp': now,
      });
    } finally {
      SyncTrigger.instance.unsuppress();
    }
  }

  Future<void> recordHistory(SyncHistoryEntry entry) async {
    // T11: Skip recording history for successful empty syncs to prevent log spam
    if (entry.success && entry.rowsSent == 0 && entry.rowsReceived == 0) {
      return;
    }

    SyncTrigger.instance.suppress();
    try {
      await _db.into(_db.syncHistory).insert(
            SyncHistoryCompanion.insert(
              peerDeviceId: Value(entry.peerDeviceId),
              peerDeviceName: Value(entry.peerDeviceName),
              transport: entry.transport,
              direction: entry.direction,
              rowsSent: Value(entry.rowsSent),
              rowsReceived: Value(entry.rowsReceived),
              success: Value(entry.success),
              errorMessage: Value(entry.errorMessage),
            ),
          );
      _logger.log('Engine', 'History recorded', data: {
        'peerDeviceId': entry.peerDeviceId,
        'peerDeviceName': entry.peerDeviceName,
        'transport': entry.transport,
        'direction': entry.direction,
        'rowsSent': entry.rowsSent,
        'rowsReceived': entry.rowsReceived,
        'success': entry.success,
        'error': entry.errorMessage,
      });
    } finally {
      SyncTrigger.instance.unsuppress();
    }
  }

  Future<List<SyncHistoryData>> getHistory({int limit = 20}) async {
    final rows = await (_db.select(_db.syncHistory)
          ..orderBy([(t) => OrderingTerm.desc(t.syncedAt)])
          ..limit(limit))
        .get();
    return rows;
  }

  /// Returns the count of local rows updated since the last successful sync with any peer.
  Future<int> getUnsyncedCount() async {
    try {
      final stateRow = await (_db.select(_db.syncState)
            ..orderBy([(t) => OrderingTerm.desc(t.lastSyncedAt)])
            ..limit(1))
          .getSingleOrNull();

      final lastSyncedAt = stateRow?.lastSyncedAt;
      final since = clampTimestamp(lastSyncedAt);
      _logger.log('Engine', 'Calculating unsynced count', data: {'since': since});
      final bufferSince = since == _epoch 
          ? _epoch 
          : DateTime.parse(since).subtract(const Duration(seconds: 1)).toUtc().toIso8601String();
      final sinceMillis = DateTime.parse(bufferSince).toUtc().millisecondsSinceEpoch;

      int totalUnsynced = 0;
      final profileId = await _settings.getCurrentProfileId();

      for (final table in _syncTables) {
        if (table == 'ai_challenges') {
          final r = await _db.customSelect(
            "SELECT COUNT(*) as count FROM ai_challenges WHERE id IS NOT NULL "
            "AND ${_updatedAtMillisExpr('updated_at')} > $sinceMillis "
            "AND profile_id = $profileId",
          ).getSingle();
          totalUnsynced += r.data['count'] as int;
          continue;
        }
        if (table == 'profiles') {
          final r = await _db.customSelect(
            "SELECT COUNT(*) as count FROM profiles WHERE sync_id IS NOT NULL "
            "AND ${_updatedAtMillisExpr('updated_at')} > $sinceMillis",
          ).getSingle();
          totalUnsynced += r.data['count'] as int;
          continue;
        }
        final query = "SELECT COUNT(*) as count FROM $table "
            "WHERE sync_id IS NOT NULL "
            "AND ${_updatedAtMillisExpr('updated_at')} > $sinceMillis "
            "AND profile_id = $profileId";
        final result = await _db.customSelect(query).getSingle();
        totalUnsynced += result.data['count'] as int;
      }

      return totalUnsynced;
    } catch (e) {
      _logger.log('Engine', 'Failed to calculate unsynced count', data: {'error': e.toString()});
      return 0;
    }
  }


  // ── Helpers ────────────────────────────────────────────────────────────────

  static SyncPayload deserializePayload(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    
    // If this is a wrapped response (from Desktop server), unwrap it
    if (data.containsKey('payload') && data['payload'] is String && (data['payload'] as String).isNotEmpty) {
      final innerJson = data['payload'] as String;
      final innerData = jsonDecode(innerJson) as Map<String, dynamic>;
      // Merge metadata from wrapper if missing in inner
      innerData['device_id'] ??= data['device_id'];
      innerData['device_name'] ??= data['device_name'];
      return SyncPayload.fromJson(innerData);
    }
    
    // Robust version parsing
    final versionRaw = data['version'] ?? data['payload_version'] ?? 1;
    final version = versionRaw is num 
        ? versionRaw.toInt() 
        : (int.tryParse(versionRaw.toString()) ?? 1);
    
    if (version != 1) {
      throw Exception('Unsupported payload version: $version');
    }
    return SyncPayload.fromJson(data);
  }

  static int countRows(SyncPayload payload) =>
      payload.tables.values.fold(0, (acc, rows) => acc + rows.length);

  static String clampTimestamp(String? ts) {
    if (ts == null || ts.isEmpty) return _epoch;
    
    // Normalize SQLite space format
    final trimmed = ts.trim();
    final normalized = trimmed.contains(' ') && !trimmed.contains('T') 
        ? trimmed.replaceFirst(' ', 'T') 
        : trimmed;
    
    try {
      return DateTime.parse(normalized).toUtc().toIso8601String();
    } catch (_) {
      return _epoch;
    }
  }

  static String formatSyncTime(DateTime? dt) {
    if (dt == null) return 'Never';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.month}/${dt.day}';
  }

  static String generatePairingCode() =>
      (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
}
