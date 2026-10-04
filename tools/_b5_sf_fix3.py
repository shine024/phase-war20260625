# -*- coding: utf-8 -*-
"""SF 修复第三轮（2026-10-04 拍板 JSON 备注）：
1)【管线 bug】sheet.convert("RGB") 把透明底变纯黑（丢 alpha）——源码补丁改 RGBA 保存，全 11 案重导出。
2) ww2_sup_mg42：拍板备注「第2帧删除，用第4帧代替第2帧」→ keyed[2]=keyed[4]。
3) ww1_mark4：拍板备注「1，6帧 转方向」→ 锚定帧车头朝右（f2-f5 被提示词翻成朝左）→ f1/f6 原位镜像。
4) 截断修复（raw 生成层火光/烟顶到画布左缘平切）：mortar f2-f5、105mm f3/f4、77mm f3/f5 重掷，
   正向含摄提示（火光紧贴炮口完整绽开+特效外围大片品红空白+画面只有主体）；删「没有弹丸/弹道」负面词
   （第 4 例负面词反噬：f2 首掷被"没有弹丸"召唤出炮弹）。mortar f3 动作词原带"炮弹飞向左上"一并清除。
5) 105mm f3/f4 淡橙地光 → kill_salmon_bottom 底 18% 窄带（仅这两帧；mortar 靴子/77mm 木炮腿同带会误伤）。
用法: python tools/_b5_sf_fix3.py
"""
import io
import os
import shutil
import sys
import types

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
BK = os.path.join(OUT, "_b5_backup_sf_fix3_20261004")
os.makedirs(BK, exist_ok=True)


def load_mod(name, path):
    src = open(path, encoding="utf-8").read()
    lines = [ln for ln in src.splitlines()
             if not ln.strip().startswith("sys.stdout = io.TextIOWrapper")]
    mod = types.ModuleType(name)
    mod.__file__ = path
    exec(compile("\n".join(lines), path, "exec"), mod.__dict__)
    return mod


# ---- 源码级补丁（exec 前）----
p = os.path.join(ROOT, "tools", "_b5_sf_batch.py")
src = open(p, encoding="utf-8").read()
src = "\n".join(ln for ln in src.splitlines()
                if not ln.strip().startswith("sys.stdout = io.TextIOWrapper"))
REP = [
    # 1) key_chain 挂鱼腹带钩子
    ("def key_chain(rgb):", "def key_chain(rgb, salmon=False):"),
    ("    rgba = kill_bottom_red(rgba)\n    rgba = ag.keep_main_bodies",
     "    rgba = kill_bottom_red(rgba)\n    if salmon:\n        rgba = kill_salmon_bottom(rgba, 0.18)\n    rgba = ag.keep_main_bodies"),
    ("    keyed = {1: key_chain(anchor_rgb), 6: None}",
     "    keyed = {1: key_chain(anchor_rgb, salmon=(key, 1) in SALMON_FRAMES), 6: None}"),
    ('        keyed[n] = key_chain(Image.open(raw_path).convert("RGB"))',
     '        keyed[n] = key_chain(Image.open(raw_path).convert("RGB"), salmon=(key, n) in SALMON_FRAMES)'),
    # 2) 拍板帧操作（mg42 f2←f4、mark4 f1/f6 镜像）插在朝向审计之后
    ("    cells, missing = [], []",
     '    if key == "ww2_sup_mg42" and keyed.get(4) is not None:\n'
     "        keyed[2] = keyed[4]\n"
     '    if key == "ww1_mark4":\n'
     "        for _n in (1, 6):\n"
     "            if keyed.get(_n) is not None:\n"
     "                keyed[_n] = keyed[_n].transpose(Image.FLIP_LEFT_RIGHT)\n"
     "    cells, missing = [], []"),
    # 3) RGBA 保存（部署契约：透明底）
    ('    sheet.convert("RGB").save(os.path.join(OUT, "%s_SF_attack_sheet_512.png" % key))',
     '    sheet.save(os.path.join(OUT, "%s_SF_attack_sheet_512.png" % key))'),
]
for old, new in REP:
    assert src.count(old) == 1, "补丁锚点不唯一/未找到: %r" % old[:60]
    src = src.replace(old, new)

sb = types.ModuleType("b5_batch_fixed")
sb.__file__ = p
exec(compile(src, p, "exec"), sb.__dict__)


def kill_salmon_bottom(rgba, band=0.10):
    """暗焦橙/淡橙地光（底带窄区 r>80 & r-g>25 & b<g+35）——105mm f3/f4 专用。"""
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


sb.kill_salmon_bottom = kill_salmon_bottom
sb.SALMON_FRAMES = {("ww1_105mm", 3), ("ww1_105mm", 4)}
sb.TAIL5 = "攻击末态——炮口只挂一小缕灰白色残烟，火已全熄，主体姿态回到与锚定帧完全一致的待机"


# ---- 正向含摄提示（截断修复）：火光小而紧凑、特效外围留大片品红、画面只有主体；无负面名词 ----
def sf_prompt_fix(action, mw):
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


sb.sf_prompt = sf_prompt_fix

REGEN3 = {
    "ww1_arty_mortar": {"2": "炮身沿支架微微下沉蓄力，炮口泛起小小微光",
                        "3": "炮口喷出短促紧凑的球形橙红膛口焰，膛口焰紧贴炮口完整绽开，整车轻微后坐",
                        "4": "膛口焰散成一小缕灰白色硝烟贴着炮口散开，炮身回弹",
                        "5": ""},
    "ww1_105mm": {"3": "炮口喷出短促紧凑的橙红火光，火光紧贴炮口完整绽开，整车后坐",
                  "4": "火光熄灭，一小缕灰白色硝烟贴着炮架散开"},
    "ww1_arty_77mm": {"3": "炮口喷出短促紧凑的橙红火光，火光紧贴炮口完整绽开，整车后坐",
                      "4": "火光熄灭，一小缕灰白色硝烟贴着炮架散开",
                      "5": ""},
}

# 旧产物先入备份（sheet_512 / cells_dark / gif × 全 11 案 + 重掷 raw）
ALL = [u["key"] for u in sb.UNITS if os.path.exists(os.path.join(OUT, "%s_anchor_raw.png" % u["key"]))]
for key in ALL:
    for suf in ("_SF_attack_sheet_512.png", "_SF_attack_cells_dark.png", "_SF_attack_anim.gif"):
        f = os.path.join(OUT, key + suf)
        if os.path.exists(f):
            shutil.move(f, os.path.join(BK, os.path.basename(f)))
for key, acts in REGEN3.items():
    for n in acts:
        raw = os.path.join(OUT, "%s_SF_f%s_raw.png" % (key, n))
        if os.path.exists(raw):
            shutil.move(raw, os.path.join(BK, os.path.basename(raw)))
print("备份完成 →", BK, flush=True)

for key, acts in REGEN3.items():
    u = [x for x in sb.UNITS if x["key"] == key][0]
    u["actions"].update(acts)
    print("==== %s 重掷 %s ====" % (key, sorted(acts)), flush=True)
    sb.process_unit(u, 12)

REEXPORT = [k for k in ALL if k not in REGEN3]
for key in REEXPORT:
    u = [x for x in sb.UNITS if x["key"] == key][0]
    print("==== %s 重导出（RGBA+拍板帧操作） ====" % key, flush=True)
    sb.process_unit(u, 0)
print("第三轮修复结束", flush=True)
