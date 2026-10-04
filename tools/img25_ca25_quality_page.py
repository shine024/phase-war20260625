# -*- coding: utf-8 -*-
"""codeanim 早批 25 家质量检查页：卡图(参考) vs 现部署攻击 f0/f1/GIF vs idle。
用途=拍板是否升级卡图直出。名单=实扫（与进度页同口径：EPOCH+逐像素匹配-CARD21）。"""
import os, io, sys, re, json, time
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
import numpy as np
from PIL import Image

ROOT = r"D:\godotplay\godot fair duel\phase-war"
ANIM = os.path.join(ROOT, "assets", "effects", "unit_anims")
CODE = os.path.join(ROOT, ".godot", "unit_review", "codeanim")
PROG_WEB = os.path.join(ROOT, "docs", "img25_progress_web")
OUT_HTML = os.path.join(ROOT, ".godot", "unit_review", "img25_早批25_质量检查.html")
EPOCH = time.mktime(time.strptime("2026-09-29", "%Y-%m-%d"))

CARD21 = set(json.load(open(os.path.join(
    ROOT, ".godot", "unit_review", "codeanim_configs", "_configs_card21.json"), encoding="utf-8")).keys())

txt = open(os.path.join(ROOT, "docs", "img25_重做清单_20260929.md"), encoding="utf-8").read()
rows = re.findall(r"^\|\s*\d+\s*\|\s*([a-z0-9_]+)\s*\|", txt, re.M)


def is_cardbatch(key):
    src = os.path.join(CODE, key + "_codeanim_sheet.png")
    dst = os.path.join(ANIM, key, "sheet_attack.png")
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


WEB = os.path.join(ROOT, ".godot", "unit_review", "img25_staging", "_relight2", "web")
os.makedirs(WEB, exist_ok=True)
keys = []
for key in rows:
    sa = os.path.join(ANIM, key, "sheet_attack.png")
    if os.path.exists(sa) and os.path.getmtime(sa) >= EPOCH and is_cardbatch(key) and key not in CARD21:
        keys.append(key)
print("早批 %d 家: %s" % (len(keys), ",".join(keys)))


def cell_jpg(sheet, cx, out, size=256):
    im = Image.open(sheet).convert("RGBA")
    w = min(256, im.width)
    c = im.crop((cx, 0, cx + w, min(im.height, 256)))
    b = Image.new("RGBA", c.size, (240, 238, 230, 255))
    b.alpha_composite(c)
    b.convert("RGB").save(out, quality=88)


for key in keys:
    d = os.path.join(ANIM, key)
    cell_jpg(os.path.join(d, "sheet_attack.png"), 0, os.path.join(WEB, key + "_qf0.jpg"))
    cell_jpg(os.path.join(d, "sheet_attack.png"), 256, os.path.join(WEB, key + "_qf1.jpg"))
    idl = os.path.join(d, "sheet_idle.png")
    if os.path.exists(idl):
        cell_jpg(idl, 0, os.path.join(WEB, key + "_qidle.jpg"))
    print("web", key, "ok", flush=True)

CARD_REL = "../../docs/img25_progress_web"  # 页面在 .godot/unit_review/ 下，回两级到项目根

BODY = []
for key in keys:
    gif = os.path.join(CODE, key + "_codeanim_anim.gif")
    gif_html = ('<img class=gif src="codeanim/{k}_codeanim_anim.gif">'.format(k=key) if os.path.exists(gif)
                else '<img class=gif src="img25_staging/_relight2/web/{k}_qf1.jpg">'
                     '<div style="font-size:11px;color:#a86">无 GIF，显示 f1</div>'.format(k=key))
    BODY.append("""
<tr><td class=kk>{k}</td>
<td><img src="{card}/{k}_card.jpg"></td>
<td><img src="img25_staging/_relight2/web/{k}_qidle.jpg"></td>
<td><img src="img25_staging/_relight2/web/{k}_qf0.jpg"></td>
<td><img src="img25_staging/_relight2/web/{k}_qf1.jpg"></td>
<td class=gif>{gif}</td>
<td class=nt><textarea id="nt_{k}" placeholder="要升级卡图直出 / 可以不动 / 具体问题…"></textarea>
<div class=btns><button onclick="mark('{k}','可以')">可以</button><button onclick="mark('{k}','要升级')">要升级</button><span id="st_{k}"></span></div></td></tr>""".format(k=key, card=CARD_REL, gif=gif_html))

