#!/bin/bash
# awesome-function-calling - Local Docs Viewer (macOS)
# Double-click this file to run it. If macOS blocks it the first time,
# right-click -> Open, then confirm. See INSTRUCTION.md Section 12.

cd "$(dirname "$0")"

echo "====================================================================="
echo "  awesome-function-calling - Local Viewer (Was made by Oleh Datsyk)"
echo "====================================================================="
echo ""
echo "NOTE: This repository is a documentation project,"
echo "not a running application. This script starts a"
echo "simple local web server so you can browse the"
echo "Markdown/JSON files in your web browser, then"
echo "opens your browser automatically."
echo ""

fail() {
    echo ""
    echo "[ERROR] $1"
    echo "See INSTRUCTION.md for setup steps and Troubleshooting."
    echo ""
    read -n 1 -s -r -p "Press any key to close this window..."
    exit 1
}

# --- Step 1: Check Python is installed ---
echo "[1/4] Checking for Python..."
if command -v python3 >/dev/null 2>&1; then
    PYTHON=python3
elif command -v python >/dev/null 2>&1; then
    PYTHON=python
else
    fail "Python was not found. Install it from https://www.python.org/downloads/ (see INSTRUCTION.md, Section 1), then run this script again."
fi
PYVER=$($PYTHON --version 2>&1)
echo "      Found $PYVER"
echo ""

# --- Step 2: Check for optional virtual environment ---
echo "[2/4] Checking for virtual environment..."
if [ -f "venv/bin/activate" ]; then
    echo "      Found existing virtual environment. Activating..."
    source "venv/bin/activate"
else
    echo "      No virtual environment found (none is required for this"
    echo "      docs-only repo). Skipping. See INSTRUCTION.md Section 7"
    echo "      if you want to create one for experimenting with code snippets."
fi
echo ""

# --- Step 3: Check for .env file (informational only - not required) ---
echo "[3/4] Checking for .env file..."
if [ -f ".env" ]; then
    echo "      Found .env file."
else
    echo "      No .env file found. This is expected - this repo does not"
    echo "      call any live APIs, so no API keys are required."
fi
echo ""

# --- Step 4: Start local server and open browser ---
echo "[4/4] Starting local server on http://localhost:8000 ..."
echo "      Press CTRL+C in this window to stop the server when you're done."
echo ""

( sleep 1 && open "http://localhost:8000" ) &

$PYTHON -m http.server 8000
STATUS=$?

if [ $STATUS -ne 0 ]; then
    fail "The local server failed to start or exited unexpectedly."
fi

read -n 1 -s -r -p "Server stopped. Press any key to close this window..."
