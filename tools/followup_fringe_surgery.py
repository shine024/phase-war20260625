# -*- coding: utf-8 -*-
"""部署版品红边晕逐帧手术（2026-10-06 follow-up 批，26 attack + 4 idle 家）。

对象：`.godot/unit_review/fam43_deploy_v2/fringe_followup_20261006.json` 清单——
其余批次（route_apply/早批/img25/MK）部署 sheet 上的同款品红 AA 边晕。
路线：**部署版直接手术**（MK 传统），不重生成不重部署——上游锚定可能已被并行
会话重掷（锚定时效门），重生成会引入边晕以外的漂移。

与 load_anchor 修法的差异（部署版特有）：
1. sheet 已烘描边（anim.json outline.color，α≈217 暗色环，落在原纯透明区）——
   边圈 dilation 必须把描边环视作透明，否则够不着晕带；
2. 选择性掩码：只重染「落在 最近非pm实色→纯品红 线段附近」的 pm 像素
   （seg_fit：w*>0.06 且 err<50，键控混合特征、与本体亮度无关），品红/紫罗兰
   **本体涂装的 AA**（对自身涂装实色投影 proj_any≈0）原样保留——fe_ 族大面
   品红涂装靠它保命；
3. 回填源 = 实色且非 pm 且非描边环；参考系（proj 基准）= 实色含 pm 但非描边环
   （涂装 AA 的最近实色是它自己的涂装 → proj≈0 → 天然豁免）。

用法：
  python tools/followup_fringe_surgery.py          # 执行手术（备份→改写→md5 校验）
  python tools/followup_fringe_surgery.py --rescan  # 只重扫边晕计数（f0+f1 口径）
"""
import sys, os, json, hashlib, argparse
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # GBK 控制台防炸
except Exception:
    pass
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIM = os.path.join(ROOT, "assets", "effects", "unit_anims")
OUT = os.path.join(ROOT, ".godot", "unit_review", "fam43_deploy_v2")
FU = os.path.join(OUT, "fringe_followup_20261006.json")
BAK = os.path.join(OUT, "_old", "followup_fringe_20261006")

PROJ_ANY_T = 25   # 对任意实色基准的品红投影阈值（涂装 AA 自参照≈0 → 豁免）


