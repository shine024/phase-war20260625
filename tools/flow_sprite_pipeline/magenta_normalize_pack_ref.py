# -*- coding: utf-8 -*-
# 参考实现（受跟踪副本，2026-10-10 自 flow_m1a2sep 批收编）：换单位改 HERE 工作目录与输出名；门禁清单见 docs/FLOW_精灵帧生成工作流.md §12。
"""mod_arm_m1a2sep 六格攻击归一化 + 256 装帧 + idle bob + 卡图合成 + 锚点测量
锚定特征: 履带带(暗色最长横行段)——炮口焰/硝烟不进入判据
缩放: 全局 s = 252 / max(帧alpha bbox 跨度); 逐帧轴分离修正 rx=s*track_w1/track_wf, ry 同理(|偏差|<1.5% 吸附 1)
横向: rest 帧(1,2,5,6) 履带心对齐帧1; 帧3,4 保留后坐 dx=(tc_f-tc1)*s (|dx|>=2px 才保留)
纵向: 履带底统一 y=242 (ff≈0.0547, 贴旧 0.0527)
"""
from PIL import Image
import numpy as np
import os, json

HERE = os.path.dirname(os.path.abspath(__file__))
FR = 256
GROUND_Y = 236  # 暗计数底; 视觉橡胶底≈+6px≈242, ff≈0.05 对齐旧 0.0527
CANVAS_CX = 128
MAX_SPAN = 252

def load(i):
    return np.asarray(Image.open(os.path.join(HERE, 'kcell%d.png' % i)).convert('RGBA')).copy()

def speck_clean(a):
    """连通域 <60px 且质心距格缘<14px → 清除(邻格渗色斑点)"""
    al = a[:, :, 3] > 0
    h, w = al.shape
    lbl = np.zeros((h, w), np.int32)
    cur = 0
    from collections import deque
    for yy in range(h):
        for xx in range(w):
            if al[yy, xx] and lbl[yy, xx] == 0:
                cur += 1
                dq = deque([(yy, xx)]); lbl[yy, xx] = cur
                px = []
                while dq:
                    y, x = dq.popleft(); px.append((y, x))
                    for dy, dx in ((1,0),(-1,0),(0,1),(0,-1)):
                        ny, nx = y+dy, x+dx
                        if 0 <= ny < h and 0 <= nx < w and al[ny, nx] and lbl[ny, nx] == 0:
                            lbl[ny, nx] = cur; dq.append((ny, nx))
                if len(px) < 60:
                    ys = [p[0] for p in px]; xs = [p[1] for p in px]
                    cy, cx = sum(ys)/len(ys), sum(xs)/len(xs)
                    if cy < 14 or cy > h-14 or cx < 14 or cx > w-14:
                        for y, x in px:
                            a[y, x, :] = 0
    return a

def track_metrics(a):
    """暗色掩码 → 履带带(最长横行段>=150px): 返回 bottom, w, h, cx; 找不到回退全暗bbox"""
    rgb = a[:, :, :3].astype(int)
    al = a[:, :, 3]
    dark = (rgb.max(axis=2) < 150) & (al > 100)
    h, w = dark.shape
    # 双判据: 宽度=连续run>=150(仅履带带产生, FX免疫); 底缘/cx=行计数>=80(路轮高光不漏底行)
    wrun = 0; wcx = None
    for y in range(h):
        row = dark[y]; x = 0
        while x < w:
            if row[x]:
                x0 = x
                while x < w and row[x]: x += 1
                if x - x0 >= 150 and x - x0 > wrun:
                    wrun = x - x0; wcx = (x0 + x) / 2.0
            else: x += 1
    rows = []
    for y in range(h):
        xs = np.where(dark[y])[0]
        if len(xs) >= 80:
            rows.append((y, float(np.mean(xs))))
    if not rows or wrun == 0:
        ys, xs = np.where(dark)
        return int(ys.max()), int(xs.max()-xs.min()+1), float(xs.mean())
    return rows[-1][0], wrun, wcx

cells = [load(i) for i in range(1, 7)]
cells = [speck_clean(c) for c in cells]

tm = [track_metrics(c) for c in cells]
spans = []
for i, c in enumerate(cells):
    ys, xs = np.where(c[:, :, 3] > 10)
    spans.append(int(xs.max() - xs.min() + 1))
S = max(spans)
s = MAX_SPAN / S
print('src spans:', spans, 'max', S, 'global s=%.4f' % s)

