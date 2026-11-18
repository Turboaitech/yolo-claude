#!/bin/zsh -l
# Double-click in Finder to open Codex in YOLO mode (no approvals, no sandbox).
cd "$HOME"
exec codex --dangerously-bypass-approvals-and-sandbox
