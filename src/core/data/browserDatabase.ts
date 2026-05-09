/**
 * Browser-compatible database shim.
 * Uses localStorage as a key-value table store when Tauri runtime is not available.
 * In Tauri, the real SQLite plugin is used.
 */

const STORAGE_PREFIX = 'studytracker_db_';

type QueryResult = { lastInsertId?: number | string };

/** Minimal SQL parser that handles our INSERT/UPDATE/DELETE/SELECT patterns against localStorage. */
export class BrowserDatabase {
  private tables: Map<string, Array<Record<string, unknown>>> = new Map();
  private autoIncrements: Map<string, number> = new Map();

  constructor() {
    this.loadFromStorage();
  }

  private loadFromStorage(): void {
    try {
      const raw = localStorage.getItem(STORAGE_PREFIX + 'tables');
      if (raw) {
        const data = JSON.parse(raw);
        for (const [name, rows] of Object.entries(data)) {
          this.tables.set(name, rows as Array<Record<string, unknown>>);
        }
      }
      const ids = localStorage.getItem(STORAGE_PREFIX + 'autoIncrements');
      if (ids) {
        const data = JSON.parse(ids);
        for (const [name, id] of Object.entries(data)) {
          this.autoIncrements.set(name, id as number);
        }
      }
    } catch {
      // Start fresh if corrupted
    }
  }

  private saveToStorage(): void {
    const tables: Record<string, unknown[]> = {};
    for (const [name, rows] of this.tables) {
      tables[name] = rows;
    }
    localStorage.setItem(STORAGE_PREFIX + 'tables', JSON.stringify(tables));
    localStorage.setItem(
      STORAGE_PREFIX + 'autoIncrements',
      JSON.stringify(Object.fromEntries(this.autoIncrements))
    );
  }

  private getTable(name: string): Array<Record<string, unknown>> {
    if (!this.tables.has(name)) {
      this.tables.set(name, []);
    }
    return this.tables.get(name)!;
  }

  private nextId(table: string): number {
    const current = this.autoIncrements.get(table) ?? 0;
    const next = current + 1;
    this.autoIncrements.set(table, next);
    return next;
  }