tw1 = tm[0][1]
frames = []
for i, c in enumerate(cells):
    rx = tw1 / tm[i][1]
    if abs(rx - 1) < 0.05: rx = 1.0  # 同模板拷贝格: ±3.6% = 遮盖板AA噪声, 吸附
    sx, sy = s * rx, s * rx
    im = Image.fromarray(c, 'RGBA')
    nw, nh = int(round(c.shape[1] * sx)), int(round(c.shape[0] * sy))
    r = np.asarray(im.resize((nw, nh), Image.LANCZOS)).copy()
    t = track_metrics(r)
    dx = (tm[i][2] - tm[0][2]) * s  # 源域后坐量→帧域
    if i in (2, 3) and abs(dx) >= 2.0:
        keep = dx
    else:
        keep = 0.0
    x_off = int(round(CANVAS_CX - t[2] + keep))
    # 钳制: 内容左缘至少留 2px(保闪焰尖不被裁)
    ys0, xs0 = np.where(r[:, :, 3] > 10)
    if x_off + int(xs0.min()) < 2:
        keep += 2 - (x_off + int(xs0.min()))
        x_off = int(round(CANVAS_CX - t[2] + keep))
    y_off = int(round(GROUND_Y - t[0]))
    canvas = np.zeros((FR, FR, 4), np.uint8)
    ys, xs = np.where(r[:, :, 3] > 0)
    by0, by1 = ys.min(), ys.max(); bx0, bx1 = xs.min(), xs.max()
    # 先裁到内容再放置, 避免负偏移裁切
    crop = r[by0:by1+1, bx0:bx1+1]
    px = x_off + bx0; py = y_off + by0
    ch, cw = crop.shape[:2]
    cx0, cy0 = max(0, px), max(0, py)
    cx1, cy1 = min(FR, px + cw), min(FR, py + ch)
    canvas[cy0:cy1, cx0:cx1] = crop[cy0-py:cy1-py, cx0-px:cx1-px]
    frames.append(canvas)
    tb_final = y_off + t[0]
    print('cell%d rx=%.3f span=%d track_w=%d dx_keep=%.1f place=(%d,%d) final_bottom=%d bbox x[%d..%d] y[%d..%d]'
          % (i+1, rx, spans[i], tm[i][1], keep, px, py, tb_final, px, px+cw-1, py, py+ch-1))

# 门禁预检: 贴边/品红残留/空帧
print('--- gates ---')
ok = True
for i, f in enumerate(frames):
    ys, xs = np.where(f[:, :, 3] > 10)
    if len(ys) == 0: print('cell%d EMPTY' % (i+1)); ok = False; continue
    touch = xs.min() == 0 or xs.max() == FR-1 or ys.min() == 0 or ys.max() == FR-1
    rgb = f[:, :, :3].astype(int); al = f[:, :, 3]
    magmask = (rgb[:, :, 0] > 140) & (rgb[:, :, 2] > 140) & (rgb[:, :, 1] < 0.75 * np.minimum(rgb[:, :, 0], rgb[:, :, 2]) - 10) & (al > 60)
    if magmask.any():
        # LANCZOS 插值晕: 帧域二次杀 (钢蓝/橙焰/灰烟都不会读作品红)
        f[magmask, 3] = 0
        print('cell%d MAGENTA-resize %d → killed' % (i+1, int(magmask.sum())))
    rgb = f[:, :, :3].astype(int); al = f[:, :, 3]
    mag = ((rgb[:, :, 0] > 140) & (rgb[:, :, 2] > 140) & (rgb[:, :, 1] < 0.75 * np.minimum(rgb[:, :, 0], rgb[:, :, 2]) - 10) & (al > 60)).sum()
    if touch: print('cell%d EDGE-TOUCH x[%d..%d] y[%d..%d]' % (i+1, xs.min(), xs.max(), ys.min(), ys.max())); ok = False
    if mag > 0: print('cell%d MAGENTA %d' % (i+1, mag)); ok = False

# 敌侧 fireX/fireY: 格3 橙焰 (r>190, 90<=g<=190, b<110)
_ys0, _xs0 = np.where(frames[0][:, :, 3] > 10)
foot = round(1 - (_ys0.max() + 1) / FR, 4)  # 视觉地线基准(供 fireY 换算)
f3 = frames[2]
rgb = f3[:, :, :3].astype(int); al = f3[:, :, 3]
orange = (rgb[:, :, 0] > 190) & (rgb[:, :, 1] >= 90) & (rgb[:, :, 1] <= 190) & (rgb[:, :, 2] < 110) & (al > 100)
oys, oxs = np.where(orange)
if len(oxs) > 20:
    per_row_max = {}
    for y, x in zip(oys, oxs):
        per_row_max[y] = max(per_row_max.get(y, 0), x)
    fx = float(np.median(list(per_row_max.values())))
    local = oys[np.abs(oxs - fx) <= 8]
    fy = float(np.median(local)) if len(local) >= 10 else float(np.median(oys))
    fireX_e = round(fx / FR, 4)
    fireY_pct = round(((1 - foot) * FR - fy) / FR * 100, 2)  # 基准=写入ff的视觉地线
    print('flash px=%d fx_med=%.1f fy_med=%.1f → enemy fireX=%s fireY_pct=%s player fireX=%s'
          % (len(oxs), fx, fy, fireX_e, fireY_pct, round(1-fireX_e, 4)))
