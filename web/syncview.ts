let closeSync: (() => void) | null = null;

function openSync() {
  closeSync?.();
  const backdrop = el("div", "sheet-backdrop");
  const sheet = el("div", "sheet");
  backdrop.append(sheet);
  document.body.append(backdrop);

  let busyNow = false;

  const button = (label: string, cls: string, onClick: () => void) => {
    const b = el("button", "btn " + cls, label);
    b.addEventListener("click", onClick);
    return b;
  };
  const field = (placeholder: string, type: string, value = "") => {
    const input = el("input", "sheet-field");
    input.type = type;
    input.placeholder = placeholder;
    input.value = value;
    input.autocomplete = "off";
    input.spellcheck = false;
    input.setAttribute("autocapitalize", "off");
    return input;
  };
  const message = el("div", "sheet-message");
  const fail = (err: unknown) => { message.textContent = (err as Error).message; message.classList.add("error"); };

  async function act(work: () => Promise<void>) {
    if (busyNow) return;
    busyNow = true;
    message.textContent = "";
    message.classList.remove("error");
    sheet.classList.add("busy");
    try { await work(); } catch (err) { fail(err); } finally { busyNow = false; sheet.classList.remove("busy"); }
  }

  function paint() {
    sheet.replaceChildren();
    sheet.append(el("div", "sheet-heading", "Synk"));
    if (Sync.signedIn) {
      const key = field("", "text", Sync.key);
      key.readOnly = true;
      key.classList.add("sheet-key");
      key.addEventListener("focus", () => key.select());
      const copy = () => {
        key.focus();
        key.setSelectionRange(0, key.value.length);
        const done = document.execCommand("copy");
        message.classList.remove("error");
        message.textContent = done ? "Nyckeln är kopierad." : "Markera nyckeln och kopiera den.";
      };
      sheet.append(
        el("p", "", "Uppgifterna synkas med enheter som har samma synknyckel. Klistra in den på din andra enhet under Synk."),
        key,
        el("p", "sheet-status", statusText()),
        message,
        row(button("Koppla från", "destructive", () => act(async () => { await Sync.disconnect(); paint(); })),
          button("Kopiera", "", copy),
          button("Synka nu", "", () => act(async () => { await Sync.now(); paint(); })),
          button("Klar", "default", close)),
      );
    } else {
      const input = field("Klistra in synknyckel", "text");
      const join = () => act(async () => { await Sync.join(input.value); paint(); });
      input.addEventListener("keydown", (e) => { if (e.key === "Enter") { e.preventDefault(); join(); } });
      sheet.append(
        el("p", "", "Har du redan synk på en annan enhet? Klistra in dess synknyckel. Annars skapar du en ny nyckel här."),
        input, message,
        row(button("Avbryt", "", close),
          button("Skapa ny nyckel", "", () => act(async () => { await Sync.create(); paint(); })),
          button("Anslut", "default", join)),
      );
    }
  }

  function row(...buttons: HTMLElement[]) {
    const r = el("div", "sheet-buttons");
    r.append(...buttons);
    return r;
  }

  const stop = Sync.onStatus(() => { if (!busyNow && Sync.signedIn) paint(); });
  const onKey = (e: KeyboardEvent) => { if (e.key === "Escape") { e.preventDefault(); close(); } };
  document.addEventListener("keydown", onKey, true);
  backdrop.addEventListener("pointerdown", (e) => { if (e.target === backdrop) close(); });

  function close() {
    stop();
    document.removeEventListener("keydown", onKey, true);
    backdrop.remove();
    closeSync = null;
  }
  closeSync = close;
  paint();
}

function statusText() {
  const when = Sync.last ? new Date(Sync.last).toLocaleTimeString("sv-SE", { hour: "2-digit", minute: "2-digit" }) : "";
  switch (Sync.status) {
    case "syncing": return "Synkar…";
    case "offline": return "Ingen internetanslutning. Synkar när den är tillbaka.";
    case "error": return "Fel: " + Sync.error;
    case "ok": return when ? `Senast synkad ${when}.` : "";
    default: return "";
  }
}
