const native = (cmd: string, args: Record<string, unknown> = {}): Promise<any> =>
  window.webkit.messageHandlers.native.postMessage({ cmd, ...args });

const REFERENCE_DATE_MS = 978307200000;
const toRef = (ms: number) => (ms - REFERENCE_DATE_MS) / 1000;
const fromRef = (seconds: number) => seconds * 1000 + REFERENCE_DATE_MS;
const nowRef = () => toRef(Date.now());
