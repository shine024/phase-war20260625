# -*- coding: utf-8 -*-
"""部署单位分帧动画(v2 雪碧图版): 源 f*.png(512²) → 缩小256² 拼单张横条 sheet
产物: assets/effects/unit_anims/<key>/sheet_{idle,attack}.png + anim.json(帧数/fps)
兼容: 老的 idle_f*.png/attack_f*.png 逐帧副本会被清理

v6.15 描边预烘焙: 发布期把 v26.9 运行期 alpha 膨胀 shader(shaders/unit_outline.gdshader)
改为离线画进雪碧图——核显上该 shader 是每单位每帧 8向×3环采样的 fillrate 大头, 烘焙后
普通 sprite 绘制零额外开销, 视觉等价(屏 ~1.6px 深色描边)。Godot 侧读 anim.json 的
outline.baked 跳过 shader(见 unit_frame_anim.is_outline_baked → card_grid_unit_visuals)。
存量已发布 sheet 直接批烘焙: python tools/deploy_unit_anims.py --bake-existing
boss 逐帧(idle_f*.png, BossIdleAnim 消费)批烘焙: python tools/deploy_unit_anims.py --bake-boss-frames
"""
import glob
import json
import os
import re
import sys

from PIL import Image

SRC = r'资料/单位分帧动画'
DST = r'assets/effects/unit_anims'
FRAME = 256
FPS = 8

# ── 描边烘焙参数(唯一真身, 发布/存量批处理共用) ──
OUTLINE_BAKE = True
OUTLINE_WIDTH_PX = 4      # 256 帧基准描边半径(纹素); 屏幕≈1.6px @ 典型 scale≈0.44(卡宽112px)
OUTLINE_COLOR = (13, 18, 28, 217)  # = shader outline_color(0.05,0.07,0.11,0.85) × 255
OUTLINE_FEATHER = 0.6     # 描边层 alpha 高斯羽化 sigma(近似 shader 3 环采样的软边)


