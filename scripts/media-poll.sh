#!/usr/bin/env bash
# Poll active MPRIS player with priority for music apps

find_player() {
    local listed p st
    for p in spotify yandex yandexmusic yandex-music; do
        for listed in $(playerctl -l 2>/dev/null); do
            if echo "$listed" | grep -qi "$p"; then
                st=$(playerctl --player="$listed" status 2>/dev/null)
                if [ "$st" = "Playing" ] || [ "$st" = "Paused" ]; then
                    echo "$listed"
                    return 0
                fi
            fi
        done
    done
    for listed in $(playerctl -l 2>/dev/null); do
        st=$(playerctl --player="$listed" status 2>/dev/null)
        if [ "$st" = "Playing" ] || [ "$st" = "Paused" ]; then
            echo "$listed"
            return 0
        fi
    done
    return 1
}

PLAYER=$(find_player) || true

if [ -z "$PLAYER" ]; then
    printf '%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\n' \
        "Stopped" "" "" "" "0" "0" "" "0" ""
    exit 0
fi

status=$(playerctl --player="$PLAYER" status 2>/dev/null)
title=$(playerctl --player="$PLAYER" metadata title 2>/dev/null)
artist=$(playerctl --player="$PLAYER" metadata artist 2>/dev/null)
album=$(playerctl --player="$PLAYER" metadata album 2>/dev/null)
[ -z "$album" ] && album="-"
arturl=$(playerctl --player="$PLAYER" metadata mpris:artUrl 2>/dev/null)
pos=$(playerctl --player="$PLAYER" position 2>/dev/null)
len_us=$(playerctl --player="$PLAYER" metadata mpris:length 2>/dev/null)
len=$(awk -v l="$len_us" 'BEGIN { if (l+0 > 0) printf "%.3f", l/1000000; else print "0" }')

show_cover=0
if echo "$PLAYER" | grep -qiE 'spotify|yandex'; then
    if [ -n "$arturl" ]; then
        show_cover=1
    fi
fi

# Use unit separator (0x1F) between fields to avoid issues with | in metadata
printf '%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\n' \
    "$status" "$title" "$artist" "$arturl" "$pos" "$len" "$PLAYER" "$show_cover" "$album"
