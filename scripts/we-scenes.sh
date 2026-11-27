#!/usr/bin/env bash
# Список обоев Wallpaper Engine из Мастерской Steam: scene (папка) и video (файл).
#   we-scenes.sh          -> "<путь>\t<название>" по строке на обои
#   we-scenes.sh --dirs   -> только пути
#   we-scenes.sh --thumbs -> "<путь>\t<папка с preview.*>"
WS="${WE_WORKSHOP:-$HOME/.local/share/Steam/steamapps/workshop/content/431960}"
[ -d "$WS" ] || exit 0
python3 -I - "$WS" "$1" <<'EOF'
import json, os, sys
ws, mode = sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else ""
VIDEO = (".mp4", ".webm", ".mkv", ".mov", ".m4v")
rows = []
for d in os.listdir(ws):
    p = os.path.join(ws, d)
    try:
        with open(os.path.join(p, "project.json"), encoding="utf-8-sig") as f:
            j = json.load(f)
    except Exception:
        continue
    kind = str(j.get("type", "")).lower()
    if kind == "scene":
        path = p
    elif kind == "video":
        fn = str(j.get("file") or "")
        path = os.path.join(p, fn)
        if not fn or not fn.lower().endswith(VIDEO) or not os.path.isfile(path):
            continue
    else:
        continue  # web/application обои поставить нечем
    title = " ".join(str(j.get("title") or d).split())
    rows.append((title.lower(), path, p, title))
for _, path, d, title in sorted(rows):
    if mode == "--dirs":
        print(path)
    elif mode == "--thumbs":
        print(f"{path}\t{d}")
    else:
        print(f"{path}\t{title}")
EOF
