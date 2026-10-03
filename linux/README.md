# yolo-claude — Linux

GNOME `.desktop` launchers. Install the two Claude ones with:

```sh
./install.sh
```

That copies `yolo-claude.desktop` and `claude-usage.desktop` to
`~/.local/share/applications` and your Desktop (marked trusted), and the icons to
`~/.local/share/icons`.

| Launcher | Runs | Icon |
| --- | --- | --- |
| `yolo-claude.desktop` | `claude --dangerously-skip-permissions` | `icons/claude.png` |
| `claude-usage.desktop` | the same, opened on `/usage` | `icons/claude-usage.png` (battery) |
| `yolo-codex.desktop` | Codex with `--dangerously-bypass-approvals-and-sandbox` | `icons/chatgpt.png` |
| `yolo-ab-glm.desktop` | Claude Code against a local GLM-5.3 Flash (vLLM :8001) via `~/.local/bin/yolo-ab-glm` | `icons/glm-pink.png` |

The Claude launchers run through `bash -l` so `~/.local/bin` is on PATH. The last
two hardcode `/home/bo`; edit the paths before copying them by hand.
