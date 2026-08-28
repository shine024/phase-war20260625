# -*- coding: utf-8 -*-
"""
美术效果领域审计扫描器（阶段4「机」部分）
输出: docs/effect_check_reports/vfx_audit_20260817/scan_result.json + 控制台摘要
检查条款: A1(抠图) A2(出血) A3(规格) A5(帧一致性) A6(透明浪费) E6(双份存储)
          F1(死资产) F2(引用完整性) F3(命名) F4(重复) A4(import设置一致性)
"""
import os, re, json, hashlib, sys
from collections import defaultdict
from PIL import Image
import numpy as np

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
EFFECTS_DIR = os.path.join(ROOT, "assets", "effects")
OUT_DIR = os.path.join(ROOT, "docs", "effect_check_reports", "vfx_audit_20260817")
os.makedirs(OUT_DIR, exist_ok=True)

# ───────────────────────── 1. 磁盘清单 ─────────────────────────
textures = []  # {rel, abs, w, h}
for dp, _, fns in os.walk(EFFECTS_DIR):
    for fn in fns:
        if fn.lower().endswith(".png"):
            p = os.path.join(dp, fn)
            textures.append({"rel": os.path.relpath(p, ROOT).replace(os.sep, "/"), "abs": p})
print(f"[disk] {len(textures)} effect PNGs")

# ───────────────────────── 2. 引用解析（三级） ─────────────────────────
# 收集全部源码文本
SRC_EXTS = (".gd", ".tscn", ".tres", ".cfg", ".import")
src_texts = {}
for base in ("scripts", "scenes", "managers", "data", "resources", "ui", "shaders"):
    bdir = os.path.join(ROOT, base)
    if not os.path.isdir(bdir):
        continue
    for dp, _, fns in os.walk(bdir):
        for fn in fns:
            if fn.endswith(SRC_EXTS):
                p = os.path.join(dp, fn)
                try:
                    src_texts[os.path.relpath(p, ROOT).replace(os.sep, "/")] = open(p, encoding="utf-8", errors="ignore").read()
                except OSError:
                    pass
all_src = "\n".join(src_texts.values())
# 根目录零散 gd 也算
for fn in os.listdir(ROOT):
    if fn.endswith(".gd"):
        all_src += "\n" + open(os.path.join(ROOT, fn), encoding="utf-8", errors="ignore").read()

dir_refs = set(re.findall(r"res://assets/effects/[A-Za-z0-9_/\.\-]+", all_src))

def tier_status(tex):
    """返回引用级别: direct / dirname / basename / prefix / none"""
    res = "res://" + tex["rel"].replace("assets/", "assets/", 1)
    res = "res://" + tex["rel"]  # rel 已含 assets/...
    if res in dir_refs:
        return "direct"
    bn = os.path.splitext(os.path.basename(tex["rel"]))[0]
    if bn in all_src:
        return "basename"
    # 名字构造: 去掉尾部帧号后再查前缀（覆盖 "name_f%d" / "name%d" 拼接）
    m = re.sub(r"(_f)?\d+$", "", bn)
    if m and m != bn and (m + '"') in all_src or (m + "'") in all_src or ('"(' + m) in all_src or (m + "_") in all_src:
        return "prefix"
    # 常量拼接: 目录常量是否存在引用（目录被动态列举/拼名）
    d = os.path.dirname(res) + "/"
    if d in all_src:
        return "dirname"
    return "none"

