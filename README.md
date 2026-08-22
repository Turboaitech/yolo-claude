# yolo-claude

A Windows desktop shortcut that launches Claude Code in "YOLO" mode — permission
prompts disabled.

> **Warning:** the shortcut intentionally bypasses Claude Code's safety
> confirmations (`--dangerously-skip-permissions`). Only use it in environments
> where you accept that.

## Install

From a **normal PowerShell window** (see [the container gotcha](#the-container-gotcha)):

```powershell
git clone https://github.com/Turboaitech/yolo-claude.git
cd yolo-claude
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

The installer:

1. Resolves `claude.exe` to a real, non-virtualized path — reusing a copy already
   on disk if it finds one, and only downloading the native installer as a last
   resort.
2. Puts it in `%USERPROFILE%\.local\bin`.
3. Generates `Claude Code.lnk` on your Desktop with the correct absolute path for
   *your* machine, pointing straight at `claude.exe`.
4. Adds `%USERPROFILE%\.local\bin` to your user PATH.

Flags: `-SkipPathUpdate` leaves PATH alone, `-Force` re-copies `claude.exe` even if
one is already installed.

## The container gotcha

**Do not `npm install -g @anthropic-ai/claude-code` from a terminal inside the
Claude desktop app.**

That app runs in an MSIX container. Writes to `%APPDATA%` from inside it are
silently redirected:

```
C:\Users\<you>\AppData\Roaming\npm
  -> C:\Users\<you>\AppData\Local\Packages\Claude_<id>\LocalCache\Roaming\npm
```

Inside the app everything looks perfectly installed — `claude --version` works,
`where claude` finds it. But Explorer, Task Scheduler, and ordinary terminals run
*outside* the container and see nothing there. A shortcut built against those paths
dies with `The system cannot find the path specified.`

An `nvm4w` layout makes it worse, because `C:\nvm4w\nodejs` is a junction pointing
at `AppData\Roaming\npm` — so the shortcut target *resolves*, to an empty directory.

Symptoms and how to tell them apart:

| Symptom | Cause |
| --- | --- |
| Shortcut flashes and closes, "path not found" | CLI only exists inside the container |
| `where claude` works in the app, fails elsewhere | same |
| `gh auth status` logged in one place, logged out in another | `hosts.yml` written to the redirected `%APPDATA%` |

To confirm from inside the app, run something through Task Scheduler — it executes
outside the container and sees the real filesystem:

```powershell
schtasks /create /tn Probe /tr "cmd /c where claude > %USERPROFILE%\probe.txt 2>&1" /sc once /st 23:59 /f
schtasks /run /tn Probe
# then read %USERPROFILE%\probe.txt and: schtasks /delete /tn Probe /f
```

`install.ps1` detects the container, warns, and installs to `%USERPROFILE%\.local\bin`,
which is **not** virtualized.

## Notes

The old `.vbs` wrappers and prebuilt `.lnk` files were removed. The VBS existed to
avoid a stray parent console window, which a shortcut pointing straight at
`claude.exe` doesn't have; the `.lnk` binaries had one machine's absolute paths
baked in, which is what broke them in the first place. `install.ps1` generates the
shortcut correctly instead.
