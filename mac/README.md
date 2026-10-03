# yolo-claude — macOS

Double-clickable Terminal launchers:

| Launcher | Runs | Icon |
| --- | --- | --- |
| `yolo-claude.command` | `claude --dangerously-skip-permissions` | `icons/claude.png` |
| `claude-usage.command` | the same, opened on `/usage` | `icons/claude-usage.png` (battery) |

```sh
./install.sh
```

copies both to `~/Desktop`, makes them executable, and sets their Finder icons.
Each looks for `~/.local/bin/claude` first, then whatever `claude` is on PATH.

The first launch may be blocked by Gatekeeper: right-click → Open once.