HTML = """<!DOCTYPE html><html><head><meta charset="utf-8"><title>img25 codeanim 早批 25 家质量检查</title>
<style>
body{font:14px/1.5 "Microsoft YaHei",sans-serif;background:#1b1e24;color:#ddd;margin:0;padding:14px}
h1{font-size:18px;color:#fff} h1 small{color:#8ab4ff;font-size:13px}
.note{background:#262b33;border-left:4px solid #e8a;padding:8px 12px;margin:8px 0;font-size:13px}
table{border-collapse:collapse;width:100%;table-layout:fixed}
th{position:sticky;top:0;background:#22262e;color:#9fc3ff;padding:6px;border:1px solid #3a4150;font-size:13px;z-index:2}
td{border:1px solid #3a4150;padding:5px;vertical-align:top;background:#20242b}
td img{width:170px;image-rendering:auto;display:block;background:#111}
td.gif img{width:200px}
.kk{font-weight:bold;color:#ffd479;width:100px;font-size:13px}
.nt{width:230px}
textarea{width:100%;height:64px;background:#161a20;color:#eee;border:1px solid #444;font:12px sans-serif;box-sizing:border-box}
.btns{margin-top:4px;display:flex;gap:6px;align-items:center}
button{background:#31405a;color:#cfe3ff;border:1px solid #4a5f80;padding:2px 10px;cursor:pointer;border-radius:3px}
.okchip{display:inline-block;padding:1px 8px;border-radius:8px;font-size:12px}
.ok{background:#1d3a1d;color:#8f8}.bad{background:#3a2a1d;color:#fa8}
.bar{position:sticky;bottom:0;background:#22262e;padding:8px;border-top:1px solid #3a4150;display:flex;gap:10px;z-index:2}
</style></head><body>
<h1>img25 codeanim 早批质量检查 <small>__N__ 家 · 拍板：升级卡图直出 or 可以不动</small></h1>
<div class=note><b>看什么</b>：①「卡图」与「攻击 f0」的<b>组成是否一致</b>（车型/兵种/持装/配色——你的标准：组成要一样）；
②攻击与 idle 朝向；③开火帧火光位置。这 25 家已在线，但锚定源=idle/中间产物<b>不是卡图</b>；判「要升级」的将进下一批卡图直出（管线现成）。</div>
<table><tr><th>单位</th><th>卡图（参考）</th><th>现役 idle f0</th><th>攻击 f0</th><th>攻击 f1 开火</th><th>GIF</th><th>判定</th></tr>
__ROWS__
</table>
<div class=bar>
<button onclick="allUp()">一键全标要升级</button>
<button onclick="exp()">导出 JSON（+复制）</button>
<span id=saved></span></div>
<script>
var KEY='img25_ca25_quality';
var KEYS=__KEYS__;
var S=JSON.parse(localStorage.getItem(KEY)||'{}');
function save(){localStorage.setItem(KEY,JSON.stringify(S));document.getElementById('saved').textContent='已保存 '+new Date().toLocaleTimeString();}
KEYS.forEach(function(k){
  var t=document.getElementById('nt_'+k);
  t.addEventListener('input',function(){S[k]=S[k]||{};S[k].note=t.value;clearTimeout(window._d);window._d=setTimeout(save,300);});
  if(S[k]&&S[k].note)t.value=S[k].note;
  chip(k);
});
function chip(k){var st=document.getElementById('st_'+k);var v=S[k]&&S[k].status;
  st.innerHTML=v?'<span class="okchip '+(v=='可以'?'ok':'bad')+'">'+v+'</span>':'';}
function mark(k,v){S[k]=S[k]||{};S[k].status=v;save();chip(k);}
function allUp(){KEYS.forEach(function(k){S[k]=S[k]||{};S[k].status='要升级';chip(k);});save();}
function exp(){var b=new Blob([JSON.stringify(S,null,1)],{type:'application/json'});
  var a=document.createElement('a');a.href=URL.createObjectURL(b);a.download='img25_ca25_quality.json';a.click();
  navigator.clipboard.writeText(JSON.stringify(S,null,1));}
</script></body></html>"""

html = HTML.replace("__N__", str(len(keys))).replace("__ROWS__", "".join(BODY)).replace("__KEYS__", json.dumps(keys))
open(OUT_HTML, "w", encoding="utf-8").write(html)
print("OK ->", OUT_HTML, "units:", len(keys))
