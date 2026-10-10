# -*- coding: utf-8 -*-
"""
anim_subject_normalize.py — 动画雪碧图主体归一 + anim.json subject 元数据回填
=============================================================================
v6.55 尺寸链批（战斗界面待机/攻击动画主体大小符合视觉预期）的三件套工具：
  ① --fix-unkeyed     抠除未键控的深色底（边界泛洪，主体/烘焙描边不动）
  ② --normalize-attack  attack f0 主体高对齐 idle f0（脚线锚定整组重缩放）
  ③ subject 元数据写入 anim.json（部署门数据源，运行期不消费——运行期由
     UnitFrameAnim 驱动器对 idle f0 做 used_rect 实扫描，本块用于校验门对账）

铁律（沿 deploy_unit_anims / _tmp_fix77 先例）:
  - png 不入 git：运行本工具前必须外部备份（本批备份
    D:/godotplay/_art_backup/unit_anims_pre_subject_20261010/）
  - 再生成 sheet 后必须重跑本工具（幂等）：部署门校验
    「无 subject 块 = 资产过期」
  - 帧缘振铃规则：重缩放后逐帧断言实心(α≥128)零触边（帧缘 2px 内）

用法:
  python tools/anim_subject_normalize.py                # 全量处理（抠底+归一+写subject）
  python tools/anim_subject_normalize.py --verify       # 只校验不写
  python tools/anim_subject_normalize.py --dir ww2_arm_sherman   # 单目录
"""
import argparse
import json
import os
import sys
from collections import deque

import numpy as np
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', 'assets', 'effects', 'unit_anims'))
UNKEYED_OPAQUE_THRESHOLD = 0.55   # 单帧 α≥128 占比超过此值 → 疑似未抠底
DRIFT_TOLERANCE = 0.03            # attack f0 主体高对 idle f0 容差（3% 内不动）
EDGE_MARGIN_PX = 2                # 重缩放后实心内容距帧缘最小距离
KEY_TOLERANCE = 28                # 泛洪键控色距容差（RGB 各通道和 = tol*3）
# 实心主体阈值（2026-10-10 二轮）：老批次坦克 attack 车体画得小、半透明烟尘 bbox 又
# 顶满帧缘导致逐帧钳制失效（残差 0.69~0.84 修不动）。α≥250 只认实心车体——缩放比与
# 防触边钳制都按它算；脚线锚与裁剪范围仍用全 α 底缘（含描边与羽化）。
BODY_SOLID_ALPHA = 250


def solid_bbox(frame_rgba):
    """实心主体 bbox（α≥BODY_SOLID_ALPHA）；烟尘/火光/羽化边全排除。
    软笔触美术（喷枪/光晕，实心像素 <不透明内容 5%）返回 None——调用方必须
    回退 smart_bbox 全 α 口径，否则 idle/attack 两边口径错配会整体错缩。"""
    m = frame_rgba[:, :, 3] >= BODY_SOLID_ALPHA
    if m.sum() < max(64, (frame_rgba[:, :, 3] >= 32).sum() * 0.05):
        return None
    return bbox_of(m)


def frames_of(png_path, fs):
    im = np.asarray(Image.open(png_path).convert('RGBA'), dtype=np.uint8)
    if im.shape[1] % fs != 0:
        raise ValueError(f'{png_path}: 宽 {im.shape[1]} 不是 fs={fs} 整数倍')
    n = im.shape[1] // fs
    return [im[:, i * fs:(i + 1) * fs, :].copy() for i in range(n)]


def body_mask(frame_rgba):
    """主体掩码：不透明像素剔除帧内火光（橙黄/蓝白/白炽三通道词表）。"""
    r = frame_rgba[:, :, 0].astype(np.int16)
    g = frame_rgba[:, :, 1].astype(np.int16)
    b = frame_rgba[:, :, 2].astype(np.int16)
    al = frame_rgba[:, :, 3]
    opaque = al >= 32
    flash = (((r > 170) & (g > 90) & (b < 120) & ((r - b) > 70))
             | ((b > 190) & (r < 140) & (g > 140))
             | ((r > 230) & (g > 230) & (b > 230)))
    return opaque & ~flash


def bbox_of(mask):
    ys, xs = np.where(mask)
    if len(xs) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def smart_bbox(frame_rgba):
    """剔火光主体 bbox；火光占比过高（主体被剔剩 <40%）回退全 alpha bbox。"""
    full = frame_rgba[:, :, 3] >= 32
    body = body_mask(frame_rgba)
    fb, bb_ = bbox_of(full), bbox_of(body)
    if fb is None:
        return None, False
    if bb_ is None or body.sum() < full.sum() * 0.4:
        return fb, False
    return bb_, True


