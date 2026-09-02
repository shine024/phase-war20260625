#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""部署 32 张相位仪图标（docs/待生成相位仪图标_32张/ → assets/ui/instruments/）。

徽章风不透明底（影幕系列先例：无透明化处理，直接复制）。
校验：PIL 可开、1024x1024、非平凡内容（防 curl 半截文件）。
部署后运行：python tools/gen_ui_thumbs.py --only=instruments 补 _thumb128。
"""
import os
import sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(ROOT, "docs", "待生成相位仪图标_32张")
DST_DIR = os.path.join(ROOT, "assets", "ui", "instruments")

FILES = [
    "pi_helix_04", "pi_atlas_04",
    "pi_special_rage", "pi_special_void", "pi_special_aegis", "pi_special_nova",
    "pi_steel_01", "pi_steel_02", "pi_steel_03", "pi_steel_04", "pi_steel_05",
    "pi_flame_01", "pi_flame_02", "pi_flame_03", "pi_flame_04", "pi_flame_05",
    "pi_thunder_01", "pi_thunder_02", "pi_thunder_03", "pi_thunder_04", "pi_thunder_05",
    "pi_void_01", "pi_void_02", "pi_void_03", "pi_void_04", "pi_void_05",
    "pi_steelflame_01", "pi_thundersteel_01", "pi_voidflame_01",
    "pi_steelthunder_01", "pi_flamevoid_01",
    "pi_omega_01",
]


def main() -> int:
    ok = 0
    fail = 0
    for fname in FILES:
        src = os.path.join(SRC_DIR, fname + ".png")
        dst = os.path.join(DST_DIR, fname + ".png")
        if not os.path.exists(src):
            print(f"FAIL {fname}: source missing")
            fail += 1
            continue
        try:
            with Image.open(src) as img:
                img.verify()  # 完整性
            with Image.open(src) as img:
                w, h = img.size
                if w != 1024 or h != 1024:
                    print(f"FAIL {fname}: size {w}x{h} != 1024x1024")
                    fail += 1
                    continue
                # 非平凡内容：中心区域亮度方差（全黑/纯色图会被检出）
                rgb = img.convert("L").resize((64, 64))
                px = list(rgb.getdata())
                mean = sum(px) / len(px)
                var = sum((p - mean) ** 2 for p in px) / len(px)
                if var < 40:
                    print(f"FAIL {fname}: near-flat content (var={var:.0f})")
                    fail += 1
                    continue
            with open(src, "rb") as fsrc, open(dst, "wb") as fdst:
                fdst.write(fsrc.read())
            print(f"OK {fname}.png ({os.path.getsize(dst)} bytes, var={var:.0f})")
            ok += 1
        except Exception as e:
            print(f"FAIL {fname}: {e}")
            fail += 1
    print(f"\nDone: {ok} OK, {fail} FAIL")
    return 0 if fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
