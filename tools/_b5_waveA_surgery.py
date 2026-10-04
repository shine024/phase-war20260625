# -*- coding: utf-8 -*-
"""B5 WaveA 像素手术（2026-10-04）：三案现役卷修复，全走备份→手术→网格回验。
1. ww2_fort_bunker  idle 去灯：每帧顶部青蓝能量信标+吊杆按色域摘除（用户主诉"待机不要有灯光"）
2. mod_inf_marine   idle 去地渍：脚底低饱和灰白拖抹按"底部区域+低饱和+高亮"摘除（主诉"地面"）
3. cold_spetsnaz / mod_apache_e  idle 微呼吸合成：摆幅过大（主诉"待机摆动太大"）——以 f0 为基，垂直微缩1px+平移1px 的 8 帧微呼吸环，counts 不变
备份 .godot/art_backup_b5_waveA_20261004/（md5 清单同存）。幂等不保证——重跑前先还原备份。
"""
import hashlib
import io
import os
import shutil
import sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UA = os.path.join(ROOT, "assets", "effects", "unit_anims")
BK = os.path.join(ROOT, ".godot", "art_backup_b5_waveA_20261004")
PROBE = os.path.join(ROOT, ".godot", "unit_review", "b5_probe")
FS = 256


def backup(rel):
    src = os.path.join(ROOT, rel)
    dst = os.path.join(BK, rel)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    if os.path.isfile(src) and not os.path.isfile(dst):
        shutil.copy2(src, dst)
        h = hashlib.md5(open(src, "rb").read()).hexdigest()
        with open(dst + ".md5", "w") as f:
            f.write(h)


def frames_of(path):
    im = Image.open(path).convert("RGBA")
    n = im.width // FS
    return im, [im.crop((i * FS, 0, (i + 1) * FS, FS)) for i in range(n)], n


def save_sheet(frames, path):
    out = Image.new("RGBA", (len(frames) * FS, FS), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        out.paste(fr, (i * FS, 0))
    out.save(path)


def grid(frames, name):
    cols = 4
    rows = (len(frames) + cols - 1) // cols
    g = Image.new("RGBA", (cols * FS, rows * FS), (40, 44, 52, 255))
    for i, fr in enumerate(frames):
        g.paste(fr, (i % cols * FS, i // cols * FS), fr)
    g.convert("RGB").save(os.path.join(PROBE, name))


def op_bunker():
    """每帧顶部（y<96）摘青蓝信标：蓝青色域(高蓝、中绿、低红)连通即清；吊杆灰蓝细杆同摘。"""
    rel = "assets/effects/unit_anims/ww2_fort_bunker/sheet_idle.png"
    backup(rel)
    im, frames, n = frames_of(os.path.join(ROOT, rel))
    removed = 0
    out_frames = []
    for fr in frames:
        a = np.asarray(fr).copy()
        r, g, b, al = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int), a[..., 3]
        cand = (b > 120) & (b >= g - 10) & (r < 150) & (al > 0)
        cand[96:, :] = False  # 只在顶部找（信标+杆区）
        # 连通到顶部 1/3 的才算（杆从屋顶上伸）
        ys, xs = np.where(cand)
        if len(ys):
            keep = np.zeros_like(cand)
            # 泛洪：从顶行有 cand 的列向下连带
            for x0 in np.unique(xs):
                col = np.where(cand[:, x0])[0]
                if len(col) and col.min() < 70:  # 触到上部=信标/杆
                    y1 = col.max()
                    keep[:y1 + 1, x0] = True
            # 水平扩散 1px 吃光晕
            keep[:, 1:] |= keep[:, :-1]
            keep[:, :-1] |= keep[:, 1:]
            a[keep] = (0, 0, 0, 0)
            removed += int(keep.sum())
        out_frames.append(Image.fromarray(a))
    save_sheet(out_frames, os.path.join(ROOT, rel))
    grid(out_frames, "FIX_bunker_idle_grid.png")
    print("[bunker] 摘除像素 %d（8 帧）" % removed)


def op_marine():
    """脚底地渍：底部 52px 内低饱和(r,g,b 间距<26)+高亮(lum>128)非靴色像素清除，向内蚀刻保靴底轮廓。"""
    rel = "assets/effects/unit_anims/mod_inf_marine/sheet_idle.png"
    backup(rel)
    im, frames, n = frames_of(os.path.join(ROOT, rel))
    removed = 0
    out_frames = []
    for fr in frames:
        a = np.asarray(fr).copy()
        r, g, b, al = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int), a[..., 3]
        lum = (r + g + b) / 3
        spread = np.max(np.stack([r, g, b]), axis=0) - np.min(np.stack([r, g, b]), axis=0)
        cand = (spread < 26) & (lum > 128) & (al > 0)
        cand[:-52, :] = False
        # 两次腐蚀+一次膨胀：细长拖抹连片才清，靴底暖色高光(饱和)天然排除
        m = cand.copy()
        m[1:, :] &= m[:-1, :]
        m[:, 1:] &= m[:, :-1]
        grow = m.copy()
        grow[:, :-1] |= m[:, 1:]
        grow[1:, :] |= m[:-1, :]
        a[grow] = (0, 0, 0, 0)
        removed += int(grow.sum())
        out_frames.append(Image.fromarray(a))
    save_sheet(out_frames, os.path.join(ROOT, rel))
    grid(out_frames, "FIX_marine_idle_grid.png")
    print("[marine] 摘除像素 %d（8 帧）" % removed)


def breath(fr):
    """微呼吸：基准帧 f0 → 8 帧环 [0,0,U,U,0,0,D,D]，U=上移1px(顶压1行)，D=还原。运动≤1px。"""
    a0 = np.asarray(fr)
    up = np.roll(a0, -1, axis=0)
    up[-1, :] = 0
    return [Image.fromarray(a0), Image.fromarray(a0), Image.fromarray(up), Image.fromarray(up),
            Image.fromarray(a0), Image.fromarray(a0), Image.fromarray(a0), Image.fromarray(a0)]


def op_breath(dirname):
    rel = "assets/effects/unit_anims/%s/sheet_idle.png" % dirname
    backup(rel)
    im, frames, n = frames_of(os.path.join(ROOT, rel))
    # 基准帧=像素量最大的帧（最完整姿态）
    best = max(range(n), key=lambda i: int(np.asarray(frames[i])[..., 3].sum()))
    out = breath(frames[best])
    save_sheet(out, os.path.join(ROOT, rel))
    grid(out, "FIX_%s_idle_grid.png" % dirname)
    print("[%s] idle 重排为 f%d 基微呼吸环（8 帧）" % (dirname, best))


if __name__ == "__main__":
    os.makedirs(BK, exist_ok=True)
    os.makedirs(PROBE, exist_ok=True)
    op_bunker()
    op_marine()
    op_breath("cold_spetsnaz")
    op_breath("mod_apache_e")
    print("WaveA 完成。回验网格：.godot/unit_review/b5_probe/FIX_*.png")
