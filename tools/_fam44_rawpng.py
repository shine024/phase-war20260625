# -*- coding: utf-8 -*-
"""原始 PNG 解码器（stdlib zlib，绕过 PIL 解码路径）。

2026-10-07 实证：本机 PIL 的 PNG 解码在冷堆新进程里会把 2496 宽 sheet 的
右列（格3/格6）解成黑/白垃圾——盘上字节经 zlib 直解完全正确（md5 各构建收敛
=确定性编码+内容一致）。凡 PIL 读大图出现「整块纯黑/纯白」且 frac=1.000，
一律先用本解码器复核，再定结论。PIL 的编码路径已证无损（见上）。
"""
import struct
import zlib

import numpy as np


def raw_decode_rgb(path):
    """返回 HxWx3 uint8（仅支持 8bit RGB/RGBA PNG；pal8 需先经 PIL 转 RGB 落盘）。"""
    data = open(path, "rb").read()
    pos = 8
    idat = b""
    w = h = bd = ct = None
    while pos < len(data):
        ln = struct.unpack(">I", data[pos:pos + 4])[0]
        typ = data[pos + 4:pos + 8]
        if typ == b"IHDR":
            w, h, bd, ct = struct.unpack(">IIBB", data[pos + 8:pos + 18])
        elif typ == b"IDAT":
            idat += data[pos + 8:pos + 8 + ln]
        pos += 12 + ln
    assert bd == 8 and ct in (2, 6), "unsupported png bd=%s ct=%s" % (bd, ct)
    bpp = 3 if ct == 2 else 4
    stride = w * bpp
    raw = zlib.decompress(idat)
    out = bytearray()
    prev = bytearray(stride)
    pos2 = 0
    for _y in range(h):
        f = raw[pos2]
        pos2 += 1
        line = bytearray(raw[pos2:pos2 + stride])
        pos2 += stride
        if f == 1:
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 255
        elif f == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif f == 3:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 255
        elif f == 4:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                c = prev[i - bpp] if i >= bpp else 0
                b = prev[i]
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        out += line
        prev = line
    arr = np.frombuffer(bytes(out), dtype=np.uint8).reshape(h, w, bpp)
    return arr[..., :3].copy()


def cell_metrics(a, x_off=0, y_off=0, dark=180, gray_tip=False):
    """单格暗内容量测：bbox / 炮管尖（最左实暗像素）/ 车头前沿。
    gray_tip=True 时炮管尖只取低饱和像素（|R-B|<25），排除橙色焰。"""
    ai = a.astype(np.int32)
    lum = (ai[..., 0] * 299 + ai[..., 1] * 587 + ai[..., 2] * 114) // 1000
    ys, xs = np.where(lum < dark)
    if gray_tip:
        m2 = (lum < 150) & (np.abs(ai[..., 0] - ai[..., 2]) < 25)
        ys2, xs2 = np.where(m2)
    else:
        ys2, xs2 = np.where(lum < 150)
    k = np.lexsort((ys2, xs2))[0]
    lb = lum[ys.max() - 120:ys.max() - 40]
    hrow = np.where(lb < dark)[1]
    return {
        "bbox": (int(xs.min()) + x_off, int(xs.max()) + x_off,
                 int(ys.min()) + y_off, int(ys.max()) + y_off),
        "tip": (int(xs2[k]) + x_off, int(ys2[k]) + y_off),
        "hull": int(hrow.min()) + x_off if len(hrow) else -1,
    }


if __name__ == "__main__":
    import sys
    sys.stdout.reconfigure(encoding="utf-8")
    a = raw_decode_rgb(".godot/unit_review/img25_staging/ww1_mark4_chainMix3_n_sheet_832.png")
    CELL = 832
    print("cell | bbox x0-x1 y0-y1 | tip(x,y) | hull |")
    res = []
    for i in range(6):
        c, r = i % 3, i // 3  # 格序：1-3 上行、4-6 下行；c=列 i%3, r=行 i//3
        m = cell_metrics(a[r * CELL:(r + 1) * CELL, c * CELL:(c + 1) * CELL],
                         c * CELL, r * CELL, gray_tip=(i == 2))
        res.append(m)
        print(i + 1, "| x%d-%d y%d-%d" % m["bbox"], "| tip=(%d,%d)" % m["tip"],
              "| hull x%d" % m["hull"])
    # 车身一致性：格2/4/5 与格1 的 tip/hull 对照
    for pair, name in [((1, 3), "c2~c4"), ((1, 4), "c2~c5")]:
        same = res[pair[0]]["tip"] == res[pair[1]]["tip"] and res[pair[0]]["hull"] == res[pair[1]]["hull"]
        print(name, "metrics identical:", same)
    print("c1 vs c2  tip:", res[0]["tip"], res[1]["tip"], " hull:", res[0]["hull"], res[1]["hull"])
