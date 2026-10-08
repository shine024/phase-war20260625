# -*- coding: utf-8 -*-
"""fam44 单帧重掷（2026-10-07 用户裁定：逐帧链残留变形/长短炮管不一/摇摆
→ 哪帧不行只重掷那一帧，其余帧不动）

参考 = [白底锚, 上一帧]（与 _fam44_frame_chain.py 同构），动作 delta 同 FRAMES[n]；
--lock 追加针对性硬锁（治炮管长短不一/变形/帧间摇摆）。
重掷不落链——产出独立单帧，经目检挑选后由 _fam44_chain_norm.py 混装入卷。

用法:
    python tools/_fam44_frame_patch.py <key> --anchor <白底锚png> --frame 3 \
        --prev <上一帧png> [--lock "附加硬锁句子"] [--rolls 2 --roll-start 3]
产出（只落 staging）:
    <key>_patchR<r>_f<n>.png（2048² 单帧，未归一未入格）
"""
import argparse
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import img25_attack_gen as g
from _fam44_frame_chain import FRAMES, VIEW, FX

from PIL import Image


def build_patch_prompt(n, lock, extra):
    return (
        "第一张图是主体的身份锚定帧：" + VIEW + "均匀纯白色背景，无地面无影子。\n"
        "第二张图是这个动画的上一帧。请输出单张图：版式与第二张图完全一致——"
        "主体同大小、同画面位置、同离地高度、同纯白底；身份、配色、细节与视角同第一张图。\n"
        "唯一动作修改：" + FRAMES[n] + "除此之外画面里的一切与上一帧保持完全一致。\n"
        "【硬性·不变式】" + lock + "\n"
        "【硬性·特效】" + FX + "\n"
        "【硬性·无场景】没有地面、没有地平线、没有影子；除主体及其火光烟外画面里没有任何别的东西。\n"
        + ((extra + "\n") if extra else "") +
        "不要数字、文字、边框线、水印。主体完整不出画面。"
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("key")
    ap.add_argument("--anchor", required=True, help="白底正侧视身份锚")
    ap.add_argument("--frame", type=int, required=True, choices=[2, 3, 4, 5])
    ap.add_argument("--prev", required=True, help="上一帧 png（重掷的版式与细节基准）")
    ap.add_argument("--lock", required=True, help="针对性硬锁（治本帧的病）")
    ap.add_argument("--cells-json", default=None)
    ap.add_argument("--rolls", type=int, default=1)
    ap.add_argument("--roll-start", type=int, default=1)
    args = ap.parse_args()

    extra = None
    if args.cells_json:
        with open(args.cells_json, encoding="utf-8") as f:
            extra = json.load(f).get("extra")

    anchor = Image.open(args.anchor).convert("RGB")
    prev = Image.open(args.prev).convert("RGB")
    uri_anchor = g.data_uri(anchor)
    uri_prev = g.data_uri(prev)

    for roll in range(args.roll_start, args.roll_start + args.rolls):
        t0 = time.time()
        payload = os.path.join(g.OUT, "_patch_payload_%s_%d_%d.json" % (args.key, os.getpid(), args.frame))
        with open(payload, "w", encoding="utf-8") as f:
            f.write(json.dumps({"model": "agnes-image-2.5-flash",
                                "prompt": build_patch_prompt(args.frame, args.lock, extra),
                                "size": "2K", "ratio": "1:1",
                                "extra_body": {"image": [uri_anchor, uri_prev],
                                               "response_format": "b64_json"}},
                               ensure_ascii=False))
        raw = g.gen_image(payload)
        if raw is None:
            print("  patchR%d f%d 失败" % (roll, args.frame), flush=True)
            return
        fp = os.path.join(g.OUT, "%s_patchR%d_f%d.png" % (args.key, roll, args.frame))
        with open(fp, "wb") as f:
            f.write(raw)
        print("OK %s (%.0fs)" % (fp, time.time() - t0), flush=True)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
