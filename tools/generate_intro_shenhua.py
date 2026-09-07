# -*- coding: utf-8 -*-
"""generate_intro_shenhua.py —— 深航计划版序章图批量生成（agnes-image-2.1-flash）

为开场故事"深航计划版"补 5 张图（4 张漫画分格 + 1 张雪原醒来大图），
风格对齐现有 This War of Mine 阴郁手绘分格（色板经 PIL 实测抽样：
炭黑 + 暗橄榄棕 + 暗红/琥珀点缀）。

prompt 铁律（tools/_agnes_image_api.md v26.8 实测）：
  - 负面词反激活，只留结构性排除（text/frame/border/comic grid）；
  - 正面意象锁死（画什么，不画什么）；
  - 不用 gritty/somber/dusty 等拖垃圾进画面的风格词；
  - 单幅整图限定（防模型画成多格漫画网格）。

用法：
  python tools/generate_intro_shenhua.py            # 全部 5 张（已存在的跳过）
  python tools/generate_intro_shenhua.py --force    # 强制重生成全部
  python tools/generate_intro_shenhua.py b6_black_gates wakeup_snowfield  # 指定
"""
import json, os, re, subprocess, sys, time

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_MD = os.path.join(ROOT, "tools", "_agnes_image_api.md")
BASE_URL = "https://apihub.agnes-ai.cn/v1"
MODEL = "agnes-image-2.1-flash"
SIZE = "1152x768"   # ≈3:2；finalize 时 aspect-fill 居中裁到 1280x720

# 风格基底：色板词来自现有分格 PIL 抽样（#000/#202020/#404020/#402020 主导）
P_STYLE = (
    "Hand-painted storybook illustration for a 2D game story panel, "
    "painterly brush strokes, muted palette of charcoal black and dark olive-brown "
    "with one dim warm amber accent light, night scene lit by a single light source, "
    "crisp edges, high detail, no text, no watermark, no signature, "
    "no frame, no border, no comic panel grid, single full-bleed image. "
)
P_NEGA = "text, watermark, signature, frame, border, comic panel grid, split panels"

# id → (相对输出目录, 文件名, 场景描述)
TARGETS = {
    "b6_black_gates": (
        os.path.join("assets", "intro", "comic"),
        "b6_black_gates.png",
        "Scene: a night sky over a dark continent seen from a high hilltop: "
        "dozens of colossal black rectangular gates hang in the low storm clouds, "
        "each gate a towering monolith slab of pure black with a thin edge of violet glow, "
        "narrow beams of violet light pour down from the gates onto distant cities, "
        "one distant city burns with a faint amber glow on the horizon, "
        "a tiny column of fleeing silhouettes walks along a road in the lower foreground. ",
    ),
    "b7_deep_voyage": (
        os.path.join("assets", "intro", "comic"),
        "b7_deep_voyage.png",
        "Scene: a vast modern international assembly hall like a united nations summit at night: "
        "hundreds of delegates in dark business suits seated in wide curved tiered rows "
        "facing a brightly lit stage, "
        "one speaker stands at a podium on the stage gesturing toward a massive wall-sized digital screen "
        "behind them showing a glowing holographic globe surrounded by icons of small black rectangular gates, "
        "professional conference lighting with cool blue wash over the audience, warm spotlights on the stage. ",
    ),
    "b8_sacrifice": (
        os.path.join("assets", "intro", "comic"),
        "b8_sacrifice.png",
        "Scene: one colossal perfectly round portal of violet and golden swirling energy "
        "hangs low over a flat dark plain at night like a giant luminous ring hovering above ground, "
        "a long convoy of olive military trucks with canvas covers drives straight toward the portal "
        "seen from behind so only red taillights are visible in a receding line, "
        "the front trucks already half inside the glowing ring, "
        "golden sparks and embers rain down from the portal rim, "
        "small silhouettes of soldiers stand watching along both sides of the road, "
        "cinematic wide shot. ",
    ),
    "b10_rift_stream": (
        os.path.join("assets", "intro", "comic"),
        "b10_rift_stream.png",
        "Scene: a long river of a thousand tiny walking silhouettes drifts through a tunnel "
        "of fractured space at night, the tunnel is lined with cracked glass-like shards, "
        "each shard reflecting a different starfield, ribbons of violet energy tear silently "
        "between the travelers, some silhouettes glow faintly golden and hold together "
        "while others crumble into drifting motes of light, the river of people stretches into the far distance. ",
    ),
    "wakeup_snowfield": (
        os.path.join("assets", "intro"),
        "wakeup_snowfield.png",
        "Scene: an endless snowfield at first light under a pale grey sky: "
        "a long eight-wheeled armored command vehicle sits in deep snow in the middle ground, "
        "its body a fully enclosed box-shaped crew module with a row of small dark windows along "
        "the side, olive green and dark brown armor plating with faint cyan glow strips, "
        "rolled canvas on the roof, one headlight glows warm amber, "
        "a trail of fresh footprints leads from the foreground snow to the vehicle's side door, "
        "on the far horizon one colossal black rectangular monolith slab of pure black towers "
        "straight up into the low clouds, its top lost in the sky, a thin edge of violet glow "
        "along its outline, soft snowfall, long cold blue shadows. ",
    ),
}


