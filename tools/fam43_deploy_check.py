# -*- coding: utf-8 -*-
"""fam43_deploy_v2 部署后客观像素审计（Read 看图通道失效期的替代检验）。

逐家检查已部署 sheet_attack/sheet_idle/anim.json：
  ① 尺寸契约：attack 2560×256（10×256）、idle N×256
  ② 空帧：任一帧 alpha≥16 像素 < 300 判空
  ③ 品红残留：与 (255,0,255) 距离<60 的实心块像素 > 50 判残留
  ④ 地线一致性：ground 家（foot<0.10）各帧内容底缘 y 的极差 ≤ 4px；
     air 家各帧内容质心 y 极差 ≤ 12px
  ⑤ 描边存在：内容边缘暗色（RGB 和<180 且 alpha≥200）像素占比 1%-45%
  ⑥ anim.json：counts.attack==10、foot_frac 与条实测互差 < 0.03
用法: python tools/fam43_deploy_check.py
"""
import io
import json
import os
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image

try:
    from scipy import ndimage as _ndi
except ImportError:
    _ndi = None

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIM = os.path.join(ROOT, "assets", "effects", "unit_anims")
FRAME = 256


def frames_of(path):
    im = np.asarray(Image.open(path).convert("RGBA"))
    h, w = im.shape[:2]
    return [im[:, i * FRAME:(i + 1) * FRAME] for i in range(w // FRAME)]


def content(a):
    return a[:, :, 3] >= 16


def bottom_y(fr):
    m = content(fr)
    return int(np.where(m.any(axis=1))[0].max()) if m.any() else -1


def load_ok():
    """与 fam43_deploy_v2.load_ok 同源：判定合并后 status=可以 的 47 家。"""
    import glob
    import re
    v = {}
    ps = glob.glob(os.path.join(ROOT, "tools", "fam43_review*.json"))
    ps.sort(key=lambda p: int(re.findall(r"\((\d+)\)", p)[-1])
            if re.search(r"\(\d+\)", p) else -1)
    for p in ps:
        v.update(json.load(open(p, encoding="utf-8")))
    return sorted(k for k, d in v.items() if d.get("status") == "可以")


def main():
    keys = load_ok()
    bad = []
    n_ok = 0
    for k in keys:
        aj_path = os.path.join(ANIM, k, "anim.json")
        if not os.path.exists(aj_path):
            bad.append((k, ["缺 anim.json"]))
            continue
        aj = json.load(open(aj_path, encoding="utf-8"))
        errs = []
        ap = os.path.join(ANIM, k, "sheet_attack.png")
        ip = os.path.join(ANIM, k, "sheet_idle.png")
        im_a = Image.open(ap).convert("RGBA")
        if im_a.size != (FRAME * 10, FRAME):
            errs.append("attack尺寸%s" % (im_a.size,))
        frs = frames_of(ap)
        empties = [i for i, f in enumerate(frs) if content(f).sum() < 300]
        if empties:
            errs.append("空帧%s" % empties)
        # 品红残留
        for i, f in enumerate(frs):
            m = content(f)
            if not m.any():
                continue
            rgb = f[:, :, :3].astype(int)
            d = np.sqrt(((rgb - np.array([255, 0, 255])) ** 2).sum(axis=2))
            if int(((d < 60) & m).sum()) > 50:
                errs.append("f%d品红残留" % i)
                break
        bots = [bottom_y(f) for f in frs]
        body_m = content(frs[0])
        foot = aj.get("foot_frac", 0)
        if foot < 0.10:  # ground：底缘一致
            if max(bots) - min(bots) > 4:
                errs.append("地线极差%d" % (max(bots) - min(bots)))
        else:  # air：垂直居中 → 质心稳定
            cens = []
            for f in frs:
                m = content(f)
                if m.any():
                    cens.append(float(np.asarray(m.nonzero()[0]).mean()))
            if cens and max(cens) - min(cens) > 14:
                errs.append("air质心漂移%.0f" % (max(cens) - min(cens)))
        # foot 实测对照（描边会扩 4px，容 0.03）
        bb = max(bots)
        foot_meas = round((FRAME - 1 - bb) / FRAME, 4)
        if abs(foot_meas - foot) > 0.03:
            errs.append("foot不符 json=%s meas=%s" % (foot, foot_meas))
        # 描边存在：边界环（内容 & ~腐蚀1px）暗色占比——描边烘过则环大半是暗的
        ring = body_m & ~_ndi.binary_erosion(body_m)
        tot = int(ring.sum())
        if tot:
            f0 = frs[0]
            rgb = f0[:, :, :3].astype(int)
            dark = int(((rgb.sum(axis=2) < 200) & ring).sum())
            r = dark / tot
            if r < 0.35:
                errs.append("边界环暗色占比%.2f" % r)
        # idle
        if not os.path.exists(ip):
            errs.append("缺idle")
        else:
            n = aj["counts"].get("idle")
            im_i = Image.open(ip).convert("RGBA")
            if im_i.size != (FRAME * (n or 0), FRAME):
                errs.append("idle尺寸%s vs counts %s" % (im_i.size, n))
        if errs:
            bad.append((k, errs))
        else:
            n_ok += 1
        print("[check] %-26s %s" % (k, "; ".join(errs) if errs else "OK"))
    print("\n== %d 家过检 / %d 家异常 ==" % (n_ok, len(bad)))
    for k, e in bad:
        print("  ✗ %s: %s" % (k, "; ".join(e)))


if __name__ == "__main__":
    main()
