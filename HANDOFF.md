# AttGöra: handoff

Written 2026-11-11, updated 2026-11-18, for whoever picks this app up next, person or AI session. **[README.md](README.md)** is the user guide. This file covers the current state and traps.

## Where things are

| What | Where |
|---|---|
| Source (the only copy; edit only here) | `~/Applications/AttGöra-källkod/` |
| Installed app | `~/Applications/AttGöra.app`, with a symlink on the Desktop |
| User data (real, never test against it) | `~/Library/Application Support/Todo/todos.json` |
| Bundle id | `se.gustavlundstrom.todo` |
| Build and install | `./bygg.sh` |

## State as of 2026-11-18 (version 2.0)

Rewritten from SwiftUI to TypeScript. The page in `web/` (compiled by `tsc` into `mac/build/web/`) runs in a `WKWebView` inside a small Swift shell, `mac/src/main.swift`, the same set-up as JobbbAppp. The page talks to the shell through one message handler, `native`, with commands `load`, `save`, `loadSync`, `saveSync`, `platform`, `ready`, `getScale`, `setScale`, `version`, `open`, `dialog`, `menu` and `saveFile` (see `web/native.ts`). The shell calls back into the page through `window.todo` (⌘N, text size, update check, alarm result).

Features: add (after the last starred task), edit (double-click the text), in progress (single click), star, alarm with a custom clock, drag to reorder (press and hold), double-click blank space to move to top, filter, clear completed, text size, update check against GitHub Releases.

## Sync and iPhone (added 2026-11-26)

- `web/sync.ts`: no accounts. Devices share a random 24-character sync key (user's choice; Cloudflare can't send sign-in e-mails). The Worker stores rows under SHA-256 of the key, one row per device in `snapshots`; each device reads the others' rows, merges, and PUTs its own. "Koppla från" deletes the device's row. Merge rules: newest `modified` per task wins, `deleted` tombstones (kept 400 days) beat older edits, order comes from the snapshot with the newest `orderModified`.
- `Store.set` stamps `modified` on every changed task and records deletions/reorders; `Store.replace` applies a merge without stamping. Never write `store.items` directly.
- Server: Cloudflare Worker `attgora-sync` (https://attgora-sync.gustavlundstrom2.workers.dev) with D1 database `attgora-sync`, on the user's existing Cloudflare account (user didn't want another Supabase account). Code in `cloudflare/`; deploy with `npx wrangler deploy`, schema changes with `npx wrangler d1 migrations apply attgora-sync --remote`. `SYNC_URL` is at the top of `web/sync.ts`.
- iPhone shell `ios/AttGora/AttGoraApp.swift` implements the same `native` commands as the Mac shell plus `ready`. Team 9LQQ7466X2, bundle id `com.florenceliu.attgora`. The Xcode project was written by hand; the `web` folder reference points at `mac/build/web`, so run `npm run build` before building in Xcode.
- Alarms: the Mac rings only alarms less than 10 minutes late and silently clears older ones (they may come from the phone). The iPhone clears past alarms when it opens.

## Traps

- `todos.json` keeps the format of the Swift version: dates are seconds since 2001-01-01 (Apple's reference date), not Unix time. Use `toRef`/`fromRef` in `web/native.ts`. Old files load fine.
- Alarms are checked by the shell every 5 seconds, not by the page, so they ring even when the window is closed (closing only hides it). The shell keeps its own copy of the items from the last `save`.
- `Store.set` re-sorts after every change: unticked tasks first, then open tasks, then done tasks; a done task loses its alarm and "in progress". Rows are addressed by id, never by index.
- A single click waits about 0.3 s before toggling "in progress", so a double-click can cancel it.
- Background clicks from automation tools land unreliably in the web view. Test interactions by serving `mac/build/web` with a mocked `window.webkit` bridge in a browser instead. `TODO_DATA_DIR` points the app at a separate data folder for testing.
- The app was called Todo until 2.1.0. The bundle id (`se.gustavlundstrom.todo`), the data folder (`Application Support/Todo`) and the `TodoItem` type keep the old name on purpose, so existing tasks and settings carry over. The executable is `AttGora` (no ö) so `pgrep`/`pkill` match it reliably. The GitHub repo is `StereotomicBoom/AttGora`; GitHub redirects the old `Todo` URLs.
- The uninstaller started as a copy of a script shared with other apps; this copy only knows about AttGöra.

## Ideas not done

Due dates, multiple lists.
