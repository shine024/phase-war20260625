"""
重生成 docs\重修改卡图\ 下11张卡图（第二批：准备攻击姿态）
对象：vis_enemy_004/005/024/032/034/036/037/040/114 + ww1_inf_enfield + ww1_inf_mp18_x
标准：敌方卡官方模板（STRICT_PREFIX + 中文主体 + NEGATIVE，同 generate_drop_card_icons.py）
     + 单个单位 + 准备攻击预备姿态（未开火无枪口焰）+ 朝左 + 严格2D正侧视
     + agnes-image-2.1-flash @ .cn（同已部署敌方 drop 卡配置）
输出：docs/重修改卡图/<原文件名>.png（白底 1024，供审核抠图）
当前部署版备份在 docs/重修改卡图/_参考原图/
"""
import os, json, urllib.request, time, ssl

BASE_URL = "https://apihub.agnes-ai.cn/v1/images/generations"
MODEL = "agnes-image-2.1-flash"
OUTPUT_DIR = r"F:\godot fair duet\create\phase-war\docs\重修改卡图"

api_key = ""
try:
    with open(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                           "tools", "_api_key.txt"), "r", encoding="utf-8") as f:
        api_key = f.readline().strip()
except Exception:
    pass
api_key = os.environ.get("SKIPPABLE_API_KEY", api_key) or api_key
if not api_key:
    print("ERROR: No API key found!"); exit(1)

print(f"API key: {api_key[:10]}...")
print()

# ===== 敌方卡官方风格模板 =====
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
    "开火枪口焰、烟雾、弹壳、发射物、爆炸、多人班组、3D渲染立体感、真实照片。"
)
READY = (
    "画面中绝对没有枪口火光、没有烟雾、没有弹壳、没有射出的弹药或光束，"
    "武器处于举起静止待发状态。"
)

