import { writable } from 'svelte/store';

export type AiDebriefPayload = {
  sessionId: number;
  sentence: string;
  createdAt: number;
};

export const debriefSignal = writable<AiDebriefPayload | null>(null);
