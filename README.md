# AttGöra

A simple Mac to-do app (Swedish interface). The app itself is written in TypeScript (`web/`); a small Swift shell (`mac/src/main.swift`) shows it in a native window.

This folder is the **master copy**. Make changes here and run `./bygg.sh`. The app in `~/Applications/AttGöra.app` is always built from this folder. Never edit the installed app bundle.

The current state and pitfalls for whoever takes over are in [HANDOFF.md](HANDOFF.md).

## Features

- Add a task in the "Ny uppgift" field (Return or "Lägg till"). ⌘N jumps to the field.
- Click a task's text to mark it as in progress (light blue row background); click again to turn it off. Double-click the text to edit it. Tick the checkbox to mark it done (this also clears "in progress").
- Delete with right-click → "Ta bort".
- Save a task as a text file anywhere with right-click → "Spara som…" (title, status, priority, alarm and created date; the Desktop is suggested).
- Completed tasks sink to the bottom automatically; unticking moves a task back up.
- Drag tasks to reorder them. Unfinished tasks always stay above completed ones.
- Star: click the star to mark a task as important, or right-click → "Prioritet". New tasks are placed right after the last starred task.
- Alarm: click the stopwatch to set a time. Scroll over the hours or minutes, use the arrows or type digits. The alarm rings even when the window is closed, as long as the app is running.
- Double-click the blank space next to a task to move it to the top. Press and hold a row, then drag, to reorder.
- Appearance: the half-filled circle at the far left of the button row switches Ljust → Mellan (muted grey) → Mörkt, as does Visa → Utseende on the Mac. The choice is remembered and does not follow macOS.
- Lists: "+" next to the input field starts a new list ("Ny lista"). The icon button opens a menu with all lists (with how many are left in each), plus "Byt namn" and "Ta bort" for the current list. Deleting a list deletes its tasks. Tasks from before lists existed are in the list "AttGöra".
- Notes: the pencil button opens one shared notes window, saved as you type. The pencil turns blue when there are notes.
- The footer shows how many are left in the current list and has "Rensa klara".
- Sync: the cloud button in the footer (or AttGöra → Synk…). On one device choose "Skapa ny nyckel", copy the sync key and paste it under Synk on the other device. Tasks then sync about every minute and whenever the app comes to the front. The newest edit of each task wins, deleted tasks stay deleted, and the most recently reordered list decides the order.

## iPhone

The iPhone app (`ios/`) shows the same page in a native shell. Differences from the Mac: long-press a task (without moving) for the menu; press, hold and drag to reorder; alarms are notifications (with "Snooza 5 min"); "Spara som…" opens the share sheet; light or dark follows the phone until you pick an appearance with the circle button. It is installed from TestFlight (App Store Connect → AttGöra → TestFlight).

## Quick start

| To … | Do this |
|---|---|
| Build and install the app | `./bygg.sh` (quits the running app, replaces `~/Applications/AttGöra.app` and recreates the Desktop shortcut). Needs Node.js. |
| Check the TypeScript without building | `npm run typecheck` |
| Redraw the icon | Edit `mac/make-icon.swift` and run `./bygg.sh` |
| Share a new version | Bump `VERSION`, commit, then run `./bygg.sh release` (builds, pushes and publishes a GitHub Release with the zip) |
| Upload the iPhone app to TestFlight | `./bygg.sh iphone` (build number is the current date and time) |
| Uninstall | Double-click `Avinstallera AttGöra.command` (asks separately before deleting your tasks) |

## Files

| Path | What |
|---|---|
| `web/app.ts` | The window: input field, list buttons, rows, drag to reorder, editing, footer, update check |
| `web/alarm.ts` | The alarm popover with the clock |
| `web/store.ts` | Loads, orders and saves the tasks |
| `web/native.ts` | Talks to the Swift shell |
| `web/listview.ts` | The list menu, renaming and deleting lists, and the notes window |
| `web/sync.ts`, `web/syncview.ts` | Sync through the Cloudflare Worker, and the sync-key sheet |
| `web/index.html`, `web/app.css` | Page layout, colours and sizes |
| `mac/src/main.swift` | The shell: window, menus, saving `todos.json`, alarms, dialogs and the right-click menu |
| `mac/make-icon.swift` | Draws the icon (two notes under a fridge magnet, dark lines on cream) |
| `mac/set-icon.swift` | Sets the square-cornered Finder icon |
| `ios/` | The iPhone shell (`AttGora/AttGoraApp.swift`) and its Xcode project |
| `cloudflare/` | The sync server: a Worker (`src/index.ts`) with a D1 table (`migrations/`). Deploy with `npx wrangler deploy` in that folder |
| `VERSION` | Version number, written into the app and used as the release tag (`v1.0`) |
| `delning/` | Install guide included in the share package `~/Applications/AttGöra för Mac.zip` |
| `mac/build/` | Build output (not in git) |

## Data

Tasks are saved as JSON in `~/Library/Application Support/Todo/todos.json`, written on every change. The folder keeps the app's old name, Todo, so tasks survived the rename. Lists, the selected list and the notes are in `lists.json`, and sync state (sync key, deleted tasks) in `sync.json`, both next to it. On the iPhone these files are in the app's own Application Support folder.
