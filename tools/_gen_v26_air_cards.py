#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v26 新飞机卡图生成（8张，D段 card_id 命名，仿 gen_drone_icons.py 模板）：
  ww2_air_bomber(B-17) / ww2_air_dive_bomber(Ju 87) / cold_air_strike_fighter(F-111)
  / cold_air_bomber(图-95) / mod_air_multirole(F-15E) / mod_air_bomber(B-52)
  / fut_air_stealth_multirole(六代机) / fut_air_stealth_bomber(B-21)

输出白底原图到 docs/待生成卡图_v26飞机/ 供审核（用户看过后再 deploy）。"""
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
OUTPUT_DIR = os.path.join(ROOT, "docs", "待生成卡图_v26飞机")

STRICT_PREFIX = (
    "STRICTLY a pure 2D side profile silhouette view, absolutely NO front view, "
    "NO three-quarter view, NO perspective depth, flat orthographic game sprite, "
    "single subject only centered, clean pure white background with NO ground, "
    "NO shadow, NO floor, NO reflection, NO watermark, NO signature, NO text, "
    "NO extra sketches, NO character faces visible, NO environment, "
    "studio isolated product shot style. "
)
NEGATIVE = (
    "不要：三分之四视角、斜侧视、透视 perspective、广角、仰视、俯视、等距 isometric、"
    "鸟瞰 top-down、看到顶部、背景场景、地面、投影底板、文字、水印、logo、人物。"
    "机头必须朝向画面左侧。"
)

UNITS = [
    {
        "fname": "ww2_air_bomber",
        "display": "B-17 空中堡垒",
        "prompt": STRICT_PREFIX + (
            "二战重型战略轰炸机（B-17 空中堡垒），严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "军事设定图，以【二战·轰炸机】四发重型轰炸机为主体，机头朝向画面左侧，"
            "完整机体居中入镜，细长圆柱形机身、四台星形活塞发动机与宽大展弦比机翼轮廓清晰，"
            "机身多处球形自卫机枪塔与垂直尾翼结构明确，银色蒙皮铆接痕与战时涂装，"
            "低饱和银灰主色，干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "fname": "ww2_air_dive_bommer_PLACEHOLDER",
        "display": "占位",
        "prompt": "",
    },
    {
        "fname": "ww2_air_dive_bomber",
        "display": "Ju 87 斯图卡",
        "prompt": STRICT_PREFIX + (
            "二战俯冲轰炸机（Ju 87 斯图卡），严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "军事设定图，以【二战·俯冲轰炸机】倒鸥形机翼双座俯冲轰炸机为主体，机头朝向画面左侧，"
            "完整机体居中入镜，倒鸥形弯曲机翼、固定主起落架整流罩与双座纵向座舱轮廓清晰，"
            "机腹挂载重型炸弹、发动机整流罩结构明确，深灰绿迷彩涂装，"
            "低饱和军绿灰主色，干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "fname": "cold_air_strike_fighter",
        "display": "F-111 土豚",
        "prompt": STRICT_PREFIX + (
            "冷战可变后掠翼战斗轰炸机（F-111 土豚），严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "军事设定图，以【冷战·战斗轰炸机】可变后掠翼重型战机为主体，机头朝向画面左侧，"
            "完整机体居中入镜，机身两侧可变后掠翼与并列双座座舱轮廓清晰，"
            "机腹武器舱与进气道结构明确，越战灰白迷彩涂装，"
            "低饱和灰白主色，干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "fname": "cold_air_bomber",
        "display": "图-95 熊式",
        "prompt": STRICT_PREFIX + (
            "冷战战略轰炸机（图-95 熊式），严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "军事设定图，以【冷战·战略轰炸机】四发涡轮螺旋桨远程轰炸机为主体，机头朝向画面左侧，"
            "完整机体居中入镜，粗壮机身、四台共轴反转螺旋桨发动机与后掠机翼轮廓清晰，"
            "机头玻璃观测舱与机尾炮塔结构明确，苏联灰蓝涂装，"
            "低饱和灰蓝主色，干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "fname": "mod_air_multirole",
        "display": "F-15E 攻击鹰",
        "prompt": STRICT_PREFIX + (
            "现代双发重型多用途战斗机（F-15E 攻击鹰），严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "军事设定图，以【现代·多用途战机】双发重型战斗机为主体，机头朝向画面左侧，"
            "完整机体居中入镜，楔形机身、双垂尾与翼下重型挂载（炸弹与导弹）轮廓清晰，"
            "保形油箱与方形进气道结构明确，浅灰空优迷彩，"
            "低饱和浅灰主色，局部挂架细节，干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "fname": "mod_air_bomber",
        "display": "B-52 同温层堡垒",
        "prompt": STRICT_PREFIX + (
            "现代战略轰炸机（B-52 同温层堡垒），严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "军事设定图，以【现代·战略轰炸机】八发亚音速远程轰炸机为主体，机头朝向画面左侧，"
            "完整机体居中入镜，细长机身、八台涡扇发动机吊舱与后掠上单翼轮廓清晰，"
            "机腹密集挂架与高大垂直尾翼结构明确，深灰机体涂装，"
            "低饱和深灰主色，干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "fname": "fut_air_stealth_multirole",
        "display": "六代机制空型",
        "prompt": STRICT_PREFIX + (
            "近未来六代隐身多用途战斗机，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面设定图，以【近未来·六代机】无尾飞翼构型隐身战机为主体，机头朝向画面左侧，"
            "完整机体居中入镜，扁平融合机身、倾斜双垂尾与内埋武器舱轮廓清晰，"
            "自适应循环发动机喷口与分布式光学孔径结构明确，低可视度深灰隐身涂层，"
            "低饱和炭灰主色，局部蓝色能量航灯发光，干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "fname": "fut_air_stealth_bomber",
        "display": "B-21 突袭者",
        "prompt": STRICT_PREFIX + (
            "飞翼隐身战略轰炸机（B-21 突袭者，同 B-2 幽灵飞翼构型），严格2D正侧视，正交投影，"
            "游戏单位立绘/精灵图姿态，科幻硬表面设定图，"
            "主体是一整块后掠飞翼：没有垂直尾翼、没有水平尾翼、没有独立筒状机身、没有驾驶员座舱盖气泡，"
            "整机如一片厚刃刀锋/纯三角形飞镖，机头尖锐朝向画面左侧，"
            "机背中线隆起一条脊线并开背部进气口，机尾为锯齿状W形后缘轮廓清晰，"
            "深色低可视度隐身涂层与蒙皮拼接线，"
            "低饱和暗灰主色，局部青色能量指示微光，干净棚拍纯白背景，无地面无场景无杂物，高清。"
            "绝对禁止：垂直尾翼、双垂尾、传统机身、外露挂架、常规战斗机布局。" + NEGATIVE
        ),
    },
]
UNITS = [u for u in UNITS if u["prompt"]]


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
    for u in UNITS:
        out = os.path.join(OUTPUT_DIR, u["fname"] + ".png")
        if os.path.exists(out):
            print("[skip] 已存在 %s" % u["fname"])
            ok += 1
            continue
        print("[%s] 生成中：%s ..." % (u["fname"], u["display"]), flush=True)
        try:
            url = call_api(u["prompt"])
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
