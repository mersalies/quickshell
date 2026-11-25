#!/usr/bin/env python3
"""Список курсорных тем + PNG-превью (стрелка, рука, текст, ожидание).

Вывод: JSON-массив [{name, dir, previews: [png, ...]}] в stdout.
Превью кэшируются в ~/.cache/quickshell/cursors/<theme>/<shape>.png
"""
import json
import os
import struct
import sys
import zlib

HOME = os.path.expanduser("~")
ROOTS = [os.path.join(HOME, ".icons"), os.path.join(HOME, ".local/share/icons"), "/usr/share/icons"]
CACHE = os.path.join(HOME, ".cache/quickshell/cursors")
SHAPES = [
    ("arrow", ["left_ptr", "default", "arrow"]),
    ("hand", ["pointer", "hand2", "hand1", "pointing_hand"]),
    ("text", ["text", "xterm", "ibeam"]),
    ("wait", ["wait", "watch", "left_ptr_watch", "progress"]),
]
WANT = 48


def read_xcursor(path):
    """Возвращает (w, h, argb_bytes) кадра, ближайшего к WANT px."""
    with open(path, "rb") as f:
        data = f.read()
    if data[:4] != b"Xcur":
        return None
    _hsize, _ver, ntoc = struct.unpack_from("<III", data, 4)
    best = None
    for i in range(ntoc):
        typ, sub, pos = struct.unpack_from("<III", data, 16 + i * 12)
        if typ != 0xFFFD0002:
            continue
        if best is None or abs(sub - WANT) < abs(best[0] - WANT):
            best = (sub, pos)
    if not best:
        return None
    pos = best[1]
    _hdr, _t, _s, _v, w, h, _xh, _yh, _d = struct.unpack_from("<9I", data, pos)
    px = data[pos + 36: pos + 36 + w * h * 4]
    return w, h, px


def write_png(path, w, h, argb):
    rows = bytearray()
    for y in range(h):
        rows.append(0)
        for x in range(w):
            b, g, r, a = argb[(y * w + x) * 4:(y * w + x) * 4 + 4]
            if a:  # Xcursor хранит premultiplied alpha
                r, g, b = min(255, r * 255 // a), min(255, g * 255 // a), min(255, b * 255 // a)
            rows += bytes((r, g, b, a))

    def chunk(tag, payload):
        c = tag + payload
        return struct.pack(">I", len(payload)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b"")
    tmp = path + ".tmp"
    with open(tmp, "wb") as f:
        f.write(png)
    os.replace(tmp, path)


def main():
    seen = set()
    themes = []
    for root in ROOTS:
        if not os.path.isdir(root):
            continue
        for name in sorted(os.listdir(root), key=str.lower):
            cdir = os.path.join(root, name, "cursors")
            if name in seen or name == "default" or not os.path.isdir(cdir):
                continue
            seen.add(name)
            previews = []
            outdir = os.path.join(CACHE, name)
            for shape, candidates in SHAPES:
                out = os.path.join(outdir, shape + ".png")
                if not os.path.exists(out):
                    for c in candidates:
                        src = os.path.join(cdir, c)
                        if not os.path.exists(src):
                            continue
                        try:
                            img = read_xcursor(os.path.realpath(src))
                        except Exception:
                            img = None
                        if img:
                            os.makedirs(outdir, exist_ok=True)
                            write_png(out, *img)
                            break
                if os.path.exists(out):
                    previews.append(out)
            if previews:
                themes.append({"name": name, "dir": os.path.join(root, name), "previews": previews})
    json.dump(themes, sys.stdout)


if __name__ == "__main__":
    main()
