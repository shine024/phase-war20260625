"""
重生成 docs\重修改卡图\ 下6张卡图
风格：严格按项目敌方卡官方模板（STRICT_PREFIX + 中文主体描述 + NEGATIVE，
      参考 tools/generate_drop_card_icons.py / tools/gen_drone_icons.py）
要求：单个单位、准备攻击姿态（举枪瞄准/充能待发，未开火无枪口焰）、朝左、严格2D正侧视
输出：docs/重修改卡图/<card_id>.png
"""
import os, json, urllib.request, time, ssl

# 2.1-flash（.cn 端点）= 已部署敌方 drop 卡同款配置，指令遵循明显好于 2.0-flash
BASE_URL = "https://apihub.agnes-ai.cn/v1/images/generations"
MODEL = "agnes-image-2.1-flash"
OUTPUT_DIR = r"F:\godot fair duet\create\phase-war\docs\重修改卡图"

api_key = ""
# .cn 端点优先用项目 key 文件（与 generate_drop_card_icons.py 同源，已验证可用）
try:
    with open(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                           "tools", "_api_key.txt"), "r", encoding="utf-8") as f:
        api_key = f.readline().strip()
except Exception:
    pass
api_key = os.environ.get("SKIPPABLE_API_KEY", api_key) or api_key
if not api_key:
    config_path = os.path.expanduser("~/.hermes/config.yaml")
    try:
        with open(config_path, "r", encoding="utf-8") as f:
            for line in f:
                if "api_key:" in line and not line.strip().startswith("#"):
                    api_key = line.strip().split("api_key:", 1)[1].strip()
                    break
    except Exception:
        pass
if not api_key:
    print("ERROR: No API key found!"); exit(1)

print(f"API key: {api_key[:10]}...")
print()

# ===== 敌方卡官方风格模板（与 tools/generate_drop_card_icons.py 完全一致）=====
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
    "鸟瞰 top-down、看到顶部、背景场景、地面、投影底板、文字、水印、logo、"
    "开火枪口焰、烟雾、弹壳、发射物、爆炸、3D渲染立体感、真实照片。"
)

# 6 cards: 单个单位、准备攻击姿态、朝左、严格2D正侧视
CARDS = [
    ("fut_swarm",
     STRICT_PREFIX + (
         "近未来自主蜂群无人机，严格2D正侧视（只能看到机身侧面轮廓，看不到正面），正交投影，"
         "游戏单位立绘/精灵图姿态，科幻硬表面空中单位设定图，以【近未来·空中】蜂群无人机为主体，"
         "完整单位居中入镜，呈准备攻击预备姿态：机头必须指向画面左侧边缘，"
         "微型导弹发射舱舱门开启露出导弹待发、传感器窗口蓝点亮起，蓄势待发，"
         "画面中绝对没有正在发射的导弹、没有推进火焰尾迹、没有射出的光束，"
         "紧凑球形机身、微型喷气推进器与传感器阵列轮廓清晰，模块化舱段结构明确，"
         "低饱和军灰主色，局部蓝色能量节点发光，"
         "干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
     )),
    ("fut_nano_drone",
     STRICT_PREFIX + (
         "近未来纳米修复无人机，严格2D正侧视（只能看到机身侧面轮廓，看不到正面），正交投影，"
         "游戏单位立绘/精灵图姿态，科幻硬表面支援无人机设定图，以【近未来·空中】纳米修复机为主体，"
         "完整单位居中入镜，呈准备攻击预备姿态：机头必须指向画面左侧边缘，"
         "多关节机械修复臂向画面左侧前伸张开、绿色纳米发射器喷口聚光充能，"
         "画面中绝对没有射出的光束、没有能量射线、没有烟雾，"
         "小巧球形本体、多关节机械修复臂与能量光束发射器轮廓清晰，"
         "精密齿轮与纳米喷口结构明确，"
         "低饱和浅银灰主色，局部绿色纳米光束与蓝色能量环发光，"
         "干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
     )),
    ("drop_smg_mk2",
     STRICT_PREFIX + (
         "一战德军 MP18-II 冲锋枪突击兵，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
         "科幻硬表面军事单位设定图，单名士兵持伯格曼 MP18-II 冲锋枪呈准备攻击预备姿态："
         "士兵必须面向画面左侧，枪口指向画面左侧边缘，身体前倾压步、"
         "冲锋枪举至肩线手指搭扳机蓄势待发，"
         "画面中绝对没有枪口火光、没有烟雾、没有弹壳、没有射出的弹药，武器处于举起静止待发状态，"
         "煤灰色野战军装配尖顶钢盔与弹药挎包轮廓清晰，金属磨损旧化，"
         "低饱和军灰主色，局部蓝色能量指示微光，"
         "干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
     )),
    ("drop_phase_lance",
     STRICT_PREFIX + (
         "二战实验性相位刺刀突击兵，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
         "科幻硬表面军事单位设定图，单名士兵持加装相位刺刀的突击步枪呈准备攻击预备姿态："
         "士兵必须面向画面左侧，弓步压身、刺刀后收蓄力预突刺指向画面左侧，相位刃充能待发尚未突刺，"
         "枪口下方伸出细长发光蓝色相位能量刃，灰绿野战服与钢盔轮廓清晰，"
         "低饱和灰绿主色，相位刃青蓝能量发光，"
         "干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
     )),
    ("drop_thunder_field",
     STRICT_PREFIX + (
         "现代雷霆特种突击兵，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
         "科幻硬表面军事单位设定图，单名特种兵持粗壮雷霆突击步枪（顶部导轨+枪身电容组）"
         "呈准备攻击预备姿态：士兵必须面向画面左侧，枪口指向画面左侧边缘，"
         "举枪抵肩瞄准、枪身电容组电弧充满待发，"
         "画面中绝对没有枪口火光、没有烟雾、没有弹壳、没有射出的弹药，武器处于举起静止待发状态，"
         "深色作战服战术背心与头盔轮廓清晰，"
         "低饱和深灰主色，枪身电容组蓝色电弧微光，"
         "干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
     )),
    ("drop_railgun",
     STRICT_PREFIX + (
         "近未来动力装甲电磁步枪兵，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
         "科幻硬表面军事单位设定图，单名动力装甲步兵持电磁轨道步枪（双导轨+管状储能环）"
         "呈准备攻击预备姿态：士兵必须面向画面左侧，枪口指向画面左侧边缘，"
         "托枪抵肩瞄准、双导轨间电磁光弧充能待发，"
         "画面中绝对没有枪口火光、没有炮口焰、没有烟雾、没有射出的弹丸，武器处于举起静止待发状态，"
         "白色与浅灰装甲板轮廓清晰，外露液压关节，"
         "低饱和白灰主色，双导轨之间蓝色电磁光弧发光，"
         "干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
     )),
]

