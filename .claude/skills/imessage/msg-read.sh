#!/bin/bash
CONTACT="${1:?Usage: msg-read.sh <phone_or_email> [limit]}"
LIMIT="${2:-30}"
python3 "$(dirname "$0")/decode-body.py" read "$CONTACT" "$LIMIT"
