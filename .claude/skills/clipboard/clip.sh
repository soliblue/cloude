#!/bin/bash
MODE="${1:-read}"

case "$MODE" in
    read)
        CONTENT=$(pbpaste)
        if [ -z "$CONTENT" ]; then
            echo "Clipboard is empty"
        else
            echo "$CONTENT" | head -c 10000
            if [ ${#CONTENT} -gt 10000 ]; then
                echo ""
                echo "[TRUNCATED — clipboard content exceeds 10,000 characters]"
            fi
        fi
        ;;
    write)
        shift
        echo -n "$*" | pbcopy
        echo "Copied to Mac clipboard"
        ;;
    *)
        echo "Usage: clip.sh [read|write \"text\"]"
        ;;
esac
