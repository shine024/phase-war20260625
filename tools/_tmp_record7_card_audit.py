# -*- coding: utf-8 -*-
"""记录7#12/#19/#20 卡图全量机械审计（2026-09-24）。

范围：assets/card_icons/player/*.png + enemy/*.png（跳过 _thumb*、bak_*、占位）。
三项检查（只读审计，不改动任何资产）：
  A 白底未抠——四边 2px 边框环内近白不透明像素占比 ≥55% 判嫌疑（可修复候选）。
  B 边缘截断——内容 bbox（alpha>8）任意边贴到画布边缘 ≤1px 判嫌疑（人形缺脚/装备切边）。
  C 朝向离群——内容 bbox 内左右半 alpha 质量偏侧（|skew|<0.06 视为无法判定），
    按阵营取全 population 中位偏侧为基准，与基准反号者列嫌疑（人工复核，机械判据对
    武器/背包对冲姿势不灵敏，不作定罪）。
输出：stdout 报告（三节各列嫌疑清单 + 汇总计数）。
可重跑：python tools/_tmp_record7_card_audit.py
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(ROOT, 'assets', 'card_icons')

WHITE_T = 235      # 近白阈值
OPAQUE_T = 200     # 不透明阈值
BORDER = 2         # 边框环宽
EDGE_T = 1         # 截断判定：bbox 距边缘 ≤1px


def audit_img(p):
    im = Image.open(p).convert('RGBA')
    w, h = im.size
    px = im.load()
    # A: 边框环近白不透明占比
    ring = tot = 0
    for y in range(h):
        for x in range(w):
            if x < BORDER or x >= w - BORDER or y < BORDER or y >= h - BORDER:
                tot += 1
                r, g, b, a = px[x, y]
                if a > OPAQUE_T and r > WHITE_T and g > WHITE_T and b > WHITE_T:
                    ring += 1
    white_ratio = ring / max(1, tot)
    # B/C: 内容 bbox 与左右质量
    a = im.getchannel('A').point(lambda v: 255 if v > 8 else 0)
    bbox = a.getbbox()
    trunc = []
    if bbox:
        if bbox[0] <= EDGE_T:
            trunc.append('L')
        if bbox[1] <= EDGE_T:
            trunc.append('T')
        if bbox[2] >= w - 1 - EDGE_T:
            trunc.append('R')
        if bbox[3] >= h - 1 - EDGE_T:
            trunc.append('B')
        apx = a.load()
        left = right = 0
        cx = (bbox[0] + bbox[2]) / 2.0
        for y in range(bbox[1], bbox[3]):
            for x in range(bbox[0], bbox[2]):
                if apx[x, y]:
                    if x < cx:
                        left += 1
                    else:
                        right += 1
        t = max(1, left + right)
        skew = (right - left) / t
    else:
        skew = 0.0
    return white_ratio, trunc, skew, (w, h)


def scan(camp):
    rows = []
    d = os.path.join(BASE, camp)
    for fn in sorted(os.listdir(d)):
        if not fn.endswith('.png') or fn.startswith('_'):
            continue
        p = os.path.join(d, fn)
        try:
            wr, trunc, skew, size = audit_img(p)
            rows.append((fn, wr, trunc, skew, size))
        except Exception as e:  # noqa: BLE001
            print(f'  ERR {fn}: {e}')
    return rows


def main():
    all_skews = {}
    results = {}
    for camp in ('player', 'enemy'):
        rows = scan(camp)
        results[camp] = rows
        sk = [r[3] for r in rows if abs(r[3]) >= 0.06]
        all_skews[camp] = sk

    print('=== A. 白底未抠嫌疑（边框环近白占比 ≥0.55）===')
    for camp in ('player', 'enemy'):
        bad = [(fn, wr) for fn, wr, tr, sk, sz in results[camp] if wr >= 0.55]
        print(f'[{camp}] {len(bad)} / {len(results[camp])}')
        for fn, wr in bad:
            print(f'   {fn}  white={wr:.2f}')
    print('=== B. 边缘截断嫌疑（bbox 贴边 ≤1px）===')
    for camp in ('player', 'enemy'):
        bad = [(fn, tr) for fn, wr, tr, sk, sz in results[camp] if tr]
        print(f'[{camp}] {len(bad)} / {len(results[camp])}')
        for fn, tr in bad[:40]:
            print(f'   {fn}  edges={"".join(tr)}')
        if len(bad) > 40:
            print(f'   ...（其余 {len(bad) - 40} 项略）')
    print('=== C. 朝向离群嫌疑（与阵营中位偏侧反号，|skew|≥0.06 参与判定）===')
    for camp in ('player', 'enemy'):
        sk = all_skews[camp]
        if not sk:
            print(f'[{camp}] 可判定样本不足')
            continue
        sk_sorted = sorted(sk)
        median = sk_sorted[len(sk_sorted) // 2]
        base_sign = 1 if median > 0 else -1
        bad = [(fn, sk) for fn, wr, tr, sk, sz in results[camp]
               if abs(sk) >= 0.06 and (1 if sk > 0 else -1) != base_sign]
        print(f'[{camp}] 基准偏侧={"右" if base_sign > 0 else "左"}(median={median:+.2f}) 反号 {len(bad)} / 可判定 {len(sk)}')
        for fn, sk in bad:
            print(f'   {fn}  skew={sk:+.2f}')


if __name__ == '__main__':
    main()
