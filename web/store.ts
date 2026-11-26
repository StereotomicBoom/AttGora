const STARRED = 2;

const DELETED_KEPT = 400 * 86400;

const DEFAULT_LIST = "default";

const withoutModified = (i: TodoItem) => { const { modified, ...rest } = i; return JSON.stringify(rest); };

class Store {
  items: TodoItem[] = [];
  deleted: Record<string, number> = {};
  orderModified = 0;
  lists: TodoList[] = [];
  current = DEFAULT_LIST;
  note: Note = { text: "", modified: 0 };
  onChange: () => void = () => {};
  onLocalChange: () => void = () => {};

  async load() {
    try {
      const raw = JSON.parse(await native("load")) as Partial<TodoItem>[];
      const items = raw.map((r) => ({
        id: r.id ?? crypto.randomUUID().toUpperCase(),
        title: r.title ?? "",
        done: r.done ?? false,
        created: r.created ?? nowRef(),
        priority: r.priority ? STARRED : 0,
        inProgress: r.inProgress ?? false,
        ...(typeof r.alarm === "number" ? { alarm: r.alarm } : {}),
        ...(typeof r.modified === "number" ? { modified: r.modified } : {}),
        list: r.list ?? DEFAULT_LIST,
      }));
      this.items = [...items.filter((i) => !i.done), ...items.filter((i) => i.done)];
    } catch {
      this.items = [];
    }
    try {
      const meta = JSON.parse(await native("loadLists"));
      this.lists = Array.isArray(meta.lists) ? meta.lists : [];
      this.current = meta.current ?? DEFAULT_LIST;
      if (meta.note) this.note = meta.note;
    } catch {}
    this.ensureLists();
  }

  private ensureLists() {
    if (!this.lists.length) this.lists = [{ id: DEFAULT_LIST, name: "AttGöra", created: 0 }];
    this.lists.sort((a, b) => a.created - b.created);
    if (!this.lists.some((l) => l.id === this.current)) this.current = this.lists[0].id;
  }

  private saveMeta() {
    native("saveLists", { json: JSON.stringify({ lists: this.lists, current: this.current, note: this.note }) });
  }

  listOf(item: TodoItem) {
    return this.lists.some((l) => l.id === item.list) ? item.list! : this.lists[0].id;
  }

  itemsIn(list: string) {
    return this.items.filter((i) => this.listOf(i) === list);
  }

  get visible() {
    return this.itemsIn(this.current);
  }

  get currentList() {
    return this.lists.find((l) => l.id === this.current)!;
  }

  remainingIn(list: string) {
    return this.itemsIn(list).filter((i) => !i.done).length;
  }

  selectList(id: string) {
    this.current = id;
    this.saveMeta();
    this.onChange();
  }

  addList() {
    const now = nowRef();
    this.lists.push({ id: crypto.randomUUID().toUpperCase(), name: "Ny lista", created: now, modified: now });
    this.current = this.lists[this.lists.length - 1].id;
    this.saveMeta();
    this.onChange();
    this.onLocalChange();
  }

  renameList(id: string, name: string) {
    this.lists = this.lists.map((l) => (l.id === id ? { ...l, name, modified: nowRef() } : l));
    this.saveMeta();
    this.onChange();
    this.onLocalChange();
  }

  deleteList(id: string) {
    if (this.lists.length <= 1) return;
    const gone = new Set(this.itemsIn(id).map((i) => i.id));
    this.lists = this.lists.filter((l) => l.id !== id);
    this.deleted[id] = nowRef();
    this.ensureLists();
    this.saveMeta();
    this.set(this.items.filter((i) => !gone.has(i.id)));
  }

  setNote(text: string) {
    this.note = { text, modified: nowRef() };
    this.saveMeta();
    this.onLocalChange();
  }

  private arrange(next: TodoItem[]) {
    const wasDone = new Set(this.items.filter((i) => i.done).map((i) => i.id));
    const unticked = next.filter((i) => !i.done && wasDone.has(i.id));
    const open = next.filter((i) => !i.done && !wasDone.has(i.id));
    const done = next.filter((i) => i.done).map((i) => {
      if (i.alarm == null && !i.inProgress) return i;
      const { alarm, ...rest } = i;
      return { ...rest, inProgress: false };
    });
    return [...unticked, ...open, ...done];
  }

  private set(next: TodoItem[]) {
    const prev = this.items;
    const arranged = this.arrange(next);
    this.stamp(prev, arranged);
    this.items = arranged;
    native("save", { json: JSON.stringify(this.items) });
    this.onChange();
    this.onLocalChange();
  }

  replace(items: TodoItem[], deleted: Record<string, number>, orderModified: number, lists: TodoList[], note: Note) {
    this.items = this.arrange(items);
    this.deleted = deleted;
    this.orderModified = orderModified;
    this.lists = lists;
    this.note = note;
    this.ensureLists();
    this.saveMeta();
    native("save", { json: JSON.stringify(this.items) });
    this.onChange();
  }

  private stamp(prev: TodoItem[], next: TodoItem[]) {
    const now = nowRef();
    const before = new Map(prev.map((i) => [i.id, withoutModified(i)]));
    for (let n = 0; n < next.length; n++) {
      if (before.get(next[n].id) !== withoutModified(next[n])) next[n] = { ...next[n], modified: now };
    }
    const nextIds = new Set(next.map((i) => i.id));
    for (const i of prev) if (!nextIds.has(i.id)) this.deleted[i.id] = now;
    for (const [id, at] of Object.entries(this.deleted)) if (at < now - DELETED_KEPT) delete this.deleted[id];
    const prevIds = new Set(prev.map((i) => i.id));
    const kept = (list: TodoItem[], other: Set<string>) => list.filter((i) => other.has(i.id)).map((i) => i.id).join();
    if (kept(prev, nextIds) !== kept(next, prevIds)) this.orderModified = now;
  }

  get(id: string) {
    return this.items.find((i) => i.id === id);
  }

  get remaining() {
    return this.remainingIn(this.current);
  }

  add(title: string) {
    const trimmed = title.trim();
    if (!trimmed) return;
    const item: TodoItem = { id: crypto.randomUUID().toUpperCase(), title: trimmed, done: false, created: nowRef(), priority: 0, inProgress: false, list: this.current };
    let lastStarred = -1;
    this.items.forEach((i, n) => { if (!i.done && i.priority && this.listOf(i) === this.current) lastStarred = n; });
    const next = [...this.items];
    next.splice(lastStarred + 1, 0, item);
    this.set(next);
  }

  update(id: string, change: Partial<TodoItem>) {
    this.set(this.items.map((i) => {
      if (i.id !== id) return i;
      const updated = { ...i, ...change };
      if (updated.alarm == null) delete updated.alarm;
      return updated;
    }));
  }

  move(visible: string[], from: number, to: number) {
    const reordered = [...visible];
    reordered.splice(to, 0, reordered.splice(from, 1)[0]);
    const visibleSet = new Set(visible);
    let n = 0;
    this.set(this.items.map((i) => (visibleSet.has(i.id) ? this.get(reordered[n++])! : i)));
  }

  moveToTop(id: string) {
    const item = this.get(id);
    if (item) this.set([item, ...this.items.filter((i) => i.id !== id)]);
  }

  delete(id: string) {
    this.set(this.items.filter((i) => i.id !== id));
  }

  clearCompleted() {
    this.set(this.items.filter((i) => !i.done || this.listOf(i) !== this.current));
  }
}