# ───────────────────────── 3. 像素分析 ─────────────────────────
def analyze(tex):
    img = Image.open(tex["abs"]).convert("RGBA")
    a = np.asarray(img, dtype=np.uint8)
    alpha = a[:, :, 3]
    h, w = alpha.shape
    tex["w"], tex["h"] = w, h
    tex["pot"] = (w & (w - 1)) == 0 and (h & (h - 1)) == 0
    tex["over1024"] = max(w, h) > 1024
    tex["aspect"] = round(max(w, h) / max(1, min(w, h)), 2)

    # A1 四角 8x8 平均 alpha
    c = 8
    corners = [float(alpha[:c, :c].mean()), float(alpha[:c, -c:].mean()),
               float(alpha[-c:, :c].mean()), float(alpha[-c:, -c:].mean())]
    tex["corner_alpha_max"] = round(max(corners), 1)

    # A1 方框: 不透明占比
    opaque = (alpha > 245)
    tex["opaque_ratio"] = round(float(opaque.mean()), 4)

    # 内容 bbox (alpha>10)
    ys, xs = np.where(alpha > 10)
    if len(xs) == 0:
        tex["content_bbox_ratio"] = 0.0
        tex["margin_min_pct"] = 100.0
        tex["ring6_content_pct"] = 0.0
    else:
        x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
        tex["content_bbox_ratio"] = round(float((x1 - x0 + 1) * (y1 - y0 + 1)) / (w * h), 4)
        tex["margin_min_pct"] = round(100.0 * min(x0, w - 1 - x1, y0, h - 1 - y1) / max(w, h), 2)
        # A2 外圈6%环内内容占比（相对全图面积）
        bw = max(2, int(min(w, h) * 0.06))
        ring = np.zeros_like(alpha, dtype=bool)
        ring[:bw, :] = True; ring[-bw:, :] = True; ring[:, :bw] = True; ring[:, -bw:] = True
        tex["ring6_content_pct"] = round(float((ring & (alpha > 10)).sum()) / (w * h), 4)

    # A1 内部洞: 从边界洪水填充透明区，剩余的封闭透明区=洞
    trans = alpha < 10
    hole = None
    if trans.any():
        try:
            from scipy import ndimage  # 可选，缺失则跳过（v20.20-fix: 旧版裸 import 必崩）
        except ImportError:
            ndimage = None
        if ndimage is not None:
            lab, n = ndimage.label(trans)
            border_labels = set(lab[0, :]) | set(lab[-1, :]) | set(lab[:, 0]) | set(lab[:, -1])
            border_labels.discard(0)
            sizes = ndimage.sum(trans, lab, range(1, n + 1))
            worst = 0.0
            for i in range(1, n + 1):
                if i not in border_labels:
                    worst = max(worst, float(sizes[i - 1]) / (w * h))
            hole = round(worst, 4)
    tex["hole_ratio"] = hole

    # A1 边缘残色嫌疑: 最外2px环上 10<alpha<245 的彩色像素占比
    ring2 = np.zeros_like(alpha, dtype=bool)
    ring2[:2, :] = True; ring2[-2:, :] = True; ring2[:, :2] = True; ring2[:, -2:] = True
    semi = (alpha >= 10) & (alpha <= 245)
    tex["edge2_semi_ratio"] = round(float((ring2 & semi).sum()) / (w * h), 4)

    # F4 内容 hash
    tex["hash"] = hashlib.md5(a.tobytes()).hexdigest()
    return tex

print("[scan] analyzing pixels ...")
try:
    import scipy  # noqa
    HAVE_SCIPY = True
except ImportError:
    HAVE_SCIPY = False
    print("[warn] scipy 不可用，跳过内部洞检测")

for t in textures:
    analyze(t)
    if not HAVE_SCIPY:
        t["hole_ratio"] = None

# ───────────────────────── 4. 分组统计 ─────────────────────────
# A5 帧序列: 同目录同前缀 f\d+
groups = defaultdict(list)
for t in textures:
    m = re.match(r"^(.*)_f(\d+)$", os.path.splitext(os.path.basename(t["rel"]))[0])
    if m:
        groups[(os.path.dirname(t["rel"]), m.group(1))].append((int(m.group(2)), t))
frame_issues = []
for (d, name), frames in groups.items():
    frames.sort()
    dims = {(t["w"], t["h"]) for _, t in frames}
    idxs = [i for i, _ in frames]
    contiguous = idxs == list(range(idxs[0], idxs[0] + len(idxs)))
    if len(dims) > 1 or not contiguous:
        frame_issues.append({"dir": d, "name": name, "frames": idxs, "dims": sorted(dims),
                             "issue": "尺寸不一" if len(dims) > 1 else ("编号不连续" if not contiguous else "")})

