interface Window {
  webkit: { messageHandlers: { native: { postMessage(message: Record<string, unknown>): Promise<any> } } };
  todo: {
    focusNew(): void;
    scaleBy(delta: number): void;
    resetScale(): void;
    checkForUpdates(manual: boolean): void;
    setAlarm(id: string, alarm: number | null): void;
  };
}

interface TodoItem {
  id: string;
  title: string;
  done: boolean;
  created: number;
  priority: number;
  inProgress: boolean;
  alarm?: number;
}

interface MenuEntry {
  id?: string;
  title?: string;
  checked?: boolean;
  separator?: boolean;
  submenu?: MenuEntry[];
}
