# -*- coding: utf-8 -*-
"""视频级自检关卡（动画工作流 ②，docs/ANIM_SPRITE_WORKFLOW.md 〇节）。

用法: python tools/anim_video_selfcheck.py [unit ...]
不带参数 = 检查全部已有 source.mp4 的单位动画。

对每段 source.mp4 均匀抽 4 探针帧, 用 v6 主体连通域抠图后检查:
  keep%   —— 主体占比, 合理区间 3%~50% (过小=主体破碎, 过大=背景没抠掉)
  facing  —— 列轮廓与参考卡(白底ref)正/镜像相关度, 全帧应为 +1 (向左)
  bg%     —— 被判为背景的占比, 应 >55% (白底视频的正常值 ~70-85%)

任一指标失败 → 该视频按工作流直接重新生成, 不进入分帧。
"""
import os
import sys
import glob
import json
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
OUT_DIR = os.path.join(ROOT, "资料", "单位分帧动画")
REF_DIR = os.path.join(OUT_DIR, "_ref")
FFMPEG = r"D:\360安全浏览器下载\铁血联盟3\Godot\ffmpeg-8.0-essentials_build\ffmpeg-8.0-essentials_build\bin\ffmpeg.exe"

from PIL import Image, ImageDraw  # noqa: E402
import numpy as np  # noqa: E402


