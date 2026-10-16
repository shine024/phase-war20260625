# -*- coding: utf-8 -*-
"""视频攻击动作试验批（2026-10-15）：011/012/017 三单位，agnes-video-2.5-flash keyframe 模式。

用户口径：红底首帧（主体军绿/铁灰与纯红零冲突）。管线：
  现役卡图 → 红底 1280x720 首帧 → imgbb → POST api.agnes-ai.cn/v1/videos (mode=keyframe)
  → 轮询 /agnesapi → 下载 mp4 → ffmpeg 8fps 抽帧 → 红键控 → 统一缩放拼 attack sheet
产物只落暂存 docs/卡图API重生成_20261014/video_trial/，目检后才谈部署。
用法：python tools/_tmp_video_attack_trial.py 011,012,017
"""
import base64
import glob
import io
import json
import os
import ssl
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "卡图API重生成_20261014", "video_trial")
CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE
BASE = "https://api.agnes-ai.cn/v1"
QUERY = "https://api.agnes-ai.cn/agnesapi"
MODEL = "agnes-video-2.5-flash"
IMGBB_KEY = "05948b794b00406bb44955b722d15e65"
FFMPEG = shutil.which("ffmpeg") if (shutil := __import__("shutil")) else None
FFMPEG = FFMPEG or r"C:\ProgramData\chocolatey\bin\ffmpeg.exe"

UNITS_V = {
    "011": dict(name="81mm迫击炮",
                prompt="The same olive-green automatic 81mm mortar weapon from the first frame on the solid pure red background: the mortar FIRES one round, a compact orange muzzle flash at the upward-pointing muzzle with a small smoke puff, the auto-loader arm dips to feed the next round, the whole weapon rocks slightly on its base from the recoil, then settles back to the ready stance. Keep the exact same solid pure red #FF0000 background in every frame, the weapon stays the same size and position, full body visible, no camera movement."),
    "012": dict(name="81mm迫击炮组",
                prompt="The same riveted automatic trench mortar with chain feed and brass gears from the first frame on the solid pure red background: the mortar FIRES, a compact orange muzzle flash at the upward-pointing muzzle, the chain ammunition belt advances by one link and the brass gears turn one notch, the tube presses slightly down from recoil then eases back. Keep the exact same solid pure red #FF0000 background in every frame, the weapon stays the same size and position, full body visible, no camera movement."),
    "017": dict(name="ZSU-23-4自行高炮",
                prompt="CRITICAL: the entire video keeps the exact same flat pure red #FF0000 background as the first frame in EVERY frame - absolutely no scenery, no ground, no sand, no bushes, no sky change; the vehicle hovers over pure red. The same Soviet ZSU-23-4 anti-aircraft gun vehicle from the first frame: the quad 23mm autocannon cluster FIRES a short burst toward the upper left, rapid compact orange muzzle flashes at the four barrel tips, small casings ejecting from the turret side, the hull rocks slightly on its suspension and the radar dish stays raised. Keep the exact same solid pure red #FF0000 background in every frame, the vehicle stays the same size and position, full body visible, no camera movement."),
}

INV_NOTE = "红键判据: r>150 & g<0.55r & b<0.55r（红底），加角点中位色距回退"


def http_json(url, payload=None, key=None, timeout=120):
    hdrs = {"User-Agent": "Mozilla/5.0"}
    data = None
    if payload is not None:
        data = json.dumps(payload).encode()
        hdrs["Content-Type"] = "application/json"
    if key:
        hdrs["Authorization"] = "Bearer " + key
    req = urllib.request.Request(url, data=data, headers=hdrs)
    with urllib.request.urlopen(req, timeout=timeout, context=CTX) as r:
        return json.loads(r.read().decode("utf-8", "ignore"))


def keys():
    return [l.strip() for l in open(os.path.join(ROOT, "tools", "_api_key.txt"),
                                    encoding="utf-8") if l.strip()]


