#!/usr/bin/env bash
#
# billAnaly - One-Click Start
# macOS / Linux version.  Windows users: run start.bat instead.
#
# Usage:
#   chmod +x start.sh && ./start.sh
#   or:  bash start.sh
#
set -u

cd "$(dirname "$0")" || exit 1

VENV_DIR="venv"
VENV_PY="$VENV_DIR/bin/python"
PORT=8000

# pip mirror - faster downloads in China. Set to "" to use the default PyPI.
MIRROR="https://pypi.tuna.tsinghua.edu.cn/simple"

echo "============================================================"
echo "               billAnaly - One-Click Start"
echo "============================================================"
echo

open_browser() {
    case "$(uname -s)" in
        Darwin) open "$1" >/dev/null 2>&1 || true ;;
        *)      xdg-open "$1" >/dev/null 2>&1 || true ;;
    esac
}

# ================= 1. Python interpreter =================
if [ -x "$VENV_PY" ]; then
    echo "[1/5] Virtual environment already exists, skipping."
else
    echo "[1/5] First run: creating virtual environment..."

    PYCMD=""
    for c in python3 python; do
        if command -v "$c" >/dev/null 2>&1; then
            PYCMD="$c"
            break
        fi
    done

    if [ -z "$PYCMD" ]; then
        echo
        echo "[ERROR] Python 3 not found. Please install Python 3.10 or newer:"
        echo "        macOS : brew install python3   (or download from python.org)"
        echo "        Ubuntu: sudo apt install python3 python3-venv"
        echo
        exit 1
    fi

    if ! "$PYCMD" -m venv "$VENV_DIR"; then
        echo
        echo "[ERROR] Failed to create the virtual environment."
        echo "        On Debian/Ubuntu you may also need: sudo apt install python3-venv"
        echo
        exit 1
    fi
    echo "      Virtual environment created."
fi

# ================= 2. Dependencies =================
if "$VENV_PY" -c "import fastapi,uvicorn,openai,yaml,pandas,matplotlib,numpy" >/dev/null 2>&1; then
    echo "[2/5] Dependencies already installed, skipping."
else
    echo "[2/5] Installing dependencies (the first run can take a few minutes)..."

    if [ -n "$MIRROR" ]; then
        "$VENV_PY" -m pip install --upgrade pip -i "$MIRROR" || true
        PIP_OK=0
        "$VENV_PY" -m pip install -r requirements.txt -i "$MIRROR" || PIP_OK=1
    else
        "$VENV_PY" -m pip install --upgrade pip || true
        PIP_OK=0
        "$VENV_PY" -m pip install -r requirements.txt || PIP_OK=1
    fi

    if [ "$PIP_OK" -ne 0 ]; then
        echo
        echo "[ERROR] Failed to install dependencies. Check your network and retry."
        exit 1
    fi
    echo "      Dependencies installed."
fi

# ================= 3. Configuration =================
if [ ! -f config.yaml ]; then
    echo "[3/5] config.yaml not found, copying from config-example.yaml..."
    cp config-example.yaml config.yaml
    echo "      Created. Remember to fill in your DeepSeek API Key."
    echo
elif grep -q "sk-" config.yaml 2>/dev/null; then
    echo "[3/5] config.yaml OK."
else
    echo
    echo "[NOTE] No DeepSeek API Key found in config.yaml."
    echo "       Bookkeeping and charts still work, but AI features will fail."
    echo
fi

# ================= 4. Port check =================
if command -v lsof >/dev/null 2>&1; then
    if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
        echo
        echo "[NOTE] Port $PORT is already in use - the service may already be running."
        echo "       Opening the browser now."
        echo "       To restart, stop the existing service first (Ctrl+C in its window)."
        echo
        open_browser "http://localhost:$PORT/manager.html"
        exit 0
    fi
fi

# ================= 5. Start the service =================
echo "[5/5] Starting the service..."
echo
echo "    Manager  : http://localhost:$PORT/manager.html"
echo "    Dashboard: http://localhost:$PORT/dashboard.html"
echo
echo "    The two pages link to each other at the top."
echo "    Press Ctrl+C to stop the service."
echo

# Open the browser a few seconds later, in the background.
( sleep 4; open_browser "http://localhost:$PORT/manager.html" ) &

export PYTHONIOENCODING=utf-8
exec "$VENV_PY" server.py
