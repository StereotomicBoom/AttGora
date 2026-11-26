interface Env { DB: D1Database }

const MAX_DATA = 2_000_000;
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Authorization, Content-Type",
  "Access-Control-Max-Age": "86400",
};

const reply = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

async function spaceOf(request: Request) {
  const key = (request.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "").toLowerCase().replace(/[^a-z0-9]/g, "");
  if (key.length < 24) return null;
  const hash = await crypto.subtle.digest("SHA-256", new TextEncoder().encode("attgora:" + key));
  return [...new Uint8Array(hash)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
    const url = new URL(request.url);
    const space = await spaceOf(request);
    if (!space) return reply({ error: "Ogiltig synknyckel." }, 401);

    if (url.pathname === "/snapshots" && request.method === "GET") {
      const except = url.searchParams.get("except") ?? "";
      const { results } = await env.DB.prepare("SELECT device, name, data, updated_at FROM snapshots WHERE space = ? AND device != ?")
        .bind(space, except).all();
      return reply(results);
    }

    const match = url.pathname.match(/^\/snapshots\/([0-9a-f]{32})$/);
    if (match && request.method === "PUT") {
      const body = await request.json<{ name?: string; data?: string }>().catch(() => null);
      if (typeof body?.data !== "string" || body.data.length > MAX_DATA) return reply({ error: "Ogiltig data." }, 400);
      await env.DB.prepare(
        "INSERT INTO snapshots (space, device, name, data, updated_at) VALUES (?, ?, ?, ?, ?) " +
        "ON CONFLICT (space, device) DO UPDATE SET name = excluded.name, data = excluded.data, updated_at = excluded.updated_at")
        .bind(space, match[1], String(body.name ?? "").slice(0, 60), body.data, Date.now()).run();
      return reply({ ok: true });
    }
    if (match && request.method === "DELETE") {
      await env.DB.prepare("DELETE FROM snapshots WHERE space = ? AND device = ?").bind(space, match[1]).run();
      return reply({ ok: true });
    }

    return reply({ error: "Hittades inte." }, 404);
  },
};
