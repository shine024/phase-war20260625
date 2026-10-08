# -*- coding: utf-8 -*-
"""fam44 开火点设定页：非「可以」行，点图设 muzzle（codeanim 家直接对应配置 1024 锚定域）。

用法: python tools/fam44_muzzle_page.py
读判定: .godot/unit_review/fam44_review*.json（带 (N) 后缀较新优先）+ tools/ 同名
产物: .godot/unit_review/fam44_muzzle.html
导出: fam44_muzzle.json → {rowid: {pt:[x,y], space:N, note:str}}
"""
import glob
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UR = os.path.join(ROOT, ".godot", "unit_review")
WEB = os.path.join(UR, "fam44_review_web")
CFG = os.path.join(UR, "codeanim_configs", "_configs_fam44.json")
ASSETS = os.path.join(ROOT, "assets", "effects", "unit_anims")
CARDS = os.path.join(ROOT, "assets", "card_icons")

BATCH_B = {
    "mod_arm_stryker_e": "enemy/vis_enemy_059.png",
    "mod_arm_m1a2sep": "enemy/vis_enemy_023.png",
    "ww2_arm_garand_para": "enemy/ww2_arm_garand_para.png",
}


def load_verdicts():
    v = {}
    ps = glob.glob(os.path.join(UR, "fam44_review*.json")) + glob.glob(
        os.path.join(ROOT, "tools", "fam44_review*.json"))
    ps.sort(key=lambda p: (int(re.findall(r"\((\d+)\)", p)[-1]) if re.search(r"\(\d+\)", p) else -1,
                           os.path.getmtime(p)))
    for p in ps:
        try:
            v.update(json.load(open(p, encoding="utf-8")))
            print("[verdict] %s (%d)" % (os.path.basename(p), len(v)))
        except Exception as e:
            print("[warn] %s 解析失败: %s" % (p, e))
    return v


