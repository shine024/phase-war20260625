# -*- coding: utf-8 -*-
"""
AI 视角重摄批处理：把"要改的图"文件夹内全部背景图改为 100 米远距视角，
地面近景道具因距离变小，解决道具比坦克大的比例失衡。

管线（每张图）：
  1. agnes-2.5-flash 反推氛围（锁定天气/色调/天空/地面材质，跳过前景物件）
  2. agnes-image-2.1-flash img2img（extra_body.image 数组，i2i 标志 = URL 含 /i2i/）
  3. 下载 → 等比裁剪缩放到与输入相同尺寸
鲁棒性：单图 4 次重试；失败记录到 _failed.txt 供重跑；已存在的输出跳过（断点续跑）。
用法：python tools/bg_rework/ai_rework_batch.py
"""
import os, sys, json, time, ssl, base64, urllib.request
import glob

KEY = open("tools/_api_key.txt", encoding="utf-8").read().strip().splitlines()[0]
CHAT = "https://apihub.agnes-ai.com/v1/chat/completions"
IMG = "https://apihub.agnes-ai.com/v1/images/generations"

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE
OPENER = urllib.request.build_opener(urllib.request.HTTPSHandler(context=ctx), urllib.request.ProxyHandler({}))  # 直连 opener：urlopen(context=) 会无视 install_opener 重建带系统代理的 opener，必须用 OPENER.open  # 绕过系统代理(本地VPN端口不在时urllib会拒连,curl不受影响)

SRC_DIR = "docs/重修背景图/要改的图"
OUT_DIR = "docs/重修背景图"
FAIL_LOG = "tools/bg_rework/_batch_failed.txt"

# 顽固图名单：普通 100m 重摄后视觉复检仍残留大道具 → prompt 追加显式禁令
# 第二轮（2026-08-26 全量 68 张分诊）新增 9 张 FAIL：10/15/27/31/33/55/63/67/98
STUBBORN = {
    "bg_level_13.png", "bg_level_35.png", "bg_level_36.png",
    "bg_level_50.png", "bg_level_54.png", "bg_level_59.png",
    "bg_level_10.png", "bg_level_15.png", "bg_level_27.png",
    "bg_level_31.png", "bg_level_33.png", "bg_level_55.png",
    "bg_level_63.png", "bg_level_67.png", "bg_level_98.png",
}
STUBBORN_EXTRA = ("STRICT: this ground must be COMPLETELY CLEAR of man-made objects and large obstacles. "
    "Absolutely NO crates, NO boxes, NO barrels, NO drums, NO sandbags, NO sacks, NO wooden posts, NO stakes, "
    "NO rope coils, NO planks, NO wire, NO tools, NO supplies, NO storage, NO stockpile, "
    "NO large boulders, NO rock piles, NO fallen logs, NO tree trunks in the foreground — "
    "nothing man-made and nothing large resting on the near ground at all. "
    "Only bare natural ground: dirt, mud, grass tufts, small stones, faint tracks. "
    "Small stones must stay SMALL — no rock taller than a boot.")

REVERSE_INSTR = ("Describe this game background image's VISUAL APPEARANCE in ONE flowing English paragraph "
    "for use as an image-generation prompt. Focus ONLY on: time of day, weather, color palette and mood, "
    "the SKY, and the distant horizon silhouette line. Then describe the ground MATERIAL and color only. "
    "Do NOT describe any foreground objects, props, debris, crates, sacks, planks, wire, barriers, mounds or "
    "structures — treat the foreground as empty open ground. "
    "Use neutral terms a landscape artist would use; avoid military/war/weapon/injury vocabulary.")

