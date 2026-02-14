#!/bin/bash
QUERY="${1:?Usage: search.sh <query> [directory]}"
DIR="${2:-}"
LIMIT=50

if [ -n "$DIR" ]; then
    mdfind -onlyin "$DIR" "$QUERY" | head -n "$LIMIT"
else
    mdfind "$QUERY" | head -n "$LIMIT"
fi
