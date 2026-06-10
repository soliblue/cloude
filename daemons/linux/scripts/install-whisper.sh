#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENV="$DIR/whisper-env"
MODELS="$DIR/whisper-models"

echo "Installing faster-whisper into $VENV"
python3 -m venv "$VENV"
"$VENV/bin/pip" install --quiet --upgrade pip
"$VENV/bin/pip" install --quiet faster-whisper

echo "Warming the base model into $MODELS"
"$VENV/bin/python" -c "from faster_whisper import WhisperModel; WhisperModel('base', device='cpu', compute_type='int8', download_root='$MODELS')"

echo "whisper ready"
