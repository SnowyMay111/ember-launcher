// Forwards a small allowlist of CurseForge API v1 calls and adds the API key, which only lives in the
// function secret CURSEFORGE_API_KEY. The launcher calls it with the project's public anon key.
// It is not a browser API: no CORS headers, so a web page cannot spend the key from a visitor's browser.
const UPSTREAM = "https://api.curseforge.com";

const MAX_BODY_BYTES = 64 * 1024;
const MAX_DRAIN_BYTES = 1024 * 1024;
const MAX_QUERY_CHARS = 2000;
const UPSTREAM_TIMEOUT_MS = 20_000;
// Per caller address and per function instance, so it is a brake on a flood, not an exact quota.
// Browsing and installing a pack stay far below it.
const LIMIT_PER_MINUTE = 300;
const hits = new Map<string, { minute: number; count: number }>();

// GET: search, one mod, its files, one file, a download URL. POST: several mods at once.
const GET_ALLOWED = [
  /^\/v1\/mods\/search$/,
  /^\/v1\/mods\/\d+$/,
  /^\/v1\/mods\/\d+\/files$/,
  /^\/v1\/mods\/\d+\/files\/\d+$/,
  /^\/v1\/mods\/\d+\/files\/\d+\/download-url$/,
];
const POST_ALLOWED = [/^\/v1\/mods$/, /^\/v1\/mods\/files$/];

function reply(status: number, error: string): Response {
  return new Response(JSON.stringify({ error }), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });
}

function overLimit(req: Request): boolean {
  const address = (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim() || "unknown";
  const minute = Math.floor(Date.now() / 60_000);
  const entry = hits.get(address);
  if (!entry || entry.minute !== minute) {
    if (hits.size > 5000) hits.clear();
    hits.set(address, { minute, count: 1 });
    return false;
  }
  entry.count += 1;
  return entry.count > LIMIT_PER_MINUTE;
}

// The request body, or null when it is larger than the limit (whatever content-length claims).
async function readBody(req: Request): Promise<Uint8Array | null> {
  const reader = req.body?.getReader();
  if (!reader) return new Uint8Array();
  const chunks: Uint8Array[] = [];
  let size = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    // Over the limit the rest is read and dropped: answering before an HTTP/2 upload ends stalls the caller.
    if (size <= MAX_BODY_BYTES) {
      chunks.push(value);
    } else if (size > MAX_DRAIN_BYTES) {
      await reader.cancel();
      break;
    }
  }
  if (size > MAX_BODY_BYTES) return null;
  const body = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    body.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return body;
}

Deno.serve(async (req: Request): Promise<Response> => {
  const url = new URL(req.url);
  // The function is served under /functions/v1/curseforge-proxy; keep only what follows.
  const path = url.pathname.replace(/^.*\/curseforge-proxy/, "");
  const allowed = req.method === "GET" ? GET_ALLOWED : req.method === "POST" ? POST_ALLOWED : [];
  if (!allowed.some((re) => re.test(path)) || url.search.length > MAX_QUERY_CHARS) {
    return reply(403, "not allowed");
  }
  if (overLimit(req)) return reply(429, "too many requests");

  const key = Deno.env.get("CURSEFORGE_API_KEY");
  if (!key) return reply(503, "not configured");

  let body: Uint8Array | undefined;
  if (req.method === "POST") {
    const read = await readBody(req);
    if (!read) return reply(413, "body too large");
    body = read;
  }

  // Not "/v1/mods/search/": that path is served from a cache that ignores searchFilter, sortField and sortOrder,
  // so every query came back with the same wrong page. The plain path needs a User-Agent to get past the 403.
  let upstream: Response;
  try {
    upstream = await fetch(UPSTREAM + path + url.search, {
      method: req.method,
      headers: {
        "x-api-key": key,
        accept: "application/json",
        "content-type": "application/json",
        "user-agent": "Ember-Launcher/1.0 (+https://github.com/SnowyMay111/ember-launcher)",
      },
      body,
      signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS),
    });
  } catch {
    return reply(504, "upstream did not answer");
  }
  // Only good answers may be cached: a cached error would hide CurseForge coming back.
  return new Response(await upstream.text(), {
    status: upstream.status,
    headers: {
      "content-type": "application/json",
      "cache-control": upstream.ok ? "public, max-age=300" : "no-store",
    },
  });
});
