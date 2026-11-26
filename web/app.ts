const store = new Store();
const REPO = "StereotomicBoom/AttGora";

let scale = 1;
let editingId: string | null = null;
let dragging = false;
let suppressClickUntil = 0;
let platform: "mac" | "ios" = "mac";

const icons = {
  check: '<svg viewBox="0 0 24 24"><polyline points="5 12.5 10 17.5 19 7" fill="none" stroke="currentColor" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  star: (filled: boolean) =>
    `<svg viewBox="0 0 24 24"><path d="M12 2.9l2.75 5.82 6.38.78-4.7 4.38 1.2 6.32L12 17.08l-5.63 3.12 1.2-6.32-4.7-4.38 6.38-.78z" fill="${filled ? "currentColor" : "none"}" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/></svg>`,
  stopwatch: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><circle cx="12" cy="13.5" r="7.6"/><path d="M9.6 2.6h4.8M12 2.6v3.3M12 13.5V9.2M18.4 6.6l1.5-1.5"/></svg>',
  chevronUp: '<svg viewBox="0 0 24 24"><polyline points="5 15.5 12 8.5 19 15.5" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  chevronDown: '<svg viewBox="0 0 24 24"><polyline points="5 8.5 12 15.5 19 8.5" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  minus: '<svg viewBox="0 0 24 24"><path d="M5 12h14" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"/></svg>',
  plus: '<svg viewBox="0 0 24 24"><path d="M5 12h14M12 5v14" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"/></svg>',
  lists: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"><rect x="5.4" y="5" width="13.1" height="15" transform="rotate(-8 12 5.25)" style="fill: var(--btn)"/><path d="M5.4 5H18.5V17L15.5 20H5.4Z" transform="rotate(3 12 5.25)" style="fill: var(--btn)"/><path d="M18.5 17H15.5V20Z" transform="rotate(3 12 5.25)" fill="currentColor"/><circle cx="12" cy="5.25" r="2.2" fill="currentColor" stroke="none"/></svg>',
  pencil: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M4.5 19.5l1-4.2L16.2 4.6a2.1 2.1 0 0 1 3 3L8.5 18.4z"/><path d="M14.4 6.4l3 3"/></svg>',
  theme: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="8" fill="none" stroke="currentColor" stroke-width="2"/><path d="M12 4a8 8 0 0 1 0 16z" fill="currentColor"/></svg>',
  cloud: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><path d="M7 18.5h10.5a4 4 0 0 0 .6-7.95A6 6 0 0 0 6.6 9.1 4.7 4.7 0 0 0 7 18.5z"/></svg>',
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
const syncButton = $<HTMLButtonElement>("sync");
const themeButton = $<HTMLButtonElement>("theme");
const newListButton = $<HTMLButtonElement>("new-list");
const listsButton = $<HTMLButtonElement>("lists");
const noteButton = $<HTMLButtonElement>("note");
const listName = $<HTMLButtonElement>("list-name");

function visibleIds() {
  return store.visible.map((i) => i.id);
}

function alarmLabel(ref: number) {
  return new Date(fromRef(ref)).toLocaleTimeString("sv-SE", { hour: "2-digit", minute: "2-digit" });
}

function activeAlarm(item: TodoItem) {
  return item.alarm != null && fromRef(item.alarm) > Date.now() ? item.alarm : null;
}

async function saveAsText(item: TodoItem) {
  const when = (ref: number) =>
    new Date(fromRef(ref)).toLocaleString("sv-SE", { day: "numeric", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" });
  const status = item.done ? "Klar" : item.inProgress ? "Pågår" : "Kvar";
  const active = activeAlarm(item);
  const lines = [
    item.title,
    "",
    "Status: " + status,
    ...(item.priority ? ["Prioritet: ★"] : []),
    ...(active != null ? ["Alarm: " + when(active)] : []),
    "Skapad: " + when(item.created),
  ];
  const name = (item.title.replace(/[\/:\\]/g, "-").slice(0, 60).trim() || "Uppgift") + ".txt";
  try {
    await native("saveFile", { name, text: lines.join("\n") + "\n" });
  } catch (err) {
    await native("dialog", { title: "Kunde inte spara", text: String(err) });
  }
}

function render() {
  const ids = visibleIds();
  list.replaceChildren(...ids.map((id, n) => renderRow(store.get(id)!, n + 1)));
  empty.hidden = ids.length > 0;
  empty.textContent = "Inget att göra 🎉";
  remaining.textContent = `${store.remaining} kvar`;
  clearDone.disabled = !store.visible.some((i) => i.done);
  listName.textContent = store.currentList.name;
  noteButton.classList.toggle("on", !!store.note.text.trim());
  addButton.disabled = !newInput.value.trim();
  smaller.disabled = scale <= 0.7;
  bigger.disabled = scale >= 2.0;
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

  row.addEventListener("contextmenu", (e) => {
    e.preventDefault();
    openRowMenu(item);
  });

  row.addEventListener("pointerdown", (e) => startPress(e, wrap, item));

  row.append(num, check, star, alarm, area);
  wrap.append(row, el("div", "rule"));
  return wrap;
}

async function openRowMenu(item: TodoItem) {
  const picked = await native("menu", {
    items: [
      { title: "Prioritet", submenu: [
        { id: "p0", title: "Ingen", checked: !item.priority },
        { id: "p2", title: "Medel", checked: !!item.priority },
      ] },
      { id: "save", title: "Spara som…" },
      { separator: true },
      { id: "delete", title: "Ta bort" },
    ] satisfies MenuEntry[],
  });
  if (picked === "save") saveAsText(item);
  else if (picked === "p0") store.update(item.id, { priority: 0 });
  else if (picked === "p2") store.update(item.id, { priority: STARRED });
  else if (picked === "delete") store.delete(item.id);
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

function startPress(e: PointerEvent, wrap: HTMLDivElement, item: TodoItem) {
  if (e.button !== 0 || editingId || (e.target as HTMLElement).closest("button, textarea")) return;
  const startY = e.clientY, startX = e.clientX;
  const cancel = () => {
    clearTimeout(timer);
    window.removeEventListener("pointermove", early);
    window.removeEventListener("pointerup", cancel);
    window.removeEventListener("pointercancel", cancel);
  };
  const early = (m: PointerEvent) => { if (Math.hypot(m.clientX - startX, m.clientY - startY) > 6) cancel(); };
  const timer = window.setTimeout(() => { cancel(); beginDrag(wrap, startY, item); }, 350);
  window.addEventListener("pointermove", early);
  window.addEventListener("pointerup", cancel);
  window.addEventListener("pointercancel", cancel);
}

function beginDrag(wrap: HTMLDivElement, startY: number, item: TodoItem) {
  dragging = true;
  const items = [...list.children] as HTMLDivElement[];
  const from = items.indexOf(wrap);
  const rects = items.map((i) => i.getBoundingClientRect());
  const height = rects[from].height;
  let to = from;
  let moved = 0;
  wrap.classList.add("dragging");
  document.body.classList.add("is-dragging");

  const move = (m: PointerEvent) => {
    const dy = m.clientY - startY;
    moved = Math.max(moved, Math.abs(dy));
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
    window.removeEventListener("pointercancel", up);
    dragging = false;
    suppressClickUntil = Date.now() + 300;
    document.body.classList.remove("is-dragging");
    if (to !== from) store.move(visibleIds(), from, to);
    else render();
    if (platform === "ios" && moved < 8) openRowMenu(item);
  };
  window.addEventListener("pointermove", move);
  window.addEventListener("pointerup", up);
  window.addEventListener("pointercancel", up);
}

function clearPastAlarms() {
  for (const i of store.items) {
    if (i.alarm != null && fromRef(i.alarm) <= Date.now()) store.update(i.id, { alarm: undefined });
  }
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
  openSync,
  newList: () => store.addList(),
  openNote,
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
const themes = [["light", "Ljust"], ["mid", "Mellan"], ["dark", "Mörkt"]];
const paintTheme = () => {
  const current = themes.find(([id]) => id === document.documentElement.dataset.theme) ?? themes[0];
  themeButton.title = `Utseende: ${current[1]} (klicka för att byta)`;
};
themeButton.innerHTML = icons.theme;
themeButton.addEventListener("click", () => {
  const n = themes.findIndex(([id]) => id === document.documentElement.dataset.theme);
  const next = themes[(n + 1) % themes.length][0];
  document.documentElement.dataset.theme = next;
  native("setTheme", { value: next });
  paintTheme();
});
new MutationObserver(paintTheme).observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] });
paintTheme();
newListButton.innerHTML = icons.plus;
listsButton.innerHTML = icons.lists;
noteButton.innerHTML = icons.pencil;
newListButton.addEventListener("click", () => { store.addList(); if (platform === "mac") newInput.focus(); });
listsButton.addEventListener("click", openListMenu);
listName.addEventListener("click", openListMenu);
noteButton.addEventListener("click", openNote);
smaller.innerHTML = icons.minus;
bigger.innerHTML = icons.plus;
syncButton.innerHTML = icons.cloud;
syncButton.addEventListener("click", openSync);
const paintSync = () => {
  syncButton.classList.toggle("on", Sync.signedIn);
  syncButton.classList.toggle("problem", Sync.status === "error");
  syncButton.title = Sync.signedIn ? "Synk: " + (statusText() || "på") : "Synk: av";
};

store.onChange = render;
document.addEventListener("touchmove", (e) => { if (dragging) e.preventDefault(); }, { passive: false });
setInterval(() => { if (!editingId && !dragging && !closeAlarm) render(); }, 30_000);

(async () => {
  platform = await native("platform").catch(() => "mac");
  document.documentElement.dataset.platform = platform;
  scale = await native("getScale");
  document.documentElement.style.setProperty("--s", String(scale));
  fitNewInput();
  await store.load();
  render();
  if (platform === "mac") newInput.focus();
  await Sync.load();
  Sync.onStatus(paintSync);
  paintSync();
  if (platform === "mac") checkForUpdates(false);
  if (platform === "ios") {
    clearPastAlarms();
    document.addEventListener("visibilitychange", () => { if (!document.hidden) clearPastAlarms(); });
  }
  native("ready");
})();
