# -*- coding: utf-8 -*-
"""
回炉重做（绿标版）：要改的图2 里标绿的图不再修补，直接从 要改的图 原图
重跑 100 米重摄管线，并在 prompt 中：
  1. 点名绿标物体必须完全消失（由视觉模型先读 要改的图2 描述绿标是什么）
  2. 追加尺寸硬条款：地面杂物不得高于画面高度 2%（720p ≈ 15px）
管线（每张图）：
  1. agnes-2.5-flash 双图反推：图1=原图（氛围），图2=绿标图（列出被涂物体）
  2. agnes-image-2.1-flash img2img 原图（不吃绿标图，避免绿色入画）
  3. 下载 → 等比裁剪缩放回原尺寸
用法：python tools/bg_rework/rework_marked.py bg_level_45.png ...
"""
import os, sys, json, time, ssl, base64, urllib.request, io
sys.stdout.reconfigure(encoding="utf-8", errors="replace")

KEY = open("tools/_api_key.txt", encoding="utf-8").read().strip().splitlines()[0]
CHAT = "https://apihub.agnes-ai.com/v1/chat/completions"
IMG = "https://apihub.agnes-ai.com/v1/images/generations"

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE
OPENER = urllib.request.build_opener(urllib.request.HTTPSHandler(context=ctx), urllib.request.ProxyHandler({}))  # 直连 opener：urlopen(context=) 会无视 install_opener 重建带系统代理的 opener，必须用 OPENER.open  # 绕过系统代理(本地VPN端口不在时urllib会拒连,curl不受影响)

SRC_DIR = "docs/重修背景图/要改的图"        # 原图（生成基底）
MARK_DIR = "docs/重修背景图/要改的图2"      # 绿标图（仅用于反推点名）
OUT_DIR = "docs/重修背景图"

REVERSE_INSTR = ("You see TWO versions of the same game background. Image 1 = original. "
    "Image 2 = the same scene where a user PAINTED BRIGHT GREEN over unwanted objects. "
    "Answer in two short English parts, nothing else:\n"
    "PART A (one paragraph): describe image 1's VISUAL APPEARANCE for an image prompt — "
    "ONLY time of day, weather, color palette and mood, the SKY, distant horizon silhouette, "
    "and the ground MATERIAL and color. Treat the foreground as empty open ground; do NOT "
    "describe foreground objects. Use neutral landscape terms, no military vocabulary.\n"
    "PART B (one line): list ONLY the objects covered by green paint in image 2, "
    "as a comma list (e.g. 'two barrels, a crate stack'). If none visible, write NONE.")

# 无绿标图时的单图氛围反推（与 ai_rework_batch.py 同款）
REVERSE_PLAIN = ("Describe this game background image's VISUAL APPEARANCE in ONE flowing English paragraph "
    "for use as an image-generation prompt. Focus ONLY on: time of day, weather, color palette and mood, "
    "the SKY, and the distant horizon silhouette line. Then describe the ground MATERIAL and color only. "
    "Do NOT describe any foreground objects, props, debris, crates, sacks, planks, wire, barriers, mounds or "
    "structures — treat the foreground as empty open ground. "
    "Use neutral terms a landscape artist would use; avoid military/war/weapon/injury vocabulary.")

# 100 米定稿版（与 ai_rework_batch.py 一致）+ 尺寸硬条款
MODIFY = ("Re-shoot the SAME scene from a MUCH more distant viewpoint: the camera now stands about 100 meters away "
    "watching through a long telephoto lens, so the entire battlefield is compressed and flat. "
    "The ground strip at the very bottom edge of the frame is now 100 meters from the viewer. "
    "Because of this great viewing distance, EVERYTHING resting on the ground reads as SMALL and FAR: "
    "the sandbag clusters, crates, wooden posts, barrels and rope coils that once loomed large in the near "
    "foreground are now gone or shrunk into tiny distant specks. "
    "Keep the SAME weather, sky, color mood and ground material as the original. "
    "The ground is one continuous, fairly level open expanse stretching across the full frame width, "
    "dotted only with sparse low grass tufts, tiny pebbles and faint wheel tracks — all seen from far away, "
    "so the open field where game units stand is clean and readable. "
    "Near the very bottom edge keep only a thin line of tiny natural ground details. "
    "HARD SIZE RULE: absolutely NO crate, box, barrel, drum, sandbag, sack, post, stake, plank, wire coil, "
    "tool, wreck part, rock, boulder, log or any man-made/natural debris anywhere on the ground "
    "taller than 2 percent of the frame height (at 720 pixels tall that is about 15 pixels, "
    "smaller than a boot seen from 100 meters). Everything loose on the ground must read as "
    "gravel, pebbles, dust, faint tracks and low grass tufts. "
    "The very BOTTOM EDGE strip of the frame (the lowest 40 pixels) must be COMPLETELY EMPTY: "
    "flat plain ground texture only — absolutely NO pots, planters, vases, bowls, jars, "
    "bricks, stones, crates or any object resting there at all. "
    "The objects listed as REMOVE-BELOW must be COMPLETELY ABSENT. "
    "Natural ambient light. No people, no soldiers, no vehicles, no text, no UI, no watermark. "
    "No harsh edges or borders anywhere. Same painterly game-background art style as the original.")

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

