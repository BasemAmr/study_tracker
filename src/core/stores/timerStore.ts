/** Timer store for live study sessions */

import { writable, derived, get } from 'svelte/store';
import type { StudySessionMode } from '../domain';
import { createStudySession } from '../services/sessionService';
import { soundUtils } from '../utils/soundUtils';
import { nowISO } from '../utils/dateUtils';

export type TimerState = 'idle' | 'running' | 'paused' | 'break';

export type SessionMetadata = {
  subjectId: number | null;
  subjectName: string | null;
  topic: string | null;
  mood: string | null;
  notes: string | null;
  backgroundImage: string | null;
};

export type TimerData = {
  state: TimerState;
  mode: StudySessionMode;
  elapsedSeconds: number;
  breakSeconds: number;
  startedAt: string | null;
  /** Pomodoro specific */
  pomodoroCount: number;
  pomodoroFocusMinutes: number;
  pomodoroBreakMinutes: number;
  isBreakPhase: boolean;
  /** Phase elapsed (resets each pomodoro cycle) */
  phaseElapsedSeconds: number;
  metadata: SessionMetadata | null;
};

const defaultTimer: TimerData = {
  state: 'idle',
  mode: 'long_session',
  elapsedSeconds: 0,
  breakSeconds: 0,
  startedAt: null,
  pomodoroCount: 0,
  pomodoroFocusMinutes: 25,
  pomodoroBreakMinutes: 5,
  isBreakPhase: false,
  phaseElapsedSeconds: 0,
  metadata: null
};

const _timer = writable<TimerData>({ ...defaultTimer });

let intervalId: ReturnType<typeof setInterval> | null = null;

async function handleFocusEnd(t: TimerData) {
  // Play sound
  soundUtils.playBreakStart();

  // Auto-save session
  if (t.elapsedSeconds >= 10) {
    const durationMinutes = Math.max(1, Math.round(t.elapsedSeconds / 60));
    try {
      await createStudySession({
        startAt: t.startedAt ?? nowISO(),
        endAt: nowISO(),
        durationMinutes,
        subjectId: t.metadata?.subjectId,
        subjectName: t.metadata?.subjectName,
        topic: t.metadata?.topic,
        mood: t.metadata?.mood,
        notes: t.metadata?.notes,
        mode: t.mode,
        breakMinutes: 0, // Focus-only portion
        backgroundImage: t.metadata?.backgroundImage
      });
      // Dispatch event for UI to refresh history
      window.dispatchEvent(new CustomEvent('session-saved'));
    } catch (err) {
      console.error('[TimerStore] Auto-save failed:', err);
    }
  }
}

function tick(): void {
  const t = get(_timer);
  if (t.state === 'running') {
    const newElapsed = t.elapsedSeconds + 1;
    const newPhaseElapsed = t.phaseElapsedSeconds + 1;

    if (t.mode === 'pomodoro' && !t.isBreakPhase) {
      const focusSeconds = t.pomodoroFocusMinutes * 60;
      if (newPhaseElapsed >= focusSeconds) {
        // Switch to break phase
        const updated = {
          ...t,
          elapsedSeconds: 0, // Reset focus counter for the next session
          phaseElapsedSeconds: 0,
          isBreakPhase: true,
          state: 'break' as TimerState,
          pomodoroCount: t.pomodoroCount + 1,
          startedAt: nowISO() // Reset start time for the next focus period
        };
        _timer.set(updated);
        handleFocusEnd(t); // Pass old state to save
        return;
      }
    }

    _timer.set({
      ...t,
      elapsedSeconds: t.isBreakPhase ? t.elapsedSeconds : newElapsed,
      breakSeconds: t.isBreakPhase ? t.breakSeconds + 1 : t.breakSeconds,
      phaseElapsedSeconds: newPhaseElapsed
    });
    return;
  }

  if (t.state === 'break') {
    const newPhaseElapsed = t.phaseElapsedSeconds + 1;
    const breakLimit = t.pomodoroBreakMinutes * 60;

    if (newPhaseElapsed >= breakLimit) {
      // Auto-resume focus
      soundUtils.playFocusResume();
      _timer.set({
        ...t,
        elapsedSeconds: 0, // Reset for the new focus session to ensure correct auto-save duration
        phaseElapsedSeconds: 0,
        isBreakPhase: false,
        state: 'running' as TimerState,
        startedAt: nowISO()
      });
      return;
    }

    _timer.set({
      ...t,
      phaseElapsedSeconds: newPhaseElapsed
    });
  }
}

export const timer = {
  subscribe: _timer.subscribe,

  start(mode: StudySessionMode, focusMinutes = 25, breakMinutes = 5, metadata: SessionMetadata | null = null): void {
    this.reset();
    _timer.set({
      ...defaultTimer,
      state: 'running',
      mode,
      startedAt: nowISO(),
      pomodoroFocusMinutes: focusMinutes,
      pomodoroBreakMinutes: breakMinutes,
      metadata
    });
    if (!intervalId) intervalId = setInterval(tick, 1000);
  },

  pause(): void {
    _timer.update((t) => ({ ...t, state: 'paused' }));
    if (intervalId) {
      clearInterval(intervalId);
      intervalId = null;
    }
  },

  resume(): void {
    const current = get(_timer);
    if (current.state === 'paused' || current.state === 'break') {
      _timer.update((t) => ({ ...t, state: 'running' }));
      if (!intervalId) intervalId = setInterval(tick, 1000);
    }
  },

  /** Resume from pomodoro break to next focus cycle */
  resumeFromBreak(): void {
    soundUtils.playFocusResume();
    _timer.update((t) => ({
      ...t,
      state: 'running',
      isBreakPhase: false,
      phaseElapsedSeconds: 0,
      startedAt: nowISO()
    }));
    if (!intervalId) {
      intervalId = setInterval(tick, 1000);
    }
  },

  /** Skip current break */
  skipBreak(): void {
    this.resumeFromBreak();
  },

  stop(): TimerData {
    const current = get(_timer);
    if (intervalId) {
      clearInterval(intervalId);
      intervalId = null;
    }
    _timer.set({ ...defaultTimer });
    return current;
  },

  reset(): void {
    if (intervalId) {
      clearInterval(intervalId);
      intervalId = null;
    }
    _timer.set({ ...defaultTimer });
  },

  getSnapshot(): TimerData {
    return get(_timer);
  }
};

/** Derived store: formatted display time */
export const timerDisplay = derived(_timer, ($t) => {
  const totalSeconds = $t.isBreakPhase 
    ? Math.max(0, ($t.pomodoroBreakMinutes * 60) - $t.phaseElapsedSeconds)
    : ($t.mode === 'pomodoro' 
        ? Math.max(0, ($t.pomodoroFocusMinutes * 60) - $t.phaseElapsedSeconds)
        : $t.elapsedSeconds);
        
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;
  const pad = (n: number) => String(n).padStart(2, '0');

  return hours > 0
    ? `${pad(hours)}:${pad(minutes)}:${pad(seconds)}`
    : `${pad(minutes)}:${pad(seconds)}`;
});

/** Derived store: focus time in minutes */
export const focusMinutesElapsed = derived(_timer, ($t) => {
  return Math.floor($t.elapsedSeconds / 60);
});

/** Derived store: is timer active? */
export const isTimerActive = derived(_timer, ($t) => {
  return $t.state !== 'idle';
});
