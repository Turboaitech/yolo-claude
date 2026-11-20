# yolo-claude

Desktop launchers for Claude Code (and friends) in "YOLO" mode — permission
prompts disabled. Organized by platform:

| Folder | What's there |
| --- | --- |
| [`windows/`](windows/) | `install.ps1` → `yolo-claude.lnk` + `claude-usage.lnk` (battery icon) + `yolo-codex.lnk` (ChatGPT icon), plain `.bat` equivalents, local-model launcher, home-server launchers `yolo-spark` / `yolo-6000`, icon tools |
| [`linux/`](linux/) | `yolo-claude.desktop` + `claude-usage.desktop` via `install.sh`, plus `yolo-codex` / `yolo-ab-glm` |
| [`mac/`](mac/) | `yolo-claude.command` + `claude-usage.command` + `yolo-codex.command` via `install.sh` (sets Finder icons) |

> **Warning:** these launchers intentionally bypass safety confirmations
> (`--dangerously-skip-permissions` and equivalents). Only use them on a machine
> you are sitting at. See the Windows README's
> [lockdown section](windows/README.md#the-lockdown) for why Remote Control,
> Workflows and cron routines should be off when you do.
