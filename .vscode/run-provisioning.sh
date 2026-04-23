#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROVISIONING_DIR="$ROOT_DIR/provisioning"
PYTHON_BIN="${PYTHON_BIN:-python3.13}"
HOST="${PROVISIONING_HOST:-127.0.0.1}"
PORT="${PROVISIONING_PORT:-8080}"
VENV_DIR="$PROVISIONING_DIR/.venv"

cd "$PROVISIONING_DIR"

if [[ ! -x "$VENV_DIR/bin/python" ]]; then
  "$PYTHON_BIN" -m venv "$VENV_DIR"
fi

"$VENV_DIR/bin/pip" install -q -r requirements.txt

echo "Launching provisioning server on http://$HOST:$PORT"
exec "$VENV_DIR/bin/uvicorn" app.main:app --host "$HOST" --port "$PORT" --reload
