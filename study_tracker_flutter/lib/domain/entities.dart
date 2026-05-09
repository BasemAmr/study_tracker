import 'dart:convert';

import 'enums.dart';

/// A single study session — the core entity of the app.
class StudySession {
  final int? id;
  final DateTime startAt;
  final DateTime endAt;
  final int durationMinutes;
  final int? subjectId;
  final String? subjectName;
  final String? topic;
  final String? chapterTag;
  final String? mood;
  final String? notes;
  final StudySessionMode mode;
  final int breakMinutes;
  final String? backgroundImage;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<SessionTask> tasks;

  const StudySession({
    this.id,
    required this.startAt,
    required this.endAt,
    required this.durationMinutes,
    this.subjectId,
    this.subjectName,
    this.topic,
    this.chapterTag,
    this.mood,
    this.notes,
    required this.mode,
    this.breakMinutes = 0,
    this.backgroundImage,
    this.createdAt,
    this.updatedAt,
    this.tasks = const [],
  });

  StudySession copyWith({
    int? id,
    DateTime? startAt,
    DateTime? endAt,
    int? durationMinutes,
    int? subjectId,
    String? subjectName,
    String? topic,
    String? chapterTag,
    String? mood,
    String? notes,
    StudySessionMode? mode,
    int? breakMinutes,
    String? backgroundImage,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<SessionTask>? tasks,
  }) {
    return StudySession(
      id: id ?? this.id,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      subjectId: subjectId ?? this.subjectId,
      subjectName: subjectName ?? this.subjectName,
      topic: topic ?? this.topic,
      chapterTag: chapterTag ?? this.chapterTag,
      mood: mood ?? this.mood,
      notes: notes ?? this.notes,
      mode: mode ?? this.mode,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      backgroundImage: backgroundImage ?? this.backgroundImage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tasks: tasks ?? this.tasks,
    );
  }
}

/// A task within a session.
class SessionTask {
  final int? id;
  final int? sessionId;
  final String title;
  final bool completed;
  final DateTime? createdAt;

  const SessionTask({
    this.id,
    this.sessionId,
    required this.title,
    this.completed = false,
    this.createdAt,
  });

