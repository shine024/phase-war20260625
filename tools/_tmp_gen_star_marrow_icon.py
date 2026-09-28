# 星髓货币图标生成（v6.35 收尾：data/basic_resources.gd 占位晶体图标欠账）
# 依据 tools/_agnes_image_api.md 2026-09-27 段：agnes-image-2.5-flash @ apihub 网关。
# 管线复用 tools/_archived/_tmp_gen_six_card_icons.py 模式（curl 子进程 + flood 白底转透明）。
# 产物：assets/resources/star_marrow.png（1024 RGBA）；原图备份 .godot/art_regen/。
import json, os, sys, time, base64, io, subprocess
import numpy as np
from PIL import Image, ImageDraw

OUT = 'assets/resources/star_marrow.png'
BAKQ = '.godot/art_regen/star_marrow_raw'
os.makedirs(BAKQ, exist_ok=True)

KEYS = [
    "sk-thpXTkWon9RiLMdnsZgqlQUH7XI6SdlhLYsx7eQToj7GtIPv",
    "sk-2mxCpSC8Nf0nm2TAf9fYHuRxNj7aeoIttPuuu9ivodbU3zXN",
    "sk-Pzu3QigNdQlVhFC7cVDVsTDwfvt3T6nIDq23HeJgaKMnRo6K",
]
ENDPOINT = "https://apihub.agnes-ai.cn/v1/images/generations"

STYLE = ("single object only, centered in frame, semi-realistic stylized game resource icon "
         "illustration, pure white background, no text, no watermark, no logo, no perspective "
         "view, no extra sketches, no hands, no background scenery, no pedestal.")

SUBJECT = ("A round game resource badge icon: dark gunmetal circular metal frame enclosing a "
           "cluster of jagged dark violet crystal shards, the crystals glowing from within with "
           "bright magenta-purple psychic energy light, pale violet luminous core, deep purple "
           "and magenta palette, an otherworldly star marrow crystal harvested from beyond a "
           "black gate, flat front view.")


def _curl(args, body=None, timeout=300):
    body_file = None
    if body is not None:
        # Windows stdin 传体会被截断（服务端报 unexpected end of JSON input）——走临时文件
        body_file = os.path.join(BAKQ, '_request_body.json')
        with open(body_file, 'wb') as f:
            f.write(body)
        args = args + ['-d', '@' + body_file.replace('\\', '/')]
    cmd = ['curl', '--http1.1', '-s', '--max-time', str(timeout)] + args
    p = subprocess.run(cmd, capture_output=True)
    if p.returncode != 0:
        raise RuntimeError(f'curl rc={p.returncode}: {p.stderr.decode(errors="ignore")[:200]}')
    return p.stdout


def gen(prompt, key_idx):
    body = json.dumps({"model": "agnes-image-2.5-flash", "prompt": prompt + " " + STYLE,
                       "size": "1K", "ratio": "1:1", "n": 1,
                       "response_format": "b64_json"}).encode()
    out = _curl(['-X', 'POST', ENDPOINT,
                 '-H', 'Authorization: Bearer ' + KEYS[key_idx % len(KEYS)],
                 '-H', 'Content-Type: application/json'], body)
    parsed = json.loads(out.decode(errors='ignore'))
    if "data" not in parsed:
        raise RuntimeError(f"响应无 data: {out.decode(errors='ignore')[:300]}")
    d = parsed["data"][0]
    if d.get("b64_json"):
        return Image.open(io.BytesIO(base64.b64decode(d["b64_json"])))
    raw = _curl(['-L', d.get("url")], None, 120)
    return Image.open(io.BytesIO(raw))


def white_to_alpha(im):
    """四角+上下中点 flood 出白底 → 透明；保留晶体内芯高光。"""
    im = im.convert("RGBA")
    seeds = [(2, 2), (im.size[0]-3, 2), (2, im.size[1]-3), (im.size[0]-3, im.size[1]-3),
             (im.size[0]//2, 2), (im.size[0]//2, im.size[1]-3)]
    for s in seeds:
        try:
            ImageDraw.floodfill(im, s, (255, 0, 255, 255), thresh=60)
        except Exception:
            pass
    a = np.asarray(im).copy()
    magenta = (a[..., 0] > 240) & (a[..., 1] < 60) & (a[..., 2] > 240)
    a[magenta] = (0, 0, 0, 0)
    return Image.fromarray(a)


def content_stats(im):
    a = np.asarray(im)
    opaque = a[..., 3] > 25
    ys, xs = np.nonzero(opaque)
    if len(xs) == 0:
        return None, 0.0, (0, 0, 0)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    fill = (x1-x0+1) * (y1-y0+1) / (im.size[0] * im.size[1])
    # 色相采样只取中心 60% 区域（金属框像素会拉平均，晶芯才是判据）
    h, w = a.shape[:2]
    cx0, cx1 = int(w*0.2), int(w*0.8)
    cy0, cy1 = int(h*0.2), int(h*0.8)
    core = a[cy0:cy1, cx0:cx1]
    core = core[core[..., 3] > 25]
    if len(core) == 0:
        core = a[opaque]
    r, g, b = int(core[..., 0].mean()), int(core[..., 1].mean()), int(core[..., 2].mean())
    return (x0, y0, x1, y1), fill, (r, g, b)


final = None
for attempt in range(1, 4):
    gen_im = None
    for tx in range(3):
        try:
            gen_im = gen(SUBJECT, attempt - 1 + tx)
            break
        except Exception as e:
            print(f"掷{attempt} 传输重试{tx+1}: {e}")
            time.sleep(4)
    if gen_im is None:
        continue
    raw_path = os.path.join(BAKQ, f"star_marrow_try{attempt}.png")
    gen_im.save(raw_path)
    im = white_to_alpha(gen_im)
    bbox, fill, (r, g, b) = content_stats(im)
    print(f"掷{attempt}: bbox={bbox} fill={fill:.2f} avg_rgb=({r},{g},{b})")
    if bbox is None:
        continue
    # 质量门：内容占比合理 + 主体偏紫红（r>b>g 量级，区别于晶体 teal 的 b>r>g）
    if not (0.12 <= fill <= 0.75):
        print("  弃：内容占比越界")
        continue
    if not (r > g + 18 and b > g + 5):
        print("  弃：色相不满足紫红家族（与晶体 teal 同脸风险）")
        continue
    crop = im.crop(bbox)
    side = max(crop.size)
    pad = int(side * 0.08)
    sq = Image.new("RGBA", (side + pad * 2, side + pad * 2), (0, 0, 0, 0))
    sq.paste(crop, (pad + (side - crop.size[0]) // 2, pad + (side - crop.size[1]) // 2), crop)
    final = sq.resize((1024, 1024), Image.LANCZOS)
    final.save(raw_path.replace('_try', '_picked_try'))
    break

if final is None:
    print("FAIL: 三掷全弱，未产出")
    sys.exit(1)

final.save(OUT)
print(f"OK: {OUT} 1024x1024")
