# -*- coding: utf-8 -*-
"""从 Noto Sans SC 可变字体生成项目打包用的中文字体子集。

产物（assets/fonts/）：
  NotoSansSC-Regular.ttf  — wght=400 实例化 + 子集
  NotoSansSC-Medium.ttf   — wght=500 实例化 + 子集（标题/强调备选）

子集字符集 = ASCII 可打印 + GB2312 全部汉字/符号 + 项目代码中实际出现的
非 ASCII 字符（scenes/scripts/managers/data/resources 扫描，防生僻字缺字形）。

用法：python tools/make_cjk_font_subset.py
依赖：pip install fonttools
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# 源可变字体不入 git（.font_src/ 已 gitignore）；缺失时自动从 google/fonts 仓库下载
SRC_VF = os.path.join(ROOT, ".font_src", "NotoSansSC-VF.ttf")
VF_URL = "https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf"
OUT_DIR = os.path.join(ROOT, "assets", "fonts")
SCAN_DIRS = ["scenes", "scripts", "managers", "data", "resources", "tests"]
SCAN_EXT = {".gd", ".tscn", ".json", ".tres", ".cfg"}

# 运行期可能拼出来但代码里没写全的符号兜底（GB2312 已覆盖大部分）
EXTRA_CHARS = (
    "★☆◆◇○●□■▲▽※→←↑↓↔⇒·—…～￥％＋－×÷≠≤≥∞℃"
    "①②③④⑤⑥⑦⑧⑨⑩⑪⑫ Cavalry0123456789"
)


def collect_project_chars() -> str:
    chars = set()
    for d in SCAN_DIRS:
        base = os.path.join(ROOT, d)
        if not os.path.isdir(base):
            continue
        for dirpath, _dirnames, filenames in os.walk(base):
            for fn in filenames:
                if os.path.splitext(fn)[1].lower() not in SCAN_EXT:
                    continue
                p = os.path.join(dirpath, fn)
                try:
                    with open(p, "r", encoding="utf-8", errors="ignore") as f:
                        for ch in f.read():
                            if ord(ch) > 127:
                                chars.add(ch)
                except OSError:
                    continue
    return "".join(sorted(chars))


def gb2312_chars() -> str:
    out = []
    for hb in range(0xB0, 0xF8):  # 汉字区（一级+二级）
        for lb in range(0xA1, 0xFF):
            try:
                out.append(bytes([hb, lb]).decode("gb2312"))
            except UnicodeDecodeError:
                continue
    for hb in range(0xA1, 0xAA):  # 符号区（★☆◆●等在此）
        for lb in range(0xA1, 0xFF):
            try:
                out.append(bytes([hb, lb]).decode("gb2312"))
            except UnicodeDecodeError:
                continue
    return "".join(out)


def ensure_source_font() -> bool:
    if os.path.exists(SRC_VF):
        return True
    os.makedirs(os.path.dirname(SRC_VF), exist_ok=True)
    print(f"[fetch] 下载源字体 -> {SRC_VF}")
    import urllib.request
    try:
        urllib.request.urlretrieve(VF_URL, SRC_VF)
    except OSError as e:
        print(f"[ERR] 下载失败: {e}（可手动下载放到 .font_src/NotoSansSC-VF.ttf）")
        return False
    return True


def main() -> int:
    if not ensure_source_font():
        return 1

    charset = (
        "".join(chr(c) for c in range(0x20, 0x7F))
        + EXTRA_CHARS
        + gb2312_chars()
        + collect_project_chars()
    )
    charset = "".join(sorted(set(charset)))
    charset_path = os.path.join(ROOT, ".godot", "cjk_charset.txt")
    with open(charset_path, "w", encoding="utf-8") as f:
        f.write(charset)
    print(f"[subset] 字符集 {len(charset)} 字符 -> {charset_path}")

    results = []
    for weight, out_name in ((400, "NotoSansSC-Regular.ttf"), (500, "NotoSansSC-Medium.ttf")):
        instanced = os.path.join(ROOT, ".godot", f"_noto_w{weight}.ttf")
        r1 = subprocess.run(
            [sys.executable, "-m", "fontTools.varLib.instancer",
             SRC_VF, f"wght={weight}", "-o", instanced, "--quiet"],
            capture_output=True, text=True)
        if r1.returncode != 0:
            print(f"[ERR] instancer wght={weight} 失败:\n{r1.stderr[-1500:]}")
            return 1
        out_path = os.path.join(OUT_DIR, out_name)
        r2 = subprocess.run(
            [sys.executable, "-m", "fontTools.subset", instanced,
             f"--text-file={charset_path}",
             f"--output-file={out_path}",
             "--layout-features=*", "--glyph-names",
             "--drop-tables+=DSIG", "--no-hinting"],
            capture_output=True, text=True)
        if r2.returncode != 0:
            print(f"[ERR] subset {out_name} 失败:\n{r2.stderr[-1500:]}")
            return 1
        size_kb = os.path.getsize(out_path) // 1024
        results.append((out_name, size_kb))
        print(f"[subset] {out_name}: {size_kb} KB")

    print("[subset] 完成。后续：godot --headless --import 生成 .import 元数据。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
