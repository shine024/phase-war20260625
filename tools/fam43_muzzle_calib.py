# -*- coding: utf-8 -*-
"""fam43 枪口点击校准页（2026-10-06 第4轮「还是错」终结器）。

5 家位置争议单位：bmp1_x / m270 / ww2_arty_m81（要修还是错）
                + zsu23 / flame_raider_advanced（可以但备注位置不对）。
每家显示锚定抠图（暗底）+ 当前枪口标记（金十字）；用户点两下：
  第1下=武器口（绿十字），第2下=管身方向参考点（画轴线）→ 自动算 flash_angle。
导出 JSON {key:{"muzzle":[x,y],"flash_angle":n}} → 回填配置重生。
产物: .godot/unit_review/fam43_muzzle_calib.html + fam43_calib_web/
"""
import io
import json
import os
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANCH = os.path.join(ROOT, ".godot", "unit_review", "fam43_anchor_from_card")
CFG = os.path.join(ROOT, ".godot", "unit_review", "codeanim_configs", "_configs_fam43.json")
WEB = os.path.join(ROOT, ".godot", "unit_review", "fam43_calib_web")
KEYS = ["cold_sup_bmp1_x", "mod_arty_m270", "ww2_arty_m81",
        "cold_sup_zsu23", "flame_raider_advanced",
        # R2 换卡重锚 4 家（2026-10-06 (4).json 后整链）
        "ww2_air_dive_bomber", "mod_air_multirole",
        "fe_helix_phantom", "flame_raider_expert"]


def cutout(k):
    """锚定品红场 → 透明抠图（页面暗底显示）。"""
    a = np.asarray(Image.open(os.path.join(ANCH, "%s_anchor_raw.png" % k)).convert("RGBA")).copy()
    rgb = a[:, :, :3].astype(int)
    d = np.sqrt(((rgb - np.array([255, 0, 255])) ** 2).sum(axis=2))
    a[:, :, 3] = np.where(d < 100, 0, a[:, :, 3])
    return Image.fromarray(a)


