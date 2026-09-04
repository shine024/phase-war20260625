# -*- coding: utf-8 -*-
"""Steam 素材客观审计：尺寸/alpha/锐度/标题对比/黑边/2x真实性。只打印结论，不改文件。"""
import os, math
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A = os.path.join(ROOT, '_steam_assets')

SPEC = {
    'capsules/header_capsule_920x430.png': (920, 430),
    'capsules/header_capsule_2x_1840x860.png': (1840, 860),
    'capsules/small_capsule_462x174.png': (462, 174),
    'capsules/small_capsule_2x_924x348.png': (924, 348),
    'capsules/main_capsule_616x353.png': (616, 353),
    'capsules/main_capsule_2x_1232x706.png': (1232, 706),
    'capsules/page_background_1438x810.png': (1438, 810),
    'capsules/community_icon_184x184.png': (184, 184),
    'capsules/library_capsule_600x900.png': (600, 900),
    'capsules/library_capsule_2x_1200x1800.png': (1200, 1800),
    'capsules/library_hero_3840x1240.png': (3840, 1240),
    'capsules/library_logo_1280x720.png': (1280, 720),
}
SHOTS = ['01_battle_storm.png', '02_battle_deploy.png', '03_base.png',
         '04_world_map.png', '05_growth.png', '06_title.png', '07_battle_break.png']
for s in SHOTS:
    SPEC['screenshots/' + s] = (1920, 1080)


def lum(im):
    a = np.asarray(im.convert('RGB'), dtype=np.float32)
    return a[..., 0] * 0.2126 + a[..., 1] * 0.7152 + a[..., 2] * 0.0722


def lap_var(gray):
    """Laplacian 方差（清晰度）"""
    k = gray[1:-1, 1:-1] * 4 - gray[:-2, 1:-1] - gray[2:, 1:-1] - gray[1:-1, :-2] - gray[1:-1, 2:]
    return float(k.var())


def psnr(a, b):
    d = np.asarray(a, np.float32) - np.asarray(b, np.float32)
    mse = float((d * d).mean())
    return 99.0 if mse < 1e-6 else 10 * math.log10(255 ** 2 / mse)


def border_report(im, bw=60):
    """黑边/糊边检测：边缘带 vs 中心的清晰度和亮度"""
    g = lum(im)
    h, w = g.shape
    c = g[bw:h - bw, bw:w - bw]
    t = g[:bw, :]; b = g[-bw:, :]; l = g[:, :bw]; r = g[:, -bw:]
    bor = np.concatenate([t.ravel(), b.ravel(), l.ravel(), r.ravel()])
    center_sharp = lap_var(g[bw * 2:h - bw * 2, bw * 2:w - bw * 2])
    # 边缘带模糊度：各边条带单独算梯度能量
    def grad_e(x):
        if x.ndim == 1:
            x = x[None, :]
        gx = np.abs(np.diff(x, axis=1)).mean(); gy = np.abs(np.diff(x, axis=0)).mean()
        return (gx + gy) / 2
    strips = [g[:bw, :], g[-bw:, :], g[:, :bw], g[:, -bw:]]
    return dict(border_lum=float(bor.mean()), center_lum=float(c.mean()),
                border_flat=float(bor.std()), center_sharp=lap_var(g),
                g_border=float(np.mean([grad_e(s) for s in strips])), g_center=grad_e(c))


def title_contrast(path, box, bright_pct=97):
    """标题区：文字像素（最亮 pct%）与周围背景环的 RMS 对比"""
    im = Image.open(path)
    g = lum(im)
    x0, y0, x1, y1 = box
    t = g[y0:y1, x0:x1]
    thr = np.percentile(t, bright_pct)
    mask = t >= thr
    if mask.sum() < 10:
        return None
    tmean = float(t[mask].mean())
    # 背景环：标题区外扩 30px
    ex = 30
    X0, Y0 = max(0, x0 - ex), max(0, y0 - ex)
    X1, Y1 = min(g.shape[1], x1 + ex), min(g.shape[0], y1 + ex)
    ring = g[Y0:Y1, X0:X1].copy()
    ring[(Y0 and y0 - Y0 or 0) + (y0 - Y0):(y1 - Y0), (x0 - X0):(x1 - X0)] = np.nan
    bg = float(np.nanmean(ring))
    rms = math.sqrt(max(0.0, tmean ** 2 - 0))  # 文字亮度
    return dict(text_lum=tmean, bg_lum=bg, contrast=tmean - bg,
                wc_ratio=(tmean + 12) / (bg + 12))  # 近似亮度对比率


