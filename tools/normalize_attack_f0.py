# -*- coding: utf-8 -*-
"""attack_f0.png 攻击姿态归一（2026-09-20）。
症状：敌方单位攻击瞬间"一会大一会小、一会左一会右"——AttackPoseAnim 裸换 texture，
attack_f0 内容占比/位置与卡图不一致（实测 16 单位中 15 个出 0.88~1.14 带外，最大 1.84×）。

归一口径（与 v32.2 动画部署验收②同源：占比修在资产层，代码只补分辨率差）：
  1. 等比缩放攻击姿态内容 → 内容高 = 卡图内容高（rh 校正 1.0；宽度留姿态自然差）
  2. 内容矩形中心 x 对齐卡图内容矩形中心 x（消横向跳）
  3. 内容矩形底边对齐卡图内容底边（脚线锚定，消纵向浮沉）
原图备份 .godot/art_backup_attack_f0_20260920/<unit>/attack_f0.png。
可重跑：python tools/normalize_attack_f0.py（幂等：备份只首次落盘）。
"""
import json
import os
import shutil

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAP = os.path.join(ROOT, '.godot', 'attack_f0_map.json')
BACKUP = os.path.join(ROOT, '.godot', 'art_backup_attack_f0_20260920')

def content_bbox(im):
    """非透明内容包围盒（alpha>8），全透明返回 None。"""
    a = im.getchannel('A').point(lambda v: 255 if v > 8 else 0)
    return a.getbbox()

def main():
    pairs = json.load(open(MAP, encoding='utf-8'))
    print(f"units={len(pairs)}")
    changed = 0
    for aid, card_rel in sorted(pairs.items()):
        card_p = os.path.join(ROOT, card_rel.replace('res://', ''))
        atk_p = os.path.join(ROOT, 'assets/effects/unit_anims', aid, 'attack_f0.png')
        if not os.path.exists(atk_p):
            print(f"  SKIP(no atk) {aid}")
            continue
        card = Image.open(card_p).convert('RGBA')
        atk = Image.open(atk_p).convert('RGBA')
        cb, ab = content_bbox(card), content_bbox(atk)
        if cb is None or ab is None:
            print(f"  SKIP(empty) {aid}")
            continue
        card_h = cb[3] - cb[1]
        atk_h = ab[3] - ab[1]
        s = card_h / max(atk_h, 1)
        # 等比缩放姿态内容（高对齐；LANCZOS 保边缘）
        content = atk.crop(ab)
        nw = max(1, round(content.width * s))
        nh = max(1, round(content.height * s))
        content = content.resize((nw, nh), Image.LANCZOS)
        # 画布：保持原尺寸（512²），透明底
        out = Image.new('RGBA', atk.size, (0, 0, 0, 0))
        card_cx = (cb[0] + cb[2]) / 2.0
        target_x = round(card_cx - nw / 2.0)
        target_y = round(cb[3] - nh)  # 底边对齐卡图内容底边（脚线）
        out.paste(content, (target_x, target_y), content)
        # 备份（只首次）
        bdir = os.path.join(BACKUP, aid)
        if not os.path.exists(bdir):
            os.makedirs(bdir)
            shutil.copy2(atk_p, os.path.join(bdir, 'attack_f0.png'))
        out.save(atk_p)
        rw_after = nw / max(cb[2] - cb[0], 1)
        print(f"  NORM {aid}: scale={s:.3f} rw_after={rw_after:.2f} rh_after=1.00 dx={target_x - ab[0]:+d}px")
        changed += 1
    print(f"DONE changed={changed}")

if __name__ == '__main__':
    main()
