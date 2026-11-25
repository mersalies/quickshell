#!/usr/bin/env bash
# Список scene-обоев Wallpaper Engine из Мастерской Steam.
#   we-scenes.sh          -> "<папка>\t<название>" по строке на обои
#   we-scenes.sh --dirs   -> только папки
WS="${WE_WORKSHOP:-$HOME/.local/share/Steam/steamapps/workshop/content/431960}"
[ -d "$WS" ] || exit 0
python3 -I - "$WS" "$1" <<'EOF'
import json, os, sys
ws, mode = sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else ""
rows = []
for d in os.listdir(ws):
    p = os.path.join(ws, d)
    try:
        with open(os.path.join(p, "project.json"), encoding="utf-8-sig") as f:
            j = json.load(f)
    except Exception:
        continue
    if str(j.get("type", "")).lower() != "scene":
        continue
    title = " ".join(str(j.get("title") or d).split())
    rows.append((title.lower(), p, title))
for _, p, title in sorted(rows):
    print(p if mode == "--dirs" else f"{p}\t{title}")
EOF
