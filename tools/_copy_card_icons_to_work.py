# -*- coding: utf-8 -*-
"""One-shot: copy all card_icons/*.png into work folder + manifest. Run from repo root."""
import glob
import os
import re
import shutil

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "card_icons")
ROOT = os.path.normpath(ROOT)
DST = os.path.join(ROOT, "work_全卡面加工")


def main() -> None:
    os.makedirs(DST, exist_ok=True)
    pngs = sorted(glob.glob(os.path.join(ROOT, "*.png")))
    for src in pngs:
        shutil.copy2(src, os.path.join(DST, os.path.basename(src)))

    gd = os.path.normpath(os.path.join(ROOT, "..", "..", "data", "default_cards.gd"))
    m: dict[str, str] = {}
    if os.path.isfile(gd):
        text = open(gd, encoding="utf-8").read()
        pat = re.compile(
            r'list\.append\(_(platform|energy_start|energy_regen|energy_instant|energy_hybrid)\("([^"]+)",\s*"([^"]+)"'
        )
        for mo in pat.finditer(text):
            m[mo.group(2) + ".png"] = mo.group(3)

    pl = os.path.normpath(os.path.join(ROOT, "..", "..", "data", "phase_laws.gd"))
    if os.path.isfile(pl):
        lines = open(pl, encoding="utf-8").readlines()
        i = 0
        while i < len(lines):
            mo = re.match(r'\s*"([a-z0-9_]+)":\s*\{\s*$', lines[i])
            if mo:
                key = mo.group(1)
                for j in range(i + 1, min(i + 40, len(lines))):
                    nmo = re.search(r'"name":\s*"([^"]+)"', lines[j])
                    if nmo:
                        m[key + ".png"] = nmo.group(1)
                        break
            i += 1

    basenames = [os.path.basename(p) for p in pngs]
    open(os.path.join(DST, "全部文件名_一行.txt"), "w", encoding="utf-8").write(" ".join(basenames))
    open(os.path.join(DST, "全部文件名_分行.txt"), "w", encoding="utf-8").write("\n".join(basenames) + "\n")

    lines_tab = []
    for bn in basenames:
        nm = m.get(bn, "")
        if nm:
            lines_tab.append(f"{bn}\t{nm}")
        else:
            lines_tab.append(f"{bn}\t（未在 default_cards/phase_laws 匹配，多为 shape 聚合图）")
    open(os.path.join(DST, "卡面文件名与显示名.txt"), "w", encoding="utf-8").write("\n".join(lines_tab) + "\n")

    readme = f"""加工目录说明

1. 本文件夹内是从 assets/card_icons/ 根目录复制的全部 .png 卡面（共 {len(pngs)} 张），可在此批量改图。
2. 改完后请将同名文件覆盖回上一级目录：assets/card_icons/<同名>.png
3. 不要改文件名（与 card_id / 聚合图 key 一致），否则游戏内找不到图。
4. 汇总文件：
   - 全部文件名_一行.txt   所有文件名空格分隔
   - 全部文件名_分行.txt   每行一个文件名
   - 卡面文件名与显示名.txt  文件名与显示名对照（脚本解析；未匹配的为聚合占位图）
"""
    open(os.path.join(DST, "README.txt"), "w", encoding="utf-8").write(readme)
    print("OK", len(pngs), "png ->", DST)


if __name__ == "__main__":
    main()
