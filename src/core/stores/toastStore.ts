/** Toast notification store */

import { writable, derived } from 'svelte/store';

export type ToastType = 'success' | 'error' | 'info' | 'warning';

export type Toast = {
  id: number;
  message: string;
  type: ToastType;
};

let nextId = 1;
const _toasts = writable<Toast[]>([]);

export const toasts = {
  subscribe: _toasts.subscribe,

  show: (message: string, type: ToastType = 'info', durationMs = 3000): void => {
    const id = nextId++;
    _toasts.update((t) => [...t, { id, message, type }]);

    setTimeout(() => {
      _toasts.update((t) => t.filter((toast) => toast.id !== id));
    }, durationMs);
  },

  success: (message: string): void => {
    toasts.show(message, 'success');
  },

  error: (message: string): void => {
    toasts.show(message, 'error', 5000);
  },

  info: (message: string): void => {
    toasts.show(message, 'info');
  },

  dismiss: (id: number): void => {
    _toasts.update((t) => t.filter((toast) => toast.id !== id));
  }
};
