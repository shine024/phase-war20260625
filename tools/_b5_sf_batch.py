# -*- coding: utf-8 -*-
"""B5 SF 单帧直出全批（2026-10-04 用户令：网格卷全弃，没有的就重新生图直出）。

11 案攻击重出：每案 4 次调用（帧 2-4 用 §十 已验证 cells 文案，帧 5 通用末态，帧 1/6=锚定帧本体）。
相对试点（tools/_b5_singleframe_pilot.py）新增：
- 车底红细线补刀（bbox 下条带内纯红/橙红杀——品红谓词故意不碰的纯红残留）
- 空中单位垂直居中锚定（bomber）
- 逐单位射出端词（炮口/枪口/射口/弹舱口）
断点续跑：<key>_SF_f{n}_raw.png 已存在即跳过调用。产物 <key>_SF_attack_*，绝不写 assets/。
用法: python tools/_b5_sf_batch.py [--only key1,key2]
"""
import argparse
import base64
import io
import json
import os
import sys
import time
import types

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
from PIL import Image  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
FS = 512


def load_mod(name, path):
    src = open(path, encoding="utf-8").read()
    lines = [ln for ln in src.splitlines() if "sys.stdout = io.TextIOWrapper" not in ln]
    mod = types.ModuleType(name)
    mod.__file__ = path
    exec(compile("\n".join(lines), path, "exec"), mod.__dict__)
    return mod


ag = load_mod("b5_ag", os.path.join(ROOT, "tools", "img25_attack_gen.py"))

# 帧起势通用尾（帧 5）
TAIL5 = "攻击末态——硝烟淡去只剩一缕残烟，主体姿态回到与锚定帧完全一致的待机"

UNITS = [
    dict(key="ww2_sup_mg42", mw="枪口",
         actions={"2": "枪托抵肩微微上抬，枪口泛起点点微光",
                  "3": "枪口爆出锐长橙红色火光，弹壳向右抛出",
                  "4": "火光衰减，枪口青烟拉出一缕"}),
    dict(key="ww2_boss_kingtiger", mw="炮口",
         actions={"2": "炮管微微后缩蓄力，炮口泛起微光",
                  "3": "炮口爆出巨大橙白色火光，整车明显后坐",
                  "4": "火光衰减，大团硝烟从炮口散开"}),
    dict(key="ww2_air_bomber", mw="机腹弹舱口", air=True,
         actions={"2": "机腹弹舱门开启，一串航空炸弹脱离机腹向下坠落",
                  "3": "炸弹坠离画面，弹舱门全开",
                  "4": "弹舱门收拢复位"}),
    dict(key="ww1_arty_mortar", mw="炮口",
         actions={"2": "炮身沿支架微微下沉蓄力",
                  "3": "炮口喷出球形橙红膛口焰，一枚炮弹离开炮口飞向左上方",
                  "4": "膛口焰散成烟环，炮身回弹"}),
    dict(key="ww1_a7v", mw="射口",
         actions={"2": "侧面机枪射口泛起微光",
                  "3": "射口喷出短促橙红火光",
                  "4": "火光衰减，青烟贴着车体散开"}),
    dict(key="ww1_lanchest", mw="枪口",
         actions={"2": "炮塔机枪微微上抬泛光",
                  "3": "枪口喷出短促橙红火光，弹壳抛出",
                  "4": "火光衰减，青烟一缕"}),
    dict(key="ww1_mark4", mw="炮口",
         actions={"2": "艏炮微微后缩蓄力泛光",
                  "3": "艏炮喷出橙白色火光，车体微震",
                  "4": "火光衰减硝烟涌出"}),
    dict(key="mod_arm_m1a2sep", mw="炮口",
         actions={"2": "炮管微微后缩蓄力，炮口泛起微光",
                  "3": "炮口爆出巨大的橙白色火光，火光在炮口位置炸开，车体随之后坐",
                  "4": "火光衰减，大团硝烟从炮口向左飘散"}),
    dict(key="mod_air_technical_e", mw="枪口",
         actions={"2": "机枪微微上抬，枪口泛起微光",
                  "3": "枪口喷出锐长橙红火光，弹壳向右抛出",
                  "4": "火光衰减，枪口青烟一缕"}),
    dict(key="ww1_arty_77mm", mw="炮口",
         actions={"2": "炮身沿炮架向后滑动蓄力泛光",
                  "3": "炮口爆出橙白色火光，整车后坐",
                  "4": "火光衰减大团硝烟散开"}),
    dict(key="ww1_105mm", mw="炮口",
         actions={"2": "炮身沿炮架向后滑动蓄力泛光",
                  "3": "炮口爆出橙白色火光，整车后坐",
                  "4": "火光衰减大团硝烟散开"}),
]