def bake_outline_on_sheet(sheet, frame=FRAME, w_px=OUTLINE_WIDTH_PX,
                          color=OUTLINE_COLOR, feather=OUTLINE_FEATHER):
    """雪碧图描边预烘焙: 每帧切片独立 alpha 膨胀(cv2 椭圆核), 描边只落纯透明区
    (alpha<16, 复刻 shader keep 语义对半透明软阴影/烟雾的保护), 本体像素不动。
    ⚠️ 必须按帧切片——雪碧图横条帧间无分隔空隙, 整条 dilate 会把邻帧实体串进来。"""
    import numpy as np
    import cv2
    if sheet.width % frame != 0:
        raise ValueError('sheet 宽 %d 不是帧宽 %d 的整数倍' % (sheet.width, frame))
    arr = np.asarray(sheet).copy()
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * w_px + 1, 2 * w_px + 1))
    for i in range(arr.shape[1] // frame):
        x0, x1 = i * frame, (i + 1) * frame
        cell = arr[:, x0:x1]
        a = cell[..., 3]
        dil = cv2.dilate(a, k)
        zone = (dil > 0) & (a < 16)
        if not zone.any():
            continue
        layer = np.zeros_like(cell)
        layer[..., 0], layer[..., 1], layer[..., 2] = color[0], color[1], color[2]
        layer[..., 3] = np.where(zone, color[3], 0)
        layer[..., 3] = cv2.GaussianBlur(layer[..., 3], (0, 0), feather)
        # src-over: 描边层在下、原帧在上——本体(含半透明软像素)覆盖, 仅透明区露出描边。
        # keep 语义对齐 shader: smoothstep(0.02,0.38,ca) 的实心像素描边权重严格归零
        # (否则羽化渗入实心边界 ~2px, 违反 shader"ca≥0.38 完全不描边"), 且仅描边层
        # alpha>0 处混合, 其余像素位级保留(float 全帧混合会留 ±1 舍入噪声)。
        lf = layer.astype(np.float32)
        cf = cell.astype(np.float32)
        la = lf[..., 3:4] / 255.0
        ca = cf[..., 3:4] / 255.0
        t = np.clip((ca - 0.02) / (0.38 - 0.02), 0.0, 1.0)
        la = la * (1.0 - t * t * (3.0 - 2.0 * t))
        oa = la + ca * (1.0 - la)
        mixed = np.where(oa > 0, (lf * la + cf * ca * (1.0 - la)) / np.maximum(oa, 1e-6), 0.0)
        out = np.where(la > 0, mixed, cf)  # 掩码用 keep 调整后的有效 alpha——归零处位级保留
        arr[:, x0:x1] = np.clip(out, 0, 255).astype(np.uint8)
    return Image.fromarray(arr)


def outline_meta(frame_basis=FRAME, w_px=OUTLINE_WIDTH_PX):
    return {'baked': True, 'width_px': w_px,
            'color': list(OUTLINE_COLOR), 'frame_basis': frame_basis}


if '--bake-boss-frames' in sys.argv:
    # boss/相位师逐帧资产描边烘焙(BossIdleAnim 消费的 idle_f*.png, 512² 单图整帧)。
    # v6.15 存量轮只烘了横条 sheet; 本模式补齐剩余两类未烘焙资产中唯一有持续收益的:
    #   - boss idle 帧: 6fps 整场循环 + 全场最大精灵(512²×VISUAL_SCALE 2.0), shader
    #     fillrate 大头, 烘焙后同 sheet 一样普通绘制零开销。
    #   - attack_f0(AttackPoseAnim 0.16s 瞬态帧)刻意不烘: 11/16 因 v24.3 守卫永不显示,
    #     其余仅开火瞬间显示, 且宿主单位静态卡图(与 UI 共用)仍走 shader——烘了会在
    #     姿态帧被 shader 二次外扩, 收益趋零。
    # 描边宽度按"屏 ~1.6px"规则换算: boss scale = BASE_CARD_WIDTH_PX(58.9)/512×2.0
    # = 0.23 → 1.6/0.23 ≈ 7 纹素(512 基准); 羽化按宽度等比放大, 保持软边比例与 sheet 一致。
    # 目录写 anim.json{"outline":...} 作标记(纯标记文件, 无 fps/frame_size——boss 目录无
    # sheet, UnitFrameAnim._resolve_key 因缺 sheet_idle 不会命中它), Godot 侧
    # UnitFrameAnim.is_outline_baked 兜底段读它跳过 shader。备份同 --bake-existing。
    import datetime
    import shutil
    BOSS_W_PX = 7
    bak_root = os.path.join('.godot', 'art_backup_outline_' + datetime.date.today().isoformat())
    n_done = n_skip = 0
    for adir in sorted(glob.glob(os.path.join(DST, '*'))):
        if not os.path.isdir(adir) or not os.path.exists(os.path.join(adir, 'idle_f0.png')):
            continue
        base = os.path.basename(adir)
        jp = os.path.join(adir, 'anim.json')
        if os.path.exists(jp):
            meta = json.load(open(jp, encoding='utf-8'))
            if meta.get('outline', {}).get('baked'):
                n_skip += 1
                continue
        else:
            meta = {}
        for fp in sorted(glob.glob(os.path.join(adir, 'idle_f*.png'))):
            dst_bak = os.path.join(bak_root, base)
            os.makedirs(dst_bak, exist_ok=True)
            shutil.copy2(fp, os.path.join(dst_bak, os.path.basename(fp)))
            img = Image.open(fp).convert('RGBA')
            # 单图整帧: frame=img.width 即单片切片; 羽化随宽度等比(0.6@4px 基准)
            bake_outline_on_sheet(img, frame=img.width, w_px=BOSS_W_PX,
                                  feather=OUTLINE_FEATHER * BOSS_W_PX / OUTLINE_WIDTH_PX).save(fp)
        meta['outline'] = outline_meta(frame_basis=512, w_px=BOSS_W_PX)
        json.dump(meta, open(jp, 'w', encoding='utf-8'))
        n_done += 1
    print('boss-frame baked units: %d  skipped(幂等): %d  backup -> %s' % (n_done, n_skip, bak_root))
    sys.exit(0)


if '--bake-existing' in sys.argv:
    # 存量批处理: 直接对 assets 已发布 sheet 烘焙(不走重发布——源帧可能含手工修正,
    # 重缩放会覆盖)。原图备份 .godot/art_backup_outline_<date>/, anim.json 写 outline
    # 标记(幂等, 已烘焙跳过)。boss/相位师逐帧资产(BossIdleAnim 消费, 非横条 sheet)
    # 本模式不处理——归 --bake-boss-frames(宽度基准/标记方式不同, 见该模式注释)。
    import datetime
    import shutil
    bak_root = os.path.join('.godot', 'art_backup_outline_' + datetime.date.today().isoformat())
    n_done = n_skip = 0
    for adir in sorted(glob.glob(os.path.join(DST, '*'))):
        jp = os.path.join(adir, 'anim.json')
        base = os.path.basename(adir)
        if not os.path.isdir(adir) or not os.path.exists(jp) \
                or base.startswith('boss_') or base.startswith('enemy_master'):
            continue
        meta = json.load(open(jp, encoding='utf-8'))
        if meta.get('outline', {}).get('baked'):
            n_skip += 1
            continue
        fs = int(meta.get('frame_size', FRAME))
        changed = False
        for anim in ('idle', 'attack'):
            sp = os.path.join(adir, 'sheet_%s.png' % anim)
            if not os.path.exists(sp):
                continue
            sheet = Image.open(sp).convert('RGBA')
            dst_bak = os.path.join(bak_root, base)
            os.makedirs(dst_bak, exist_ok=True)
            shutil.copy2(sp, os.path.join(dst_bak, os.path.basename(sp)))
            bake_outline_on_sheet(sheet, frame=fs).save(sp)
            changed = True
        if changed:
            meta['outline'] = outline_meta(fs)
            json.dump(meta, open(jp, 'w', encoding='utf-8'))
            n_done += 1
    print('baked units: %d  skipped(幂等): %d  backup -> %s' % (n_done, n_skip, bak_root))
    sys.exit(0)

keys = []
import importlib.util
spec = importlib.util.spec_from_file_location('gua', 'tools/generate_unit_animations.py')
gua = importlib.util.module_from_spec(spec)
sys.modules['gua'] = gua
spec.loader.exec_module(gua)
keys.extend(gua.UNITS.keys())
extra = json.load(open('tools/unit_animations_extra.json', encoding='utf-8'))
keys.extend(k for k in extra.keys() if k not in keys)
keys.sort(key=len, reverse=True)
print('known keys:', len(keys))

os.makedirs(DST, exist_ok=True)
n_units = n_sheets = n_png = 0
for d in sorted(os.listdir(SRC)):
    dp = os.path.join(SRC, d)
    if not os.path.isdir(dp) or d.startswith('_'):
        continue
    if d.startswith('enemy_master') or d.startswith('boss_'):
        continue
    key = next((k for k in keys if d == k or d.startswith(k + '_')), None)
    if key is None:
        # fix5: 目录带 NNN_ 序号前缀, 剥离后再匹配
        stripped = re.sub(r'^\d{3}_', '', d)
        key = next((k for k in keys if stripped == k or stripped.startswith(k + '_')), None)
    if key is None:
        print('!! no key match for', d)
        continue
    out_dir = os.path.join(DST, key)
    os.makedirs(out_dir, exist_ok=True)
    counts = {}
    for anim in ('idle', 'attack'):
        frames = sorted(glob.glob(os.path.join(dp, anim, 'f*.png')))
        if len(frames) < 4:
            print('!! skip %s/%s only %d frames' % (d, anim, len(frames)))
            continue
        sheet = Image.new('RGBA', (FRAME * len(frames), FRAME), (0, 0, 0, 0))
        for i, f in enumerate(frames):
            im = Image.open(f).convert('RGBA')
            if im.size != (FRAME, FRAME):
                im = im.resize((FRAME, FRAME), Image.LANCZOS)
            sheet.paste(im, (i * FRAME, 0))
        if OUTLINE_BAKE:
            sheet = bake_outline_on_sheet(sheet)
        sheet.save(os.path.join(out_dir, 'sheet_%s.png' % anim))
        counts[anim] = len(frames)
        n_sheets += 1
    # 清理 v1 逐帧副本
    for old in glob.glob(os.path.join(out_dir, 'idle_f*.png')) + glob.glob(os.path.join(out_dir, 'attack_f*.png')):
        os.remove(old)
        n_png += 1
    meta = {'fps': FPS, 'frame_size': FRAME, 'counts': counts}
    if OUTLINE_BAKE and counts:
        meta['outline'] = outline_meta()
    json.dump(meta, open(os.path.join(out_dir, 'anim.json'), 'w', encoding='utf-8'))
    n_units += 1
print('deployed units: %d  sheets: %d  removed v1 pngs: %d' % (n_units, n_sheets, n_png))
