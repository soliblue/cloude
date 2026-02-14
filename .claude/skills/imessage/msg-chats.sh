#!/bin/bash
LIMIT="${1:-20}"
python3 "$(dirname "$0")/decode-body.py" chats "$LIMIT"
