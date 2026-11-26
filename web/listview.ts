async function openListMenu() {
  const current = store.currentList;
  const picked: string | null = await native("menu", {
    items: [
      ...store.lists.map((l) => ({ id: "list:" + l.id, title: `${l.name} (${store.remainingIn(l.id)})`, checked: l.id === current.id })),
      { separator: true },
      { id: "new", title: "Ny lista" },
      { id: "rename", title: `Byt namn på ”${current.name}”…` },
      ...(store.lists.length > 1 ? [{ id: "delete", title: `Ta bort ”${current.name}”…` }] : []),
    ] satisfies MenuEntry[],
  });
  if (!picked) return;
  if (picked.startsWith("list:")) store.selectList(picked.slice(5));
  else if (picked === "new") store.addList();
  else if (picked === "rename") renameList(current);
  else if (picked === "delete") deleteList(current);
}

async function deleteList(list: TodoList) {
  const count = store.itemsIn(list.id).length;
  const text = count ? `Listan och dess ${count} ${count === 1 ? "uppgift" : "uppgifter"} tas bort på alla enheter.` : "Listan tas bort på alla enheter.";
  const choice = await native("dialog", { title: `Ta bort ”${list.name}”?`, text, buttons: ["Ta bort", "Avbryt"] });
  if (choice === 0) store.deleteList(list.id);
}

function openPanel(cls: string, build: (sheet: HTMLDivElement, close: () => void) => void, onClose = () => {}) {
  const backdrop = el("div", "sheet-backdrop");
  const sheet = el("div", "sheet " + cls);
  backdrop.append(sheet);
  document.body.append(backdrop);
  const onKey = (e: KeyboardEvent) => { if (e.key === "Escape") { e.preventDefault(); close(); } };
  document.addEventListener("keydown", onKey, true);
  backdrop.addEventListener("pointerdown", (e) => { if (e.target === backdrop) close(); });
  let closed = false;
  function close() {
    if (closed) return;
    closed = true;
    onClose();
    document.removeEventListener("keydown", onKey, true);
    backdrop.remove();
  }
  build(sheet, close);
}

function panelButtons(...buttons: [string, string, () => void][]) {
  const row = el("div", "sheet-buttons");
  for (const [label, cls, onClick] of buttons) {
    const b = el("button", "btn " + cls, label);
    b.addEventListener("click", onClick);
    row.append(b);
  }
  return row;
}

function renameList(list: TodoList) {
  openPanel("", (sheet, close) => {
    const input = el("input", "sheet-field");
    input.value = list.name;
    input.spellcheck = false;
    const save = () => {
      const name = input.value.trim();
      if (name && name !== list.name) store.renameList(list.id, name);
      close();
    };
    input.addEventListener("keydown", (e) => { if (e.key === "Enter") { e.preventDefault(); save(); } });
    sheet.append(el("div", "sheet-heading", "Byt namn på listan"), input, panelButtons(["Avbryt", "", close], ["Spara", "default", save]));
    requestAnimationFrame(() => { input.focus(); input.select(); });
  });
}

let noteOpen = false;

function openNote() {
  if (noteOpen) return;
  noteOpen = true;
  let box: HTMLTextAreaElement;
  let timer = 0;
  const save = () => {
    clearTimeout(timer);
    if (box.value !== store.note.text) { store.setNote(box.value); render(); }
  };
  openPanel("note-sheet", (sheet, close) => {
    box = el("textarea", "sheet-field note-text");
    box.value = store.note.text;
    box.placeholder = "Skriv anteckningar här";
    box.spellcheck = false;
    box.addEventListener("input", () => { clearTimeout(timer); timer = window.setTimeout(save, 600); });
    sheet.append(el("div", "sheet-heading", "Anteckningar"), box, panelButtons(["Klar", "default", close]));
    requestAnimationFrame(() => box.focus());
  }, () => { save(); noteOpen = false; });
}
