# Todo: handoff

Written 2026-11-11 for whoever picks this app up next, person or AI session. **[README.md](README.md)** is the user guide. This file covers the current state and traps.

## Where things are

| What | Where |
|---|---|
| Source (the only copy; edit only here) | `~/Applications/Todo-källkod/` |
| Installed app | `~/Applications/Todo.app`, with a symlink on the Desktop |
| User data (real, never test against it) | `~/Library/Application Support/Todo/todos.json` |
| Bundle id | `se.gustavlundstrom.todo` |
| Build and install | `./bygg.sh` |

## State as of 2026-11-11

First version: add, edit, complete, delete, filter, clear completed, ⌘N. Built with plain `swiftc -parse-as-library` (no Xcode project, no SwiftPM).

## Traps

- **No SwiftData.** Storage is a Codable JSON file, chosen because SwiftData macros don't build reliably with plain `swiftc`. Changing `TodoItem`'s fields breaks decoding of existing data unless new fields are optional or have defaults handled in a custom decoder; a failed decode starts with an empty list and the next save overwrites the file.
- `TodoStore.items` saves on every `didSet`, including each keystroke while editing a task. Fine for small lists.
- The uninstaller is a copy of the shared script used by the other apps, with a `todo` entry added. The other apps' copies don't know about Todo.

## Ideas not done

Due dates, multiple lists, drag to reorder.