# (文件名, 提示词)
CARDS = [
    ("vis_enemy_004",  # ww1_inf_cavalry 骑兵斥候：骑兵卡宾枪/马刀
     STRICT_PREFIX + (
         "一战德军骑兵斥候，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
         "科幻硬表面军事单位设定图，单名骑兵骑乘战马呈准备攻击预备姿态："
         "马头必须指向画面左侧，战马昂首前蹄蓄势未跃，骑兵身体前倾、"
         "骑兵卡宾枪举至肩线瞄准画面左侧，腰间马刀入鞘，"
         "煤灰色骑兵军装、尖顶钢盔与骑兵靴轮廓清晰，皮革马具结构明确，金属磨损旧化，"
         "低饱和军灰主色，局部蓝色能量指示微光，"
         "干净棚拍纯白背景，无地面无场景无杂物，高清。" + READY + NEGATIVE
     )),
    ("vis_enemy_005",  # ww1_sup_engineer 工兵班：步枪/爆破装药（单人化）
     STRICT_PREFIX + (
         "一战德军野战工兵，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
         "科幻硬表面军事单位设定图，单名工兵持毛瑟步枪呈准备攻击预备姿态："
         "士兵必须面向画面左侧，端枪至肩线瞄准画面左侧，手指搭扳机，"
         "腰间挂工兵铲与爆破装药包、背工具卷筒，"
         "煤灰色工兵军装与尖顶钢盔轮廓清晰，帆布装备带结构明确，金属磨损旧化，"
         "低饱和军灰主色，局部蓝色能量指示微光，"
         "干净棚拍纯白背景，无地面无场景无杂物，高清。" + READY + NEGATIVE
     )),
    ("vis_enemy_024",  # fut_inf_scout_mech 侦察机甲：粒子束步枪
     STRICT_PREFIX + (
         "近未来侦察机甲，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
         "科幻硬表面军事单位设定图，单台轻型双足侦察机甲呈准备攻击预备姿态："
         "机甲必须面向画面左侧，粒子束步枪举至肩线瞄准画面左侧，"
         "枪口聚能环蓝色充能光待发，头部传感器阵列与桅杆式观瞄镜亮起蓝点，"
         "细长双足腿部与背部天线轮廓清晰，模块化装甲结构明确，"
         "低饱和军灰绿主色，局部蓝色能量节点发光，"
         "干净棚拍纯白背景，无地面无场景无杂物，高清。" + READY + NEGATIVE
     )),
    ("vis_enemy_032",  # fut_inf_storm_rider 暴风骑士：磁轨狙击炮
     STRICT_PREFIX + (
         "近未来暴风骑士，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
         "科幻硬表面军事单位设定图，单名穿动力装甲的骑士骑乘反重力悬浮摩托"
         "呈准备攻击预备姿态：悬浮摩托车头必须指向画面左侧、低空悬浮姿态，"
         "骑士端磁轨狙击炮瞄准画面左侧，双导轨间蓝色电磁光弧充能待发，"
         "流线型装甲车身与底部推进器轮廓清晰，骑士动力装甲外露液压关节结构明确，"
         "低饱和深灰主色，局部蓝色能量导管发光，"
         "干净棚拍纯白背景，无地面无场景无杂物，高清。" + READY + NEGATIVE
     )),
    ("vis_enemy_034",  # fut_air_regen_frame 再生骨架：激光炮
     STRICT_PREFIX + (
         "近未来再生骨架飞行单元，严格2D正侧视（只能看到侧面轮廓，看不到正面），"
         "正交投影，游戏单位立绘/精灵图姿态，科幻硬表面空中单位设定图，"
         "单具外露骨架结构的无人飞行单元呈准备攻击预备姿态："
         "机体必须指向画面左侧，机首激光炮聚能充能蓝白光待发，"
         "肋骨状再生框架与关节节点轮廓清晰，受损断口处绿色再生组织微光结构明确，"
         "低饱和钛银灰主色，局部绿色再生光点与蓝色能量节点发光，"
         "干净棚拍纯白背景，无地面无场景无杂物，高清。" + READY + NEGATIVE
     )),
    ("vis_enemy_036",  # ww1_inf_mp18 步兵班·MP18：冲锋枪（单人，立姿瞄准）
     STRICT_PREFIX + (
         "一战德军步兵，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
         "科幻硬表面军事单位设定图，单名士兵持伯格曼MP18冲锋枪呈准备攻击预备姿态："
         "士兵必须面向画面左侧，立姿端枪至肩线瞄准画面左侧，手指搭扳机，"
         "原野灰标准军装、尖顶钢盔与弹药挎包轮廓清晰，皮革装备带结构明确，"
         "低饱和原野灰主色，局部蓝色能量指示微光，"
         "干净棚拍纯白背景，无地面无场景无杂物，高清。" + READY + NEGATIVE
     )),
    ("vis_enemy_037",  # ww1_inf_rifle 步兵班·步枪：跪姿据枪
     STRICT_PREFIX + (
         "一战德军步枪兵，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
         "科幻硬表面军事单位设定图，单名士兵持毛瑟Gew98步枪呈准备攻击预备姿态："
         "士兵必须面向画面左侧，单膝跪地据枪、步枪端稳瞄准画面左侧，"
         "原野灰军装、尖顶钢盔与背部行军背包轮廓清晰，皮革弹匣袋结构明确，"
         "低饱和原野灰主色，局部蓝色能量指示微光，"
         "干净棚拍纯白背景，无地面无场景无杂物，高清。" + READY + NEGATIVE
     )),
    ("vis_enemy_040",  # ww1_inf_storm_e 暴风突击队·精锐：冲锋枪（前倾压步）
     STRICT_PREFIX + (
         "一战德军暴风突击队精锐，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
         "科幻硬表面军事单位设定图，单名突击兵持伯格曼MP18冲锋枪呈准备攻击预备姿态："
         "士兵必须面向画面左侧，身体前倾压步冲锋预备、冲锋枪举至胸口高度"
         "指向画面左侧，手指搭扳机，"
         "加强型钢盔、突击胸甲与手榴弹袋轮廓清晰，防毒面具罐结构明确，"
         "低饱和深军灰主色，局部蓝色能量指示微光，"
         "干净棚拍纯白背景，无地面无场景无杂物，高清。" + READY + NEGATIVE
     )),
    ("vis_enemy_114",  # guardian_future_omega 终焉守护者·近未来：终焉粒子主炮
     STRICT_PREFIX + (
         "近未来终焉守护者巨型决战机甲，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
         "科幻硬表面重型军事单位设定图，单台大型人形决战机甲呈准备攻击预备姿态："
         "机甲必须面向画面左侧，右臂终焉粒子主炮抬起蓄能、炮口聚积炽白蓝色粒子光待发，"
         "肩部导弹发射舱舱门开启露出弹体待发，厚重复合装甲板与外露散热结构轮廓清晰，"
         "胸部能量核心结构明确，"
         "低饱和深灰黑主色，局部蓝紫色能量核心与导管发光，"
         "干净棚拍纯白背景，无地面无场景无杂物，高清。" + READY + NEGATIVE
     )),
    ("ww1_inf_enfield",  # 李-恩菲尔德志愿兵排：步枪
     STRICT_PREFIX + (
         "一战英军志愿兵，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
         "科幻硬表面军事单位设定图，单名士兵持李-恩菲尔德步枪呈准备攻击预备姿态："
         "士兵必须面向画面左侧，立姿端枪至肩线瞄准画面左侧，手指搭扳机，"
         "土黄色英军军装、宽檐帽与织物弹药腰带轮廓清晰，皮质装备结构明确，"
         "低饱和卡其主色，局部蓝色能量指示微光，"
         "干净棚拍纯白背景，无地面无场景无杂物，高清。" + READY + NEGATIVE
     )),
    ("ww1_inf_mp18_x",  # MP18 突击队：冲锋枪（行进间举枪）
     STRICT_PREFIX + (
         "一战德军MP18突击队兵，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
         "科幻硬表面军事单位设定图，单名突击兵持伯格曼MP18冲锋枪呈准备攻击预备姿态："
         "士兵必须面向画面左侧，大步推进中举枪至腰肩之间指向画面左侧，"
         "身体前倾蓄势，背部突击背包与鼓形弹匣袋轮廓清晰，绑腿与短靴结构明确，"
         "低饱和原野灰主色，局部蓝色能量指示微光，"
         "干净棚拍纯白背景，无地面无场景无杂物，高清。" + READY + NEGATIVE
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
    only = set(sys.argv[1:])
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    todo = [(cid, p) for cid, p in CARDS if not only or cid in only]
    total = len(todo)
    success = failed = 0
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
    print(f"Results: {success} generated, {failed} failed")

if __name__ == "__main__":
    main()
