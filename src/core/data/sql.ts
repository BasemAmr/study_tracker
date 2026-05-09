export type SqlRow = Record<string, unknown>;

export type SqlDatabase = {
  execute: (sql: string, values?: Array<string | number | null>) => Promise<{ lastInsertId?: number | string }>;
  select: <T>(sql: string, values?: Array<string | number | null>) => Promise<T>;
};

export function toBoolean(value: unknown): boolean {
  return value === 1 || value === true;
}

export function toIntegerBoolean(value: boolean): number {
  return value ? 1 : 0;
}

export function normalizeText(value: string): string {
  return value.trim();
}

export function normalizeNullableText(value?: string | null): string | null {
  if (value === undefined || value === null) {
    return null;
  }

  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
}
