#!/usr/bin/env python3
"""生成 14 张势力专属卡（fe_*）卡图。

调用 agnes-image-2.0-flash API，输出到 docs/待生成卡图_14张fe/ 供审核。
审核通过后用 deploy_fe_card_icons.py 部署到 assets/card_icons/（card_id.png 直接命名，
走引擎查找链①优先级，无需改代码、无需配 PLAYER_ICON_OVERRIDE）。

域名：实测 .com SSL reset，.cn 可用（2026-08）。
Key：3 个轮换（docs/生图API.txt）。
"""
import json
import os
import subprocess
import time
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
with open(KEY_FILE, "r", encoding="utf-8") as f:
    API_KEY = f.read().strip()
BASE_URL = "https://apihub.agnes-ai.cn/v1"   # 实测 .cn 可用，.com SSL reset
MODEL = "agnes-image-2.0-flash"
OUTPUT_DIR = os.path.join(ROOT, "docs", "待生成卡图_14张fe")

# 复用 generate_missing_card_icons_11.py 的 prompt 模板
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

# 14 张 fe_* 势力专属卡（card_id, 显示名, prompt）
UNITS = [
    # ─── 钢壁防务（iron_wall_corp）重装堡垒/超级步兵 ───
    {
        "fname": "fe_iron_wall_bastion",
        "display": "不朽堡垒（钢壁防务·堡垒）",
        "prompt": STRICT_PREFIX + (
            "近未来科幻终极堡垒要塞，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面重型堡垒单位设定图，以【近未来·堡垒】不朽堡垒为主体，"
            "完整单位居中入镜，三层复合装甲板结构、双联装防空炮塔与中央能量核心轮廓清晰，"
            "厚重铆接合金墙体与多向炮廓结构明确，金属磨损旧化，"
            "低饱和暗钢铁灰主色，局部亮蓝能量护盾纹路与核心发光，Boss威压感，"
            "干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "fname": "fe_iron_wall_juggernaut",
        "display": "重装先驱（钢壁防务·超级步兵）",
        "prompt": STRICT_PREFIX + (
            "近未来科幻超级重装步兵，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面重型人形单位设定图，以【近未来·轻装（实际重型）】重装先驱为主体，"
            "完整单位居中入镜，实验性反应装甲外骨骼、重型动力甲与肩扛武器轮廓清晰，"
            "厚重板块式装甲与液压关节结构明确，金属磨损旧化，"
            "低饱和暗钢铁主色，局部亮蓝反应装甲纹路与眼缝发光，威武压迫感，"
            "干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    # ─── 新星兵工（nova_arms）重火力 ───
    {
        "fname": "fe_nova_devastator",
        "display": "歼灭者自行火炮（新星兵工·支援）",
        "prompt": STRICT_PREFIX + (
            "近未来科幻终极自行火炮平台，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面重型支援单位设定图，以【近未来·支援】歼灭者自行火炮为主体，"
            "完整单位居中入镜，多联装重型火箭/榴弹发射管阵列、重型履带底盘与指挥塔轮廓清晰，"
            "棱角分明的合金装甲与多管炮结构明确，金属磨损旧化，"
            "低饱和军灰主色，局部橙红能量炮膛与火控核心发光，Boss级火力威压感，"
            "干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "fname": "fe_nova_ghost_sniper",
        "display": "幽灵狙击组（新星兵工·精英狙击）",
        "prompt": STRICT_PREFIX + (
            "现代科幻精英狙击小组，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面精锐人形单位设定图，以【现代·轻装】幽灵狙击组为主体，"
            "完整单位居中入镜，电磁轨道步枪长管、光学瞄准与吉利服伪装轮廓清晰，"
            "流线型战术外骨骼与消磁涂层结构明确，轻度磨损，"
            "低饱和暗灰主色，局部亮蓝轨道步枪能量槽与瞄准光发光，精锐冷峻感，"
            "干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    # ─── 以太动力（aether_dynamics）高速悬浮 ───
    {
        "fname": "fe_aether_hover_cavalry",
        "display": "以太骑兵（以太动力·悬浮突击）",
        "prompt": STRICT_PREFIX + (
            "近未来科幻悬浮摩托突击队，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面高速轻型单位设定图，以【近未来·轻装】以太骑兵为主体，"
            "完整单位居中入镜，悬浮摩托底盘、能量推进器与骑乘士兵轮廓清晰，"
            "流线型悬浮车体与侧挂武器结构明确，轻度磨损，"
            "低饱和亮青蓝主色，局部强烈蓝色悬浮能量场与推进尾焰发光，极速穿插感，"
            "干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "fname": "fe_aether_swarm_queen",
        "display": "蜂群母机（以太动力·空中母舰）",
        "prompt": STRICT_PREFIX + (
            "近未来科幻无人机空中母舰，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面空中Boss级单位设定图，以【近未来·空中】蜂群母机为主体，"
            "完整单位居中入镜，巨型飞翼母舰机身、多联无人机释放舱与能量炮塔轮廓清晰，"
            "棱角分明的合金蒙皮与全息指挥阵列结构明确，轻度磨损，"
            "低饱和冷灰主色，局部亮蓝蜂群指挥光网与核心发光，Boss级空中威压感，"
            "干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    # ─── 量子后勤（quantum_logistics）基地/修复 ───
    {
        "fname": "fe_quantum_mobile_base",
        "display": "移动堡垒基地（量子后勤·移动基地）",
        "prompt": STRICT_PREFIX + (
            "近未来科幻移动指挥中心基地，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面重型堡垒支援单位设定图，以【近未来·堡垒】移动堡垒基地为主体，"
            "完整单位居中入镜，巨型履带底盘、指挥塔楼与全息通信阵列轮廓清晰，"
            "厚重合金装甲与维修机械臂结构明确，金属磨损旧化，"
            "低饱和暖白灰主色，局部亮绿修复能量场与全息指挥光发光，沉稳支援感，"
            "干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "fname": "fe_quantum_repair_drone",
        "display": "纳米修复蜂群（量子后勤·修复无人机）",
        "prompt": STRICT_PREFIX + (
            "近未来科幻纳米修复无人机群，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面空中支援单位设定图，以【近未来·空中】纳米修复蜂群为主体，"
            "完整单位居中入镜，多架小型修复无人机编队、机械臂与修复射流轮廓清晰，"
            "流线型蜂群机体与能量管线结构明确，轻度磨损，"
            "低饱和亮白主色，局部亮绿纳米修复光束与核心发光，灵动支援感，"
            "干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    # ─── 螺旋侦察（helix_recon）潜行/精确 ───
    {
        "fname": "fe_helix_phantom",
        "display": "幻影特工（螺旋侦察·光学迷彩）",
        "prompt": STRICT_PREFIX + (
            "近未来科幻光学迷彩超级侦察兵，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面精锐人形单位设定图，以【近未来·轻装】幻影特工为主体，"
            "完整单位居中入镜，流线型迷彩外骨骼、双持消音武器与战术目镜轮廓清晰，"
            "半透明光学迷彩涂层与液压关节结构明确，轻度磨损，"
            "低饱和暗紫主色，局部亮紫光学迷彩光晕与眼缝发光，神秘潜行感，"
            "干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "fname": "fe_helix_orbital_strike",
        "display": "轨道打击引导组（螺旋侦察·天基火力）",
        "prompt": STRICT_PREFIX + (
            "近未来科幻轨道打击引导小组，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面重型支援单位设定图，以【近未来·支援】轨道打击引导组为主体，"
            "完整单位居中入镜，大型折叠式激光引导仪、相控阵天线与重装底盘轮廓清晰，"
            "棱角分明的合金支架与定向能量设备结构明确，轻度磨损，"
            "低饱和暗灰紫主色，局部强烈亮紫天基锁定光束与核心发光，Boss级远程威压感，"
            "干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    # ─── 虚空相位（void_research）相位科技 ───
    {
        "fname": "fe_void_phase_cannon",
        "display": "相位炮台（虚空相位·相位武器）",
        "prompt": STRICT_PREFIX + (
            "近未来科幻相位武器平台炮台，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面重型堡垒单位设定图，以【近未来·堡垒】相位炮台为主体，"
            "完整单位居中入镜，巨型相位主炮管、能量聚能环与悬浮基座轮廓清晰，"
            "棱角分明的相位合金装甲与能量管线结构明确，轻度磨损，"
            "低饱和暗紫黑主色，局部强烈紫色相位能量核心与共鸣纹路发光，神秘虚空威压感，"
            "干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "fname": "fe_void_dimensional_soldier",
        "display": "次元行者（虚空相位·次元改造步兵）",
        "prompt": STRICT_PREFIX + (
            "近未来科幻次元改造超级步兵，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面精锐人形单位设定图，以【近未来·轻装】次元行者为主体，"
            "完整单位居中入镜，相位扭曲外骨骼、次元跃迁核心与手持相位武器轮廓清晰，"
            "半透明次元裂隙特效与能量管线结构明确，轻度磨损，"
            "低饱和暗紫主色，局部强烈紫色次元裂隙光晕与核心发光，神秘超凡感，"
            "干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    # ─── 边境联合（frontier_union）通用/混编 ───
    {
        "fname": "fe_frontier_veteran",
        "display": "边境老兵（边境联合·均衡步兵）",
        "prompt": STRICT_PREFIX + (
            "现代科幻身经百战的老兵步兵，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面精锐人形单位设定图，以【现代·轻装】边境老兵为主体，"
            "完整单位居中入镜，模块化战术外骨骼、突击步枪与多功能背包轮廓清晰，"
            "磨损但保养良好的合金装甲与战术挂载结构明确，中度磨损，"
            "低饱和卡其绿主色，局部亮琥珀色传感器与眼缝发光，沉稳老兵质感，"
            "干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "fname": "fe_frontier_mixed_company",
        "display": "混编突击队（边境联合·三位一体）",
        "prompt": STRICT_PREFIX + (
            "近未来科幻混编三位一体突击队，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面中型装甲单位设定图，以【近未来·装甲】混编突击队为主体，"
            "完整单位居中入镜，轮式装甲车体、顶部防空导弹与侧挂步兵战斗舱轮廓清晰，"
            "棱角分明的多任务合金装甲与三系武器挂载结构明确，轻度磨损，"
            "低饱和军绿主色，局部亮琥珀色多功能传感器与核心发光，全能突击质感，"
            "干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
]


def generate_image(prompt: str, output_path: str) -> tuple:
    """调用 agnes-image-2.0-flash 生成图片。"""
    payload = json.dumps({
        "model": MODEL,
        "prompt": prompt,
        "size": "1024x1024",
        "n": 1,
    })
    tmpfile = output_path + ".payload.json"
    with open(tmpfile, "w", encoding="utf-8") as f:
        f.write(payload)

    hdr = "Authorization: Bearer " + API_KEY
    resp_file = output_path + ".resp.json"
    cmd = [
        "curl", "--http1.1", "-4", "-s",
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

    content = open(resp_file, "r", encoding="utf-8").read()
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
    dl_cmd = ["curl", "--http1.1", "-4", "-s", "-L", "-o", output_path, url, "--max-time", "120"]
    subprocess.run(dl_cmd, capture_output=True, text=True, timeout=150)

    if os.path.exists(output_path) and os.path.getsize(output_path) > 1000:
        return True, "OK (" + str(os.path.getsize(output_path)) + " bytes)"
    return False, "Download failed/too small"


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print("Output dir: " + OUTPUT_DIR)
    print("BASE_URL: " + BASE_URL)
    print("Generating " + str(len(UNITS)) + " images...\n")

    results = []
    for i, unit in enumerate(UNITS):
        fname = unit["fname"] + ".png"
        fpath = os.path.join(OUTPUT_DIR, fname)
        label = unit["display"]
        print("[" + str(i + 1) + "/" + str(len(UNITS)) + "] " + label + "...")

        success, msg = generate_image(unit["prompt"], fpath)
        results.append((unit["fname"], unit["display"], fname, success, msg))

        if success:
            print("  OK: " + msg)
        else:
            print("  FAILED: " + msg + " — retrying once...")
            time.sleep(3)
            success2, msg2 = generate_image(unit["prompt"], fpath)
            results[-1] = (unit["fname"], unit["display"], fname, success2, msg2)
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
        print("  " + r[0] + " (" + r[1] + ") -> " + r[2] + " : " + status)
    print("\nTotal: " + str(ok) + " OK, " + str(fail) + " FAIL of " + str(len(results)))


if __name__ == "__main__":
    main()
