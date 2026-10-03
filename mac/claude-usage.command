#!/bin/zsh -l
# Double-click in Finder to open Claude Code on /usage in Terminal.
cd "$HOME"
claude="$HOME/.local/bin/claude"
[ -x "$claude" ] || claude="$(command -v claude)"
exec "$claude" --dangerously-skip-permissions "/usage"
