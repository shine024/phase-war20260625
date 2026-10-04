# -*- coding: utf-8 -*-
"""SF 补刀第二轮（2026-10-04 复检发现）：
- a7v f4/f5：动作词"青烟"=召唤青绿大烟雾（正向词压不住词义本身）→ 改"灰白色硝烟"；
  f5 末态炮口仍挂残焰 → 末态词也去"硝烟"只留"灰白残烟一缕"。
- mark4 f2：艏炮被画到车顶 → 动作词钉死"侧炮座原位"。
坏 raw 先移备份（round2 子目录）。用法: python tools/_b5_sf_regens2.py
"""
import io
import os
import shutil
import sys
import types

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
BK = os.path.join(OUT, "_b5_backup_sf_regens_20261004", "round2")
os.makedirs(BK, exist_ok=True)


def load_mod(name, path):
    src = open(path, encoding="utf-8").read()
    lines = [ln for ln in src.splitlines()
             if not ln.strip().startswith("sys.stdout = io.TextIOWrapper")]
    mod = types.ModuleType(name)
    mod.__file__ = path
    exec(compile("\n".join(lines), path, "exec"), mod.__dict__)
    return mod


sb = load_mod("b5_batch", os.path.join(ROOT, "tools", "_b5_sf_batch.py"))

# 内联正向措辞版（勿 import _b5_sf_regens——那会把它第一轮 whole 重跑）
def sf_prompt_pos(action, mw):
    return (
        "第一张图是这个 2D 游戏精灵的身份锚定帧：纯正侧视角，面朝画面正左方。\n"
        "任务：输出同样纯品红背景下的单帧新图，画同一主体攻击动作中的一个瞬间：" + action + "。\n"
        "【保持·硬性】与锚定帧完全同身份、同体型、同比例、同配色、同武器装备，部件一个不增、不减、不改；"
        "朝向与视角与锚定帧完全一致：面朝画面正左方的纯正侧视图，" + mw + "在画面左侧，车头在画面右侧，"
        "纯正侧视；主体在画面中的大小与位置与锚定帧一致，整车位置固定不动，"
        "只有武器部件运动、火光与硝烟这类攻击动作。\n"
        "【特效·硬性】主体悬空呈现在纯色背景前，火光与烟只出现在" + mw + "位置（画面左侧），"
        "烟只许一小缕，完整位于画面内部，四周留出纯品红空隙；没有弹道、没有弹丸。\n"
        "【光照·硬性】主体完全受光、照明充足，与锚定帧同色调，高光与暗部层次分明，材质细节全部清晰可读。\n"
        "【背景·硬性】整幅纯品红色 #FF00FF 平涂，主体之外全是同色平涂，无文字、无水印、无边框。"
    )


sb.sf_prompt = sf_prompt_pos
sb.TAIL5 = "攻击末态——炮口只挂一小缕灰白色残烟，火已全熄，主体姿态回到与锚定帧完全一致的待机"

REGEN2 = {
    "ww1_a7v": {"4": "火光熄灭，一小缕灰白色硝烟贴着车体散开", "5": ""},  # f5 走 TAIL5（已换灰白残烟版）
    "ww1_mark4": {"2": "艏炮保持在与锚定帧相同的车体侧面炮座原位，仅炮口喷出短促橙红火光"},
}
for key, acts in REGEN2.items():
    u = [x for x in sb.UNITS if x["key"] == key][0]
    u["actions"].update(acts)
    for n in acts:
        raw = os.path.join(OUT, "%s_SF_f%s_raw.png" % (key, n))
        if os.path.exists(raw):
            shutil.move(raw, os.path.join(BK, os.path.basename(raw)))
    print("==== %s 重掷 %s ====" % (key, sorted(acts)), flush=True)
    sb.process_unit(u, 10)
print("第二轮补刀结束", flush=True)
