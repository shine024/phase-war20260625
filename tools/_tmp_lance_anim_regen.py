# -*- coding: utf-8 -*-
"""白刃先锋班（drop_phase_lance）战斗分帧动画重生成（用户裁决：卡图已换 WW2 形象）。

策略：逐帧 img2img"换装不换姿"——以现有 20 帧（idle 8 + attack 12，姿态/构图已验证
连贯）为姿态锚，prompt 锁死姿势只换着装（未来装甲→WW2 灰绿制服+钢盔+木托刺刀步枪），
黑底反抠复用 generate_attack_frames 管线（key_black/color_match/normalize_to_base），
拼条后复用 deploy_unit_anims.bake_outline_on_sheet 烘焙描边。
安全阀：20 帧全部成功才落盘（任一帧重试耗尽即放弃，旧动画原样保留）。
原图备份 .godot/art_backup_lance_anim_20260925/。
可重跑：python tools/_tmp_lance_anim_regen.py
"""
import importlib.util
import io
import json
import os
import shutil
import sys
import time

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIM_DIR = os.path.join(ROOT, 'assets', 'effects', 'unit_anims', 'drop_phase_lance')
BACKUP = os.path.join(ROOT, '.godot', 'art_backup_lance_anim_20260925')
REF_CARD = os.path.join(ROOT, 'assets', 'card_icons', 'enemy', 'drop_phase_lance.png')
FRAME = 256
COUNTS = {'idle': 8, 'attack': 12}

PROMPT = (
    "Keep this EXACT pose, framing, camera distance and scale — the soldier's stance, "
    "limbs, head angle and rifle position must remain identical to the input. Only "
    "change his equipment and clothing: replace the futuristic grey armor suit with an "
    "early-1940s field-grey wool uniform with chest pouches and a steel helmet, and "
    "replace the glowing energy-blade rifle with a wooden-stocked early assault rifle "
    "fitted with a long fixed steel sword bayonet. Hand-painted stylized card-art "
    "look, muted palette of field grey, olive brown and gunmetal. Same single soldier, "
    "same size filling the frame, crisp clean silhouette on pure black background. "
    "No text, no watermark, no new objects, no muzzle flash."
)


def load_mod(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main():
    gaf = load_mod('gaf', os.path.join(ROOT, 'tools', 'generate_attack_frames.py'))
    dua = load_mod('dua', os.path.join(ROOT, 'tools', 'deploy_unit_anims.py'))
    keys = gaf.load_keys()
    ref = Image.open(REF_CARD).convert('RGBA')
    if ref.size != (512, 512):
        ref = ref.resize((512, 512), Image.LANCZOS)

    sheets = {}
    for kind, n in COUNTS.items():
        p = os.path.join(ANIM_DIR, f'sheet_{kind}.png')
        im = Image.open(p).convert('RGBA')
        assert im.width == FRAME * n, f'{p} 宽度 {im.width} != {FRAME * n}'
        sheets[kind] = im

    old_backup_done = False
    key_idx = 0
    new_frames = {}
    for kind, n in COUNTS.items():
        for i in range(n):
            fr = sheets[kind].crop((i * FRAME, 0, (i + 1) * FRAME, FRAME))
            base512 = fr.resize((512, 512), Image.LANCZOS)
            black = Image.new('RGBA', (512, 512), (0, 0, 0, 255))
            black.alpha_composite(base512)
            buf = io.BytesIO()
            black.convert('RGB').save(buf, format='PNG')
            got = None
            for attempt in range(3):
                try:
                    raw = gaf.call_img2img(PROMPT, buf.getvalue(), keys[key_idx % len(keys)],
                                           size='1024x1024')
                    out = Image.open(io.BytesIO(raw)).convert('RGB')
                    if out.size != (512, 512):
                        out = out.resize((512, 512), Image.LANCZOS)
                    matted = gaf.key_black(out)
                    matted = gaf.color_match(matted, ref)
                    frame512 = gaf.normalize_to_base(matted, base512)
                    got = frame512.resize((FRAME, FRAME), Image.LANCZOS)
                    break
                except Exception as e:  # noqa: BLE001
                    print(f'[{kind}{i}] attempt {attempt} fail: {str(e)[:120]}')
                    key_idx += 1
                    time.sleep(20 * (attempt + 1))
            if got is None:
                print(f'ABORT：{kind}{i} 三投皆败——旧动画保留未动')
                return 1
            new_frames[(kind, i)] = got
            print(f'[{kind}{i}] OK')
        # 一类完成即备份一次旧 sheet（只备份首次）
        if not old_backup_done:
            os.makedirs(BACKUP, exist_ok=True)
            for k2 in COUNTS:
                src = os.path.join(ANIM_DIR, f'sheet_{k2}.png')
                dst = os.path.join(BACKUP, f'sheet_{k2}.png')
                if not os.path.exists(dst):
                    shutil.copy2(src, dst)
            old_backup_done = True

    # 全部成功 → 组新 sheet + 烘焙描边 + 落盘
    for kind, n in COUNTS.items():
        sheet = Image.new('RGBA', (FRAME * n, FRAME), (0, 0, 0, 0))
        for i in range(n):
            sheet.paste(new_frames[(kind, i)], (i * FRAME, 0))
        sheet = dua.bake_outline_on_sheet(sheet)
        sheet.save(os.path.join(ANIM_DIR, f'sheet_{kind}.png'))
        print(f'sheet_{kind}.png 写入（{FRAME * n}x{FRAME}，描边已烘焙）')
    aj = {
        'fps': 8, 'frame_size': FRAME, 'counts': dict(COUNTS),
        'outline': {'baked': True, 'width_px': 4, 'color': [13, 18, 28, 217], 'frame_basis': FRAME},
    }
    with open(os.path.join(ANIM_DIR, 'anim.json'), 'w', encoding='utf-8') as f:
        json.dump(aj, f, ensure_ascii=False)
    print('ANIM_REGEN_OK')


if __name__ == '__main__':
    sys.exit(main())
