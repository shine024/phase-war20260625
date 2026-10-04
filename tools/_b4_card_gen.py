# -*- coding: utf-8 -*-
"""B4 生图批：plat 24 补卡图 + 5 张参考重绘 + 3 案派生制卡。暂存审阅制——只落
.godot/b4_card_staging/，绝不写 assets/，用户审阅通过后才 deploy。

- plat 24：agnes 文生图，STYLE_BIBLE §6.1 十段拼装（白底/朝右/厚涂/冷调/负面白名单）
- regen 5（stryker_e/prism/rolls/mp18_x/phantom）：参考卡图 img2img 重绘（正侧面/全身修正）
- derive 3（mlrs_e/air_drone/delta_e）：家族卡直拷或 sheet f0 上采样（dark_templar 特案先例）
- 白底 lit_gate：非剪影、受光、本体像素量门；失败带强化光照后缀重试一次
"""
import base64, io, json, os, subprocess, sys, time
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEYS = [k for k in __import__("re").findall(r"sk-[A-Za-z0-9]{20,}",
        open(os.path.join(ROOT, "tools", "_agnes_image_api.md"), encoding="utf-8").read())]
API = "https://apihub.agnes-ai.cn/v1/images/generations"
STAGE = os.path.join(ROOT, ".godot", "b4_card_staging")
os.makedirs(STAGE, exist_ok=True)
MODEL = "agnes-image-2.5-flash"

# ---------- §6.1 十段拼装（plat 24 文生图） ----------
NEG = "text, perspective view, frame, ground, ceiling"
BASE = ("overcast diffused lighting, {rim}, muted cold palette of deep blue-grey steel and cold grey, "
        "thick painterly stylized game card illustration, clean painterly silhouettes defined by value "
        "contrast and a narrow rim light, smooth blended brushwork, hard-edge steel surfaces, "
        "the unit is evenly lit and clearly readable with medium-bright overall value, bright highlights "
        "and rich painted material detail, never a dark silhouette, "
        "clean pure white background with NO ground")
RIM = {"hist": "one narrow cool sky-blue rim light along the back edge",
       "sci": "one narrow cyan rim light along the back edge, faint glow limited to emissive parts",
       "xeno": "one narrow faint violet rim light along the back edge"}
COMP = {"hist": "single military unit or vehicle, full body, eye-level side view, facing right, "
                "historically accurate equipment detail, unit fills about three quarters of the frame with even white margins",
        "sci": "single hard-surface sci-fi unit or vehicle, full body, eye-level side view, facing right, "
               "sleek angular panel lines, unit fills about three quarters of the frame with even white margins",
        "xeno": "single alien creature, full body, eye-level side view, facing right, "
                "unit fills about three quarters of the frame with even white margins"}
TIER = {"basic": "standard-issue equipment, clean functional look",
        "advanced": "upgraded with additional armor plating, reinforced joints and a second weapon mount",
        "expert": "elite refit with a glowing energy core, ornate trim lines and master-crafted finish"}

