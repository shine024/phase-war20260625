# -*- coding: utf-8 -*-
"""img25 重做清单进度页：解析 docs/img25_重做清单_20260929.md 的 88 家，
对照 assets/effects/unit_anims 实况（attack 表/帧数/mtime）+ 卡图直出批比对，
生成 docs/img25_重做清单_进度.html。数据=每次运行实扫，非手工登记。"""
import os, io, sys, re, json, time, hashlib
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
import numpy as np
from PIL import Image

ROOT = r"D:\godotplay\godot fair duel\phase-war"
DOC = os.path.join(ROOT, "docs", "img25_重做清单_20260929.md")
ICONS = os.path.join(ROOT, "assets", "card_icons")
ANIM_ROOT = os.path.join(ROOT, "assets", "effects", "unit_anims")
CODE = os.path.join(ROOT, ".godot", "unit_review", "codeanim")
WEB = os.path.join(ROOT, "docs", "img25_progress_web")
OUT_HTML = os.path.join(ROOT, "docs", "img25_重做清单_进度.html")
EPOCH = time.mktime(time.strptime("2026-09-29", "%Y-%m-%d"))  # 重做启动日

txt = open(DOC, encoding="utf-8").read()
rows = re.findall(r"^\|\s*(\d+)\s*\|\s*([a-z0-9_]+)\s*\|\s*([^|]+)\|\s*([^|]+)\|\s*([a-zA-Z_/0-9.]+\.png)\s*\|",
                  txt, re.M)
assert len(rows) == 88, "解析到 %d 行, 应 88" % len(rows)

os.makedirs(WEB, exist_ok=True)


def md5(p):
    return hashlib.md5(open(p, "rb").read()).hexdigest()


