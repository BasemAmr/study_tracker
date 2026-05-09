/**
 * Utility for playing UI sounds using Web Audio API to avoid external file dependencies.
 */

let audioContext: AudioContext | null = null;

function getContext() {
  if (!audioContext) {
    audioContext = new (window.AudioContext || (window as any).webkitAudioContext)();
  }
  return audioContext;
}

/**
 * Plays a soft, premium chime sound.
 * @param frequency The base frequency of the chime.
 * @param type Oscillator type.
 * @param duration Duration in seconds.
 */
function playChime(frequency: number, type: OscillatorType = 'sine', duration: number = 0.5) {
  try {
    const ctx = getContext();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();

    osc.type = type;
    osc.frequency.setValueAtTime(frequency, ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(frequency * 0.5, ctx.currentTime + duration);

    gain.gain.setValueAtTime(0.2, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + duration);

    osc.connect(gain);
    gain.connect(ctx.destination);

    osc.start();
    osc.stop(ctx.currentTime + duration);
  } catch (e) {
    console.warn('[StudyTracker] Sound playback failed:', e);
  }
}

export const soundUtils = {
  /** Play when a focus session ends and break starts */
  playBreakStart() {
    // A pleasant "ding-ding"
    playChime(880, 'sine', 0.6); // A5
    setTimeout(() => playChime(1108.73, 'sine', 0.8), 150); // C#6
  },

  /** Play when a break ends and focus resumes */
  playFocusResume() {
    // An uplifting "rising" chime
    playChime(659.25, 'sine', 0.6); // E5
    setTimeout(() => playChime(880, 'sine', 0.8), 150); // A5
  }
};
