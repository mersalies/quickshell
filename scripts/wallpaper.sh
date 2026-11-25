#!/usr/bin/env bash
# Смена обоев: картинки/GIF через awww, видео через mpvpaper или слой quickshell,
# scene-обои Wallpaper Engine (папка из Мастерской) через linux-wallpaperengine.
# Обои можно ставить на все мониторы сразу или на каждый отдельно.
#   wallpaper.sh set <path> [mpvpaper|quickshell] [--no-wal] [--output <монитор|all>]
#   wallpaper.sh restore [mpvpaper|quickshell]   (при старте Hyprland / смене бэкенда)
#   wallpaper.sh list                            (монитор<TAB>путь для каждого монитора)
#   wallpaper.sh still <path>                    (печатает путь к статичному кадру)
#   wallpaper.sh watch                           (пауза сцен на мониторах с полноэкранным окном)
# Последняя строка вывода `set` — путь к статичной картинке (для pywal/блюра).
# Состояние: ~/wallpapers/current-<монитор> — обои монитора, ~/wallpapers/current — последние выбранные.

WALL_DIR="$HOME/wallpapers"
STATE_DIR="$HOME/.config/quickshell/state"
FRAME_DIR="$HOME/.cache/wallpaper-frames"
MPV_OPTS="no-audio loop hwdec=auto-safe panscan=1.0 profile=fast"
WE_FPS=30
WE_LOG="$HOME/.cache/linux-wallpaperengine.log"
WE_PATTERN='^(\./|/[^ ]*/)?linux-wallpaperengine( |$)'

# Scene-обои — это папка Мастерской Wallpaper Engine (appid 431960)
is_scene() { [ -d "$1" ] && [ -f "$1/project.json" ]; }

is_video() {
    case "${1,,}" in
        *.mp4|*.webm|*.mkv|*.mov|*.m4v) return 0 ;;
        *) return 1 ;;
    esac
}

monitors() { hyprctl monitors -j | jq -r '.[].name'; }

# Обои монитора (с откатом на общие)
wall_of() {
    local p
    p=$(readlink -f "$WALL_DIR/current-$1" 2>/dev/null)
    [ -e "$p" ] || p=$(readlink -f "$WALL_DIR/current" 2>/dev/null)
    [ -e "$p" ] || p="$WALL_DIR/Balcony-ja.png"
    echo "$p"
}

backend_state() {
    local b
    b=$(cat "$STATE_DIR/wall-backend" 2>/dev/null)
    [ -n "$b" ] && echo "$b" || echo mpvpaper
}

# Кадр из видео — подложка под видео, источник цветов pywal и блюра для hyprlock
still_of() {
    local f="$1"
    mkdir -p "$FRAME_DIR"
    local out="$FRAME_DIR/$(echo -n "$f" | md5sum | cut -d' ' -f1).jpg"
    if is_scene "$f"; then
        # Превью из Мастерской (jpg или gif) -> jpg
        local prev
        prev=$(ls "$f"/preview.* 2>/dev/null | head -1)
        if [ -n "$prev" ] && { [ ! -s "$out" ] || [ "$prev" -nt "$out" ]; }; then
            convert "${prev}[0]" -quality 92 "$out" 2>/dev/null ||
            ffmpeg -nostdin -v error -y -i "$prev" -frames:v 1 -q:v 2 "$out" 2>/dev/null
        fi
        echo "$out"; return
    fi
    if ! is_video "$f"; then echo "$f"; return; fi
    if [ ! -s "$out" ] || [ "$f" -nt "$out" ]; then
        ffmpeg -nostdin -v error -y -ss 1 -i "$f" -frames:v 1 -q:v 2 "$out" 2>/dev/null ||
        ffmpeg -nostdin -v error -y -i "$f" -frames:v 1 -q:v 2 "$out" 2>/dev/null
    fi
    echo "$out"
}

wait_awww() {
    for _ in $(seq 1 50); do
        awww query >/dev/null 2>&1 && return 0
        sleep 0.1
    done
}

# В режиме quickshell без mpvpaper откатываемся на quickshell
effective_backend() {
    local b="$1"
    if [ "$b" = mpvpaper ] && ! command -v mpvpaper >/dev/null 2>&1; then b=quickshell; fi
    echo "$b"
}

# mpvpaper запускается отдельным процессом на каждый монитор
stop_mpv() {
    pkill -f -- "^mpvpaper .* ALL /" 2>/dev/null   # старый общий процесс
    pkill -f -- "^mpvpaper .* $1 /" 2>/dev/null
}

start_mpv() {
    stop_mpv "$1"
    # -p: пауза, когда обои не видно (полноэкранное окно)
    setsid -f mpvpaper -p -o "$MPV_OPTS" "$1" "$2" >/dev/null 2>&1
}

WATCH_PATTERN='wallpaper\.sh watch$'

# Свой linux-wallpaperengine на каждый монитор со сценой. Встроенная пауза движка
# останавливает все экраны сразу, поэтому она выключена (--no-fullscreen-pause),
# а паузу по мониторам делает `wallpaper.sh watch`.
stop_watch() {
    local p
    # setsid делает watch лидером группы — гасим вместе с socat
    for p in $(pgrep -f "$WATCH_PATTERN"); do kill -TERM -- "-$p" 2>/dev/null || kill "$p" 2>/dev/null; done
}

