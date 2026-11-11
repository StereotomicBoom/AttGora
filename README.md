# Todo

A simple Mac to-do app (Swedish interface), written in SwiftUI.

This folder is the **master copy**. Make changes here and run `./bygg.sh`. The app in `~/Applications/Todo.app` is always built from this folder. Never edit the installed app bundle.

The current state and pitfalls for whoever takes over are in [HANDOFF.md](HANDOFF.md).

## Features

- Add a task in the "Ny uppgift" field (Return or "Lägg till"). ⌘N jumps to the field.
- Click a task's text to mark it as in progress (light blue row background); click again to turn it off. Double-click the text to edit it. Tick the checkbox to mark it done (this also clears "in progress").
- Delete with the Delete key on a selected row, or right-click → "Ta bort".
- Completed tasks sink to the bottom automatically; unticking moves a task back up.
- Drag tasks to reorder them (in any filter). Unfinished tasks always stay above completed ones.
- Priority: click the coloured square next to the checkbox to step through outlined grey (none) → green (low) → orange (medium) → red (high), or right-click → "Prioritet". It is a label only; it does not change the order.
- White window, always in light appearance (also when macOS is in dark mode).
- Filter: Alla / Kvar / Klara. The footer shows how many are left and has "Rensa klara".

## Quick start

| To … | Do this |
|---|---|
| Build and install the app | `./bygg.sh` (quits the running app, replaces `~/Applications/Todo.app` and recreates the Desktop shortcut) |
| Redraw the icon | Edit `mac/make-icon.swift` and run `./bygg.sh` |
| Uninstall | Double-click `Avinstallera Todo.command` (asks separately before deleting your tasks) |

## Files

| Path | What |
|---|---|
| `mac/Todo/TodoApp.swift` | App entry point, window and the "Ny uppgift" menu command |
| `mac/Todo/ContentView.swift` | The window: input field, filter, list, footer |
| `mac/Todo/Store.swift` | `TodoItem` and `TodoStore`: loads and saves the tasks |
| `mac/make-icon.swift` | Draws the icon (white checkmark on blue) |
| `mac/set-icon.swift` | Sets the square-cornered Finder icon |
| `mac/build/` | Build output (not in git) |

## Data

Tasks are saved as JSON in `~/Library/Application Support/Todo/todos.json`, written on every change.