  async execute(sql: string, values?: Array<string | number | null>): Promise<QueryResult> {
    const trimmed = sql.trim().replace(/\s+/g, ' ');

    // CREATE TABLE — just ensure table exists
    const createMatch = trimmed.match(/CREATE TABLE IF NOT EXISTS (\w+)/i);
    if (createMatch) {
      this.getTable(createMatch[1]);
      this.saveToStorage();
      return {};
    }

    // CREATE INDEX — no-op
    if (/CREATE INDEX/i.test(trimmed)) {
      return {};
    }

    // PRAGMA — no-op
    if (/PRAGMA/i.test(trimmed)) {
      return {};
    }

    // INSERT
    const insertMatch = trimmed.match(/INSERT INTO (\w+)\s*\(([^)]+)\)\s*VALUES\s*\(([^)]+)\)/i);
    if (insertMatch) {
      const table = insertMatch[1];
      const columns = insertMatch[2].split(',').map((c) => c.trim());
      const rows = this.getTable(table);
      const id = this.nextId(table);

      const row: Record<string, unknown> = { id };
      const params = values ?? [];
      let paramIdx = 0;

      for (const col of columns) {
        if (col === 'id') continue;
        const valPlaceholder = insertMatch[3].split(',')[columns.indexOf(col)]?.trim();
        if (valPlaceholder === '?') {
          row[col] = params[paramIdx++] ?? null;
        } else if (valPlaceholder === 'CURRENT_TIMESTAMP') {
          row[col] = new Date().toISOString();
        } else {
          row[col] = params[paramIdx++] ?? null;
        }
      }

      rows.push(row);
      this.saveToStorage();
      return { lastInsertId: id };
    }

    // INSERT with ON CONFLICT (upsert)
    const upsertMatch = trimmed.match(/INSERT INTO (\w+)\s*\(([^)]+)\)\s*VALUES\s*\(([^)]+)\)\s*ON CONFLICT/i);
    if (upsertMatch) {
      const table = upsertMatch[1];
      const columns = upsertMatch[2].split(',').map((c) => c.trim());
      const rows = this.getTable(table);
      const params = values ?? [];

      const keyCol = columns[0];
      const keyVal = params[0];

      const existingIdx = rows.findIndex((r) => r[keyCol] === keyVal);

      if (existingIdx >= 0) {
        let paramIdx = 0;
        for (const col of columns) {
          rows[existingIdx][col] = params[paramIdx++] ?? null;
        }
        rows[existingIdx]['updated_at'] = new Date().toISOString();
      } else {
        const row: Record<string, unknown> = {};
        let paramIdx = 0;
        for (const col of columns) {
          row[col] = params[paramIdx++] ?? null;
        }
        rows.push(row);
      }

      this.saveToStorage();
      return {};
    }

    // UPDATE
    const updateMatch = trimmed.match(/UPDATE (\w+) SET (.+) WHERE (.+)/i);
    if (updateMatch) {
      const table = updateMatch[1];
      const rows = this.getTable(table);
      const params = values ?? [];

      // Find the WHERE id = ? at the end
      const whereClause = updateMatch[3].replace(';', '').trim();
      const whereCol = whereClause.split('=')[0].trim();
      const whereVal = params[params.length - 1];

      const matchingRows = rows.filter((r) => r[whereCol] == whereVal);

      const setParts = updateMatch[2].split(',').map((s) => s.trim());
      let paramIdx = 0;

      for (const row of matchingRows) {
        paramIdx = 0;
        for (const part of setParts) {
          const col = part.split('=')[0].trim();
          const valPart = part.split('=')[1]?.trim();
          if (valPart === '?') {
            row[col] = params[paramIdx++];
          } else if (valPart?.includes('CURRENT_TIMESTAMP')) {
            row[col] = new Date().toISOString();
          } else {
            paramIdx++;
          }
        }
      }

      this.saveToStorage();
      return {};
    }

    // DELETE
    const deleteMatch = trimmed.match(/DELETE FROM (\w+) WHERE (\w+)\s*=\s*\?/i);
    if (deleteMatch) {
      const table = deleteMatch[1];
      const col = deleteMatch[2];
      const val = values?.[0];
      const rows = this.getTable(table);
      const filtered = rows.filter((r) => r[col] != val);
      this.tables.set(table, filtered);
      this.saveToStorage();
      return {};
    }

    // If nothing matched, no-op
    this.saveToStorage();
    return {};
  }

  async select<T>(sql: string, values?: Array<string | number | null>): Promise<T> {
    const trimmed = sql.trim().replace(/\s+/g, ' ');

    // Extract table name from SELECT ... FROM table_name
    const fromMatch = trimmed.match(/FROM\s+(\w+)/i);
    if (!fromMatch) {
      return [] as unknown as T;
    }

    const table = fromMatch[1];
    let rows = [...this.getTable(table)];

    // Handle WHERE clauses
    const whereMatch = trimmed.match(/WHERE\s+(.+?)(?:\s+ORDER|\s+LIMIT|\s+GROUP|\s*;?\s*$)/i);
    if (whereMatch && values && values.length > 0) {
      const whereStr = whereMatch[1];
      const conditions = whereStr.split(/\s+AND\s+/i);
      let paramIdx = 0;

      for (const condition of conditions) {
        const trimCond = condition.trim();

        // Handle LIKE
        if (trimCond.includes('LIKE')) {
          const colMatch = trimCond.match(/(\w+)\s+LIKE\s+\?/i);
          if (colMatch) {
            const col = colMatch[1];
            const pattern = String(values[paramIdx++] ?? '').replace(/%/g, '');
            rows = rows.filter((r) =>
              String(r[col] ?? '').toLowerCase().includes(pattern.toLowerCase())
            );
          }
          // Handle grouped LIKE conditions  
          const groupedMatch = trimCond.match(/\((.+)\)/);
          if (groupedMatch) {
            const orParts = groupedMatch[1].split(/\s+OR\s+/i);
            const patterns: Array<{ col: string; pattern: string }> = [];
            for (const part of orParts) {
              const m = part.trim().match(/(\w+)\s+LIKE\s+\?/i);
              if (m) {
                patterns.push({ col: m[1], pattern: String(values[paramIdx++] ?? '').replace(/%/g, '') });
              }
            }
            if (patterns.length > 0) {
              rows = rows.filter((r) =>
                patterns.some((p) =>
                  String(r[p.col] ?? '').toLowerCase().includes(p.pattern.toLowerCase())
                )
              );
            }
          }
        }
        // Handle = ?
        else if (trimCond.includes('= ?')) {
          const col = trimCond.split('=')[0].trim();
          const val = values[paramIdx++];
          rows = rows.filter((r) => r[col] == val);
        }
        // Handle >= ?
        else if (trimCond.includes('>= ?')) {
          const col = trimCond.split('>=')[0].trim();
          const val = values[paramIdx++];
          rows = rows.filter((r) => String(r[col] ?? '') >= String(val ?? ''));
        }
        // Handle <= ?
        else if (trimCond.includes('<= ?')) {
          const col = trimCond.split('<=')[0].trim();
          const val = values[paramIdx++];
          rows = rows.filter((r) => String(r[col] ?? '') <= String(val ?? ''));
        }
      }
    }

    // Handle ORDER BY
    const orderMatch = trimmed.match(/ORDER BY\s+(.+?)(?:\s+LIMIT|\s*;?\s*$)/i);
    if (orderMatch) {
      const parts = orderMatch[1].split(',').map((p) => p.trim());
      for (const part of parts.reverse()) {
        const [col, dir] = part.split(/\s+/);
        const desc = dir?.toUpperCase() === 'DESC';
        rows.sort((a, b) => {
          const va = String(a[col] ?? '');
          const vb = String(b[col] ?? '');
          return desc ? vb.localeCompare(va) : va.localeCompare(vb);
        });
      }
    }

    // Handle aggregate functions (COUNT, SUM, AVG)
    if (/SELECT\s+COUNT|SUM|AVG|COALESCE/i.test(trimmed)) {
      const count = rows.length;
      const sumMatch = trimmed.match(/SUM\((\w+)\)/i);
      const avgMatch = trimmed.match(/AVG\((\w+)\)/i);

      const sumCol = sumMatch?.[1];
      const avgCol = avgMatch?.[1];

      const sumVal = sumCol ? rows.reduce((s, r) => s + Number(r[sumCol] ?? 0), 0) : 0;
      const avgVal = avgCol && count > 0 ? rows.reduce((s, r) => s + Number(r[avgCol] ?? 0), 0) / count : 0;

      return [
        {
          total_sessions: count,
          total_minutes: sumVal,
          average_minutes: avgVal
        }
      ] as unknown as T;
    }

    // Handle JOIN (simplified — for subjects with session count)
    if (/LEFT JOIN/i.test(trimmed)) {
      // For the listSubjects query, just return subjects with session_count = 0
      rows = rows.map((r) => ({ ...r, session_count: 0 }));
    }

    // Handle LIMIT
    const limitMatch = trimmed.match(/LIMIT\s+(\?|\d+)/i);
    if (limitMatch) {
      let limit: number;
      if (limitMatch[1] === '?') {
        // Find the limit param — it's usually the last or second-to-last param
        const offsetMatch = trimmed.match(/OFFSET\s+\?/i);
        if (offsetMatch && values) {
          limit = Number(values[values.length - 2] ?? 50);
          const offset = Number(values[values.length - 1] ?? 0);
          rows = rows.slice(offset, offset + limit);
        } else if (values) {
          limit = Number(values[values.length - 1] ?? 50);
          rows = rows.slice(0, limit);
        }
      } else {
        limit = parseInt(limitMatch[1]);
        rows = rows.slice(0, limit);
      }
    }

    // Handle COLLATE NOCASE for name matching
    if (/COLLATE NOCASE/i.test(trimmed) && values && values[0]) {
      const searchVal = String(values[0]).toLowerCase();
      rows = rows.filter((r) => String(r['name'] ?? '').toLowerCase() === searchVal);
    }

    return rows as unknown as T;
  }
}