def imgbb_upload(path):
    b64 = base64.b64encode(open(path, "rb").read()).decode()
    body = urllib.parse.urlencode({
        "key": IMGBB_KEY, "image": b64, "expiration": "86400",
        "name": os.path.splitext(os.path.basename(path))[0]}).encode()
    last = None
    for att in range(4):  # imgbb 偶发 SSL 握手超时，重试 4 次
        req = urllib.request.Request("https://api.imgbb.com/1/upload", data=body,
                                     headers={"Content-Type": "application/x-www-form-urlencoded"})
        try:
            with urllib.request.urlopen(req, timeout=120, context=CTX) as r:
                d = json.loads(r.read().decode())
            if not d.get("success"):
                raise RuntimeError("imgbb failed: " + json.dumps(d)[:200])
            return d["data"]["url"]
        except Exception as e:
            last = e
            print("  imgbb retry %d: %r" % (att + 1, e)[:100], flush=True)
            time.sleep(8)
    raise RuntimeError("imgbb upload failed: %r" % last)


def make_first_frame(no, name):
    im = Image.open(os.path.join(ROOT, "docs", "卡图API重生成_20261014",
                                 "cut", "%s·%s.png" % (no, name))).convert("RGBA")
    im.thumbnail((760, 620))
    ff = Image.new("RGB", (1280, 720), (255, 0, 0))
    ff.paste(im, ((1280 - im.width) // 2, (720 - im.height) // 2), im)
    p = os.path.join(OUT, "%s_red.jpg" % no)
    ff.save(p, quality=95)
    return p


def create_task(no, cfg):
    # data URI 首帧（红底 1280x720 本地合成直传）——imgbb 已不可用（SSL 中断）
    ff = make_first_frame(no, cfg["name"])
    buf = io.BytesIO()
    Image.open(ff).convert("RGB").save(buf, "JPEG", quality=90)
    url = "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()
    payload = {"model": MODEL, "prompt": cfg["prompt"], "seconds": "3",
               "mode": "keyframe", "size": "720P", "aspect_ratio": "16:9",
               "first_frame": url}
    last = None
    for att in range(30):  # 503 队满长退避骑穿；403/401 熔断
        k = keys()[att % len(keys())]
        try:
            d = http_json(BASE + "/videos", payload, key=k, timeout=120)
            vid = d.get("video_id") or d.get("id") or d.get("task_id")
            print("  [%s] task created: %s" % (no, vid), flush=True)
            return vid, url
        except urllib.error.HTTPError as e:
            last = e.read().decode("utf-8", "ignore")[:150]
            print("  [%s] HTTP %d %s" % (no, e.code, last), flush=True)
            if e.code == 403 or e.code == 401:
                raise SystemExit(3)
            if e.code == 503:
                time.sleep(60 + min(att, 20) * 10)
                continue
        except Exception as e:
            last = repr(e)[:150]
            print("  [%s] err %s" % (no, last), flush=True)
            time.sleep(8)
    raise RuntimeError("create %s failed: %s" % (no, last))


def find_mp4(obj, hits):
    if isinstance(obj, dict):
        for k2, v in obj.items():
            if isinstance(v, str) and (".mp4" in v.lower()):
                hits.append(v)
            else:
                find_mp4(v, hits)
    elif isinstance(obj, list):
        for it in obj:
            find_mp4(it, hits)


def poll_task(no, vid, max_wait=1800):
    t0 = time.time()
    while time.time() - t0 < max_wait:
        for k in keys():
            try:
                url = QUERY + "?" + urllib.parse.urlencode(
                    {"video_id": vid, "model_name": MODEL})
                d = http_json(url, key=k, timeout=60)
                hits = []
                find_mp4(d, hits)
                if hits:
                    return hits[0]
                st = json.dumps(d)[:160]
                print("  [%s] poll: %s" % (no, st), flush=True)
                break
            except urllib.error.HTTPError as e:
                body = e.read().decode("utf-8", "ignore")[:120]
                print("  [%s] poll HTTP %d %s" % (no, e.code, body), flush=True)
                if e.code in (401, 403):
                    raise SystemExit(3)
                time.sleep(15)
            except Exception as e:
                print("  [%s] poll err %r" % (no, e), flush=True)
                time.sleep(15)
        time.sleep(20)
    raise RuntimeError("poll %s timeout" % no)


def download(url, path):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=300, context=CTX) as r, open(path, "wb") as f:
        while True:
            c = r.read(65536)
            if not c:
                break
            f.write(c)
    return os.path.getsize(path)


def key_red(im):
    a = np.asarray(im.convert("RGB")).astype(int)
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    mag = (r > 150) & (g < 0.55 * r) & (b < 0.55 * r)
    alpha = np.where(mag, 0, 255).astype(np.uint8)
    return np.dstack([a.astype(np.uint8), alpha])


def build_sheet(no, mp4):
    import numpy as np
    fdir = os.path.join(OUT, "%s_frames" % no)
    os.makedirs(fdir, exist_ok=True)
    subprocess.run([FFMPEG, "-y", "-i", mp4, "-vf", "fps=8",
                    os.path.join(fdir, "f%02d.png")], capture_output=True)
    frames = sorted(glob.glob(os.path.join(fdir, "f*.png")))
    keyed = []
    for f in frames:
        arr = key_red(Image.open(f))
        if (arr[:, :, 3] > 0).mean() > 0.92:  # 全不透明=红底没认出（压缩漂移），跳过空帧
            continue
        keyed.append(arr)
    if not keyed:
        print("  [%s] 无有效键控帧", no)
        return
    masks = [k[:, :, 3] > 0 for k in keyed]
    union = np.logical_or.reduce(masks)
    ys, xs = np.nonzero(union)
    ux0, ux1, uy0, uy1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    FS = 256
    scale = min(int(FS * 0.88) / (ux1 - ux0), int(FS * 0.90) / (uy1 - uy0))
    sheet = Image.new("RGBA", (FS * len(keyed), FS), (0, 0, 0, 0))
    for i, arr in enumerate(keyed):
        sub = arr[uy0:uy1, ux0:ux1]
        h, w = sub.shape[:2]
        nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
        fr = Image.fromarray(sub, "RGBA").resize((nw, nh), Image.LANCZOS)
        cv = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
        cv.paste(fr, ((FS - nw) // 2, FS - nh - int(round(0.055 * FS))), fr)
        sheet.paste(cv, (i * FS, 0))
    out = os.path.join(OUT, "%s_sheet_attack_trial.png" % no)
    sheet.save(out)
    print("  [%s] sheet: %d 帧 -> %s" % (no, len(keyed), os.path.basename(out)),
          flush=True)


import numpy as np  # noqa: E402


def main(nos):
    os.makedirs(OUT, exist_ok=True)
    for no in nos:
        cfg = UNITS_V[no]
        tfile = os.path.join(OUT, "%s_task.json" % no)
        print("[%s·%s]" % (no, cfg["name"]), flush=True)
        if os.path.exists(tfile):
            vid = json.load(open(tfile))["video_id"]
        else:
            vid, url = create_task(no, cfg)
            json.dump({"video_id": vid, "created": time.time()},
                      open(tfile, "w"))
        mp4 = os.path.join(OUT, "%s.mp4" % no)
        if not os.path.exists(mp4):
            src = poll_task(no, vid)
            n = download(src, mp4)
            print("  [%s] mp4 %.1fMB" % (no, n / 1e6), flush=True)
        build_sheet(no, mp4)
    print("TRIAL DONE", flush=True)


if __name__ == "__main__":
    nos = (sys.argv[1].split(",") if len(sys.argv) > 1 else ["011", "012", "017"])
    main(nos)
