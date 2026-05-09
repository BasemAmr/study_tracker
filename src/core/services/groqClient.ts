import { BaseDirectory, writeTextFile } from '@tauri-apps/plugin-fs';
import { getSettingByKey } from '../data/repositories/appSettingsRepository';

export const GROQ_CHAT_ENDPOINT = 'https://api.groq.com/openai/v1/chat/completions';
export const GROQ_DEFAULT_MODEL = 'openai/gpt-oss-120b';

export type GroqChatOptions = {
  prompt: string;
  systemPrompt?: string;
  jsonMode?: boolean;
  maxTokens?: number;
  timeoutMs?: number;
};

function stringifyError(error: unknown): string {
  if (error instanceof Error) {
    return `${error.name}: ${error.message}\n${error.stack ?? ''}`.trim();
  }
  return String(error);
}

export async function logGroqError(message: string, details: unknown): Promise<void> {
  try {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const payload = `${message}\n${JSON.stringify(details, null, 2)}\n`;
    await writeTextFile(`studytracker-groq-${timestamp}.log`, payload, {
      baseDir: BaseDirectory.Desktop
    });
  } catch (writeError) {
    console.error('Failed to write Groq desktop log:', writeError);
  }
}

async function resolveApiKey(): Promise<string | null> {
  const row = await getSettingByKey('groqApiKey');
  const v = row?.value?.trim();
  return v && v.length > 0 ? v : null;
}

/**
 * Minimal Groq/OpenAI-compat chat invoke with hard timeout (Feature 3 default 3000 ms).
 * Returns assistant text content or null on failure/timeout/non-JSON success for callers.
 */
export async function chatCompletion(opts: GroqChatOptions): Promise<string | null> {
  const apiKey = await resolveApiKey();
  if (!apiKey) return null;

  const timeoutMs = opts.timeoutMs ?? 3000;
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const body: Record<string, unknown> = {
      model: GROQ_DEFAULT_MODEL,
      messages: [
        ...(opts.systemPrompt ? [{ role: 'system', content: opts.systemPrompt }] : []),
        { role: 'user', content: opts.prompt }
      ],
      temperature: 0.7
    };

    if (opts.jsonMode) {
      body.response_format = { type: 'json_object' };
    }
    if (opts.maxTokens !== undefined) {
      body.max_tokens = opts.maxTokens;
    }

    const response = await fetch(GROQ_CHAT_ENDPOINT, {
      method: 'POST',
      signal: controller.signal,
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(body)
    });

    if (!response.ok) {
      const errorText = await response.text();
      await logGroqError('Groq API request failed', {
        status: response.status,
        statusText: response.statusText,
        body: errorText
      });
      console.error('Groq API error:', errorText);
      return null;
    }

    const data = (await response.json()) as { choices?: Array<{ message?: { content?: string } }> };
    const content = data.choices?.[0]?.message?.content;
    if (typeof content !== 'string' || content.length === 0) {
      await logGroqError('Groq response missing choices[0].message.content', data);
      return null;
    }
    return content;
  } catch (err) {
    if ((err as Error)?.name === 'AbortError') {
      await logGroqError('Groq request aborted (timeout)', { timeoutMs });
      return null;
    }
    await logGroqError('Groq fetch failed', { error: stringifyError(err) });
    console.error('Groq fetch error:', err);
    return null;
  } finally {
    clearTimeout(timeoutId);
  }
}
