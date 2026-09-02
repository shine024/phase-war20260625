#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v26 新改造专属图标生成（12张）：单件装备特写、白底孤立、图标风格。
输出白底原图到 docs/待生成改造图标_v26/ 供审核（用户看过后再 deploy 到
assets/ui/icons/mod_icons/<mod_id>.png 并更新改造条目 icon 字段）。"""
import json
import os
import sys
import time
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _netfix as netfix

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
with open(KEY_FILE, "r") as f:
    API_KEY = f.readline().strip()
BASE_URL = "https://apihub.agnes-ai.com/v1"
MODEL = "agnes-image-2.0-flash"
OUTPUT_DIR = os.path.join(ROOT, "docs", "待生成改造图标_v26")

PREFIX = (
    "Single military equipment item icon, 2D game item art, single subject only centered, "
    "clean pure white background, NO ground, NO shadow, NO reflection, NO text, "
    "NO watermark, NO signature, NO extra objects, NO environment, NO hands, NO people, "
    "studio isolated product shot style. "
)
NEGATIVE = (
    "不要：多件物体、场景、地面、投影、文字、水印、logo、人物、手、爆炸、火焰烟雾背景。"
)

ICONS = [
    ("air_17_bombsight", "轰炸瞄准具",
     PREFIX + "二战机械陀螺轰炸瞄准具特写，金属镜筒与陀螺稳定平台、目镜与旋钮刻度盘清晰，"
     "黄铜与军灰金属质感，低饱和军灰主色，高清图标。" + NEGATIVE),
    ("air_18_heavy_rack", "重载挂架",
     PREFIX + "飞机重型炸弹挂架特写，金属挂架钩锁与并列挂弹梁结构清晰，"
     "挂架上的炸弹固定环细节，军灰金属质感，低饱和灰绿主色，高清图标。" + NEGATIVE),
    ("air_19_cluster_dispenser", "集束布撒器",
     PREFIX + "机载集束弹药布撒器特写，长方体布撒器弹箱、打开的舱门与撒布中的子弹药轮廓清晰，"
     "军灰弹体与黄色标识环，低饱和军灰主色，高清图标。" + NEGATIVE),
    ("air_20_standoff_missile", "防区外导弹",
     PREFIX + "隐身巡航导弹特写，弹体斜置展示、折叠弹翼与进气口、头部导引头窗口清晰，"
     "浅灰隐身涂层弹体，低饱和浅灰主色，高清图标。" + NEGATIVE),
    ("air_21_terrain_radar", "地形跟随雷达",
     PREFIX + "机载地形跟随雷达天线特写，平板缝隙天线阵面与安装基座、波导接口清晰，"
     "深灰雷达罩与金属边框，低饱和深灰主色，局部绿色指示灯，高清图标。" + NEGATIVE),
    ("air_22_countermeasure", "干扰弹布撒器",
     PREFIX + "机载箔条/曳光弹干扰弹发射器特写，圆柱发射巢的多个发射孔与安装架清晰，"
     "部分箔条条带散出，军灰金属质感，低饱和军灰主色，高清图标。" + NEGATIVE),
    ("arm_17_spacer_armor", "附加钢板",
     PREFIX + "坦克焊接附加钢板装甲特写，带螺栓固定的多层间隙钢板与支撑架结构清晰，"
     "锈迹磨损的轧制钢板质感，低饱和军绿灰主色，高清图标。" + NEGATIVE),
    ("arm_18_gun_mantlet", "厚重炮盾",
     PREFIX + "坦克厚重整体式炮盾特写，弧面铸钢炮盾包覆火炮根部、防盾螺栓与炮管固定座清晰，"
     "深灰铸钢与迷彩斑驳质感，低饱和深灰主色，高清图标。" + NEGATIVE),
    ("aa_14_searchlight", "探照灯组",
     PREFIX + "防空探照灯特写，大型弧光探照灯抛物面反射镜与防护栅格、支架摇柄清晰，"
     "暗色灯体与玻璃镜面反光，低饱和炭灰主色，局部暖白光芯，高清图标。" + NEGATIVE),
    ("aa_15_flak_burst", "定时引信防空弹",
     PREFIX + "防空炮定时引信弹药特写，竖置炮弹弹体、弹头机械引信刻度环与弹底发射药筒清晰，"
     "黄铜弹壳与涂漆弹体，低饱和军灰黄铜色，高清图标。" + NEGATIVE),
    ("for_14_bomb_shelter", "防空洞加固",
     PREFIX + "地下工事防爆加固门特写，厚重钢制防爆门与铰链、加固斜撑与混凝土门框清晰，"
     "混凝土与锈蚀钢材质感，低饱和灰主色，高清图标。" + NEGATIVE),
    ("gen_stealth_coating", "雷达吸波涂层",
     PREFIX + "雷达吸波涂层样板特写，六边形涂层板材切面与多层吸波结构剖面、表面锯齿纹理清晰，"
     "深色哑光涂层与金属底层，低饱和炭黑主色，局部蓝紫光泽，高清图标。" + NEGATIVE),
]


def call_api(prompt: str) -> str:
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": "1024x1024", "n": 1})
    req = urllib.request.Request(
        BASE_URL + "/images/generations",
        data=payload.encode("utf-8"),
        headers={"Content-Type": "application/json", "Authorization": "Bearer " + API_KEY},
        method="POST",
    )
    with netfix.open_url(req, timeout=180) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    return data["data"][0]["url"]


def download(url: str, path: str) -> None:
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with netfix.open_url(req, timeout=180) as resp:
        with open(path, "wb") as f:
            f.write(resp.read())


def main() -> None:
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    ok, fail = 0, 0
    for mid, name, prompt in ICONS:
        out = os.path.join(OUTPUT_DIR, mid + ".png")
        if os.path.exists(out):
            print("[skip] 已存在 %s" % mid)
            ok += 1
            continue
        print("[%s] 生成中：%s ..." % (mid, name), flush=True)
        try:
            url = call_api(prompt)
            download(url, out)
            print("  -> %s" % out, flush=True)
            ok += 1
        except Exception as e:
            print("  !! 失败: %r" % e, flush=True)
            fail += 1
        time.sleep(2)
    print("完成：成功 %d / 失败 %d，输出目录 %s" % (ok, fail, OUTPUT_DIR))
    sys.exit(1 if fail else 0)


if __name__ == "__main__":
    main()