def key_frame_background(fr, tol=KEY_TOLERANCE):
    """单帧边界泛洪键控。返回 (处理后帧, 杀除像素数)。"""
    H, W = fr.shape[:2]
    rgb = fr[:, :, :3].astype(np.int16)
    al = fr[:, :, 3]
    border_rgb = np.concatenate([rgb[0, :, :], rgb[-1, :, :], rgb[:, 0, :], rgb[:, -1, :]], axis=0)
    border_al = np.concatenate([al[0, :], al[-1, :], al[:, 0], al[:, -1]])
    border_rgb = border_rgb[border_al >= 128]
    if len(border_rgb) == 0:
        return fr, 0
    med = np.median(border_rgb, axis=0)
    similar = (np.abs(rgb - med).sum(axis=2) <= tol * 3) & (al > 0)
    bg = np.zeros((H, W), dtype=bool)
    dq = deque()
    for x in range(W):
        for y in (0, H - 1):
            if similar[y, x] and not bg[y, x]:
                bg[y, x] = True
                dq.append((y, x))
    for y in range(H):
        for x in (0, W - 1):
            if similar[y, x] and not bg[y, x]:
                bg[y, x] = True
                dq.append((y, x))
    while dq:
        y, x = dq.popleft()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < H and 0 <= nx < W and similar[ny, nx] and not bg[ny, nx]:
                bg[ny, nx] = True
                dq.append((ny, nx))
    out = fr.copy()
    out[:, :, 3][bg] = 0
    # 1px 羽化：紧邻背景的不透明像素 α×0.7 去黑晕
    bgp = np.pad(bg, 1, constant_values=True)
    halo = np.zeros((H, W), dtype=bool)
    for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        halo |= bgp[1 + dy:1 + dy + H, 1 + dx:1 + dx + W]
    halo &= ~bg & (out[:, :, 3] > 0)
    out[:, :, 3][halo] = (out[:, :, 3][halo].astype(np.int16) * 70 // 100).astype(np.uint8)
    return out, int(bg.sum())


def opaque_frac(frames):
    fr = frames[len(frames) // 2]
    return float((fr[:, :, 3] >= 128).mean())


def border_opaque_ratio(frame):
    """帧四边像素的不透明占比——未抠底时背景顶满帧边（≈1.0）；
    大体量美术（堡垒类）本身占画幅大但边界透明（≈0）。"""
    H, W = frame.shape[:2]
    al = frame[:, :, 3]
    border = np.concatenate([al[0, :], al[-1, :], al[:, 0], al[:, -1]])
    return float((border >= 128).mean())


def is_unkeyed(frames):
    """未抠底判定：整帧高不透明 **且** 不透明像素中「主色」占比过半——真背景是
    一整块近单色矩形（键控能力内）；大体量美术（堡垒类）色彩丰富、主色占比低。
    （v2 判据：旧「边界大部分不透明」被 sherman 类背景矩形顶边留透明的资产击穿——
    2026-10-10 五轮实踩。）"""
    fr = frames[len(frames) // 2]
    if opaque_frac(frames) <= UNKEYED_OPAQUE_THRESHOLD:
        return False
    al = fr[:, :, 3]
    op = al >= 128
    if not op.any():
        return False
    rgb = fr[:, :, :3].astype(np.int16)
    med = np.median(rgb[op], axis=0)
    share = float((np.abs(rgb - med).sum(axis=2) <= KEY_TOLERANCE * 3)[op].mean())
    return share > 0.5


def rescale_frame(fr, k):
    """围绕帧自身内容 bbox 底心重缩放（脚线锚定=全 α 底缘）。
    k>1 时的防触边钳制按**实心主体** bbox 算——半透明烟尘允许溢出裁剪，
    车体不被烟尘 bbox 顶满帧缘而钳死（二轮修复 t34/m1a2 类残差）。"""
    bb, _ = smart_bbox(fr)
    if bb is None or abs(k - 1.0) < 1e-6:
        return fr
    H, W = fr.shape[:2]
    x0, y0, x1, y1 = bb
    sb = solid_bbox(fr)
    bw, bh = float(x1 - x0), float(y1 - y0)
    if sb is not None and k > 1.0:
        bw = max(1.0, float(sb[2] - sb[0]))
        bh = max(1.0, float(sb[3] - sb[1]))
    if k > 1.0:
        k_eff = min(k,
                    (W - 2.0 * EDGE_MARGIN_PX) / bw,
                    (H - 2.0 * EDGE_MARGIN_PX) / bh)
    else:
        k_eff = k
    crop = Image.fromarray(fr[y0:y1, x0:x1])
    nw = max(1, int(round((x1 - x0) * k_eff)))
    nh = max(1, int(round((y1 - y0) * k_eff)))
    scaled = np.asarray(crop.resize((nw, nh), Image.LANCZOS), dtype=np.uint8)
    cx = (x0 + x1) / 2.0
    foot_y = y1  # 内容底 = 脚线（含烘焙描边底缘）
    nx0 = int(round(cx - nw / 2.0))
    ny1 = int(round(foot_y))
    out = np.zeros_like(fr)
    sx0, sy0 = max(0, nx0), max(0, ny1 - nh)
    sx1, sy1 = min(W, nx0 + nw), min(H, ny1)
    out[sy0:sy1, sx0:sx1] = scaled[sy0 - ny1 + nh: sy1 - ny1 + nh, sx0 - nx0: sx1 - nx0]
    # 帧缘振铃清理：边缘 2px 内 α<16 归零
    for i in range(EDGE_MARGIN_PX):
        out[i, :, 3][out[i, :, 3] < 16] = 0
        out[H - 1 - i, :, 3][out[H - 1 - i, :, 3] < 16] = 0
        out[:, i, 3][out[:, i, 3] < 16] = 0
        out[:, W - 1 - i, 3][out[:, W - 1 - i, 3] < 16] = 0
    return out


def solid_touches_edge(frames, margin=2):
    bad = 0
    for fr in frames:
        H, W = fr.shape[:2]
        solid = fr[:, :, 3] >= 128
        if (solid[:margin, :].any() or solid[H - margin:, :].any()
                or solid[:, :margin].any() or solid[:, W - margin:].any()):
            bad += 1
    return bad


def _body_touches_edge(fr, margin=2):
    H, W = fr.shape[:2]
    body = body_mask(fr)
    if not body.any():
        return False
    return (body[:margin, :].any() or body[H - margin:, :].any()
            or body[:, :margin].any() or body[:, W - margin:].any())


def save_sheet(path, frames):
    im = np.concatenate(frames, axis=1)
    Image.fromarray(im).save(path)


def trimmed_median_frame_h(frames):
    """attack 参考高 = 各帧**实心主体**高的裁剪中位（去头尾 15%）——半透明烟尘/火光
    不计入（α≥BODY_SOLID_ALPHA），f0 污染与烟尘顶满帧缘两类问题同时免疫；
    干净序列中位≈f0，幂等收敛。"""
    hs = []
    for fr in frames:
        sb = solid_bbox(fr)
        if sb is None:
            fb, _ = smart_bbox(fr)
            sb = fb
        if sb:
            hs.append(float(sb[3] - sb[1]))
    if not hs:
        return 0.0
    hs.sort()
    trim = int(len(hs) * 0.15)
    core = hs[trim:len(hs) - trim] if len(hs) >= 5 else hs
    return core[len(core) // 2]


def process_dir(d, do_fix=True):
    p = os.path.join(ROOT, d)
    json_path = os.path.join(p, 'anim.json')
    meta = json.load(open(json_path, encoding='utf-8'))
    fs = int(meta.get('frame_size', 256))
    idle_path = os.path.join(p, 'sheet_idle.png')
    attack_path = os.path.join(p, 'sheet_attack.png')
    changed = {'unkeyed': False, 'normalized': False, 'subject': False}
    notes = []

    idle = frames_of(idle_path, fs)
    attack = frames_of(attack_path, fs) if os.path.isfile(attack_path) else []

    # ① 抠底（idle / attack 各自判定）
    if do_fix:
        for nm, lst, path in (('idle', idle, idle_path), ('attack', attack, attack_path)):
            if not lst or not is_unkeyed(lst):
                continue
            fixed = []
            killed = 0
            for fr in lst:
                fr2, k = key_frame_background(fr)
                fixed.append(fr2)
                killed += k
            if not is_unkeyed(fixed):
                save_sheet(path, fixed)
                if nm == 'idle':
                    idle = fixed
                else:
                    attack = fixed
                changed['unkeyed'] = True
                notes.append(f'keyed {nm} ({killed}px)')
            else:
                notes.append(f'KEY-FAIL {nm} still opaque={opaque_frac(fixed):.2f}')

    # ② attack f0 → idle f0 主体高归一
    ib, _ = smart_bbox(idle[0])
    subject = {}
    if ib:
        ih_w, ih_h = (ib[2] - ib[0]) / fs, (ib[3] - ib[1]) / fs
        subject['idle_w'] = round(ih_w, 4)
        subject['idle_h'] = round(ih_h, 4)
    if attack and ib and not is_unkeyed(attack):
        # 抠底失败的未键控 sheet 禁止归一——实心/全 α bbox 都会被背景矩形带偏
        # （fut_swarm k=0.506 半帧缩水实踩），保持原样等人工/重生成。
        isb = solid_bbox(idle[0])
        idle_h_px = float(isb[3] - isb[1]) if isb else float(ib[3] - ib[1])
        # 参考高 = attack 各帧主体高的裁剪中位（去头尾 15%）——f0 常被灰白烟雾/尘土
        # 污染（不在火光词表内），中位对峰值帧鲁棒；干净序列中位≈f0，幂等收敛。
        ref_h = trimmed_median_frame_h(attack)
        if ref_h > 0.0:
            k = idle_h_px / max(1.0, ref_h)
            ab, _ = smart_bbox(attack[0])
            subject['attack_w'] = round((ab[2] - ab[0]) / fs, 4) if ab else 0.0
            subject['attack_h'] = round(ref_h / fs, 4)
            if do_fix and abs(k - 1.0) > DRIFT_TOLERANCE:
                fixed = [rescale_frame(fr, k) for fr in attack]
                save_sheet(attack_path, fixed)
                attack = fixed
                changed['normalized'] = True
                notes.append(f'normalized attack x{k:.3f}')
                body_touch = sum(1 for fr in attack if _body_touches_edge(fr))
                if body_touch:
                    notes.append(f'warn {body_touch} frames body at edge')
                subject['attack_w'] = round(subject['attack_w'] * k, 4)
                subject['attack_h'] = round(subject['attack_h'] * k, 4)

    # ③ foot_frac 刷新（仅抠底目录——底曾把内容底缘拖到帧底，旧值必错）
    if changed['unkeyed']:
        bottoms = []
        for fr in idle + attack:
            bb, _ = smart_bbox(fr)
            if bb:
                bottoms.append(bb[3])
        if bottoms:
            meta['foot_frac'] = round(1.0 - max(bottoms) / fs, 4)
            notes.append(f"foot_frac -> {meta['foot_frac']}")

    # ④ subject 块写入（对账数据源；运行期由驱动器实扫不受此影响）
    if subject:
        subject['tool'] = 'anim_subject_normalize.py'
        if meta.get('subject') != subject:
            meta['subject'] = subject
            changed['subject'] = True

    if do_fix and any(changed.values()):
        json.dump(meta, open(json_path, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
    return changed, notes, subject


def verify_dir(d):
    p = os.path.join(ROOT, d)
    meta = json.load(open(os.path.join(p, 'anim.json'), encoding='utf-8'))
    fs = int(meta.get('frame_size', 256))
    problems = []
    if 'subject' not in meta:
        problems.append('no-subject')
        return problems
    idle = frames_of(os.path.join(p, 'sheet_idle.png'), fs)
    attack = frames_of(os.path.join(p, 'sheet_attack.png'), fs)
    if is_unkeyed(idle):
        problems.append('idle-unkeyed')
    if is_unkeyed(attack):
        problems.append('attack-unkeyed')
    ib, _ = smart_bbox(idle[0])
    ab = smart_bbox(attack[0])[0] if attack else None
    if ib and ab is not None:
        ref_h = trimmed_median_frame_h(attack)
        isb = solid_bbox(idle[0])
        idle_ref_h = float(isb[3] - isb[1]) if isb else float(ib[3] - ib[1])
        if ref_h > 0.0:
            drift = ref_h / max(1.0, idle_ref_h)
            if abs(drift - 1.0) > DRIFT_TOLERANCE:
                problems.append(f'drift={drift:.3f}')
    ih = meta['subject'].get('idle_h')
    if ib and ih and abs((ib[3] - ib[1]) / fs - ih) > 0.01:
        problems.append('subject-stale')
    return problems


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--verify', action='store_true')
    ap.add_argument('--dir', action='append', default=[])
    args = ap.parse_args()

    dirs = args.dir or sorted(d for d in os.listdir(ROOT)
                              if os.path.isfile(os.path.join(ROOT, d, 'sheet_idle.png')))
    if args.verify:
        bad = 0
        for d in dirs:
            probs = verify_dir(d)
            if probs:
                bad += 1
                print(f'FAIL {d}: {", ".join(probs)}')
        print(f'verify: {len(dirs) - bad}/{len(dirs)} clean')
        sys.exit(1 if bad else 0)

    n_key = n_norm = n_subj = 0
    for d in dirs:
        changed, notes, subject = process_dir(d)
        n_key += changed['unkeyed']
        n_norm += changed['normalized']
        n_subj += changed['subject']
        tag = ' '.join(k for k, v in changed.items() if v)
        if tag or notes:
            print(f'{d:32s} [{tag or "-"}] {" | ".join(notes)}')
    print(f'\ndone: keyed={n_key} normalized={n_norm} subject_written={n_subj} / {len(dirs)} dirs')


if __name__ == '__main__':
    main()
