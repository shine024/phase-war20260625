# -*- coding: utf-8 -*-
"""fam44 逐帧 img2img 链（2026-10-07 用户拍板「试生图」：路线③ temporal coherence）

六格合并的阶段2 已实证自带 3/4 先验（R15/R16 对照），本脚本绕开合并：
每帧单张 img2img，参考 = [身份锚(白底正侧视), 上一帧]；只让模型改一处动作。
格1/格6 = 锚本体（首尾闭合与身份零漂移由代码保证），只生成格2-5。
产出自组 3×2 整版 832 + GIF（全部代码拼装，不经生图合并）。

用法:
    python tools/_fam44_frame_chain.py <key> --anchor <白底正侧视png> \
        [--cells-json <extra锁>] [--rolls N --roll-start N]

产出（只落 staging）:
    <key>_chainR<r>_f<n>.png / <key>_chainR<r>_sheet_832.png / <key>_chainR<r>_anim.gif
"""
import argparse
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import img25_attack_gen as g  # data_uri/gen_image/OUT

from PIL import Image

# 逐帧增量动作（与 img25_attack_gen.DEFAULT_CELLS v2 同源；格1/6=锚本体不生成）
FRAMES = {
    2: "预备：炮口出现一个很小的橙色圆形火点；",
    3: "开火！炮口焰在炮口位置爆发，明亮但不遮掩机身；",
    4: "火光衰减成贴在炮口上的一小团收敛圆润的火光；",
    5: "车体整体沿画面横轴向右（炮口反方向）平移一小段，大小与离地高度完全不变，炮口挂着少量余烟；",
}

VIEW = ("严格平面正侧视：只看到主体左侧面，任何朝上的表面（顶面、顶盖、上表面）一律不可见；"
        "车体前后两端是垂直切面；轮子/负重轮排成一条水平线且每个都是正圆；"
        "主体头尾长轴与画面横轴完全平行。")

FX = ("没有弹道、没有弹丸、没有飞行物、没有光束——只有炮口火光和烟；"
      "火光烟只贴在炮口位置且完整在画面内部，绝不触碰画面边缘；"
      "烟朝画面左侧（炮口方向）飘散或原地消散，绝不向车尾方向蔓延。")


def build_delta_prompt(delta, extra):
    return (
        "第一张图是主体的身份锚定帧：" + VIEW + "均匀纯白色背景，无地面无影子。\n"
        "第二张图是这个动画的上一帧。请输出单张图：版式与第二张图完全一致——"
        "主体同大小、同画面位置、同离地高度、同纯白底；身份、配色、细节与视角同第一张图。\n"
        "唯一动作修改：" + delta + "除此之外画面里的一切与上一帧保持完全一致。\n"
        "【硬性·特效】" + FX + "\n"
        "【硬性·无场景】没有地面、没有地平线、没有影子；除主体及其火光烟外画面里没有任何别的东西。\n"
        + ((extra + "\n") if extra else "") +
        "不要数字、文字、边框线、水印。主体完整不出画面。"
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("key")
    ap.add_argument("--anchor", required=True, help="白底正侧视身份锚（格1/6 本体）")
    ap.add_argument("--cells-json", default=None, help="复用逐格脚本 JSON 里的 extra（身份硬锁）")
    ap.add_argument("--rolls", type=int, default=1)
    ap.add_argument("--roll-start", type=int, default=1)
    args = ap.parse_args()

    extra = None
    frames = FRAMES
    if args.cells_json:
        with open(args.cells_json, encoding="utf-8") as f:
            data = json.load(f)
        extra = data.get("extra")
        if data.get("frames"):
            frames = {int(k): v for k, v in data["frames"].items()}

    anchor = Image.open(args.anchor).convert("RGB")
    uri_anchor = g.data_uri(anchor)

    for roll in range(args.roll_start, args.roll_start + args.rolls):
        t0 = time.time()
        imgs = {1: anchor.copy(), 6: anchor.copy()}
        prev_img = anchor
        for n in range(2, 6):
            uri_prev = g.data_uri(prev_img)
            payload = os.path.join(g.OUT, "_chain_payload_%s_%d_%d.json" % (args.key, os.getpid(), n))
            with open(payload, "w", encoding="utf-8") as f:
                f.write(json.dumps({"model": "agnes-image-2.5-flash",
                                    "prompt": build_delta_prompt(frames[n], extra),
                                    "size": "2K", "ratio": "1:1",
                                    "extra_body": {"image": [uri_anchor, uri_prev],
                                                   "response_format": "b64_json"}},
                                   ensure_ascii=False))
            raw = g.gen_image(payload)
            if raw is None:
                print("  chainR%d f%d 失败" % (roll, n), flush=True)
                return
            fp = os.path.join(g.OUT, "%s_chainR%d_f%d.png" % (args.key, roll, n))
            with open(fp, "wb") as f:
                f.write(raw)
            prev_img = Image.open(fp).convert("RGB")
            imgs[n] = prev_img
            print("  f%d OK (%.0fs)" % (n, time.time() - t0), flush=True)

        # 代码拼装 3×2 整版 832（不经生图合并）
        CELL = 832
        sheet = Image.new("RGB", (CELL * 3, CELL * 2), (255, 255, 255))
        for idx in range(6):
            n = idx + 1
            c, r = idx % 3, idx // 3
            sheet.paste(imgs[n].resize((CELL, CELL), Image.LANCZOS), (c * CELL, r * CELL))
        sp = os.path.join(g.OUT, "%s_chainR%d_sheet_832.png" % (args.key, roll))
        sheet.save(sp)

        gif_frames = [imgs[n].resize((330, 330), Image.LANCZOS) for n in range(1, 7)]
        gp = os.path.join(g.OUT, "%s_chainR%d_anim.gif" % (args.key, roll))
        gif_frames[0].save(gp, save_all=True, append_images=gif_frames[1:],
                           duration=125, loop=0)
        print("OK %s (%.0fs, 生成4帧+代码拼装)" % (sp, time.time() - t0), flush=True)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