def load_keys():
    src = open(KEY_MD, "r", encoding="utf-8").read()
    keys = re.findall(r"sk-[A-Za-z0-9]{20,}", src)
    if not keys:
        raise SystemExit("tools/_agnes_image_api.md 里找不到 key")
    return keys


def call_api(prompt, key, out):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": SIZE, "n": 1})
    tmp, resp = out + ".payload.json", out + ".resp.json"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(payload)
    subprocess.run(["curl", "--http1.1", "-s", "-X", "POST", BASE_URL + "/images/generations",
                    "-H", "Authorization: Bearer " + key, "-H", "Content-Type: application/json",
                    "--data-binary", "@" + tmp, "-o", resp, "--max-time", "180"],
                   capture_output=True, text=True, timeout=200)
    try:
        os.unlink(tmp)
    except OSError:
        pass
    content = open(resp, "r", encoding="utf-8", errors="replace").read()
    try:
        os.unlink(resp)
    except OSError:
        pass
    try:
        data = json.loads(content)
    except json.JSONDecodeError:
        print("  非法响应: " + content[:160])
        return False
    url = (data.get("data") or [{}])[0].get("url", "")
    if url:
        subprocess.run(["curl", "--http1.1", "-s", "-L", "-o", out, url, "--max-time", "180"],
                       capture_output=True, text=True, timeout=200)
        return os.path.exists(out) and os.path.getsize(out) > 5000
    b64 = (data.get("data") or [{}])[0].get("b64_json", "")
    if b64:
        import base64
        with open(out, "wb") as f:
            f.write(base64.b64decode(b64))
        return os.path.getsize(out) > 5000
    print("  无图像数据: " + content[:160])
    return False


def finalize(raw_path, out_path, size=(1280, 720), edge_frac=0.045):
    """裁掉生图自带的纸白边（edge_frac 比例四边）→ aspect-fill 居中裁切 → PNG 1280x720"""
    im = Image.open(raw_path).convert("RGB")
    if edge_frac > 0:
        dw, dh = int(im.width * edge_frac), int(im.height * edge_frac)
        im = im.crop((dw, dh, im.width - dw, im.height - dh))
    sw, sh = size
    scale = max(sw / im.width, sh / im.height)
    nw, nh = round(im.width * scale), round(im.height * scale)
    im = im.resize((nw, nh), Image.LANCZOS)
    left, top = (nw - sw) // 2, (nh - sh) // 2
    im = im.crop((left, top, left + sw, top + sh))
    im.save(out_path, "PNG")


def main():
    force = "--force" in sys.argv
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    targets = args or list(TARGETS.keys())
    bad = [t for t in targets if t not in TARGETS]
    if bad:
        raise SystemExit("未知目标: %s（可选: %s）" % (", ".join(bad), ", ".join(TARGETS.keys())))
    keys = load_keys()
    ok_n = 0
    for i, tid in enumerate(targets):
        rel_dir, fname, desc = TARGETS[tid]
        out_dir = os.path.join(ROOT, rel_dir)
        raw_dir = os.path.join(out_dir, "_raw")
        os.makedirs(raw_dir, exist_ok=True)
        out = os.path.join(out_dir, fname)
        raw = os.path.join(raw_dir, "agnes-%s.jpeg" % tid)
        print("[%d/%d] %s ..." % (i + 1, len(targets), tid), end=" ", flush=True)
        if os.path.exists(out) and os.path.getsize(out) > 5000 and not force and not args:
            print("已存在，跳过")
            ok_n += 1
            continue
        if (force or args) and os.path.exists(raw):
            try:
                os.unlink(raw)
            except OSError:
                pass
        if not (os.path.exists(raw) and os.path.getsize(raw) > 5000):
            prompt = P_STYLE + desc + "Avoid: " + P_NEGA
            ok = call_api(prompt, keys[i % len(keys)], raw)
            if not ok:
                print("FAIL（生图失败）")
                continue
        try:
            finalize(raw, out)
        except Exception as e:  # noqa: BLE001
            print("FAIL（后处理: %s）" % e)
            continue
        print("OK %dKB -> %s" % (os.path.getsize(out) // 1024, os.path.relpath(out, ROOT)))
        ok_n += 1
        if i < len(targets) - 1:
            time.sleep(3)
    print("完成 %d/%d" % (ok_n, len(targets)))


if __name__ == "__main__":
    main()
