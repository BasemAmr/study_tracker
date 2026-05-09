/** Simple client-side router store for SPA navigation */

import { writable, derived, type Readable } from 'svelte/store';

export type Route = 'dashboard' | 'sessions' | 'analytics' | 'settings' | 'achievements' | 'sync';

const _currentRoute = writable<Route>('dashboard');

export const currentRoute: Readable<Route> = derived(_currentRoute, ($r) => $r);

export function navigate(route: Route): void {
  _currentRoute.set(route);
}
