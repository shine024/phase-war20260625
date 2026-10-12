# -*- coding: utf-8 -*-
"""P1-I mod_icons 布置（2026-10-12）：staging 目验达标后覆盖 assets。

先备份后覆盖（AGENTS.md 铁律）：_art_backup/mod_icons_p1i_20261012/。
尺寸归一 1024²（族标准；arm_04/art_13 原 128px 离群顺带升级）。
部署名单硬编码 28 张（与 _tmp_p1i_modicons_gen.py ICONS 同表），命令行可传子集。

用法: python -I tools/_tmp_p1i_modicons_deploy.py [name ...]
"""
import os
import shutil
import sys

from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..'))
SRC = os.path.join(ROOT, '.godot', 'unit_review', 'img25_staging', 'mod_icons')
DST = os.path.join(ROOT, 'assets', 'ui', 'icons', 'mod_icons')
BACKUP = r'F:\godot fair duet\_art_backup\mod_icons_p1i_20261012'

NAMES = [
    'air_08_ecm', 'air_09_air_refuel', 'air_10_drop_tank', 'air_12_data_link',
    'air_13_ejection_seat', 'air_14_swing_wing', 'air_16_phase_shift',
    'air_17_bombsight', 'air_22_countermeasure', 'air_23_cockpit_armor',
    'air_24_canard', 'air_25_dual_mode_seeker', 'air_26_drone_wingman',
    'air_thermolite_bomb', 'arm_11_fire_control', 'arm_12_thermal_sight',
    'gen_09_ir_jammer', 'inf_21_thermal', 'inf_29_iron_sights',
    'rec_02_ir_suppression', 'art_06_fire_computer', 'art_09_rapid_fire',
    'inf_09_dual_mag', 'gen_20_squad_tablet', 'arm_13_deep_wading',
    'arm_19_track_guards', 'arm_04_aps', 'art_13_apfsds_sabot',
]


def main() -> None:
    only = set(sys.argv[1:]) or None
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
        bdir = os.path.join(BACKUP)
        os.makedirs(bdir, exist_ok=True)
        bak = os.path.join(bdir, name + '.png')
        if os.path.isfile(dst) and not os.path.isfile(bak):
            shutil.copy2(dst, bak)
        im.convert('RGB').save(dst)
        print(f'[deploy] {name} {im.size} backup={os.path.isfile(bak)}')
    print('done. 记得 --import 重导入')


if __name__ == '__main__':
    main()