def main():
    os.makedirs(WEB, exist_ok=True)
    cfgs = json.load(open(CFG, encoding="utf-8"))
    cur = {}
    for k in KEYS:
        im = cutout(k)
        im.resize((1024, 1024), Image.LANCZOS).save(os.path.join(WEB, "%s.png" % k))
        c = cfgs.get(k, {})
        cur[k] = {"muzzle": c.get("muzzle"), "flash_angle": c.get("flash_angle", 0)}
    h = ["<!DOCTYPE html><html><head><meta charset='utf-8'><title>fam43 枪口校准</title><style>",
         "body{font:14px/1.5 'Microsoft YaHei',sans-serif;background:#1b1e24;color:#ddd;margin:0;padding:14px}",
         "h1{font-size:18px;color:#fff}",
         ".row{display:flex;gap:14px;margin:14px 0;align-items:flex-start}",
         ".wrap{position:relative;width:512px;height:512px;background:#101318;border:1px solid #3a4150;cursor:crosshair}",
         ".wrap img{width:512px;height:512px;display:block;pointer-events:none}",
         "canvas{position:absolute;left:0;top:0;pointer-events:none}",
         ".kk{font-weight:bold;color:#ffd479;width:170px}",
         ".st{font-size:12px;color:#9fc3ff;margin-top:6px;min-height:34px}",
         ".note{background:#262b33;border-left:4px solid #e8a;padding:8px 12px;margin:8px 0;font-size:13px}",
         ".bar{position:sticky;bottom:0;background:#22262e;padding:10px;border-top:1px solid #3a4150}",
         "button{background:#31405a;color:#cfe3ff;border:1px solid #4a5f80;padding:4px 14px;cursor:pointer;border-radius:3px}",
         "</style></head><body>",
         "<h1>fam43 枪口点击校准 <small>5 家·两下一组：先点<b>武器口</b>，再点<b>管身方向参考点</b>（往炮根/枪托方向点一下）</small></h1>",
         "<div class=note>金十字=当前火光位置（被打回的错位）。绿十字=你点的新枪口；白线=武器轴线，"
         "角度自动换算。每家点满两下即可，点错再点会从头来。全部点完按「导出 JSON」。</div>"]
    for k in KEYS:
        h.append("<div class=row><div class=kk>%s<br><span class=st id='st_%s'></span></div>"
                 "<div class=wrap id='w_%s'><img src='fam43_calib_web/%s.png'>"
                 "<canvas id='c_%s' width=512 height=512></canvas></div></div>"
                 % (k, k, k, k, k))
    h.append("<div class=bar><button onclick=exp()>导出 JSON（+复制）</button><span id=saved></span></div>")
    h.append("<script>var KEYS=%s;var CUR=%s;var P={}%s;" % (
        json.dumps(KEYS), json.dumps(cur, ensure_ascii=False), ""))
    h.append("""
var S=JSON.parse(localStorage.getItem('fam43_calib')||'{}');
KEYS.forEach(function(k){
 var w=document.getElementById('w_'+k), cv=document.getElementById('c_'+k), st=document.getElementById('st_'+k);
 var ctx=cv.getContext('2d');
 function draw(){
  ctx.clearRect(0,0,512,512);
  var c=CUR[k];
  if(c.muzzle){ // 金十字=当前
   ctx.strokeStyle='#e8b23a';ctx.lineWidth=2;
   cross(c.muzzle[0]/2,c.muzzle[1]/2);
  }
  var p=S[k];
  if(p&&p.muzzle){ // 绿十字=新
   ctx.strokeStyle='#59e05a';ctx.lineWidth=2;
   cross(p.muzzle[0]/2,p.muzzle[1]/2);
   if(p.back){ctx.beginPath();ctx.moveTo(p.muzzle[0]/2,p.muzzle[1]/2);
    ctx.lineTo(p.back[0]/2,p.back[1]/2);ctx.strokeStyle='#fff';ctx.setLineDash([6,4]);ctx.stroke();ctx.setLineDash([]);}
  }
  var txt=[];
  if(c.muzzle)txt.push('当前 ['+c.muzzle.join(',')+']°'+c.flash_angle);
  if(p&&p.muzzle&&p.back)txt.push('→ 新 ['+p.muzzle.join(',')+']°'+p.flash_angle);
  else if(p&&p.muzzle)txt.push('→ 枪口已点，再点管身参考点');
  else txt.push('未点（这家不用改可留空）');
  st.textContent=txt.join('  ');
 }
 function cross(x,y){ctx.beginPath();ctx.moveTo(x-14,y);ctx.lineTo(x+14,y);ctx.moveTo(x,y-14);ctx.lineTo(x,y+14);ctx.stroke();
  ctx.beginPath();ctx.arc(x,y,7,0,7);ctx.stroke();}
 w.addEventListener('click',function(ev){
  var r=w.getBoundingClientRect();
  var x=Math.round((ev.clientX-r.left)*2), y=Math.round((ev.clientY-r.top)*2); // 1024 域
  var p=S[k]||{};
  if(!p.muzzle||p.back){p={muzzle:[x,y]};}
  else if(!p.back){p.back=[x,y];
   var fx=p.muzzle[0]-p.back[0], fy=p.muzzle[1]-p.back[1];
   p.flash_angle=Math.round(-Math.atan2(-fy,-fx)*180/Math.PI);
   if(p.flash_angle>90)p.flash_angle-=360; if(p.flash_angle<-90)p.flash_angle+=360;
  }
  S[k]=p;localStorage.setItem('fam43_calib',JSON.stringify(S));draw();
 });
 draw();
});
function exp(){var o={};KEYS.forEach(function(k){var p=S[k];if(p&&p.muzzle)o[k]={muzzle:p.muzzle,flash_angle:p.flash_angle||0};});
 var t=JSON.stringify(o,null,1);navigator.clipboard.writeText(t);
 var b=new Blob([t],{type:'application/json'});var a=document.createElement('a');
 a.href=URL.createObjectURL(b);a.download='fam43_calib.json';a.click();
 document.getElementById('saved').textContent='已导出 '+Object.keys(o).length+' 家 '+new Date().toLocaleTimeString();}
</script></body></html>""")
    open(os.path.join(ROOT, ".godot", "unit_review", "fam43_muzzle_calib.html"), "w",
         encoding="utf-8").write("\n".join(h))
    print("wrote fam43_muzzle_calib.html", len(KEYS), "家")


if __name__ == "__main__":
    main()
