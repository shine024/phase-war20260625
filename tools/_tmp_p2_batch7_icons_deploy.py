# -*- coding: utf-8 -*-
"""P2 批7 布置：staging mod_icons_p2 27 张 → assets/ui/icons/mod_icons/。

先备份后覆盖：_art_backup/p2_batch7_20261012/。
用法: python -I tools/_tmp_p2_batch7_icons_deploy.py [name ...]
"""
import os
import shutil
import sys

from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..'))
SRC = os.path.join(ROOT, '.godot', 'unit_review', 'img25_staging', 'mod_icons_p2')
DST = os.path.join(ROOT, 'assets', 'ui', 'icons', 'mod_icons')
BACKUP = r'F:\godot fair duet\_art_backup\p2_batch7_20261012'

NAMES = [
    'aa_06_laser', 'gen_21_vanguard_repair', 'gen_22_aegis_protocol',
    'gen_23_singularity_core', 'eng_01_mine_sweeper', 'air_05_helmet_sight',
    'aa_02_iff', 'gen_02_digital', 'gen_07_mine_resistant',
    'gen_stealth_coating', 'gen_17_electronic_hijack', 'rec_11_decoy',
    'art_14_counter_battery', 'air_02_vector_thrust', 'inf_32_heavy_barrel',
    'for_12_anti_tank_trench', 'enh_regen_up',
    'inf_17_tourniquet', 'inf_18_ifak', 'inf_25_medic_sacrifice',
    'inf_34_kill_field_dressing', 'rec_10_medkit', 'eng_08_medical',
    'inf_30_load_vest', 'rec_14_crit_designator', 'sup_targeting_drone',
    'eng_16_field_generator',
]


def main() -> None:
    only = set(sys.argv[1:]) or None
    os.makedirs(BACKUP, exist_ok=True)
    for name in NAMES:
        if only and name not in only:
            continue
        src = os.path.join(SRC, name + '.png')
        dst = os.path.join(DST, name + '.png')
        if not os.path.isfile(src):
            print(f'[skip] {name}: staging 缺')
            continue
        im = Image.open(src)
        if im.size != (1024, 1024):
            im = im.resize((1024, 1024), Image.LANCZOS)
        bak = os.path.join(BACKUP, name + '.png')
        if os.path.isfile(dst) and not os.path.isfile(bak):
            shutil.copy2(dst, bak)
        im.convert('RGB').save(dst)
        print(f'[deploy] {name}')
    print('done. 记得 --import 重导入')


if __name__ == '__main__':
    main()