def generate_one(card_id, prompt):
    data = json.dumps({
        "model": MODEL,
        "prompt": prompt,
        "image_size": "1024x1024",
    }).encode("utf-8")
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    # Use no-proxy handler to bypass local SOCKS proxy (10808)
    # Bypass SSL cert verification (server cert expired)
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), urllib.request.HTTPSHandler(context=ctx))
    req = opener.open(urllib.request.Request(BASE_URL, data=data, headers=headers), timeout=300)
    with req as resp:
        result = json.loads(resp.read().decode("utf-8"))
    if "data" in result and len(result["data"]) > 0:
        item = result["data"][0]
        img_url = item.get("url")
        if img_url and "http" in str(img_url):
            img_req = urllib.request.Request(img_url, headers={"User-Agent": "Mozilla/5.0"})
            img_opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), urllib.request.HTTPSHandler(context=ctx))
            with img_opener.open(img_req, timeout=60) as img_resp:
                img_data = img_resp.read()
            output_path = os.path.join(OUTPUT_DIR, f"{card_id}.png")
            with open(output_path, "wb") as f:
                f.write(img_data)
            return True, len(img_data)
    return False, "No URL"

def main():
    import sys
    only = set(sys.argv[1:])  # 可传 card_id 列表只重生成部分
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    todo = [(cid, p) for cid, p in CARDS if not only or cid in only]
    total = len(todo)
    success = failed = skipped = 0
    for i, (card_id, prompt) in enumerate(todo):
        path = os.path.join(OUTPUT_DIR, f"{card_id}.png")
        if os.path.exists(path):
            os.remove(path)
            print(f"[{i+1}/{total}] OVERRIDING existing: {card_id}")
        print(f"[{i+1}/{total}] Generating: {card_id}...", end=" ", flush=True)
        ok, detail = generate_one(card_id, prompt)
        if ok:
            success += 1
            print(f"OK ({int(detail/1024)}KB)")
        else:
            failed += 1
            print(f"FAIL: {detail}")
        if i < total - 1:
            time.sleep(3)
    print()
    print(f"Results: {success} generated, {failed} failed, {skipped} skipped")

if __name__ == "__main__":
    main()
