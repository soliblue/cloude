#!/bin/bash

LIMIT="${1:-20}"

extract_commands() {
    local file="$1"
    local format="$2"

    if [[ "$format" == "zsh" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^:[[:space:]][0-9]+:[0-9]+\;(.*)$ ]]; then
                printf "%s\n" "${BASH_REMATCH[1]}"
            fi
        done < "$file"
    else
        while IFS= read -r line; do
            [[ -n "$line" ]] && printf "%s\n" "$line"
        done < "$file"
    fi
}

get_first_word() {
    while IFS= read -r cmd; do
        first="${cmd%% *}"
        [[ -n "$first" ]] && printf "%s\n" "$first"
    done
}

if [[ -f "$HOME/.zsh_history" ]]; then
    extract_commands "$HOME/.zsh_history" "zsh" | get_first_word | sort | uniq -c | sort -rn | head -n "$LIMIT" | while read -r count cmd; do
        printf "%s|%s\n" "$count" "$cmd"
    done
elif [[ -f "$HOME/.bash_history" ]]; then
    extract_commands "$HOME/.bash_history" "bash" | get_first_word | sort | uniq -c | sort -rn | head -n "$LIMIT" | while read -r count cmd; do
        printf "%s|%s\n" "$count" "$cmd"
    done
else
    echo "No history file found (~/.zsh_history or ~/.bash_history)" >&2
    exit 1
fi