FAM = {
    "flame_raider":  ("hist", "焰袭者喷火突击兵：现代消防级防火装具——连体隔热防火服、全罩防火面罩与背负式燃料罐组，双手持紧凑型喷火器，引焰口一点小橙色光",
                      "plus one small warm ember-orange glow from the flamethrower pilot flame, "),
    "flame_siege":   ("hist", "焰攻城投射器：固定炮位工事中的重型喷燃抛射炮，炮身安装在座钣与支架上，带防盾，炮管中等仰角，喷口一点小橙色光；无履带无车轮，不是坦克不是车辆",
                      "plus one small warm ember-orange glow from the emitter nozzle, "),
    "steel_fortress": ("hist", "钢铁堡垒要塞建筑：巨型固定防御工事建筑，嵌入式炮台与多层装甲板结构，矗立在地基上的堡垒；绝对不是坦克、没有履带、没有车轮、不能行驶", ""),
    "steel_titan":   ("hist", "钢铁泰坦重型战车：旋转炮塔与长主炮管的重型坦克，多层装甲与宽履带", ""),
    "thunter_striker": ("sci", "雷击者突击兵：现代模块化单兵装具——战术背心外挂电池组与绝缘护具、全罩战术头盔与护目镜，手持特斯拉长枪卡宾，枪身带电弧光与外露电缆",
                      ""),
    "thunter_sniper": ("sci", "雷狙击手：现代远程狙击手装具——战术头盔、观测镜组与伪装布罩，身披绝缘斗篷，持长程精确步枪，高倍光学镜", ""),
    "void_stealth":  ("xeno", "虚空潜行者：异形生物甲壳外骨骼——棱角暗色哑光甲壳如昆虫骨板，甲壳缝隙透出微光，持弯刃，半披风轻盈身形", ""),
    "void_mage":     ("xeno", "虚空法师：层叠法袍，悬浮符印环，双手间凝聚紫色能量", ""),
}
TIER_CN = {"basic": "标准制式装备，干净利落的量产感",
           "advanced": "升级型：附加装甲板、加固关节与第二武器挂架",
           "expert": "精英改装型：发光能量核心、饰线与大师级工艺"}
PLAT = ["%s_%s" % (f, t) for f in FAM for t in ("basic", "advanced", "expert")]

PLAT_PROMPT = ("游戏卡图立绘：{subject}，{tier}。"
               "严格2D正侧视，正交投影，面朝画面正右方，绝不朝左；"
               "{axis}{pose}"
               "完整全身居中入镜，四周留约百分之十白色边距，主体任何部分不得触碰画布四边，脚部完整落在画面内。"
               "{accent}低饱和冷灰蓝钢色调（deep blue-grey steel and cold grey），主体受光充足、照明均匀，"
               "高光与暗部层次分明，材质细节清晰可读，绝不允许画成黑色剪影或单色深色轮廓块；"
               "厚涂插画风格（thick painterly illustration），形体由色块与明暗交界塑造，"
               "笔触平滑融合（smooth blended painterly brushwork, rendered color masses）；"
               "干净棚拍纯白背景，无地面无场景无杂物无投影；"
               "【单一主体·硬性】画面中只允许出现这一个主体本身，严禁出现第二辆载具、第二个人物、"
               "背景车辆、背景坦克、背景战友、远景装甲单位或任何背景道具；背景是摄影棚白底，不是战场；"
               "画面中没有文字、水印、边框、旗帜徽标字母；"
               "严禁大面积高饱和绿、大面积正红、粉、品红、俯视、斜视角、3/4视角、画面裁切、透视缩短。"
               "text, perspective view, frame, ground, ceiling, foreshortening")

# 轴控制四件套（中文版，源自 docs/单位分帧动画生成管线.md 三批节 orthographic 硬锁句式）：
# 视点句+主轴句+重叠句+禁深度句。重叠句按家族取"侧视所见几何"，最灵。
AXIS = {
    "steel_titan":   "车体沿水平轴线横贯画面：两条履带在正侧视中完全重叠为一条连续履带线，负重轮只露一排；"
                     "完全看不到车头正面与车尾正面，无任何透视缩短；",
    "flame_siege":   "炮身与支架沿水平轴线横贯画面：防盾呈正侧剖面，完全看不到炮口正对镜头的形状；"
                     "无任何透视缩短；",
    "steel_fortress": "堡垒立面沿水平轴线展开，炮台朝画面正右方：完全看不到建筑正面与背面的进深，"
                      "无任何透视缩短；",
    "flame_raider":  "只见单侧脸颊与单侧肩膀，远侧手臂被躯干遮挡，枪口与鼻尖同指画面正右方；无任何透视缩短；",
    "thunter_striker": "只见单侧脸颊与单侧肩膀，远侧手臂被躯干遮挡，长枪枪口与鼻尖同指画面正右方；无任何透视缩短；",
    "thunter_sniper": "只见单侧脸颊与单侧肩膀，远侧手臂被躯干遮挡，步枪枪口与鼻尖同指画面正右方；无任何透视缩短；",
    "void_stealth":  "只见单侧脸颊轮廓，远侧手臂被躯干遮挡，弯刃与鼻尖同指画面正右方；无任何透视缩短；",
    "void_mage":     "只见单侧脸颊轮廓，悬浮符印环呈正侧扁椭圆，法球与鼻尖同指画面正右方；无任何透视缩短；",
}
# 步兵持枪姿（10-02 铁规：举至肩瞄准/准备射击；持枪下垂或竖持=返工，"calm ready stance"类措辞禁用）
POSE = {
    "flame_raider":    "双手持喷火器平举至肩，火舌口朝画面正右方，做喷射准备姿；",
    "thunter_striker": "双手持特斯拉长枪举至肩，枪托抵肩瞄准，做射击准备姿；",
    "thunter_sniper":  "双手持长程步枪举至肩，枪托抵肩、经由光学镜瞄准，做狙击瞄准姿；",
    "void_stealth":    "弯刃前指，做突进准备姿；",
}


