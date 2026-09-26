# -*- coding: utf-8 -*-
"""记录3#4：77mm野战炮攻击帧炮口火光贴边裁切修复。
根因：源帧 f01/f02 内容左边距仅 8px(512 画布)，缩到 256 后余 4px，恰好被
deploy_unit_anims.py 的 4px 描边预烘焙吃光 → sheet f01/f02 内容贴左缘(x=0)，
火光/烟被裁半幅（游戏内 32 帧基准读作"C 形半圆火光"）。
修法：源帧 f01/f02 内容整体右移 12px(512 空间)，与其余帧族左缘(x≈19-21)对齐，
再按 deploy_unit_anims.py 同管线（LANCZOS 缩放 + cv2 描边预烘焙）重建本单元
idle/attack 双 sheet + anim.json。原 sheet/anim.json/源帧先备份 .godot/art_backup_77mm_fix_20260926/。
"""
import glob, json, os, shutil, sys
import numpy as np
from PIL import Image

SRC_DIR = r'资料/单位分帧动画/041_ww1_arty_77mm_77mm野战炮'
DST_DIR = r'assets/effects/unit_anims/ww1_arty_77mm'
BACKUP = r'.godot/art_backup_77mm_fix_20260926'
SHIFT = 12  # 512 空间右移像素（→ 256 空间 6px：描边 4px + 2px 余量）
FRAME = 256
FPS = 8

# ── 提取 deploy_unit_anims.py 的常量与烘焙函数（不 import——该脚本无 __main__ 守卫，
#    import 会触发全量重部署）──
with open('tools/deploy_unit_anims.py', encoding='utf-8') as f:
    txt = f.read()
head = txt.split("if '--bake-boss-frames' in sys.argv:", 1)[0]
ns = {}
exec(head, ns)
bake_outline_on_sheet = ns['bake_outline_on_sheet']
outline_meta = ns['outline_meta']

os.makedirs(BACKUP, exist_ok=True)
# 只在首次运行时备份（防重跑把已位移的源帧覆写掉原始备份）——位移段从备份读原帧，
# 备份不存在时才从当前源帧建立
for p in glob.glob(os.path.join(SRC_DIR, 'attack', 'f*.png')):
    dst = os.path.join(BACKUP, os.path.basename(p))
    if not os.path.exists(dst):
        shutil.copy2(p, dst)
for p in glob.glob(os.path.join(DST_DIR, '*')):
    dst = os.path.join(BACKUP, os.path.basename(p))
    if not os.path.exists(dst):
        shutil.copy2(p, dst)

# ── 1) 源帧右移（幂等：先从备份还原原帧再处理，防脚本重跑位移叠加）──
# f01 内容宽 472 → +12 与帧族左缘(x≈19-21)对齐；
# f02 烟几乎满幅（内容宽 486，双侧 4px 描边在 256 画布怎么位移都有一侧贴边）→
#   +6 是唯一两侧都只留"淡描边尾"的位移；配合重建段的振铃清理（见下）解决左缘。
SHIFT_BY = {'f01.png': 12, 'f02.png': 6}
for fname, shift in SHIFT_BY.items():
    p = os.path.join(SRC_DIR, 'attack', fname)
    im = Image.open(os.path.join(BACKUP, fname)).convert('RGBA')
    bbox = im.getbbox()
    if bbox[2] + shift > im.width:
        raise SystemExit('右移越界 %s bbox=%s' % (fname, bbox))
    shifted = Image.new('RGBA', im.size, (0, 0, 0, 0))
    shifted.paste(im, (shift, 0))
    shifted.save(p)
    print('shifted', fname, bbox, '->', shifted.getbbox())

# ── 2) 同管线重建双 sheet（deploy_unit_anims 同款 + 振铃清理）──
def _clean_frame_ringing(im256: Image.Image) -> Image.Image:
    """LANCZOS 512→256 缩放在硬边外侧 ~3px 产生 alpha 1~15 的振铃像素；
    deploy 管线的描边膨胀(cv2.dilate)把任何非零 alpha 当内容——振铃把膨胀区
    拽到画布边缘，描边被帧界裁切=竖直暗边（"火光裁半"真因）。
    清理：帧左右各 12px 内 alpha<16（引擎 keep 语义边界=16，≤15 全部不可见）
    的像素置 0；实心烟体(α≥128)与渐变尾(α≥16)不动。仅本单元使用。"""
    arr = np.array(im256)
    strip = 12
    for xs in (range(0, strip), range(256 - strip, 256)):
        for x in xs:
            col = arr[:, x, 3]
            arr[:, x, 3] = np.where(col < 16, 0, col)
    return Image.fromarray(arr)

counts = {}
for anim in ('idle', 'attack'):
    frames = sorted(glob.glob(os.path.join(SRC_DIR, anim, 'f*.png')))
    assert len(frames) >= 4, anim
    sheet = Image.new('RGBA', (FRAME * len(frames), FRAME), (0, 0, 0, 0))
    for i, fp in enumerate(frames):
        im = Image.open(fp).convert('RGBA')
        if im.size != (FRAME, FRAME):
            im = im.resize((FRAME, FRAME), Image.LANCZOS)
        im = _clean_frame_ringing(im)
        sheet.paste(im, (i * FRAME, 0))
    sheet = bake_outline_on_sheet(sheet)
    sheet.save(os.path.join(DST_DIR, 'sheet_%s.png' % anim))
    counts[anim] = len(frames)
meta = {'fps': FPS, 'frame_size': FRAME, 'counts': counts, 'outline': outline_meta()}
json.dump(meta, open(os.path.join(DST_DIR, 'anim.json'), 'w', encoding='utf-8'))
print('anim.json', meta)

# ── 3) 校验：实心内容（alpha≥128）不得触边；淡尾（outline 羽化尾，alpha<128）
#    触边单独报告不判失败（idle 帧族枪尾描边尾贴边为源画布固有，肉眼不可见）──
bad = []
faint = []
def _edge_check(anim):
    sh = Image.open(os.path.join(DST_DIR, 'sheet_%s.png' % anim)).convert('RGBA')
    n = sh.width // FRAME
    for i in range(n):
        fr = sh.crop((i * FRAME, 0, (i + 1) * FRAME, sh.height))
        b = fr.getbbox()
        if not b:
            continue
        touch = (b[0] <= 0 or b[1] <= 0 or b[2] >= FRAME or b[3] >= sh.height)
        if not touch:
            continue
        a = np.asarray(fr)[..., 3]
        solid_touch = (a[:, 0] >= 128).any() or (a[:, -1] >= 128).any() \
            or (a[0, :] >= 128).any() or (a[-1, :] >= 128).any()
        (bad if solid_touch else faint).append((anim, i, b))
for anim in ('idle', 'attack'):
    _edge_check(anim)
print('solid edge-touch:', bad if bad else 'NONE')
print('faint edge-touch (outline feather tail):', faint if faint else 'NONE')
sys.exit(1 if bad else 0)
