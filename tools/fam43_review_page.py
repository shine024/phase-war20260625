# -*- coding: utf-8 -*-
"""fam43 重生成批目检页：锚定 vs f0/f1/f1放大/f9闭环 + GIF，判定「可以/要修」。

用法: python tools/fam43_review_page.py
产物: .godot/unit_review/fam43_review.html + fam43_review_web/*.jpg
"""
import json
import os
import re

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, ".godot", "unit_review", "codeanim")
WEB = os.path.join(ROOT, ".godot", "unit_review", "fam43_review_web")
ANCH = os.path.join(ROOT, ".godot", "unit_review", "fam43_anchor_from_card")
CFG = os.path.join(ROOT, ".godot", "unit_review", "codeanim_configs", "_configs_fam43.json")

CELL = 512


def cell_of(sheet, f):
    col, row = f % 5, f // 5
    return sheet.crop((col * CELL, row * CELL, (col + 1) * CELL, (row + 1) * CELL))


def load_verdicts():
    """读判定 JSON（用户导出的验收结果；带 (N) 后缀的较新优先）。status=可以的行隐藏。"""
    import glob
    v = {}
    ps = glob.glob(os.path.join(ROOT, "tools", "fam43_review*.json"))
    ps.sort(key=lambda p: (int(re.findall(r"\((\d+)\)", p)[-1]) if re.search(r"\(\d+\)", p) else -1))
    for p in ps:
        try:
            v.update(json.load(open(p, encoding="utf-8")))
            print("[verdict] %s (%d)" % (os.path.basename(p), len(v)))
        except Exception as e:
            print("[warn] %s 解析失败: %s" % (p, e))
    return v


