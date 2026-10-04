# -*- coding: utf-8 -*-
"""B4 污染案恢复：relight 双图参考（FT-17 坦克）内容注入步兵/虚空场景 → 全部重掷。
亮度恢复只走 gain 收敛循环（无参考注入）；4 轮仍不过门才用【单图】relight（无第二图）再 gain。
用法: python tools/_b4_recover_c.py
"""
import importlib.util, io, json, os, sys
_KEEP = sys.stdout  # 子模块顶层会重包 stdout，持引用防 GC 关缓冲
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
from PIL import Image
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAGE = os.path.join(ROOT, ".godot", "b4_card_staging")

C = ["fe_helix_phantom", "flame_raider_advanced", "thunter_sniper_basic", "thunter_sniper_advanced",
     "thunter_sniper_expert", "thunter_striker_advanced", "void_mage_advanced",
     "void_stealth_basic", "void_stealth_advanced", "void_stealth_expert", "ww1_inf_mp18_x"]


def load(name, path):
    """加载工具模块但剔除其顶层的 stdout 重包行（多模块连环重包会互相关掉共享缓冲）。"""
    import types
    src = open(path, encoding="utf-8").read()
    lines = [ln for ln in src.splitlines() if "sys.stdout = io.TextIOWrapper" not in ln]
    mod = types.ModuleType(name)
    mod.__file__ = path
    exec(compile("\n".join(lines), path, "exec"), mod.__dict__)
    return mod


b4 = load("b4c_gen", os.path.join(ROOT, "tools", "_b4_card_gen.py"))
_KEEP2 = sys.stdout  # b4 的 wrapper；不持会被下一模块 import 链 GC 掉并关掉共享缓冲
gl = load("b4c_gain", os.path.join(ROOT, "tools", "_b4_gain_loop.py"))
_KEEP3 = sys.stdout

MP18_POSITIVE = ("第一张图是参考卡图。把它重画成一张新的游戏卡图立绘：一战风暴步兵，钢盔、军大衣、绑腿长靴，"
                 "双手持MP18冲锋枪举至肩瞄准，全身完整居中，四周留约百分之十白色边距。\n"
                 "背景为纯白无缝影棚背景（seamless pure white studio background），整幅平涂纯白。\n"
                 "低饱和冷灰蓝钢色调，主体完全受光、照明充足，材质细节清晰可读。\n"
                 "厚涂插画风格（thick painterly illustration），无黑色描边。画面中没有文字、水印、边框。")

SINGLE_RELIGHT = ("第一张图是一张构图正确的游戏卡图立绘，但被画得过于昏暗。请输出一张新图：\n"
                  "【保持】完全保持第一张图的视角、构图、全部部件、姿态与大小，主体逐部件重合；"
                  "背景保持整幅纯白平涂。\n"
                  "【只修光照】主体完全受光、照明充足，高光、中间调、暗部层次分明，材质细节清晰可读；"
                  "色相保持第一张图的涂装身份。\n"
                  "【风格】厚涂插画，无黑色描边。画面中没有文字、水印、边框。")


def gain_loop_img(im):
    """对单张图跑 gain 收敛循环，返回 (图, ok, info)。"""
    a = np.asarray(im.convert("RGB")).astype(float)
    ok, info = gl.gate(a.astype(int))
    for tgt in gl.TARGETS:
        if ok:
            break
        _, body = gl.body_mask(a)
        m = float(a[body].mean())
        gain = max(1.0, min(tgt / max(m, 1.0), 1.35))
        if gain <= 1.01:
            break
        a = np.clip(a * gain, 0, 255)
        a[a.min(axis=2) >= gl.WHITE_SNAP] = 255.0
        ok, info = gl.gate(a.astype(int))
    return Image.fromarray(a.astype(np.uint8)), ok, info


def single_relight(p):
    im = Image.open(p).convert("RGB")
    payload = {"model": b4.MODEL, "prompt": SINGLE_RELIGHT, "size": "1024x1024",
               "extra_body": {"image": [b4.uri_of(p)], "response_format": "b64_json"}}
    raw = b4.gen(payload, "srelight")
    if not raw:
        return None
    import io as _io
    return Image.open(_io.BytesIO(raw)).convert("RGB")


def main():
    for cid in C:
        for suf in ("_raw.png", "_raw_dark1.png", "_raw_dark2.png", "_raw_left.png"):
            f = os.path.join(STAGE, cid + suf)
            if os.path.isfile(f):
                os.remove(f)
        # 1) 重掷
        if cid == "ww1_inf_mp18_x":
            b4.run_case(cid, MP18_POSITIVE, "assets/card_icons/player/ww1_inf_enfield.png")
        elif cid in b4.REGEN:
            ref, subject, accent = b4.REGEN[cid]
            b4.run_case(cid, b4.CONVERT.format(subject=subject, accent=accent),
                        ref.replace("res://", "") if ref else None)
        else:
            fam, _, tier = cid.rpartition("_")
            b4.run_case(cid, b4.plat_prompt(cid), None)
        p = os.path.join(STAGE, cid + "_raw.png")
        if not os.path.isfile(p):
            print("[FAIL] %s 重掷无果" % cid, flush=True)
            continue
        # 2) gain 循环（无注入）
        im, ok, info = gain_loop_img(Image.open(p))
        if not ok:
            # 3) 单图 relight 兜底（无第二图，零注入面）再 gain
            im2 = single_relight(p)
            if im2 is not None:
                im, ok, info = gain_loop_img(im2)
        im.save(p)
        print("[%s] %s %s" % ("OK" if ok else "MISS", cid, json.dumps(info)), flush=True)
    print("恢复轮完成", flush=True)


if __name__ == "__main__":
    main()
