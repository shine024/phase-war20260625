# -*- coding: utf-8 -*-
"""记录5#1 v38e: agnes img2img 重绘雪原黑门——PIL 局部改图三轮(v37小柱/v38a-c补丁带/
v38d频率分离)都不理想，转全图 img2img：锁卡车/雪原/构图，修天空拼接痕迹+画紫光黑门。

用法: python tools/_tmp_snowfield_gate_v38e.py
输入: assets/intro/_art_backup/wakeup_snowfield_v37_20260924.png
输出: .godot/art_regen/wakeup_snowfield_v38e_r{1,2}.png（候选，裁 1280x720）
"""
import base64, json, os, sys, time, io
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _netfix as netfix
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEYS = [
    "sk-thpXTkWon9RiLMdnsZgqlQUH7XI6SdlhLYsx7eQToj7GtIPv",
    "sk-2mxCpSC8Nf0nm2TAf9fYHuRxNj7aeoIttPuuu9ivodbU3zXN",
    "sk-Pzu3QigNdQlVhFC7cVDVsTDwfvt3T6nIDq23HeJgaKMnRo6K",
]
BASE_URL = "https://apihub.agnes-ai.com/v1"
MODEL = "agnes-image-2.1-flash"
SRC = os.path.join(ROOT, "assets", "intro", "_art_backup", "wakeup_snowfield_v37_20260924.png")
OUT_DIR = os.path.join(ROOT, ".godot", "art_regen")

PROMPT = (
    "保持画面构图不变：前景的军绿色六轮装甲基地卡车、车顶白烟、车侧青色能量线条、"
    "雪原车辙与冷蓝调阴云天空全部保持原样，卡车细节不得改变。"
    "修复天空中部偏右的人工矩形拼接痕迹，让云层自然连续过渡。"
    "在远处地平线右侧（画面横向约 75% 处）画一道细长的竖直黑色裂缝状传送门剪影："
    "下宽上尖的窄长黑缝立在雪原尽头，门缝中透出神秘紫色微光，"
    "门口下方雪地有淡淡的紫色反光辉光。远景小而神秘，电影感，写实风格，冷色调，"
    "no text, no watermark, no people"
)


def call_img2img(b64: str, key: str) -> str:
    payload = json.dumps({
        "model": MODEL,
        "prompt": PROMPT,
        "size": "1280x720",
        "n": 1,
        "extra_body": {"image": [b64]},   # 记忆铁律：img2img 必须 extra_body.image 数组
    })
    req = urllib.request.Request(
        BASE_URL + "/images/generations",
        data=payload.encode("utf-8"),
        headers={"Content-Type": "application/json", "Authorization": "Bearer " + key},
        method="POST",
    )
    with netfix.open_url(req, timeout=240) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    return data["data"][0].get("url", "")


def download(url: str, path: str) -> None:
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with netfix.open_url(req, timeout=180) as resp:
        with open(path, "wb") as f:
            f.write(resp.read())


def main() -> None:
    im = Image.open(SRC).convert("RGB")
    buf = io.BytesIO()
    im.save(buf, format="PNG")
    b64 = base64.b64encode(buf.getvalue()).decode("ascii")
    os.makedirs(OUT_DIR, exist_ok=True)
    for attempt in range(1, 4):
        key = KEYS[(attempt - 1) % len(KEYS)]
        print("[%d] img2img 生成中 ..." % attempt, flush=True)
        try:
            url = call_img2img(b64, key)
            if "/i2i/" not in url:
                print("  ⚠ 响应 URL 无 /i2i/ 标志（可能退化 text2img）:", url[:90])
            out = os.path.join(OUT_DIR, "wakeup_snowfield_v38e_r%d.png" % attempt)
            download(url, out)
            img = Image.open(out).convert("RGB")
            if img.size != (1280, 720):
                # aspect-fill 裁回 1280x720
                w, h = img.size
                scale = max(1280 / w, 720 / h)
                nw, nh = int(w * scale + 0.5), int(h * scale + 0.5)
                img = img.resize((nw, nh), Image.LANCZOS)
                left, top = (nw - 1280) // 2, (nh - 720) // 2
                img = img.crop((left, top, left + 1280, top + 720))
                img.save(out)
            print("  -> %s" % out, flush=True)
            if attempt >= 2:
                break
            time.sleep(2)
        except Exception as e:
            print("  !! 失败: %r" % e, flush=True)
            time.sleep(3)


if __name__ == "__main__":
    main()