def is_cardbatch(key):
    """部署件是否=当前 codeanim 卡图直出批（10格512重采样hstack）。"""
    src = os.path.join(CODE, key + "_codeanim_sheet.png")
    dst = os.path.join(ANIM_ROOT, key, "sheet_attack.png")
    if not (os.path.exists(src) and os.path.exists(dst)):
        return False
    sh = Image.open(src).convert("RGBA")
    strip = Image.new("RGBA", (2560, 256), (0, 0, 0, 0))
    for i in range(10):
        c = sh.crop(((i % 5) * 512, (i // 5) * 512, (i % 5) * 512 + 512, (i // 5) * 512 + 512))
        strip.paste(c.resize((256, 256), Image.LANCZOS), (i * 256, 0))
    a = np.asarray(strip).astype(int)
    b = np.asarray(Image.open(dst).convert("RGBA")).astype(int)
    return a.shape == b.shape and int(np.abs(a - b).max()) == 0


CARD21 = set(json.load(open(os.path.join(
    ROOT, ".godot", "unit_review", "codeanim_configs", "_configs_card21.json"), encoding="utf-8")).keys())

units = []
for no, key, chan, weap, card in rows:
    d = os.path.join(ANIM_ROOT, key)
    sa = os.path.join(d, "sheet_attack.png")
    aj = os.path.join(d, "anim.json")
    n = None
    if os.path.exists(aj):
        try:
            n = json.load(open(aj, encoding="utf-8")).get("counts", {}).get("attack")
        except Exception:
            pass
    mt = os.path.getmtime(sa) if os.path.exists(sa) else None
    if not os.path.exists(sa):
        st, cls = "无攻击表", "no"
    elif mt < EPOCH:
        st, cls = "旧件未重做", "old"
    elif is_cardbatch(key):
        st, cls = ("卡图直出批v9", "card") if key in CARD21 else ("codeanim早批", "ca")
    else:
        st, cls = "img25生图批", "done"
    units.append(dict(no=int(no), key=key, chan=chan.strip(), weap=weap.strip(), card=card,
                      n=n, mtime=mt, status=st, cls=cls))
    # 卡图缩略
    cj = os.path.join(WEB, key + "_card.jpg")
    if not os.path.exists(cj):
        p = os.path.join(ICONS, card)
        if os.path.exists(p):
            c = Image.open(p).convert("RGB"); c.thumbnail((140, 140))
            c.save(cj, quality=85)

done = [u for u in units if u["cls"] in ("card", "done", "ca")]
card_n = sum(1 for u in units if u["cls"] == "card")
ca_n = sum(1 for u in units if u["cls"] == "ca")
other_n = sum(1 for u in units if u["cls"] == "done")
old_n = sum(1 for u in units if u["cls"] == "old")
none_n = sum(1 for u in units if u["cls"] == "no")
# 悬置项：文档头部点名的豁免/待确认家不在 88 清单内 — 照录文字即可

secs = [("cold", "cold（16）"), ("drop", "drop（1）"), ("fut", "fut（10）"), ("guardian", "guardian（3）"),
        ("mod", "mod（17）"), ("platform", "platform（11）"), ("vis", "vis（1）"),
        ("ww1", "ww1（13）"), ("ww2", "ww2（16）")]
CH = {}
for pre, ttl in secs:
    CH[pre] = [u for u in units if u["key"].startswith(pre + "_") or (pre == "vis" and u["key"].startswith("vis_"))]

body = []
for pre, ttl in secs:
    ks = CH[pre]
    if not ks:
        continue
    dn = sum(1 for u in ks if u["cls"] in ("card", "done"))
    body.append("<h2>%s <small>%d/%d</small></h2><table><tr><th>#</th><th>状态</th><th>单位</th><th>卡图</th>"
                "<th>通道</th><th>attack帧</th><th>部署时间</th><th>来源</th></tr>" % (ttl, dn, len(ks)))
    for u in sorted(ks, key=lambda x: x["no"]):
        mtt = time.strftime("%m-%d %H:%M", time.localtime(u["mtime"])) if u["mtime"] else "—"
        body.append("<tr class=%s><td>%d</td><td><span class='chip %s'>%s</span></td><td class=kk>%s</td>"
                    "<td><img src='img25_progress_web/%s_card.jpg'></td><td>%s</td><td>%s</td><td>%s</td>"
                    "<td>%s</td></tr>"
                    % (u["cls"], u["no"], u["cls"], u["status"], u["key"], u["key"], u["chan"],
                       u["n"] if u["n"] else "—", mtt,
                       "codeanim 卡图直出（v9 换装批）" if u["cls"] == "card" else
                       ("codeanim 早批（源=锚定帧，非卡图）" if u["cls"] == "ca" else
                       ("img25 生图批部署" if u["cls"] == "done" else "—"))))
    body.append("</table>")

HTML = """<!DOCTYPE html><html><head><meta charset="utf-8"><title>img25 重做清单进度</title>
<style>
body{font:14px/1.5 "Microsoft YaHei",sans-serif;background:#1b1e24;color:#ddd;margin:0;padding:14px}
h1{font-size:19px;color:#fff} h1 small{color:#8ab4ff;font-size:13px}
h2{font-size:15px;color:#ffd479;margin:20px 0 6px} h2 small{color:#8f8;font-size:13px}
.sum{background:#262b33;border-left:4px solid #4a8cff;padding:10px 14px;margin:10px 0;font-size:14px}
.sum b{color:#fff}
table{border-collapse:collapse;width:100%;table-layout:fixed}
th{position:sticky;top:0;background:#22262e;color:#9fc3ff;padding:5px;border:1px solid #3a4150;font-size:12px;z-index:2}
td{border:1px solid #3a4150;padding:4px 6px;vertical-align:middle;background:#20242b;font-size:12px}
td img{width:64px;height:64px;object-fit:contain;background:#111;display:block}
tr.no td,.old td{background:#2a2024}
.kk{font-weight:bold;color:#ffd479}
.chip{display:inline-block;padding:1px 8px;border-radius:8px;font-size:11px;white-space:nowrap}
.chip.card{background:#1d3a1d;color:#8f8}.chip.done{background:#1d2a3a;color:#8cf}.chip.ca{background:#2a2a1d;color:#dda}
.chip.old{background:#3a2a1d;color:#fa8}.chip.no{background:#3a1d1d;color:#f88}
</style></head><body>
<h1>img25 重做清单进度 <small>docs/img25_重做清单_20260929.md · 实扫 assets __NOW__</small></h1>
<div class=sum>
共 <b>88</b> 家：✅ 已重做部署 <b>__DONE__</b>（卡图直出批 v9 __CARD__ ／ codeanim 早批 __CA__ ·源=锚定帧非卡图／ img25 生图批 __OTHER__）；
⚠ 旧件未重做 <b>__OLD__</b>；❌ 无攻击表 <b>__NONE__</b>。
注：codeanim 早批 25 家攻击动画已在线但锚定源为 idle/中间产物——如需严格执行「一切以卡图为源」，这 25 家是下一批卡图直出升级候选。
</div>
__BODY__
</body></html>"""

html = (HTML.replace("__NOW__", time.strftime("%Y-%m-%d %H:%M"))
            .replace("__DONE__", str(len(done))).replace("__CARD__", str(card_n))
            .replace("__CA__", str(ca_n)).replace("__OTHER__", str(other_n))
            .replace("__OLD__", str(old_n)).replace("__NONE__", str(none_n))
            .replace("__BODY__", "".join(body)))
open(OUT_HTML, "w", encoding="utf-8").write(html)
print("OK ->", OUT_HTML)
print("88 家：卡图直出v9 %d / codeanim早批 %d / img25生图批 %d / 旧件 %d / 无攻击表 %d"
      % (card_n, ca_n, other_n, old_n, none_n))
for u in units:
    if u["cls"] in ("old", "no"):
        print("  未完成:", u["key"], u["status"], "attack=%s" % u["n"])
