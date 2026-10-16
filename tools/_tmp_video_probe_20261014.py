# -*- coding: utf-8 -*-
"""Agnes Video 2.5 Flash 接口探针(2026-10-14):POST /v1videos 建任务 → GET /agnesapi 轮询。
mode=text 已实测合法(text2video/t2v/i2v 均报 invalid mode);503 video_queue_full=队满退避重试;
429=免费档限流换 key。产物打印原始 JSON,视频 URL 落 docs/卡图API重生成_20261014/raw/。
用法: python tools/_tmp_video_probe_20261014.py [prompt]
"""
import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.request

WS = os.path.dirname(os.path.abspath(os.path.join(__file__, "..")))
IMG = "https://apihub.agnes-ai.com/v1/videos"
QRY = "https://apihub.agnes-ai.com/agnesapi?video_id=%s&model_name=agnes-video-2.5"
CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE
MODEL = "agnes-video-2.5-flash"

KEYS = [l.strip() for l in open(os.path.join(WS, "tools", "_api_key.txt"), encoding="utf-8")
        if l.strip().startswith("sk-")]
PROMPT = sys.argv[1] if len(sys.argv) > 1 else (
    "Side view of a green WWII tank slowly rolling from right to left across a flat "
    "magenta background, then firing once with a small orange muzzle flash, "
    "2D game sprite style, flat lighting, no camera movement")


def http(url, body=None, key=None, timeout=300):
    hdr = {"Content-Type": "application/json"}
    if key:
        hdr["Authorization"] = "Bearer " + key
    req = urllib.request.Request(url, data=json.dumps(body).encode() if body else None,
                                 headers=hdr)
    try:
        r = urllib.request.urlopen(req, timeout=timeout, context=CTX)
        return r.code, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw)
        except Exception:
            return e.code, {"raw": raw[:200]}


def create():
    for att in range(120):
        key = KEYS[att % len(KEYS)]
        code, js = http(IMG, {"model": MODEL, "prompt": PROMPT, "mode": "text"}, key)
        tag = "att%d %s" % (att, key[:10])
        if code in (200, 201):
            print("[%s] created: %s" % (tag, json.dumps(js, ensure_ascii=False)[:400]), flush=True)
            return js
        print("[%s] HTTP %d %s" % (tag, code, json.dumps(js, ensure_ascii=False)[:180]), flush=True)
        time.sleep(120 if code == 503 else 30)
    raise SystemExit("create: 120 次尝试全败")


def poll(video_id, minutes=25):
    seen = None
    for i in range(minutes * 4):
        code, js = http(QRY % video_id, None, KEYS[0], 60)
        blob = json.dumps(js, ensure_ascii=False)
        print("[poll %02d] HTTP %d %s" % (i, code, blob[:300]), flush=True)
        if code == 200:
            st = js.get("status") or (js.get("data") or {}).get("status") or ""
            if st != seen:
                print("  status: %s" % st, flush=True)
                seen = st
            if st in ("succeeded", "success", "completed", "done"):
                return js
            if st in ("failed", "error"):
                return js
        time.sleep(15)
    return None


def main():
    js = create()
    vid = js.get("video_id") or (js.get("data") or {}).get("video_id") or js.get("id")
    print("video_id =", vid, flush=True)
    if not vid:
        raise SystemExit("无 video_id, 停")
    out = poll(vid)
    print("final:", json.dumps(out, ensure_ascii=False, indent=1)[:2000] if out else "轮询超时", flush=True)


if __name__ == "__main__":
    main()
