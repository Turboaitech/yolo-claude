@echo off
setlocal enabledelayedexpansion
title RTX PRO 6000 - Claude Code (whatever model the box serves, YOLO)

rem === Claude Code against a 2x RTX PRO 6000 box behind an Anthropic-compatible gateway. ===
rem Settings live in a local file that is NOT in this repo:
rem     %USERPROFILE%\.local\bin\yolo-6000.env.cmd
rem with lines like:
rem     set "YOLO_6000_HOSTS=6000.local 192.168.1.50"   (tried in order)
rem     set "YOLO_6000_PORT=8899"
rem     set "YOLO_6000_KEY=sk-..."                      (gateway API key)
rem     set "YOLO_6000_CTX=131072"                       (server context window)
rem The model is NOT hardcoded: the first non "+web" id from /v1/models is used.

set "ENVFILE=%USERPROFILE%\.local\bin\yolo-6000.env.cmd"
if exist "%ENVFILE%" call "%ENVFILE%"
if not defined YOLO_6000_HOSTS (
    echo.
    echo Missing settings. Create %ENVFILE% with YOLO_6000_HOSTS, YOLO_6000_PORT and YOLO_6000_KEY.
    pause
    exit /b 1
)
if not defined YOLO_6000_PORT set "YOLO_6000_PORT=8899"
if not defined YOLO_6000_KEY set "YOLO_6000_KEY=sk-local"
if not defined YOLO_6000_CTX set "YOLO_6000_CTX=131072"

set "BASE="
for %%H in (%YOLO_6000_HOSTS%) do (
    if not defined BASE (
        curl.exe -sf --max-time 4 "http://%%H:%YOLO_6000_PORT%/health" >nul 2>&1
        if not errorlevel 1 set "BASE=http://%%H:%YOLO_6000_PORT%"
    )
)
if not defined BASE (
    echo.
    echo Could not reach any of: %YOLO_6000_HOSTS% on port %YOLO_6000_PORT%.
    echo Is the box up and the gateway running?
    pause
    exit /b 1
)

set "MODEL_ID="
for /f "delims=" %%I in ('powershell -NoProfile -Command "$h=@{Authorization='Bearer %YOLO_6000_KEY%'}; ((Invoke-RestMethod -Uri '%BASE%/v1/models' -Headers $h -TimeoutSec 10).data | Where-Object { $_.id -notlike '*+web' } | Select-Object -First 1).id" 2^>nul') do set "MODEL_ID=%%I"
if not defined MODEL_ID (
    echo Reached %BASE% but could not read a model id from /v1/models. Check YOLO_6000_KEY.
    pause
    exit /b 1
)

set "ANTHROPIC_BASE_URL=%BASE%"
set "ANTHROPIC_AUTH_TOKEN=%YOLO_6000_KEY%"
set "ANTHROPIC_API_KEY="
set "ANTHROPIC_MODEL=%MODEL_ID%"
set "ANTHROPIC_DEFAULT_OPUS_MODEL=%MODEL_ID%"
set "ANTHROPIC_DEFAULT_SONNET_MODEL=%MODEL_ID%"
set "ANTHROPIC_DEFAULT_HAIKU_MODEL=%MODEL_ID%"
set "ANTHROPIC_SMALL_FAST_MODEL=%MODEL_ID%"
set "CLAUDE_CODE_SUBAGENT_MODEL=%MODEL_ID%"
set "CLAUDE_CODE_MAX_CONTEXT_TOKENS=%YOLO_6000_CTX%"
set "CLAUDE_CODE_MAX_OUTPUT_TOKENS=32000"
set "MAX_THINKING_TOKENS=0"
set "DISABLE_TELEMETRY=1"
set "DISABLE_ERROR_REPORTING=1"
set "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"
set "CLAUDE_CODE_DISABLE_AUTO_MEMORY=1"

set "CLAUDE_BIN=%USERPROFILE%\.local\bin\claude.exe"
if not exist "%CLAUDE_BIN%" (
    for /f "delims=" %%I in ('where claude 2^>nul') do (
        set "CLAUDE_BIN=%%I"
        goto :resolved
    )
)
:resolved
if not exist "%CLAUDE_BIN%" (
    echo Could not find claude. Install it with:
    echo     irm https://claude.ai/install.ps1 ^| iex
    pause
    exit /b 1
)

echo.
echo Model      : %MODEL_ID%
echo Context    : %YOLO_6000_CTX% tokens
echo Endpoint   : %BASE%  (RTX PRO 6000)
echo.

call "%CLAUDE_BIN%" --model "%MODEL_ID%" --effort "low" --dangerously-skip-permissions

if errorlevel 1 (
    echo.
    echo Claude Code exited with an error. Press any key to close.
    pause >nul
)
endlocal
