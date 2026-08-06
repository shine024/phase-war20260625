#!/usr/bin/env python3
"""生成 21 张缺失改造模块图标（v9.1 组合技套路配套改造）。
调用 agnes-image-2.0-flash API，输出到 docs/待生成改造图标_21张/ 供审核。
审核通过后用 deploy_mod_icons.py 部署到 assets/ui/icons/mod_icons/。

风格对齐现有 64 张改造图标（已分析）：
- 512x512 最终尺寸（API 出 1024x1024，部署脚本缩放）
- RGB 白底不透明（无 alpha，不做透明处理）
- 扁平化军事科技风 / 机械拟物图形 / 单主体居中 / 低饱和主色+局部能量发光
"""
import json
import os
import subprocess
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# 3 个 agnes-ai key 轮换（避免单 key 限流）。.cn 国内端点可达，.com 被网络阻断。
API_KEYS = [
    "sk-thpXTkWon9RiLMdnsZgqlQUH7XI6SdlhLYsx7eQToj7GtIPv",
    "sk-2mxCpSC8Nf0nm2TAf9fYHuRxNj7aeoIttPuuu9ivodbU3zXN",
    "sk-Pzu3QigNdQlVhFC7cVDVsTDwfvt3T6nIDq23HeJgaKMnRo6K",
]
_key_idx = 0  # 轮换指针
BASE_URL = "https://apihub.agnes-ai.cn/v1"
MODEL = "agnes-image-2.0-flash"
OUTPUT_DIR = os.path.join(ROOT, "docs", "待生成改造图标_21张")

# 改造图标专用前缀（区别于卡面图：图标是单部件俯视/正视、无需朝左）
# 关键约束：扁平图标、单主体居中、纯白背景、无文字水印、机械拟物
ICON_PREFIX = (
    "A clean flat 2D game UI icon, single mechanical component centered, "
    "absolutely NO perspective, NO three-quarter view, orthographic flat front view, "
    "pure solid white background (#FFFFFF) with NO ground, NO shadow, NO floor, "
    "NO reflection, NO watermark, NO signature, NO text, NO letters, NO numbers, "
    "NO logo, NO extra objects, NO environment, NO scene, "
    "studio isolated product shot style, crisp clean edges, "
    "military sci-fi hard-surface tech style. "
)
NEGATIVE = (
    "不要：透视、三分之四视角、斜侧视、背景场景、地面、投影、阴影、"
    "文字、字母、数字、水印、logo、人物、多主体、杂物、边框。"
)

