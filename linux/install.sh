#!/usr/bin/env bash
# Installs yolo-claude.desktop and claude-usage.desktop into the app menu and
# onto the Desktop. Icons go to ~/.local/share/icons so Icon=claude resolves.
set -euo pipefail
cd "$(dirname "$0")"

icons="$HOME/.local/share/icons"
apps="$HOME/.local/share/applications"
desk="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
mkdir -p "$icons" "$apps" "$desk"

cp icons/claude.png icons/claude-usage.png "$icons/"
for f in yolo-claude.desktop claude-usage.desktop; do
  install -m 755 "$f" "$apps/$f"
  install -m 755 "$f" "$desk/$f"
  # GNOME refuses to launch untrusted desktop files until this is set.
  gio set "$desk/$f" metadata::trusted true 2>/dev/null || true
done

command -v claude >/dev/null || echo "warning: 'claude' is not on PATH -- install Claude Code first"
echo "installed to $apps and $desk"
