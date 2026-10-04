# -*- coding: utf-8 -*-
"""B4 relight 轮：对 staging 里过不了白底亮度门的 raw 做 img2img 双图回收。
Image1=本单位的暗图（结构锚定，逐部件重合）；Image2=亮度/风格基准（官方成品卡）。
只修光照配色不动结构——img25 relight_prompt 卡图域适配版。
用法: python tools/_b4_relight.py            # 全部 DARK 件
      python tools/_b4_relight.py <case_id>  # 指定件
"""
import base64, io, json, os, subprocess, sys, time
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEYS = [k for k in __import__("re").findall(r"sk-[A-Za-z0-9]{20,}",
        open(os.path.join(ROOT, "tools", "_agnes_image_api.md"), encoding="utf-8").read())]
API = "https://apihub.agnes-ai.cn/v1/images/generations"
STAGE = os.path.join(ROOT, ".godot", "b4_card_staging")
MODEL = "agnes-image-2.5-flash"
REF = os.path.join(ROOT, "assets", "card_icons", "player", "vis_player_002.png")  # ft17：亮部充足的成品基准

RELIGHT = ("第一张图是一张构图正确的游戏卡图立绘，但它被画得过于昏暗、接近黑色剪影；"
           "第二张图是亮度与画风基准（官方成品卡图）。\n"
           "请输出一张新图，要求：\n"
           "【保持】完全保持第一张图的视角、构图、全部部件组成、姿态与大小——主体轮廓与第一张图逐部件重合，"
           "不新增、不删除、不简化任何部件；背景保持整幅纯白平涂，无地面无阴影无场景。\n"
           "【只修光照与配色】按第二张图的明度基调重打光：主体完全受光、照明充足，高光、中间调、暗部层次分明，"
           "材质细节（纹理、舱盖、履带、武器结构、布料褶皱）清晰可读；整体明度对齐第二张图——"
           "最亮处接近第二张图的高光亮度，最暗部位也不得比第二张图的最暗部位更暗；"
           "色相保持第一张图的冷灰蓝涂装身份，不换成暖色涂装。\n"
           "【风格】厚涂插画（thick painterly illustration），无黑色描边、无卡通勾线。\n"
           "【严禁】黑色剪影、逆光、背光、暗场照明、整体压暗、单色深色轮廓块、"
           "改变视角或姿态、增删部件、文字、水印、边框。")


def uri_of(path):
    with open(path, "rb") as f:
        return "data:image/png;base64," + base64.b64encode(f.read()).decode()


def gen(payload, tag):
    pp = os.path.join(STAGE, "_payload.json")
    with open(pp, "w", encoding="utf-8") as f:
        f.write(json.dumps(payload))
    for i in range(3):
        r = subprocess.run(["curl", "--http1.1", "-s", "-X", "POST", API,
                            "-H", "Authorization: Bearer " + KEYS[i % len(KEYS)],
                            "-H", "Content-Type: application/json",
                            "--data-binary", "@" + pp, "--max-time", "360"],
                           capture_output=True, text=True, timeout=380)
        try:
            d = json.loads(r.stdout)
        except Exception:
            print("  [%s] 响应非 JSON" % tag, flush=True)
            time.sleep(12)
            continue
        if d.get("error") or d.get("code"):
            print("  [%s] API错: %s" % (tag, json.dumps(d, ensure_ascii=False)[:150]), flush=True)
            time.sleep(12)
            continue
        item = (d.get("data") or [{}])[0]
        if item.get("b64_json"):
            return base64.b64decode(item["b64_json"])
        if item.get("url"):
            dl = subprocess.run(["curl", "--http1.1", "-s", "-L", item["url"], "--max-time", "120"],
                                capture_output=True, timeout=140)
            try:
                Image.open(io.BytesIO(dl.stdout)).load()
                return dl.stdout
            except Exception:
                pass
    return None


def lit_gate_white(im):
    import numpy as np
    a = np.asarray(im.convert("RGB")).astype(int)
    h, w, _ = a.shape
    border = np.concatenate([a[:3].reshape(-1, 3), a[-3:].reshape(-1, 3),
                             a[:, :3].reshape(-1, 3), a[:, -3:].reshape(-1, 3)])
    bg = np.median(border, axis=0)
    bg_ok = bool(bg.min() >= 225)
    dist = np.sqrt(((a - bg) ** 2).sum(axis=2))
    body = dist > 100
    n = int(body.sum())
    if n < 4000:
        return False, {"verdict": "empty", "body_px": n}
    rgb = a[body]
    mean = float(rgb.mean())
    lit = float((rgb.max(axis=1) > 100).mean())
    ok = bg_ok and mean >= 80 and lit >= 0.35
    return ok, {"mean": round(mean, 1), "lit": round(lit, 2), "verdict": "pass" if ok else "dark"}


def main():
    only = sys.argv[1] if len(sys.argv) > 1 else None
    ref_uri = uri_of(REF)
    raws = sorted(f for f in os.listdir(STAGE) if f.endswith("_raw.png"))
    n_ok = n_fix = n_fail = 0
    for f in raws:
        cid = f[:-len("_raw.png")]
        if only and only not in cid:
            continue
        p = os.path.join(STAGE, f)
        im = Image.open(p).convert("RGB")
        ok, info = lit_gate_white(im)
        if ok:
            n_ok += 1
            continue
        # 备份暗图 → relight
        dark_bak = p.replace("_raw.png", "_raw_dark1.png")
        if not os.path.isfile(dark_bak):
            os.rename(p, dark_bak)
        payload = {"model": MODEL, "prompt": RELIGHT, "size": "1024x1024",
                   "extra_body": {"image": [uri_of(dark_bak), ref_uri], "response_format": "b64_json"}}
        t0 = time.time()
        raw = gen(payload, cid)
        if not raw:
            os.rename(dark_bak, p)  # 还原
            n_fail += 1
            print("[FAIL] %s relight 无果" % cid, flush=True)
            continue
        im2 = Image.open(io.BytesIO(raw)).convert("RGB")
        ok2, info2 = lit_gate_white(im2)
        if ok2:
            im2.save(p)
            n_fix += 1
            print("[FIX] %s %.0fs %s" % (cid, time.time() - t0, json.dumps(info2)), flush=True)
        else:
            os.rename(dark_bak, p)  # 两版都暗，保留原图待人工挑
            n_fail += 1
            print("[STILL-DARK] %s %.0fs %s（保留原暗图，两版都在 staging）" % (
                cid, time.time() - t0, json.dumps(info2)), flush=True)
            im2.save(p.replace("_raw.png", "_raw_dark2.png"))
    print("relight 轮：原亮 %d / 修亮 %d / 仍暗 %d" % (n_ok, n_fix, n_fail), flush=True)


if __name__ == "__main__":
    main()