# 21 张改造图标：文件名（不含.png）、显示名、prompt
# 按套路主题色统一：燃烧=橙红、电磁=蓝紫、纳米=青绿、光束=亮黄白、侦察=灰蓝、化学=黄绿
ICONS = [
    # ========== 套路1 助燃燃烧链（橙红主题，4 张） ==========
    {
        "fname": "mod_thermolite",
        "display": "温压弹（云爆弹战斗部）",
        "prompt": ICON_PREFIX + (
            "一枚航空云爆弹/温压弹战斗部，扁平游戏图标，以【燃烧·橙红】温压弹为主体，"
            "完整弹体居中入镜，圆柱形弹身、钝圆形燃料空气战斗部与尾翼稳定器轮廓清晰，"
            "弹体表面的二次引爆引信与云爆剂扩散环结构明确，金属质感，"
            "低饱和暗灰金属主色，弹头局部橙红色炽热燃烧核心发光，干净纯白背景，无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "fname": "mod_ammo_incendiary",
        "display": "助燃剂弹（镁粉混合弹药）",
        "prompt": ICON_PREFIX + (
            "一枚助燃剂/镁粉混合燃烧弹药，扁平游戏图标，以【燃烧·橙红】助燃剂弹为主体，"
            "完整炮弹居中入镜，锥形弹头、透明观察窗内可见镁粉颗粒与圆柱弹体轮廓清晰，"
            "弹底助燃剂释放孔与延时引信结构明确，金属质感，"
            "低饱和军绿金属主色，弹头窗口内橙红色镁粉灼热发光，干净纯白背景，无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "fname": "mod_ammo_phosphorus",
        "display": "白磷弹（M825白磷发烟弹）",
        "prompt": ICON_PREFIX + (
            "一枚白磷发烟炮弹，扁平游戏图标，以【燃烧·橙红】白磷弹为主体，"
            "完整炮弹居中入镜，圆柱形弹体、弹体侧面白色磷化物填充标识与尾部延时引信轮廓清晰，"
            "弹顶的弹头释放阀与弹身刻槽结构明确，金属质感，"
            "低饱和灰白金属主色，弹体局部橙黄色白磷燃烧烟雾发光，干净纯白背景，无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "fname": "mod_combustion_catalyst",
        "display": "燃烧催化剂（化学催化涂层）",
        "prompt": ICON_PREFIX + (
            "一个化学催化涂层反应舱装置，扁平游戏图标，以【燃烧·橙红】燃烧催化剂为主体，"
            "完整装置居中入镜，圆筒形催化反应舱、舱内螺旋催化涂层与顶部注入阀轮廓清晰，"
            "舱壁的反应温控管与底部输出接口结构明确，金属质感，"
            "低饱和暗灰金属主色，舱内橙红色催化燃烧反应核心发光，干净纯白背景，无场景无杂物，高清。" + NEGATIVE
        ),
    },

    # ========== 套路2 电磁脉冲链（蓝紫电弧主题，4 张；mod_electronic 改路径走 electronics） ==========
    {
        "fname": "mod_emp_warhead",
        "display": "电磁战斗部（微波战斗部）",
        "prompt": ICON_PREFIX + (
            "一枚电磁脉冲/微波战斗部，扁平游戏图标，以【电磁·蓝紫】电磁战斗部为主体，"
            "完整战斗部居中入镜，圆锥形微波发生器天线阵列、金属弹体外壳与尾部电源舱轮廓清晰，"
            "内部的环形磁通压缩线圈与前端相位发射器结构明确，金属质感，"
            "低饱和暗灰金属主色，前端蓝紫色电磁脉冲电弧与线圈环绕发光，干净纯白背景，无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "fname": "mod_antiradiation",
        "display": "反辐射导弹（AGM-88 HARM）",
        "prompt": ICON_PREFIX + (
            "一枚反辐射导弹，扁平游戏图标，以【电磁·蓝紫】反辐射导弹为主体，"
            "完整导弹居中入镜，细长流线型弹体、尖锥形被动雷达导引头与十字形尾翼轮廓清晰，"
            "弹体中部的固定弹翼与尾部固体火箭喷口结构明确，金属质感，"
            "低饱和灰白金属主色，导引头前端蓝紫色电磁寻波传感阵列发光，干净纯白背景，无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "fname": "mod_ammo_graphite",
        "display": "石墨纤维弹（石墨纤维战斗部）",
        "prompt": ICON_PREFIX + (
            "一枚石墨纤维战斗部，扁平游戏图标，以【电磁·蓝紫】石墨纤维弹为主体，"
            "完整战斗部居中入镜，圆柱形弹体、弹体剖开处可见密集石墨碳纤维线团与撒布器轮廓清晰，"
            "前端引爆引信与尾部抛撒机构结构明确，金属质感，"
            "低饱和深灰金属主色，碳纤维线团散发蓝紫色导电电弧微光发光，干净纯白背景，无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "fname": "mod_overload",
        "display": "过载电容（储能电容阵列）",
        "prompt": ICON_PREFIX + (
            "一个储能过载电容阵列装置，扁平游戏图标，以【电磁·蓝紫】过载电容为主体，"
            "完整装置居中入镜，方形金属外壳内排列的圆柱超级电容阵列、顶部高压接线柱与底部散热鳍片轮廓清晰，"
            "外壳的电压表与泄压阀结构明确，金属质感，"
            "低饱和暗灰金属主色，电容间隙与接线柱强烈蓝紫色过载电弧环绕发光，干净纯白背景，无场景无杂物，高清。" + NEGATIVE
        ),
    },

    # ========== 套路3 纳米浓度场（科技青绿主题，3 张） ==========
    {
        "fname": "mod_nano_amp",
        "display": "纳米放大器（纳米谐振弹头）",
        "prompt": ICON_PREFIX + (
            "一个纳米谐振放大器装置，扁平游戏图标，以【纳米·青绿】纳米放大器为主体，"
            "完整装置居中入镜，球面谐振腔、腔内悬浮的纳米颗粒云与外环谐振线圈轮廓清晰，"
            "顶部的能量聚焦透镜与底部基座结构明确，金属质感，"
            "低饱和暗灰金属主色，谐振腔内青绿色纳米粒子云旋涡发光，干净纯白背景，无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "fname": "mod_nano_seeder",
        "display": "纳米播种机（纳米粒子播撒装置）",
        "prompt": ICON_PREFIX + (
            "一个纳米粒子播撒器装置，扁平游戏图标，以【纳米·青绿】纳米播种机为主体，"
            "完整装置居中入镜，圆筒形粒子储存罐、顶部多向喷撒喷嘴与底部压缩泵轮廓清晰，"
            "罐体的观察窗内纳米粉尘与侧面浓度调节阀结构明确，金属质感，"
            "低饱和暗灰金属主色，喷嘴与观察窗青绿色纳米粒子喷雾流发光，干净纯白背景，无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "fname": "mod_nano_catalyst",
        "display": "纳米催化剂（自复制纳米颗粒）",
        "prompt": ICON_PREFIX + (
            "一个自复制纳米催化剂反应核心装置，扁平游戏图标，以【纳米·青绿】纳米催化剂为主体，"
            "完整装置居中入镜，中央六边形自复制反应核心、外环分子链增殖轨道与底部基质注入管轮廓清晰，"
            "核心周围的能量护盾环与顶部扩散孔结构明确，金属质感，"
            "低饱和暗灰金属主色，反应核心青绿色纳米自复制增殖光晕强烈发光，干净纯白背景，无场景无杂物，高清。" + NEGATIVE
        ),
    },

    # ========== 套路4 光束谐振链（亮黄白主题，4 张） ==========
    {
        "fname": "mod_targeting_laser",
        "display": "瞄准激光（机载激光指示吊舱）",
        "prompt": ICON_PREFIX + (
            "一个机载激光指示瞄准吊舱，扁平游戏图标，以【光束·亮黄】瞄准激光为主体，"
            "完整吊舱居中入镜，流线型长筒吊舱、前端球形光学透镜与尾部万向稳定万向节轮廓清晰，"
            "筒身的散热栅格与内部激光发生器结构明确，金属质感，"
            "低饱和暗灰金属主色，前端透镜亮黄白色高能激光瞄准光束发光，干净纯白背景，无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "fname": "mod_beam_splitter",
        "display": "光束分裂器（分光棱镜组件）",
        "prompt": ICON_PREFIX + (
            "一个光束分裂分光棱镜装置，扁平游戏图标，以【光束·亮黄】光束分裂器为主体，"
            "完整装置居中入镜，中央立方分光棱镜、棱镜外的入射光准直管与两侧出射聚光镜轮廓清晰，"
            "底座的精密调节旋钮与支架结构明确，金属质感，"
            "低饱和暗灰金属主色，棱镜内亮黄白色入射主光束分裂为多道次级光束发光，干净纯白背景，无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "fname": "mod_reflector",
        "display": "反射阵列（可调反射镜组）",
        "prompt": ICON_PREFIX + (
            "一个可调式光束反射镜组阵列装置，扁平游戏图标，以【光束·亮黄】反射阵列为主体，"
            "完整装置居中入镜，多面可调角度的方形反射镜、镜组背面的伺服调节臂与中央支柱轮廓清晰，"
            "镜面阵列的边框与底座旋转关节结构明确，金属质感，"
            "低饱和暗灰金属主色，镜面亮黄白色反射光束与边缘折射微光发光，干净纯白背景，无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "fname": "mod_optical_fiber",
        "display": "光纤链路（战场光纤通信网）",
        "prompt": ICON_PREFIX + (
            "一个战场光纤通信链路终端装置，扁平游戏图标，以【光束·亮黄】光纤链路为主体，"
            "完整装置居中入镜，方形通信终端盒、盒体一侧盘绕的发光光纤线圈与面板接口轮廓清晰，"
            "终端的信号指示灯与光纤接头结构明确，金属质感，"
            "低饱和暗灰金属主色，光纤线圈内亮黄白色光信号脉冲流转发光，干净纯白背景，无场景无杂物，高清。" + NEGATIVE
        ),
    },

    # ========== 套路5 侦察链式（灰蓝标记主题，2 张） ==========
    {
        "fname": "mod_targeting_drone",
        "display": "目标指示无人机（标定攻击无人机）",
        "prompt": ICON_PREFIX + (
            "一架微型标定攻击指示无人机，扁平游戏图标，以【侦察·灰蓝】目标指示无人机为主体，"
            "完整无人机居中入镜，四旋翼或固定翼机体、机腹下方球形光电/激光标定吊舱与顶部数据链天线轮廓清晰，"
            "机体的传感器阵列与起落架结构明确，金属质感，"
            "低饱和暗灰蓝主色，吊舱底部灰蓝色激光目标标定十字光斑发光，干净纯白背景，无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "fname": "mod_weakpoint",
        "display": "弱点分析仪（目标弱点推演模块）",
        "prompt": ICON_PREFIX + (
            "一个目标弱点推演分析仪模块，扁平游戏图标，以【侦察·灰蓝】弱点分析仪为主体，"
            "完整模块居中入镜，方形分析主机、面板上全息目标三维弱点扫描投影与侧面接口轮廓清晰，"
            "主机的运算核心与外接数据链结构明确，金属质感，"
            "低饱和暗灰蓝主色，全息投影灰蓝色目标弱点红框锁定标记发光，干净纯白背景，无场景无杂物，高清。" + NEGATIVE
        ),
    },

    # ========== 套路6 化学污染场（腐蚀黄绿主题，4 张） ==========
    {
        "fname": "mod_acid",
        "display": "酸液战斗部（腐蚀性酸战斗部）",
        "prompt": ICON_PREFIX + (
            "一枚腐蚀性酸液战斗部，扁平游戏图标，以【化学·黄绿】酸液战斗部为主体，"
            "完整战斗部居中入镜，圆柱形耐酸弹体、弹体内剖开处可见绿色酸液储罐与喷洒阀轮廓清晰，"
            "弹顶的撞击引信与弹身的腐蚀警示标识结构明确，金属质感，"
            "低饱和暗灰金属主色，酸液储罐与喷阀黄绿色腐蚀性酸液滴落与蒸气发光，干净纯白背景，无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "fname": "mod_ammo_chem",
        "display": "化学集束弹（M687化学子母弹）",
        "prompt": ICON_PREFIX + (
            "一枚化学集束子母弹，扁平游戏图标，以【化学·黄绿】化学集束弹为主体，"
            "完整炮弹居中入镜，圆柱形母弹弹体、弹体剖开处可见内含多枚小子弹与撒布机构轮廓清晰，"
            "母弹的定时抛撒引信与子弹化学战斗部结构明确，金属质感，"
            "低饱和暗灰金属主色，子弹散布处黄绿色化学毒剂云团扩散发光，干净纯白背景，无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "fname": "mod_chem_sprayer",
        "display": "化学喷洒器（车载化学喷洒系统）",
        "prompt": ICON_PREFIX + (
            "一个车载化学喷洒系统装置，扁平游戏图标，以【化学·黄绿】化学喷洒器为主体，"
            "完整装置居中入镜，圆柱形化学剂储罐、前端高压喷洒枪与顶部加注口轮廓清晰，"
            "罐体的压力泵与输药管结构明确，金属质感，"
            "低饱和暗灰金属主色，喷枪前端黄绿色化学毒剂高压喷雾锥形扩散发光，干净纯白背景，无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "fname": "mod_pollution",
        "display": "污染蓄能器（化学物质浓缩舱）",
        "prompt": ICON_PREFIX + (
            "一个化学物质污染浓缩蓄能舱装置，扁平游戏图标，以【化学·黄绿】污染蓄能器为主体，"
            "完整装置居中入镜，球形浓缩蓄能舱、舱内分层化学污染物与外环循环管路轮廓清晰，"
            "舱顶的浓度均衡阀与底部排出泵结构明确，金属质感，"
            "低饱和暗灰金属主色，舱内黄绿色化学污染物浓缩旋涡与蒸气发光，干净纯白背景，无场景无杂物，高清。" + NEGATIVE
        ),
    },
]


def _next_key():
    """轮换取下一个 API key。"""
    global _key_idx
    k = API_KEYS[_key_idx % len(API_KEYS)]
    _key_idx += 1
    return k


def generate_image(prompt: str, output_path: str) -> tuple:
    """调用 agnes-image-2.0-flash 生成图片。失败时轮换 key 重试。"""
    payload = json.dumps({
        "model": MODEL,
        "prompt": prompt,
        "size": "1024x1024",
        "n": 1,
    })
    tmpfile = output_path + ".payload.json"
    with open(tmpfile, "w") as f:
        f.write(payload)

    # 轮换尝试所有 key
    last_err = ""
    for attempt in range(len(API_KEYS)):
        key = _next_key()
        hdr = "Authorization: Bearer " + key
        resp_file = output_path + ".resp.json"
        cmd = [
            "curl", "--http1.1", "-s",
            "-X", "POST", BASE_URL + "/images/generations",
            "-H", hdr,
            "-H", "Content-Type: application/json",
            "--data-binary", "@" + tmpfile,
            "-o", resp_file,
            "--connect-timeout", "15",
            "--max-time", "180",
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=210)

        if result.returncode != 0:
            last_err = "curl exit " + str(result.returncode) + ": " + (result.stderr or "")[:150]
            continue

        if not os.path.exists(resp_file) or os.path.getsize(resp_file) < 10:
            last_err = "No response file"
            continue

        content = open(resp_file).read()
        try:
            os.unlink(resp_file)
        except OSError:
            pass

        try:
            data = json.loads(content)
        except json.JSONDecodeError:
            last_err = "Response not JSON: " + content[:150]
            continue

        if "data" not in data or len(data["data"]) == 0:
            err = data.get("error", {})
            last_err = err.get("message", str(data)[:150]) if isinstance(err, dict) else str(data)[:150]
            # 401/限流类错误才轮换 key，其他错误直接返回
            if "auth" in last_err.lower() or "401" in last_err or "rate" in last_err.lower() or "quota" in last_err.lower():
                continue
            return False, "No data: " + last_err

        url = data["data"][0].get("url", "")
        if not url:
            last_err = "No URL in response"
            continue

        # 生成调用成功，清理 payload，下载图片
        try:
            os.unlink(tmpfile)
        except OSError:
            pass
        dl_cmd = ["curl", "--http1.1", "-s", "-L", "-o", output_path, url,
                  "--connect-timeout", "15", "--max-time", "90"]
        subprocess.run(dl_cmd, capture_output=True, text=True, timeout=120)

        if os.path.exists(output_path) and os.path.getsize(output_path) > 1000:
            return True, "OK (" + str(os.path.getsize(output_path)) + " bytes)"
        last_err = "Download failed/too small"
        break  # 下载失败不轮换 key（已生成成功），直接返回

    try:
        os.unlink(tmpfile)
    except OSError:
        pass
    return False, last_err


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print("Output dir: " + OUTPUT_DIR)
    print("Generating " + str(len(ICONS)) + " mod icons...\n")

    results = []
    for i, icon in enumerate(ICONS):
        fname = icon["fname"] + ".png"
        fpath = os.path.join(OUTPUT_DIR, fname)
        print("[" + str(i + 1) + "/" + str(len(ICONS)) + "] " + icon["display"] + " -> " + fname)

        success, msg = generate_image(icon["prompt"], fpath)
        results.append((icon["fname"], icon["display"], fname, success, msg))

        if success:
            print("  OK: " + msg)
        else:
            print("  FAILED: " + msg + " — retrying once...")
            time.sleep(3)
            success2, msg2 = generate_image(icon["prompt"], fpath)
            results[-1] = (icon["fname"], icon["display"], fname, success2, msg2)
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
