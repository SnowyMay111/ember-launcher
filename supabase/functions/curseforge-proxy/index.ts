// Forwards a small allowlist of CurseForge API v1 calls and adds the API key, which only lives in the
// function secret CURSEFORGE_API_KEY. The launcher calls it with the project's public anon key.
const UPSTREAM = "https://api.curseforge.com";

const CORS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, apikey, content-type",
};

// GET: search, one mod, its files, one file, a download URL. POST: several mods at once.
const GET_ALLOWED = [
  /^\/v1\/mods\/search$/,
  /^\/v1\/mods\/\d+$/,
  /^\/v1\/mods\/\d+\/files$/,
  /^\/v1\/mods\/\d+\/files\/\d+$/,
  /^\/v1\/mods\/\d+\/files\/\d+\/download-url$/,
];
const POST_ALLOWED = [/^\/v1\/mods$/, /^\/v1\/mods\/files$/];

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });

  const url = new URL(req.url);
  // The function is served under /functions/v1/curseforge-proxy; keep only what follows.
  const path = url.pathname.replace(/^.*\/curseforge-proxy/, "");
  const allowed = req.method === "GET" ? GET_ALLOWED : req.method === "POST" ? POST_ALLOWED : [];
  if (!allowed.some((re) => re.test(path))) {
    return new Response(JSON.stringify({ error: "not allowed" }), { status: 403, headers: CORS });
  }

  const key = Deno.env.get("CURSEFORGE_API_KEY");
  if (!key) return new Response(JSON.stringify({ error: "not configured" }), { status: 503, headers: CORS });

  // Not "/v1/mods/search/": that path is served from a cache that ignores searchFilter, sortField and sortOrder,
  // so every query came back with the same wrong page. The plain path needs a User-Agent to get past the 403.
  const upstream = await fetch(UPSTREAM + path + url.search, {
    method: req.method,
    headers: {
      "x-api-key": key,
      accept: "application/json",
      "content-type": "application/json",
      "user-agent": "Ember-Launcher/1.0 (+https://github.com/SnowyMay111/ember-launcher)",
    },
    body: req.method === "POST" ? await req.text() : undefined,
  });
  return new Response(await upstream.text(), {
    status: upstream.status,
    headers: { ...CORS, "content-type": "application/json", "cache-control": "public, max-age=300" },
  });
});
