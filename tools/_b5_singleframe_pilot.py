# -*- coding: utf-8 -*-
"""B5 单帧直出生图试点（2026-10-04）。

背景：§十 3×2 网格每格独立采样 → 朝向各自漂（一会左一会右 + 3/4 视角，用户全废）；
AXIS_EN 英文轴条款 R2 起已生效仍拦不住；而单图生成（锚定帧阶段）朝向服从极好
（如 mod_arm_m1a2sep_anchor_raw 正侧朝左完美）。本试点把攻击帧改成逐帧单出：
Image1=锚定帧（身份+朝向锚），每次调用只出 1 帧，品红底，键控后 512 规范化
右缘+底缘锚定拼表。帧 1/6 = 锚定帧本体，实际只调 4 次图。

产物只落 .godot/unit_review/img25_staging/<key>_SF_attack_*，绝不写 assets/（§十 铁律）。
断点续跑：单帧原始图落 <key>_SF_f{n}_raw.png，已有即跳过该帧调用。
用法: python tools/_b5_singleframe_pilot.py <key> [--actions-json path] [--gap 10]
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

# 默认动作脚本：M1A2SEP 主炮（措辞沿用 §十 已验证 cells 文案）
DEFAULT_ACTIONS = {
    "2": "第 1 态——炮管微微后缩蓄力，炮口泛起微光，车体姿态与锚定帧完全一致",
    "3": "第 2 态——炮口爆出巨大的橙白色火光，火光在炮口位置炸开，车体随之后坐",
    "4": "第 3 态——火光衰减，大团硝烟从炮口向左飘散",
    "5": "第 4 态——炮管后坐复位，炮口余烟缭绕，车体回到与锚定帧一致的位置",
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
    """全局品红残底清除（depink 会把品红洗成灰——必须在 depink 之前杀透明）。
    谓词：亮品红 (r-g>30 & b-g>10) ∪ 暗红品红 (r>100 & r>g*1.9 & b>g*1.4 & g<70)
        ∪ 淡紫粉 (r-g>12 & b-g>8 & r>150——火光映地粉光池；粉=蓝分高于绿，
        沙黄/橙火=蓝分低于绿、灰烟白烟=三分接近，均不命中)。"""
    import numpy as np
    a = np.asarray(rgba).copy()
    r, g, b = a[:, :, 0].astype(int), a[:, :, 1].astype(int), a[:, :, 2].astype(int)
    hit = ((r - g > 30) & (b - g > 10)) | ((r > 100) & (r > g * 1.9) & (b > g * 1.4) & (g < 70)) \
        | ((r - g > 12) & (b - g > 8) & (r > 150))
    a[:, :, 3][hit] = 0
    return Image.fromarray(a)


def key_chain(rgb):
    """品红底 → 键控（品红色相限制 v3）→ 全局品红补刀 → depink → 主体域保留。"""
    bg = ag.detect_bg_color(rgb)
    rgba = ag.chroma_key(rgb, bg)
    rgba = kill_pink(rgba)
    rgba = ag.depink(rgba)
    rgba = ag.keep_main_bodies(rgba, 0.35)
    return rgba


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("key")
    ap.add_argument("--actions-json", default=None,
                    help='{"2".."5": 逐帧动作}；缺省用 M1A2SEP 主炮脚本')
    ap.add_argument("--gap", type=int, default=10, help="调用间隔秒（限流）")
    args = ap.parse_args()

    actions = dict(DEFAULT_ACTIONS)
    if args.actions_json:
        with open(args.actions_json, encoding="utf-8") as f:
            actions = {k: v for k, v in json.load(f).items() if k.isdigit()}

    anchor_path = os.path.join(OUT, args.key + "_anchor_raw.png")
    if not os.path.exists(anchor_path):
        print("缺锚定帧:", anchor_path)
        sys.exit(1)
    with open(anchor_path, "rb") as f:
        anchor_uri = "data:image/png;base64," + base64.b64encode(f.read()).decode()
    anchor_rgb = Image.open(anchor_path).convert("RGB")

    # 帧 1/6 = 锚定帧本体；帧 2-5 逐帧单出（断点续跑）
    keyed = {1: key_chain(anchor_rgb), 6: None}
    keyed[6] = keyed[1]
    for n in (2, 3, 4, 5):
        raw_path = os.path.join(OUT, "%s_SF_f%d_raw.png" % (args.key, n))
        if not os.path.exists(raw_path):
            payload = os.path.join(OUT, "_sf_payload.json")
            with open(payload, "w", encoding="utf-8") as f:
                f.write(json.dumps({"model": "agnes-image-2.5-flash",
                                    "prompt": sf_prompt(actions[str(n)]),
                                    "size": "1K", "ratio": "1:1",
                                    "extra_body": {"image": [anchor_uri],
                                                   "response_format": "b64_json"}},
                                   ensure_ascii=False))
            print("帧 %d 生成中… %s" % (n, actions[str(n)][:30]), flush=True)
            t0 = time.time()
            raw = ag.gen_image(payload)
            if raw is None:
                print("  [FAIL] 帧 %d 三掷皆废" % n, flush=True)
                continue
            with open(raw_path, "wb") as f:
                f.write(raw)
            print("  OK 帧 %d (%.0fs)" % (n, time.time() - t0), flush=True)
            time.sleep(args.gap)
        keyed[n] = key_chain(Image.open(raw_path).convert("RGB"))

    # 朝向体检（提示性，L=朝左标准）
    sus = []
    for n in (1, 2, 3, 4, 5, 6):
        if keyed.get(n) is not None and ag.facing(keyed[n]) == "R":
            sus.append(n)
    print("朝向可疑格: %s（提示性，须目验终审）" % (sus or "无"), flush=True)

    # 规范化：全局唯一缩放 + 右缘+底缘锚定（机身钉死，火光向左伸缩不晃机身）
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
    valid = [c for c in cells if c is not None]
    if not valid:
        print("[FAIL] 无有效帧")
        sys.exit(2)
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
    sheet.convert("RGB").save(os.path.join(OUT, "%s_SF_attack_sheet_512.png" % args.key))

    # GIF（深底合成，10fps）+ 3×2 深底网格
    bgc = Image.new("RGBA", (FS, FS), (60, 60, 60, 255))
    comp = []
    for f in frames:
        b = bgc.copy()
        b.paste(f, (0, 0), f)
        comp.append(b.convert("RGB"))
    comp[0].save(os.path.join(OUT, "%s_SF_attack_anim.gif" % args.key), save_all=True,
                 append_images=comp[1:], duration=100, loop=0)
    cell = 212
    g = Image.new("RGB", (3 * cell, 2 * cell), (40, 44, 52))
    for i, f in enumerate(frames):
        fr = f.convert("RGBA").resize((cell, cell), Image.LANCZOS)
        g.paste(fr, (i % 3 * cell, i // 3 * cell), fr)
    g.save(os.path.join(OUT, "%s_SF_attack_cells_dark.png" % args.key))
    print("[export] %s_SF_attack_* 缺帧%s" % (args.key, missing or "无"), flush=True)


if __name__ == "__main__":
    main()