def sf_prompt(action, mw):
    return (
        "第一张图是这个 2D 游戏精灵的身份锚定帧：纯正侧视角，面朝画面正左方。\n"
        "任务：输出同样纯品红背景下的单帧新图，画同一主体攻击动作中的一个瞬间：" + action + "。\n"
        "【保持·硬性】与锚定帧完全同身份、同体型、同比例、同配色、同武器装备，部件一个不增、不减、不改；"
        "朝向与视角与锚定帧完全一致：面朝画面正左方的纯正侧视图，" + mw + "在画面左侧，绝不朝右，"
        "绝不 3/4 视角、绝不俯视仰视；主体在画面中的大小与位置与锚定帧一致，整车位置固定不动，"
        "只有武器部件运动、火光与硝烟这类攻击动作。\n"
        "【特效·硬性】火光与烟只出现在" + mw + "位置（画面左侧），完整位于画面内部，不触碰画布四边，"
        "绝不在下方画出地面、光斑或反光；没有弹道、没有弹丸、没有光束、没有曳光。\n"
        "【光照·硬性】主体完全受光、照明充足，高光与暗部层次分明，材质细节全部清晰可读。\n"
        "【背景·硬性】整幅纯品红色 #FF00FF 平涂，主体之外无杂色、无地面、无影子、无场景、无文字、无水印、无边框。"
    )


def kill_pink(rgba):
    """全局品红残底清除（必须在 depink 前）：亮品红∪暗红品红∪淡紫粉（粉=蓝分高于绿）。"""
    import numpy as np
    a = np.asarray(rgba).copy()
    r, g, b = a[:, :, 0].astype(int), a[:, :, 1].astype(int), a[:, :, 2].astype(int)
    hit = ((r - g > 30) & (b - g > 10)) | ((r > 100) & (r > g * 1.9) & (b > g * 1.4) & (g < 70)) \
        | ((r - g > 12) & (b - g > 8) & (r > 150))
    a[:, :, 3][hit] = 0
    return Image.fromarray(a)


def kill_bottom_red(rgba, band=0.14):
    """bbox 下条带纯红/橙红补刀（开火帧车底红地光细线——蓝分低的纯红品红谓词碰不到）。
    只动底部 band 高度条带，火光（位于中高部）不进条带；履带深灰 r-g 小不命中。"""
    import numpy as np
    a = np.asarray(rgba).copy()
    al = a[:, :, 3] > 8
    ys, xs = np.where(al)
    if len(ys) == 0:
        return rgba
    y0, y1 = int(ys.min()), int(ys.max())
    cut = y1 - int((y1 - y0) * band)
    r, g = a[:, :, 0].astype(int), a[:, :, 1].astype(int)
    b = a[:, :, 2].astype(int)
    hit = (np.arange(a.shape[0]) > cut)[:, None] & (r > 140) & (r - g > 70) & (g < 100)
    a[:, :, 3][hit] = 0
    return Image.fromarray(a)


def key_chain(rgb):
    bg = ag.detect_bg_color(rgb)
    rgba = ag.chroma_key(rgb, bg)
    rgba = kill_pink(rgba)
    rgba = ag.depink(rgba)
    rgba = kill_bottom_red(rgba)
    rgba = ag.keep_main_bodies(rgba, 0.35)
    return rgba


