# -*- coding: utf-8 -*-
"""总审查页（批1+批2 全部 36 单位）：现役卡图 vs 新 raw vs 键控 cut vs 开火4格。
数据源 = 两个批脚本的 UNITS 清单 + raw/ 目录扫描（磁盘为真）。
产物：docs/卡图API重生成_20261014/review_all.html
"""
import glob
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _tmp_api_card_regen_20261014 import UNITS, OUT  # noqa: E402
import _tmp_api_card_regen_batch2 as B2  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

HTML = """<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="utf-8">
<title>卡图+攻击图 总审查（批1+批2 · 36 单位）</title>
<style>
:root{--bg:#101418;--panel:#1a2027;--panel2:#232b34;--txt:#dbe4ee;--dim:#8b98a8;
  --line:#2d3742;--ok:#3fb96f;--bad:#e05c5c;--accent:#4aa8ff;--zoom:190px}
body.light{--bg:#eef1f5;--panel:#fff;--panel2:#f2f5f9;--txt:#1d2733;--dim:#5d6b7c;--line:#d5dce5}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--txt);font:13px/1.5 "Microsoft YaHei",system-ui,sans-serif}
header{position:sticky;top:0;z-index:20;background:var(--panel);border-bottom:1px solid var(--line);padding:10px 16px}
h1{font-size:17px;margin:0 0 6px}
.bar{display:flex;flex-wrap:wrap;gap:10px;align-items:center;margin-top:4px}
.bar label{color:var(--dim)}
select{background:var(--panel2);color:var(--txt);border:1px solid var(--line);border-radius:6px;padding:4px 8px;font-size:12px}
main{padding:12px 16px 80px}
.row{display:flex;gap:12px;align-items:stretch;background:var(--panel);border:1px solid var(--line);
  border-radius:10px;padding:12px;margin-bottom:10px}
.row .meta{flex:0 0 210px}
.nm{font-weight:bold;font-size:14px}
.iid{color:var(--dim);font-size:11px;font-family:Consolas,monospace;word-break:break-all;margin-top:2px}
.tag{display:inline-block;font-size:11px;border-radius:4px;padding:0 6px;background:var(--panel2);
  border:1px solid var(--line);color:var(--dim);margin:4px 4px 0 0}
.tag.ok{color:var(--ok);border-color:color-mix(in srgb,var(--ok) 45%,transparent)}
.tag.err{color:var(--bad);border-color:var(--bad)}
.cols{flex:1;display:flex;gap:10px;flex-wrap:wrap;align-items:flex-start}
.cell{display:flex;flex-direction:column;gap:4px}
.cell .cap{font-size:11px;color:var(--dim)}
.imgbox{width:var(--zoom);height:var(--zoom);border-radius:8px;overflow:hidden;border:1px solid var(--line)}
.imgbox img{width:100%;height:100%;object-fit:contain}
.imgbox.raw{background:#3c0f3c}
body.light .imgbox.raw{background:#c9a0c9}
.imgbox.chk{background:repeating-conic-gradient(var(--panel2) 0 25%, transparent 0 50%) 0 0/22px 22px}
.imgbox.fire{background:#3c0f3c;width:auto;height:var(--zoom);flex:0 0 var(--zoom)}
.imgbox.none{display:flex;align-items:center;justify-content:center;color:var(--bad);font-size:11px;
  background:var(--panel2)}
footer{position:fixed;bottom:0;left:0;right:0;background:var(--panel);border-top:1px solid var(--line);
  padding:6px 16px;font-size:12px;color:var(--dim);z-index:20}
</style>
</head>
<body>
<header>
  <h1>卡图 + 攻击图 总审查 <small id="gen"></small></h1>
  <div class="bar">
    <label>尺寸 <select id="selZoom"><option>150</option><option value="190" selected>190</option>
      <option>260</option><option>360</option></select></label>
    <label>主题 <select id="selTheme"><option value="dark" selected>深色</option>
      <option value="light">浅色</option></select></label>
    <label>只看 <select id="selFilter"><option value="">全部</option>
      <option value="nofire">缺攻击图</option><option value="hasfire">有攻击图</option></select></label>
    <span style="color:var(--dim)">列：现役卡图 · 新raw(品红) · 键控cut · 开火4格</span>
  </div>
</header>
<main id="app"></main>
<footer>删除即弃选：raw/ cut/ poses/ 同名文件。全部暂存，选定后才部署 assets/。</footer>
<script>
const DATA = __DATA__;
const app = document.getElementById('app');
function esc(s){return (s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;')}
function render(){
  app.innerHTML='';
  const filt = document.getElementById('selFilter').value;
  for (const r of DATA.rows) {
    if (filt==='nofire' && r.fire) continue;
    if (filt==='hasfire' && !r.fire) continue;
    const row=document.createElement('div'); row.className='row';
    row.innerHTML = `
      <div class="meta">
        <div class="nm">${esc(r.no+'·'+r.name)}</div>
        <div class="iid">${esc(r.uid)}</div>
        <span class="tag">${esc(r.era||'')}</span>
        ${r.raw?'<span class="tag ok">raw</span>':'<span class="tag err">无raw</span>'}
        ${r.cut?'<span class="tag ok">cut</span>':''}
        ${r.fire?'<span class="tag ok">开火4格</span>':'<span class="tag err">攻击图未落地</span>'}
      </div>
      <div class="cols">
        <div class="cell"><div class="cap">现役卡图</div>
          <div class="imgbox chk"><img src="${r.icon||''}" loading="lazy"
            onerror="this.parentElement.className='imgbox none';this.remove()"></div></div>
        <div class="cell"><div class="cap">新 raw</div>
          ${r.raw?`<div class="imgbox raw"><img src="${r.raw}" loading="lazy"></div>`
                 :'<div class="imgbox none">-</div>'}</div>
        <div class="cell"><div class="cap">键控 cut</div>
          ${r.cut?`<div class="imgbox chk"><img src="${r.cut}" loading="lazy"></div>`
                 :'<div class="imgbox none">-</div>'}</div>
        <div class="cell"><div class="cap">开火4格（左上→右上→左下→右下）</div>
          ${r.fire?`<div class="imgbox fire"><img src="${r.fire}" loading="lazy"></div>`
                  :'<div class="imgbox none">生成中…</div>'}</div>
      </div>`;
    app.appendChild(row);
  }
}
document.getElementById('gen').textContent = DATA.generated;
document.getElementById('selZoom').onchange = e =>
  document.documentElement.style.setProperty('--zoom', e.target.value+'px');
document.getElementById('selTheme').onchange = e =>
  document.body.classList.toggle('light', e.target.value==='light');
document.getElementById('selFilter').onchange = render;
render();
</script>
</body>
</html>
"""


