# yolo-claude — macOS

Double-clickable Terminal launchers:

| Launcher | Runs | Icon |
| --- | --- | --- |
| `yolo-claude.command` | `claude --dangerously-skip-permissions` | `icons/claude.png` |
| `claude-usage.command` | the same, opened on `/usage` | `icons/claude-usage.png` (battery) |
| `yolo-codex.command` | `codex --dangerously-bypass-approvals-and-sandbox` | `icons/chatgpt.png` |

```sh
./install.sh
```

copies all three to `~/Desktop`, makes them executable, and sets their Finder icons.
The Claude launchers look for `~/.local/bin/claude` first, then whatever `claude`
is on PATH; `yolo-codex` uses `codex` from the login-shell PATH.

The first launch may be blocked by Gatekeeper: right-click → Open once.
