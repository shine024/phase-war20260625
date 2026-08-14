# -*- coding: utf-8 -*-
"""
背景图 3x3 反推改图工作流
========================
把单车道侧滚战斗背景(bg_level_XX.png)转成 3x3 对 3x3 开阔地面布局。

流水线(两步,氛围忠实度最大化):
  1. 反推原图 —— agnes-2.5-flash 多模态看图,生成中性视觉描述(锁定氛围/天空/地面材质)
     结果缓存到 reverseprompt_level_XX.txt,下次命中缓存跳网络
  2. img2img 改图 —— agnes-image-2.1-flash = 原图 base64 + 反推描述 + 改图指令(MODIFY)
     改图指令要点:天空压到约 1/3 + 地面占约 2/3 平整开阔 + 前景自然装饰 + 同质地面连续延伸(无雾无线)

用法:
  python 背景图_3x3反推改图_工作流.py               # 默认跑 [2,3,4,5]
  python 背景图_3x3反推改图_工作流.py 4             # 单关
  python 背景图_3x3反推改图_工作流.py 6 7 8 9 10    # 批量

输入: assets/backgrounds/bg_level_XX.png
输出: docs/3x3_vs_3x3/bg_3x3_level_XX.png
"""
import json, urllib.request, urllib.error, ssl, base64, time, sys, os

# SSL 绕过(apihub 证书过期)
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

KEY = "sk-2mxCpSC8Nf0nm2TAf9fYHuRxNj7aeoIttPuuu9ivodbU3zXN"
CHAT = "https://apihub.agnes-ai.com/v1/chat/completions"
IMG = "https://apihub.agnes-ai.com/v1/images/generations"

# 反推指令:中性视觉词,聚焦时间/天气/天空/地平线/地面材质,跳过前景物件,禁战争词(过审)
REVERSE_INSTR = ("Describe this game background image's VISUAL APPEARANCE in ONE flowing English paragraph "
    "for use as an image-generation prompt. Focus ONLY on: time of day, weather, color palette and mood, "
    "the SKY, and the distant horizon silhouette line. Then describe the ground MATERIAL and color only. "
    "Do NOT describe any foreground objects, props, debris, crates, sacks, planks, wire, barriers, mounds or "
    "structures — treat the foreground as empty open ground. "
    "Use neutral terms a landscape artist would use; avoid military/war/weapon/injury vocabulary.")

# 改图指令(v12 最终,经 2-5 关验证):
#   - 天空约 1/3(清晰可见但小),地面约 2/3
#   - 地面平整开阔(单位可站立),自然手绘纹理 + 稀草/碎石
#   - 前景底边有草丛/碎石装饰(不秃)
#   - 地面非空但有细节,无大物/结构/箱/沙袋/板/丝/障碍/载具/人物
#   - 同质同色地面连续延伸到远景(近远景一体,无雾、无地平线、无硬线)
#   - 远处几棵小树/灌木同色族柔和小
MODIFY = ("Recompose: the SKY is a clearly visible but moderate portion at the top (roughly one third of the frame), "
    "and the GROUND fills the larger bottom part (roughly two thirds). Ground is bigger than sky, but sky still clearly visible. "
    "The ground is a HUGE wide fairly-level natural expanse spanning the FULL frame width edge-to-edge, "
    "level smooth so units can stand stable (not rugged, not bumpy), "
    "with natural hand-painted ground texture: faint color mottling, small patches of sparse low grass tufts, "
    "scattered tiny pebbles and small weathered rocks. "
    "Near the BOTTOM edge add natural foreground detail: a few clumps of grass, small stones, "
    "low dry weeds, so the bottom edge is not bare. "
    "The open ground is NOT empty or blank — it has subtle natural ground details, but NO large objects, "
    "NO structures, NO buildings, NO crates, NO sacks, NO planks, NO wire, NO barriers, NO vehicles, "
    "NO characters, NO soldiers, NO barricades. "
    "The same ground texture continues all the way to the far distance with no change in material — "
    "near and far are ONE continuous surface in the same color and texture. A few low distant trees or bushes "
    "sit softly on the ground far away, small and quiet, the same color family as the ground. "
    "Keep the original color mood and weather feel, but make the sky SMALL. "
    "NO hard line or border anywhere in the image. "
    "Natural ambient light — no stage spotlight, no artificial beam. "
    "Near side-view perspective. No text, no grid lines, no checkerboard, no UI, no watermark, no frame.")

def post(url, body, timeout=240):
    """带 4 次重试的 POST。"""
    for a in range(1, 5):
        try:
            req = urllib.request.Request(url, data=json.dumps(body).encode(),
                headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"})
            r = urllib.request.urlopen(req, timeout=timeout, context=ctx)
            return json.loads(r.read().decode())
        except urllib.error.HTTPError as e:
            err = e.read().decode()
            print("  HTTP %d %s" % (e.code, err[:200]))
            if a < 4:
                time.sleep(3); continue
            raise
        except Exception as e:
            print("  net err %r" % e)
            if a < 4:
                time.sleep(3); continue
            raise

def reverse(level):
    """反推原图。命中缓存(reverseprompt_level_XX.txt)直接读,不发请求。"""
    cache = "docs/3x3_vs_3x3/reverseprompt_level_%02d.txt" % level
    if os.path.exists(cache):
        desc = open(cache, encoding="utf-8").read()
        print("L%02d reverse (cached): %s" % (level, desc[:120].replace("\n", " ")))
        return desc
    b64 = base64.b64encode(open("assets/backgrounds/bg_level_%02d.png" % level, "rb").read()).decode()
    body = {"model": "agnes-2.5-flash", "messages": [{"role": "user", "content": [
        {"type": "text", "text": REVERSE_INSTR},
        {"type": "image_url", "image_url": {"url": "data:image/png;base64," + b64}}]}]}
    d = post(CHAT, body, timeout=180)
    desc = d["choices"][0]["message"]["content"]
    open("docs/3x3_vs_3x3/reverseprompt_level_%02d.txt" % level, "w", encoding="utf-8").write(desc)
    print("L%02d reverse: %s" % (level, desc[:140].replace("\n", " ")))
    return desc

def gen(level, desc):
    """img2img:原图 + 反推描述 + 改图指令 → bg_3x3_level_XX.png。"""
    b64 = base64.b64encode(open("assets/backgrounds/bg_level_%02d.png" % level, "rb").read()).decode()
    body = {"model": "agnes-image-2.1-flash", "prompt": desc + MODIFY, "size": "1792x1024",
        "extra_body": {"image": ["data:image/png;base64," + b64], "response_format": "url"}}
    d = post(IMG, body, timeout=300)
    img_url = d["data"][0]["url"]
    out = "docs/3x3_vs_3x3/bg_3x3_level_%02d.png" % level
    urllib.request.urlretrieve(img_url, out)
    print("L%02d gen OK -> %s" % (level, out))

# 默认 [2,3,4,5];argv 传关号覆盖
LEVELS = [int(x) for x in sys.argv[1:]] if len(sys.argv) > 1 else [2, 3, 4, 5]
for lv in LEVELS:
    try:
        desc = reverse(lv)
        gen(lv, desc)
    except Exception as e:
        print("L%02d FAIL %r" % (lv, e))
    time.sleep(2)
print("DONE")
