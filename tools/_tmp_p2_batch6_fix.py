# -*- coding: utf-8 -*-
"""P2 修复批6（2026-10-12）：程序可修包（确定性 7 项）。

P0+P1 收口后用户拍板「P2 全修」。批6 全 PIL 程序修，零生成：
1. wreck_4 右下游离白色杂丝擦除（小连通域不连主体）
2. res_crystal 竖长 55×96 → 内容 fit 96² 居中（消费端 fit 缩放补齐 12% 偏小）
3. b2a_powerless 相框去框：crop 纸边+镜像延伸回原尺寸（兄弟格满幅统一）
4. bg_level_11 尺寸 1935×1080 → 1920×1072 等比（全套唯一非标宽）
5. enh *_up 五张贴「↑」角标（base/up 对近不可分的最低成本区分，报告修复建议 4）
6. bg 过曝 8 张压曝（soft roll-off 高光 + 轻提中暗对比）
7. cards 4 张对比度/可读性拉升（mod_air_multrole ×2 / mod_sup_growler ×2）

先备份后覆盖（AGENTS.md 铁律）：_art_backup/p2_batch6_20261012/。
用法: python -I tools/_tmp_p2_batch6_fix.py [step ...]   # 缺省全跑
"""
import os
import shutil
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..'))
BACKUP = r'F:\godot fair duet\_art_backup\p2_batch6_20261012'


def backup(rel: str) -> None:
    src = os.path.join(ROOT, rel)
    dst = os.path.join(BACKUP, rel.replace('/', '_'))
    os.makedirs(BACKUP, exist_ok=True)
    if os.path.isfile(src) and not os.path.isfile(dst):
        shutil.copy2(src, dst)


def overwrite(rel: str, im: Image.Image) -> None:
    backup(rel)
    im.save(os.path.join(ROOT, rel))
    print(f'[ok] {rel}')


# 1 ------------------------------------------------------------------
def fix_wreck4() -> None:
    rel = 'assets/map/wreck_4.png'
    a = np.array(Image.open(os.path.join(ROOT, rel)).convert('RGBA'))
    h, w = a.shape[:2]
    solid = (a[..., 3] >= 200) & (a[..., :3].min(axis=2) >= 195)
    # 连通域：只搜 solid 像素
    seen = np.zeros((h, w), bool)
    comps = []
    for y in range(h):
        for x in range(w):
            if solid[y, x] and not seen[y, x]:
                dq = deque([(y, x)])
                seen[y, x] = True
                pix = []
                while dq:
                    cy, cx = dq.popleft()
                    pix.append((cy, cx))
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            ny, nx = cy + dy, cx + dx
                            if 0 <= ny < h and 0 <= nx < w and solid[ny, nx] and not seen[ny, nx]:
                                seen[ny, nx] = True
                                dq.append((ny, nx))
                comps.append(pix)
    comps.sort(key=len, reverse=True)
    main = comps[0]
    removed = 0
    for pix in comps[1:]:
        if len(pix) > h * w * 0.01:
            continue  # 大块非杂丝
        ys = [p[0] for p in pix]
        xs = [p[1] for p in pix]
        # 主体 bbox 外的悬空小块才擦（主体右下方游离）
        my0, my1 = min(p[0] for p in main), max(p[0] for p in main)
        mx0, mx1 = min(p[1] for p in main), max(p[1] for p in main)
        if min(ys) > my1 or min(xs) > mx1:
            for cy, cx in pix:
                a[cy, cx] = (0, 0, 0, 0)
            removed += len(pix)
    overwrite(rel, Image.fromarray(a, 'RGBA'))
    print(f'  wreck_4: comps={len(comps)} main={len(main)} removed={removed}px')


