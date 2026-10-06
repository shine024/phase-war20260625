# -*- coding: utf-8 -*-
"""fam43 卡重生成批 R3·4 张（2026-10-06 用户判定 (3).json）。

  ww2_air_dive_bomber  锚图就错了→卡图也错：移植 v26 已验收 Ju 87 配方（朝右版）
  mod_air_multirole    仍非侧视：移植 v26 已验收 F-15E 配方（朝右版）+ SIDE_RESCUE
  fe_helix_phantom     抬枪要强化：枪托抵肩/贴腮瞄准/枪口水平右指
  flame_raider_expert  平放出枪要强化：喷火管从炮塔笔直水平探出超出车体前缘

v26 配方源: tools/_gen_v26_air_cards.py（其 multirole/dive_bomber 卡图均过验收侧视）。
复用 fam43_cards_redo 的 gen/lit_gate/BASE_TAIL。只落 staging，绝不写 assets/。
用法: python tools/fam43_cards_redo3.py [key ...]
"""
import io
import json
import os
import sys
import types

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAGE = os.path.join(ROOT, ".godot", "unit_review", "fam43_cards_redo")


def load(name, path):
    """加载工具模块但剔除顶层 stdout 重包行（连环重包会互相关掉共享缓冲）。"""
    lines = [ln for ln in open(path, encoding="utf-8").read().split("\n")
             if "sys.stdout = io.TextIOWrapper" not in ln]
    mod = types.ModuleType(name)
    mod.__file__ = path
    exec(compile("\n".join(lines), path, "exec"), mod.__dict__)
    return mod


r1 = load("f43_redo1", os.path.join(ROOT, "tools", "fam43_cards_redo.py"))

# v26 已验收的英文正侧锁前缀（纯正向，无负面词段）
STRICT_PREFIX = (
    "STRICTLY a pure 2D side profile silhouette view, absolutely NO front view, "
    "NO three-quarter view, NO perspective depth, flat orthographic game sprite, "
    "single subject only centered, clean pure white background with NO ground, "
    "NO shadow, NO floor, NO reflection, NO watermark, NO signature, NO text, "
    "NO extra sketches, NO character faces visible, NO environment, "
    "studio isolated product shot style. "
)

UNITS = {
    "ww2_air_dive_bomber": dict(
        subject=("二战俯冲轰炸机（Ju 87 斯图卡），严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
                 "军事设定图，以【二战·俯冲轰炸机】倒鸥形机翼双座俯冲轰炸机为主体，机头朝向画面正右方，"
                 "完整机体居中入镜，倒鸥形弯曲机翼（inverted gull wings 翼根明显下折）、"
                 "固定主起落架流线整流罩（fixed spatted landing gear）与双座纵向全玻璃座舱轮廓清晰，"
                 "机腹挂载重型炸弹、发动机整流罩结构明确，深灰绿迷彩涂装，"
                 "低饱和军绿灰主色，干净棚拍纯白背景，无地面无场景无杂物，高清"),
        pose="水平直线平飞姿态，机首朝画面正右方，起落架放下状态。",
        axis=r1.AXIS_AIR, prefix=STRICT_PREFIX),
    "mod_air_multirole": dict(
        subject=("现代双发重型多用途战斗机（F-15E 攻击鹰），严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
                 "军事设定图，以【现代·多用途战机】双发重型战斗机为主体，机头朝向画面正右方，"
                 "完整机体居中入镜，楔形机身、双垂尾与翼下重型挂载（炸弹与导弹）轮廓清晰，"
                 "保形油箱与方形进气道结构明确，浅灰空优迷彩，"
                 "低饱和浅灰主色，局部挂架细节，干净棚拍纯白背景，无地面无场景无杂物，高清"),
        pose="水平直线平飞姿态，机首朝向画面正右方，起落架收起状态。",
        axis=r1.AXIS_AIR, prefix=STRICT_PREFIX),
    "fe_helix_phantom": dict(
        subject=("近未来相位幻影特工（phase phantom trooper）：紧身轻量相位纤维作战服与兜帽"
                 "（软质面料质感，微光织纹），肩部与胸前轻量装甲板，腰间能量刃鞘"),
        pose=("双手持一柄细长相位能量步枪（phase energy rifle，枪身带淡青能量纹路）"
              "举枪瞄准：枪托紧抵右肩（stock firmly against the shoulder）、面颊贴住枪托、"
              "一手握握把一手托护木，枪管完全水平、枪口高度与肩线齐平，枪口指向画面正右方。"),
        axis=r1.AXIS_INF, prefix=""),
    "flame_raider_expert": dict(
        subject=("烈焰专家级 BA-64 轻型突击车平台（BA-64 light armored car）：苏联 BA-64 四轮"
                 "轻型装甲车底盘，棱角焊接装甲板，开放式顶部小炮塔装一挺重型喷火器"
                 "（heavy flamethrower），车体侧后挂背负式燃油罐组"),
        pose=("炮塔转向正侧，喷火管从炮塔正面笔直水平伸出（straight rigid tube jutting "
              "horizontally out of the turret front），管身完全水平与地面平行，"
              "喷口明显超出车体前缘，指向画面正右方，喷口一点小橙色引焰光。"),
        axis=("视点在车体正侧方：车体主轴水平横贯画面，四轮侧视重叠成单列轮线，"
              "只见车体单侧面，不见车头正面与车尾正面；无任何透视缩短；"),
        prefix=""),
}
SIDE_RESCUE = ("。再次强调：这是一张正侧档案照式卡图（exact side-profile blueprint view），"
               "相机与机身中线完全等高，从正左侧拍摄；机首与机尾必须处于同一水平高度；"
               "两侧机翼侧视重叠成单一线条；绝对禁止 3/4 视角、斜视角、俯视角。")


def run_case(key):
    u = UNITS[key]
    out = os.path.join(STAGE, "%s_raw.png" % key)
    if os.path.isfile(out) and os.path.getsize(out) > 10000:
        print("[skip] %s 已有" % key, flush=True)
        return
    prompt = ("%s游戏卡图立绘：%s。严格2D正侧视，正交投影，面朝画面正右方，绝不朝左；%s%s%s"
              % (u["prefix"], u["subject"], u["axis"], u["pose"], r1.BASE_TAIL))
    if key == "mod_air_multirole":
        prompt += SIDE_RESCUE
    r1.gen.__globals__["print"] = print
    payload = {"model": r1.MODEL, "prompt": prompt, "size": "1024x1024",
               "extra_body": {"response_format": "b64_json"}}
    import time
    t0 = time.time()
    raw = r1.gen(payload, key)
    if not raw:
        print("[FAIL] %s 三次无果" % key, flush=True)
        return
    im = Image.open(io.BytesIO(raw)).convert("RGB")
    ok, info = r1.lit_gate_white(im)
    if not ok and info.get("verdict") == "dark":
        raw2 = r1.gen(dict(payload, prompt=prompt + r1.LIT_RESCUE), key + "-r")
        if raw2:
            im2 = Image.open(io.BytesIO(raw2)).convert("RGB")
            ok2, info2 = r1.lit_gate_white(im2)
            if ok2:
                im, ok, info = im2, ok2, info2
    im.save(out)
    print("[%s] %s %.0fs %s" % ("OK" if ok else "DARK", key, time.time() - t0,
                                json.dumps(info, ensure_ascii=False)), flush=True)


def main():
    keys = sys.argv[1:] or list(UNITS)
    for k in keys:
        run_case(k)
    print("R3 卡重生成完成 → %s" % STAGE, flush=True)


if __name__ == "__main__":
    main()
