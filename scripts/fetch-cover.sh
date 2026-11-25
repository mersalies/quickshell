#!/usr/bin/env bash
# Resolve album art to a local file:// path. Tries MPRIS artUrl, then Yandex, iTunes, Deezer.

title="$1"
artist="$2"
album="${3:-}"
arturl="${4:-}"

if [ -z "$title" ] || [ -z "$artist" ]; then
    exit 1
fi

export PYTHONUNBUFFERED=1

python3 - "$title" "$artist" "$album" "$arturl" <<'PY'
import hashlib
import json
import os
import re
import socket
import subprocess
import sys
import urllib.parse
import urllib.request

_orig_getaddrinfo = socket.getaddrinfo

def _ipv4_getaddrinfo(host, port, family=0, type=0, proto=0, flags=0):
    return _orig_getaddrinfo(host, port, socket.AF_INET, type, proto, flags)

socket.getaddrinfo = _ipv4_getaddrinfo

title, artist, album, arturl = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
cache_dir = os.path.join(
    os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")),
    "quickshell",
    "covers",
)
os.makedirs(cache_dir, mode=0o755, exist_ok=True)
cache_key = hashlib.sha256(f"{artist}\x1f{title}\x1f{album}".encode()).hexdigest()


def normalize(text):
    return re.sub(r"\s+", " ", (text or "").lower().strip())


def score_pair(result_title, result_artist):
    score = 0
    t = normalize(title)
    a = normalize(artist)
    rt = normalize(result_title)
    ra = normalize(result_artist)
    if rt == t:
        score += 4
    elif t and (t in rt or rt in t):
        score += 2
    if ra == a:
        score += 3
    elif a and (a in ra or ra in a):
        score += 3
    elif any(part.strip() and part.strip() in ra for part in a.split(",")):
        score += 1
    return score


def is_image(path):
    try:
        with open(path, "rb") as handle:
            header = handle.read(16)
    except OSError:
        return False
    return (
        header.startswith(b"\xff\xd8")
        or header.startswith(b"\x89PNG")
        or header.startswith(b"GIF8")
        or (header.startswith(b"RIFF") and b"WEBP" in header)
    )


def ext_for(path):
    try:
        with open(path, "rb") as handle:
            header = handle.read(16)
    except OSError:
        return ".jpg"
    if header.startswith(b"\x89PNG"):
        return ".png"
    if header.startswith(b"GIF8"):
        return ".gif"
    if header.startswith(b"RIFF") and b"WEBP" in header:
        return ".webp"
    return ".jpg"


def cached_path():
    for ext in (".jpg", ".png", ".webp", ".gif"):
        path = os.path.join(cache_dir, cache_key + ext)
        if os.path.isfile(path) and os.path.getsize(path) > 100:
            return path
    return ""


def publish(path):
    final = os.path.join(cache_dir, cache_key + ext_for(path))
    if os.path.abspath(path) != os.path.abspath(final):
        os.replace(path, final)
    print("file://" + final, flush=True)
    sys.exit(0)


def curl_get(url, dest, timeout=4):
    if not url.startswith("http://") and not url.startswith("https://"):
        return False
    tmp = dest + ".part"
    cmd = [
        "curl", "-4", "-fsSL",
        "--max-time", str(timeout),
        "--max-redirs", "3",
        "-A", "quickshell-music-panel/1.0",
        "-o", tmp,
        url,
    ]
    try:
        result = subprocess.run(cmd, check=False, capture_output=True)
        if result.returncode != 0 or not os.path.isfile(tmp) or os.path.getsize(tmp) < 100:
            if os.path.exists(tmp):
                os.remove(tmp)
            return False
        if not is_image(tmp):
            os.remove(tmp)
            return False
        os.replace(tmp, dest)
        return True
    except Exception:
        if os.path.exists(tmp):
            os.remove(tmp)
        return False


def copy_local(url):
    path = url
    if path.startswith("file://"):
        path = path[7:]
    if not path.startswith("/"):
        return ""
    if not os.path.isfile(path) or os.path.getsize(path) < 100 or not is_image(path):
        return ""
    dest = os.path.join(cache_dir, cache_key + ".src")
    try:
        with open(path, "rb") as src, open(dest, "wb") as out:
            out.write(src.read())
        if is_image(dest):
            return dest
    except OSError:
        pass
    if os.path.exists(dest):
        os.remove(dest)
    return ""


