export type StudySessionMode = 'pomodoro' | 'long_session' | 'manual';

export type ThemeMode = 'light' | 'dark' | 'system';

export type Language = 'en';

export type AppSettingValue = string | number | boolean;

export type SessionTask = {
  id?: number;
  sessionId?: number;
  title: string;
  completed: boolean;
  createdAt?: string;
};

export type StudySession = {
  id?: number;
  startAt: string;
  endAt: string;
  durationMinutes: number;
  subjectId?: number | null;
  subjectName?: string | null;
  topic?: string | null;
  chapterTag?: string | null;
  mood?: string | null;
  notes?: string | null;
  mode: StudySessionMode;
  breakMinutes?: number;
  backgroundImage?: string | null;
  createdAt?: string;
  updatedAt?: string;
  tasks?: SessionTask[];
};

export type SubjectGroup = {
  id?: number;
  name: string;
  color?: string | null;
  createdAt?: string;
};

export type Subject = {
  id?: number;
  name: string;
  color?: string | null;
  groupId?: number | null;
  difficultyLevel?: number | null;
  createdAt?: string;
};

export type GroupedSubjects = {
  group: SubjectGroup | null;
  subjects: Subject[];
};

export type Profile = {
  id?: number;
  syncId?: string;
  name: string;
  academicLevel?: string;
  ownerDeviceId?: string;
  createdAt?: string;
  updatedAt?: string;
};

export type AppSetting = {
  key: string;
  value: string;
  updatedAt?: string;
};

export type Goal = {
  id?: number;
  name: string;
  targetMinutes: number;
  active: boolean;
  createdAt?: string;
  updatedAt?: string;
};

export type MoodLog = {
  id?: number;
  sessionId?: number | null;
  mood: string;
  note?: string | null;
  createdAt?: string;
};

export type AiChallengeMetric = 'sessions' | 'minutes' | 'streak' | 'subjects' | 'pomodoros';
export type AiChallengeTier = 'daily' | 'weekly' | 'monthly' | 'surprise';
export type AiChallengeDifficulty = 'easy' | 'medium' | 'hard' | 'extreme';
export type AiChallengeStatus = 'active' | 'completed' | 'expired' | 'replaced';

/** Shape stored in ai_challenges.sub_targets_json for multi-progress missions. */
export type AiMissionSubTargets = {
  mode: string;
  count: number;
  minutesPerSubject?: number;
};

export type AiChallengeCloseReason = 'replaced' | 'expired' | 'completed';

export type AiChallenge = {
  id: string;
  tier: AiChallengeTier;
  title: string;
  description: string;
  icon: string;
  metric: AiChallengeMetric;
  target: number;
  expiresAt: string;
  difficulty: AiChallengeDifficulty;
  rewardBadgeName: string;
  rewardBadgeIcon: string;
  completed: boolean;
  rawResponse?: string;
  createdAt?: string;
  updatedAt?: string;
  subTargets?: AiMissionSubTargets | null;
  unitMinMinutes?: number | null;
  status: AiChallengeStatus;
};

export type AiChallengeHistoryEntry = {
  id: number;
  profileId: number;
  tier: AiChallengeTier;
  title: string;
  description: string;
  metric: AiChallengeMetric;
  target: number;
  progressAtClose: number;
  closeReason: AiChallengeCloseReason;
  closedAt: string;
  originalCreatedAt: string;
  originalExpiresAt: string;
  subTargets?: AiMissionSubTargets | null;
  unitMinMinutes?: number | null;
};

export type NewAiChallengeHistoryEntry = Omit<AiChallengeHistoryEntry, 'id'>;

export type SessionFilter = {
  subjectId?: number;
  groupId?: number;
  mode?: StudySessionMode;
  startFrom?: string;
  startTo?: string;
  limit?: number;
  offset?: number;
  query?: string;
};

export type SettingKeys =
  | 'dailyGoalMinutes'
  | 'focusMinutes'
  | 'breakMinutes'
  | 'themeMode'
  | 'language'
  | 'defaultSessionMode'
  | 'defaultBackground'
  | 'overlayOpacity'
  | 'mediaPlaylistPath'
  | 'displayName'
  | 'groqApiKey'
  | 'aiChallengesEnabled'
  | 'lastFetchDaily'
  | 'lastFetchWeekly'
  | 'lastFetchMonthly'
  | 'currentProfileId';

export type StructuredSettings = {
  dailyGoalMinutes: number;
  focusMinutes: number;
  breakMinutes: number;
  themeMode: ThemeMode;
  language: Language;
  defaultSessionMode: StudySessionMode;
  defaultBackground?: string;
  overlayOpacity?: number;
  mediaPlaylistPath?: string;
  mediaAutoplay?: boolean;
  mediaVolume?: number;
  displayName?: string;
  groqApiKey?: string;
  aiChallengesEnabled?: boolean;
  lastFetchDaily?: string;
  lastFetchWeekly?: string;
  lastFetchMonthly?: string;
  currentProfileId?: number;
};

export type SessionSummary = {
  totalSessions: number;
  totalMinutes: number;
  averageMinutes: number;
  recentSessions: StudySession[];
};
