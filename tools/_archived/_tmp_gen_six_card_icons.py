import json, os, sys, time, base64, io, subprocess
import numpy as np
from PIL import Image, ImageDraw

OUT = 'assets/card_icons/player'
BAKQ = '.godot/art_regen/six_card_icons_raw'
os.makedirs(BAKQ, exist_ok=True)

KEYS = [
    "sk-thpXTkWon9RiLMdnsZgqlQUH7XI6SdlhLYsx7eQToj7GtIPv",
    "sk-2mxCpSC8Nf0nm2TAf9fYHuRxNj7aeoIttPuuu9ivodbU3zXN",
    "sk-Pzu3QigNdQlVhFC7cVDVsTDwfvt3T6nIDq23HeJgaKMnRo6K",
]
ENDPOINT = "https://apihub.agnes-ai.com/v1/images/generations"

STYLE = ("side profile view facing right, single vehicle only, centered in frame, "
         "semi-realistic stylized military game asset illustration, dark olive-green and gunmetal "
         "palette with small red glowing accent lights, weathered steel, pure white background, "
         "no text, no watermark, no logo, no extra sketches, no perspective view, no humans, "
         "no background scenery.")

CARDS = {
    "storm_rider": "A heavily modified World War 2 assault tank with sloped welded armor plates, "
                   "angled storm-deflector fins along the hull, one long main gun pointing right, "
                   "wide tracks, twin exhaust pipes.",
    "bulwark": "A World War 2 armored personnel carrier with a massive thick frontal shield plate, "
               "riveted boxy hull, six small road wheels, a rooftop machine gun mount.",
    "titan_mk2": "An upgraded World War 1 Mark V style rhomboid tank, modernized dark steel plating, "
                 "side sponson cannons, a top armor cupola, one long track wrapping around the hull.",
    "abrams_mk2": "A modern main battle tank in Abrams style, layered composite armor blocks, a long "
                  "smoothbore gun pointing right, low-profile turret with smoke launchers, seven road wheels.",
    "heavy_carrier": "A colossal tracked land battleship carrying a flat flight deck with four small "
                     "propeller aircraft parked on it, two small turrets, massive segmented tracks, "
                     "industrial riveted hull.",
    "regen_frame": "A field maintenance recovery vehicle with a folding crane arm on its rear, "
                   "spare track links and tool boxes on the hull, a radio mast, six road wheels.",
}

def _curl(args, body=None, timeout=150):
    body_file = None
    if body is not None:
        # Windows stdin 传体会被截断（服务端报 unexpected end of JSON input）——
        # AGENTS 同款教训：改走临时文件
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
    """curl 子进程直调（项目管线先例：urllib 对该端点 SSL 验证失败）。传输错误抛异常，不占质量掷次。"""
    body = json.dumps({"model": "agnes-image-2.1-flash", "prompt": prompt + " " + STYLE,
                       "size": "1024x1024", "n": 1}).encode()
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
    """四角 flood 出白底 → 透明；保留车体内部高光。"""
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

def content_bbox_fill(im):
    a = np.asarray(im)
    opaque = a[..., 3] > 25
    ys, xs = np.nonzero(opaque)
    if len(xs) == 0:
        return None, 0.0
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    return (x0, y0, x1, y1), (x1-x0+1) * (y1-y0+1) / (im.size[0] * im.size[1])

results = []
only = sys.argv[1:] if len(sys.argv) > 1 else list(CARDS.keys())
for card_id in only:
    ok = False
    for attempt in range(1, 4):  # 红线 2：质量重掷上限 3（传输失败不占掷次，另计轮换）
        t0 = time.time()
        gen_im = None
        for tx in range(3):  # 传输重试（轮换 key）
            try:
                gen_im = gen(CARDS[card_id], attempt - 1 + tx)
                break
            except Exception as e:
                print(f"{card_id} 掷{attempt} 传输重试{tx+1}: {e}")
                time.sleep(4)
        if gen_im is None:
            continue
        raw_path = os.path.join(BAKQ, f"{card_id}_try{attempt}.png")
        gen_im.convert("RGB").save(raw_path)
        im = white_to_alpha(gen_im)
        bbox, fill = content_bbox_fill(im)
        if bbox is None or fill < 0.10 or fill > 0.99:
            print(f"{card_id} 掷{attempt}: 内容占比异常 {fill:.2f}，质量重掷")
            continue
        crop = im.crop(bbox)
        side = max(crop.size)
        pad = int(side * 0.06)
        sq = Image.new("RGBA", (side + 2*pad, side + 2*pad), (0, 0, 0, 0))
        sq.paste(crop, (pad + (side - crop.size[0]) // 2, pad + (side - crop.size[1]) // 2))
        sq = sq.resize((512, 512), Image.LANCZOS)
        sq.save(os.path.join(OUT, f"{card_id}.png"))
        print(f"{card_id} 掷{attempt}: OK 填充{fill:.2f} {int(time.time()-t0)}s -> {card_id}.png")
        results.append((card_id, attempt, round(fill, 2)))
        ok = True
        break
    if not ok:
        print(f"{card_id}: 3 掷仍不合格 —— 升级人工裁决（红线 2）")
        results.append((card_id, 0, 0.0))
print("\nSUMMARY:", results)
