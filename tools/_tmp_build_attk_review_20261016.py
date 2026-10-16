# -*- coding: utf-8 -*-
"""攻击帧动画检查页(2026-10-16):36 卡开火4格 → 四拍循环动画网页。

功能:
- 每卡动画播放器:canvas 裁 2048² 卷四拍循环(ready→firing→recoil→settling),帧率可调
- 96px 战场预览(image-rendering pixelated)同步播放,验小尺寸可辨度
- 触边自动扫描:每拍四边 12px 带内亮像素(lum>150,烟/火特征)计数,阈值超标签红
- 单步/暂停/慢放;点击放大弹层手动逐拍检查抠图坏点(070 擦除区/110 合成区重点)
产物:docs/卡图API重生成_20261014/attk_review.html(图走相对路径 raw/)
用法:python -I -u tools/_tmp_build_attk_review_20261016.py
"""
import glob
import json
import os
import re

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "docs", "卡图API重生成_20261014", "raw")

EDGE = 12      # 图缘检测带宽 px
TH = 150       # 亮像素阈值(lum):品红底~76,烟白>150,火光>200
MIN_PIX = 30   # 单边亮像素计数报警下限


def scan_edges(path):
    """返回 {拍名: {边: 计数}},只保留超阈边。"""
    v = np.asarray(Image.open(path).convert("RGB")).astype(np.float64)
    lum = v @ np.array([0.299, 0.587, 0.114])
    out = {}
    for i, beat in enumerate(["TL", "TR", "BL", "BR"]):
        y0, x0 = (i // 2) * 1024, (i % 2) * 1024
        g = lum[y0:y0 + 1024, x0:x0 + 1024]
        bands = {"左": g[:, :EDGE], "右": g[:, -EDGE:], "上": g[:EDGE, :], "下": g[-EDGE:, :]}
        hits = {k: int((b > TH).sum()) for k, b in bands.items()}
        hits = {k: c for k, c in hits.items() if c >= MIN_PIX}
        if hits:
            out[beat] = hits
    return out


vols = sorted(glob.glob(os.path.join(RAW, "*_开火4格.png")))
cards = []
for p in vols:
    base = os.path.basename(p)[:-len("_开火4格.png")]
    m = re.match(r"^(\d+)·(.+)$", base)
    no, name = m.group(1), m.group(2)
    edges = scan_edges(p)
    cards.append({"no": no, "name": name, "file": "raw/" + os.path.basename(p), "edges": edges})

warn_n = sum(1 for c in cards if c["edges"])
print("卷 %d 张,触边警告 %d 张" % (len(cards), warn_n), flush=True)
for c in cards:
    if c["edges"]:
        print("  %s·%s %s" % (c["no"], c["name"], json.dumps(c["edges"], ensure_ascii=False)), flush=True)

HTML = """<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="utf-8">
<title>攻击帧动画检查(36 卡四拍循环)</title>
<style>
:root{--bg:#101418;--panel:#1a2027;--panel2:#232b34;--txt:#dbe4ee;--dim:#8b98a8;
  --line:#2d3742;--ok:#3fb96f;--warn:#e0aCmd;--bad:#e05c5c;--accent:#4aa8ff}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--txt);font:13px/1.5 "Microsoft YaHei",system-ui,sans-serif}
header{position:sticky;top:0;z-index:20;background:var(--panel);border-bottom:1px solid var(--line);
  padding:10px 16px}
h1{font-size:17px;margin:0 0 6px}
.bar{display:flex;flex-wrap:wrap;gap:14px;align-items:center;font-size:12px;color:var(--dim)}
.bar b{color:var(--txt)}
input[type=range]{width:120px;vertical-align:middle}
button{background:var(--panel2);color:var(--txt);border:1px solid var(--line);border-radius:6px;
  padding:3px 10px;font-size:12px;cursor:pointer}
button.on{border-color:var(--accent);color:var(--accent)}
main{padding:12px 16px 80px}
.row{display:flex;gap:14px;background:var(--panel);border:1px solid var(--line);border-radius:10px;
  padding:12px;margin-bottom:10px;align-items:flex-start}
.row.warnrow{border-color:color-mix(in srgb,var(--bad) 55%,transparent)}
.meta{flex:0 0 230px}
.nm{font-weight:bold;font-size:14px}
.no{color:var(--accent);font-family:Consolas,monospace;margin-right:6px}
.tags{margin-top:6px;display:flex;flex-wrap:wrap;gap:4px}
.tag{font-size:11px;border-radius:4px;padding:0 6px;background:var(--panel2);border:1px solid var(--line);color:var(--dim)}
.tag.bad{color:var(--bad);border-color:var(--bad);font-weight:bold}
.ctr{margin-top:8px;display:flex;flex-wrap:wrap;gap:4px}
.ctr button{padding:2px 8px;font-size:11px}
.stage{display:flex;gap:14px;align-items:flex-start}
.anim{width:var(--sz,220px);height:var(--sz,220px);border-radius:8px;border:1px solid var(--line);
  background-repeat:no-repeat;cursor:zoom-in;background-color:#3c0f3c}
.anim.small{--sz:96px;image-rendering:pixelated;border-style:dashed}
.anim .lb{display:none}
.capp{font-size:10px;color:var(--dim);text-align:center;margin-top:2px}
#lb{position:fixed;inset:0;background:rgba(0,0,0,.88);display:none;z-index:50;
  flex-direction:column;align-items:center;justify-content:center;gap:10px}
#lb .big{width:min(88vmin,880px);height:min(88vmin,880px);background-repeat:no-repeat;
  border-radius:10px;background-color:#3c0f3c}
#lb .cap{font-size:14px}
#lb .ctr2{display:flex;gap:8px}
footer{position:fixed;bottom:0;left:0;right:0;background:var(--panel);border-top:1px solid var(--line);
  padding:6px 16px;font-size:12px;color:var(--dim);z-index:20}
</style>
</head>
<body>
<header>
  <h1>攻击帧动画检查 <small style="color:var(--dim);font-size:12px">ready→firing→recoil→settling 循环 · 触边自动扫描(lum>150,边带12px)</small></h1>
  <div class="bar">
    <span>帧率 <b id="fpsv">4</b> fps <input type="range" id="fps" min="1" max="12" value="4"></span>
    <button id="playall" class="on">全部播放</button>
    <button id="pauseall">全部暂停</button>
    <span style="width:1px;height:18px;background:var(--line)"></span>
    <button id="f96">96px 预览列</button>
    <button id="fwarn" class="fw">只看触边警告</button>
    <span style="width:1px;height:18px;background:var(--line)"></span>
    <span>点击画面 = 放大逐拍检查(抠图坏点重点:070 车体炮/天线、110 射击孔)</span>
  </div>
</header>
<main id="list"></main>
<div id="lb">
  <div class="big" id="lbig"></div>
  <div class="cap" id="lcap"></div>
  <div class="ctr2">
    <button id="lprev">◀ 上一拍</button><button id="lnext">下一拍 ▶</button>
    <button id="lplay">播放</button><button id="lclose">关闭</button>
  </div>
</div>
<footer>触边判定:拍内四边 12px 带亮像素≥30 → 烟/火贴图缘,须 PIL 羽化收边(禁止直接裁剪);触发卡重验抠图区。</footer>
<script>
const CARDS=__DATA__;
const POS=[[0,0],[100,0],[0,100],[100,100]];
const BEAT=["TL ready","TR firing","BL recoil","BR settling"];
let fps=4, playing=true;

function el(h){const d=document.createElement("div");d.innerHTML=h;return d.firstElementChild;}

function build(){
  const list=document.getElementById("list");
  for(const c of CARDS){
    const hasWarn=Object.keys(c.edges).length>0;
    const tags=BEAT.map((b,i)=>{
      const e=c.edges["TL,TR,BL,BR".split(",")[i]];
      return e?`<span class="tag bad">${b}: ${Object.entries(e).map(([k,v])=>k+v).join(" ")}</span>`
              :`<span class="tag">${b.split(" ")[0]} ✓</span>`;
    }).join("");
    const row=el(`<div class="row${hasWarn?" warnrow":""}" data-no="${c.no}">
      <div class="meta">
        <div class="nm"><span class="no">${c.no}</span>${c.name}</div>
        <div class="tags">${tags}</div>
        <div class="ctr">
          <button data-a="pp">暂停</button><button data-a="prev">◀</button><button data-a="next">▶</button>
          <button data-a="fps-">慢-</button><button data-a="fps+">快+</button>
          <span style="color:var(--dim);font-size:11px;align-self:center" class="fv">${fps}fps</span>
        </div>
      </div>
      <div class="stage">
        <div><div class="anim" data-i="0" style="background-image:url('${c.file}');background-size:200% 200%;background-position:0 0"></div>
        <div class="capp">动画(220px)</div></div>
        <div><div class="anim small" data-i="0" style="background-image:url('${c.file}');background-size:200% 200%;background-position:0 0"></div>
        <div class="capp">战场 96px</div></div>
      </div>
    </div>`);
    const anims=row.querySelectorAll(".anim");
    const ppBtn=row.querySelector('[data-a=pp]'), fv=row.querySelector(".fv");
    const st={i:0,acc:0,on:true,per:1/fps};
    st.tick=(dt)=>{
      if(!st.on)return;
      st.acc+=dt;
      if(st.acc>=st.per){st.acc=0;st.i=(st.i+1)%4;paint();}
    };
    const paint=()=>{
      const [x,y]=POS[st.i];
      anims.forEach(a=>a.style.backgroundPosition=x+"% "+y+"%");
      ppBtn.textContent=st.on?"暂停":"播放";
    };
    row._tick=st.tick;
    row._setFps=(v)=>{st.per=1/v;fv.textContent=v+"fps";};
    row._step=()=>{st.on=false;st.i=(st.i+1)%4;paint();};
    row._pp=()=>{st.on=!st.on;paint();};
    row._seek=(d)=>{st.on=false;st.i=(st.i+d+4)%4;paint();};
    row._setOn=(v)=>{if(st.on!==v){st.on=v;paint();}};
    ppBtn.onclick=()=>row._pp();
    row.querySelectorAll(".ctr button").forEach(b=>{
      if(b===ppBtn)return;
      b.onclick=()=>{
        const a=b.dataset.a;
        if(a==="prev")row._seek(-1); else if(a==="next")row._seek(1);
        else if(a==="fps-")row._setFps(Math.max(1,fpsOf(row)-1));
        else if(a==="fps+")row._setFps(Math.min(12,fpsOf(row)+1));
      };
    });
    const fpsOf=(r)=>parseInt(r.querySelector(".fv").textContent);
    anims.forEach(a=>a.onclick=()=>openLb(c));
    list.appendChild(row);
  }
}

function tickAll(dt){document.querySelectorAll(".row").forEach(r=>r._tick&&r._tick(dt));}
let last=performance.now();
function loop(t){const dt=(t-last)/1000;last=t;if(playing)tickAll(dt);requestAnimationFrame(loop);}
requestAnimationFrame(loop);

document.getElementById("fps").oninput=e=>{
  fps=+e.target.value;document.getElementById("fpsv").textContent=fps;
  document.querySelectorAll(".row").forEach(r=>r._setFps&&r._setFps(fps));
};
document.getElementById("playall").onclick=()=>{playing=true;
  document.querySelectorAll(".row").forEach(r=>r._setOn&&r._setOn(true));};
document.getElementById("pauseall").onclick=()=>{playing=false;
  document.querySelectorAll(".row").forEach(r=>r._setOn&&r._setOn(false));};
document.getElementById("f96").onclick=e=>{
  document.body.classList.toggle("s96");
  const on=document.body.classList.contains("s96");
  e.target.classList.toggle("on",on);
  document.querySelectorAll(".row .stage").forEach(s=>s.style.display=on?"none":"");
  document.querySelectorAll(".row .anim.small").forEach(a=>{
    a.style.setProperty("--sz",on?"96px":"220px");
    a.style.width=a.style.height="var(--sz)";
    a.parentElement.style.display=on?"":"none";
    a.parentElement.previousElementSibling.style.display=on?"none":"";
  });
};
document.getElementById("fwarn").onclick=e=>{
  const on=e.target.classList.toggle("on");
  document.querySelectorAll(".row").forEach(r=>{
    r.style.display=(on&&!r.classList.contains("warnrow"))?"none":"";
  });
};
/* 简化:96px 切换直接改两列显隐 */
document.getElementById("f96").onclick=e=>{
  const on=e.target.classList.toggle("on");
  document.querySelectorAll(".row").forEach(r=>{
    const full=r.querySelector(".anim:not(.small)").parentElement;
    const sm=r.querySelector(".anim.small").parentElement;
    full.style.display=on?"none":"";
    sm.style.display=on?"":"none";
  });
};

let lbC=null,lbI=0,lbT=null,lbOn=false;
function openLb(c){lbC=c;lbI=0;lbOn=false;paintLb();document.getElementById("lb").style.display="flex";}
function paintLb(){
  const [x,y]=POS[lbI];
  document.getElementById("lbig").style.cssText=
    `width:min(88vmin,880px);height:min(88vmin,880px);background-color:#3c0f3c;`+
    `background-image:url('${lbC.file}');background-repeat:no-repeat;`+
    `background-size:200% 200%;background-position:${x}% ${y}%`;
  const e=lbC.edges["TL,TR,BL,BR".split(",")[lbI]];
  document.getElementById("lcap").innerHTML=
    `<b>${lbC.no}·${lbC.name}</b> — ${BEAT[lbI]}`+(e?` <span style="color:var(--bad)">⚠ 触边: ${JSON.stringify(e)}</span>`:"");
}
document.getElementById("lprev").onclick=()=>{lbI=(lbI+3)%4;paintLb();};
document.getElementById("lnext").onclick=()=>{lbI=(lbI+1)%4;paintLb();};
document.getElementById("lplay").onclick=e=>{
  lbOn=!lbOn;e.target.textContent=lbOn?"暂停":"播放";
  clearInterval(lbT);
  if(lbOn)lbT=setInterval(()=>{lbI=(lbI+1)%4;paintLb();},250);
};
document.getElementById("lclose").onclick=()=>{clearInterval(lbT);document.getElementById("lb").style.display="none";};
document.addEventListener("keydown",e=>{
  if(document.getElementById("lb").style.display!=="flex")return;
  if(e.key==="ArrowLeft"){lbI=(lbI+3)%4;paintLb();}
  if(e.key==="ArrowRight"){lbI=(lbI+1)%4;paintLb();}
  if(e.key==="Escape")document.getElementById("lclose").click();
});
build();
</script>
</body>
</html>"""

html = HTML.replace("__DATA__", json.dumps(cards, ensure_ascii=False))
out = os.path.join(ROOT, "docs", "卡图API重生成_20261014", "attk_review.html")
with open(out, "w", encoding="utf-8") as f:
    f.write(html)
print("-> %s" % out, flush=True)
