@echo off
setlocal enabledelayedexpansion
title DGX Spark - Claude Code (whatever model the Spark serves, YOLO)

rem === Claude Code against a DGX Spark serving an Anthropic-compatible API. ===
rem Settings live in a local file that is NOT in this repo:
rem     %USERPROFILE%\.local\bin\yolo-spark.env.cmd
rem with lines like:
rem     set "YOLO_SPARK_HOSTS=100.x.y.z 192.168.1.9"   (tailnet first, LAN fallback)
rem     set "YOLO_SPARK_PORT=8888"
rem The model is NOT hardcoded: it is read from /v1/models every launch.

set "ENVFILE=%USERPROFILE%\.local\bin\yolo-spark.env.cmd"
if exist "%ENVFILE%" call "%ENVFILE%"
if not defined YOLO_SPARK_HOSTS (
    echo.
    echo Missing settings. Create %ENVFILE% with YOLO_SPARK_HOSTS and YOLO_SPARK_PORT.
    pause
    exit /b 1
)
if not defined YOLO_SPARK_PORT set "YOLO_SPARK_PORT=8888"

set "BASE="
for %%H in (%YOLO_SPARK_HOSTS%) do (
    if not defined BASE (
        curl.exe -sf --max-time 4 "http://%%H:%YOLO_SPARK_PORT%/v1/models" >nul 2>&1
        if not errorlevel 1 set "BASE=http://%%H:%YOLO_SPARK_PORT%"
    )
)
if not defined BASE (
    echo.
    echo Could not reach the Spark on %YOLO_SPARK_HOSTS% port %YOLO_SPARK_PORT%.
    echo Is Tailscale up? Is the server running?
    pause
    exit /b 1
)

set "MODEL_ID="
set "SERVER_CTX="
for /f "delims=" %%I in ('powershell -NoProfile -Command "(Invoke-RestMethod -Uri '%BASE%/v1/models' -TimeoutSec 10).data[0].id" 2^>nul') do set "MODEL_ID=%%I"
for /f "delims=" %%I in ('powershell -NoProfile -Command "$m=(Invoke-RestMethod -Uri '%BASE%/v1/models' -TimeoutSec 10).data[0]; if($m.max_model_len){$m.max_model_len}elseif($m.context_length){$m.context_length}" 2^>nul') do set "SERVER_CTX=%%I"
if not defined MODEL_ID (
    echo Reached %BASE% but could not read a model id from /v1/models.
    pause
    exit /b 1
)
if not defined SERVER_CTX set "SERVER_CTX=131072"

set "ANTHROPIC_BASE_URL=%BASE%"
set "ANTHROPIC_AUTH_TOKEN=sk-local"
set "ANTHROPIC_API_KEY="
set "ANTHROPIC_MODEL=%MODEL_ID%"
set "ANTHROPIC_DEFAULT_OPUS_MODEL=%MODEL_ID%"
set "ANTHROPIC_DEFAULT_SONNET_MODEL=%MODEL_ID%"
set "ANTHROPIC_DEFAULT_HAIKU_MODEL=%MODEL_ID%"
set "ANTHROPIC_SMALL_FAST_MODEL=%MODEL_ID%"
set "CLAUDE_CODE_SUBAGENT_MODEL=%MODEL_ID%"
set "CLAUDE_CODE_MAX_CONTEXT_TOKENS=%SERVER_CTX%"
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
echo Context    : %SERVER_CTX% tokens
echo Endpoint   : %BASE%  (DGX Spark)
echo.

call "%CLAUDE_BIN%" --model "%MODEL_ID%" --effort "low" --dangerously-skip-permissions

if errorlevel 1 (
    echo.
    echo Claude Code exited with an error. Press any key to close.
    pause >nul
)
endlocal
