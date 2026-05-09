import { debriefSignal } from '../stores/aiDebriefStore';
import { chatCompletion } from './groqClient';
import { getAiFeaturesOrDefault, getForProfile } from '../data/repositories/aiFeatureSettingsRepository';
import { getCurrentProfileId } from '../data/repositories/profileRepository';
import { getSessionById, listSessionsForProfile } from '../data/repositories/sessionRepository';

async function rollupSubject(subjectLabel: string, profileId: number, excludeId: number | undefined) {
  const rows = await listSessionsForProfile(profileId, {
    limit: 4000,
    offset: 0
  });

  let totalDur = 0;
  let count = 0;
  let lastIso: string | null = null;
  for (const s of rows) {
    const name = (s.subjectName ?? 'General').trim() || 'General';
    if (name !== subjectLabel) continue;
    if (excludeId != null && s.id === excludeId) continue;
    totalDur += s.durationMinutes;
    count += 1;
    if (!lastIso || new Date(s.startAt) > new Date(lastIso)) lastIso = s.startAt;
  }
  const avg = count > 0 ? Math.round(totalDur / count) : null;
  return { avgDur: avg, priorCount: count, lastPriorIso: lastIso };
}

/**
 * Fire-and-forget debrief (~3s SLA). Silent on errors — never blocks save flow or shows error UI.
 */
export async function generateForSession(sessionId: number): Promise<void> {
  let profileId: number;
  try {
    profileId = await getCurrentProfileId();
  } catch {
    return;
  }

  try {
    const settingsRow = await getForProfile(profileId);
    const feats = getAiFeaturesOrDefault(profileId, settingsRow);
    if (!feats.debriefEnabled) return;

    const session = await getSessionById(sessionId);
    if (!session) return;

    const subj = (session.subjectName ?? 'General').trim() || 'General';
    const { avgDur, priorCount, lastPriorIso } = await rollupSubject(subj, profileId, session.id);

    const context = `
Session snapshot:
Subject: "${subj}"
Duration (minutes): ${session.durationMinutes}
Mood: ${session.mood?.trim() || 'not recorded'}
Mode: ${session.mode}

Prior ${subj} history (excluding this row):
Older sessions counted: ${priorCount}
Rolling average duration: ${avgDur ?? 'unknown'}
Latest prior session: ${lastPriorIso ?? 'none'}
`;

    const systemPrompt = `
You produce exactly ONE restrained sentence reacting to how this session compares to "${subj}" history.
Facts:
${context}
Rules: no emoji; never start with motivational praise clichés ("Great job", "Amazing");
limit ~22 words unless numbers require slightly more room.
`;

    const userPrompt = `Single plain sentence referencing duration and mood and/or averages.`;

    const sentence = await chatCompletion({
      systemPrompt,
      prompt: userPrompt,
      jsonMode: false,
      maxTokens: 120,
      timeoutMs: 3000,
    });
    if (!sentence) return;

    debriefSignal.set({
      sessionId,
      sentence: sentence.trim(),
      createdAt: Date.now()
    });
  } catch {
    /* intentionally silent — spec */
  }
}