def rel(p):
    return os.path.relpath(p, OUT).replace("\\", "/") if p else None


def build():
    import datetime
    units = {u["no"]: u for u in UNITS}
    for u in B2.UNITS2:
        units.setdefault(u["no"], u)
    fires = {os.path.basename(f).split("·")[0]: rel(f)
             for f in glob.glob(os.path.join(ROOT, "docs/卡图API重生成_20261014/raw/*_开火4格.png"))}
    rows = []
    for no, u in sorted(units.items()):
        raw = os.path.join(RAW_DIR, "%s·%s.png" % (no, u["name"]))
        cut = os.path.join(CUT_DIR, "%s·%s.png" % (no, u["name"]))
        icon = os.path.join(ROOT, u["icon"]) if u.get("icon") else None
        rows.append(dict(
            no=no, name=u["name"], uid=u["uid"], era=u.get("era", ""),
            icon=rel(icon) if icon and os.path.exists(icon) else None,
            raw=rel(raw) if os.path.exists(raw) else None,
            cut=rel(cut) if os.path.exists(cut) else None,
            fire=fires.get(no)))
    html = HTML.replace("__DATA__", json.dumps(
        dict(generated=datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
             rows=rows), ensure_ascii=False))
    path = os.path.join(OUT, "review_all.html")
    open(path, "w", encoding="utf-8").write(html)
    print("page ->", path, "| rows:", len(rows), "| with fire:", len(fires))


RAW_DIR = os.path.join(OUT, "raw")
CUT_DIR = os.path.join(OUT, "cut")

if __name__ == "__main__":
    build()