def pm_sig(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx = a[..., :3].max(axis=2)
    s = (mx - a[..., :3].min(axis=2)) / np.maximum(mx, 1)
    return (r > g + 15) & (b > g + 15) & (s > 0.20)


def outline_mask(a, oc):
    """烘焙描边环：颜色近 anim.json outline.color 且距 α<16 在 4px 内（描边宽 4）。"""
    if oc is None:
        return np.zeros(a.shape[:2], bool)
    d = np.abs(a[..., :3] - np.array(oc[:3])).sum(axis=2)
    return (d < 60) & (a[..., 3] >= 16) & ndi.binary_dilation(a[..., 3] < 16, iterations=4)


def frame_surgery(a, oc):
    """单帧 256×256 手术，返回 (改写RGB数组, recolor像素数)。alpha 不动。

    判据（两翻车实录定形：①单门 proj>60 对暗色本体失明——暗体×低权品红=暗梅色
    proj 仅 ~20；②最近实色本身可能被 LANCZOS 内渗染色、当参考系会漏杀）：
      seg_fit  = 像素落在「最近非 pm 实色 → 纯品红(255,0,255)」线段附近
                 （w*>0.06 且 err<50）→ 键控混合特征，亮度无关；
      proj_any = 对最近「任意实色」品红方向投影 > 25（涂装 AA 对自身涂装 ≈0 → 豁免；
                 晕贴品红涂装边 ≈0 → 弃治=对涂装视觉 camouflage，无害）。
    """
    al = a[..., 3]
    pm = pm_sig(a.astype(int))
    ol = outline_mask(a, oc)
    transp_eff = (al < 16) | ol
    edge_zone = ndi.binary_dilation(transp_eff, iterations=2)
    solid_any = (al >= 200) & ~ol          # proj 基准：含 pm 涂装
    solid_ok = solid_any & ~pm             # 回填源：非 pm
    if not solid_any.any() or not solid_ok.any():
        return a, 0
    _, (ry, rx) = ndi.distance_transform_edt(~solid_any, return_indices=True)
    _, (sy, sx) = ndi.distance_transform_edt(~solid_ok, return_indices=True)
    rgb = a[..., :3].astype(int)
    MAG = np.array([255, 0, 255])
    d_any = rgb - a[ry, rx, :3].astype(int)
    proj_any = d_any[..., 0] - 2 * d_any[..., 1] + d_any[..., 2]
    ref = a[sy, sx, :3].astype(int)        # 回填源色 = 线段起点
    seg = MAG - ref
    vv = rgb - ref
    denom = np.maximum((seg * seg).sum(axis=2), 400)
    w = (vv * seg).sum(axis=2) / denom
    w = np.clip(w, 0.0, 1.0)
    pred = ref + w[..., None] * seg
    err = np.sqrt(((rgb - pred) ** 2).sum(axis=2))
    d_ok = rgb - ref
    proj_ok = d_ok[..., 0] - 2 * d_ok[..., 1] + d_ok[..., 2]
    recolor = (pm & (al >= 16) & (edge_zone | (al < 200)) & (proj_any > PROJ_ANY_T)
               & (((w > 0.06) & (err < 60))         # 暗体低权混合：线段拟合
                  | (proj_ok > 60)))                # 亮体混合：对非 pm 实色投影必大
    near_pm = (al < 16) & pm               # 残余近透 pm RGB 也回填（描边环非 pm，不受影响）
    out = a.copy()
    out[..., :3][recolor] = a[sy, sx, :3][recolor]
    out[..., :3][near_pm] = a[sy, sx, :3][near_pm]
    return out, int(recolor.sum())


def fringe_f01(sheet, n):
    """复查口径：f0+f1 带内 pm 像素数（与 followup json 同口径）。"""
    tot = 0
    for f in range(min(2, n)):
        a = sheet[:, f * 256:(f + 1) * 256].astype(int)
        al = a[..., 3]
        tot += int((pm_sig(a) & (al >= 16) & (al < 200)).sum())
    return tot


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rescan", action="store_true")
    args = ap.parse_args()
    fu = json.load(open(FU, encoding="utf-8"))
    items = [(e["key"], "attack") for e in fu["attack"]] + [(e["key"], "idle") for e in fu["idle"]]
    report = {}
    for k, kind in items:
        d = os.path.join(ANIM, k)
        aj = json.load(open(os.path.join(d, "anim.json"), encoding="utf-8"))
        n = aj.get("counts", {}).get(kind, 0)
        if not n:
            print("[skip] %s %s no-counts" % (k, kind)); continue
        oc = (aj.get("outline") or {}).get("color")
        sp = os.path.join(d, "sheet_%s.png" % kind)
        img = Image.open(sp).convert("RGBA")
        sheet = np.array(img)
        before = fringe_f01(sheet, n)
        if args.rescan:
            print("%-28s %-6s f01=%d" % (k, kind[0].upper(), before))
            report["%s_%s" % (k, kind)] = before
            continue
        os.makedirs(BAK, exist_ok=True)
        bp = os.path.join(BAK, "%s_%s.png" % (k, kind))
        if not os.path.exists(bp):
            img.save(bp)
        md5_src = hashlib.md5(open(sp, "rb").read()).hexdigest()
        changed = 0
        for f in range(n):
            cell = sheet[:, f * 256:(f + 1) * 256]
            out, c = frame_surgery(cell, oc)
            changed += c
            sheet[:, f * 256:(f + 1) * 256] = out
        after = fringe_f01(sheet, n)
        Image.fromarray(sheet).save(sp)
        md5_new = hashlib.md5(open(sp, "rb").read()).hexdigest()
        print("%-28s %-6s f01 %5d -> %4d  recolor=%5d  md5 %s..%s" %
              (k, kind[0].upper(), before, after, changed, md5_src[:6], md5_new[:6]))
        report["%s_%s" % (k, kind)] = {"before": before, "after": after, "recolor_px": changed}
    if args.rescan:
        json.dump(report, open(os.path.join(OUT, "fringe_followup_rescan.json"), "w", encoding="utf-8"),
                  ensure_ascii=False, indent=1)
    else:
        json.dump(report, open(os.path.join(OUT, "fringe_followup_surgery_report.json"), "w", encoding="utf-8"),
                  ensure_ascii=False, indent=1)
        print("backup -> %s" % BAK)


if __name__ == "__main__":
    main()
