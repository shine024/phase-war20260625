# -*- coding: utf-8 -*-
"""mark4/105mm 改走生图域出攻击帧（2026-10-07 用户令：视频域死锁，用生图流程）。

路线 = B5 单帧直出（img25_attack_gen 键控链）+ fam44_cards_redo 今晚实证 API 通道。
锚定 = 现役 player 卡图 → 朝左校正 → fca.extract 品红场（1024）。
帧 1/6=锚定帧本体，帧 2-5 逐帧单出（agnes-image-2.5-flash，cn 域 curl+--ssl-no-revoke）。
产物只落 .godot/unit_review/img25_staging/（§十 铁律不写 assets）。
用法: python tools/_fam44_sf_mark4_105mm.py <key>   # 逐家跑；断点续跑按 _SF_f{n}_raw.png
"""
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
fcr = load_mod("f44_cr", os.path.join(ROOT, "tools", "fam44_cards_redo.py"))
import fam43_card_anchors as fca  # noqa: E402

UNITS = {
    "ww1_mark4": dict(
        card="assets/card_icons/player/ww1_mark4.png",
        actions={
            "2": "第 1 态——侧舷炮微微后缩蓄力，炮口泛起微光，菱形车体姿态与锚定帧完全一致",
            "3": "第 2 态——炮口爆出巨大的橙白色火光，火光在炮口位置炸开，菱形车体随之后坐",
            "4": "第 3 态——火光衰减，大团硝烟从炮口向左飘散",
            "5": "第 4 态——炮管后坐复位，炮口余烟缭绕，车体回到与锚定帧一致的位置",
        }),
    "ww1_105mm": dict(
        card="assets/card_icons/player/ww1_105mm.png",
        actions={
            "2": "第 1 态——炮管微微后缩蓄力，炮口泛起微光，炮架与车轮姿态与锚定帧完全一致",
            "3": "第 2 态——炮口爆出巨大的橙白色火光，火光在炮口位置炸开，炮管猛烈后坐",
            "4": "第 3 态——火光衰减，大团硝烟从炮口向左飘散",
            "5": "第 4 态——炮管后坐复位，炮口余烟缭绕，炮架回到与锚定帧一致的位置",
        }),
}


def sf_prompt(action):
    return (
        "第一张图是这个 2D 游戏精灵的身份锚定帧：纯正侧视角，面朝画面正左方。\n"
        "任务：输出同样纯品红背景下的单帧新图，画同一主体攻击动作中的一个瞬间：" + action + "。\n"
        "【保持·硬性】与锚定帧完全同身份、同体型、同比例、同配色、同武器装备，部件一个不增、不减、不改；"
        "朝向与视角与锚定帧完全一致：面朝画面正左方的纯正侧视图，炮口在画面左侧，绝不朝右，"
        "绝不 3/4 视角、绝不俯视仰视；主体在画面中的大小与位置与锚定帧一致，整车位置固定不动，"
        "只有炮管后坐、火光与硝烟这类武器动作。\n"
        "【特效·硬性】火光与烟只出现在炮口位置（画面左侧），完整位于画面内部，不触碰画布四边；"
        "只有炮口火光与硝烟，没有弹道、没有弹丸、没有光束、没有曳光。\n"
        "【光照·硬性】主体完全受光、照明充足，高光与暗部层次分明，材质细节（纹理、舱盖、履带、炮管结构）"
        "全部清晰可读，即使沙黄涂装也保持鲜明。\n"
        "【背景·硬性】整幅纯品红色 #FF00FF 平涂，主体之外无杂色、无地面、无影子、无场景、无文字、无水印、无边框。"
    )


def kill_pink(rgba):
    """B5 品红残底清除（亮品红∪暗红品红∪淡紫粉三谓词，火光/沙黄/灰烟不命中）。"""
    import numpy as np
    a = np.asarray(rgba).copy()
    r, g, b = a[:, :, 0].astype(int), a[:, :, 1].astype(int), a[:, :, 2].astype(int)
    hit = ((r - g > 30) & (b - g > 10)) | ((r > 100) & (r > g * 1.9) & (b > g * 1.4) & (g < 70)) \
        | ((r - g > 12) & (b - g > 8) & (r > 150))
    a[:, :, 3][hit] = 0
    return Image.fromarray(a)


def key_chain(rgb):
    bg = ag.detect_bg_color(rgb)
    rgba = ag.chroma_key(rgb, bg)
    rgba = kill_pink(rgba)
    rgba = ag.depink(rgba)
    rgba = ag.keep_main_bodies(rgba, 0.35)
    return rgba


def build_anchor(key):
    """player 卡图 → 朝左校正 → 品红场 1024 锚定。"""
    card = Image.open(os.path.join(ROOT, UNITS[key]["card"])).convert("RGBA")
    fac = ag.facing(card)
    if fac == "R":
        card = card.transpose(Image.FLIP_LEFT_RIGHT)
        print("[anchor] %s 卡图朝%s → 已翻朝左" % (key, fac))
    tmp = os.path.join(OUT, "_tmp_card_%s.png" % key)
    card.save(tmp)
    arr, npix = fca.purge_pink_pockets(fca.extract(tmp))
    os.remove(tmp)
    out = os.path.join(OUT, "%s_anchor_raw.png" % key)
    Image.fromarray(arr).save(out)
    print("[anchor] %s → %s（口袋回填 %d px）" % (key, out, npix))
    return out


