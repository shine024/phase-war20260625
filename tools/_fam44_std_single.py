# -*- coding: utf-8 -*-
"""fam44 两段式·阶段1：标准单张（2026-10-07 用户定流程）

先 img2img 生成一张「标准单张」（身份+正侧视基准，无特效无格子），
视觉检查迭代通过后，再作为身份锚喂给 img25_attack_gen.py 做格子合并
（阶段2：--anchor 指向本脚本产出）。

用法:
    python tools/_fam44_std_single.py <key> --cells-json <json> [--rolls N --roll-start N]

产出（只落 staging）:
    <key>_std_R<n>.png
"""
import argparse
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import img25_attack_gen as g  # 复用 data_uri/gen_image/KEYS/OUT


def build_std_prompt(subject, extra, pose):
    return (
        "第一张图是主体的身份锚定帧（唯一真身）。请输出单张图：就是这同一个主体，"
        "与锚定帧完全同身份、同体型、同比例、同配色、同涂装、同细节、同武器。\n"
        "【硬性·视角＝严格平面正侧视】只看到主体的左侧面：主体任何朝上的表面（顶面、顶盖、上表面）一律不可见；"
        "车体前后两端是垂直切面，没有可见的斜切面或纵深面；轮子/负重轮排成一条水平线且每个轮子都是正圆（不是椭圆）；"
        "主体头尾长轴与画面横轴完全平行，高度方向与画面纵轴完全平行，相机与主体同高、无俯仰、透视深度为零"
        "（机械制图左视图）。\n"
        "【硬性·丢弃锚定帧透视】第一张图只取它的平面轮廓、结构与配色身份；"
        "若锚定帧本身带任何透视（可见顶面、斜切面、椭圆轮），一律忽略并按上一条平面规则修正后输出，"
        "不要照抄锚定帧的视角。\n"
        "姿态：" + pose + "。无火光、无烟、无任何特效。\n"
        "【硬性·无场景】画面是悬在均匀纯色背景前的主体本体：没有地面、没有地平线、没有影子；"
        "除主体外，画面里没有任何别的东西。\n"
        + ((extra or "") + "\n" if extra else "") +
        "主体完整居中，四周留出边距。不要数字、文字、边框线、水印。"
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("key")
    ap.add_argument("--subject", required=True)
    ap.add_argument("--cells-json", default=None, help="复用逐格脚本里的 extra（身份/视角硬锁条款）")
    ap.add_argument("--pose", default="中性待发姿态，与锚定帧完全一致")
    ap.add_argument("--rolls", type=int, default=2)
    ap.add_argument("--roll-start", type=int, default=1)
    args = ap.parse_args()

    extra = None
    if args.cells_json:
        with open(args.cells_json, encoding="utf-8") as f:
            extra = json.load(f).get("extra")

    anchor_path = os.path.join(g.OUT, args.key + "_anchor_raw.png")
    if not os.path.exists(anchor_path):
        print("缺锚定帧:", anchor_path)
        sys.exit(1)
    from PIL import Image
    anchor_img = Image.open(anchor_path).convert("RGB")
    uri = g.data_uri(anchor_img)

    payload = os.path.join(g.OUT, "_std_payload_%s_%d.json" % (args.key, os.getpid()))
    with open(payload, "w", encoding="utf-8") as f:
        f.write(json.dumps({"model": "agnes-image-2.5-flash",
                            "prompt": build_std_prompt(args.subject, extra, args.pose),
                            "size": "2K", "ratio": "1:1",
                            "extra_body": {"image": [uri], "response_format": "b64_json"}},
                           ensure_ascii=False))
    print("标准单张生成中… 共 %d 掷" % args.rolls, flush=True)
    for roll in range(args.roll_start, args.roll_start + args.rolls):
        t0 = time.time()
        raw = g.gen_image(payload)
        if raw is None:
            print("  第 %d 掷失败" % roll, flush=True)
            continue
        out = os.path.join(g.OUT, "%s_std_R%d.png" % (args.key, roll))
        with open(out, "wb") as f:
            f.write(raw)
        print("OK %s (%.0fs)" % (out, time.time() - t0), flush=True)


if __name__ == "__main__":
    main()
