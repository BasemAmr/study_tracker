/**
 * Process-wide async mutex used to serialize heavy writers against the SQLite
 * database. Even with WAL enabled, the Tauri SQL plugin can briefly trip
 * SQLITE_BUSY when sync apply (multi-row UPSERT) and a UI mutation
 * (e.g. profile delete BEGIN/COMMIT) overlap. Wrapping both in
 * `withWriteLock(...)` makes the contention deterministic.
 *
 * Reads do NOT need to take this lock — WAL gives concurrent readers.
 */

type Task<T> = () => Promise<T>;

let tail: Promise<unknown> = Promise.resolve();

export function withWriteLock<T>(task: Task<T>): Promise<T> {
  const run = tail.then(task, task);
  // Swallow rejection on the chain so a single failure doesn't poison the queue.
  tail = run.catch(() => {});
  return run;
}

/** Retry an SQL statement when the Tauri SQL plugin returns SQLITE_BUSY
 * ("database is locked"). We sleep with jittered backoff between attempts
 * so a transient lock from a parallel pool connection clears before we give up.
 *
 * The plugin's per-connection busy_timeout (5s default) only fires while
 * SQLite itself is waiting; some lock paths bubble up before that timer runs,
 * which is when we see "code: 5". Retry handles that. */
export async function execWithBusyRetry<T>(
  fn: () => Promise<T>,
  opts: { attempts?: number; baseDelayMs?: number; label?: string } = {}
): Promise<T> {
  const attempts = opts.attempts ?? 6;
  const base = opts.baseDelayMs ?? 50;
  let lastErr: unknown;
  for (let i = 0; i < attempts; i++) {
    try {
      return await fn();
    } catch (e) {
      const msg = String((e as { message?: string })?.message ?? e);
      const isBusy = /database is locked|code:\s*5/i.test(msg);
      if (!isBusy) throw e;
      lastErr = e;
      const delay = base * Math.pow(2, i) * (0.7 + Math.random() * 0.6);
      if (opts.label) {
        console.warn(`[DB] BUSY on ${opts.label} (attempt ${i + 1}/${attempts}), retrying in ${Math.round(delay)}ms`);
      }
      await new Promise((r) => setTimeout(r, delay));
    }
  }
  throw lastErr;
}