def main():
    key = sys.argv[1]
    anchor_path = os.path.join(OUT, "%s_anchor_raw.png" % key)
    if not os.path.exists(anchor_path):
        build_anchor(key)
    with open(anchor_path, "rb") as f:
        anchor_uri = "data:image/png;base64," + base64.b64encode(f.read()).decode()
    anchor_rgb = Image.open(anchor_path).convert("RGB")

    keyed = {1: key_chain(anchor_rgb), 6: None}
    keyed[6] = keyed[1]
    for n in (2, 3, 4, 5):
        raw_path = os.path.join(OUT, "%s_SF_f%d_raw.png" % (key, n))
        if not os.path.exists(raw_path):
            payload = {"model": "agnes-image-2.5-flash",
                       "prompt": sf_prompt(UNITS[key]["actions"][str(n)]),
                       "size": "1K", "ratio": "1:1",
                       "extra_body": {"image": [anchor_uri], "response_format": "b64_json"}}
            print("帧 %d 生成中… %s" % (n, UNITS[key]["actions"][str(n)][:30]), flush=True)
            t0 = time.time()
            raw = fcr.gen(payload, "%s_f%d" % (key, n))
            if raw is None:
                print("  [FAIL] 帧 %d 三掷皆废" % n, flush=True)
                continue
            with open(raw_path, "wb") as f:
                f.write(raw)
            print("  OK 帧 %d (%.0fs)" % (n, time.time() - t0), flush=True)
            time.sleep(10)
        keyed[n] = key_chain(Image.open(raw_path).convert("RGB"))

    sus = [n for n in (1, 2, 3, 4, 5, 6)
           if keyed.get(n) is not None and ag.facing(keyed[n]) == "R"]
    print("朝向可疑格: %s（提示性，须目验终审）" % (sus or "无"), flush=True)

    cells, missing = [], []
    for n in (1, 2, 3, 4, 5, 6):
        k = keyed.get(n)
        if k is None:
            missing.append(n)
            cells.append(None)
            continue
        bb = ag.alpha_bbox(k)
        if bb is None:
            missing.append(n)
            cells.append(None)
            continue
        cells.append(k.crop(bb))
    # 锚定帧本体宽度对齐（f2/f5=火效最小帧取 min 估本体；防 1024 锚定与 API 帧真实尺寸差）
    if cells[0] is not None and cells[1] is not None and cells[4] is not None:
        ref = min(cells[1].size[0], cells[4].size[0])
        ratio = ref / cells[0].size[0]
        if 0.7 <= ratio <= 1.4 and abs(ratio - 1.0) > 0.02:
            c0 = cells[0]
            cells[0] = c0.resize((max(1, int(c0.size[0] * ratio)), max(1, int(c0.size[1] * ratio))),
                                 Image.LANCZOS)
            print("[align] 锚定宽 %d→%d (×%.2f)" % (c0.size[0], cells[0].size[0], ratio), flush=True)
        cells[5] = cells[0].copy()  # 帧 6 同步（含对齐后尺寸）
    valid = [c for c in cells if c is not None]
    sc = (FS - 24) / max(max(c.size[0] for c in valid), max(c.size[1] for c in valid))
    frames = []
    for c in cells:
        cv = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
        if c is not None:
            nw, nh = max(1, int(c.size[0] * sc)), max(1, int(c.size[1] * sc))
            cc = c.resize((nw, nh), Image.LANCZOS)
            cv.paste(cc, (FS - nw - 12, FS - nh - 12), cc)
        frames.append(cv)

    sheet = Image.new("RGBA", (FS * 6, FS), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * FS, 0))
    sheet.convert("RGB").save(os.path.join(OUT, "%s_SF_attack_sheet_512.png" % key))

    bgc = Image.new("RGBA", (FS, FS), (60, 60, 60, 255))
    comp = []
    for f in frames:
        b = bgc.copy()
        b.paste(f, (0, 0), f)
        comp.append(b.convert("RGB"))
    comp[0].save(os.path.join(OUT, "%s_SF_attack_anim.gif" % key), save_all=True,
                 append_images=comp[1:], duration=100, loop=0)
    cell = 212
    g = Image.new("RGB", (3 * cell, 2 * cell), (40, 44, 52))
    for i, f in enumerate(frames):
        fr = f.convert("RGBA").resize((cell, cell), Image.LANCZOS)
        g.paste(fr, (i % 3 * cell, i // 3 * cell), fr)
    g.save(os.path.join(OUT, "%s_SF_attack_cells_dark.png" % key))
    print("[export] %s_SF_attack_* 缺帧%s" % (key, missing or "无"), flush=True)


if __name__ == "__main__":
    main()