def main():
    cfgs = json.load(open(CFG, encoding="utf-8"))
    verdict = load_verdicts()

    # 行定义：(rowid, 显示名, 可点大图路径, 自然边长, 种子点, 参考图列表)
    rows = []
    for k in cfgs:
        if verdict.get(k, {}).get("status") == "可以":
            continue
        anchor = os.path.join(UR, "fam44_anchor_from_card", "%s_anchor_raw.png" % k)
        if not os.path.exists(anchor):
            print("[skip] %s 无锚定" % k)
            continue
        refs = [("f0", "fam44_review_web/%s_f0.jpg" % k),
                ("f1", "fam44_review_web/%s_f1.jpg" % k),
                ("GIF", "codeanim/%s_codeanim_anim.gif" % k)]
        rows.append((k, k, "fam44_anchor_from_card/%s_anchor_raw.png" % k, 1024,
                     cfgs[k].get("muzzle"), refs))
    # 批A 待修行（assets 现役 f0 帧）
    for k in ("mod_arm_m1a2sep",):
        if verdict.get("A:" + k, {}).get("status") == "可以":
            continue
        sp = os.path.join(ASSETS, k, "sheet_attack.png")
        if not os.path.exists(sp):
            continue
        from PIL import Image
        sheet = Image.open(sp).convert("RGBA")
        c0 = sheet.crop((0, 0, 256, 256))
        bg = Image.new("RGBA", (256, 256), (24, 24, 28, 255))
        bg.alpha_composite(c0)
        bg.convert("RGB").resize((512, 512), Image.NEAREST).save(
            os.path.join(WEB, "%s_mzclick.jpg" % k), quality=90)
        rows.append(("A:" + k, k + "（现役 f0）", "fam44_review_web/%s_mzclick.jpg" % k, 512,
                     None, [("f1", "fam44_review_web/%s_af1.jpg" % k)]))
    # 批B 待修行（新 cardE 为可点图）
    for k, rel in BATCH_B.items():
        if verdict.get("B:" + k, {}).get("status") == "可以":
            continue
        p = os.path.join(CARDS, rel)
        if not os.path.exists(p):
            continue
        rows.append(("B:" + k, k + "（新卡E）", os.path.relpath(p, UR).replace("\\", "/"), 512,
                     None, [("旧卡E", "fam44_review_web/%s_old_enemy.jpg" % k)]))

    h = ["<!DOCTYPE html><html><head><meta charset='utf-8'><title>fam44 开火点设定</title><style>",
         "body{font:14px/1.5 'Microsoft YaHei',sans-serif;background:#1b1e24;color:#ddd;margin:0;padding:14px}",
         "h1{font-size:18px;color:#fff} h2{font-size:15px;color:#9fc3ff;margin:18px 0 6px}",
         ".note{background:#262b33;border-left:4px solid #e8a;padding:8px 12px;margin:8px 0;font-size:13px}",
         ".card{display:flex;gap:14px;background:#20242b;border:1px solid #3a4150;padding:10px;margin:8px 0}",
         ".clickwrap{position:relative;flex:0 0 448px} .clickwrap img{width:448px;display:block;background:#111;cursor:crosshair}",
         ".cross{position:absolute;width:22px;height:22px;pointer-events:none;transform:translate(-50%,-50%)}",
         ".cross:before,.cross:after{content:'';position:absolute;background:#ff5252}",
         ".cross:before{left:10px;top:0;width:2px;height:22px} .cross:after{top:10px;left:0;height:2px;width:22px}",
         ".cross i{position:absolute;left:14px;top:-16px;background:#ff5252;color:#fff;font:11px sans-serif;font-style:normal;padding:0 3px;white-space:nowrap}",
         ".kk{font-weight:bold;color:#ffd479;font-size:14px} .pre{font-size:12px;color:#fa8;margin:2px 0}",
         ".coord{font:13px monospace;color:#8f8;background:#161a20;padding:2px 8px;border-radius:3px;display:inline-block;margin:4px 0}",
         ".refs{display:flex;gap:6px;margin-top:6px} .refs img{width:120px;display:block;background:#111}",
         ".refs div{font-size:11px;color:#9ab;text-align:center}",
         "textarea{width:100%;height:48px;background:#161a20;color:#eee;border:1px solid #444;font:12px sans-serif;box-sizing:border-box}",
         ".chip{display:inline-block;padding:1px 8px;border-radius:8px;font-size:12px} .set{background:#1d3a1d;color:#8f8}.unset{background:#3a2a1d;color:#fa8}",
         "button{background:#31405a;color:#cfe3ff;border:1px solid #4a5f80;padding:2px 10px;cursor:pointer;border-radius:3px}",
         ".bar{position:sticky;bottom:0;background:#22262e;padding:8px;border-top:1px solid #3a4150}",
         "</style></head><body>",
         "<h1>fam44 开火点设定 <small>共 %d 行（已去除「可以」）</small></h1>" % len(rows),
         "<div class=note><b>怎么用</b>：在左侧大图上<b>点击枪口/开火位置</b>（红十字=当前设定，再点可改）。",
         "codeanim 家大图=1024 锚定域，坐标直接对应 _configs_fam44.json 的 muzzle；批A/批B 行坐标记录备用。",
         "右侧参考图：f1=当前火光实际落点。全部设完点底部「导出 JSON」。</div>"]
    h.append("<script>var ROWS=%s;</script>" % json.dumps(
        [{"id": r[0], "name": r[1], "img": r[2], "space": r[3], "seed": r[4]} for r in rows]))
    for rid, name, img, space, seed, refs in rows:
        vd = verdict.get(rid, {})
        pre = ""
        if vd.get("status") == "要修":
            pre = "<div class=pre>前判定：要修%s</div>" % (
                " · " + vd["note"] if vd.get("note") else "")
        h.append("<div class=card><div class=clickwrap id='w_%s'>"
                 "<img src='%s' onclick=\"pt(event,'%s',%d)\">"
                 "<div class=cross id='c_%s' style='display:none'><i id='l_%s'></i></div></div>" % (
                     rid.replace(":", "_"), img, rid.replace(":", "_"), space,
                     rid.replace(":", "_"), rid.replace(":", "_")))
        h.append("<div style='flex:1'><div class=kk>%s%s</div>%s" % (name, "", pre))
        h.append("<div class=coord id='v_%s'>未设点</div> <span class='chip unset' id='h_%s'>未设</span>" % (
            rid.replace(":", "_"), rid.replace(":", "_")))
        h.append("<div class=refs>")
        for lbl, rimg in refs:
            h.append("<div>%s<br><img src='%s'></div>" % (lbl, rimg))
        h.append("</div><textarea id='nt_%s' placeholder='备注（导出随行）'></textarea></div></div>" % (
            rid.replace(":", "_")))
    h.append("<div class=bar><button onclick=exp()>导出 muzzle JSON（+复制）</button> <span id=saved></span> "
             "<span style='color:#9ab;font-size:12px'>产物 fam44_muzzle.json</span></div>")
    h.append("""
<script>
var KEY='fam44_muzzle';
var S=JSON.parse(localStorage.getItem(KEY)||'{}');
var MAP={};ROWS.forEach(function(r){MAP[r.id.replace(/:/g,'_')]=r;});
function dom(id){return document.getElementById(id);}
function put(id,pt,save){S[id]=S[id]||{};S[id].pt=pt;S[id].space=MAP[id].space;
 dom('v_'+id).textContent='pt = ['+pt[0]+', '+pt[1]+']  (空间 '+MAP[id].space+')';
 dom('h_'+id).textContent='已设';dom('h_'+id).className='chip set';
 var c=dom('c_'+id);c.style.display='block';
 var im=dom('w_'+id).querySelector('img').getBoundingClientRect();
 c.style.left=(pt[0]/MAP[id].space*im.width)+'px';c.style.top=(pt[1]/MAP[id].space*im.height)+'px';
 dom('l_'+id).textContent=pt[0]+','+pt[1];
 if(save!==false){localStorage.setItem(KEY,JSON.stringify(S));dom('saved').textContent='已保存 '+new Date().toLocaleTimeString();}}
function pt(e,id,space){var im=e.currentTarget;var r=im.getBoundingClientRect();
 var x=Math.round((e.clientX-r.left)/r.width*space),y=Math.round((e.clientY-r.top)/r.height*space);
 x=Math.max(0,Math.min(space,x));y=Math.max(0,Math.min(space,y));put(id,[x,y]);}
ROWS.forEach(function(r){var id=r.id.replace(/:/g,'_');
 var t=dom('nt_'+id);
 t.addEventListener('input',function(){S[id]=S[id]||{};S[id].note=t.value;localStorage.setItem(KEY,JSON.stringify(S));});
 if(S[id]){if(S[id].note)t.value=S[id].note;if(S[id].pt)setTimeout(function(){put(id,S[id].pt,false);},0);}
 else if(r.seed)setTimeout(function(){put(id,r.seed,false);},0);});
function exp(){ROWS.forEach(function(r){var id=r.id.replace(/:/g,'_');if(S[id]&&S[id].note&&!S[id].pt)S[id].pt=null;});
 var b=new Blob([JSON.stringify(S,null,1)],{type:'application/json'});
 var a=document.createElement('a');a.href=URL.createObjectURL(b);a.download='fam44_muzzle.json';a.click();
 navigator.clipboard.writeText(JSON.stringify(S,null,1));}
</script></body></html>""")
    open(os.path.join(UR, "fam44_muzzle.html"), "w", encoding="utf-8").write("\n".join(h))
    print("wrote fam44_muzzle.html · %d 行（codeanim 未判定 %d + 待修 %d）" % (
        len(rows), sum(1 for r in rows if ":" not in r[0]), sum(1 for r in rows if ":" in r[0])))


if __name__ == "__main__":
    main()