def process_unit(u, gap):
    key = u["key"]
    anchor_path = os.path.join(OUT, key + "_anchor_raw.png")
    if not os.path.exists(anchor_path):
        print("[skip] %s 缺锚定帧" % key, flush=True)
        return
    with open(anchor_path, "rb") as f:
        anchor_uri = "data:image/png;base64," + base64.b64encode(f.read()).decode()
    anchor_rgb = Image.open(anchor_path).convert("RGB")
    keyed = {1: key_chain(anchor_rgb), 6: None}
    keyed[6] = keyed[1]
    for n in (2, 3, 4, 5):
        raw_path = os.path.join(OUT, "%s_SF_f%d_raw.png" % (key, n))
        if not os.path.exists(raw_path):
            action = TAIL5 if n == 5 else u["actions"][str(n)]
            payload = os.path.join(OUT, "_sf_payload.json")
            with open(payload, "w", encoding="utf-8") as f:
                f.write(json.dumps({"model": "agnes-image-2.5-flash",
                                    "prompt": sf_prompt(action, u["mw"]),
                                    "size": "1K", "ratio": "1:1",
                                    "extra_body": {"image": [anchor_uri],
                                                   "response_format": "b64_json"}},
                                   ensure_ascii=False))
            print("[%s] 帧 %d 生成中… %s" % (key, n, action[:24]), flush=True)
            t0 = time.time()
            raw = ag.gen_image(payload)
            if raw is None:
                print("  [FAIL] 帧 %d 三掷皆废" % n, flush=True)
                continue
            with open(raw_path, "wb") as f:
                f.write(raw)
            print("  OK (%.0fs)" % (time.time() - t0), flush=True)
            time.sleep(gap)
        keyed[n] = key_chain(Image.open(raw_path).convert("RGB"))
    sus = [n for n in (1, 2, 3, 4, 5, 6)
           if keyed.get(n) is not None and ag.facing(keyed[n]) == "R"]
    print("[%s] 朝向可疑格: %s（提示性，须目验终审）" % (key, sus or "无"), flush=True)

    cells, missing = [], []
    for n in (1, 2, 3, 4, 5, 6):
        k = keyed.get(n)
        bb = ag.alpha_bbox(k) if k is not None else None
        if k is None or bb is None:
            missing.append(n)
            cells.append(None)
            continue
        cells.append(k.crop(bb))
    valid = [c for c in cells if c is not None]
    if not valid:
        print("[%s] [FAIL] 无有效帧" % key, flush=True)
        return
    sc = (FS - 24) / max(max(c.size[0] for c in valid), max(c.size[1] for c in valid))
    frames = []
    for c in cells:
        cv = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
        if c is not None:
            nw, nh = max(1, int(c.size[0] * sc)), max(1, int(c.size[1] * sc))
            cc = c.resize((nw, nh), Image.LANCZOS)
            x = (FS - nw) // 2 if u.get("air") else FS - nw - 12
            y = (FS - nh) // 2 if u.get("air") else FS - nh - 12
            cv.paste(cc, (x, y), cc)
        frames.append(cv)
    sheet = Image.new("RGBA", (FS * 6, FS), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * FS, 0))
    sheet.save(os.path.join(OUT, "%s_SF_attack_sheet_512.png" % key))  # RGBA 透明（convert("RGB") 会丢 alpha 变黑底——fix3 教训）
    bgc = Image.new("RGBA", (FS, FS), (60, 60, 60, 255))
    comp = []
    for f in frames:
        b = bgc.copy()
        b.paste(f, (0, 0), f)
        comp.append(b.convert("RGB"))
    comp[0].save(os.path.join(OUT, "%s_SF_attack_anim.gif" % key), save_all=True,
                 append_images=comp[1:], duration=100, loop=0)
    cell = 212
    g2 = Image.new("RGB", (3 * cell, 2 * cell), (40, 44, 52))
    for i, f in enumerate(frames):
        fr = f.convert("RGBA").resize((cell, cell), Image.LANCZOS)
        g2.paste(fr, (i % 3 * cell, i // 3 * cell), fr)
    g2.save(os.path.join(OUT, "%s_SF_attack_cells_dark.png" % key))
    print("[%s] export SF 完成 缺帧%s" % (key, missing or "无"), flush=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default=None)
    ap.add_argument("--gap", type=int, default=10)
    args = ap.parse_args()
    only = set(args.only.split(",")) if args.only else None
    for u in UNITS:
        if only and u["key"] not in only:
            continue
        print("==== %s ====" % u["key"], flush=True)
        process_unit(u, args.gap)
    print("SF 全批结束", flush=True)


if __name__ == "__main__":
    main()
