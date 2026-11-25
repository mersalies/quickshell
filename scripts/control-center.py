#!/usr/bin/env python3
"""Сохранение настроек «Пульта» quickshell.

  control-center.py cursor  '{"theme": "Bibata-Modern-Ice", "size": 24}'
  control-center.py monitors '[{"output": "eDP-2", "mode": "1920x1080@144", ...}]'

Состояние хранится в quickshell/state/control-center.json, из него
генерируется ~/.config/hypr/control-center.lua (его читает hyprland.lua).
Для курсора дополнительно применяется тема сразу везде: Hyprland, GTK, X11.
"""
import json
import os
import re
import subprocess
import sys

HOME = os.path.expanduser("~")
STATE = os.path.join(HOME, ".config/quickshell/state/control-center.json")
LUA = os.path.join(HOME, ".config/hypr/control-center.lua")
SAFE = re.compile(r"^[A-Za-z0-9._+@-]+$")


def lua_str(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


def lua_val(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    return lua_str(v)


def atomic_write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        f.write(text)
    os.replace(tmp, path)


def render_lua(state):
    out = ["-- Сгенерировано пунктом управления quickshell. Правки вручную будут перезаписаны.", "return {"]
    c = state.get("cursor")
    if c:
        out.append(f"    cursor = {{ theme = {lua_str(c['theme'])}, size = {int(c['size'])} }},")
    out.append("    monitors = {")
    for m in state.get("monitors", []):
        fields = ", ".join(f"{k} = {lua_val(v)}" for k, v in m.items())
        out.append(f"        {{ {fields} }},")
    out.append("    },")
    out.append("}")
    return "\n".join(out) + "\n"


def set_ini(path, section, key, value):
    lines = open(path).read().splitlines() if os.path.exists(path) else []
    sec, done, res = None, False, []
    for ln in lines:
        m = re.match(r"^\s*\[(.+)\]\s*$", ln)
        if m:
            if sec == section and not done:
                res.append(f"{key}={value}")
                done = True
            sec = m.group(1)
        elif sec == section and re.match(rf"^\s*{re.escape(key)}\s*=", ln):
            if not done:
                res.append(f"{key}={value}")
                done = True
            continue
        res.append(ln)
    if not done:
        if sec != section:
            res.append(f"[{section}]")
        res.append(f"{key}={value}")
    atomic_write(path, "\n".join(res) + "\n")


def apply_cursor(theme, size):
    subprocess.run(["hyprctl", "setcursor", theme, str(size)], capture_output=True)
    subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "cursor-theme", theme], capture_output=True)
    subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "cursor-size", str(size)], capture_output=True)
    for gtk in ("gtk-3.0", "gtk-4.0"):
        p = os.path.join(HOME, ".config", gtk, "settings.ini")
        if os.path.exists(p):
            set_ini(p, "Settings", "gtk-cursor-theme-name", theme)
            set_ini(p, "Settings", "gtk-cursor-theme-size", str(size))
    atomic_write(os.path.join(HOME, ".icons/default/index.theme"),
                 f"[Icon Theme]\nName=Default\nComment=Default cursor theme\nInherits={theme}\n")


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ("cursor", "monitors"):
        sys.exit(__doc__)
    what, payload = sys.argv[1], json.loads(sys.argv[2])
    try:
        state = json.load(open(STATE))
    except Exception:
        state = {}

    if what == "cursor":
        theme, size = str(payload["theme"]), int(payload["size"])
        if not SAFE.match(theme) or not 8 <= size <= 128:
            sys.exit("bad cursor")
        apply_cursor(theme, size)
        state["cursor"] = {"theme": theme, "size": size}
    else:
        mons = []
        for m in payload:
            mons.append({
                "output": str(m["output"]),
                "mode": str(m["mode"]),
                "position": str(m["position"]),
                "scale": float(m.get("scale", 1)),
                "transform": int(m.get("transform", 0)),
            })
        state["monitors"] = mons

    atomic_write(STATE, json.dumps(state, indent=2, ensure_ascii=False))
    atomic_write(LUA, render_lua(state))
    print("ok")


if __name__ == "__main__":
    main()
