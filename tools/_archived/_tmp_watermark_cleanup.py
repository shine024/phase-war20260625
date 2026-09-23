import os, shutil
import numpy as np
from PIL import Image

BAK = os.path.join('.godot', 'art_backup_watermark_20260922')
TARGETS = (
    [f'assets/ui/stars/star_{i}.png' for i in range(1, 9)]
    + [f'assets/ui/factions/{n}_128.png' for n in
       ['aether_dynamics', 'frontier_union', 'helix_recon', 'iron_wall_corp',
        'neutral', 'nova_arms', 'quantum_logistics', 'void_research']]
    + ['assets/resources/basic_nano.png']
)

def detect_text_mask(arr, x0f, y0f, thr):
    """右下角区域内：比区域中位数亮 thr 的像素视为水印文字。"""
    h, w = arr.shape[:2]
    x0, y0 = int(w * x0f), int(h * y0f)
    reg = arr[y0:, x0:, :3].astype(np.int16)
    lum = reg.mean(axis=2)
    med = np.median(lum)
    mask = lum > med + thr
    return (x0, y0), mask

def row_interp_fill(img_arr, x0, y0, mask):
    """对掩码像素按行线性插值填充（平滑渐变底最优）。"""
    reg = img_arr[y0:, x0:, :3]
    h, w = mask.shape
    filled = 0
    for ry in range(h):
        xs = np.nonzero(mask[ry])[0]
        if xs.size == 0:
            continue
        # 分组连续 run
        splits = np.nonzero(np.diff(xs) > 1)[0]
        runs = np.split(xs, splits + 1)
        for run in runs:
            a, b = run[0], run[-1]
            left = reg[ry, a - 1] if a > 0 else None
            right = reg[ry, b + 1] if b + 1 < w else None
            if left is None and right is None:
                continue
            if left is None:
                reg[ry, a:b + 1] = right
            elif right is None:
                reg[ry, a:b + 1] = left
            else:
                n = b - a + 1
                for k in range(1, n + 1):
                    t = k / (n + 1)
                    reg[ry, a + k - 1] = (left * (1 - t) + right * t).astype(np.uint8)
            filled += run.size
    return filled

os.makedirs(BAK, exist_ok=True)
report = []
for p in TARGETS:
    bak_path = os.path.join(BAK, p.replace('/', '_'))
    if not os.path.exists(bak_path):
        shutil.copy2(p, bak_path)
    im = Image.open(p)
    arr = np.asarray(im).copy()
    is_nano = 'basic_nano' in p
    if is_nano:
        # 透明底图标：清掉水印文字的 alpha
        (x0, y0), mask = detect_text_mask(arr, 0.55, 0.80, 60)  # 透明底上水印是不透明亮字
        reg_a = arr[y0:, x0:, 3]
        # 水印=有 alpha 的亮像素；再膨胀 1px 清残边
        m = mask & (reg_a > 10)
        m2 = m.copy()
        m2[1:, :] |= m[:-1, :]; m2[:-1, :] |= m[1:, :]
        m2[:, 1:] |= m[:, :-1]; m2[:, :-1] |= m[:, 1:]
        reg_a[m2] = 0
        n = int(m2.sum())
        action = 'alpha清零'
    else:
        thr = 15 if 'stars' in p else 22
        (x0, y0), mask = detect_text_mask(arr, 0.55, 0.84, thr)
        n = row_interp_fill(arr, x0, y0, mask)
        action = '行内插值'
    Image.fromarray(arr).save(p)
    report.append((p, action, n))
    print(f'{p}: {action} {n} px')

tot = [r for r in report if r[2] == 0]
print('\n零命中（需人工看）:', [r[0] for r in tot] if tot else '无')
print('BAK_DIR:', BAK)
