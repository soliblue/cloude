#!/bin/bash
QUERY="${1:?Usage: msg-search.sh <query> [limit]}"
LIMIT="${2:-20}"
python3 "$(dirname "$0")/decode-body.py" search "$QUERY" "$LIMIT"