# 2 ------------------------------------------------------------------
def fix_res_crystal() -> None:
    rel = 'assets/ui/icons/res_crystal.png'
    im = Image.open(os.path.join(ROOT, rel)).convert('RGBA')
    bbox = im.getbbox()
    content = im.crop(bbox)
    s = min(92 / content.width, 92 / content.height)
    content = content.resize((max(1, int(content.width * s)), max(1, int(content.height * s))), Image.LANCZOS)
    canvas = Image.new('RGBA', (96, 96), (0, 0, 0, 0))
    canvas.alpha_composite(content, ((96 - content.width) // 2, (96 - content.height) // 2))
    overwrite(rel, canvas)
    print(f'  res_crystal: {im.size} -> 96x96 content x{s:.3f}')


# 3 ------------------------------------------------------------------
def fix_b2a() -> None:
    rel = 'assets/intro/comic/b2a_powerless.png'
    im = Image.open(os.path.join(ROOT, rel)).convert('RGB')
    w, h = im.size
    # 内框深线外沿裁：上16 左12 右12 底42（目验定位）
    core = im.crop((12, 16, w - 12, h - 42))
    cw, ch = core.size
    canvas = Image.new('RGB', (w, h))
    # 镜像延伸四边回原尺寸（边缘=烟雾/暗部，无缝）
    canvas.paste(core, (12, 16))
    top = core.crop((0, 0, cw, 16)).transpose(Image.FLIP_TOP_BOTTOM)
    canvas.paste(top, (12, 0))
    bot = core.crop((0, ch - 42, cw, ch)).transpose(Image.FLIP_TOP_BOTTOM)
    canvas.paste(bot, (12, 16 + ch))
    lf = canvas.crop((12, 0, 24, h)).transpose(Image.FLIP_LEFT_RIGHT)
    canvas.paste(lf, (0, 0))
    rt = canvas.crop((12 + cw - 12, 0, 12 + cw, h)).transpose(Image.FLIP_LEFT_RIGHT)
    canvas.paste(rt, (12 + cw, 0))
    overwrite(rel, canvas)
    print(f'  b2a: crop({cw}x{ch}) mirror-fill -> {w}x{h}')


# 4 ------------------------------------------------------------------
def fix_bg11() -> None:
    rel = 'assets/backgrounds/bg_level_11.png'
    im = Image.open(os.path.join(ROOT, rel))
    nw, nh = 1920, round(im.height * 1920 / im.width)
    overwrite(rel, im.resize((nw, nh), Image.LANCZOS))
    print(f'  bg11: {im.size} -> {nw}x{nh}')


# 5 ------------------------------------------------------------------
def fix_enh_up() -> None:
    """enh *_up 贴金色 ↑ 角标（右上角，带描边）。"""
    names = ['enh_crit_up', 'enh_def_up', 'enh_dodge_up', 'enh_dmg_up', 'enh_range_up']
    S = 64  # 4x 超采样角标
    badge = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(badge)
    d.ellipse([2, 2, S - 2, S - 2], fill=(20, 26, 20, 235), outline=(255, 214, 92, 255), width=5)
    # 上箭头
    ax = S / 2
    d.polygon([(ax, S * 0.22), (ax + S * 0.20, S * 0.48), (ax + S * 0.09, S * 0.48),
               (ax + S * 0.09, S * 0.78), (ax - S * 0.09, S * 0.78), (ax - S * 0.09, S * 0.48),
               (ax - S * 0.20, S * 0.48)], fill=(255, 214, 92, 255))
    badge = badge.resize((16, 16), Image.LANCZOS)
    for n in names:
        rel = f'assets/ui/icons/mod_icons/{n}.png'
        im = Image.open(os.path.join(ROOT, rel)).convert('RGBA')
        im.alpha_composite(badge, (im.width - 16 - 10, 10))
        overwrite(rel, im)
        print(f'  {n}: badge ok')


# 6 ------------------------------------------------------------------
OVER_EXPOSED = [
    'assets/backgrounds/bg_endless_gate_t0.png',
    'assets/backgrounds/bg_level_42.png',
    'assets/backgrounds/bg_level_45.png',
    'assets/backgrounds/bg_level_57.png',
    'assets/backgrounds/bg_level_76.png',
    'assets/backgrounds/bg_level_80.png',
    'assets/backgrounds/bg_level_90.png',
    'assets/backgrounds/bg_level_96.png',
]


def fix_overexposed() -> None:
    """高光 soft roll-off（>170 段压 0.55）+ 中暗部轻提亮对比。"""
    lo, hi, slope = 170.0, 255.0, 0.55
    lut = []
    for v in range(256):
        f = float(v)
        if f <= lo:
            f = f * 1.02
        else:
            f = lo * 1.02 + (f - lo) * slope * (1.0 - 0.18 * (f - lo) / (hi - lo))
        lut.append(max(0, min(255, int(round(f)))))
    for rel in OVER_EXPOSED:
        im = Image.open(os.path.join(ROOT, rel)).convert('RGB')
        out = im.point(lut * 3)
        overwrite(rel, out)
        m0 = np.array(im).mean().round(0)
        m1 = np.array(out).mean().round(0)
        print(f'  {os.path.basename(rel)}: meanL {m0:.0f} -> {m1:.0f}')


# 7 ------------------------------------------------------------------
LOW_CONTRAST_CARDS = [
    'assets/card_icons/player/mod_air_multirole.png',
    'assets/card_icons/enemy/mod_air_multirole.png',
    'assets/card_icons/player/mod_sup_growler.png',
    'assets/card_icons/enemy/mod_sup_growler.png',
]


def fix_cards_contrast() -> None:
    """低对比卡图：percentile 拉伸（2%~99%）+ 饱和 x1.18。"""
    for rel in LOW_CONTRAST_CARDS:
        im = Image.open(os.path.join(ROOT, rel)).convert('RGBA')
        a = np.array(im).astype(np.float32)
        rgb, al = a[..., :3], a[..., 3:]
        solid = al[..., 0] >= 128
        if solid.sum() < 100:
            print(f'[skip] {rel}: 无实底')
            continue
        for ch in range(3):
            lo, hi = np.percentile(rgb[..., ch][solid], (2, 99))
            if hi - lo < 1:
                continue
            rgb[..., ch][solid] = np.clip((rgb[..., ch][solid] - lo) * 255.0 / (hi - lo), 0, 255)
        mean = rgb[solid].mean()
        rgb[solid] = np.clip((rgb[solid] - mean) * 1.18 + mean, 0, 255)
        out = np.concatenate([rgb, al], axis=2).astype(np.uint8)
        overwrite(rel, Image.fromarray(out, 'RGBA'))
        print(f'  {os.path.basename(rel)}: stretch+sat ok')


STEPS = {
    'wreck4': fix_wreck4, 'crystal': fix_res_crystal, 'b2a': fix_b2a,
    'bg11': fix_bg11, 'enh_up': fix_enh_up,
    'overexp': fix_overexposed, 'cards': fix_cards_contrast,
}


def main() -> None:
    only = set(sys.argv[1:]) or None
    for k, fn in STEPS.items():
        if only and k not in only:
            continue
        print(f'== {k} ==')
        fn()


if __name__ == '__main__':
    main()
