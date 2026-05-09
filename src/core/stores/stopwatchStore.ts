/** Stopwatch store — centisecond precision with lap tracking */

import { writable, derived, get } from 'svelte/store';

export type StopwatchState = 'idle' | 'running' | 'paused';

export type Lap = {
  number: number;
  splitMs: number;
  totalMs: number;
};

export type StopwatchData = {
  state: StopwatchState;
  elapsedMs: number;
  laps: Lap[];
  lastLapMs: number;
};

const defaultStopwatch: StopwatchData = {
  state: 'idle',
  elapsedMs: 0,
  laps: [],
  lastLapMs: 0
};

const _stopwatch = writable<StopwatchData>({ ...defaultStopwatch });

let intervalId: ReturnType<typeof setInterval> | null = null;
let startTimestamp = 0;
let pausedElapsed = 0;

function tick(): void {
  const now = performance.now();
  const elapsed = pausedElapsed + (now - startTimestamp);
  _stopwatch.update((s) => ({ ...s, elapsedMs: Math.floor(elapsed) }));
}

export const stopwatch = {
  subscribe: _stopwatch.subscribe,

  start(): void {
    const current = get(_stopwatch);
    if (current.state === 'running') return;

    if (current.state === 'paused') {
      pausedElapsed = current.elapsedMs;
    } else {
      pausedElapsed = 0;
      _stopwatch.set({ ...defaultStopwatch, state: 'running' });
    }

    startTimestamp = performance.now();
    _stopwatch.update((s) => ({ ...s, state: 'running' }));
    intervalId = setInterval(tick, 50);
  },

  pause(): void {
    if (intervalId) {
      clearInterval(intervalId);
      intervalId = null;
    }
    _stopwatch.update((s) => {
      pausedElapsed = s.elapsedMs;
      return { ...s, state: 'paused' };
    });
  },

  lap(): void {
    _stopwatch.update((s) => {
      if (s.state !== 'running') return s;
      const splitMs = s.elapsedMs - s.lastLapMs;
      const newLap: Lap = {
        number: s.laps.length + 1,
        splitMs,
        totalMs: s.elapsedMs
      };
      return { ...s, laps: [...s.laps, newLap], lastLapMs: s.elapsedMs };
    });
  },

  reset(): void {
    if (intervalId) {
      clearInterval(intervalId);
      intervalId = null;
    }
    startTimestamp = 0;
    pausedElapsed = 0;
    _stopwatch.set({ ...defaultStopwatch });
  }
};

/** Format milliseconds to HH:MM:SS.d */
export function formatStopwatch(ms: number): string {
  const totalSeconds = Math.floor(ms / 1000);
  const decisecond = Math.floor((ms % 1000) / 100);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;

  const pad = (n: number) => String(n).padStart(2, '0');
  return `${pad(hours)}:${pad(minutes)}:${pad(seconds)}.${decisecond}`;
}

/** Format ms for lap display */
export function formatLapTime(ms: number): string {
  const totalSeconds = Math.floor(ms / 1000);
  const decisecond = Math.floor((ms % 1000) / 100);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${pad(minutes)}:${pad(seconds)}.${decisecond}`;
}

export const stopwatchDisplay = derived(_stopwatch, ($s) => formatStopwatch($s.elapsedMs));