def plat_prompt(pid):
    fam, _, tier = pid.rpartition("_")
    std, subject, warm = FAM[fam]
    accent = {"flame_raider": "焰系单位整体涂装中带一处小的暖橙光点缀；",
              "flame_siege": "焰系单位整体涂装中带一处小的暖橙光点缀；"}.get(fam, "")
    return PLAT_PROMPT.format(subject=subject, tier=TIER_CN[tier], accent=accent,
                              axis=AXIS.get(fam, ""), pose=POSE.get(fam, ""))


# ---------- 参考重绘（regen 5，img2img） ----------
CONVERT = ("第一张图是参考卡图。把它重画成一张新的游戏卡图立绘：{subject}。\n"
           "【视角·硬性】纯侧面视角（正侧视图），面朝画面正右方，绝不朝左，绝不允许俯视、斜视或 3/4 视角。\n"
           "【构图·硬性】单主体居中，全身完整，四周留出约百分之十白色边距，主体任何部分不得触碰画布四边，脚部完整落在画面内不裁切。\n"
           "【组成·硬性】部件组成与参考卡图完全一致，不新增、不删除、不简化任何部件。\n"
           "【视轴·硬性】视点在主体正侧方：主体轴线水平横贯画面，只见单侧一面（步兵只见单侧脸颊与单侧肩膀，"
           "远侧手臂被躯干遮挡）；完全看不到正面或背面，无任何透视缩短；轮式或履带类两侧车轮/履带"
           "在正侧视中重叠为单排一条连续线。\n"
           "【单一主体·硬性】画面中只允许有参考图中这一个主体本身；严禁添加背景车辆、背景坦克、"
           "第二个人物、战友或任何背景道具；背景是摄影棚纯白，不是战场。\n"
           "【配色·硬性】低饱和冷灰蓝钢色基调（deep blue-grey steel and cold grey），主体完全受光、照明充足，"
           "高光与暗部层次分明，材质细节清晰可读；{accent}严禁大面积高饱和绿、大面积正红、粉、品红；"
           "严禁画成黑色剪影，严禁逆光或暗场照明，严禁单色深色轮廓块。\n"
           "【风格·硬性】厚涂插画（thick painterly illustration），笔触平滑过渡，硬边钢面，"
           "形体由色块与明暗交界塑造（painted color masses with soft blended transitions）；"
           "干净棚拍纯白背景，无地面无场景无杂物无投影。\n"
           "画面中没有文字、水印、边框、旗帜徽标字母。")
