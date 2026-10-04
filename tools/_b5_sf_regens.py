# -*- coding: utf-8 -*-
"""SF 批后补刀（2026-10-04 目验发现）：
- ww1_arty_mortar f3/f4、ww1_a7v f4/f5：负面词反噬——"无地面/无影子/绝不在下方画出地面"
  被渲染成灰影椭圆、车底红渍、青绿大烟雾、锈色漂移 → 换正向措辞重掷（坏 raw 先移备份）。
- mod_arm_m1a2sep f3：车底 salmon 渍（r-g 大但 b≈g，品红/纯红谓词都绕过）→ 底带扩谓词补刀后重导出。
- ww1_lanchest f2/f3（橄榄黄/锈色罩漂移）、ww1_mark4 f2/f4（炮位跳车顶/整车缩水发白）。
其余 raw 全部走缓存不重生成。用法: python tools/_b5_sf_regens.py
"""
import io
import os
import shutil
import sys
import types

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
import numpy as np  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
BK = os.path.join(OUT, "_b5_backup_sf_regens_20261004")
os.makedirs(BK, exist_ok=True)


def load_mod(name, path):
    src = open(path, encoding="utf-8").read()
    # 只删顶层 stdout wrapper 调用行（删"包含该串的行"会误删 _b5_sf_batch 自己的过滤定义）
    lines = [ln for ln in src.splitlines()
             if not ln.strip().startswith("sys.stdout = io.TextIOWrapper")]
    mod = types.ModuleType(name)
    mod.__file__ = path
    exec(compile("\n".join(lines), path, "exec"), mod.__dict__)
    return mod


sb = load_mod("b5_batch", os.path.join(ROOT, "tools", "_b5_sf_batch.py"))


def sf_prompt_pos(action, mw):
    """正向措辞版：不提地面/影子/反光（负面词=召唤）。"""
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


# 底带 salmon/暗焦橙扩谓词：窄带（底 10%）内 r-g>25 即杀——
# 实测 m1a2sep f3 渍=暗焦橙 r≈101 g≈66 b≈41，r>150 咬不住；窄带内只有履带（灰，r-g<15）与渍，安全。
def kill_salmon_bottom(rgba, band=0.10):
    a = np.asarray(rgba).copy()
    al = a[:, :, 3] > 8
    ys, xs = np.where(al)
    if len(ys) == 0:
        return rgba
    y0, y1 = int(ys.min()), int(ys.max())
    cut = y1 - int((y1 - y0) * band)
    r, g = a[:, :, 0].astype(int), a[:, :, 1].astype(int)
    b = a[:, :, 2].astype(int)
    hit = (np.arange(a.shape[0]) > cut)[:, None] & (r > 80) & (r - g > 25) & (b < g + 35)
    a[:, :, 3][hit] = 0
    return Image.fromarray(a)


from PIL import Image  # noqa: E402

orig_key_chain = sb.key_chain


def key_chain_v2(rgb):
    rgba = orig_key_chain(rgb)
    return kill_salmon_bottom(rgba)


# ---- 1) m1a2sep f3 补刀后重导出（不调 API）----
sb.key_chain = key_chain_v2
u = [x for x in sb.UNITS if x["key"] == "mod_arm_m1a2sep"][0]
print("==== mod_arm_m1a2sep 补刀重导出 ====", flush=True)
sb.process_unit(u, 0)

# ---- 2) mortar/a7v 指定帧重掷（正向词）----
REGEN = {
    "ww1_arty_mortar": ["3", "4"],
    "ww1_a7v": ["4", "5"],
    "ww1_lanchest": ["2", "3"],
    "ww1_mark4": ["2", "4"],
}
sb.key_chain = orig_key_chain
sb.sf_prompt = sf_prompt_pos
for key, frames in REGEN.items():
    u = [x for x in sb.UNITS if x["key"] == key][0]
    for n in frames:
        raw = os.path.join(OUT, "%s_SF_f%s_raw.png" % (key, n))
        if os.path.exists(raw):
            shutil.move(raw, os.path.join(BK, os.path.basename(raw)))
    print("==== %s 重掷 %s ====" % (key, frames), flush=True)
    sb.process_unit(u, 10)
print("补刀结束", flush=True)