def main():
    os.makedirs(WEB, exist_ok=True)
    cfgs = json.load(open(CFG, encoding="utf-8"))
    verdict = load_verdicts()
    keys = list(cfgs)
    rows = []
    for k in keys:
        sp = os.path.join(OUT_DIR, "%s_codeanim_sheet.png" % k)
        if not os.path.exists(sp):
            continue
        sheet = Image.open(sp).convert("RGBA")
        mz = cfgs[k].get("muzzle", [512, 512])
        for f in (0, 1, 2, 9):
            c = cell_of(sheet, f)
            bg = Image.new("RGBA", c.size, (24, 24, 28, 255))
            bg.alpha_composite(c)
            bg.convert("RGB").resize((256, 256), Image.LANCZOS).save(
                os.path.join(WEB, "%s_f%d.jpg" % (k, f)), quality=88)
        # f1 枪口放大：512 格内以 muzzle/2 为中心取 220²
        c1 = cell_of(sheet, 1)
        cx, cy = mz[0] / 2.0, mz[1] / 2.0
        r = 110
        box = (max(0, int(cx - r)), max(0, int(cy - r)),
               min(CELL, int(cx + r)), min(CELL, int(cy + r)))
        z = c1.crop(box)
        zb = Image.new("RGBA", (z.width, z.height), (24, 24, 28, 255))
        zb.alpha_composite(z)
        zb.convert("RGB").resize((256, 256), Image.NEAREST).save(
            os.path.join(WEB, "%s_f1z.jpg" % k), quality=88)
        ap = os.path.join(ANCH, "%s_anchor_raw.png" % k)
        if os.path.exists(ap):
            a = Image.open(ap).convert("RGB").resize((220, 220), Image.LANCZOS)
            a.save(os.path.join(WEB, "%s_anch.jpg" % k), quality=85)
        rows.append(k)

    # 显示行 = 未判定 + 要修的（「可以」的隐藏——用户令 2026-10-06）
    show = [k for k in rows if verdict.get(k, {}).get("status") != "可以"]
    n_ok = len(rows) - len(show)
    h = ["<!DOCTYPE html><html><head><meta charset='utf-8'><title>fam43 codeanim 重生成目检</title><style>",
         "body{font:14px/1.5 'Microsoft YaHei',sans-serif;background:#1b1e24;color:#ddd;margin:0;padding:14px}",
         "h1{font-size:18px;color:#fff} .note{background:#262b33;border-left:4px solid #e8a;padding:8px 12px;margin:8px 0;font-size:13px}",
         "table{border-collapse:collapse;width:100%;table-layout:fixed}",
         "th{position:sticky;top:0;background:#22262e;color:#9fc3ff;padding:6px;border:1px solid #3a4150;z-index:2}",
         "td{border:1px solid #3a4150;padding:5px;vertical-align:top;background:#20242b}",
         "td img{width:190px;display:block;background:#111} td.kk{font-weight:bold;color:#ffd479;width:120px;font-size:13px}",
         "textarea{width:100%;height:56px;background:#161a20;color:#eee;border:1px solid #444;font:12px sans-serif;box-sizing:border-box}",
         ".btns{margin-top:4px;display:flex;gap:6px;align-items:center} button{background:#31405a;color:#cfe3ff;border:1px solid #4a5f80;padding:2px 10px;cursor:pointer;border-radius:3px}",
         ".okchip{display:inline-block;padding:1px 8px;border-radius:8px;font-size:12px} .ok{background:#1d3a1d;color:#8f8}.bad{background:#3a2a1d;color:#fa8}",
         ".pre{font-size:12px;color:#fa8;margin:2px 0} .new{font-size:11px;color:#8cf;border:1px solid #4a5f80;border-radius:3px;padding:0 4px;margin-left:4px}",
         ".bar{position:sticky;bottom:0;background:#22262e;padding:8px;border-top:1px solid #3a4150}",
         "</style></head><body>",
         "<h1>fam43 codeanim 卡图直出重生成目检 <small>显示 %d 家 · 已隐藏 %d 家「可以」 · 看火光位/朝向/闭环</small></h1>" % (len(show), n_ok),
         "<div class=note><b>看什么</b>：① f1 火光是否落在<b>武器轴线枪口</b>（f1z 放大格）② f0 与 f9 是否一致（闭环）",
         "③ cutout 家族后坐是否穿帮 ④ GIF 整体节奏。判定写入备注，导出 JSON 回填修复。</div>",
         "<table><tr><th>单位</th><th>锚定</th><th>f0</th><th>f1</th><th>f1 放大</th><th>f2</th><th>f9</th><th>GIF</th><th>判定</th></tr>"]
    for k in show:
        vd = verdict.get(k, {})
        pre = ""
        if vd.get("status") == "要修":
            pre = "<div class=pre>前判定：要修%s</div>" % (
                " · " + vd["note"] if vd.get("note") else "")
        tag = "" if k in verdict else "<span class=new>新</span>"
        h.append("<tr><td class=kk>%s%s%s</td>" % (k, tag, pre))
        h.append("<td><img src='fam43_review_web/%s_anch.jpg'></td>" % k)
        for f in (0, 1,):
            h.append("<td><img src='fam43_review_web/%s_f%d.jpg'></td>" % (k, f))
        h.append("<td><img src='fam43_review_web/%s_f1z.jpg'></td>" % k)
        for f in (2, 9):
            h.append("<td><img src='fam43_review_web/%s_f%d.jpg'></td>" % (k, f))
        h.append("<td class=gif><img src='codeanim/%s_codeanim_anim.gif' width=200></td>" % k)
        h.append(("<td><textarea id='nt_%s' placeholder='问题…'></textarea>"
                  "<div class=btns><button onclick=\"mark('%s','可以')\">可以</button>"
                  "<button onclick=\"mark('%s','要修')\">要修</button><span id='st_%s'></span></div></td></tr>")
                 % (k, k, k, k))
    h.append("</table><div class=bar><button onclick=exp()>导出 JSON（+复制）</button><span id=saved></span></div>")
    h.append("<script>var KEY='fam43_review';var KEYS=%s;" % json.dumps(show))
    h.append("var VERDICT=%s;" % json.dumps(verdict, ensure_ascii=False))
    h.append("""
var S=Object.assign({},VERDICT,JSON.parse(localStorage.getItem(KEY)||'{}'));
function save(){localStorage.setItem(KEY,JSON.stringify(S));document.getElementById('saved').textContent='已保存 '+new Date().toLocaleTimeString();}
KEYS.forEach(function(k){var t=document.getElementById('nt_'+k);
 t.addEventListener('input',function(){S[k]=S[k]||{};S[k].note=t.value;clearTimeout(window._d);window._d=setTimeout(save,300);});
 if(S[k]&&S[k].note)t.value=S[k].note;chip(k);});
function chip(k){var st=document.getElementById('st_'+k);var v=S[k]&&S[k].status;
 st.innerHTML=v?'<span class="okchip '+(v=='可以'?'ok':'bad')+'">'+v+'</span>':'';}
function mark(k,v){S[k]=S[k]||{};S[k].status=v;save();chip(k);}
function exp(){var b=new Blob([JSON.stringify(S,null,1)],{type:'application/json'});
 var a=document.createElement('a');a.href=URL.createObjectURL(b);a.download='fam43_review.json';a.click();
 navigator.clipboard.writeText(JSON.stringify(S,null,1));}
</script></body></html>""")
    open(os.path.join(ROOT, ".godot", "unit_review", "fam43_review.html"), "w",
         encoding="utf-8").write("\n".join(h))
    print("wrote fam43_review.html", len(rows), "rows")


if __name__ == "__main__":
    main()