print('=' * 100)
print('【1】尺寸规范')
bad = []
for rel, (W, H) in SPEC.items():
    p = os.path.join(A, rel)
    if not os.path.exists(p):
        print(f'  ✗ 缺失 {rel}'); bad.append(rel); continue
    im = Image.open(p)
    mode = im.mode
    ok = im.size == (W, H)
    if not ok:
        bad.append(rel)
    print(f'  {"✓" if ok else "✗"} {rel:52s} {im.size} (期望 {W}×{H}) mode={mode}')
print('  缺尺寸错误：', bad or '无')

print('=' * 100)
print('【2】2x 真实性（2x 降采样后与 1x 的 PSNR；>50dB ≈ 2x 就是从 1x 放大的）')
PAIRS = [
    ('capsules/header_capsule_920x430.png', 'capsules/header_capsule_2x_1840x860.png'),
    ('capsules/small_capsule_462x174.png', 'capsules/small_capsule_2x_924x348.png'),
    ('capsules/main_capsule_616x353.png', 'capsules/main_capsule_2x_1232x706.png'),
    ('capsules/library_capsule_600x900.png', 'capsules/library_capsule_2x_1200x1800.png'),
]
for one, two in PAIRS:
    a = Image.open(os.path.join(A, one)).convert('RGB')
    b = Image.open(os.path.join(A, two)).convert('RGB')
    bd = b.resize(a.size, Image.LANCZOS)
    p = psnr(a, bd)
    sharp1 = lap_var(lum(a)); sharp2 = lap_var(lum(b))
    print(f'  {os.path.basename(two):44s} PSNR(1x, 2x↓)={p:5.1f}dB  锐度 1x={sharp1:8.1f} 2x={sharp2:8.1f}  -> {"疑似由1x放大" if p < 50 else "真2x"}')

print('=' * 100)
print('【3】截图检查（黑边/糊边/锐度/曝光）')
for s in SHOTS:
    p = os.path.join(A, 'screenshots', s)
    im = Image.open(p)
    r = border_report(im)
    g = lum(im)
    dark_pct = float((g < 16).mean() * 100)
    br_pct = float((g > 240).mean() * 100)
    flag = []
    if r['border_flat'] < 6:
        flag.append('边缘趋同(可能有blur-pad/黑边)')
    if r['g_border'] < r['g_center'] * 0.45:
        flag.append(f"边缘模糊(边{r['g_border']:.1f} vs 中{r['g_center']:.1f})")
    if dark_pct > 40:
        flag.append(f'过暗({dark_pct:.0f}%近黑)')
    print(f'  {s:26s} 边亮度{r["border_lum"]:6.1f} 中亮度{r["center_lum"]:6.1f} 边std{r["border_flat"]:6.1f} 锐度{r["center_sharp"]:8.1f} 暗px{dark_pct:4.1f}% 亮px{br_pct:4.1f}%  {"⚠ " + "; ".join(flag) if flag else "OK"}')

print('=' * 100)
print('【4】胶囊标题可读性（文字亮度-背景亮度，>90 较稳，>60 及格）')
CHECKS = [
    ('capsules/header_capsule_920x430.png', (40, 205, 460, 380)),
    ('capsules/small_capsule_462x174.png', (20, 60, 235, 150)),
    ('capsules/main_capsule_616x353.png', (30, 150, 310, 290)),
    ('capsules/library_capsule_600x900.png', (60, 660, 540, 890)),
]
for rel, box in CHECKS:
    r = title_contrast(os.path.join(A, rel), box)
    if r:
        print(f'  {os.path.basename(rel):36s} 文字{r["text_lum"]:6.1f} 背景{r["bg_lum"]:6.1f} 亮度差{r["contrast"]:6.1f} {"✓" if r["contrast"] > 60 else "⚠"}')

print('=' * 100)
print('【5】library logo 透明度')
lg = Image.open(os.path.join(A, 'capsules/library_logo_1280x720.png'))
if lg.mode == 'RGBA':
    al = np.asarray(lg)[..., 3]
    print(f'  alpha: 不透明px {(al > 200).mean() * 100:.1f}%  半透明 {(al > 0) & (al <= 200).mean() * 100:.1f}%  全透明 {(al == 0).mean() * 100:.1f}%')
else:
    print(f'  ✗ mode={lg.mode}，非 RGBA！')

print('=' * 100)
print('【6】page background 亮度（商店页面叠字需要整体偏暗）')
pb = lum(Image.open(os.path.join(A, 'capsules/page_background_1438x810.png')))
print(f'  平均亮度 {float(pb.mean()):.1f}（建议 <110），p90 {float(np.percentile(pb, 90)):.1f}（建议 <170）')

print('=' * 100)
print('【7】源图 title_bg.png')
tg = os.path.join(ROOT, 'assets', 'backgrounds', 'title_bg.png')
im = Image.open(tg)
print(f'  {im.size} mode={im.mode} 锐度={lap_var(lum(im)):.1f}')
print('done')
