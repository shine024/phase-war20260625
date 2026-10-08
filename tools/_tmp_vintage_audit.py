# -*- coding: utf-8 -*-
## 资产年代/身份总审计：卡图(敌/我) × idle × attack 的 mtime 断代 + 身份双信号（剪影IoU+调色板交）
## 判据（用户病案口径）：以后生成的为准 → 找出 idle/attack/卡图 不属同一代设计的单位
## 用法: python tools/_tmp_vintage_audit.py   （只读，不改任何资产）
## 输出: _anim_review/vintage_audit.json + 控制台摘要
import json, os, io, sys, datetime
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DUMP = os.path.join(ROOT, "_anim_review", "unit_manifest_full.json")
OUT = os.path.join(ROOT, "_anim_review", "vintage_audit.json")

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")


def res_path(p):
    return os.path.join(ROOT, p[len("res://"):]) if p and p.startswith("res://") else None


def mtime_iso(p):
    try:
        return datetime.datetime.fromtimestamp(os.path.getmtime(p)).strftime("%m-%d %H:%M")
    except OSError:
        return None


def mask_of(im):
    a = np.asarray(im.convert("RGBA"))
    return a[:, :, 3] > 32


def norm_mask(m, box=(176, 96)):
    """bbox 裁剪 → 等比缩放进 box，居中放 192² 画布 → bool mask（身份比较用）"""
    size = 192
    ys, xs = np.where(m)
    if not len(ys):
        return np.zeros((size, size), bool)
    sub = m[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    sh, sw = sub.shape
    sc = min(box[0] / sw, box[1] / sh)
    nw, nh = max(1, int(round(sw * sc))), max(1, int(round(sh * sc)))
    im = Image.fromarray((sub * 255).astype(np.uint8)).resize((nw, nh), Image.BILINEAR)
    cv = np.zeros((size, size), np.uint8)
    x0, y0 = (size - nw) // 2, (size - nh) // 2
    cv[y0:y0 + nh, x0:x0 + nw] = np.asarray(im) > 127
    return cv.astype(bool)


def rgb_hist(im, bins=4):
    a = np.asarray(im.convert("RGBA"))
    px = a[a[:, :, 3] > 32][:, :3]
    if not len(px):
        return np.zeros((bins,) * 3)
    h = np.histogramdd(px / 256.0, bins=(bins, bins, bins), range=[(0, 1)] * 3)[0]
    s = h.sum()
    return h / s if s > 0 else h


def hist_is(h1, h2):
    return float(np.minimum(h1, h2).sum())


def iou(a, b):
    u = (a | b).sum()
    return float((a & b).sum() / u) if u else 0.0


def sig(im0):
    """RGBA Image → (mask, palette, mask_flip, palette_flip)，方向不敏感成对"""
    imf = im0.transpose(Image.FLIP_LEFT_RIGHT)
    return (norm_mask(mask_of(im0)), rgb_hist(im0),
            norm_mask(mask_of(imf)), rgb_hist(imf))


def ident(s1, s2):
    m = max(iou(s1[0], s2[0]), iou(s1[2], s2[2]))
    h = max(hist_is(s1[1], s2[1]), hist_is(s1[3], s2[3]))
    return round(m, 3), round(h, 3)


def sheet_sig(path, fs, n, clean=False):
    """sheet → 代表帧 sig；clean=True 取面积最小帧（避火光）"""
    im = Image.open(path).convert("RGBA")
    cnt = min(n, 32, im.size[0] // fs)
    if cnt <= 0:
        return None
    areas = []
    for i in range(cnt):
        areas.append(int(mask_of(im.crop((i * fs, 0, (i + 1) * fs, fs))).sum()))
    idx = int(np.argmin(areas)) if clean else 0
    f0 = im.crop((idx * fs, 0, (idx + 1) * fs, fs))
    return sig(f0), idx


def main():
    d = json.load(open(DUMP, encoding="utf-8"))
    rows = []
    for sec, arr in (("fam", d["enemies"]), ("ind", d["players"]),
                     ("drop", d["captured"]), ("plat", d["platforms"])):
        for r in arr:
            rows.append(dict(r, _sec=sec))

    report = []
    for r in rows:
        a = r.get("anim") or {}
        fs = a.get("fs") or 256
        n_idle, n_atk = a.get("idle") or 0, a.get("attack") or 0
        p_idle = res_path(a.get("sheet_idle")) if n_idle >= 2 else None
        p_atk = res_path(a.get("sheet_attack")) if n_atk > 0 else None
        icon_e = res_path(r.get("icon")) if r.get("icon") else None
        icon_p = res_path(r.get("icon_player")) if r.get("icon_player") else icon_e
        files = {"cardE": icon_e, "cardP": icon_p, "idle": p_idle, "atk": p_atk}
        ent = {"sec": r["_sec"], "id": r["id"], "name": r.get("name", ""),
               "anim_key": r.get("anim_key", ""),
               "files": {k: (os.path.relpath(v, ROOT).replace("\\", "/") if v else None)
                         for k, v in files.items()},
               "mt": {k: mtime_iso(v) for k, v in files.items()},
               "epochs": {k: (os.path.getmtime(v) if v and os.path.exists(v) else 0)
                          for k, v in files.items()},
               "counts": {"idle": n_idle, "attack": n_atk}}
        try:
            mk = {}
            if icon_e and os.path.exists(icon_e):
                mk["cardE"] = sig(Image.open(icon_e).convert("RGBA"))
            if icon_p and os.path.exists(icon_p):
                mk["cardP"] = sig(Image.open(icon_p).convert("RGBA"))
            idle_sig = idle_idx = None
            if p_idle and os.path.exists(p_idle):
                idle_sig, idle_idx = sheet_sig(p_idle, fs, n_idle)
            atk_sig = atk_idx = None
            if p_atk and os.path.exists(p_atk):
                atk_sig, atk_idx = sheet_sig(p_atk, fs, n_atk, clean=True)
                ent["atk_clean_frame"] = atk_idx
            i = {}
            if idle_sig is not None and atk_sig is not None:
                m, h = ident(idle_sig, atk_sig)
                i["idle_atk"], i["idle_atk_h"] = m, h
            for ck, cm in mk.items():
                if idle_sig is not None:
                    m, h = ident(cm, idle_sig)
                    i[ck + "_idle"], i[ck + "_idle_h"] = m, h
                if atk_sig is not None:
                    m, h = ident(cm, atk_sig)
                    i[ck + "_atk"], i[ck + "_atk_h"] = m, h
            ent["iou"] = i
        except Exception as e:
            ent["err"] = str(e)[:80]
        report.append(ent)

    # ── 判级：mask 与 palette 双低 = 硬伤；单低或双中 = 疑似 ──
    for e in report:
        i = e.get("iou", {})

        def sev(base):
            m, h = i.get(base), i.get(base + "_h")
            if m is None or h is None:
                return ""
            if m < 0.55 and h < 0.55:
                return "HARD"
            if m < 0.68 and h < 0.68:
                return "SOFT"
            return ""

        flags = []
        s = sev("idle_atk")
        if s == "HARD":
            flags.append("IDLE≠ATK")
        elif s == "SOFT":
            flags.append("idle~atk?")
        for ck in ("cardE", "cardP"):
            for ak, an in ((ck + "_idle", "IDLE"), (ck + "_atk", "ATK")):
                s = sev(ak)
                if s == "HARD":
                    flags.append(ck + "≠" + an)
                elif s == "SOFT":
                    flags.append(ck + "~" + an + "?")
        e["flags"] = flags
        ep = e["epochs"]
        e["newest"] = max(ep, key=lambda k: ep.get(k, 0)) if any(ep.values()) else ""

    json.dump(report, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)

    flagged = [e for e in report if e["flags"]]
    flagged.sort(key=lambda e: min([v for k, v in e.get("iou", {}).items()
                                    if not k.endswith("_h")] or [9]))
    print("AUDIT total=%d flagged=%d -> %s" % (len(report), len(flagged),
                                               os.path.relpath(OUT, ROOT)))
    print("\n== 硬伤/疑似（身份分升序；HARD=双信号<0.55）==")
    for e in flagged:
        print("%-4s %-28s iou=%s mt[%s] new=%s %s" % (
            e["sec"], e["id"],
            {k: v for k, v in e.get("iou", {}).items() if not k.endswith("_h")},
            " ".join("%s:%s" % (k, v or "--") for k, v in e["mt"].items()),
            e["newest"], ",".join(e["flags"])))
    allv = sorted(v for e in report for k, v in e.get("iou", {}).items()
                  if not k.endswith("_h"))
    if allv:
        def pct(q):
            return allv[min(len(allv) - 1, int(q * len(allv)))]
        print("\nIoU 分布 p01=%.3f p05=%.3f p10=%.3f p25=%.3f 中位=%.3f" % (
            pct(.01), pct(.05), pct(.10), pct(.25), pct(.5)))


if __name__ == "__main__":
    main()
