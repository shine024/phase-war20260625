# -*- coding: utf-8 -*-
"""fam44 逐帧链 v2·生图层格子约束（2026-10-07 用户问「有用格子约束么」）

v1 每帧自由单张（无格子上下文）→ 尺寸/站位漂移。
v2 每步把「已完成帧的程序拼装版」整版喂回（image[1]），目标格留纯白：
    模型照邻格真实帧的大小/底缘/格内位置往目标格填下一帧——格子约束来自版面本身。
响应裁出目标格（比例坐标），拼装与 GIF 全代码。

用法:
    python tools/_fam44_frame_chain_v2.py <key> --anchor <白底正侧视png> [--cells-json <extra锁>] [--rolls N --roll-start N]
产出:
    <key>_chain2R<r>_f<n>.png / <key>_chain2R<r>_sheet_832.png / <key>_chain2R<r>_anim.gif
"""
import argparse
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import img25_attack_gen as g

from PIL import Image

FRAMES = {
    2: "预备：炮口出现一个很小的橙色圆形火点；",
    3: "开火！炮口焰在炮口位置爆发，明亮但不遮掩机身；",
    4: "火光衰减成贴在炮口上的一小团收敛圆润的火光；",
    5: "车体整体沿画面横轴向右（炮口反方向）平移一小段，大小与离地高度完全不变，炮口挂着少量余烟；",
}

VIEW = ("严格平面正侧视：只看到主体左侧面，任何朝上的表面一律不可见；"
        "车体前后两端是垂直切面；轮子/负重轮排成一条水平线且每个都是正圆；"
        "主体头尾长轴与画面横轴完全平行。")

FX = ("没有弹道、没有弹丸、没有飞行物、没有光束——只有炮口火光和烟；"
      "火光烟只贴在炮口位置且完整在本格内部，绝不触碰格子边缘；"
      "烟朝画面左侧（炮口方向）飘散或原地消散，绝不向车尾方向蔓延。")


def build_prompt(n, extra):
    prev_rc = divmod(n - 1 - 1, 3)  # 上一帧的 (row, col)
    tgt_rc = divmod(n - 1, 3)
    return (
        "第一张图是主体的身份锚定帧：" + VIEW + "均匀纯白色背景，无地面无影子。\n"
        "第二张图是一张 2 行 3 列的六格动画雪碧图的中间状态：已完成的格子里是同一个主体的连续动作帧，"
        "只有第 %d 行第 %d 列的格子是空白待填。请输出整张同版式雪碧图："
        "把第 %d 行第 %d 列格子里的主体原样复制进第 %d 行第 %d 列的空白格"
        "——与它完全相同的大小、相同的底缘离格底高度、相同的格内位置、相同的纯白底，"
        "然后只做一处动作修改：" % (prev_rc[0] + 1, prev_rc[1] + 1,
                                    prev_rc[0] + 1, prev_rc[1] + 1,
                                    tgt_rc[0] + 1, tgt_rc[1] + 1)
        + FRAMES[n] + "除此之外目标格内容与上一格保持完全一致；其余五个格子与白色区域一字不改地原样保留。\n"
        "【硬性·视角】" + VIEW + "\n"
        "【硬性·特效】" + FX + "\n"
        "【硬性·无场景】没有地面、没有地平线、没有影子；除主体及其火光烟外画面里没有任何别的东西。\n"
        + ((extra + "\n") if extra else "") +
        "不要数字、文字、边框线、水印。每格主体完整不出本格。"
    )


def crop_cell(sheet_img, n):
    w, h = sheet_img.size
    row, col = divmod(n - 1, 3)
    return sheet_img.crop((round(col * w / 3), round(row * h / 2),
                           round((col + 1) * w / 3), round((row + 1) * h / 2)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("key")
    ap.add_argument("--anchor", required=True)
    ap.add_argument("--cells-json", default=None)
    ap.add_argument("--rolls", type=int, default=1)
    ap.add_argument("--roll-start", type=int, default=1)
    args = ap.parse_args()

    extra = None
    if args.cells_json:
        with open(args.cells_json, encoding="utf-8") as f:
            extra = json.load(f).get("extra")

    anchor = Image.open(args.anchor).convert("RGB")
    uri_anchor = g.data_uri(anchor)
    CELL = 832

    for roll in range(args.roll_start, args.roll_start + args.rolls):
        t0 = time.time()
        frames = {1: anchor.copy(), 6: anchor.copy()}
        for n in range(2, 6):
            # 程序拼装当前进度版：已完成帧入格，目标格纯白
            ctx = Image.new("RGB", (CELL * 3, CELL * 2), (255, 255, 255))
            for k in range(1, n):
                ctx.paste(frames[k].resize((CELL, CELL), Image.LANCZOS),
                          ((divmod(k - 1, 3)[1]) * CELL, divmod(k - 1, 3)[0] * CELL))
            payload = os.path.join(g.OUT, "_chain2_payload_%s_%d_%d.json" % (args.key, os.getpid(), n))
            with open(payload, "w", encoding="utf-8") as f:
                f.write(json.dumps({"model": "agnes-image-2.5-flash",
                                    "prompt": build_prompt(n, extra),
                                    "size": "2K", "ratio": "3:2",
                                    "extra_body": {"image": [uri_anchor, g.data_uri(ctx)],
                                                   "response_format": "b64_json"}},
                                   ensure_ascii=False))
            raw = g.gen_image(payload)
            if raw is None:
                print("  chain2R%d f%d 失败" % (roll, n), flush=True)
                return
            import io
            out_full = Image.open(io.BytesIO(raw)).convert("RGB")
            cell = crop_cell(out_full, n).resize((CELL, CELL), Image.LANCZOS)
            fp = os.path.join(g.OUT, "%s_chain2R%d_f%d.png" % (args.key, roll, n))
            cell.save(fp)
            frames[n] = cell
            print("  f%d OK (%.0fs)" % (n, time.time() - t0), flush=True)

        sheet = Image.new("RGB", (CELL * 3, CELL * 2), (255, 255, 255))
        gf = []
        for idx in range(6):
            im = frames[idx + 1].resize((CELL, CELL), Image.LANCZOS)
            sheet.paste(im, ((idx % 3) * CELL, (idx // 3) * CELL))
            gf.append(im.resize((330, 330), Image.LANCZOS))
        base = os.path.join(g.OUT, "%s_chain2R%d" % (args.key, roll))
        sheet.save(base + "_sheet_832.png")
        gf[0].save(base + "_anim.gif", save_all=True, append_images=gf[1:], duration=125, loop=0)
        print("OK %s_sheet_832.png (%.0fs)" % (base, time.time() - t0), flush=True)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
