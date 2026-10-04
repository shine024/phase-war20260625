# -*- coding: utf-8 -*-
"""MK7 枪口读数图：idle f0 + attack 开火帧(默认f3) 放大到 320px，32px 网格+坐标标注。
用法: python tools/_mk7_zoom.py out.png u1,u2,... [fire_frame]
"""
import io
import os
import sys
import types

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STG = os.path.join(ROOT, ".godot", "unit_review", "mk6_staging")

_src = open(os.path.join(ROOT, "tools", "_mk6_mech_batch.py"), encoding="utf-8").read()
_src = _src.replace('if __name__ == "__main__":\n    main()', '')
_src = '\n'.join(l for l in _src.splitlines()
                 if not l.strip().startswith('sys.stdout = io.TextIOWrapper'))
mk = types.ModuleType('mk')
mk.__file__ = os.path.join(ROOT, "tools", "_mk6_mech_batch.py")
exec(compile(_src, '_mk6_mech_batch.py', 'exec'), mk.__dict__)

CELL = 320
SC = CELL / 256


def zoom_cell(fr):
    c = Image.new("RGB", (CELL, CELL), (28, 30, 36))
    d = ImageDraw.Draw(c)
    z = fr.resize((CELL, CELL), Image.NEAREST)
    c.paste(z, (0, 0), z)
    for v in range(0, 257, 32):
        px = int(v * SC)
        d.line((px, 0, px, CELL - 1), fill=(70, 74, 84))
        d.line((0, px, CELL - 1, px), fill=(70, 74, 84))
        if v < 256:
            d.text((px + 2, 2), str(v), fill=(160, 170, 190))
            d.text((2, px + 2), str(v), fill=(160, 170, 190))
    return c


def main():
    out = sys.argv[1]
    units = sys.argv[2].split(",")
    fi = int(sys.argv[3]) if len(sys.argv) > 3 else 3
    g = Image.new("RGB", (CELL * 2 + 8, (CELL + 18) * len(units)), (18, 20, 24))
    d = ImageDraw.Draw(g)
    for ri, u in enumerate(units):
        y = ri * (CELL + 18)
        _, _, idle = mk.load_frames(u, "idle")
        _, _, atk = mk.load_frames(u, "attack")
        d.text((4, y + 3), "%s   idle f0 | attack f%d" % (u, fi), fill=(255, 220, 120))
        g.paste(zoom_cell(idle[0]), (0, y + 16))
        g.paste(zoom_cell(atk[min(fi, len(atk) - 1)]), (CELL + 8, y + 16))
    g.save(os.path.join(STG, out))
    print("[zoom] %s" % out)


if __name__ == "__main__":
    main()
