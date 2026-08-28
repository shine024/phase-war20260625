# -*- coding: utf-8 -*-
"""
绿涂抹补全：要改的图2 里用户用绿色涂抹标记要删除的物体。
流程（每张图）：
  1. 检测绿色像素 → 膨胀 15px 掩码（盖住笔刷软边）
  2. 生图 API 修复：
     方式A：agnes-image-2.1-flash 顶层 image+mask（真 inpainting，若服务可用）
     方式B：extra_body.image 指令式编辑（"remove green-painted objects"）
  3. 结果归一到 1280x720
  4. 掩码羽化合成：掩码外 100% 原图像素 —— 不动其他地方由合成硬保证
输出：docs/重修背景图/bg_level_XX.png（覆盖同名旧版）
用法：python tools/bg_rework/green_fix.py [名字...]  # 无参 = 全部
"""
import os, sys, glob, json, time, ssl, base64, urllib.request, urllib.error
from PIL import Image, ImageFilter
import numpy as np

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

KEY = open("tools/_api_key.txt", encoding="utf-8").read().strip().splitlines()[0]
IMG = "https://apihub.agnes-ai.com/v1/images/generations"

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE
OPENER = urllib.request.build_opener(urllib.request.HTTPSHandler(context=ctx), urllib.request.ProxyHandler({}))  # 直连 opener：urlopen(context=) 会无视 install_opener 重建带系统代理的 opener，必须用 OPENER.open  # 绕过系统代理(本地VPN端口不在时urllib会拒连,curl不受影响)

SRC_DIR = "docs/重修背景图/要改的图2"
OUT_DIR = "docs/重修背景图"
MASK_DEBUG_DIR = "tools/bg_rework/_green_masks"

PROMPT_A = ("Inpaint the MASKED region (pure white in the mask image) of this game background: "
    "the masked objects were painted over with bright green marker and must be REMOVED. "
    "Fill the masked area with the surrounding scenery continuing naturally — same ground material, "
    "same horizon/sky gradient, same lighting, same painterly game-background style. "
    "Use MUTED, desaturated colors matching the surrounding ground (dirt, mud, dry grass, rubble). "
    "Do NOT use bright saturated green anywhere in the fill. "
    "No new objects in the filled area, only empty scenery. "
    "Keep every pixel OUTSIDE the mask EXACTLY unchanged.")

PROMPT_B = ("Photo retouch this game background: some unwanted objects were PAINTED OVER with bright "
    "GREEN marker. Remove the green-painted objects completely and fill those regions with the "
    "surrounding scenery continuing naturally — same ground material, same horizon and sky, same "
    "lighting, same painterly game-background style. No new objects in the filled regions, only "
    "empty scenery. Keep EVERYTHING outside the green-painted areas EXACTLY unchanged — "
    "same composition, same colors, do not regenerate or restyle the rest of the image.")

def post(url, body, timeout=300):
    for a in range(1, 5):
        try:
            req = urllib.request.Request(url, data=json.dumps(body).encode(),
                headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"})
            r = OPENER.open(req, timeout=timeout)
            return json.loads(r.read().decode())
        except urllib.error.HTTPError as e:
            err = e.read().decode()
            print("    HTTP %d %s" % (e.code, err[:150]), flush=True)
            if a < 4:
                time.sleep(3 + a * 2); continue
            raise
        except Exception as e:
            print("    net err %r" % e, flush=True)
            if a < 4:
                time.sleep(3 + a * 2); continue
            raise

def fetch_image_bytes(d):
    item = d["data"][0]
    url = item.get("url", "")
    if item.get("b64_json"):
        return base64.b64decode(item["b64_json"])
    if not url:
        raise RuntimeError("no image in response: %s" % str(d)[:200])
    for a in range(3):
        try:
            return OPENER.open(
                urllib.request.Request(url), timeout=240).read()
        except Exception:
            if a == 2:
                raise
            time.sleep(4)

def build_mask(im_rgb):
    # HSV 宽松绿检测（h80-165, s>0.5, v>0.28）——实测未涂漆图零误报，
    # 比 RGB 阈值(g>r+30)能多抓暗淡/半透明笔触，避免漏检残留
    rgb = np.array(im_rgb).astype(float) / 255.0
    mx = rgb.max(axis=2); mn = rgb.min(axis=2)
    v = mx
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0.0)
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    h = np.zeros_like(mx)
    m = (mx == r) & (mx > mn); h[m] = (60.0 * ((g - b)[m] / (mx - mn)[m])) % 360.0
    m = (mx == g) & (mx > mn); h[m] = 60.0 * ((b - r)[m] / (mx - mn)[m]) + 120.0
    m = (mx == b) & (mx > mn); h[m] = 60.0 * ((r - g)[m] / (mx - mn)[m]) + 240.0
    green = (h >= 80) & (h <= 165) & (s > 0.5) & (v > 0.28)
    m = Image.fromarray((green * 255).astype(np.uint8), "L")
    m = m.filter(ImageFilter.MaxFilter(31))      # 膨胀 ~15px
    return m