def http_get_json(url, timeout=8):
    req = urllib.request.Request(url, headers={"User-Agent": "quickshell-music-panel/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.load(resp)


def rewrite_spotify(url):
    return url.replace("https://open.spotify.com/image/", "https://i.scdn.co/image/")


def normalize_arturl(url):
    url = (url or "").strip()
    if not url:
        return ""
    url = rewrite_spotify(url)
    if url.startswith("//"):
        url = "https:" + url
    elif not re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", url):
        if url.startswith("/") or url.startswith("file://"):
            return url
        if "yandex.net/" in url or url.startswith("avatars."):
            url = "https://" + url.lstrip("/")
    url = url.replace("%%", "400x400")
    return url


def try_arturl(url):
    url = normalize_arturl(url)
    if not url:
        return False
    dest = os.path.join(cache_dir, cache_key + ".dl")
    local = copy_local(url)
    if local:
        publish(local)
    host = (urllib.parse.urlparse(url).hostname or "").lower()
    if host.endswith("scdn.co") or host.endswith("spotify.com"):
        return False
    if curl_get(url, dest, timeout=4):
        publish(dest)
    return False


def try_yandex():
    query = urllib.parse.urlencode({
        "text": f"{artist} {title}",
        "type": "track",
        "page": 0,
    })
    try:
        data = http_get_json("https://api.music.yandex.net/search?" + query)
    except Exception:
        return False
    tracks = ((data.get("result") or {}).get("tracks") or {}).get("results") or []
    best = None
    best_score = 0
    for track in tracks:
        arts = ", ".join(a.get("name", "") for a in (track.get("artists") or []))
        score = score_pair(track.get("title", ""), arts)
        albums = track.get("albums") or []
        if album and albums and normalize(album) == normalize((albums[0] or {}).get("title", "")):
            score += 1
        if score > best_score:
            best_score = score
            best = track
    if not best or best_score < 5:
        return False
    cover = (best.get("coverUri") or "")
    if not cover and best.get("albums"):
        cover = (best["albums"][0] or {}).get("coverUri") or ""
    if not cover:
        return False
    cover = cover.replace("%%", "400x400")
    if cover.startswith("//"):
        cover = "https:" + cover
    elif not cover.startswith("http"):
        cover = "https://" + cover
    dest = os.path.join(cache_dir, cache_key + ".dl")
    if curl_get(cover, dest, timeout=6):
        publish(dest)
    return False


def try_itunes():
    for country in ("ru", "us"):
        query = urllib.parse.urlencode({
            "term": f"{artist} {title}",
            "entity": "song",
            "limit": 5,
            "country": country,
        })
        try:
            data = http_get_json("https://itunes.apple.com/search?" + query)
        except Exception:
            continue
        best = None
        best_score = 0
        for item in data.get("results") or []:
            score = score_pair(item.get("trackName", ""), item.get("artistName", ""))
            if album and normalize(album) == normalize(item.get("collectionName", "")):
                score += 1
            if score > best_score:
                best_score = score
                best = item
        if not best or best_score < 5:
            continue
        art = best.get("artworkUrl100") or ""
        if not art:
            continue
        art = art.replace("100x100bb", "600x600bb").replace("100x100", "600x600")
        dest = os.path.join(cache_dir, cache_key + ".dl")
        if curl_get(art, dest, timeout=6):
            publish(dest)
    return False


def try_deezer():
    query = urllib.parse.urlencode({"q": f"{artist} {title}", "limit": 5})
    try:
        data = http_get_json("https://api.deezer.com/search?" + query)
    except Exception:
        return False
    best = None
    best_score = 0
    for item in data.get("data") or []:
        arts = (item.get("artist") or {}).get("name", "")
        score = score_pair(item.get("title", ""), arts)
        if score > best_score:
            best_score = score
            best = item
    if not best or best_score < 5:
        return False
    art = (best.get("album") or {}).get("cover_medium") or (best.get("album") or {}).get("cover_big") or ""
    if not art:
        return False
    dest = os.path.join(cache_dir, cache_key + ".dl")
    if curl_get(art, dest, timeout=6):
        publish(dest)
    return False


hit = cached_path()
if hit:
    print("file://" + hit, flush=True)
    sys.exit(0)

try_arturl(arturl)
try_yandex()
try_itunes()
try_deezer()
sys.exit(1)
PY
