# -*- coding: utf-8 -*-
"""MK9 图标重掷批（2026-10-05）：审查标记三枚视角病卡图 img2img 重掷。
  mod_arm_m1a2sep    vis_player_023  3/4 视角 → 纯侧视（沙漠黄迷彩复刻参考）
  fut_air_drone      vis_player_065  近俯视   → 纯侧视悬停（旋翼前后各一具）
  fut_space_fighter  vis_player_093  机鼻上仰 → 水平平飞（引擎微光保留）
prompt 沿 _b4_card_gen CONVERT 句式（orthographic 硬锁四件套），负面词一律不设。
产出只落 .godot/unit_review/mk9_staging/，目验过门后另行部署。
用法: python tools/_mk9_icon_regen.py
"""
import base64
import io
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tools"))
import img25_anchor_gen as ag  # noqa: E402  (gen_image / KEYS / IMG_API，keys 本地文件不外传)

from PIL import Image  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STG = os.path.join(ROOT, ".godot", "unit_review", "mk9_staging")
os.makedirs(STG, exist_ok=True)

# 视轴四件套按单位定制（视点句+主轴句+重叠句+禁深度句）
UNITS = [
    dict(key="mod_arm_m1a2sep",
         ref="assets/card_icons/player/vis_player_023.png",
         subject="美军 M1A2 SEP 主战坦克：扁平楔形炮塔与长滑膛炮管，侧裙装甲板与宽履带，"
                 "车体沙漠黄迷彩涂装",
         axis="车体与炮塔沿水平轴线横贯画面：两条履带在正侧视中完全重叠为一条连续履带线，"
              "负重轮只露一排；炮管朝画面正右方，完全看不到车头正面与车尾正面，无任何透视缩短；",
         pose="炮塔转正朝右，炮管水平指向前方；",
         color="配色严格复刻参考卡图：沙漠黄数码迷彩涂装，明度饱和度以参考图为唯一标准；",
         foot="车体完整落在画面内不裁切"),
    dict(key="fut_air_drone",
         ref="assets/card_icons/player/vis_player_065.png",
         subject="四旋翼武装无人机：深灰枪色机身与青蓝光带，四组旋翼短臂，机腹前伸武器挂架",
         axis="机身沿水平轴线横贯画面：正侧视中只见前后两具旋翼桅杆（近侧与远侧旋翼臂完全重叠），"
              "桨叶呈极扁横线；机身水平悬停无俯仰无滚转，机头与机腹武器朝画面正右方；"
              "完全看不到俯视构型与顶视形状，无任何透视缩短；",
         pose="水平悬停姿态；",
         color="配色严格复刻参考卡图：深灰枪色机身与青蓝光带，明度饱和度以参考图为唯一标准；",
         foot="机体与全部旋翼完整落在画面内不裁切"),
    dict(key="fut_space_fighter",
         ref="assets/card_icons/player/vis_player_093.png",
         subject="近未来太空战斗机：棱角机身、双垂尾、机背导弹挂架与机头炮",
         axis="机身沿水平轴线横贯画面，水平平飞：机鼻与机尾同高，无俯仰无滚转；"
              "双垂尾在正侧视中重叠为一片，机翼呈极窄横线；"
              "完全看不到正面、顶视或斜侧构型，无任何透视缩短；",
         pose="水平平飞，不开火；机尾引擎口保留一处小的青蓝微光（设备常态光效）；",
         color="配色严格复刻参考卡图：冷灰蓝钢色涂装，明度饱和度以参考图为唯一标准；",
         foot="机体完整落在画面内不裁切"),
]

TMPL = ("第一张图是参考卡图。把它重画成一张新的游戏卡图立绘：{subject}。\n"
        "【视角·硬性】纯侧面视角（正侧视图），面朝画面正右方，绝不朝左，绝不允许俯视、斜视或 3/4 视角。\n"
        "【构图·硬性】单主体居中，全身完整，四周留出约百分之十白色边距，主体任何部分不得触碰画布四边，{foot}。\n"
        "【组成·硬性】部件组成与参考卡图完全一致，不新增、不删除、不简化任何部件。\n"
        "【视轴·硬性】视点在主体正侧方：{axis}{pose}"
        "【单一主体·硬性】画面中只允许有参考图中这一个主体本身；严禁添加背景载具、第二个人物、"
        "战友或任何背景道具；背景是摄影棚纯白，不是战场。\n"
        "【配色·硬性】{color}主体完全受光、照明充足，高光与暗部层次分明，材质细节清晰可读；"
        "严禁大面积高饱和绿、大面积正红、粉、品红；"
        "严禁画成黑色剪影，严禁逆光或暗场照明，严禁单色深色轮廓块。\n"
        "【风格·硬性】厚涂插画（thick painterly illustration），笔触平滑过渡，硬边钢面，"
        "形体由色块与明暗交界塑造（painted color masses with soft blended transitions）；"
        "干净棚拍纯白背景，无地面无场景无杂物无投影。\n"
        "画面中没有文字、水印、边框、旗帜徽标字母。")


def data_uri(path):
    with open(path, "rb") as f:
        return "data:image/png;base64," + base64.b64encode(f.read()).decode()


def main():
    for u in UNITS:
        print("== %s ==" % u["key"], flush=True)
        ref_abs = os.path.join(ROOT, u["ref"])
        payload = {"model": "agnes-image-2.5-flash",
                   "prompt": TMPL.format(**u),
                   "size": "1K", "ratio": "1:1",
                   "extra_body": {"image": [data_uri(ref_abs)],
                                  "response_format": "b64_json"}}
        pp = os.path.join(STG, "_payload_%s.json" % u["key"])
        with open(pp, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False)
        raw = ag.gen_image(pp)
        if raw is None:
            print("  3 掷皆废，跳过", flush=True)
            continue
        out = os.path.join(STG, "%s_icon_raw.png" % u["key"])
        with open(out, "wb") as f:
            f.write(raw)
        ok, info = ag.lit_gate(Image.open(io.BytesIO(raw)))
        print("  亮度门: %s" % json.dumps(info, ensure_ascii=False), flush=True)
        print("  saved %s ok=%s" % (out, ok), flush=True)
    print("MK9 图标重掷批结束", flush=True)


if __name__ == "__main__":
    main()
