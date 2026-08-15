#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
一战段卡图重生（v10 视觉升级）：对齐近未来段精细度标准。
- 生成：agnes-image-2.1-flash，1024，敌向原图（面朝左侧）
- 部署：白底转透明 → 裁边缩放 512 → enemy 原图 + player 水平翻转
- 缩略：同步生成 _thumb384（现行列表档）
用法：python tools/regen_wwi_icons.py [vis_enemy_001]   # 带参只跑单张
"""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API_KEY = open(os.path.join(ROOT, "tools", "_api_key.txt"), encoding="utf-8").read().strip()
BASE_URL = "https://apihub.agnes-ai.com/v1"
MODEL = "agnes-image-2.1-flash"
ENEMY_DIR = os.path.join(ROOT, "assets", "card_icons", "enemy")
PLAYER_DIR = os.path.join(ROOT, "assets", "card_icons", "player")
THUMB384 = os.path.join(ROOT, "assets", "card_icons", "_thumb384")
RAW_DIR = os.path.join(ROOT, "assets", "card_icons", "_wwi_raw")
os.makedirs(RAW_DIR, exist_ok=True)

# 提示词基线：对齐 G 段（终焉守护者）的描写密度 + 一战工业质感
P = "严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，单位完整居中入镜且面朝左侧，" \
    "第一次世界大战军事设定图，超精密硬表面与材质细节，"
T = "铆接钢板装甲板缝与铆钉排布清晰，泥污磨痕与战地旧化质感，低饱和军绿灰主色，" \
    "干净棚拍纯白背景，无地面无场景无杂物，高清。"
N = "不要文字，不要边框，不要多对象，不要透视变形，不要照片写实人像。"

UNITS = [
    {"f": "vis_enemy_001", "p": P + "英国马克V型雄性坦克，菱形车体贯穿式履带环，侧舷57mm炮廓与机枪球座，车顶指挥塔，乘员舱铆接装甲板，" + T + N},
    {"f": "vis_enemy_002", "p": P + "法国雷诺FT-17轻型坦克，全向旋转炮塔与37mm短炮，车尾越壕尾撬，后方引擎舱格栅，履带张紧轮，" + T + N},
    {"f": "vis_enemy_003", "p": P + "德制77mm野战炮，开脚式炮架与木质轮辐包铁轮，弧形防盾铆接工艺，炮管驻退机筒，" + T + N},
    {"f": "vis_enemy_004", "p": P + "一战英国骑兵单位，战马与骑手正侧全身，骑手斜挎李恩菲尔德短步枪，皮质鞍具与武装带，军呢披风，" + T + N},
    {"f": "vis_enemy_005", "p": P + "一战战斗工兵，工兵铲与帆布工具包，沙袋堆与铁丝网剪，皮质护具与防毒面具挂盒，" + T + N},
    {"f": "vis_enemy_012", "p": P + "一战81mm斯托克斯迫击炮，双脚架与缓冲簧，圆形座钣，炮尾调节螺杆与瞄具，" + T + N},
    {"f": "vis_enemy_036", "p": P + "一战德军暴风突击兵手持MP18冲锋枪，花机关弹鼓供弹，钢盔与防毒面具罐，帆布手榴弹袋束腰，" + T + N},
    {"f": "vis_enemy_037", "p": P + "一战英军步枪兵手持李恩菲尔德步枪刺刀上膛，织物交叉武装带与弹药袋，布料军服褶皱，宽檐钢盔，" + T + N},
    {"f": "vis_enemy_038", "p": P + "一战马克沁MG08重机枪，水冷套筒散热罐与索科洛夫轮式枪架，帆布弹链垂落，挡弹板，" + T + N},
    {"f": "vis_enemy_039", "p": P + "一战中型迫击炮班组，一名炮手跪姿扶正迫击炮，炮身两脚架与座钣，弹药箱码放脚边，" + T + N},
    {"f": "vis_enemy_040", "p": P + "一战德军暴风突击队精锐，手持毛瑟C96速射型，身挂集束木柄手榴弹，胸部附加钢板护甲，" + T + N},
    {"f": "vis_enemy_041", "p": P + "一战精英型马克V坦克，附加铆接装甲裙板与防雷网，车顶指挥旗与天线，炮廓加长身管，" + T + N},
    {"f": "vis_enemy_042", "p": P + "一战德国A7V突击装甲坦克，箱形车体多层突出炮位与周身机枪眼，57mm主炮前突，车体涂装铁十字标志，终极Boss威压感，" + T + N},
    {"f": "vis_enemy_072", "p": P + "一战混凝土永备碉堡，多层射击孔与斜面防护墙，顶部伪装网与沙袋堆叠，弹痕斑驳，" + T + N},
    {"f": "vis_enemy_073", "p": P + "一战要塞重炮，巨型围城火炮与钢轨炮座，炮身驻退液压筒，扬弹机构，" + T + N},
    {"f": "ww1_arm_rolls_mk2", "p": P + "一战英国马克II型早期菱形坦克，无指挥塔低矮车体，侧舷机枪球座，履带裸露张紧轮，" + T + N},
    {"f": "ww1_inf_enfield", "p": P + "一战英军王牌步枪兵，恩菲尔德步枪配瞄准镜，军官风衣与皮质武装带，勋章绶带，" + T + N},
    {"f": "ww1_inf_mp18_x", "p": P + "一战德军精锐冲锋枪手，MP18冲锋枪双弹鼓改装，胸部附加装甲板与钢盔护鼻，" + T + N},
    {"f": "ww1_sup_ford_ambulance", "p": P + "一战福特T型野战救护车，木质车厢与红十字标志，车头散热器护栅，帆布顶棚，" + T + N},
    {"f": "ww1_sup_vickers", "p": P + "一战维克斯水冷重机枪，三脚架与冷凝水管水桶，帆布弹链板供弹，高低机摇柄，" + T + N},
]


def generate(prompt, output_path):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": "1024x1024", "n": 1})
    tmp = output_path + ".payload.json"
    open(tmp, "w", encoding="utf-8").write(payload)
    cmd = ["curl", "--http1.1", "-s", "-X", "POST", BASE_URL + "/images/generations",
           "-H", "Authorization: Bearer " + API_KEY, "-H", "Content-Type: application/json",
           "--data-binary", "@" + tmp, "-o", output_path + ".resp.json", "--max-time", "180"]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=200)
    os.unlink(tmp)
    if r.returncode != 0:
        return False, "curl exit " + str(r.returncode)
    content = open(output_path + ".resp.json", encoding="utf-8").read()
    os.unlink(output_path + ".resp.json")
    try:
        data = json.loads(content)
    except Exception:
        return False, "bad json: " + content[:150]
    if "data" not in data or not data["data"]:
        return False, "no data: " + content[:150]
    url = data["data"][0].get("url", "")
    if not url:
        return False, "no url"
    subprocess.run(["curl", "--http1.1", "-s", "-L", "-o", output_path, url, "--max-time", "180"],
                   capture_output=True, timeout=200)
    ok = os.path.exists(output_path) and os.path.getsize(output_path) > 1000
    return ok, "ok" if ok else "download failed"


def white_to_alpha(img):
    from PIL import Image
    import numpy as np
    arr = np.array(img.convert("RGB"), dtype=np.int16)
    brightness = arr.sum(axis=2) / 3.0
    alpha = np.clip((240 - brightness) * 6.375, 0, 255).astype(np.uint8)
    return Image.fromarray(np.dstack([
        arr[:, :, 0].astype(np.uint8), arr[:, :, 1].astype(np.uint8),
        arr[:, :, 2].astype(np.uint8), alpha]), "RGBA")


def fit_square(img, size=512):
    """与 deploy_card_icons_11 对齐：裁边 + 等比缩放（88% 留白）+ 居中填充到正方形。
    卡框/翻转图体系假定 512x512 正方形——非正方形会拉伸变形且溢出边框。"""
    from PIL import Image
    img = img.convert("RGBA")
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    w, h = img.size
    scale = min(size / w, size / h) * 0.88
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    img = img.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(img, ((size - nw) // 2, (size - nh) // 2), img)
    return canvas


def make_thumb(src_png, thumb_root, size=384):
    from PIL import Image
    img = Image.open(src_png).convert("RGBA")
    img.thumbnail((size, size), Image.LANCZOS)
    subdir = "player" if "vis_player" in src_png or os.sep + "player" + os.sep in src_png else "enemy"
    out_dir = os.path.join(thumb_root, subdir)
    os.makedirs(out_dir, exist_ok=True)
    img.save(os.path.join(out_dir, os.path.basename(src_png)))


def main():
    from PIL import Image
    only = sys.argv[1] if len(sys.argv) > 1 else None
    ok = fail = 0
    for u in UNITS:
        fname = u["f"]
        if only and fname != only:
            continue
        raw = os.path.join(RAW_DIR, fname + ".png")
        if not (os.path.exists(raw) and os.path.getsize(raw) > 1000):
            good, msg = generate(u["p"], raw)
            print("gen:", fname, "->", msg)
            if not good:
                fail += 1
                continue
        try:
            img = white_to_alpha(Image.open(raw))
            img = fit_square(img, 512)
            enemy_path = os.path.join(ENEMY_DIR, fname + ".png")
            img.save(enemy_path, "PNG")
            player_fname = fname.replace("vis_enemy_", "vis_player_")
            player_path = os.path.join(PLAYER_DIR, player_fname + ".png")
            img.transpose(Image.Transpose.FLIP_LEFT_RIGHT).save(player_path, "PNG")
            make_thumb(enemy_path, THUMB384)
            make_thumb(player_path, THUMB384)
            print("deploy:", fname, "+", player_fname, "+ thumbs")
            ok += 1
        except Exception as e:
            print("FAIL:", fname, e)
            fail += 1
    print(f"\nDone: {ok} ok, {fail} fail")


if __name__ == "__main__":
    main()
