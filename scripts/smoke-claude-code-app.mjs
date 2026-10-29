import { setTimeout as delay } from 'node:timers/promises';

const endpoint = 'http://127.0.0.1:3210/trpc/lambda/config.getGlobalConfig';
const maximumWaitMs = 90_000;
const isRecord = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);

const validateCatalog = (body) => {
  if (!isRecord(body) || Object.hasOwn(body, 'error')) return 'trpc-error-response';
  const providers = body?.result?.data?.json?.serverConfig?.aiProvider;
  if (!isRecord(providers)) return 'missing-provider-catalog';
  for (const provider of ['openai', 'anthropic', 'claude-code']) {
    if (!Object.hasOwn(providers, provider) || !isRecord(providers[provider])) {
      return 'missing-required-provider';
    }
  }
  const worker = providers['claude-code'];
  const enabledAnnotation =
    body?.result?.data?.meta?.values?.['serverConfig.aiProvider.claude-code.enabled'];
  // SuperJSON represents undefined as null with this exact metadata annotation.
  const enabled =
    worker.enabled === null &&
    Array.isArray(enabledAnnotation) &&
    enabledAnnotation.length === 1 &&
    enabledAnnotation[0] === 'undefined'
      ? undefined
      : worker.enabled;
  if (enabled !== undefined && enabled !== false) return 'worker-provider-enabled';
  if (!Array.isArray(worker.serverModelLists) || worker.serverModelLists.length !== 0) {
    return 'unexpected-static-worker-models';
  }
  return undefined;
};

const main = async () => {
  if (process.env.NODE_ENV !== 'production' || process.env.CLAUDE_CODE_SERVER_ENABLED !== '0') {
    console.error('App runtime smoke failed: expected production mode with the worker disabled.');
    process.exitCode = 1;
    return;
  }

  const deadline = Date.now() + maximumWaitMs;
  let failure = 'server-not-ready';
  while (Date.now() < deadline) {
    try {
      const response = await fetch(endpoint, {
        headers: { accept: 'application/json' },
        redirect: 'manual',
        signal: AbortSignal.timeout(Math.max(1, Math.min(5_000, deadline - Date.now()))),
      });
      if (response.status !== 200) {
        failure = `http-${response.status}`;
        await response.body?.cancel();
      } else if (!response.headers.get('content-type')?.includes('application/json')) {
        failure = 'unexpected-content-type';
        await response.body?.cancel();
      } else {
        const validationError = validateCatalog(await response.json());
        if (!validationError) {
          console.info('App runtime smoke passed: public provider catalog loaded; Claude Code server remains disabled.');
          return;
        }
        failure = validationError;
      }
    } catch {
      failure = 'request-or-json-failed';
    }
    const remaining = deadline - Date.now();
    if (remaining > 0) await delay(Math.min(1_000, remaining));
  }
  // Never print the response body, provider configuration, environment, or raw exceptions.
  console.error(`App runtime smoke failed within ${maximumWaitMs / 1_000}s: ${failure}.`);
  process.exitCode = 1;
};

await main();
