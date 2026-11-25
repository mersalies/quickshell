#!/usr/bin/env bash
# Compact media info for the top bar

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
line=$("$SCRIPT_DIR/media-poll.sh")

IFS=$'\x1f' read -r status title artist arturl pos len player show_cover <<< "$line"

if [ "$status" = "Playing" ] || [ "$status" = "Paused" ]; then
    if [ -n "$title" ]; then
        text="$title"
        [ -n "$artist" ] && text="$artist - $title"
        if [ ${#text} -gt 35 ]; then
            text="${text:0:32}..."
        fi
        pos_int=${pos%%.*}
        len_int=${len%%.*}
        printf '%s|%s|%s|%s\n' "$status" "$text" "${pos_int:-0}" "${len_int:-0}"
    else
        echo "stopped||0|0"
    fi
else
    echo "stopped||0|0"
fi
