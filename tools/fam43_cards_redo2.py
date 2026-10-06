# -*- coding: utf-8 -*-
"""fam43 卡重生成批 R2·3 张（2026-10-06 用户判定 (2).json 生图组）。

  fe_helix_phantom   现卡是 94px 宽退化窄条 → 重生「抬手出枪」正侧视图替换
  flame_raider_expert 现卡 254px 窄（BA-64 该是宽车）→ 重生「平放出枪」正侧视图替换
  mod_air_multirole  上轮重掷仍非侧视 → 强化正侧锁再掷

复用 fam43_cards_redo 的 gen/lit_gate/BASE_TAIL（.com realm + 白底棚拍规格）。
只落 staging .godot/unit_review/fam43_cards_redo/，绝不写 assets/（拍板后另行部署）。
用法: python tools/fam43_cards_redo2.py [key ...]
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

UNITS = {
    "fe_helix_phantom": dict(
        axis=r1.AXIS_INF,
        subject=("近未来相位幻影特工（phase phantom trooper）：紧身轻量相位纤维作战服与兜帽"
                 "（软质面料质感，微光织纹），肩部与胸前轻量装甲板，腰间能量刃鞘，"
                 "双手持一柄相位能量步枪（phase energy rifle，枪身细长带淡青能量纹路）"),
        pose="举枪到肩线高度瞄准（rifle raised to the shoulder, stock at the cheek, aiming），"
             "枪口朝画面正右方。"),
    "flame_raider_expert": dict(
        axis=("视点在车体正侧方：车体主轴水平横贯画面，四轮侧视重叠成单列轮线，"
              "只见车体单侧面，不见车头正面与车尾正面；无任何透视缩短；"),
        subject=("烈焰专家级 BA-64 轻型突击车平台（BA-64 light armored car）：苏联 BA-64 四轮"
                 "轻型装甲车底盘，棱角焊接装甲板，开放式顶部小炮塔装一挺重型喷火器"
                 "（heavy flamethrower），车体侧后挂背负式燃油罐组，喷口一点小橙色引焰光"),
        pose="炮塔转向正侧，喷火管水平伸出（barrel leveled horizontally, protruding forward），"
             "喷口朝画面正右方。"),
    "mod_air_multirole": dict(
        axis=r1.AXIS_AIR,
        subject=("现代单发多用途战斗机（modern single-engine multirole fighter jet）：气泡式座舱盖"
                 "（bubble canopy）、机腹进气道、三角翼与全动平尾、灰色现役涂装、"
                 "翼下挂格斗弹两枚，机首雷达罩清晰"),
        pose="水平直线平飞姿态，机首朝画面正右方，起落架收起状态。"),
}
# 侧视顽固案强化后缀（multirole 上轮非侧视）
SIDE_RESCUE = ("。再次强调：这是一张正侧档案照式卡图（exact side-profile blueprint view），"
               "相机与机身中线完全等高，从正左侧拍摄；机首与机尾必须处于同一水平高度；"
               "两侧机翼侧视重叠成单一线条；绝对禁止 3/4 视角、斜视角、俯视角。")


def run_case(key):
    u = UNITS[key]
    out = os.path.join(STAGE, "%s_raw.png" % key)
    if os.path.isfile(out) and os.path.getsize(out) > 10000:
        print("[skip] %s 已有" % key, flush=True)
        return
    prompt = ("游戏卡图立绘：%s。严格2D正侧视，正交投影，面朝画面正右方，绝不朝左；%s%s%s"
              % (u["subject"], u["axis"], u["pose"], r1.BASE_TAIL))
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
    print("R2 卡重生成完成 → %s" % STAGE, flush=True)


if __name__ == "__main__":
    main()
