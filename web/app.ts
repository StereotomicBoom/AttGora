const store = new Store();
const REPO = "StereotomicBoom/AttGora";

type Filter = "all" | "active" | "done";
let filter: Filter = "all";
let scale = 1;
let editingId: string | null = null;
let dragging = false;
let suppressClickUntil = 0;

const icons = {
  check: '<svg viewBox="0 0 24 24"><polyline points="5 12.5 10 17.5 19 7" fill="none" stroke="currentColor" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  star: (filled: boolean) =>
    `<svg viewBox="0 0 24 24"><path d="M12 2.9l2.75 5.82 6.38.78-4.7 4.38 1.2 6.32L12 17.08l-5.63 3.12 1.2-6.32-4.7-4.38 6.38-.78z" fill="${filled ? "currentColor" : "none"}" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/></svg>`,
  stopwatch: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><circle cx="12" cy="13.5" r="7.6"/><path d="M9.6 2.6h4.8M12 2.6v3.3M12 13.5V9.2M18.4 6.6l1.5-1.5"/></svg>',
  chevronUp: '<svg viewBox="0 0 24 24"><polyline points="5 15.5 12 8.5 19 15.5" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  chevronDown: '<svg viewBox="0 0 24 24"><polyline points="5 8.5 12 15.5 19 8.5" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  minus: '<svg viewBox="0 0 24 24"><path d="M5 12h14" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"/></svg>',
  plus: '<svg viewBox="0 0 24 24"><path d="M5 12h14M12 5v14" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"/></svg>',
};

function el<K extends keyof HTMLElementTagNameMap>(tag: K, cls = "", text?: string): HTMLElementTagNameMap[K] {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text != null) e.textContent = text;
  return e;
}

const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const newInput = $<HTMLTextAreaElement>("new-title");
const addButton = $<HTMLButtonElement>("add");
const list = $<HTMLDivElement>("list");
const empty = $<HTMLDivElement>("empty");
const remaining = $<HTMLSpanElement>("remaining");
const smaller = $<HTMLButtonElement>("smaller");
const bigger = $<HTMLButtonElement>("bigger");
const clearDone = $<HTMLButtonElement>("clear-done");

function visibleIds() {
  return store.items
    .filter((i) => (filter === "all" ? true : filter === "active" ? !i.done : i.done))
    .map((i) => i.id);
}

function alarmLabel(ref: number) {
  return new Date(fromRef(ref)).toLocaleTimeString("sv-SE", { hour: "2-digit", minute: "2-digit" });
}

function activeAlarm(item: TodoItem) {
  return item.alarm != null && fromRef(item.alarm) > Date.now() ? item.alarm : null;
}

function render() {
  const ids = visibleIds();
  list.replaceChildren(...ids.map((id, n) => renderRow(store.get(id)!, n + 1)));
  empty.hidden = ids.length > 0;
  empty.textContent = store.items.length === 0 ? "Inget att göra 🎉" : "Inga uppgifter här";
  remaining.textContent = `${store.remaining} kvar`;
  clearDone.disabled = !store.items.some((i) => i.done);
  addButton.disabled = !newInput.value.trim();
  smaller.disabled = scale <= 0.7;
  bigger.disabled = scale >= 2.0;
  document.querySelectorAll<HTMLButtonElement>(".segmented button").forEach((b) => b.classList.toggle("on", b.dataset.filter === filter));
}

