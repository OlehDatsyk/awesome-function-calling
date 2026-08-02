@echo off
setlocal EnableDelayedExpansion
title awesome-function-calling - Local Docs Viewer
cd /d "%~dp0"

echo ============================================
echo   awesome-function-calling - Local Viewer
echo ============================================
echo.
echo NOTE: This repository is a documentation project,
echo not a running application. This script starts a
echo simple local web server so you can browse the
echo Markdown/JSON files in your web browser, then
echo opens your browser automatically.
echo.

REM --- Step 1: Check Python is installed ---
echo [1/4] Checking for Python...
where python >nul 2>nul
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Python was not found on your system PATH.
    echo Please install Python from https://www.python.org/downloads/
    echo IMPORTANT: during install, check the box "Add python.exe to PATH".
    echo See INSTRUCTION.md, Section 1, for full steps.
    echo.
    pause
    exit /b 1
)
for /f "tokens=2" %%v in ('python --version 2^>^&1') do set PYVER=%%v
echo       Found Python %PYVER%
echo.

REM --- Step 2: Check for optional virtual environment ---
echo [2/4] Checking for virtual environment...
if exist "venv\Scripts\activate.bat" (
    echo       Found existing virtual environment. Activating...
    call "venv\Scripts\activate.bat"
) else (
    echo       No virtual environment found ^(none is required for this
    echo       docs-only repo^). Skipping. See INSTRUCTION.md Section 7
    echo       if you want to create one for experimenting with code snippets.
)
echo.

REM --- Step 3: Check for .env file (informational only - not required) ---
echo [3/4] Checking for .env file...
if exist ".env" (
    echo       Found .env file.
) else (
    echo       No .env file found. This is expected - this repo does not
    echo       call any live APIs, so no API keys are required.
)
echo.

REM --- Step 4: Start local server and open browser ---
echo [4/4] Starting local server on http://localhost:8000 ...
echo       Press CTRL+C in this window to stop the server when you're done.
echo.
start "" http://localhost:8000
python -m http.server 8000
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] The local server failed to start or exited unexpectedly.
    echo See the Troubleshooting section of INSTRUCTION.md.
    echo.
    pause
    exit /b 1
)

pause
