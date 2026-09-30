#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""为 unit_anims/*/anim.json 写入 foot_frac（idle 全帧最低内容底缘，占画布比）。

用途：fort_shield_aura.sync_foot_anchor 对帧动画单位精确对齐护盾罩脚线——
帧内容边距与卡图标定 FOOT_FRAC 不同（部署裁切口径不同），必须按 sheet 实测。
deploy_unit_anims.py 再生成 sheet 后需重跑本工具补字段（幂等）。

用法：python tools/_tmp_anim_foot_frac.py
"""
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'effects', 'unit_anims')


def main() -> None:
    patched, skipped = 0, []
    for d in sorted(os.listdir(ROOT)):
        dj = os.path.join(ROOT, d, 'anim.json')
        sh = os.path.join(ROOT, d, 'sheet_idle.png')
        if not (os.path.isfile(dj) and os.path.isfile(sh)):
            continue
        meta = json.load(open(dj, encoding='utf-8'))
        fs = int(meta.get('frame_size', 256))
        n = int(meta.get('counts', {}).get('idle', 0))
        img = np.array(Image.open(sh).convert('RGBA'))[:, :, 3]
        h, w = img.shape
        n = min(n, w // fs)
        if n < 1 or h != fs:
            skipped.append((d, 'bad shape'))
            continue
        best = 1.0  # 取所有 idle 帧里最低的脚线（最小 frac），罩体按最低脚对齐
        for i in range(n):
            a = img[:, i * fs:(i + 1) * fs]
            rows = np.where((a > 12).any(axis=1))[0]
            if rows.size == 0:
                continue
            best = min(best, 1.0 - (rows.max() + 0.5) / fs)
        if best >= 1.0:
            skipped.append((d, 'empty'))
            continue
        meta['foot_frac'] = round(max(best, 0.0), 4)
        json.dump(meta, open(dj, 'w', encoding='utf-8'), ensure_ascii=False)
        patched += 1
    print('patched:', patched, 'skipped:', skipped)


if __name__ == '__main__':
    main()
