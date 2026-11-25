#!/usr/bin/env bash
# Fetch lyrics from lrclib.net with search fallback

title="$1"
artist="$2"
album="${3:-}"
duration="${4:-0}"

if [ -z "$title" ] || [ -z "$artist" ]; then
    exit 1
fi

python3 - "$title" "$artist" "$album" "$duration" <<'PY'
import json
import sys
import urllib.parse
import urllib.request

title, artist, album, duration_s = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
duration = 0.0
try:
    duration = float(duration_s)
except ValueError:
    duration = 0.0


def normalize(text):
    return (text or "").lower().strip()


def score_result(result):
    score = 0
    t = normalize(title)
    a = normalize(artist)
    rt = normalize(result.get("trackName", ""))
    ra = normalize(result.get("artistName", ""))
    if rt == t:
        score += 4
    elif t in rt or rt in t:
        score += 2
    if ra == a or a in ra or ra in a:
        score += 3
    elif any(part.strip() and part.strip() in ra for part in a.split(",")):
        score += 1
    if duration > 0 and abs(float(result.get("duration") or 0) - duration) <= 4:
        score += 2
    if album and normalize(album) == normalize(result.get("albumName", "")):
        score += 1
    if result.get("syncedLyrics"):
        score += 1
    return score


def http_get_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": "quickshell-music-panel/1.0"})
    with urllib.request.urlopen(req, timeout=12) as resp:
        return json.load(resp)


def try_get(params):
    url = "https://lrclib.net/api/get?" + urllib.parse.urlencode(params)
    return http_get_json(url)


def try_search(query):
    url = "https://lrclib.net/api/search?" + urllib.parse.urlencode({"q": query})
    return http_get_json(url)


def has_lyrics(data):
    return bool((data.get("plainLyrics") or "").strip() or (data.get("syncedLyrics") or "").strip())


def pick_best(results):
    best = None
    best_score = 0
    for item in results or []:
        score = score_result(item)
        if score > best_score:
            best_score = score
            best = item
    if best_score >= 4:
        return best
    return None


data = None

get_params = {"track_name": title, "artist_name": artist}
if album:
    get_params["album_name"] = album
if duration > 0:
    get_params["duration"] = int(round(duration))

try:
    candidate = try_get(get_params)
    if has_lyrics(candidate):
        data = candidate
except Exception:
    pass

if data is None:
    queries = [
        f"{title} {artist}",
        f"{artist} {title}",
        title,
    ]
    seen_ids = set()
    for query in queries:
        try:
            results = try_search(query)
        except Exception:
            continue
        best = pick_best(results)
        if not best:
            continue
        best_id = best.get("id")
        if best_id in seen_ids:
            continue
        seen_ids.add(best_id)
        if has_lyrics(best):
            data = best
            break
        try:
            candidate = try_get({
                "track_name": best.get("trackName", title),
                "artist_name": best.get("artistName", artist),
                "album_name": best.get("albumName", album),
                "duration": int(round(float(best.get("duration") or duration or 0))),
            })
            if has_lyrics(candidate):
                data = candidate
                break
        except Exception:
            continue

if not data or not has_lyrics(data):
    sys.exit(1)

plain = (data.get("plainLyrics") or "").replace("\r\n", "\n")
synced = (data.get("syncedLyrics") or "").replace("\r\n", "\n")

print("PLAIN\x1e" + plain)
print("SYNCED\x1e" + synced)
PY
