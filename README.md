# yolo-claude

Windows desktop shortcuts that launch AI coding CLIs in "YOLO" mode — permission
prompts and approval gates disabled.

> **Warning:** every shortcut here intentionally bypasses the safety confirmations
> of its tool. File writes, shell commands, and network calls all run unattended.
> Only point them at a working directory you accept an agent modifying without asking.

## Quick install

```powershell
git clone https://github.com/Turboaitech/yolo-claude.git
cd yolo-claude
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

A `yolo-claude` shortcut appears on your desktop, wearing the Claude logo instead
of the default executable icon.

`-ExecutionPolicy Bypass` is there because a default Windows install refuses to run
local scripts. To lift that permanently: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`.

### What `install.ps1` does

- Copies `icons/claude-logo.ico` to `~/.claude/claude-logo.ico` — outside the Claude
  Code install tree, so an update can't wipe it.
- Creates `yolo-claude.lnk` on the desktop targeting `claude.exe`
  with `--dangerously-skip-permissions`, starting in your home directory.
- Refreshes the Explorer icon cache so the logo shows without a sign-out.

`claude.exe` is auto-detected from `~/.local/bin`, `%LOCALAPPDATA%\Programs\claude`,
the npm global bin, then `PATH`. The OneDrive-redirected Desktop is preferred when
it exists.

### Options

```powershell
.\install.ps1 -Name "yolo"                      # different shortcut name
.\install.ps1 -ClaudePath "D:\tools\claude.exe" # explicit binary
.\install.ps1 -Arguments ""                     # no flags, normal Claude Code
.\install.ps1 -WorkingDirectory "C:\code"       # start somewhere else
```

### Uninstall

```powershell
Remove-Item "$([Environment]::GetFolderPath('Desktop'))\yolo-claude.lnk"
Remove-Item "$HOME\.claude\claude-logo.ico"
```

## `shortcuts/`

Prebuilt `.lnk` files for the other launchers. `install.ps1` covers the plain
Claude Code one and is the better path; these are here for the variants it doesn't
generate yet.

| Shortcut | Launches | Flags |
| --- | --- | --- |
| `Claude Code.lnk` | `wscript` → `scripts/claude-launch.vbs` → `claude.cmd` | `--dangerously-skip-permissions` |
| `Qwen 3.8 Claude Code.lnk` | `wscript` → `scripts/qwen38-claude-launch.vbs` → `scripts/qwen38-claude-code.cmd` | Claude Code pointed at local Ollama, `--dangerously-skip-permissions` |
| `Codex.lnk` | `cmd /d /k codex.cmd` | `--dangerously-bypass-approvals-and-sandbox` |

These `.lnk` files are Windows binaries with absolute paths baked in. They assume:

- `C:\Users\boisg\` as the home / working directory
- Node installed via nvm4w at `C:\nvm4w\nodejs\` (`claude.cmd`, `codex.cmd`)
- the `.vbs` / `.cmd` files from `scripts/` sitting in `C:\Users\boisg\`

On a different machine, copy `scripts/*` into `%USERPROFILE%\` and either re-create
these shortcuts or edit their targets to match your paths. This is exactly the
brittleness `install.ps1` exists to avoid — it resolves paths at install time
instead of baking them in.

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
- `make-icon.ps1` — rebuilds `icons/claude-logo.ico` from a source PNG. Not needed
  to install; the `.ico` is committed.

## `icons/`

`claude-logo.ico` — the Claude burst at nine sizes (256→16px) with a transparent
background, so Windows never has to rescale.

Sourced from [seeklogo](https://seeklogo.com/vector-logo/554534/claude). The original
PNG has an opaque white background; `make-icon.ps1` recovers a real alpha channel
from the white/orange blend rather than colour-keying it, which is what keeps the
burst's anti-aliased edges from carrying a white fringe on dark taskbars.
