# yolo-bash

Windows desktop shortcuts that launch AI coding CLIs in "YOLO" mode — permission
prompts and approval gates disabled.

> **Warning:** every shortcut here intentionally bypasses the safety confirmations
> of its tool. Only use them in environments where you accept that.

## `shortcuts/`

| Shortcut | Launches | Flags |
| --- | --- | --- |
| `Claude Code.lnk` | `wscript` → `scripts/claude-launch.vbs` → `claude.cmd` | `--dangerously-skip-permissions` |
| `Qwen 3.8 Claude Code.lnk` | `wscript` → `scripts/qwen38-claude-launch.vbs` → `scripts/qwen38-claude-code.cmd` | Claude Code pointed at local Ollama, `--dangerously-skip-permissions` |
| `Codex.lnk` | `cmd /d /k codex.cmd` | `--dangerously-bypass-approvals-and-sandbox` |

The `.lnk` files are Windows binaries with absolute paths baked in. They assume:

- `C:\Users\boisg\` as the home / working directory
- Node installed via nvm4w at `C:\nvm4w\nodejs\` (`claude.cmd`, `codex.cmd`)
- the `.vbs` / `.cmd` files from `scripts/` sitting in `C:\Users\boisg\`

On a different machine, re-create the shortcuts rather than copying them, or edit
their targets to match your paths.

## `scripts/`

- `claude-launch.vbs` — one-liner that opens a `cmd /k` window running Claude Code.
  The VBS wrapper exists so the shortcut spawns a real console without a stray
  parent window.
- `qwen38-claude-launch.vbs` — same trick, but runs `qwen38-claude-code.cmd`.
- `qwen38-claude-code.cmd` — points Claude Code at a **local** model:
  - `ANTHROPIC_BASE_URL=http://127.0.0.1:11434` (Ollama), auth token `ollama`
  - clears `ANTHROPIC_API_KEY` so nothing leaks to the real API
  - `MAX_THINKING_TOKENS=0` plus telemetry/error-reporting off
  - starts `ollama serve` if `/api/version` doesn't answer within 3s
  - runs `--model qwen3.8-claude-nothink --effort low`

## Install

Copy `scripts/*` into `%USERPROFILE%\` and `shortcuts/*` onto your Desktop.