REGEN = {
    "mod_arm_stryker_e": ("res://assets/card_icons/player/vis_player_059.png",
                          "现代八轮装甲运兵车（斯崔克型），方正车体、全侧面对正镜头，顶部武器站", ""),
    "fut_arm_prism":     ("res://assets/card_icons/player/vis_player_026.png",
                          "近未来棱镜主战坦克，棱角装甲、长炮管与镜塔光窗", ""),
    "ww1_arm_rolls":     (None,
                          "一战劳斯莱斯装甲车：修长方形引擎盖与竖条散热格栅，四个辐条充气车轮（是轮式车辆，"
                          "绝对没有履带），车体后部上置球形旋转炮塔与细炮管；一战英国军绿色涂装偏冷灰化", ""),
    "ww1_inf_mp18_x":    ("res://assets/card_icons/player/ww1_inf_enfield.png",
                          "一战风暴步兵（同参考图风格与时代）：钢盔、军大衣、绑腿长靴，"
                          "双手持MP18冲锋枪举至肩瞄准；参考图换成MP18冲锋枪，其余身份保持", ""),
    "fe_helix_phantom":  ("res://assets/card_icons/player/fe_helix_phantom.png",
                          "近未来相位幻影步兵：贴身轻量相位织物战衣与兜帽（柔软织物质感），"
                          "轻量化护甲片缀于肩胸，能量刃收于腰侧", ""),
    "mod_inf_scout_drone": ("res://assets/card_icons/player/vis_player_022.png",
                            "现代四旋翼侦察无人机，薄型机身、云台相机与天线，正侧面平飞姿态", ""),
}
# REGEN 里 ref=None 的文生图案：各自的轴控/持枪姿补充段
REGEN_T2I_EXTRA = {
    "ww1_arm_rolls": "四个辐条车轮在正侧视中重叠为一排单列车轮（one single row of wheels seen in profile）；"
                     "完全看不到车头正面与车尾正面，无任何透视缩短；",
}


# ---------- API ----------
def gen(payload, tag):
    pp = os.path.join(STAGE, "_payload.json")
    with open(pp, "w", encoding="utf-8") as f:
        f.write(json.dumps(payload))
    for i in range(3):
        r = subprocess.run(["curl", "--http1.1", "-s", "-X", "POST", API,
                            "-H", "Authorization: Bearer " + KEYS[i % len(KEYS)],
                            "-H", "Content-Type: application/json",
                            "--data-binary", "@" + pp, "--max-time", "360"],
                           capture_output=True, text=True, timeout=380)
        try:
            d = json.loads(r.stdout)
        except Exception:
            print("  [%s] 响应非 JSON: %s" % (tag, r.stdout[:100]), flush=True)
            time.sleep(12)
            continue
        if d.get("error") or d.get("code"):
            print("  [%s] API错: %s" % (tag, json.dumps(d, ensure_ascii=False)[:160]), flush=True)
            time.sleep(12)
            continue
        item = (d.get("data") or [{}])[0]
        if item.get("b64_json"):
            return base64.b64decode(item["b64_json"])
        if item.get("url"):
            dl = subprocess.run(["curl", "--http1.1", "-s", "-L", item["url"], "--max-time", "120"],
                                capture_output=True, timeout=140)
            try:
                Image.open(io.BytesIO(dl.stdout)).load()
                return dl.stdout
            except Exception:
                pass
    return None


def uri_of(path):
    with open(path, "rb") as f:
        return "data:image/png;base64," + base64.b64encode(f.read()).decode()


def lit_gate_white(im):
    """白底卡图亮度门：底要白、本体要受光不剪影、本体量要足。"""
    import numpy as np
    a = np.asarray(im.convert("RGB")).astype(int)
    h, w, _ = a.shape
    border = np.concatenate([a[:3].reshape(-1, 3), a[-3:].reshape(-1, 3),
                             a[:, :3].reshape(-1, 3), a[:, -3:].reshape(-1, 3)])
    bg = np.median(border, axis=0)
    bg_ok = bool(bg.min() >= 225)
    dist = np.sqrt(((a - bg) ** 2).sum(axis=2))
    body = dist > 100
    n = int(body.sum())
    if n < 4000:
        return False, {"bg": [round(float(v)) for v in bg], "body_px": n, "verdict": "empty"}
    rgb = a[body]
    mean = float(rgb.mean())
    lit = float((rgb.max(axis=1) > 100).mean())
    ok = bg_ok and mean >= 80 and lit >= 0.35
    return ok, {"bg": [round(float(v)) for v in bg], "body_px": n,
                "mean": round(mean, 1), "lit": round(lit, 2),
                "verdict": "pass" if ok else "dark"}