# E6 双份存储: 散帧组 + 同名 sheet
dual_storage = []
for (d, name), frames in groups.items():
    sheet = os.path.join(EFFECTS_DIR, os.path.relpath(d, os.path.join(ROOT, "assets", "effects")), name + "_sheet.png")
    if os.path.exists(sheet):
        dual_storage.append({"frames": [t["rel"] for _, t in frames], "sheet": os.path.relpath(sheet, ROOT).replace(os.sep, "/")})

# F4 重复 hash
hashes = defaultdict(list)
for t in textures:
    hashes[t["hash"]].append(t["rel"])
dups = {k: v for k, v in hashes.items() if len(v) > 1}

# ───────────────────────── 5. import 设置一致性 (A4/E1) ─────────────────────────
import_settings = defaultdict(list)
for dp, _, fns in os.walk(EFFECTS_DIR):
    for fn in fns:
        if fn.endswith(".import"):
            p = os.path.join(dp, fn)
            txt = open(p, encoding="utf-8", errors="ignore").read()
            key = tuple(re.findall(r"(compress/mode|mipmaps/generate|process/premult_alpha|process/hdr_as_srgb|detect_3d/compress_to)=(\S*)", txt))
            import_settings[tuple(sorted(key))].append(os.path.relpath(p, ROOT).replace(os.sep, "/"))

# ───────────────────────── 6. F2 工程完整性 ─────────────────────────
issues_eng = []
# 孤儿 .import（源文件不存在）
for dp, _, fns in os.walk(ROOT):
    if ".git" in dp or ".godot" in dp or "addons" in dp:
        continue
    for fn in fns:
        if fn.endswith(".import") and "assets" in dp:
            src = os.path.join(dp, fn[:-len(".import")])
            if not os.path.exists(src):
                issues_eng.append({"type": "orphan_import", "path": os.path.relpath(src + ".import", ROOT).replace(os.sep, "/")})
# 孤儿 .uid（对应 .gd 不存在）
for dp, _, fns in os.walk(ROOT):
    if ".git" in dp or ".godot" in dp or "addons" in dp:
        continue
    for fn in fns:
        if fn.endswith(".gd.uid"):
            if not os.path.exists(os.path.join(dp, fn[:-len(".uid")])):
                issues_eng.append({"type": "orphan_uid", "path": os.path.relpath(os.path.join(dp, fn), ROOT).replace(os.sep, "/")})
# 空目录（assets 与 shaders 下）
for dp, _, fns in os.walk(os.path.join(ROOT, "assets")):
    if not fns and not os.listdir(dp):
        issues_eng.append({"type": "empty_dir", "path": os.path.relpath(dp, ROOT).replace(os.sep, "/")})
for extra in ("shaders", os.path.join(ROOT, "assets", "battle", "vfx")):
    if os.path.isdir(extra) and not os.listdir(extra):
        issues_eng.append({"type": "empty_dir", "path": os.path.relpath(extra, ROOT).replace(os.sep, "/")})

# ───────────────────────── 7. 汇总输出 ─────────────────────────
report = {
    "textures": [{k: t.get(k) for k in ("rel", "w", "h", "pot", "over1024", "aspect", "corner_alpha_max",
                                        "opaque_ratio", "content_bbox_ratio", "margin_min_pct",
                                        "ring6_content_pct", "hole_ratio", "edge2_semi_ratio", "hash")} | {"ref": tier_status(t)}
                 for t in textures],
    "frame_issues": frame_issues,
    "dual_storage": dual_storage,
    "duplicates": {k[:8]: v for k, v in dups.items()},
    "import_settings_variants": [{"settings": list(k), "count": len(v), "sample": v[:3]} for k, v in import_settings.items()],
    "eng_issues": issues_eng,
    "scipy": HAVE_SCIPY,
}
with open(os.path.join(OUT_DIR, "scan_result.json"), "w", encoding="utf-8") as f:
    json.dump(report, f, ensure_ascii=False, indent=1)

