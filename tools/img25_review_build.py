# -*- coding: utf-8 -*-
"""img25 审阅页生成器（09-29）：扫 worklist + img25_staging，产出 tools/img25_review.html。
每单位一行：卡图 | 现役攻击条带(播放) | 候选条带(播放) | 候选 raw | 裁决下拉+备注。
裁决存 localStorage + 导出 JSON。重跑本脚本即刷新名单（保留裁决，按 key 存）。
用法：python tools/img25_review_build.py"""
import glob
import html
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_HTML = os.path.join(ROOT, "tools", "img25_review.html")

wl = json.load(open(os.path.join(ROOT, ".godot", "unit_review", "img25_worklist.json"), encoding="utf-8"))
icons = json.load(open(os.path.join(ROOT, ".godot", "anim_icon_map.json"), encoding="utf-8"))
STG = ".godot/unit_review/img25_staging"


def rel(p):
    return "../" + p.replace("\\", "/")


rows = []
for key in sorted(wl):
    meta = wl[key]
    en = meta.get("energy")
    wpn = meta.get("weapon", "")
    d = os.path.join(ROOT, "assets", "effects", "unit_anims", key)
    live = os.path.join(d, "sheet_attack.png") if os.path.exists(os.path.join(d, "sheet_attack.png")) else None
    live_w = 0
    if live:
        from PIL import Image
        live_w = Image.open(live).width
    icon = icons.get(key, {}).get("icon", "")
    icon = icon.replace("res://", "assets/") if icon else ""
    cand = "%s/%s_attackC.png" % (STG, key) if os.path.exists(os.path.join(ROOT, STG, "%s_attackC.png" % key)) else ""
    raw = "%s/%s_attackC_raw.png" % (STG, key) if os.path.exists(os.path.join(ROOT, STG, "%s_attackC_raw.png" % key)) else ""
    prev = "%s/%s_attackABC_preview.png" % (STG, key) if os.path.exists(os.path.join(ROOT, STG, "%s_attackABC_preview.png" % key)) else ""

    def strip_img(p, w_px, cls):
        if not p:
            return '<div class="miss">缺</div>'
        return ('<div class="anim %s" data-w="%d" style="background-image:url(\'%s\')"></div>' % (cls, w_px, rel(p)))

    live_s = strip_img(live, live_w, "live") if live else '<div class="miss">缺</div>'
    cand_s = ('<div class="anim cand" data-w="1536" style="background-image:url(\'%s\')"></div>' % rel(cand)) if cand else '<div class="miss">未出</div>'
    raw_i = ('<a href="%s" target="_blank"><img class="thumb" src="%s"></a>' % (rel(raw), rel(raw))) if raw else '<div class="miss">—</div>'
    prev_i = ('<a href="%s" target="_blank"><img class="thumb" src="%s"></a>' % (rel(prev), rel(prev))) if prev else '<div class="miss">—</div>'
    icon_i = ('<img class="card" src="%s">' % rel(icon)) if icon else '<div class="miss">无卡图</div>'
    rows.append(
        '<div class="row" data-key="%s">'
        '<div class="meta"><div class="k">%s</div><div class="sub">%s%s</div></div>'
        '<div class="cell cardc">%s</div>'
        '<div class="cell strip">%s<div class="cap">现役</div></div>'
        '<div class="cell strip">%s<div class="cap">候选(6帧)</div></div>'
        '<div class="cell">%s<div class="cap">raw</div></div>'
        '<div class="cell">%s<div class="cap">对比图</div></div>'
        '<div class="cell verdict"><select>'
        '<option value="">待定</option><option value="adopt">采纳</option>'
        '<option value="reject">否决</option><option value="redo">重做</option></select>'
        '<textarea placeholder="备注"></textarea></div>'
        '</div>' % (html.escape(key), html.escape(key), ("能量" if en else "动能"), " · " + html.escape(wpn),
                    icon_i, live_s, cand_s, raw_i, prev_i))

