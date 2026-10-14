# -*- coding: utf-8 -*-
"""P2 批8 布置：staging p2_batch8 → assets（备份后覆盖）。

- runes×3：白角 BFS 键控→透明底，bbox 居中 995² RGBA + _thumb128
- alloy：同键控，居中 1024² RGBA
- pi×3：1024² 直接布置（atlas/eon=RGB、helix=RGBA）+ _thumb128
- bg_t2：1312×736 → 1280×718（原档规格）

备份：_art_backup/p2_batch8_20261012/。
用法: python -I tools/_tmp_p2_batch8_deploy.py [name ...]
"""
import os
import shutil
import sys
from collections import deque

from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..'))
SRC = os.path.join(ROOT, '.godot', 'unit_review', 'img25_staging', 'p2_batch8')
BACKUP = r'F:\godot fair duet\_art_backup\p2_batch8_20261012'

# name -> (staging文件, 目标路径, 目标尺寸, 是否键控, mode, 圆形遮罩)
JOBS = {
    'rune_defense_01_common': ('rune_defense_01_common_raw.png',
                               'assets/runes/common/rune_defense_01.png',
                               (995, 995), True, 'RGBA', True),
    'rune_energy_03_common': ('rune_energy_03_common_raw.png',
                              'assets/runes/common/rune_energy_03.png',
                              (995, 995), True, 'RGBA', True),
    'rune_special_06_legendary': ('rune_special_06_legendary_raw.png',
                                  'assets/runes/legendary/rune_special_06.png',
                                  (995, 995), True, 'RGBA', True),
    'alloy': ('alloy_raw.png', 'assets/resources/alloy.png',
              (1024, 1024), True, 'RGBA', False),
    'pi_atlas_01': ('pi_atlas_01_raw.png', 'assets/ui/instruments/pi_atlas_01.png',
                    (1024, 1024), False, 'RGB', False),
    'pi_eon_03': ('pi_eon_03_raw.png', 'assets/ui/instruments/pi_eon_03.png',
                  (1024, 1024), False, 'RGB', False),
    'pi_helix_04': ('pi_helix_04_raw.png', 'assets/ui/instruments/pi_helix_04.png',
                    (1024, 1024), False, 'RGBA', False),
    'bg_endless_gate_t2': ('bg_endless_gate_t2_raw.png',
                           'assets/backgrounds/bg_endless_gate_t2.png',
                           (1280, 718), False, 'RGB', False),
}


def key_white_edges(im: Image.Image, thresh: int = 238) -> Image.Image:
    """从四边 BFS，把与边缘连通的近白像素置透明（卡图092 同款管线）。"""
    im = im.convert('RGBA')
    w, h = im.size
    px = im.load()

    def is_white(p):
        return p[0] >= thresh and p[1] >= thresh and p[2] >= thresh

    seen = [[False] * w for _ in range(h)]
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if is_white(px[x, y]) and not seen[y][x]:
                seen[y][x] = True
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if is_white(px[x, y]) and not seen[y][x]:
                seen[y][x] = True
                q.append((x, y))
    n = 0
    while q:
        x, y = q.popleft()
        px[x, y] = (255, 255, 255, 0)
        n += 1
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] \
                    and is_white(px[nx, ny]):
                seen[ny][nx] = True
                q.append((nx, ny))
    print(f'    键控 {n}px 透明')
    return im


def place_centered(im: Image.Image, size: tuple) -> Image.Image:
    """bbox 裁剪后等比缩放居中放到 size 画布（留 1.5% 边距）。"""
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    cw, ch = size
    m = int(min(cw, ch) * 0.015)
    aw, ah = cw - 2 * m, ch - 2 * m
    r = min(aw / im.width, ah / im.height)
    nw, nh = max(1, round(im.width * r)), max(1, round(im.height * r))
    im = im.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new('RGBA', size, (0, 0, 0, 0))
    canvas.alpha_composite(im, ((cw - nw) // 2, (ch - nh) // 2))
    return canvas


def backup(dst: str) -> None:
    rel = os.path.relpath(dst, ROOT)
    b = os.path.join(BACKUP, rel.replace('..', '_'))
    os.makedirs(os.path.dirname(b), exist_ok=True)
    if os.path.isfile(dst) and not os.path.isfile(b):
        shutil.copy2(dst, b)


def main() -> None:
    only = set(sys.argv[1:]) or None
    for name, (src_name, dst_rel, size, do_key, mode) in JOBS.items():
        if only and name not in only:
            continue
        src = os.path.join(SRC, src_name)
        dst = os.path.join(ROOT, dst_rel)
        if not os.path.isfile(src):
            print(f'[skip] {name}: staging 缺 {src_name}')
            continue
        im = Image.open(src)
        print(f'[{name}] {im.size} -> {dst_rel} {size}')
        if do_key:
            im = key_white_edges(im)
            im = place_centered(im, size)
        else:
            im = im.resize(size, Image.LANCZOS)
        backup(dst)
        if mode == 'RGB':
            bg = Image.new('RGB', im.size, (0, 0, 0))
            bg.paste(im.convert('RGB'))
            bg.save(dst)
        else:
            im.convert(mode).save(dst)
        # thumb 同步（runes 与 instruments）
        parts = dst_rel.replace('\\', '/').split('/')
        if parts[0] == 'assets' and parts[1] in ('runes', 'ui'):
            if parts[1] == 'runes':
                thumb = os.path.join(ROOT, 'assets', 'runes', '_thumb128',
                                     parts[2], parts[3])
            else:
                thumb = os.path.join(ROOT, 'assets', 'ui', 'instruments',
                                     '_thumb128', parts[3])
            backup(thumb)
            im.resize((128, 128), Image.LANCZOS).convert('RGBA').save(thumb)
            print(f'    thumb -> {os.path.relpath(thumb, ROOT)}')
        print(f'    ok {Image.open(dst).size} {Image.open(dst).mode}')
    print('done. 记得 --import 重导入')


if __name__ == '__main__':
    main()