  SessionTask copyWith({
    int? id,
    int? sessionId,
    String? title,
    bool? completed,
    DateTime? createdAt,
  }) {
    return SessionTask(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// A subject (course / topic area).
class Subject {
  final int? id;
  final String name;
  final String? color;
  final int? groupId;
  final DateTime? createdAt;

  const Subject({
    this.id,
    required this.name,
    this.color,
    this.groupId,
    this.createdAt,
  });

  Subject copyWith({
    int? id,
    String? name,
    String? color,
    int? groupId,
    DateTime? createdAt,
  }) {
    return Subject(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      groupId: groupId ?? this.groupId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// A group of related subjects.
class SubjectGroup {
  final int? id;
  final String name;
  final String? color;
  final DateTime? createdAt;

  const SubjectGroup({
    this.id,
    required this.name,
    this.color,
    this.createdAt,
  });
}

/// Sentinel `owner_device_id` for [syncId] `profile-default` — not a real device UUID (LAN sync spec).
const kProfileOwnerSharedSentinel = 'shared';

/// A local scholar profile.
class Profile {
  final int? id;
  final String? syncId;
  final String name;
  final String academicLevel;
  final String? ownerDeviceId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Profile({
    this.id,
    this.syncId,
    required this.name,
    required this.academicLevel,
    this.ownerDeviceId,
    this.createdAt,
    this.updatedAt,
  });

  Profile copyWith({
    int? id,
    String? syncId,
    String? name,
    String? academicLevel,
    String? ownerDeviceId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Profile(
      id: id ?? this.id,
      syncId: syncId ?? this.syncId,
      name: name ?? this.name,
      academicLevel: academicLevel ?? this.academicLevel,
      ownerDeviceId: ownerDeviceId ?? this.ownerDeviceId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

extension ProfileOwnershipDisplay on Profile {
  String ownershipBadge(String syncDeviceId) {
    final od = ownerDeviceId?.trim();
    if (od == kProfileOwnerSharedSentinel) return 'SHARED';
    if (od == null || od.isEmpty || od == syncDeviceId) return 'MY DEVICE';
    return 'SYNCED';
  }
}

/// Subjects organized by group.
class GroupedSubjects {
  final SubjectGroup? group;
  final List<Subject> subjects;

  const GroupedSubjects({
    this.group,
    required this.subjects,
  });
}

/// A study goal.
class Goal {
  final int? id;
  final String name;
  final int targetMinutes;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Goal({
    this.id,
    required this.name,
    required this.targetMinutes,
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });
}

/// A mood log entry.
class MoodLog {
  final int? id;
  final int? sessionId;
  final String mood;
  final String? note;
  final DateTime? createdAt;

  const MoodLog({
    this.id,
    this.sessionId,
    required this.mood,
    this.note,
    this.createdAt,
  });
}

/// Multi-progress mission sub-targets (`sub_targets_json` on disk).
class AiMissionSubTargets {
  final String mode;
  final int count;
  final int? minutesPerSubject;

  const AiMissionSubTargets({
    required this.mode,
    required this.count,
    this.minutesPerSubject,
  });

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'count': count,
        if (minutesPerSubject != null) 'minutesPerSubject': minutesPerSubject,
      };

  String toJsonString() => jsonEncode(toJson());

  static AiMissionSubTargets? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>?;
      if (m == null) return null;
      final mode = m['mode'] as String?;
      final count = m['count'];
      if (mode == null || count is! num) return null;
      final mps = m['minutesPerSubject'];
      return AiMissionSubTargets(
        mode: mode,
        count: count.toInt(),
        minutesPerSubject: mps is num ? mps.toInt() : null,
      );
    } catch (_) {
      return null;
    }
  }
}

/// An AI-generated challenge.
class AiChallenge {
  final String id;
  final AiChallengeTier tier;
  final String title;
  final String description;
  final String icon;
  final AiChallengeMetric metric;
  final int target;
  final DateTime expiresAt;
  final AiChallengeDifficulty difficulty;
  final String rewardBadgeName;
  final String rewardBadgeIcon;
  final bool completed;
  final String? rawResponse;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final AiMissionSubTargets? subTargets;
  final int? unitMinMinutes;
  final AiChallengeStatus status;

  const AiChallenge({
    required this.id,
    required this.tier,
    required this.title,
    required this.description,
    required this.icon,
    required this.metric,
    required this.target,
    required this.expiresAt,
    required this.difficulty,
    required this.rewardBadgeName,
    required this.rewardBadgeIcon,
    this.completed = false,
    this.rawResponse,
    this.createdAt,
    this.updatedAt,
    this.subTargets,
    this.unitMinMinutes,
    this.status = AiChallengeStatus.active,
  });
}

/// Closed AI mission snapshot (local-only).
class AiChallengeHistoryEntry {
  final int id;
  final int profileId;
  final AiChallengeTier tier;
  final String title;
  final String description;
  final AiChallengeMetric metric;
  final int target;
  final int progressAtClose;
  final AiChallengeCloseReason closeReason;
  final String closedAt;
  final String originalCreatedAt;
  final String originalExpiresAt;
  final AiMissionSubTargets? subTargets;
  final int? unitMinMinutes;

  const AiChallengeHistoryEntry({
    required this.id,
    required this.profileId,
    required this.tier,
    required this.title,
    required this.description,
    required this.metric,
    required this.target,
    required this.progressAtClose,
    required this.closeReason,
    required this.closedAt,
    required this.originalCreatedAt,
    required this.originalExpiresAt,
    this.subTargets,
    this.unitMinMinutes,
  });
}

/// Insert payload for [AiChallengeHistoryRepository.create] (no database id yet).
class NewAiChallengeHistoryEntry {
  final int profileId;
  final AiChallengeTier tier;
  final String title;
  final String description;
  final AiChallengeMetric metric;
  final int target;
  final int progressAtClose;
  final AiChallengeCloseReason closeReason;
  final String closedAt;
  final String originalCreatedAt;
  final String originalExpiresAt;
  final AiMissionSubTargets? subTargets;
  final int? unitMinMinutes;

  const NewAiChallengeHistoryEntry({
    required this.profileId,
    required this.tier,
    required this.title,
    required this.description,
    required this.metric,
    required this.target,
    required this.progressAtClose,
    required this.closeReason,
    required this.closedAt,
    required this.originalCreatedAt,
    required this.originalExpiresAt,
    this.subTargets,
    this.unitMinMinutes,
  });
}

class AppSetting {
  final String key;
  final String value;
  final DateTime? updatedAt;

  const AppSetting({
    required this.key,
    required this.value,
    this.updatedAt,
  });
}


/// Structured settings object parsed from key-value store.
class StructuredSettings {
  final int dailyGoalMinutes;
  final int focusMinutes;
  final int breakMinutes;
  final AppThemeMode themeMode;
  final StudySessionMode defaultSessionMode;
  final String? defaultBackground;
  final double? overlayOpacity;
  final int? overlayHue;
  final String? displayName;
  final String? academicLevel;
  final String languageCode;
  final bool aiChallengesEnabled;
  final String? groqApiKey;
  final bool isFocusAudioEnabled;
  final double focusAudioVolume;
  final bool wifiSyncEnabled;
  final String syncDeviceId;

  const StructuredSettings({
    this.dailyGoalMinutes = 120,
    this.focusMinutes = 25,
    this.breakMinutes = 5,
    this.themeMode = AppThemeMode.light,
    this.defaultSessionMode = StudySessionMode.pomodoro,
    this.defaultBackground,
    this.overlayOpacity,
    this.overlayHue,
    this.displayName,
    this.academicLevel,
    this.languageCode = 'en',
    this.aiChallengesEnabled = false,
    this.groqApiKey,
    this.isFocusAudioEnabled = false,
    this.focusAudioVolume = 0.5,
    this.wifiSyncEnabled = false,
    this.syncDeviceId = '',
  });

  StructuredSettings copyWith({
    int? dailyGoalMinutes,
    int? focusMinutes,
    int? breakMinutes,
    AppThemeMode? themeMode,
    StudySessionMode? defaultSessionMode,
    String? defaultBackground,
    double? overlayOpacity,
    int? overlayHue,
    String? displayName,
    String? academicLevel,
    String? languageCode,
    bool? aiChallengesEnabled,
    String? groqApiKey,
    bool? isFocusAudioEnabled,
    double? focusAudioVolume,
    bool? wifiSyncEnabled,
    String? syncDeviceId,
  }) {
    return StructuredSettings(
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      focusMinutes: focusMinutes ?? this.focusMinutes,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      themeMode: themeMode ?? this.themeMode,
      defaultSessionMode: defaultSessionMode ?? this.defaultSessionMode,
      defaultBackground: defaultBackground ?? this.defaultBackground,
      overlayOpacity: overlayOpacity ?? this.overlayOpacity,
      overlayHue: overlayHue ?? this.overlayHue,
      displayName: displayName ?? this.displayName,
      academicLevel: academicLevel ?? this.academicLevel,
      languageCode: languageCode ?? this.languageCode,
      aiChallengesEnabled: aiChallengesEnabled ?? this.aiChallengesEnabled,
      groqApiKey: groqApiKey ?? this.groqApiKey,
      isFocusAudioEnabled: isFocusAudioEnabled ?? this.isFocusAudioEnabled,
      focusAudioVolume: focusAudioVolume ?? this.focusAudioVolume,
      wifiSyncEnabled: wifiSyncEnabled ?? this.wifiSyncEnabled,
      syncDeviceId: syncDeviceId ?? this.syncDeviceId,
    );
  }
}

/// Filter for querying sessions.
class SessionFilter {
  final int? subjectId;
  final int? groupId;
  final StudySessionMode? mode;
  final DateTime? startFrom;
  final DateTime? startTo;
  final int limit;
  final int offset;
  final String? query;

  const SessionFilter({
    this.subjectId,
    this.groupId,
    this.mode,
    this.startFrom,
    this.startTo,
    this.limit = 50,
    this.offset = 0,
    this.query,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionFilter &&
        other.subjectId == subjectId &&
        other.groupId == groupId &&
        other.mode == mode &&
        _sameDate(other.startFrom, startFrom) &&
        _sameDate(other.startTo, startTo) &&
        other.limit == limit &&
        other.offset == offset &&
        other.query == query;
  }

  @override
  int get hashCode {
    return Object.hash(
      subjectId,
      groupId,
      mode,
      startFrom?.millisecondsSinceEpoch,
      startTo?.millisecondsSinceEpoch,
      limit,
      offset,
      query,
    );
  }

  static bool _sameDate(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.millisecondsSinceEpoch == b.millisecondsSinceEpoch;
  }
}

/// Summary statistics.
class SessionSummary {
  final int totalSessions;
  final int totalMinutes;
  final double averageMinutes;
  final List<StudySession> recentSessions;

  const SessionSummary({
    this.totalSessions = 0,
    this.totalMinutes = 0,
    this.averageMinutes = 0,
    this.recentSessions = const [],
  });
}
