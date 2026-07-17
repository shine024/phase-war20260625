#!/usr/bin/env python3
"""生成 11 张缺失卡图：6 平台卡(082-087) + 5 守护者卡(110-114)。
调用 agnes-image-2.0-flash API，输出到 docs/待生成卡图_11张/ 供审核。
审核通过后用 deploy_card_icons_11.py 部署到 assets/card_icons/。
"""
import json
import os
import subprocess
import time
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
with open(KEY_FILE, "r") as f:
    API_KEY = f.read().strip()
BASE_URL = "https://apihub.agnes-ai.com/v1"
MODEL = "agnes-image-2.0-flash"
OUTPUT_DIR = os.path.join(ROOT, "docs", "待生成卡图_11张")

# 复用 regenerate_7_sprites.py 的 prompt 模板
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
)

# 11 张卡：编号、文件名、显示名、prompt
UNITS = [
    # === F段：6 张平台卡（无源ID映射的变种）===
    {
        "num": 82,
        "fname": "vis_enemy_082",
        "display": "一战野战观测站",
        "prompt": STRICT_PREFIX + (
            "一战野战观测/通信平台，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面支援单位设定图，以【一战·支援】野战观测站为主体，"
            "完整单位居中入镜，木制观察塔架、野战电话交换机与有线电缆线圈轮廓清晰，"
            "帆布帐篷与旗语信号旗结构明确，金属磨损旧化，"
            "低饱和灰绿主色，局部蓝色能量指示灯发光，干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "num": 83,
        "fname": "vis_enemy_083",
        "display": "二战雷达指挥车",
        "prompt": STRICT_PREFIX + (
            "二战雷达指挥车，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面支援单位设定图，以【二战·支援】雷达指挥车为主体，"
            "完整单位居中入镜，折叠式网格天线阵列、车厢侧面地图桌与通信设备轮廓清晰，"
            "卡车底盘与履带轮组结构明确，金属磨损旧化，"
            "低饱和军绿灰主色，局部蓝色能量雷达屏幕发光，干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "num": 84,
        "fname": "vis_enemy_084",
        "display": "二战203毫米重型迫击炮",
        "prompt": STRICT_PREFIX + (
            "二战203毫米重型迫击炮阵地，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面火力支援单位设定图，以【二战·支援】203毫米重型迫击炮为主体，"
            "完整单位居中入镜，粗壮迫击炮管、重型底座底盘与弹药箱堆轮廓清晰，"
            "仰角炮口与液压驻锄结构明确，金属磨损旧化，"
            "低饱和军灰主色，局部蓝色能量炮膛发光，干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "num": 85,
        "fname": "vis_enemy_085",
        "display": "冷战悍马轻型侦察车",
        "prompt": STRICT_PREFIX + (
            "冷战悍马轻型侦察车，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面轻型车辆设定图，以【冷战·轻装】悍马侦察车为主体，"
            "完整单位居中入镜，四轮高机动底盘、车顶机枪架与通信天线轮廓清晰，"
            "方正车体与防弹玻璃结构明确，轻度磨损，"
            "低饱和沙黄主色，局部蓝色能量车灯与传感器发光，干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "num": 86,
        "fname": "vis_enemy_086",
        "display": "冷战BRDM-2轮式装甲侦察车",
        "prompt": STRICT_PREFIX + (
            "冷战BRDM-2轮式装甲侦察车，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面轻型装甲设定图，以【冷战·轻装】BRDM-2侦察车为主体，"
            "完整单位居中入镜，四轮两轴底盘、中央炮塔与14.5mm机枪轮廓清晰，"
            "船形防弹车体与轮胎链条结构明确，金属磨损旧化，"
            "低饱和军绿主色，局部蓝色能量潜望镜发光，干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "num": 87,
        "fname": "vis_enemy_087",
        "display": "近未来量子感知雷达平台",
        "prompt": STRICT_PREFIX + (
            "近未来量子感知雷达平台，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面支援单位设定图，以【近未来·支援】量子感知雷达平台为主体，"
            "完整单位居中入镜，悬浮全息雷达穹顶、量子纠缠天线阵列与底盘轮廓清晰，"
            "棱角分明的合金装甲与能量管线结构明确，轻度磨损，"
            "低饱和冷灰主色，局部蓝色能量核心与全息扫描光发光，干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    # === G段：5 张守护者成就卡（终极Boss奖励，更强Boss感）===
    {
        "num": 110,
        "fname": "vis_enemy_110",
        "display": "铁壁守护者·一战",
        "prompt": STRICT_PREFIX + (
            "一战终极Boss守护者重型装甲巨兽，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面Boss级装甲设定图，以【一战·Boss】铁壁守护者为主体，"
            "完整单位居中入镜，巨型菱形坦克底盘、多联装重型火炮与厚重铆接装甲板轮廓清晰，"
            "超尺度履带与指挥塔结构明确，严重战损旧化，"
            "低饱和暗钢铁主色，多处蓝色能量核心与符文纹路发光，Boss威压感，干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "num": 111,
        "fname": "vis_enemy_111",
        "display": "闪电守护者·二战",
        "prompt": STRICT_PREFIX + (
            "二战终极Boss守护者闪电战重型装甲巨兽，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面Boss级装甲设定图，以【二战·Boss】闪电守护者为主体，"
            "完整单位居中入镜，巨型坦克底盘、88mm长管重炮与倾斜厚重装甲轮廓清晰，"
            "交错式负重轮与防磁涂层结构明确，严重战损旧化，"
            "低饱和暗灰主色，多处蓝色能量电弧纹路与核心发光，Boss威压感，干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "num": 112,
        "fname": "vis_enemy_112",
        "display": "雷霆守护者·冷战",
        "prompt": STRICT_PREFIX + (
            "冷战终极Boss守护者雷霆重型支援巨兽，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面Boss级支援单位设定图，以【冷战·Boss】雷霆守护者为主体，"
            "完整单位居中入镜，巨型多联装导弹发射阵列、相控阵雷达穹顶与重型履带底盘轮廓清晰，"
            "棱角分明的合金装甲与发射管结构明确，中度磨损，"
            "低饱和暗灰绿主色，多处蓝色能量雷暴核心与电子纹路发光，Boss威压感，干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "num": 113,
        "fname": "vis_enemy_113",
        "display": "幽灵守护者·现代",
        "prompt": STRICT_PREFIX + (
            "现代终极Boss守护者幽灵隐身飞行巨兽，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面Boss级空中单位设定图，以【现代·Boss】幽灵守护者为主体，"
            "完整单位居中入镜，巨型隐身飞翼机身、内置弹仓与全向矢量喷口轮廓清晰，"
            "棱角分明的隐身涂层蒙皮与传感器阵列结构明确，轻度磨损，"
            "低饱和暗灰黑主色，多处蓝色能量光学迷彩核心与扫描光发光，Boss威压感，干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "num": 114,
        "fname": "vis_enemy_114",
        "display": "终焉守护者·近未来",
        "prompt": STRICT_PREFIX + (
            "近未来终极Boss守护者终焉量子装甲巨兽，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面终极Boss级装甲设定图，以【近未来·Boss】终焉守护者为主体，"
            "完整单位居中入镜，巨型双足机甲底盘、重型粒子主炮与能量护盾发生器轮廓清晰，"
            "超精密的量子合金装甲与能量管线结构明确，棱角分明，"
            "低饱和冷黑钢主色，多处强烈蓝色能量核心、相位纹路与全息光发光，终极Boss威压感，干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
]


def generate_image(prompt: str, output_path: str) -> tuple[bool, str]:
    """调用 agnes-image-2.0-flash 生成图片。"""
    payload = json.dumps({
        "model": MODEL,
        "prompt": prompt,
        "size": "1024x1024",
        "n": 1,
    })
    tmpfile = output_path + ".payload.json"
    with open(tmpfile, "w") as f:
        f.write(payload)

    hdr = "Authorization: Bearer " + API_KEY
    resp_file = output_path + ".resp.json"
    cmd = [
        "curl", "--http1.1", "-s",
        "-X", "POST", BASE_URL + "/images/generations",
        "-H", hdr,
        "-H", "Content-Type: application/json",
        "--data-binary", "@" + tmpfile,
        "-o", resp_file,
        "--max-time", "120",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=150)
    try:
        os.unlink(tmpfile)
    except OSError:
        pass

    if result.returncode != 0:
        return False, "curl exit " + str(result.returncode) + ": " + (result.stderr or "")[:200]

    if not os.path.exists(resp_file) or os.path.getsize(resp_file) < 10:
        return False, "No response file"

    content = open(resp_file).read()
    try:
        os.unlink(resp_file)
    except OSError:
        pass

    try:
        data = json.loads(content)
    except json.JSONDecodeError:
        return False, "Response not JSON: " + content[:200]

    if "data" not in data or len(data["data"]) == 0:
        err = data.get("error", {})
        msg = err.get("message", str(data)[:200]) if isinstance(err, dict) else str(data)[:200]
        return False, "No data: " + msg

    url = data["data"][0].get("url", "")
    if not url:
        return False, "No URL in response"

    # 下载图片
    dl_cmd = ["curl", "--http1.1", "-s", "-L", "-o", output_path, url, "--max-time", "120"]
    subprocess.run(dl_cmd, capture_output=True, text=True, timeout=150)

    if os.path.exists(output_path) and os.path.getsize(output_path) > 1000:
        return True, "OK (" + str(os.path.getsize(output_path)) + " bytes)"
    return False, "Download failed/too small"


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print("Output dir: " + OUTPUT_DIR)
    print("Generating " + str(len(UNITS)) + " images...\n")

    results = []
    for i, unit in enumerate(UNITS):
        fname = unit["fname"] + ".png"
        fpath = os.path.join(OUTPUT_DIR, fname)
        label = "[" + str(unit["num"]) + "] " + unit["display"]
        print("[" + str(i + 1) + "/" + str(len(UNITS)) + "] " + label + "...")

        success, msg = generate_image(unit["prompt"], fpath)
        results.append((unit["num"], unit["display"], fname, success, msg))

        if success:
            print("  OK: " + msg)
        else:
            print("  FAILED: " + msg + " — retrying once...")
            time.sleep(3)
            success2, msg2 = generate_image(unit["prompt"], fpath)
            results[-1] = (unit["num"], unit["display"], fname, success2, msg2)
            if success2:
                print("  RETRY OK: " + msg2)
            else:
                print("  RETRY FAILED: " + msg2)
        time.sleep(1)

    print("\n=== Summary ===")
    ok = sum(1 for r in results if r[3])
    fail = len(results) - ok
    for r in results:
        status = "OK" if r[3] else "FAIL"
        print("  [" + str(r[0]) + "] " + r[1] + " -> " + r[2] + " : " + status)
    print("\nTotal: " + str(ok) + " OK, " + str(fail) + " FAIL of " + str(len(results)))


if __name__ == "__main__":
    main()