def b64(p):
    return base64.b64encode(open(p, "rb").read()).decode()

def process_one(name):
    from PIL import Image
    src = os.path.join(SRC_DIR, name)
    marked = os.path.join(MARK_DIR, name)
    dst = os.path.join(OUT_DIR, name)
    src_b64 = b64(src)
    in_size = Image.open(io.BytesIO(base64.b64decode(src_b64))).size

    # 1) 反推：有绿标图→双图（氛围+点名）；无→单图氛围
    if os.path.exists(marked):
        body = {"model": "agnes-2.5-flash", "messages": [{"role": "user", "content": [
            {"type": "text", "text": REVERSE_INSTR},
            {"type": "image_url", "image_url": {"url": "data:image/png;base64," + src_b64}},
            {"type": "image_url", "image_url": {"url": "data:image/png;base64," + b64(marked)}}]}]}
        d = post(CHAT, body, timeout=180)
        desc = d["choices"][0]["message"]["content"]
        if "PART A" in desc:
            atmo = desc.split("PART B")[0].replace("PART A", "").strip()
            marked_part = desc.split("PART B")[-1].strip()
        else:
            atmo, marked_part = desc.strip(), "NONE"
    else:
        body = {"model": "agnes-2.5-flash", "messages": [{"role": "user", "content": [
            {"type": "text", "text": REVERSE_PLAIN},
            {"type": "image_url", "image_url": {"url": "data:image/png;base64," + src_b64}}]}]}
        d = post(CHAT, body, timeout=180)
        atmo = d["choices"][0]["message"]["content"].strip()
        marked_part = "NONE"
    print("    [REMOVE-BELOW] %s" % marked_part[:150], flush=True)

    # 2) img2img 原图；有绿标图时作为第二张参考图（视觉点名，比文字禁令狠）
    prompt = atmo + " " + MODIFY
    images = ["data:image/png;base64," + src_b64]
    if marked_part.upper().startswith("NONE"):
        prompt = prompt.replace(" The objects listed as REMOVE-BELOW must be COMPLETELY ABSENT.", "")
    else:
        prompt = prompt.replace("REMOVE-BELOW", marked_part)
        if os.path.exists(marked):
            images.append("data:image/png;base64," + b64(marked))
            prompt += (" REFERENCE: the second attached image is the same scene with the unwanted "
                "objects painted bright GREEN. Everything painted green in that reference "
                "(and anything resembling it) must be COMPLETELY ABSENT from your output. "
                "Never reproduce any green paint.")
    body = {"model": "agnes-image-2.1-flash", "prompt": prompt, "size": "1792x1024",
        "extra_body": {"image": images, "response_format": "url"}}
    d = post(IMG, body, timeout=600)
    item = d["data"][0]
    img_url = item.get("url", "")
    if item.get("b64_json"):
        raw = base64.b64decode(item["b64_json"])
    else:
        if "/i2i/" not in img_url:
            print("    WARN: url not i2i (%s...)" % img_url[:60], flush=True)
        raw = None
        for a in range(3):
            try:
                raw = OPENER.open(
                    urllib.request.Request(img_url), timeout=240).read()
                break
            except Exception:
                if a == 2:
                    raise
                time.sleep(4)

    # 3) 归一到原尺寸
    im = Image.open(io.BytesIO(raw)).convert("RGB")
    w, h = im.size
    tw, th = in_size
    if abs(w / h - tw / th) > 0.01:
        if w / h > tw / th:
            nw = int(h * tw / th); x0 = (w - nw) // 2; im = im.crop((x0, 0, x0 + nw, h))
        else:
            nh = int(w * th / tw); y0 = (h - nh) // 2; im = im.crop((0, y0, w, y0 + nh))
    im.resize((tw, th), Image.LANCZOS).save(dst)

def main():
    names = sys.argv[1:]
    print("rework_marked: %d images" % len(names), flush=True)
    failed = []
    for i, name in enumerate(names):
        print("[%d/%d] %s ..." % (i + 1, len(names), name), flush=True)
        try:
            process_one(name)
            print("    OK", flush=True)
        except Exception as e:
            print("    FAIL %r" % e, flush=True)
            failed.append(name)
        time.sleep(1.5)
    print("DONE, failed: %s" % (failed or "none"), flush=True)

if __name__ == "__main__":
    main()
