# -*- coding: utf-8 -*-
"""审查页生成器：docs/卡图API重生成_20261014/review.html

行结构 = 编号/名称/ID/时代 + 现役敌图 + 新图 raw（品红底1024）+ 新图 cut（透明底512）。
数据 = ledger.json（生成台账）+ _tmp_api_card_regen_20261014.py 的 UNITS 清单。
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _tmp_api_card_regen_20261014 import UNITS, LEDGER, OUT  # noqa: E402

HTML = """<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="utf-8">
<title>卡图 API 重生成 · 审查（2026-10-14）</title>
<style>
:root{--bg:#101418;--panel:#1a2027;--panel2:#232b34;--txt:#dbe4ee;--dim:#8b98a8;
  --line:#2d3742;--ok:#3fb96f;--bad:#e05c5c;--accent:#4aa8ff;--zoom:200px}
body.light{--bg:#eef1f5;--panel:#fff;--panel2:#f2f5f9;--txt:#1d2733;--dim:#5d6b7c;--line:#d5dce5}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--txt);
  font:13px/1.5 "Microsoft YaHei",system-ui,sans-serif}
header{position:sticky;top:0;z-index:20;background:var(--panel);
  border-bottom:1px solid var(--line);padding:10px 16px}
h1{font-size:17px;margin:0 0 6px}
h1 small{color:var(--dim);font-weight:normal;margin-left:8px;font-size:12px}
.bar{display:flex;flex-wrap:wrap;gap:8px;align-items:center}
.bar label{color:var(--dim)}
select,button{background:var(--panel2);color:var(--txt);border:1px solid var(--line);
  border-radius:6px;padding:4px 8px;font-size:12px}
button{cursor:pointer}button:hover{border-color:var(--accent)}
main{padding:12px 16px 80px}
.row{display:flex;gap:14px;align-items:stretch;background:var(--panel);
  border:1px solid var(--line);border-radius:10px;padding:12px;margin-bottom:12px}
.row .meta{flex:0 0 240px}
.nm{font-weight:bold;font-size:15px}
.iid{color:var(--dim);font-size:11px;font-family:Consolas,monospace;word-break:break-all;margin-top:2px}
.tags{margin-top:6px;display:flex;flex-wrap:wrap;gap:4px}
.tag{font-size:11px;border-radius:4px;padding:0 6px;background:var(--panel2);
  border:1px solid var(--line);color:var(--dim)}
.tag.err{color:var(--bad);border-color:var(--bad)}
.tag.ok{color:var(--ok);border-color:color-mix(in srgb,var(--ok) 45%,transparent)}
.subj{margin-top:8px;font-size:11px;color:var(--dim);max-height:5.2em;overflow:auto;
  border-top:1px dashed var(--line);padding-top:6px}
.cols{flex:1;display:flex;gap:10px;flex-wrap:wrap;align-items:flex-start}
.cell{display:flex;flex-direction:column;gap:4px}
.cell .cap{font-size:11px;color:var(--dim)}
.imgbox{width:var(--zoom);height:var(--zoom);border-radius:8px;overflow:hidden;
  border:1px solid var(--line);position:relative}
.imgbox img{width:100%;height:100%;object-fit:contain}
.imgbox.raw{background:#3c0f3c}
body.light .imgbox.raw{background:#c9a0c9}
.imgbox.chk{background:repeating-conic-gradient(var(--panel2) 0 25%, transparent 0 50%)
  0 0/22px 22px}
.imgbox.darkbg{background:#0b0e12}
.imgbox.lightbg{background:#f4f6f9}
.imgbox.none{display:flex;align-items:center;justify-content:center;color:var(--bad);font-size:11px}
.pinfo{font-size:11px;color:var(--dim);font-family:Consolas,monospace}
footer{position:fixed;bottom:0;left:0;right:0;background:var(--panel);
  border-top:1px solid var(--line);padding:6px 16px;font-size:12px;color:var(--dim);z-index:20}
</style>
</head>
<body>
<header>
  <h1>卡图 API 重生成审查 <small id="gen"></small></h1>
  <div class="bar">
    <label>尺寸 <select id="selZoom">
      <option value="160">160</option><option value="200" selected>200</option>
      <option value="280">280</option><option value="380">380</option></select></label>
    <label>透明底 <select id="selBg">
      <option value="chk" selected>棋盘格</option><option value="darkbg">深色</option>
      <option value="lightbg">浅色</option></select></label>
    <label>底色 <select id="selTheme">
      <option value="dark" selected>深色</option><option value="light">浅色</option></select></label>
    <span style="color:var(--dim)">左=现役敌图 · 中=新图 raw(品红1024) · 右=键控后(透明512)</span>
  </div>
</header>
<main id="app"></main>
<footer>t2i 语义重出（不锁现役结构）· 骨架冻结+单变量 SUBJECT · 品红底键控对齐
magenta_cut_key_ref 口径 · 台账 ledger.json · 产物仅暂存，目检拍板后才部署</footer>
<script>
const DATA = __DATA__;
const app = document.getElementById('app');
function esc(s){return (s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;')}
for (const r of DATA.rows) {
  const row = document.createElement('div'); row.className = 'row';
  const cutBg = document.getElementById('selBg').value;
  row.innerHTML = `
    <div class="meta">
      <div class="nm">${esc(r.no + '·' + r.name)}</div>
      <div class="iid">${esc(r.uid)}</div>
      <div class="tags">
        <span class="tag">${esc(r.era)}</span>
        <span class="tag">${r.secs != null ? r.secs + 's' : ''}</span>
        ${r.raw ? '<span class="tag ok">raw OK</span>' : '<span class="tag err">生成失败</span>'}
        ${r.cut ? `<span class="tag ok">cut ${r.content_frac}</span>` : ''}
        ${r.cut_note ? `<span class="tag err">${esc(r.cut_note)}</span>` : ''}
      </div>
      <div class="subj">${esc(r.subject)}</div>
    </div>
    <div class="cols">
      <div class="cell"><div class="cap">现役敌图（不满意的结构参照）</div>
        <div class="imgbox chk"><img src="${r.icon}" loading="lazy"></div></div>
      <div class="cell"><div class="cap">新图 raw · 品红底 ${r.raw ? '' : '缺失'}</div>
        ${r.raw ? `<div class="imgbox raw"><img src="${r.raw}" loading="lazy"></div>`
                : '<div class="imgbox none">no image</div>'}</div>
      <div class="cell"><div class="cap">键控后 · 透明底 512</div>
        ${r.cut ? `<div class="imgbox ${cutBg}"><img src="${r.cut}" loading="lazy"></div>`
                : '<div class="imgbox none">no image</div>'}</div>
    </div>`;
  app.appendChild(row);
}
document.getElementById('gen').textContent = '生成 ' + DATA.generated;
document.getElementById('selZoom').onchange = e =>
  document.documentElement.style.setProperty('--zoom', e.target.value + 'px');
document.getElementById('selTheme').onchange = e =>
  document.body.classList.toggle('light', e.target.value === 'light');
document.getElementById('selBg').onchange = e => {
  for (const b of document.querySelectorAll('.imgbox.chk,.imgbox.darkbg,.imgbox.lightbg'))
    if (b.querySelector('img') && b.parentElement.textContent.includes('键控'))
      b.className = 'imgbox ' + e.target.value;
};
</script>
</body>
</html>
"""


def build():
    import datetime
    ledger = json.load(open(LEDGER, encoding="utf-8"))
    by_no = {r.get("no"): r for r in ledger}
    rows = []
    for u in UNITS:
        rec = by_no.get(u["no"], {})
        rows.append(dict(
            no=u["no"], name=u["name"], uid=u["uid"], era=u["era"],
            subject=u["subject"],
            icon=os.path.relpath(os.path.join(ROOT_PATH, u["icon"]),
                                 OUT).replace("\\", "/"),
            raw=rec.get("raw") and os.path.relpath(
                os.path.join(ROOT_PATH, rec["raw"]), OUT).replace("\\", "/"),
            cut=rec.get("cut") and os.path.relpath(
                os.path.join(ROOT_PATH, rec["cut"]), OUT).replace("\\", "/"),
            secs=rec.get("secs"), content_frac=rec.get("content_frac"),
            cut_note=rec.get("cut_note")))
    html = HTML.replace("__DATA__", json.dumps(
        dict(generated=datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
             rows=rows), ensure_ascii=False))
    path = os.path.join(OUT, "review.html")
    open(path, "w", encoding="utf-8").write(html)
    print("page ->", path)


ROOT_PATH = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

if __name__ == "__main__":
    build()