# 100 米定稿版（用户拍板）
MODIFY = ("Re-shoot the SAME scene from a MUCH more distant viewpoint: the camera now stands about 100 meters away "
    "watching through a long telephoto lens, so the entire battlefield is compressed and flat. "
    "The ground strip at the very bottom edge of the frame is now 100 meters from the viewer. "
    "Because of this great viewing distance, EVERYTHING resting on the ground reads as SMALL and FAR: "
    "the sandbag clusters, crates, wooden posts, barrels and rope coils that once loomed large in the near "
    "foreground are now gone or shrunk into tiny distant specks no bigger than small stones. "
    "Keep the SAME weather, sky, color mood and ground material as the original. "
    "The ground is one continuous, fairly level open expanse stretching across the full frame width, "
    "dotted only with sparse low grass tufts, tiny pebbles and faint wheel tracks — all seen from far away, "
    "so the open field where game units stand is clean and readable. "
    "Near the very bottom edge keep only a thin line of tiny natural ground details (small stones, grass tufts). "
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

def process_one(src, dst):
    from PIL import Image
    import io
    src_bytes = open(src, "rb").read()
    b64 = base64.b64encode(src_bytes).decode()
    in_size = Image.open(io.BytesIO(src_bytes)).size

    # 1) 反推
    body = {"model": "agnes-2.5-flash", "messages": [{"role": "user", "content": [
        {"type": "text", "text": REVERSE_INSTR},
        {"type": "image_url", "image_url": {"url": "data:image/png;base64," + b64}}]}]}
    d = post(CHAT, body, timeout=180)
    desc = d["choices"][0]["message"]["content"]

    # 2) img2img（顽固图追加显式禁令）
    prompt = desc + " " + MODIFY
    if os.path.basename(src) in STUBBORN:
        prompt += " " + STUBBORN_EXTRA
    body = {"model": "agnes-image-2.1-flash", "prompt": prompt, "size": "1792x1024",
        "extra_body": {"image": ["data:image/png;base64," + b64], "response_format": "url"}}
    d = post(IMG, body, timeout=600)
    item = d["data"][0]
    img_url = item.get("url", "")
    if not img_url and item.get("b64_json"):
        raw = base64.b64decode(item["b64_json"])
    else:
        if "/i2i/" not in img_url:
            print("    WARN: url not i2i (%s...)" % img_url[:60], flush=True)
        for a in range(3):
            try:
                req = urllib.request.Request(img_url)
                raw = OPENER.open(req, timeout=240).read()
                break
            except Exception as e:
                if a == 2:
                    raise
                time.sleep(4)

    # 3) 归一到输入尺寸
    im = Image.open(io.BytesIO(raw)).convert("RGB")
    w, h = im.size
    tw, th = in_size
    target = tw / th
    if abs(w / h - target) > 0.01:
        if w / h > target:
            nw = int(h * target); x0 = (w - nw) // 2; im = im.crop((x0, 0, x0 + nw, h))
        else:
            nh = int(w / target); y0 = (h - nh) // 2; im = im.crop((0, y0, w, y0 + nh))
    im = im.resize((tw, th), Image.LANCZOS)
    im.save(dst)

def main():
    files = sorted(glob.glob(os.path.join(SRC_DIR, "*.png")))
    print("found %d images" % len(files), flush=True)
    failed = []
    t0 = time.time()
    for i, src in enumerate(files):
        name = os.path.basename(src)
        dst = os.path.join(OUT_DIR, name)
        if os.path.exists(dst) and os.path.getsize(dst) > 50000:
            print("[%d/%d] %s SKIP (exists)" % (i + 1, len(files), name), flush=True)
            continue
        print("[%d/%d] %s ..." % (i + 1, len(files), name), flush=True)
        try:
            process_one(src, dst)
            print("    OK -> %s (%.1fs)" % (dst, time.time() - t0), flush=True)
        except Exception as e:
            print("    FAIL %r" % e, flush=True)
            failed.append(name)
        time.sleep(1.5)
    if failed:
        open(FAIL_LOG, "w", encoding="utf-8").write("\n".join(failed))
        print("\nFAILED %d: %s (see %s)" % (len(failed), ", ".join(failed), FAIL_LOG), flush=True)
    else:
        if os.path.exists(FAIL_LOG):
            os.remove(FAIL_LOG)
        print("\nALL DONE %d images, total %.1f min" % (len(files), (time.time() - t0) / 60), flush=True)

if __name__ == "__main__":
    main()
