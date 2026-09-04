# -*- coding: utf-8 -*-
"""generate_title_bg.py —— 标题画面专属背景生成（agnes-image-2.1-flash）

标题页 key art：左侧大块暗部负空间（放菜单列），右侧巨型机甲/相位奇观。
prompt 遵循 tools/_agnes_image_api.md 行为实测：负面词只留结构性排除，
画面内容全部用正面意象锁死。

用法：
  python tools/generate_title_bg.py            # 生成 v1+v2 两个方案
  python tools/generate_title_bg.py v1         # 只生成指定方案
输出：_steam_assets/video/title_bg_v1.png / v2.png（选定后复制为 assets/backgrounds/title_bg.png）
"""
import json, os, re, subprocess, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_MD = os.path.join(ROOT, "tools", "_agnes_image_api.md")
OUT_DIR = os.path.join(ROOT, "_steam_assets", "video")
BASE_URL = "https://apihub.agnes-ai.cn/v1"
MODEL = "agnes-image-2.1-flash"
SIZE = "1920x1080"     # 先试全尺寸；API 拒绝时自动回落 1152x768 再放大
SIZE_FALLBACK = "1152x768"

BASE_STYLE = (
    "EPIC WIDE key art for a war strategy card game title screen, "
    "stylized hand-painted game art, "
    "muted palette of dark blue-grey and charcoal with cold cyan (#00e5ff) glow accents "
    "and a warm amber dusk glow along the horizon. "
    "Horizon in the lower third, dramatic scale contrast, cinematic wide 16:9 landscape. "
    "LEFT SIDE of the image: the ruined landscape falls away into deep dark hills under a "
    "vast evening sky, calm, quiet and almost empty, covered in deep blue shadow with only "
    "faint distant ruin silhouettes — generous smooth empty negative space for overlaying "
    "a game menu. "
    "no text, no watermark, no signature, no frame, no border, no people"
)

VARIANTS = {
    "v1": (
        "RIGHT SIDE: the towering silhouette of a colossal retro-future mech war machine "
        "standing among ruined WWI-era brick buildings on a shattered battlefield, its joints "
        "and shoulder cannon traced with cold cyan energy lines, one great glowing cyan eye. "
        + BASE_STYLE
    ),
    "v2": (
        "CENTER-RIGHT: a giant glowing cyan phase-portal ring hovering above a ruined "
        "WWI-era city square, crackling energy tendrils reaching down to the rubble, and on "
        "the far right the small silhouette of a lone future tank facing it. "
        + BASE_STYLE
    ),
}


def load_keys():
    src = open(KEY_MD, "r", encoding="utf-8").read()
    keys = re.findall(r"sk-[A-Za-z0-9]{20,}", src)
    if not keys:
        raise SystemExit("tools/_agnes_image_api.md 里找不到 key")
    return keys


def call_api(prompt, key, out, size):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": size, "n": 1})
    tmp, resp = out + ".payload.json", out + ".resp.json"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(payload)
    subprocess.run(["curl", "--http1.1", "-s", "-X", "POST", BASE_URL + "/images/generations",
                    "-H", "Authorization: Bearer " + key, "-H", "Content-Type: application/json",
                    "--data-binary", "@" + tmp, "-o", resp, "--max-time", "240"],
                   capture_output=True, text=True, timeout=260)
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
        print("  非法响应: " + content[:200])
        return False
    url = (data.get("data") or [{}])[0].get("url", "")
    if url:
        subprocess.run(["curl", "--http1.1", "-s", "-L", "-o", out, url, "--max-time", "240"],
                       capture_output=True, text=True, timeout=260)
        return os.path.exists(out) and os.path.getsize(out) > 20000
    b64 = (data.get("data") or [{}])[0].get("b64_json", "")
    if b64:
        import base64
        with open(out, "wb") as f:
            f.write(base64.b64decode(b64))
        return os.path.getsize(out) > 20000
    print("  无图像数据: " + content[:200])
    return False


def main():
    args = [a for a in sys.argv[1:]]
    targets = args or list(VARIANTS.keys())
    keys = load_keys()
    os.makedirs(OUT_DIR, exist_ok=True)
    for i, vid in enumerate(targets):
        prompt = VARIANTS[vid]
        out = os.path.join(OUT_DIR, "title_bg_%s.png" % vid)
        key = keys[i % len(keys)]
        size = SIZE
        print("[%s] 生成中 size=%s ..." % (vid, size))
        t0 = time.time()
        ok = call_api(prompt, key, out, size)
        if not ok and size != SIZE_FALLBACK:
            print("[%s] %s 被拒，回落 %s" % (vid, size, SIZE_FALLBACK))
            size = SIZE_FALLBACK
            ok = call_api(prompt, key, out, size)
        dt = time.time() - t0
        if ok:
            print("[%s] ✓ %s (%.0fs)" % (vid, out, dt))
        else:
            print("[%s] ✗ 失败 (%.0fs)" % (vid, dt))


if __name__ == "__main__":
    main()
