const SYNC_URL = "https://attgora-sync.gustavlundstrom2.workers.dev";
const SYNC_EVERY_MS = 60 * 1000;
const KEY_ALPHABET = "abcdefghjkmnpqrstuvwxyz023456789";

interface Snapshot {
  v: 1;
  items: TodoItem[];
  deleted: Record<string, number>;
  orderModified: number;
  lists?: TodoList[];
  note?: Note;
}

interface SyncState {
  device: string;
  key: string;
  deleted: Record<string, number>;
  orderModified: number;
  pushed: string;
  last: number;
}

type SyncStatus = "off" | "syncing" | "ok" | "offline" | "error";

class SyncError extends Error {
  constructor(message: string, readonly status = 0, readonly offline = false) { super(message); }
}

const Sync = (() => {
  let state: SyncState;
  let status: SyncStatus = "off";
  let lastError = "";
  let running: Promise<void> | null = null;
  let again = false;
  let soon = 0;
  const listeners = new Set<() => void>();

  const persist = () => native("saveSync", { json: JSON.stringify({ ...state, deleted: store.deleted, orderModified: store.orderModified }) });
  const setStatus = (s: SyncStatus, error = "") => { status = s; lastError = error; listeners.forEach((f) => f()); };
  const normalize = (key: string) => key.toLowerCase().replace(/[^a-z0-9]/g, "");

  async function request(path: string, key: string, opts: { method?: string; body?: unknown } = {}) {
    let res: Response;
    try {
      res = await fetch(SYNC_URL + path, {
        method: opts.method ?? "GET",
        headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
        body: opts.body === undefined ? undefined : JSON.stringify(opts.body),
      });
    } catch {
      throw new SyncError("Kunde inte nå synkservern. Kontrollera internetanslutningen.", 0, true);
    }
    const text = await res.text();
    let out: any = null;
    try { out = text ? JSON.parse(text) : null; } catch {}
    if (!res.ok) throw new SyncError(out?.error || `Servern svarade ${res.status}.`, res.status);
    return out;
  }

  const snapshot = (): Snapshot => ({ v: 1, items: store.items, deleted: store.deleted, orderModified: store.orderModified, lists: store.lists, note: store.note });

  function newest<T extends { id: string; modified?: number }>(all: T[], deleted: Record<string, number>) {
    const found = new Map<string, T>();
    for (const x of all) {
      const have = found.get(x.id);
      if (!have || (x.modified ?? 0) > (have.modified ?? 0)) found.set(x.id, x);
    }
    for (const [id, x] of found) if ((deleted[id] ?? -Infinity) >= (x.modified ?? 0)) found.delete(id);
    return found;
  }

  function merge(local: Snapshot, other: Snapshot): Snapshot {
    const deleted = { ...local.deleted };
    for (const [id, at] of Object.entries(other.deleted ?? {})) deleted[id] = Math.max(deleted[id] ?? 0, at);

    const items = newest([...local.items, ...(other.items ?? [])], deleted);
    const lists = [...newest([...(local.lists ?? []), ...(other.lists ?? [])], deleted).values()].sort((a, b) => a.created - b.created);
    const localNote = local.note ?? { text: "", modified: 0 };
    const note = (other.note?.modified ?? 0) > localNote.modified ? other.note! : localNote;

    const otherWins = (other.orderModified ?? 0) > local.orderModified;
    const [base, rest] = otherWins ? [other.items, local.items] : [local.items, other.items ?? []];
    const order = base.map((i) => i.id).filter((id) => items.has(id));
    rest.forEach((item, n) => {
      if (!items.has(item.id) || order.includes(item.id)) return;
      let at = 0;
      for (let k = n - 1; k >= 0; k--) {
        const before = order.indexOf(rest[k].id);
        if (before >= 0) { at = before + 1; break; }
      }
      order.splice(at, 0, item.id);
    });

    return { v: 1, items: order.map((id) => items.get(id)!), deleted, orderModified: Math.max(local.orderModified, other.orderModified ?? 0), lists, note };
  }

  async function syncOnce() {
    const key = state.key;
    const rows: { device: string; data: string }[] = await request(`/snapshots?except=${state.device}`, key);
    if (state.key !== key) return;
    let merged = snapshot();
    for (const row of rows) {
      try { merged = merge(merged, JSON.parse(row.data)); } catch {}
    }
    const before = JSON.stringify(snapshot());
    if (JSON.stringify(merged) !== before) {
      if (busy()) { schedule(3000); return; }
      store.replace(merged.items, merged.deleted, merged.orderModified, merged.lists ?? [], merged.note ?? store.note);
    }
    const data = JSON.stringify(snapshot());
    if (data !== state.pushed) {
      await request(`/snapshots/${state.device}`, key, { method: "PUT", body: { name: deviceName(), data } });
      state.pushed = data;
    }
    state.last = Date.now();
    persist();
  }

  const busy = () => editingId != null || dragging || closeAlarm != null;
  const deviceName = () => (platform === "ios" ? "iPhone" : "Mac");

  function run(): Promise<void> {
    if (!state.key) return Promise.resolve();
    if (running) { again = true; return running; }
    setStatus("syncing");
    running = (async () => {
      try {
        do { again = false; await syncOnce(); } while (again);
        setStatus("ok");
      } catch (err) {
        if (!state.key) return;
        const e = err as SyncError;
        setStatus(e.offline ? "offline" : "error", e.message);
      } finally {
        running = null;
      }
    })();
    return running;
  }

  function schedule(ms = 1500) {
    clearTimeout(soon);
    soon = window.setTimeout(run, ms);
  }

  function connect(key: string) {
    state.key = key;
    state.pushed = "";
    persist();
    return run();
  }

  return {
    get status() { return status; },
    get error() { return lastError; },
    get key() { return state.key.match(/.{1,4}/g)?.join("-") ?? ""; },
    get signedIn() { return !!state.key; },
    get last() { return state.last; },
    onStatus(f: () => void) { listeners.add(f); return () => listeners.delete(f); },

    async load() {
      let saved: Partial<SyncState> = {};
      try { saved = JSON.parse(await native("loadSync")) ?? {}; } catch {}
      state = {
        device: saved.device || [...crypto.getRandomValues(new Uint8Array(16))].map((b) => b.toString(16).padStart(2, "0")).join(""),
        key: saved.key ?? "",
        deleted: saved.deleted ?? {},
        orderModified: saved.orderModified ?? 0,
        pushed: saved.pushed ?? "",
        last: saved.last ?? 0,
      };
      store.deleted = state.deleted;
      store.orderModified = state.orderModified;
      store.onLocalChange = () => { persist(); schedule(); };
      if (!saved.device) persist();
      setStatus(state.key ? "ok" : "off");
      setInterval(run, SYNC_EVERY_MS);
      window.addEventListener("focus", () => schedule(200));
      document.addEventListener("visibilitychange", () => { if (!document.hidden) schedule(200); });
      run();
    },

    create() {
      const bytes = crypto.getRandomValues(new Uint8Array(24));
      return connect([...bytes].map((b) => KEY_ALPHABET[b % KEY_ALPHABET.length]).join(""));
    },

    async join(input: string) {
      const key = normalize(input);
      if (key.length < 24) throw new Error("Nyckeln är för kort. Kopiera hela nyckeln från din andra enhet.");
      await request(`/snapshots?except=${state.device}`, key);
      return connect(key);
    },

    async disconnect() {
      const key = state.key;
      state.key = "";
      state.pushed = "";
      persist();
      setStatus("off");
      try { if (key) await request(`/snapshots/${state.device}`, key, { method: "DELETE" }); } catch {}
    },

    now: run,
  };
})();