page = '''<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>img25 生图候选审查</title>
<style>
body{font-family:"Microsoft YaHei",sans-serif;background:#141419;color:#ddd;margin:0;padding:10px}
.bar{position:sticky;top:0;z-index:9;background:#1b1b24;padding:8px 12px;border-bottom:2px solid #35455f;display:flex;gap:10px;align-items:center;flex-wrap:wrap}
.bar h1{font-size:16px;color:#6cf;margin:0}
button{background:#27405e;border:1px solid #4af;color:#cde;border-radius:4px;padding:5px 10px;cursor:pointer}
button:hover{background:#33547c}
select{background:#0e0e14;border:1px solid #345;color:#eee;border-radius:4px;padding:3px}
.note{font-size:12px;color:#89a}
.row{display:flex;gap:8px;padding:8px;border-bottom:1px solid #26262e;align-items:flex-start;background:#191920}
.row:hover{background:#1d1d27}
.row[data-v="adopt"]{background:#12241a}.row[data-v="reject"]{background:#2a1214}.row[data-v="redo"]{background:#2a2210}
.meta{width:150px;min-width:150px}.meta .k{font-weight:bold;color:#8df;font-size:13px;word-break:break-all}
.meta .sub{font-size:11px;color:#789;margin-top:3px}
.cell{width:150px;min-width:150px;text-align:center}
.cell.cardc{width:92px;min-width:92px}
.cell img{max-width:100%;max-height:130px;object-fit:contain;background:#20202a;border:1px solid #333;display:block;margin:0 auto}
.cell img.card{max-height:110px}
a.thumb img{cursor:zoom-in}
.anim{width:150px;height:100px;background-repeat:no-repeat;background-size:auto 256px;background-position:0 50%;background-color:#20202a;border:1px solid #333;margin:0 auto}
.anim.live{width:180px}.anim.cand{width:180px}
.cell .cap{font-size:10px;color:#678;margin-top:2px}
.miss{color:#655;background:#20202a;border:1px dashed #433;padding:38px 4px;font-size:12px}
.verdict select{width:110px;display:block;margin:0 auto 4px}
.verdict textarea{width:140px;height:44px;background:#0e0e14;border:1px solid #345;color:#ccc;font-size:11px}
</style></head><body>
<div class="bar"><h1>img25 生图候选审查</h1>
<span class="note" id="cnt"></span>
<button onclick="exportV()">导出裁决 JSON</button>
<button onclick="if(confirm('清空全部裁决?')){localStorage.removeItem('img25_verdicts');location.reload()}">清空裁决</button>
<span class="note">裁决自动保存（按单位名）；点 raw/对比图看原图</span></div>
<div id="list">ROWS</div>
<script>
const strips=document.querySelectorAll('.anim');
strips.forEach(el=>{const w=+el.dataset.w; if(!w) return; const fw=256; const n=Math.round(w/fw);
 if(n<2) return; let i=0; el.style.backgroundSize=(w)+'px 256px';
 setInterval(()=>{i=(i+1)%n; el.style.backgroundPositionX=(-i*fw*(el.offsetWidth/fw)*(fw/ (el.offsetHeight? 256:256)))+'px';},140);
 // 简化：窗口宽 150/180 显示 256px 帧需要缩放：用 zoom 思路——直接缩放窗口等比
});
// 更稳的播放：等比缩放窗口
strips.forEach(el=>{const w=+el.dataset.w; if(!w) return; const n=Math.round(w/256);
 const winW=el.classList.contains('live')||el.classList.contains('cand')?180:150;
 const scale=winW/256; el.style.width=winW+'px'; el.style.height=Math.round(256*0.55)+'px';
 el.style.backgroundSize=(w*scale)+'px auto';
 let i=0; if(n>1) setInterval(()=>{i=(i+1)%n; el.style.backgroundPositionX=(-i*256*scale)+'px';},150);});
const rows=[...document.querySelectorAll('.row')];
const saved=JSON.parse(localStorage.getItem('img25_verdicts')||'{}');
rows.forEach(r=>{const k=r.dataset.key; const s=saved[k]||{};
 const sel=r.querySelector('select'), ta=r.querySelector('textarea');
 if(s.v) {sel.value=s.v; r.dataset.v=s.v;}
 if(s.n) ta.value=s.n;
 const save=()=>{saved[k]={v:sel.value,n:ta.value}; localStorage.setItem('img25_verdicts',JSON.stringify(saved)); r.dataset.v=sel.value;};
 sel.onchange=save; ta.onchange=save; ta.onblur=save;});
function cnt(){const c={adopt:0,reject:0,redo:0,blank:0}; rows.forEach(r=>{const v=r.dataset.v; if(v)c[v]++;else c.blank++;});
 document.getElementById('cnt').textContent=`共 ${rows.length} 单位 · 采纳 ${c.adopt} · 否决 ${c.reject} · 重做 ${c.redo} · 待定 ${c.blank}`;}
cnt(); document.querySelectorAll('.row select').forEach(s=>s.addEventListener('change',cnt));
function exportV(){const b=new Blob([JSON.stringify(saved,null,1)],{type:'application/json'});
 const a=document.createElement('a'); a.href=URL.createObjectURL(b); a.download='img25_verdicts.json'; a.click();}
</script></body></html>'''

page = page.replace("ROWS", "\n".join(rows))
open(OUT_HTML, "w", encoding="utf-8").write(page)
print("REVIEW PAGE ->", os.path.relpath(OUT_HTML, ROOT), "units:", len(rows))
