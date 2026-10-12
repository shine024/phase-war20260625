# -*- coding: utf-8 -*-
"""批2 attack sheet 布置（2026-10-12）：staging 2496×1664 六格 → 256 重排回文拼 10。

路线拍板：832 主路被 idle 连坐卡死（anim.json frame_size 全局管 idle+attack 切格，
unit_frame_anim.gd _load_seq 单行横排 Rect2(i*fs,0,fs,fs)），本批只重做 attack，
故走试点 nano_drone/cold_f4 同款 256 兜底路：整格等比缩放（非「贴回」工艺，无
裁断/爆宽病），回文序 0,1,2,3,4,5,4,3,2,1 拼 10 帧 = counts.attack 现役值，runtime 零改动。

先备份后覆盖（AGENTS.md 铁律）：_art_backup/unit_anims_attack_regen_20261012/<key>/

用法: python -I tools/_tmp_img25_deploy_attack_r19.py
"""
import json
import os
import shutil

import numpy as np
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', 'assets', 'effects', 'unit_anims'))
STAGING = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', '.godot', 'unit_review', 'img25_staging'))
BACKUP = r'F:\godot fair duet\_art_backup\unit_anims_attack_regen_20261012'

KEYS = [
    'cold_inf_btr60',
    'ww2_arm_garand_para',
    'ww2_fort_bunker',
    'drop_mega_particle_cannon',
    'mod_arm_himars',
    'ww2_fort_flak',
]

PALINDROME = [0, 1, 2, 3, 4, 5, 4, 3, 2, 1]  # 六格回文拼 10 = counts.attack 现役值
FS = 256


def deploy(key: str) -> None:
    src = os.path.join(STAGING, f'{key}_attack_sheet_832.png')
    dst_dir = os.path.join(ROOT, key)
    dst = os.path.join(dst_dir, 'sheet_attack.png')
    meta_path = os.path.join(dst_dir, 'anim.json')

    im = Image.open(src).convert('RGBA')
    if im.size != (2496, 1664):
        raise SystemExit(f'{src}: 尺寸 {im.size} != 2496×1664')
    cells = [im.crop((c * 832, r * 832, (c + 1) * 832, (r + 1) * 832))
             for r in range(2) for c in range(3)]
    small = [c.resize((FS, FS), Image.LANCZOS) for c in cells]

    sheet = Image.new('RGBA', (FS * len(PALINDROME), FS), (0, 0, 0, 0))
    for i, idx in enumerate(PALINDROME):
        sheet.alpha_composite(small[idx], (i * FS, 0))

    # 备份（幂等：只备布置前原状）
    bdir = os.path.join(BACKUP, key)
    os.makedirs(bdir, exist_ok=True)
    for f in ('sheet_attack.png', 'anim.json'):
        if os.path.isfile(os.path.join(dst_dir, f)) and not os.path.isfile(os.path.join(bdir, f)):
            shutil.copy2(os.path.join(dst_dir, f), os.path.join(bdir, f))

    sheet.save(dst)
    # counts 校验：回文 10 必须匹配现役 attack 帧数
    meta = json.load(open(meta_path, encoding='utf-8'))
    n = int(meta.get('counts', {}).get('attack', 0))
    if n != len(PALINDROME):
        print(f'  [warn] {key}: counts.attack={n} != 回文 {len(PALINDROME)}（回文前缀 0..n-1 直排可兜）')
    print(f'{key}: 布置完成 sheet={sheet.size} backup={bdir}')


def main() -> None:
    for k in KEYS:
        deploy(k)


if __name__ == '__main__':
    main()
