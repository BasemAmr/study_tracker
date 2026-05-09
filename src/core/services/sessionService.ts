import type { SessionFilter, StudySession } from '../domain';
import { createSession, deleteSession, getRecentSessions, getSessionById, getSessionSummary, listSessions, updateSession } from '../data/repositories';
import { generateForSession as generateAiDebrief } from './aiDebriefService';

export async function createStudySession(session: StudySession): Promise<number> {
  const id = await createSession(session);
  /** Session debrief (A‑T‑3): never block save latency on Groq SLA. */
  void generateAiDebrief(id).catch(() => {});
  return id;
}

export function updateStudySession(session: StudySession): Promise<void> {
  return updateSession(session);
}

export function removeStudySession(id: number): Promise<void> {
  return deleteSession(id);
}

export function fetchStudySession(id: number): Promise<StudySession | null> {
  return getSessionById(id);
}

export function fetchStudySessions(filter: SessionFilter = {}): Promise<StudySession[]> {
  return listSessions(filter);
}

export function fetchRecentStudySessions(limit = 5): Promise<StudySession[]> {
  return getRecentSessions(limit);
}

export function fetchStudySessionSummary() {
  return getSessionSummary();
}
