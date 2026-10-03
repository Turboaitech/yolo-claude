# yolo-claude — Linux

GNOME `.desktop` launchers:

- `yolo-codex.desktop` — Codex with `--dangerously-bypass-approvals-and-sandbox`
- `yolo-ab-glm.desktop` — Claude Code in YOLO mode against a local GLM-5.3 Flash (vLLM on :8001), via `~/.local/bin/yolo-ab-glm`

Both open in `gnome-terminal` and hardcode `/home/bo`; change the paths to your
home directory before installing:

```sh
cp icons/*.png ~/.local/share/icons/
cp *.desktop ~/.local/share/applications/   # or ~/Desktop, then "Allow Launching"
```