function renderRow(item: TodoItem, number: number) {
  const wrap = el("div", "item");
  wrap.dataset.id = item.id;
  const row = el("div", "row");
  row.classList.toggle("done", item.done);
  row.classList.toggle("in-progress", item.inProgress);

  const num = el("span", "num", `${number}.`);

  const check = el("button", "check");
  check.innerHTML = item.done ? icons.check : "";
  check.title = "";
  check.setAttribute("aria-label", "Klar");
  check.addEventListener("click", () => store.update(item.id, { done: !item.done }));

  const star = el("button", "star");
  star.classList.toggle("on", !!item.priority);
  star.innerHTML = icons.star(!!item.priority);
  star.title = `Prioritet: ${item.priority ? "Medel" : "Ingen"} (klicka för att ändra)`;
  star.addEventListener("click", () => store.update(item.id, { priority: item.priority ? 0 : STARRED }));

  const alarm = el("button", "alarm");
  const active = activeAlarm(item);
  alarm.classList.toggle("on", active != null);
  alarm.innerHTML = icons.stopwatch;
  if (active != null) alarm.append(el("span", "alarm-time", alarmLabel(active)));
  alarm.disabled = item.done;
  alarm.setAttribute("aria-label", "Alarm");
  alarm.title = active != null
    ? "Alarm: " + new Date(fromRef(active)).toLocaleString("sv-SE", { day: "numeric", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" })
    : "Sätt alarm";
  alarm.addEventListener("click", () => {
    if (lastAlarmClose.id === item.id && Date.now() - lastAlarmClose.at < 400) return;
    openAlarm(alarm, item.id);
  });

  const area = el("div", "title-area");
  area.title = "Dubbelklicka: flytta överst";
  if (editingId === item.id) {
    area.append(editor(item));
  } else {
    const text = el("span", "title-text", item.title);
    text.title = item.done ? "" : "Klicka: pågår av/på · Håll in och dra: flytta · Dubbelklicka: ändra text";
    area.append(text);
  }

  for (const target of [num, area]) {
    let timer = 0;
    target.addEventListener("click", (e) => {
      if (editingId === item.id || Date.now() < suppressClickUntil) return;
      clearTimeout(timer);
      if (e.detail === 1 && !item.done) timer = window.setTimeout(() => store.update(item.id, { inProgress: !item.inProgress }), 280);
    });
    target.addEventListener("dblclick", (e) => {
      if (editingId === item.id) return;
      clearTimeout(timer);
      if ((e.target as HTMLElement).classList.contains("title-text")) startEditing(item.id);
      else store.moveToTop(item.id);
    });
  }

  row.addEventListener("contextmenu", async (e) => {
    e.preventDefault();
    const picked = await native("menu", {
      items: [
        { title: "Prioritet", submenu: [
          { id: "p0", title: "Ingen", checked: !item.priority },
          { id: "p2", title: "Medel", checked: !!item.priority },
        ] },
        { id: "delete", title: "Ta bort" },
      ] satisfies MenuEntry[],
    });
    if (picked === "p0") store.update(item.id, { priority: 0 });
    else if (picked === "p2") store.update(item.id, { priority: STARRED });
    else if (picked === "delete") store.delete(item.id);
  });

  row.addEventListener("pointerdown", (e) => startPress(e, wrap));

  row.append(num, check, star, alarm, area);
  wrap.append(row, el("div", "rule"));
  return wrap;
}

function editor(item: TodoItem) {
  const box = el("textarea", "title-edit");
  box.value = item.title;
  box.rows = 1;
  const fit = () => { box.style.height = "auto"; box.style.height = box.scrollHeight + "px"; };
  let finished = false;
  const finish = () => {
    if (finished) return;
    finished = true;
    const title = box.value.replace(/\n/g, " ").trim();
    editingId = null;
    if (title && title !== item.title) store.update(item.id, { title });
    else render();
  };
  box.addEventListener("input", fit);
  box.addEventListener("keydown", (e) => {
    if ((e.key === "Enter" && !e.shiftKey) || e.key === "Escape") { e.preventDefault(); finish(); }
  });
  box.addEventListener("blur", finish);
  requestAnimationFrame(() => { fit(); box.focus(); box.select(); });
  return box;
}

function startEditing(id: string) {
  editingId = id;
  render();
}

function startPress(e: PointerEvent, wrap: HTMLDivElement) {
  if (e.button !== 0 || editingId || (e.target as HTMLElement).closest("button, textarea")) return;
  const startY = e.clientY, startX = e.clientX;
  const cancel = () => {
    clearTimeout(timer);
    window.removeEventListener("pointermove", early);
    window.removeEventListener("pointerup", cancel);
  };
  const early = (m: PointerEvent) => { if (Math.hypot(m.clientX - startX, m.clientY - startY) > 6) cancel(); };
  const timer = window.setTimeout(() => { cancel(); beginDrag(wrap, startY); }, 350);
  window.addEventListener("pointermove", early);
  window.addEventListener("pointerup", cancel);
}

function beginDrag(wrap: HTMLDivElement, startY: number) {
  dragging = true;
  const items = [...list.children] as HTMLDivElement[];
  const from = items.indexOf(wrap);
  const rects = items.map((i) => i.getBoundingClientRect());
  const height = rects[from].height;
  let to = from;
  wrap.classList.add("dragging");
  document.body.classList.add("is-dragging");

  const move = (m: PointerEvent) => {
    const dy = m.clientY - startY;
    wrap.style.transform = `translateY(${dy}px)`;
    const center = rects[from].top + rects[from].height / 2 + dy;
    to = from;
    items.forEach((_, n) => {
      const mid = rects[n].top + rects[n].height / 2;
      if (n > from && center > mid) to = n;
      if (n < from && center < mid && to === from) to = n;
    });
    items.forEach((other, n) => {
      if (n === from) return;
      const shift = from < n && n <= to ? -height : to <= n && n < from ? height : 0;
      other.style.transform = shift ? `translateY(${shift}px)` : "";
    });
  };
  const up = () => {
    window.removeEventListener("pointermove", move);
    window.removeEventListener("pointerup", up);
    dragging = false;
    suppressClickUntil = Date.now() + 300;
    document.body.classList.remove("is-dragging");
    if (to !== from) store.move(visibleIds(), from, to);
    else render();
  };
  window.addEventListener("pointermove", move);
  window.addEventListener("pointerup", up);
}

function fitNewInput() {
  newInput.style.height = "auto";
  newInput.style.height = `${newInput.scrollHeight + newInput.offsetHeight - newInput.clientHeight}px`;
}

function add() {
  store.add(newInput.value);
  newInput.value = "";
  fitNewInput();
  render();
}

async function setScale(value: number) {
  scale = Math.min(2, Math.max(0.7, Math.round(value * 10) / 10));
  document.documentElement.style.setProperty("--s", String(scale));
  fitNewInput();
  await native("setScale", { value: scale });
  render();
}

function isNewer(a: string, b: string) {
  const x = a.split(".").map((n) => Number(n) || 0), y = b.split(".").map((n) => Number(n) || 0);
  for (let i = 0; i < Math.max(x.length, y.length); i++) {
    if ((x[i] ?? 0) !== (y[i] ?? 0)) return (x[i] ?? 0) > (y[i] ?? 0);
  }
  return false;
}

async function checkForUpdates(manual: boolean) {
  const current: string = await native("version");
  let release: { tag_name: string; html_url: string } | null = null;
  try {
    const res = await fetch(`https://api.github.com/repos/${REPO}/releases/latest`, { headers: { Accept: "application/vnd.github+json" } });
    if (res.ok) release = await res.json();
  } catch {}
  if (!release) {
    if (manual) native("dialog", { title: "Kunde inte söka efter uppdateringar", text: "Kontrollera internetanslutningen och försök igen." });
    return;
  }
  const latest = release.tag_name.replace(/^v/i, "");
  if (!isNewer(latest, current)) {
    if (manual) native("dialog", { title: "AttGöra är uppdaterad", text: `Du har den senaste versionen (${current}).` });
    return;
  }
  const choice = await native("dialog", { title: "Ny version av AttGöra", text: `Version ${latest} finns. Du har ${current}.`, buttons: ["Ladda ner", "Senare"] });
  if (choice === 0) native("open", { url: release.html_url });
}

window.todo = {
  focusNew: () => newInput.focus(),
  scaleBy: (delta) => setScale(scale + delta),
  resetScale: () => setScale(1),
  checkForUpdates,
  setAlarm: (id, alarm) => {
    closeAlarm?.();
    store.update(id, { alarm: alarm ?? undefined });
  },
};

newInput.addEventListener("input", () => { addButton.disabled = !newInput.value.trim(); fitNewInput(); });
newInput.addEventListener("keydown", (e) => {
  if (e.key === "Enter" && !e.shiftKey && !e.isComposing) { e.preventDefault(); add(); }
});
window.addEventListener("resize", fitNewInput);
addButton.addEventListener("click", add);
smaller.addEventListener("click", () => setScale(scale - 0.1));
bigger.addEventListener("click", () => setScale(scale + 0.1));
clearDone.addEventListener("click", () => store.clearCompleted());
document.querySelectorAll<HTMLButtonElement>(".segmented button").forEach((b) =>
  b.addEventListener("click", () => { filter = b.dataset.filter as Filter; render(); }));
smaller.innerHTML = icons.minus;
bigger.innerHTML = icons.plus;

store.onChange = render;
setInterval(() => { if (!editingId && !dragging && !closeAlarm) render(); }, 30_000);

(async () => {
  scale = await native("getScale");
  document.documentElement.style.setProperty("--s", String(scale));
  fitNewInput();
  await store.load();
  render();
  newInput.focus();
  checkForUpdates(false);
})();
