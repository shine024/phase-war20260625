# -*- coding: utf-8 -*-
"""嫌疑目录取证图：idle 全条 + attack 全条 + attack 嫌疑帧 2x 放大。输出 .godot/art_audit_20261011/zoom/<dir>.png"""
import os, sys, glob
from PIL import Image, ImageDraw, ImageFont

ROOT = '.'
OUT = '.godot/art_audit_20261011/zoom'
os.makedirs(OUT, exist_ok=True)
F = ImageFont.truetype('assets/fonts/NotoSansSC-Regular.ttf', 18)

def strip(p, w=1560):
    im = Image.open(p)
    if im.mode != 'RGBA':
        im = im.convert('RGBA')
    s = w / im.width
    return im.resize((w, max(1, int(im.height * s))), Image.LANCZOS), im.width // 256

def checker(w, h, sq=8):
    im = Image.new('RGB', (w, h), (120, 120, 120))
    d = ImageDraw.Draw(im)
    for y in range(0, h, sq):
        for x in range(0, w, sq):
            if (x // sq + y // sq) % 2 == 0:
                d.rectangle([x, y, min(x + sq - 1, w - 1), min(y + sq - 1, h - 1)], fill=(150, 150, 150))
    return im

def frames2x(p, fidx, cell=256, scale=2):
    im = Image.open(p)
    if im.mode != 'RGBA':
        im = im.convert('RGBA')
    tiles = []
    for fi in fidx:
        if fi * cell + cell > im.width:
            continue
        c = im.crop((fi * cell, 0, (fi + 1) * cell, im.height)).resize((cell * scale, im.height * scale), Image.NEAREST)
        tiles.append((fi, c))
    return tiles

def make(dirn, suspect_frames):
    d = f'assets/effects/unit_anims/{dirn}'
    W = 1600
    parts = []
    idle, ni = strip(f'{d}/sheet_idle.png')
    atk, na = strip(f'{d}/sheet_attack.png')
    ti = frames2x(f'{d}/sheet_idle.png', suspect_frames)
    ta = frames2x(f'{d}/sheet_attack.png', suspect_frames)
    H = 26 + idle.height + 8 + atk.height + 8 + 26 + max([t.height for _, t in ti + ta] or [0]) + 26
    sh = Image.new('RGB', (W, H), (24, 24, 24))
    dr = ImageDraw.Draw(sh)
    y = 2
    dr.text((6, y), f'{dirn}  idle({ni}f)', fill=(255, 210, 80), font=F); y += 24
    bg = checker(idle.width, idle.height); sh.paste(bg, (0, y)); sh.paste(idle, (0, y), idle); y += idle.height + 8
    dr.text((6, y), f'attack({na}f)', fill=(255, 210, 80), font=F); y += 24
    bg = checker(atk.width, atk.height); sh.paste(bg, (0, y)); sh.paste(atk, (0, y), atk); y += atk.height + 8
    dr.text((6, y), f'frames 2x: {suspect_frames}', fill=(255, 210, 80), font=F); y += 24
    x = 0
    for fi, t in ti + ta:
        bg = checker(t.width, t.height); sh.paste(bg, (x, y)); sh.paste(t, (x, y), t)
        dr.text((x + 4, y + 4), f'{"I" if fi in suspect_frames and ti and (fi, t) in ti else "A"}f{fi}', fill=(255, 80, 80), font=F)
        x += t.width + 6
    sh.save(f'{OUT}/{dirn}.png')
    print('zoom', dirn, f'{W}x{H}')

DIRS = {
    'cold_inf_btr60': [3, 5, 7], 'cold_sup_zsu23': [4, 5], 'drop_mega_particle_cannon': [3, 5, 7],
    'fe_helix_orbital_strike': [4, 6, 8], 'mod_arm_himars': [5, 6, 7], 'ww2_arm_garand_para': [5, 6, 7],
    'ww2_fort_bunker': [3, 5, 8], 'ww2_fort_flak': [4, 5, 6], 'ww1_inf_mp18_x': [6, 7, 8],
    'fut_colossus': [5, 6, 7], 'fe_iron_wall_juggernaut': [0, 2, 4], 'ww2_inf_kar98k': [0, 2, 4],
    'vis_xeno_swarmling': [0, 2, 3], 'vis_xeno_dark_templar': [2, 7, 8], 'vis_xeno_probe': [0, 2, 4],
    'vis_xeno_templar': [1, 2], 'vis_xeno_biomorph': [1, 2], 'void_mage_expert': [2, 3, 4],
    'fut_arm_prism': [0, 3, 6], 'cold_m113': [0, 4], 'fut_cyborg': [0, 2, 5], 'fut_arm_heavy_mech': [0, 4, 7],
    'fut_arm_titan_mk2': [0, 4], 'fut_arm_mech_e': [0, 4], 'fe_quantum_mobile_base': [0, 4],
    'mod_air_technical_e': [2, 4], 'ww1_arty_mortar': [0, 2], 'ww2_fort_flak': [4, 5, 6],
    'steel_fortress_basic': [0, 3], 'mod_abrams': [0, 4], 'mod_ah1': [0, 4], 'mod_apache_e': [0, 4],
    'mod_challenger2': [0, 4], 'ww1_arty_77mm': [0, 2], 'ww1_105mm': [0, 3],
}
for d, fr in DIRS.items():
    if os.path.exists(f'assets/effects/unit_anims/{d}/sheet_idle.png'):
        try:
            make(d, fr)
        except Exception as e:
            print('ERR', d, e)
print('done')