# 控制台摘要
print("\n===== 摘要 =====")
unref = [t for t in report["textures"] if t["ref"] == "none"]
dironly = [t for t in report["textures"] if t["ref"] == "dirname"]
print(f"F1 死资产候选(none): {len(unref)}  | 仅目录级引用(dirname): {len(dironly)}")
for t in unref[:40]:
    print(f"  none   {t['w']}x{t['h']}  {t['rel']}")
over = [t for t in report["textures"] if t["over1024"]]
print(f"\nA3 >1024px: {len(over)}")
for t in over:
    print(f"  {t['w']}x{t['h']}  {t['rel']}  ref={t['ref']}")
nonpot = [t for t in report["textures"] if not t["pot"]]
print(f"\nA3 non-POT(WARN): {len(nonpot)}")
aspect_bad = [t for t in report["textures"] if t["aspect"] > 16]
print(f"A3 长宽比>16: {len(aspect_bad)}")
for t in aspect_bad[:10]:
    print(f"  {t['w']}x{t['h']} ratio={t['aspect']}  {t['rel']}  ref={t['ref']}")
boxy = [t for t in report["textures"] if t["opaque_ratio"] > 0.95]
print(f"\nA1 方框嫌疑(opaque>95%): {len(boxy)}")
for t in boxy[:15]:
    print(f"  opaque={t['opaque_ratio']}  {t['rel']}")
corner = [t for t in report["textures"] if t["corner_alpha_max"] >= 10]
print(f"A1 四角不透明(corner>=10): {len(corner)}")
for t in corner[:15]:
    print(f"  corner={t['corner_alpha_max']}  {t['rel']}")
holes = [t for t in report["textures"] if t["hole_ratio"] and t["hole_ratio"] > 0.005]
print(f"A1 内部洞>0.5%: {len(holes)}")
for t in holes[:15]:
    print(f"  hole={t['hole_ratio']}  {t['rel']}")
bleed = [t for t in report["textures"] if t["ring6_content_pct"] > 0.08]
print(f"\nA2 出血嫌疑(6%环内容>8%): {len(bleed)}")
for t in bleed[:15]:
    print(f"  ring={t['ring6_content_pct']} margin={t['margin_min_pct']}%  {t['rel']}")
waste = [t for t in report["textures"] if t["content_bbox_ratio"] < 0.35]
print(f"\nA6 主体面积<35%: {len(waste)}")
for t in sorted(waste, key=lambda x: x['content_bbox_ratio'])[:15]:
    print(f"  bbox={t['content_bbox_ratio']}  {t['rel']}  ref={t['ref']}")
print(f"\nA5 帧序列问题: {len(frame_issues)}")
for fi in frame_issues:
    print(f"  {fi}")
print(f"\nE6 散帧+sheet 双份: {len(dual_storage)}")
for ds in dual_storage:
    print(f"  {ds['sheet']}  +{len(ds['frames'])}帧")
print(f"\nF4 内容重复: {len(dups)} 组")
for k, v in list(dups.items())[:10]:
    print(f"  {k[:8]}: {v}")
print(f"\nF3 时间戳文件名: ", end="")
ts = [t["rel"] for t in report["textures"] if re.search(r"\d{4}-\d{2}-\d{2}T", t["rel"])]
print(len(ts))
print(f"\nA4/E1 import 设置变体数: {len(import_settings_variants) if False else len(report['import_settings_variants'])}")
for v in report["import_settings_variants"]:
    print(f"  x{v['count']}: {dict(v['settings'])}  e.g. {v['sample'][0] if v['sample'] else ''}")
print(f"\nF2 工程问题: {len(issues_eng)}")
for e in issues_eng:
    print(f"  {e['type']}: {e['path']}")
print(f"\n[done] JSON -> {os.path.join(OUT_DIR, 'scan_result.json')}")
