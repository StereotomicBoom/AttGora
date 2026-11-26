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
- Drag tasks to reorder them (in any filter). Unfinished tasks always stay above completed ones.
- Star: click the star to mark a task as important, or right-click → "Prioritet". New tasks are placed right after the last starred task.
- Alarm: click the stopwatch to set a time. Scroll over the hours or minutes, use the arrows or type digits. The alarm rings even when the window is closed, as long as the app is running.
- Double-click the blank space next to a task to move it to the top. Press and hold a row, then drag, to reorder.
- Appearance: Visa → Utseende → Ljust / Mellan (muted grey) / Mörkt. The choice is remembered and does not follow macOS.
- Filter: Alla / Kvar / Klara. The footer shows how many are left and has "Rensa klara".

## Quick start

| To … | Do this |
|---|---|
| Build and install the app | `./bygg.sh` (quits the running app, replaces `~/Applications/AttGöra.app` and recreates the Desktop shortcut). Needs Node.js. |
| Check the TypeScript without building | `npm run typecheck` |
| Redraw the icon | Edit `mac/make-icon.swift` and run `./bygg.sh` |
| Share a new version | Bump `VERSION`, commit, then run `./bygg.sh release` (builds, pushes and publishes a GitHub Release with the zip) |
| Uninstall | Double-click `Avinstallera AttGöra.command` (asks separately before deleting your tasks) |

## Files

| Path | What |
|---|---|
| `web/app.ts` | The window: input field, filter, list, rows, drag to reorder, editing, footer, update check |
| `web/alarm.ts` | The alarm popover with the clock |
| `web/store.ts` | Loads, orders and saves the tasks |
| `web/native.ts` | Talks to the Swift shell |
| `web/index.html`, `web/app.css` | Page layout, colours and sizes |
| `mac/src/main.swift` | The shell: window, menus, saving `todos.json`, alarms, dialogs and the right-click menu |
| `mac/make-icon.swift` | Draws the icon (pen and paper, dark lines on cream) |
| `mac/set-icon.swift` | Sets the square-cornered Finder icon |
| `VERSION` | Version number, written into the app and used as the release tag (`v1.0`) |
| `delning/` | Install guide included in the share package `~/Applications/AttGöra för Mac.zip` |
| `mac/build/` | Build output (not in git) |

## Data

Tasks are saved as JSON in `~/Library/Application Support/Todo/todos.json`, written on every change. The folder keeps the app's old name, Todo, so tasks survived the rename.
