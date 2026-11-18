const STARRED = 2;

class Store {
  items: TodoItem[] = [];
  onChange: () => void = () => {};

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
      }));
      this.items = [...items.filter((i) => !i.done), ...items.filter((i) => i.done)];
    } catch {
      this.items = [];
    }
  }

  private set(next: TodoItem[]) {
    const wasDone = new Set(this.items.filter((i) => i.done).map((i) => i.id));
    const unticked = next.filter((i) => !i.done && wasDone.has(i.id));
    const open = next.filter((i) => !i.done && !wasDone.has(i.id));
    const done = next.filter((i) => i.done).map((i) => {
      const { alarm, ...rest } = i;
      return { ...rest, inProgress: false };
    });
    this.items = [...unticked, ...open, ...done];
    native("save", { json: JSON.stringify(this.items) });
    this.onChange();
  }

  get(id: string) {
    return this.items.find((i) => i.id === id);
  }

  get remaining() {
    return this.items.filter((i) => !i.done).length;
  }

  add(title: string) {
    const trimmed = title.trim();
    if (!trimmed) return;
    const item: TodoItem = { id: crypto.randomUUID().toUpperCase(), title: trimmed, done: false, created: nowRef(), priority: 0, inProgress: false };
    let lastStarred = -1;
    this.items.forEach((i, n) => { if (!i.done && i.priority) lastStarred = n; });
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
    this.set(this.items.filter((i) => !i.done));
  }
}
