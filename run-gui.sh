#!/bin/bash
# ============================================================
#  run-gui.sh – Launch the Offline Package Downloader GUI
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT=5000
URL="http://localhost:${PORT}"

echo "=================================================="
echo "📦 Starting Offline Package Downloader GUI"
echo "=================================================="

# Check Python 3
if ! command -v python3 > /dev/null 2>&1; then
    echo "❌ Error: Python 3 is required." >&2
    exit 1
fi

# Check Docker
if ! command -v docker > /dev/null 2>&1; then
    echo "❌ Error: Docker is required to download packages." >&2
    exit 1
fi

# Start python server in background
python3 "${SCRIPT_DIR}/app.py" &
SERVER_PID=$!

cleanup() {
    echo ""
    echo "Shutting down GUI server..."
    kill $SERVER_PID 2>/dev/null || true
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# Wait a moment for the server to start
sleep 1

echo "🌐 GUI Server is running at: ${URL}"
echo "Opening browser..."

# Open in default browser on Ubuntu
if command -v xdg-open > /dev/null 2>&1; then
    xdg-open "${URL}" > /dev/null 2>&1 &
elif command -v sensible-browser > /dev/null 2>&1; then
    sensible-browser "${URL}" > /dev/null 2>&1 &
elif command -v google-chrome > /dev/null 2>&1; then
    google-chrome "${URL}" > /dev/null 2>&1 &
elif command -v firefox > /dev/null 2>&1; then
    firefox "${URL}" > /dev/null 2>&1 &
fi

echo "Press Ctrl+C to stop the GUI server."
wait $SERVER_PID
