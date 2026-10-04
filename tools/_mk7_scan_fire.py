# -*- coding: utf-8 -*-
"""扫描机腹尾焰：盒内 HSV hue 5-55 & S>60 的火色像素逐帧统计。"""
import io, os, sys, types
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_src = open(os.path.join(ROOT, "tools", "_mk6_mech_batch.py"), encoding="utf-8").read()
_src = _src.replace('if __name__ == "__main__":\n    main()', '')
_src = '\n'.join(l for l in _src.splitlines()
                 if not l.strip().startswith('sys.stdout = io.TextIOWrapper'))
mk = types.ModuleType('mk')
mk.__file__ = os.path.join(ROOT, "tools", "_mk6_mech_batch.py")
exec(compile(_src, '_mk6_mech_batch.py', 'exec'), mk.__dict__)

unit = sys.argv[1]
box = tuple(int(v) for v in sys.argv[2:6])  # x0 y0 x1 y1
_, _, atk = mk.load_frames(unit, "attack")
for i, fr in enumerate(atk):
    arr = np.asarray(fr)
    hsv = np.asarray(Image.fromarray(arr[:, :, :3].astype(np.uint8)).convert("HSV")).astype(int)
    x0, y0, x1, y1 = box
    m = (hsv[:, :, 0] >= 5) & (hsv[:, :, 0] <= 55) & (hsv[:, :, 1] > 60) & (arr[:, :, 3] > 40)
    mm = np.zeros_like(m); mm[y0:y1, x0:x1] = True
    m &= mm
    if m.any():
        ys, xs = np.nonzero(m)
        print("f%-2d n=%-5d bbox=(%d,%d)-(%d,%d)" % (i, len(ys), xs.min(), ys.min(), xs.max(), ys.max()))
