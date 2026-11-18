type Part = "hour" | "minute";

let closeAlarm: (() => void) | null = null;
let lastAlarmClose = { id: "", at: 0 };

function nextOccurrence(time: Date) {
  const now = new Date();
  const today = new Date(now);
  today.setHours(time.getHours(), time.getMinutes(), 0, 0);
  if (today <= now) today.setDate(today.getDate() + 1);
  return today;
}

function openAlarm(anchor: HTMLElement, id: string) {
  closeAlarm?.();
  const item = store.get(id);
  if (!item) return;

  const soon = new Date(Date.now() + 15 * 60 * 1000);
  let date = item.alarm != null && fromRef(item.alarm) > Date.now() ? new Date(fromRef(item.alarm)) : soon;
  let hovered: Part | null = null;
  let typed = "";
  let scrollAccum = 0;

  const pop = el("div", "popover");
  const arrow = el("div", "popover-arrow");
  const heading = el("div", "popover-heading", "Alarm");
  const title = el("div", "popover-title", item.title);

  const clock = el("div", "clock");
  const digits = el("div", "clock-digits");
  const seg = (part: Part) => {
    const s = el("span", "clock-seg");
    s.tabIndex = 0;
    s.dataset.part = part;
    s.addEventListener("mousedown", (e) => { e.preventDefault(); s.focus(); });
    s.addEventListener("focus", () => { typed = ""; });
    s.addEventListener("mouseenter", () => { hovered = part; });
    s.addEventListener("mouseleave", () => { if (hovered === part) hovered = null; });
    s.addEventListener("keydown", (e) => {
      if (e.key === "ArrowUp") step(part, 1);
      else if (e.key === "ArrowDown") step(part, -1);
      else if (e.key === "ArrowLeft") hour.focus();
      else if (e.key === "ArrowRight") minute.focus();
      else if (/^\d$/.test(e.key)) type(e.key, part);
      else return;
      e.preventDefault();
    });
    return s;
  };
  const hour = seg("hour");
  const minute = seg("minute");
  digits.append(hour, el("span", "clock-colon", ":"), minute);

  const focused = (): Part | null => (document.activeElement as HTMLElement | null)?.dataset?.part as Part ?? null;
  const chevron = (up: boolean) => {
    const b = el("button", "chevron");
    b.innerHTML = up ? icons.chevronUp : icons.chevronDown;
    b.tabIndex = -1;
    b.addEventListener("mousedown", (e) => e.preventDefault());
    b.addEventListener("click", () => step(focused() ?? "minute", up ? 1 : -1));
    return b;
  };
  const chevrons = el("div", "chevrons");
  chevrons.append(chevron(true), chevron(false));
  clock.append(digits, chevrons);

  clock.addEventListener("wheel", (e) => {
    e.preventDefault();
    const part = focused() ?? hovered ?? "minute";
    let dy = -e.deltaY;
    if ((e as any).webkitDirectionInvertedFromDevice) dy = -dy;
    const wheelDelta = (e as any).wheelDeltaY as number;
    if (wheelDelta && wheelDelta % 120 === 0) {
      if (dy !== 0) step(part, dy > 0 ? 1 : -1);
      return;
    }
    scrollAccum += dy;
    while (Math.abs(scrollAccum) >= 12) {
      step(part, scrollAccum > 0 ? 1 : -1);
      scrollAccum -= scrollAccum > 0 ? 12 : -12;
    }
  }, { passive: false });

  const value = (part: Part) => (part === "hour" ? date.getHours() : date.getMinutes());
  const setPart = (part: Part, v: number) => {
    date = new Date(date);
    if (part === "hour") date.setHours(v); else date.setMinutes(v);
    date.setSeconds(0, 0);
    paint();
  };
  const step = (part: Part, delta: number) => {
    const max = part === "hour" ? 24 : 60;
    setPart(part, (((value(part) + delta) % max) + max) % max);
  };
  const type = (d: string, part: Part) => {
    typed = (typed + d).slice(-2);
    const v = Number(typed);
    if (v <= (part === "hour" ? 23 : 59)) setPart(part, v);
    if (typed.length === 2) {
      typed = "";
      if (part === "hour") minute.focus();
    }
  };
  const paint = () => {
    hour.textContent = String(date.getHours()).padStart(2, "0");
    minute.textContent = String(date.getMinutes()).padStart(2, "0");
  };

  const button = (label: string, cls: string, action: () => void) => {
    const b = el("button", "btn " + cls, label);
    b.addEventListener("click", action);
    return b;
  };
  const save = () => { store.update(id, { alarm: toRef(nextOccurrence(date).getTime()) }); close(); };
  const grid = el("div", "alarm-grid");
  grid.append(
    item.alarm != null
      ? button("Ta bort", "destructive", () => { store.update(id, { alarm: undefined }); close(); })
      : button("Avbryt", "", () => close()),
    button("Sätt alarm", "default", save),
    button("+15 min", "", () => { date = new Date(Date.now() + 15 * 60 * 1000); paint(); }),
    button("+1 h", "", () => { date = new Date(Date.now() + 60 * 60 * 1000); paint(); }),
  );

  const body = el("div", "alarm-body");
  body.append(clock, grid);
  pop.append(arrow, heading, title, body);
  document.body.append(pop);
  paint();

  const place = () => {
    const a = anchor.getBoundingClientRect();
    const w = pop.offsetWidth, h = pop.offsetHeight;
    const below = a.bottom + 10 + h <= window.innerHeight - 8 || a.top - 10 - h < 8;
    const left = Math.min(Math.max(8, a.left + a.width / 2 - w / 2), window.innerWidth - w - 8);
    pop.style.left = left + "px";
    pop.style.top = (below ? a.bottom + 10 : a.top - 10 - h) + "px";
    pop.classList.toggle("above", !below);
    arrow.style.left = a.left + a.width / 2 - left - 8 + "px";
  };
  place();

  const onKey = (e: KeyboardEvent) => {
    if (e.key === "Escape") { e.preventDefault(); close(); }
    else if (e.key === "Enter") { e.preventDefault(); save(); }
  };
  const onDown = (e: MouseEvent) => {
    if (pop.contains(e.target as Node)) return;
    close();
    lastAlarmClose = { id, at: Date.now() };
  };
  document.addEventListener("keydown", onKey, true);
  document.addEventListener("mousedown", onDown, true);
  window.addEventListener("resize", place);

  function close() {
    document.removeEventListener("keydown", onKey, true);
    document.removeEventListener("mousedown", onDown, true);
    window.removeEventListener("resize", place);
    pop.remove();
    closeAlarm = null;
  }
  closeAlarm = close;
}
