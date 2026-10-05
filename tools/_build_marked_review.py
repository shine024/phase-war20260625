# -*- coding: utf-8 -*-
"""标记复查页生成器（2026-10-05）：只显示用户标记为问题（r=yes）的行。
数据源=已重建的全量总审页 card_anim_review.html 内嵌 DATA（MK11 修复后探针态），
标注源=card_anim_review_marks (1).json 的 r=yes 键；其余行一律不进新页。
输出 tools/card_anim_review_marked.html；模板复用 _card_anim_review_template.html。
用法: python tools/_build_marked_review.py
"""
import io
import json
import os
import re
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.join(ROOT, "tools")
SRC_HTML = os.path.join(TOOLS, "card_anim_review.html")
MARKS_FILE = os.path.join(TOOLS, "card_anim_review_marks (1).json")
OUT = os.path.join(TOOLS, "card_anim_review_marked.html")


def main():
    data = json.loads(re.search(
        r"const DATA = (\{.*?\});\n",
        open(SRC_HTML, encoding="utf-8").read(), re.S).group(1))
    marks = json.load(open(MARKS_FILE, encoding="utf-8")).get("marks", {})
    want = {k: m for k, m in marks.items() if m.get("r") == "yes"}

    kept, seen = [], set()
    for sec in data.get("sections", []):
        rows = [r for r in sec.get("rows", [])
                if (sec["key"] + "|" + r["id"]) in want]
        if rows:
            kept.append((sec["key"], len(rows)))
            sec["rows"] = rows
            seen.update(sec["key"] + "|" + r["id"] for r in rows)
    data["sections"] = [s for s in data["sections"] if s.get("rows")]
    data["marks_seed"] = want          # 只嵌 r=yes 标注，卡上直接显示用户备注
    data["only_marked"] = True
    data["total"] = sum(n for _, n in kept)

    tpl = open(os.path.join(TOOLS, "_card_anim_review_template.html"),
               encoding="utf-8").read()
    payload = json.dumps(data, ensure_ascii=True, separators=(",", ":")).replace("</", "<\\/")
    html = tpl.replace("__DATA__", payload)
    banner = ('<div style="position:sticky;top:0;z-index:99;background:#7a1f1f;color:#fff;'
              'padding:6px 14px;font:600 14px/1.4 system-ui">标记复查页 — 只列你标记过问题的 '
              '%d 项（%s）。每卡下方备注为标记原文；标签为修复后探针实测，供复核。</div>' % (
                  data["total"], " + ".join("%s %d" % (k, n) for k, n in kept)))
    html = html.replace("<body>", "<body>" + banner, 1)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(html)

    missing = sorted(set(want) - seen)
    print("BUILD_OK total=%d (%s) -> %s (%.1f KB)" % (
        data["total"], " ".join("%s=%d" % (k, n) for k, n in kept),
        os.path.relpath(OUT, ROOT), os.path.getsize(OUT) / 1024))
    if missing:
        print("  无对应行的标记键 %d 个: %s" % (len(missing), ";".join(missing)))


if __name__ == "__main__":
    main()
