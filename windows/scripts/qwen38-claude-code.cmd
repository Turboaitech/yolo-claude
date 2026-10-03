@echo off
setlocal
title Qwen 3.8 27B - Claude Code (No Thinking)

set "ANTHROPIC_AUTH_TOKEN=ollama"
set "ANTHROPIC_API_KEY="
set "ANTHROPIC_BASE_URL=http://127.0.0.1:11434"
set "MAX_THINKING_TOKENS=0"
set "DISABLE_TELEMETRY=1"
set "DISABLE_ERROR_REPORTING=1"
set "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"

curl.exe -s --max-time 3 http://127.0.0.1:11434/api/version >nul 2>&1
if errorlevel 1 (
    echo Starting Ollama...
    start "" /min ollama serve
    timeout /t 3 /nobreak >nul
)

echo Claude Code is using local model: qwen3.8-claude-nothink
echo API endpoint: http://127.0.0.1:11434
echo Thinking: disabled
echo.
call "C:\nvm4w\nodejs\claude.cmd" --model "qwen3.8-claude-nothink" --effort "low" --dangerously-skip-permissions

if errorlevel 1 (
    echo.
    echo Claude Code exited with an error. Press any key to close.
    pause >nul
)

endlocal