def run_case(cid, prompt, ref_path=None):
    out = os.path.join(STAGE, "%s_raw.png" % cid)
    if os.path.isfile(out) and os.path.getsize(out) > 10000:
        print("[skip] %s 已有" % cid, flush=True)
        return
    extra = {"response_format": "b64_json"}
    if ref_path and os.path.isfile(ref_path):
        extra["image"] = [uri_of(ref_path)]
    payload = {"model": MODEL, "prompt": prompt, "size": "1024x1024",
               "extra_body": extra}
    t0 = time.time()
    raw = gen(payload, cid)
    if not raw:
        print("[FAIL] %s 三次无果" % cid, flush=True)
        return
    im = Image.open(io.BytesIO(raw)).convert("RGB")
    ok, info = lit_gate_white(im)
    if not ok and info.get("verdict") == "dark":
        p2 = prompt + "。主体必须完全受光、亮度充足，绝不允许暗色剪影。"
        raw2 = gen(dict(payload, prompt=p2), cid + "-r")
        if raw2:
            im2 = Image.open(io.BytesIO(raw2)).convert("RGB")
            ok2, info2 = lit_gate_white(im2)
            if ok2:
                im, ok, info = im2, ok2, info2
    im.save(out)
    print("[%s] %s %.0fs %s" % ("OK" if ok else "DARK", cid, time.time() - t0,
                                json.dumps(info, ensure_ascii=False)), flush=True)


# ---------- 派生 3 案（无 AI） ----------
def run_derive():
    import shutil
    outs = []
    # mlrs_e：家族卡直拷（m270 sheet 源自 vis_player_021）
    outs.append(("res://assets/card_icons/player/vis_player_021.png", "vis_player_060.png", False))
    outs.append(("res://assets/card_icons/enemy/vis_enemy_021.png", "vis_enemy_060.png", False))
    # fut_air_drone：attack_drone 专属卡（enemy 侧无现成→player 版翻转）
    outs.append(("res://assets/card_icons/player/fut_attack_drone.png", "vis_player_065.png", False))
    outs.append(("res://assets/card_icons/player/fut_attack_drone.png", "vis_enemy_065.png", True))
    # delta_e：与 mod_ranger 共用 061，需按 sheet f0 上采样重制（dark_templar 先例）
    for src, dst, flip in outs:
        s = os.path.join(ROOT, src.replace("res://", ""))
        im = Image.open(s).convert("RGBA")
        if flip:
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
        im.save(os.path.join(STAGE, dst))
        print("[derive] %s <- %s%s" % (dst, os.path.basename(src), " (flip)" if flip else ""), flush=True)
    sh = Image.open(os.path.join(ROOT, "assets/effects/unit_anims/mod_ranger/sheet_idle.png"))
    f0 = sh.crop((0, 0, 256, 256)).resize((512, 512), Image.LANCZOS)
    f0.save(os.path.join(STAGE, "vis_player_061.png"))
    f0.transpose(Image.FLIP_LEFT_RIGHT).save(os.path.join(STAGE, "vis_enemy_061.png"))
    print("[derive] vis_player_061/vis_enemy_061 <- mod_ranger f0 上采样", flush=True)


def main():
    only = sys.argv[1] if len(sys.argv) > 1 else None
    run_derive()
    cases = []
    for pid in PLAT:
        cases.append((pid, plat_prompt(pid), None))
    for cid, (ref, subject, accent) in REGEN.items():
        if ref:
            cases.append((cid, CONVERT.format(subject=subject, accent=accent), ref.replace("res://", "")))
        else:
            cases.append((cid, PLAT_PROMPT.format(
                subject=subject, tier="标准制式装备，干净利落的量产感", accent="",
                axis=REGEN_T2I_EXTRA.get(cid, ""), pose=""), None))
    for cid, prompt, ref in cases:
        if only and only not in cid:
            continue
        run_case(cid, prompt, ref)
    print("B4 生成轮完成 → %s" % STAGE, flush=True)


if __name__ == "__main__":
    main()
