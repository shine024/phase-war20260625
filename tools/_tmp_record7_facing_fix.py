# -*- coding: utf-8 -*-
"""记录7#16 资产朝向修复（2026-09-24）。

背景（调查结论）：卡图纪律"敌左我右"——敌方卡图朝左，attack_f0.png 必须与卡图同侧。
8 个敌方 attack_f0 生成时朝右（对敌方必翻转），工兵 sheet_idle 第 8 帧混入右向批次源图。
v6.15b 归一器只对齐大小/位置没有朝向度量，坏资产一直通过回归锁——本次机械翻正 + 补锁。

处理：
  1) attack_f0 朝右的 8 目录：整画布水平镜像（内容朝向翻正，尺寸/占比不变），
     再由 tools/normalize_attack_f0.py 重跑恢复与卡图的高比/中心x/脚线对齐。
  2) ww1_sup_engineer/sheet_idle.png 第 8 帧（索引 7）单元格内水平镜像
     （左向批次中混入的右向帧；镜像后左右质量分布回到 0-6 帧同侧）。
原图备份 .godot/art_backup_facing_fix_20260924/（幂等：已备份则跳过镜像）。
可重跑：python tools/_tmp_record7_facing_fix.py
"""
import os
import shutil

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BACKUP = os.path.join(ROOT, '.godot', 'art_backup_facing_fix_20260924')

# 朝右（违反敌左约定）的敌方 attack_f0 目录
ATTACK_F0_RIGHT_FACING = [
    'cold_inf_spetsnaz_e', 'ww2_inf_para_e', 'ww1_arty_mortar', 'ww1_inf_rifle',
    'ww1_sup_mg_nest', 'ww2_inf_garand', 'ww2_inf_thompson', 'ww2_sup_mg42',
    'ww1_inf_mp18',  # 朝向锁（记录7）实测抓出的第 9 张：目检误判，mass 判据反号
]
ENGINEER_IDLE = os.path.join(ROOT, 'assets/effects/unit_anims/ww1_sup_engineer/sheet_idle.png')
ENGINEER_FRAME = 7  # 第 8 帧（0 基）
ENGINEER_FRAME_SIZE = 256  # anim.json frame_size


def backup_once(src: str, rel: str) -> bool:
    """首次备份返回 True；已备份过返回 False（幂等跳过依据）。"""
    dst = os.path.join(BACKUP, rel)
    if os.path.exists(dst):
        return False
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(src, dst)
    return True


def main():
    print('== attack_f0 mirror ==')
    for aid in ATTACK_F0_RIGHT_FACING:
        p = os.path.join(ROOT, 'assets/effects/unit_anims', aid, 'attack_f0.png')
        if not os.path.exists(p):
            print(f'  SKIP(no file) {aid}')
            continue
        if not backup_once(p, os.path.join(aid, 'attack_f0.png')):
            print(f'  SKIP(already fixed) {aid}')
            continue
        im = Image.open(p).convert('RGBA')
        im.transpose(Image.FLIP_LEFT_RIGHT).save(p)
        print(f'  FLIPPED {aid}')

    print('== engineer idle frame mirror ==')
    if os.path.exists(ENGINEER_IDLE):
        if backup_once(ENGINEER_IDLE, 'ww1_sup_engineer/sheet_idle.png'):
            im = Image.open(ENGINEER_IDLE).convert('RGBA')
            W, H = im.size
            x0 = ENGINEER_FRAME * ENGINEER_FRAME_SIZE
            cell = im.crop((x0, 0, x0 + ENGINEER_FRAME_SIZE, H))
            im.paste(cell.transpose(Image.FLIP_LEFT_RIGHT), (x0, 0))
            im.save(ENGINEER_IDLE)
            print(f'  FLIPPED frame {ENGINEER_FRAME} of ww1_sup_engineer/sheet_idle.png')
        else:
            print('  SKIP(already fixed) ww1_sup_engineer/sheet_idle.png')
    else:
        print('  MISS engineer sheet')


if __name__ == '__main__':
    main()
