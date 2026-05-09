/**
 * Global media player store — persists across page navigation.
 * A single audio element is managed here; components just subscribe.
 */

import { writable, derived, get } from 'svelte/store';

export type PlayerState = 'idle' | 'playing' | 'paused';

export type Track = {
  name: string;
  url: string;
};

type PlayerData = {
  state: PlayerState;
  tracks: Track[];
  currentIndex: number;
  volume: number;
  muted: boolean;
  currentTime: number;
  duration: number;
};

const defaults: PlayerData = {
  state: 'idle',
  tracks: [],
  currentIndex: 0,
  volume: 0.7,
  muted: false,
  currentTime: 0,
  duration: 0
};

const _player = writable<PlayerData>({ ...defaults });

// The single shared audio element (created lazily)
let _audio: HTMLAudioElement | null = null;

function getAudio(): HTMLAudioElement {
  if (!_audio) {
    _audio = new Audio();
    _audio.volume = get(_player).volume;

    _audio.addEventListener('timeupdate', () => {
      _player.update((s) => ({
        ...s,
        currentTime: _audio!.currentTime,
        duration: _audio!.duration || 0
      }));
    });

    _audio.addEventListener('ended', () => {
      mediaPlayer.next();
    });

    _audio.addEventListener('play', () => {
      _player.update((s) => ({ ...s, state: 'playing' }));
    });

    _audio.addEventListener('pause', () => {
      _player.update((s) => ({
        ...s,
        state: s.tracks.length > 0 ? 'paused' : 'idle'
      }));
    });
  }
  return _audio;
}

export const mediaPlayer = {
  subscribe: _player.subscribe,

  loadFiles(files: File[]): void {
    const audio = getAudio();
    const filtered = files.filter((f) =>
      /\.(mp3|mp4|wav|ogg|m4a|webm|aac|flac)$/i.test(f.name)
    );
    if (filtered.length === 0) return;

    // Revoke old object URLs
    const current = get(_player);
    current.tracks.forEach((t) => {
      if (t.url.startsWith('blob:')) URL.revokeObjectURL(t.url);
    });

    const tracks: Track[] = filtered.map((f) => ({
      name: f.name.replace(/\.(mp3|mp4|wav|ogg|m4a|webm|aac|flac)$/i, ''),
      url: URL.createObjectURL(f)
    }));

    _player.update((s) => ({ ...s, tracks, currentIndex: 0 }));
    audio.src = tracks[0].url;
    audio.load();
  },

  play(): void {
    const audio = getAudio();
    const s = get(_player);
    if (s.tracks.length === 0) return;
    if (!audio.src || audio.src === window.location.href) {
      audio.src = s.tracks[s.currentIndex].url;
      audio.load();
    }
    audio.play().catch(() => {});
  },

  pause(): void {
    getAudio().pause();
  },

  toggle(): void {
    const s = get(_player);
    s.state === 'playing' ? mediaPlayer.pause() : mediaPlayer.play();
  },

  next(): void {
    const s = get(_player);
    if (s.tracks.length === 0) return;
    const nextIndex = (s.currentIndex + 1) % s.tracks.length;
    _player.update((p) => ({ ...p, currentIndex: nextIndex }));
    const audio = getAudio();
    audio.src = s.tracks[nextIndex].url;
    audio.load();
    audio.play().catch(() => {});
  },

  prev(): void {
    const s = get(_player);
    if (s.tracks.length === 0) return;
    const prevIndex = s.currentIndex > 0 ? s.currentIndex - 1 : s.tracks.length - 1;
    _player.update((p) => ({ ...p, currentIndex: prevIndex }));
    const audio = getAudio();
    audio.src = s.tracks[prevIndex].url;
    audio.load();
    audio.play().catch(() => {});
  },

  jumpTo(index: number): void {
    const s = get(_player);
    if (index < 0 || index >= s.tracks.length) return;
    _player.update((p) => ({ ...p, currentIndex: index }));
    const audio = getAudio();
    audio.src = s.tracks[index].url;
    audio.load();
    audio.play().catch(() => {});
  },

  setVolume(v: number): void {
    const clamped = Math.max(0, Math.min(1, v));
    _player.update((s) => ({ ...s, volume: clamped, muted: clamped === 0 }));
    const audio = getAudio();
    audio.volume = clamped;
    audio.muted = clamped === 0;
  },

  toggleMute(): void {
    const s = get(_player);
    const muted = !s.muted;
    _player.update((p) => ({ ...p, muted }));
    getAudio().muted = muted;
  },

  seek(time: number): void {
    const audio = getAudio();
    const clamped = Math.max(0, Math.min(time, audio.duration || 0));
    audio.currentTime = clamped;
    _player.update((s) => ({ ...s, currentTime: clamped }));
  },

  rewind10(): void {
    const audio = getAudio();
    this.seek(audio.currentTime - 10);
  },

  skip10(): void {
    const audio = getAudio();
    this.seek(audio.currentTime + 10);
  }
};

export const isPlayerActive = derived(_player, ($p) => $p.tracks.length > 0);
export const currentTrackName = derived(_player, ($p) =>
  $p.tracks[$p.currentIndex]?.name ?? ''
);

export function formatPlayerTime(seconds: number): string {
  if (!isFinite(seconds)) return '0:00';
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${m}:${String(s).padStart(2, '0')}`;
}
