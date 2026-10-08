# -*- coding: utf-8 -*-
"""炮类单血统 rest 帧手术 v2（2026-10-07「火炮 要重新生成」配套）。

链卷实证：锚本体与链帧异血（防盾形状/轮辐样式结构不同），格 1/6 必须换血。
v1 取 f2 杀炮膛辉光 → bore 白缺口（辉光本来就是 bore 盘本体，杀了无物可留）。
v2 改取 **f5（火光全灭+完全复位帧）**：炮口放大实证 bore 干净深孔、口罩环完整，
去 FX = 只杀炮口烟团（x<罩环左缘，浅灰低饱和谓词），零重建。

产格 1/6 = f5 去烟（同血统 rest），格 2-5 = 原链帧 → R{#}b 整版。
后续走 _fam44_gun_wheel_norm.py（枢轴自动变为链血统轮；循环缝 f5烟→rest
与 mark4 先例一致，8fps 下读作烟消散）。

用法: python tools/_fam44_gun_rest_surgery.py <key> <chainR#> [--ring-x 129]
产出: <key>_chainR{#}b_sheet_832.png + _{key}_restR{#}.png（白底 rest 帧）
"""
import io
import os
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
CELL = 832


def main():
    argv = sys.argv[1:]
    key, roll = argv[0], argv[1]
    ring_x = 129
    donor = 5
    if "--ring-x" in argv:
        ring_x = int(argv[argv.index("--ring-x") + 1])
    if "--donor" in argv:
        donor = int(argv[argv.index("--donor") + 1])

    src = os.path.join(OUT, "%s_chainR%s_sheet_832.png" % (key, roll))
    sh = Image.open(src).convert("RGB")
    assert sh.size == (CELL * 3, CELL * 2), sh.size

    # 供体格（1-based）：f5=下排中（火光全灭）；f4=下排左（衰减帧，烟不触环——首选）
    di = donor - 1
    dc, dr = di % 3, di // 3
    fd = sh.crop((dc * CELL, dr * CELL, (dc + 1) * CELL, (dr + 1) * CELL))
    a = np.asarray(fd).copy()

    # 炮口烟团：全在罩环左缘以左。浅灰低饱和谓词；深铁色（炮管）禁触。
    # 罩环左缘自动检测：炮管 y 带内从左往右第一根含 ≥3 深铁色像素的列。
    y0, y1 = 280, 620
    band = a[330:420, :200].astype(int)
    dlum = band.mean(axis=2)
    darkcols = (dlum < 80).sum(axis=0)  # 真铁色轮廓（烟影 lum 80-110 不中）
    muzzle_left = next((x for x in range(200) if darkcols[x] >= 4), ring_x)
    x1 = muzzle_left - 4
    print("[surgery] donor=f%d 罩环左缘自动检测 x=%d（CLI 提示值 %d）" % (donor, muzzle_left, ring_x))
    roi = a[y0:y1, :x1].astype(int)
    lum = roi.mean(axis=2)
    sat = roi.max(axis=2) - roi.min(axis=2)
    dark = lum < 100
    kill = (lum > 120) & (sat < 80) & ~dark
    kd = kill.copy()
    for dy in (-2, -1, 0, 1, 2):
        for dx in (-2, -1, 0, 1, 2):
            kd |= np.roll(np.roll(kill, dy, axis=0), dx, axis=1)
    kd &= ~dark
    a[y0:y1, :x1][kd] = (255, 255, 255)
    n_lost = int((dark & kd).sum())
    assert n_lost == 0, "手术误伤深铁色 %d px" % n_lost

    rest = Image.fromarray(a)
    rest.save(os.path.join(OUT, "_%s_restR%s.png" % (key, roll)))
    print("[surgery] f%d 去烟: 杀 %d px（dark 误伤 0）→ _%s_restR%s.png"
          % (donor, int(kd.sum()), key, roll))

    # 组 R{#}b 整版: 格1/6 = rest，格2-5 = 原链帧
    out = Image.new("RGB", (CELL * 3, CELL * 2), (255, 255, 255))
    for i in range(6):
        c, rr = i % 3, i // 3
        if i in (0, 5):
            out.paste(rest, (c * CELL, rr * CELL))
        else:
            out.paste(sh.crop((c * CELL, rr * CELL, (c + 1) * CELL, (rr + 1) * CELL)),
                      (c * CELL, rr * CELL))
    dst = os.path.join(OUT, "%s_chainR%sb_sheet_832.png" % (key, roll))
    out.save(dst)
    print("[done] %s" % dst)


if __name__ == "__main__":
    main()
