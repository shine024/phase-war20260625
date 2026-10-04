# -*- coding: utf-8 -*-
"""SF 修复第四轮（2026-10-04 拍板 JSON v2 备注「火光处理一下」）：
77mm / 105mm 各重掷 f2+f3——f2 蓄力帧此前画成了全开火光/白烟（语义错，改针尖微光）；
f3 火光改经典膛口焰（白热焰心+放射细星芒、小巧紧凑）。其余帧不动。
用法: python tools/_b5_sf_fix4.py
"""
import io
import os
import shutil
import sys
import types

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
BK = os.path.join(OUT, "_b5_backup_sf_fix4_20261004")
os.makedirs(BK, exist_ok=True)


def load_mod(name, path):
    src = open(path, encoding="utf-8").read()
    lines = [ln for ln in src.splitlines()
             if not ln.strip().startswith("sys.stdout = io.TextIOWrapper")]
    mod = types.ModuleType(name)
    mod.__file__ = path
    exec(compile("\n".join(lines), path, "exec"), mod.__dict__)
    return mod


def kill_salmon_bottom(rgba, band=0.10):
    import numpy as np
    from PIL import Image
    a = np.asarray(rgba).copy()
    al = a[:, :, 3] > 8
    ys, _xs = np.where(al)
    if len(ys) == 0:
        return rgba
    y0, y1 = int(ys.min()), int(ys.max())
    cut = y1 - int((y1 - y0) * band)
    r, g = a[:, :, 0].astype(int), a[:, :, 1].astype(int)
    b = a[:, :, 2].astype(int)
    hit = (np.arange(a.shape[0]) > cut)[:, None] & (r > 80) & (r - g > 25) & (b < g + 35)
    a[:, :, 3][hit] = 0
    return Image.fromarray(a)


# 源码级补丁：key_chain 挂鱼腹带钩子（RGBA 保存已烧进源文件，无需再补）
p = os.path.join(ROOT, "tools", "_b5_sf_batch.py")
src = open(p, encoding="utf-8").read()
src = "\n".join(ln for ln in src.splitlines()
                if not ln.strip().startswith("sys.stdout = io.TextIOWrapper"))
REP = [
    ("def key_chain(rgb):", "def key_chain(rgb, salmon=False):"),
    ("    rgba = kill_bottom_red(rgba)\n    rgba = ag.keep_main_bodies",
     "    rgba = kill_bottom_red(rgba)\n    if salmon:\n        rgba = kill_salmon_bottom(rgba, 0.18)\n    rgba = ag.keep_main_bodies"),
    ("    keyed = {1: key_chain(anchor_rgb), 6: None}",
     "    keyed = {1: key_chain(anchor_rgb, salmon=(key, 1) in SALMON_FRAMES), 6: None}"),
    ('        keyed[n] = key_chain(Image.open(raw_path).convert("RGB"))',
     '        keyed[n] = key_chain(Image.open(raw_path).convert("RGB"), salmon=(key, n) in SALMON_FRAMES)'),
]
for old, new in REP:
    assert src.count(old) == 1, "补丁锚点不唯一: %r" % old[:50]
    src = src.replace(old, new)

sb = types.ModuleType("b5_batch_fix4")
sb.__file__ = p
exec(compile(src, p, "exec"), sb.__dict__)
sb.kill_salmon_bottom = kill_salmon_bottom
sb.SALMON_FRAMES = {("ww1_105mm", 3), ("ww1_105mm", 4)}
sb.TAIL5 = "攻击末态——炮口只挂一小缕灰白色残烟，火已全熄，主体姿态回到与锚定帧完全一致的待机"
sb.sf_prompt = None  # 占位，下方赋值


def sf_prompt_fix4(action, mw):
    return (
        "第一张图是这个 2D 游戏精灵的身份锚定帧：纯正侧视角，面朝画面正左方。\n"
        "任务：输出同样纯品红背景下的单帧新图，画同一主体攻击动作中的一个瞬间：" + action + "。\n"
        "【保持·硬性】与锚定帧完全同身份、同体型、同比例、同配色、同武器装备，部件一个不增、不减、不改；"
        "朝向与视角与锚定帧完全一致：面朝画面正左方的纯正侧视图，" + mw + "在画面左侧，车头在画面右侧，"
        "纯正侧视；主体在画面中的大小与位置与锚定帧一致，整车位置固定不动，"
        "只有武器部件运动、火光与硝烟这类攻击动作。\n"
        "【特效·硬性】主体悬空呈现在纯色背景前；火光很小很紧凑，紧贴" + mw + "完整绽开，"
        "火光与烟全部完整落在画面内部中央区域，特效外围四面都留着大片纯品红空白；"
        "画面内容只有主体与它的小簇火光硝烟，画面空旷干净。\n"
        "【光照·硬性】主体完全受光、照明充足，与锚定帧同色调，高光与暗部层次分明，材质细节全部清晰可读。\n"
        "【背景·硬性】整幅纯品红色 #FF00FF 平涂，主体之外全是同色平涂，无文字、无水印、无边框。"
    )


sb.sf_prompt = sf_prompt_fix4

# 蓄力帧=针尖微光；火光帧=白热焰心+放射细星芒的紧凑膛口焰
REGEN4 = {
    "ww1_arty_77mm": {"2": "炮身沿炮架向后滑动蓄力，炮口泛起针尖大小的一点微光",
                      "3": "炮口喷出短促的橙白色膛口焰，焰心白热极亮，外缘呈放射状细小星芒，火光小巧紧凑，完整贴在炮口绽开，整车后坐"},
    "ww1_105mm": {"2": "炮身沿炮架向后滑动蓄力，炮口泛起针尖大小的一点微光",
                  "3": "炮口喷出短促的橙白色膛口焰，焰心白热极亮，外缘呈放射状细小星芒，火光小巧紧凑，完整贴在炮口绽开，整车后坐"},
}

for key, acts in REGEN4.items():
    u = [x for x in sb.UNITS if x["key"] == key][0]
    u["actions"].update(acts)
    for n in acts:
        raw = os.path.join(OUT, "%s_SF_f%s_raw.png" % (key, n))
        if os.path.exists(raw):
            shutil.move(raw, os.path.join(BK, os.path.basename(raw)))
    print("==== %s 重掷 %s ====" % (key, sorted(acts)), flush=True)
    sb.process_unit(u, 12)
print("第四轮（火光处理）结束", flush=True)
