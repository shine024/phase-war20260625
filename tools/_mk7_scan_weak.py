# -*- coding: utf-8 -*-
"""扫描残渣：attack 每帧 alpha>8 且在 idle 并集+dilate2 之外的像素 bbox。"""
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


def dilate(m, r):
    for _ in range(r):
        m2 = m.copy()
        m2[1:, :] |= m[:-1, :]; m2[:-1, :] |= m[1:, :]
        m2[:, 1:] |= m[:, :-1]; m2[:, :-1] |= m[:, 1:]
        m = m2
    return m


UNITS = sys.argv[1:] or [
    "drop_thunder_field", "fut_nano_drone", "mod_stryker_m2",
    "fe_aether_hover_cavalry", "fe_aether_swarm_queen", "fe_frontier_mixed_company",
    "fe_quantum_mobile_base", "cold_bradley",
]
for u in UNITS:
    _, _, idl = mk.load_frames(u, "idle")
    solid = dilate(np.zeros((256, 256), bool), 2)
    for f in idl:
        solid |= np.asarray(f)[:, :, 3] > 40
    solid = dilate(solid, 2)
    _, _, atk = mk.load_frames(u, "attack")
    print("── %s" % u)
    for i, fr in enumerate(atk):
        a = np.asarray(fr)[:, :, 3]
        m = (a > 8) & ~solid
        if m.any():
            ys, xs = np.nonzero(m)
            print("  f%-2d n=%-5d bbox=(%d,%d)-(%d,%d)" % (
                i, len(ys), xs.min(), ys.min(), xs.max(), ys.max()))
