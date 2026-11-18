#!/usr/bin/env bash
# Copies yolo-claude, claude-usage and yolo-codex .command files to the Desktop and gives
# each its icon (Finder custom icon, set through NSWorkspace).
set -euo pipefail
cd "$(dirname "$0")"

for pair in "yolo-claude:claude" "claude-usage:claude-usage" "yolo-codex:chatgpt"; do
  name="${pair%%:*}"; icon="$PWD/icons/${pair##*:}.png"
  dest="$HOME/Desktop/$name.command"
  install -m 755 "$name.command" "$dest"
  osascript -l JavaScript -e "ObjC.import('AppKit');
    \$.NSWorkspace.sharedWorkspace.setIconForFileOptions(
      \$.NSImage.alloc.initWithContentsOfFile('$icon'), '$dest', 0)" >/dev/null
  echo "installed $dest"
done

command -v claude >/dev/null || [ -x "$HOME/.local/bin/claude" ] \
  || echo "warning: claude not found -- install Claude Code first"
command -v codex >/dev/null \
  || echo "warning: codex not found -- npm install -g @openai/codex"
