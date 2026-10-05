# -*- coding: utf-8 -*-
"""MK10 重做批·阶段1（2026-10-05）：四枚"重做"裁定图标 img2img 重掷（右向出图）。
  ww1_arm_rolls      vis_player_001  劳斯莱斯装甲车（轮式，无履带）
  ww1_arm_rolls_e    vis_player_041  同车精英型（深钢涂装+附加装甲；现役 041 是辆坦克=错位源）
  ww1_arty_77mm      vis_player_003  FK96 野战炮（现役 3/4 斜视）
  ww2_boss_kingtiger vis_player_049  虎王（现役 3/4 斜视；动画共享 tiger sheet 不动）
prompt 沿 CONVERT 句式（orthographic 硬锁四件套），负面词不设。产出只落 mk10_staging。
用法: python tools/_mk10_icon_regen.py
"""
import base64
import io
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tools"))
import img25_anchor_gen as ag  # noqa: E402

from PIL import Image  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STG = os.path.join(ROOT, ".godot", "unit_review", "mk10_staging")
os.makedirs(STG, exist_ok=True)

UNITS = [
    dict(key="ww1_arm_rolls",
         ref="assets/card_icons/player/vis_player_001.png",
         subject="一战英国劳斯莱斯装甲车：修长方形引擎盖与竖条散热格栅，四个辐条充气车轮"
                 "（是轮式车辆，绝对没有履带），车体后部上置球形旋转炮塔与细机枪管，"
                 "浅蓝灰绿一战涂装",
         axis="车体沿水平轴线横贯画面：只见近侧的车轮（远侧车轮被车体完全遮挡），"
              "完全看不到车头正面与车尾正面，无任何透视缩短；",
         color="配色严格复刻参考卡图：浅蓝灰绿一战涂装，明度饱和度以参考图为唯一标准；"),
    dict(key="ww1_arm_rolls_e",
         ref="assets/card_icons/player/vis_player_041.png",
         subject="一战英国劳斯莱斯装甲车（精英型）：与参考卡图不同的车体——修长方形引擎盖与"
                 "竖条散热格栅，四个辐条充气车轮（是轮式车辆，绝对没有履带），车体后部上置"
                 "球形旋转炮塔与细机枪管，车体加装附加装甲板与车尾天线杆，深灰钢色涂装",
         axis="车体沿水平轴线横贯画面：只见近侧的车轮（远侧车轮被车体完全遮挡），"
              "完全看不到车头正面与车尾正面，无任何透视缩短；",
         color="配色硬性：深灰钢色精英涂装（不是参考卡图的涂装——参考卡图是错的坦克，"
               "只取画风不取车体），钢面受光充足；"),
    dict(key="ww1_arty_77mm",
         ref="assets/card_icons/player/vis_player_003.png",
         subject="一战 77mm 野战炮：长炮管与带观察缝的炮盾，箱形炮架与两根长驻锄尾梁，"
                 "两只大木辐条车轮",
         axis="炮管沿水平轴线指向画面正右方：炮盾呈正侧剖面，只见近侧一只大木辐条轮"
              "（远侧大轮完全重叠遮蔽），驻锄尾梁向画面左后方斜撑；"
              "完全看不到炮口正对镜头的形状，无任何透视缩短；",
         color="配色严格复刻参考卡图：钢蓝灰炮身、橄榄炮盾、木质辐条轮，"
               "明度饱和度以参考图为唯一标准；"),
    dict(key="ww2_boss_kingtiger",
         ref="assets/card_icons/player/vis_player_049.png",
         subject="二战德国虎王重型坦克（亨舍尔炮塔）：长 88mm 炮管与厚重楔形炮塔，"
                 "宽履带与交错负重轮，三色迷彩涂装",
         axis="车体与炮塔沿水平轴线横贯画面：两条履带在正侧视中完全重叠为一条连续履带线，"
              "交错负重轮重叠为一条竖列；炮管朝画面正右方，完全看不到车头正面与车尾正面，"
              "无任何透视缩短；",
         color="配色严格复刻参考卡图：三色迷彩涂装，明度饱和度以参考图为唯一标准；"),
]

TMPL = ("第一张图是参考卡图。把它重画成一张新的游戏卡图立绘：{subject}。\n"
        "【视角·硬性】纯侧面视角（正侧视图），面朝画面正右方，绝不朝左，绝不允许俯视、斜视或 3/4 视角。\n"
        "【构图·硬性】单主体居中，全身完整，四周留出约百分之十白色边距，主体任何部分不得触碰画布四边，"
        "车体完整落在画面内不裁切。\n"
        "【组成·硬性】部件组成与描述完全一致，不新增、不删除、不简化任何部件。\n"
        "【视轴·硬性】视点在主体正侧方：{axis}"
        "【单一主体·硬性】画面中只允许有这一个主体本身；严禁添加背景载具、第二个人物、"
        "战友或任何背景道具；背景是摄影棚纯白，不是战场。\n"
        "【配色·硬性】{color}主体完全受光、照明充足，高光与暗部层次分明，材质细节清晰可读；"
        "严禁大面积高饱和绿、大面积正红、粉、品红；"
        "严禁画成黑色剪影，严禁逆光或暗场照明，严禁单色深色轮廓块。\n"
        "【风格·硬性】厚涂插画（thick painterly illustration），笔触平滑过渡，硬边钢面，"
        "形体由色块与明暗交界塑造（painted color masses with soft blended transitions）；"
        "干净棚拍纯白背景，无地面无场景无杂物无投影，严禁地面阴影。\n"
        "画面中没有文字、水印、边框、旗帜徽标字母。")


def data_uri(path):
    with open(path, "rb") as f:
        return "data:image/png;base64," + base64.b64encode(f.read()).decode()


def main():
    for u in UNITS:
        print("== %s ==" % u["key"], flush=True)
        payload = {"model": "agnes-image-2.5-flash",
                   "prompt": TMPL.format(**u),
                   "size": "1K", "ratio": "1:1",
                   "extra_body": {"image": [data_uri(os.path.join(ROOT, u["ref"]))],
                                  "response_format": "b64_json"}}
        pp = os.path.join(STG, "_payload_%s.json" % u["key"])
        with open(pp, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False)
        raw = ag.gen_image(pp)
        if raw is None:
            print("  3 掷皆废，跳过", flush=True)
            continue
        with open(os.path.join(STG, "%s_icon_raw.png" % u["key"]), "wb") as f:
            f.write(raw)
        print("  saved", flush=True)
    print("MK10 阶段1 图标重掷结束", flush=True)


if __name__ == "__main__":
    main()