def matte_v6(arr):
    """与 generate_unit_animations.alpha_of v6c 同源(cv2 加速): 浅色低饱和连通域 + 纯白长条种子 + 最大连通块。"""
    import cv2
    rgbv = arr.astype(np.int16)
    mn = rgbv.min(axis=2)
    sat = rgbv.max(axis=2) - rgbv.min(axis=2)
    h, w = mn.shape
    ok = ((mn >= 135) & (sat <= 75)).astype(np.uint8)
    num, lab = cv2.connectedComponents(ok)
    kill = set()
    for edge in (lab[0, :], lab[-1, :], lab[:, 0], lab[:, -1]):
        kill |= set(np.unique(edge).tolist())
    kill.discard(0)
    pw = ((mn >= 240) & (sat <= 75)).astype(np.uint8)
    n2, lab2, st2, _ = cv2.connectedComponentsWithStats(pw)
    for i in range(1, n2):
        x, y, bw2, bh2, area = st2[i]
        if max(bw2, bh2) >= 40:
            kill.add(int(lab[int(y + bh2 // 2), int(x + bw2 // 2)]))
    kill.discard(0)
    killed = np.isin(lab, list(kill)) if kill else np.zeros((h, w), bool)
    keepc = ~killed
    n3, lab3, st3, _ = cv2.connectedComponentsWithStats(keepc.astype(np.uint8))
    if n3 > 1:
        big = 1 + int(np.argmax(st3[1:, cv2.CC_STAT_AREA]))
        return lab3 == big
    return keepc


def probe_frames(mp4, out_dir, n=4):
    """均匀抽 n 帧到 out_dir, 返回帧路径列表。"""
    os.makedirs(out_dir, exist_ok=True)
    for p in glob.glob(os.path.join(out_dir, "probe*.png")):
        os.remove(p)
    dur = subprocess.run(
        [FFMPEG, "-i", mp4], capture_output=True).stderr.decode("utf-8", "ignore")
    import re
    m = re.search(r"Duration:\s*(\d+):(\d+):(\d+\.?\d*)", dur)
    if not m:
        return []
    total = int(m.group(1)) * 3600 + int(m.group(2)) * 60 + float(m.group(3))
    outs = []
    for i in range(n):
        t = total * (i + 0.5) / n
        fp = os.path.join(out_dir, "probe%d.png" % i)
        r = subprocess.run(
            [FFMPEG, "-y", "-ss", "%.2f" % t, "-i", mp4, "-frames:v", "1", fp],
            capture_output=True)
        if r.returncode == 0 and os.path.exists(fp):
            outs.append(fp)
    return outs


def check_one(unit_dir, anim, ref_jpg):
    mp4 = os.path.join(unit_dir, anim, "source.mp4")
    if not os.path.exists(mp4):
        return None
    ref = np.asarray(Image.open(ref_jpg).convert("RGB"), dtype=np.float32)
    ref_mask = ref.min(axis=2) < 235
    ref_prof = ref_mask.sum(axis=0).astype(np.float32)

    def to128(p):
        x_old = np.linspace(0.0, 1.0, len(p))
        x_new = np.linspace(0.0, 1.0, 128)
        return np.interp(x_new, x_old, p.astype(np.float64))

    rp = to128(ref_prof)
    rp = rp / max(1.0, rp.sum())
    rp_mir = rp[::-1]
    pdir = os.path.join(unit_dir, anim, "_probe")
    frames = probe_frames(mp4, pdir)
    if len(frames) < 3:
        return {"anim": anim, "verdict": "FAIL", "reason": "抽帧失败(%d)" % len(frames)}
    keeps, facings = [], []
    for fp in frames:
        arr = np.asarray(Image.open(fp).convert("RGB"))
        keep = matte_v6(arr)
        keeps.append(float(keep.mean() * 100))
        prof = keep.sum(axis=0).astype(np.float32)
        s = prof.sum()
        if s < 1:
            facings.append(0.0)
            continue
        pn = to128(prof)
        pn = pn / pn.sum()
        c_n = float((pn * rp).sum())
        c_m = float((pn * rp_mir).sum())
        facings.append(1 if c_n >= c_m else -1)
    kp = sum(keeps) / len(keeps)
    bg = 100.0 - kp
    n_left = sum(1 for f in facings if f == 1)
    verdict = "PASS"
    reasons = []
    if not (3.0 <= kp <= 50.0):
        verdict = "FAIL"; reasons.append("keep%%=%.1f 越界" % kp)
    if n_left < len(facings):
        verdict = "FAIL"; reasons.append("朝向 %d/%d 向左" % (n_left, len(facings)))
    if bg < 55.0:
        verdict = "FAIL"; reasons.append("bg%%=%.1f 过低" % bg)
    return {"anim": anim, "verdict": verdict, "keep": round(kp, 1), "bg": round(bg, 1),
            "left": "%d/%d" % (n_left, len(frames)), "reason": "; ".join(reasons)}


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    units = sys.argv[1:]
    results = {}
    if units:
        dirs = [(u, os.path.join(OUT_DIR, u)) for u in units]
    else:
        dirs = []
        for d in sorted(os.listdir(OUT_DIR)):
            full = os.path.join(OUT_DIR, d)
            if os.path.isdir(full) and not d.startswith("_"):
                dirs.append((d.split("_", 1)[-1], full))
    for ukey, udir in dirs:
        ref = None
        for f in glob.glob(os.path.join(REF_DIR, "*white.jpg")):
            stem = os.path.basename(f).replace("_white.jpg", "")
            if udir.split(os.sep)[-1].startswith(stem) or stem == ukey:
                ref = f
                break
        if ref is None:
            continue
        for anim in ["idle", "attack"]:
            r = check_one(udir, anim, ref)
            if r:
                results["%s/%s" % (udir.split(os.sep)[-1], anim)] = r
                print("%-40s %-6s keep=%5s bg=%5s 左=%s %s" % (
                    udir.split(os.sep)[-1] + "/" + anim, r["verdict"],
                    r.get("keep", "-"), r.get("bg", "-"), r.get("left", "-"), r.get("reason", "")))
    fails = [k for k, v in results.items() if v["verdict"] != "PASS"]
    print("\n== %d 套检查, %d 失败 ==" % (len(results), len(fails)))
    for k in fails:
        print("  FAIL:", k, results[k].get("reason", ""))
    with open(os.path.join(OUT_DIR, "_selfcheck.json"), "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