def normalize(im, size):
    w, h = im.size
    tw, th = size
    if abs(w / h - tw / th) > 0.01:
        if w / h > tw / th:
            nw = int(h * tw / th); x0 = (w - nw) // 2; im = im.crop((x0, 0, x0 + nw, h))
        else:
            nh = int(w * th / tw); y0 = (h - nh) // 2; im = im.crop((0, y0, w, y0 + nh))
    return im.resize((tw, th), Image.LANCZOS)

def process_one(name):
    src = os.path.join(SRC_DIR, name)
    dst = os.path.join(OUT_DIR, name)
    base = Image.open(src).convert("RGB")
    size = base.size
    b64 = base64.b64encode(open(src, "rb").read()).decode()

    mask = build_mask(base)
    os.makedirs(MASK_DEBUG_DIR, exist_ok=True)
    mask.save(os.path.join(MASK_DEBUG_DIR, name))
    pct = (np.array(mask) > 128).mean() * 100
    print("  mask %.2f%% pixels" % pct, flush=True)
    if pct < 0.05:
        print("  no green found, skip", flush=True)
        return "skip"

    # 方式A：顶层 image + mask
    import io
    gen = method = None
    try:
        mask_png = io.BytesIO()
        mask.resize((size[0] // 4, size[1] // 4)).save(mask_png, "PNG")
        mask_b64 = base64.b64encode(mask_png.getvalue()).decode()
        body = {"model": "agnes-image-2.1-flash", "prompt": PROMPT_A,
                "image": "data:image/png;base64," + b64,
                "mask": "data:image/png;base64," + mask_b64,
                "size": "%dx%d" % size, "n": 1}
        d = post(IMG, body)
        gen = Image.open(io.BytesIO(fetch_image_bytes(d))).convert("RGB")
        method = "A(mask)"
    except Exception as e:
        print("  method A failed: %r" % e, flush=True)

    # 方式B：extra_body.image 指令式
    if gen is None:
        import io
        body = {"model": "agnes-image-2.1-flash", "prompt": PROMPT_B,
                "size": "1792x1024",
                "extra_body": {"image": ["data:image/png;base64," + b64], "response_format": "url"}}
        d = post(IMG, body)
        gen = Image.open(io.BytesIO(fetch_image_bytes(d))).convert("RGB")
        method = "B(prompt)"

    gen = normalize(gen, size)

    # 羽化合成：掩码外 100% 原图
    soft = mask.filter(ImageFilter.GaussianBlur(10))
    arr_base = np.array(base).astype(float)
    arr_gen = np.array(gen).astype(float)
    alpha = (np.array(soft).astype(float) / 255.0)[:, :, None]
    out = arr_base * (1 - alpha) + arr_gen * alpha
    out_img = Image.fromarray(out.clip(0, 255).astype(np.uint8))
    out_img.save(dst)

    # 硬校验：掩码外与原图逐像素一致
    hard = np.array(mask) > 128
    diff_outside = np.abs(np.array(out_img).astype(int) - np.array(base).astype(int)).max(axis=2)
    outside_max = diff_outside[~hard].max() if (~hard).any() else 0
    print("  %s -> %s (method %s, outside-mask max diff %d)" % (name, dst, method, outside_max), flush=True)
    return method

def main():
    names = sys.argv[1:]
    if not names:
        names = [os.path.basename(p) for p in sorted(glob.glob(os.path.join(SRC_DIR, "bg_level_*.png")))]
    print("green_fix: %d images" % len(names), flush=True)
    for i, name in enumerate(names):
        print("[%d/%d] %s" % (i + 1, len(names), name), flush=True)
        try:
            process_one(name)
        except Exception as e:
            print("  FAIL %r" % e, flush=True)
        time.sleep(1.5)

if __name__ == "__main__":
    main()
