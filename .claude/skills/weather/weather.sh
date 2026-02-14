#!/bin/bash
CITY="${1:-Berlin}"
MODE="${2:-}"

if [ "$MODE" = "full" ]; then
    curl -s "wttr.in/${CITY}?format=v2"
else
    curl -s "wttr.in/${CITY}?format=%l:+%c+%t+%h+%w+%p\n"
fi
