# yolo-claude

Desktop launchers for Claude Code (and friends) in "YOLO" mode — permission
prompts disabled. Organized by platform:

| Folder | What's there |
| --- | --- |
| [`windows/`](windows/) | `install.ps1` (shortcut + icon + settings lockdown), `claude-usage.bat`, local-model launcher, icon tools |
| [`linux/`](linux/) | `.desktop` launchers for GNOME (`yolo-codex`, `yolo-ab-glm`) and their icons |
| [`mac/`](mac/) | nothing yet |

> **Warning:** these launchers intentionally bypass safety confirmations
> (`--dangerously-skip-permissions` and equivalents). Only use them on a machine
> you are sitting at. See the Windows README's
> [lockdown section](windows/README.md#the-lockdown) for why Remote Control,
> Workflows and cron routines should be off when you do.
