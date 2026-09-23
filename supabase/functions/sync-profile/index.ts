import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function configuredKeys(name: string): string[] {
  const raw = Deno.env.get(name);
  if (!raw) return [];
  try {
    const decoded = JSON.parse(raw);
    return typeof decoded === "object" && decoded !== null
      ? Object.values(decoded).filter((value): value is string =>
          typeof value === "string"
        )
      : [];
  } catch {
    return [raw];
  }
}

function requestKey(request: Request): string | null {
  const apiKey = request.headers.get("apikey");
  if (apiKey) return apiKey;
  const authorization = request.headers.get("authorization");
  return authorization?.startsWith("Bearer ")
    ? authorization.substring("Bearer ".length)
    : null;
}

function validPayload(value: unknown): value is Record<string, unknown> {
  if (typeof value !== "object" || value === null) return false;
  const payload = value as Record<string, unknown>;
  return payload.version === 1 &&
    Array.isArray(payload.items) && payload.items.length <= 10000 &&
    Array.isArray(payload.attempts) && payload.attempts.length <= 100000 &&
    Array.isArray(payload.sessions) && payload.sessions.length <= 10000;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const allowedKeys = [
    ...configuredKeys("SUPABASE_PUBLISHABLE_KEYS"),
    ...configuredKeys("SUPABASE_ANON_KEY"),
  ];
  const key = requestKey(request);
  if (!key || !allowedKeys.includes(key)) return json({ error: "unauthorized" }, 401);

  const contentLength = Number(request.headers.get("content-length") ?? "0");
  if (contentLength > 2_000_000) return json({ error: "payload_too_large" }, 413);

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const nickname = typeof body.nickname === "string"
    ? body.nickname.trim().toLowerCase()
    : "";
  if (!/^[a-z0-9_-]{3,24}$/.test(nickname)) {
    return json({ error: "invalid_nickname" }, 400);
  }
  if (!validPayload(body.payload)) return json({ error: "invalid_payload" }, 400);

  const url = Deno.env.get("SUPABASE_URL");
  const secretKeys = configuredKeys("SUPABASE_SECRET_KEYS");
  const secret = secretKeys[0] ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !secret) return json({ error: "server_not_configured" }, 500);

  const admin = createClient(url, secret, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await admin.rpc("merge_sync_profile", {
    p_nickname: nickname,
    p_payload: body.payload,
  });
  if (error) {
    console.error(error);
    return json({ error: "sync_failed" }, 500);
  }
  const result = Array.isArray(data) ? data[0] : data;
  if (!result?.payload) return json({ error: "empty_result" }, 500);
  return json({
    payload: result.payload,
    revision: result.revision,
    updatedAt: result.updated_at,
  });
});