else:
    fireX_e = None
    print('WARN: flash px=%d too few' % len(oxs))

# idle bob 4 帧
bob = [0, -1, 0, 1]
idle = []
for dy in bob:
    f = np.zeros_like(frames[0])
    src = frames[0]
    if dy <= 0:
        f[0:FR+dy] = src[-dy:FR]
    else:
        f[dy:FR] = src[0:FR-dy]
    idle.append(f)

# 落盘: 帧Debug + sheets + contact
Image.fromarray(np.hstack(frames), 'RGBA').save(os.path.join(HERE, 'sheet_attack.png'))
Image.fromarray(np.hstack(idle), 'RGBA').save(os.path.join(HERE, 'sheet_idle.png'))
dark = np.zeros((FR, FR*6, 3), np.uint8); dark[:] = (28, 33, 48)
for i, f in enumerate(frames):
    al = (f[:, :, 3:4].astype(float) / 255)
    rgb = f[:, :, :3].astype(float)
    x0 = i * FR
    dark[:, x0:x0+FR] = (rgb * al + dark[:, x0:x0+FR] * (1 - al)).astype(np.uint8)
Image.fromarray(dark).save(os.path.join(HERE, 'cmp_frames_dark.png'))

# 主体度量 (anim.json subject)
idle0 = frames[0]
ys, xs = np.where(idle0[:, :, 3] > 10)
idle_w = round((xs.max()-xs.min()+1)/FR, 4); idle_h = round((ys.max()-ys.min()+1)/FR, 4)
atk_w = 0.0; atk_h = 0.0
for f in frames:
    fys, fxs = np.where(f[:, :, 3] > 10)
    atk_w = max(atk_w, (fxs.max()-fxs.min()+1)/FR)
    atk_h = max(atk_h, (fys.max()-fys.min()+1)/FR)
atk_w = round(atk_w, 4); atk_h = round(atk_h, 4)
foot = round(1 - (ys.max()+1)/FR, 4)
print('subject idle_w=%s idle_h=%s attack_w=%s attack_h=%s foot_frac=%s ok=%s'
      % (idle_w, idle_h, atk_w, atk_h, foot, ok))

# ===== 卡图: cell1 体裁剪 → 450px 宽 → 512² 垂直居中; 敌原样(朝左) / 我镜像 =====
c1 = cells[0]
ys, xs = np.where(c1[:, :, 3] > 10)
body = Image.fromarray(c1[ys.min():ys.max()+1, xs.min():xs.max()+1], 'RGBA')
bw, bh = body.size
tw = 450; th = int(round(bh * tw / bw))
body_r = body.resize((tw, th), Image.LANCZOS)
for name, imsrc in [('vis_enemy_023', body_r), ('vis_player_023', body_r.transpose(Image.FLIP_LEFT_RIGHT))]:
    card = Image.new('RGBA', (512, 512), (0, 0, 0, 0))
    card.paste(imsrc, ((512 - tw)//2, (512 - th)//2), imsrc)
    card.save(os.path.join(HERE, name + '.png'))
    ca = np.asarray(card)
    cys, cxs = np.where(ca[:, :, 3] > 10)
    print('%s content x[%d..%d] y[%d..%d] w_frac=%.4f h_frac=%.4f ff=%.4f'
          % (name, cxs.min(), cxs.max(), cys.min(), cys.max(),
             (cxs.max()-cxs.min()+1)/512, (cys.max()-cys.min()+1)/512, 1-(cys.max()+1)/512))

out = {'s': round(s, 4), 'fireX_enemy': fireX_e, 'fireY_pct': fireY_pct,
       'foot_frac': foot, 'idle_w': idle_w, 'idle_h': idle_h, 'attack_w': atk_w, 'attack_h': atk_h,
       'ff_card': round(1-(cys.max()+1)/512, 4), 'hf_card': round((cys.max()-cys.min()+1)/512, 4)}
json.dump(out, open(os.path.join(HERE, 'measure.json'), 'w'), indent=1)
print('MEASURE', json.dumps(out))