refresh_engine() {
    stop_watch
    pkill -CONT -f "$WE_PATTERN" 2>/dev/null   # остановленный процесс не получит TERM
    pkill -f "$WE_PATTERN" 2>/dev/null
    command -v linux-wallpaperengine >/dev/null 2>&1 || return 0
    local m p started=""
    sleep 0.2
    for m in $(monitors); do
        p=$(wall_of "$m")
        is_scene "$p" || continue
        # --silent: без звука
        setsid -f linux-wallpaperengine --silent --fps "$WE_FPS" --no-fullscreen-pause \
            --screen-root "$m" --bg "$p" --scaling fill >>"$WE_LOG" 2>&1
        started=1
    done
    [ -n "$started" ] && setsid -f bash "$0" watch >/dev/null 2>&1
}

# Пауза сцены только на том мониторе, где открыто окно на весь экран
apply_pause() {
    local covered m pids
    covered=$(hyprctl workspaces -j | jq -r --argjson mons "$(hyprctl monitors -j)" '
        [.[] | select(.hasfullscreen) | .id] as $fs
        | $mons[] | select(.activeWorkspace.id as $w | $fs | index($w)) | .name')
    for m in $(monitors); do
        pids=$(pgrep -f -- "linux-wallpaperengine .*--screen-root $m --bg") || continue
        if grep -qxF "$m" <<<"$covered"; then kill -STOP $pids; else kill -CONT $pids; fi
    done
}

cmd_watch() {
    local sock="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
    trap 'pkill -CONT -f "$WE_PATTERN" 2>/dev/null; exit 0' TERM INT
    apply_pause
    while pgrep -f "$WE_PATTERN" >/dev/null; do
        socat -u "UNIX-CONNECT:$sock" - 2>/dev/null | while IFS= read -r ev; do
            case "$ev" in
                fullscreen\>\>*|workspace*|focusedmon*|movewindow*|closewindow*|openwindow*|changefloatingmode*|activespecial*|monitoradded*|monitorremoved*)
                    apply_pause ;;
            esac
        done
        sleep 1
    done
}

# Поставить обои на один монитор (без перезапуска движка сцен)
apply_one() {
    local path="$1" backend="$2" out="$3" still="$4" trans="${5:-1}"
    ln -sfn "$path" "$WALL_DIR/current-$out"
    if is_scene "$path"; then
        stop_mpv "$out"
        awww img -o "$out" "$still" --transition-type any --transition-duration "$trans" &
    elif is_video "$path"; then
        awww img -o "$out" "$still" --transition-type any --transition-duration "$trans" &
        if [ "$backend" = mpvpaper ]; then start_mpv "$out" "$path"; else stop_mpv "$out"; fi
    else
        stop_mpv "$out"
        awww img -o "$out" "$path" --transition-type any --transition-duration 2 &
    fi
}

cmd_set() {
    local path="" backend="" no_wal="" output=all
    while [ $# -gt 0 ]; do
        case "$1" in
            --no-wal) no_wal=1 ;;
            --output) output="$2"; shift ;;
            --output=*) output="${1#--output=}" ;;
            mpvpaper|quickshell) backend="$1" ;;
            *) [ -z "$path" ] && path="$1" ;;
        esac
        shift
    done
    path="${path%/}"
    [ -e "$path" ] || { echo "нет файла: $path" >&2; exit 1; }
    backend=$(effective_backend "${backend:-$(backend_state)}")

    local outs m had_scene=""
    if [ "$output" = all ] || [ -z "$output" ]; then outs=$(monitors); else outs="$output"; fi

    for m in $outs; do is_scene "$(wall_of "$m")" && had_scene=1; done
    # Мониторы без своей записи закрепляем на текущих обоях, пока `current` не сменился
    for m in $(monitors); do
        [ -L "$WALL_DIR/current-$m" ] || ln -sfn "$(wall_of "$m")" "$WALL_DIR/current-$m"
    done

    local still
    still=$(still_of "$path")
    ln -sfn "$path" "$WALL_DIR/current"
    for m in $outs; do apply_one "$path" "$backend" "$m" "$still"; done

    if is_scene "$path" || [ -n "$had_scene" ]; then refresh_engine; fi

    [ -n "$no_wal" ] || wal -i "$still" -n -q
    wait
    echo "$still"
}

cmd_restore() {
    local backend m p
    backend=$(effective_backend "${1:-$(backend_state)}")
    wait_awww
    for m in $(monitors); do
        p=$(wall_of "$m")
        apply_one "$p" "$backend" "$m" "$(still_of "$p")"
    done
    refresh_engine
    wait
}

cmd_list() {
    local m
    for m in $(monitors); do printf '%s\t%s\n' "$m" "$(wall_of "$m")"; done
}

case "$1" in
    set) shift; cmd_set "$@" ;;
    restore) cmd_restore "$2" ;;
    list) cmd_list ;;
    watch) cmd_watch ;;
    still) still_of "$2" ;;
    *) echo "usage: $0 set <path> [mpvpaper|quickshell] [--no-wal] [--output <mon|all>] | restore [backend] | list | still <path>" >&2; exit 2 ;;
esac
