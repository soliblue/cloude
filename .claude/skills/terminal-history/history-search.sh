#!/bin/bash

PATTERN="${1:?Usage: history-search.sh <pattern> [limit]}"
LIMIT="${2:-30}"

parse_zsh_history() {
    local file="$1"
    local current_cmd=""
    local current_ts=""

    while IFS= read -r line; do
        if [[ "$line" =~ ^:[[:space:]]([0-9]+):[0-9]+\;(.*)$ ]]; then
            if [[ -n "$current_cmd" ]]; then
                printf "%s\n" "${current_ts}|${current_cmd}"
            fi
            current_ts="${BASH_REMATCH[1]}"
            current_cmd="${BASH_REMATCH[2]}"
        elif [[ -n "$current_ts" ]]; then
            current_cmd="${current_cmd} ${line}"
        fi
    done < "$file"

    if [[ -n "$current_cmd" ]]; then
        printf "%s\n" "${current_ts}|${current_cmd}"
    fi
}

parse_bash_history() {
    local file="$1"
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        printf "0|%s\n" "$line"
    done < "$file"
}

format_output() {
    while IFS='|' read -r ts cmd; do
        if [[ "$ts" -gt 0 ]] 2>/dev/null; then
            date_str=$(date -r "$ts" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")
        else
            date_str="unknown"
        fi
        printf "%s|%s\n" "$date_str" "$cmd"
    done
}

if [[ -f "$HOME/.zsh_history" ]]; then
    parse_zsh_history "$HOME/.zsh_history" | grep -i "$PATTERN" | tail -n "$LIMIT" | tail -r | format_output
elif [[ -f "$HOME/.bash_history" ]]; then
    parse_bash_history "$HOME/.bash_history" | grep -i "$PATTERN" | tail -n "$LIMIT" | tail -r | format_output
else
    echo "No history file found (~/.zsh_history or ~/.bash_history)" >&2
    exit 1
fi
