# -*- coding: utf-8 -*-
"""fam44 重做批目检页：批C codeanim 26 家 + 批A assets 现役 3 家 + 批B 卡图 4 家新旧对比。

用法: python tools/fam44_review_page.py
产物: .godot/unit_review/fam44_review.html + fam44_review_web/*.jpg|gif
判定: fam44_review*.json（带 (N) 后缀较新优先）；status=可以的行隐藏。
"""
import glob
import json
import os
import re

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, ".godot", "unit_review", "codeanim")
WEB = os.path.join(ROOT, ".godot", "unit_review", "fam44_review_web")
ANCH = os.path.join(ROOT, ".godot", "unit_review", "fam44_anchor_from_card")
CFG = os.path.join(ROOT, ".godot", "unit_review", "codeanim_configs", "_configs_fam44.json")
ASSETS = os.path.join(ROOT, "assets", "effects", "unit_anims")
BAK = os.path.join(ROOT, ".godot", "unit_review", "vintage_unify_bak")

CELL = 512   # codeanim sheet 5×2 格
FRM = 256    # assets sheet 帧宽

# 批A：现役 assets 行（已部署）。mark4/105mm 无帧，不列行只在页头注记。
BATCH_A = ["ww1_a7v", "ww1_arty_77mm", "mod_arm_m1a2sep"]
# 批B：卡图新旧对比（E/P 相对 card_icons；bak 名 = 路径下划线拼合 + .bak）
BATCH_B = {
    "mod_arm_stryker_e": ("enemy/vis_enemy_059.png", "player/vis_player_059.png"),
    "mod_arm_m1a2sep": ("enemy/vis_enemy_023.png", "player/vis_player_023.png"),
    "ww2_arm_garand_para": ("enemy/ww2_arm_garand_para.png", "player/ww2_arm_garand_para.png"),
    "ww2_sup_gmc_truck": ("enemy/ww2_sup_gmc_truck.png", "player/ww2_sup_gmc_truck.png"),
}


def cell_of(sheet, f):
    col, row = f % 5, f // 5
    return sheet.crop((col * CELL, row * CELL, (col + 1) * CELL, (col + 1) * CELL))


def thumb(c, name, size=256):
    bg = Image.new("RGBA", c.size, (24, 24, 28, 255))
    bg.alpha_composite(c)
    bg.convert("RGB").resize((size, size), Image.LANCZOS).save(
        os.path.join(WEB, name), quality=88)


def card_thumb(path, name, size=220):
    if not os.path.exists(path):
        return False
    Image.open(path).convert("RGB").resize((size, size), Image.LANCZOS).save(
        os.path.join(WEB, name), quality=85)
    return True


def bak_name(rel):
    stem = os.path.splitext(rel.replace("/", "_"))[0]
    return os.path.join(BAK, "assets_card_icons_" + stem + ".png.bak")


def load_verdicts():
    v = {}
    ps = glob.glob(os.path.join(ROOT, "tools", "fam44_review*.json"))
    ps.sort(key=lambda p: (int(re.findall(r"\((\d+)\)", p)[-1]) if re.search(r"\(\d+\)", p) else -1))
    for p in ps:
        try:
            v.update(json.load(open(p, encoding="utf-8")))
            print("[verdict] %s (%d)" % (os.path.basename(p), len(v)))
        except Exception as e:
            print("[warn] %s 解析失败: %s" % (p, e))
    return v


def rows_codeanim(cfgs):
    """批C：锚定/f0/f1/f1放大/f2/f9/GIF。返回 [(key, 有无锚定)]。"""
    out = []
    for k in cfgs:
        sp = os.path.join(OUT_DIR, "%s_codeanim_sheet.png" % k)
        if not os.path.exists(sp):
            print("[skip] %s 无 sheet" % k)
            continue
        sheet = Image.open(sp).convert("RGBA")
        mz = cfgs[k].get("muzzle", [512, 512])
        for f in (0, 1, 2, 9):
            thumb(cell_of(sheet, f), "%s_f%d.jpg" % (k, f))
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
        has_anch = os.path.exists(os.path.join(ANCH, "%s_anchor_raw.png" % k))
        if has_anch:
            Image.open(os.path.join(ANCH, "%s_anchor_raw.png" % k)).convert("RGB").resize(
                (220, 220), Image.LANCZOS).save(os.path.join(WEB, "%s_anch.jpg" % k), quality=85)
        out.append((k, has_anch))
    return out


def rows_batch_a():
    """批A：读 assets 现役 sheet_attack（12 帧×256 横条），生成帧格 + 资产 GIF。"""
    out = []
    for k in BATCH_A:
        sp = os.path.join(ASSETS, k, "sheet_attack.png")
        if not os.path.exists(sp):
            print("[skip] %s 无现役 sheet" % k)
            continue
        sheet = Image.open(sp).convert("RGBA")
        n = sheet.width // FRM
        for f in (0, 1, 2, 9):
            if f < n:
                thumb(sheet.crop((f * FRM, 0, (f + 1) * FRM, FRM)), "%s_af%d.jpg" % (k, f))
        # f1 放大：中心 128² → 256 NEAREST（视频帧无 muzzle 配置，看整体火光）
        c1 = sheet.crop((1 * FRM, 0, 2 * FRM, FRM))
        z = c1.crop((64, 64, 192, 192))
        zb = Image.new("RGBA", (128, 128), (24, 24, 28, 255))
        zb.alpha_composite(z)
        zb.convert("RGB").resize((256, 256), Image.NEAREST).save(
            os.path.join(WEB, "%s_af1z.jpg" % k), quality=88)
        frames = []
        for i in range(n):
            c = sheet.crop((i * FRM, 0, (i + 1) * FRM, FRM))
            bg = Image.new("RGBA", c.size, (24, 24, 28, 255))
            bg.alpha_composite(c)
            frames.append(bg.convert("RGB"))
        frames[0].save(os.path.join(WEB, "%s_asset.gif" % k), save_all=True,
                       append_images=frames[1:], duration=125, loop=0)
        out.append((k, n))
    return out


def rows_batch_b():
    """批B：新旧卡图（cardE+cardP）四联对比。"""
    out = []
    for k, (relel, relpl) in BATCH_B.items():
        ok = all(card_thumb(os.path.join(ROOT, "assets", "card_icons", rel),
                            "%s_new_%s.jpg" % (k, rel.split("/")[0])) for rel in (relel, relpl))
        ok &= all(card_thumb(bak_name(rel), "%s_old_%s.jpg" % (k, rel.split("/")[0]))
                  for rel in (relel, relpl))
        if ok:
            out.append(k)
        else:
            print("[skip] %s 卡图/旧卡缺失" % k)
    return out


def main():
    os.makedirs(WEB, exist_ok=True)
    cfgs = json.load(open(CFG, encoding="utf-8"))
    verdict = load_verdicts()
    c_rows = rows_codeanim(cfgs)
    a_rows = rows_batch_a()
    b_rows = rows_batch_b()

    def show(rowid):
        return verdict.get(rowid, {}).get("status") != "可以"

    c_show = [k for k, _ in c_rows if show(k)]
    a_show = [k for k, _ in a_rows if show("A:" + k)]
    b_show = [k for k in b_rows if show("B:" + k)]
    n_ok = (len(c_rows) - len(c_show)) + (len(a_rows) - len(a_show)) + (len(b_rows) - len(b_show))

    h = ["<!DOCTYPE html><html><head><meta charset='utf-8'><title>fam44 重做批目检</title><style>",
         "body{font:14px/1.5 'Microsoft YaHei',sans-serif;background:#1b1e24;color:#ddd;margin:0;padding:14px}",
         "h1{font-size:18px;color:#fff} h2{font-size:15px;color:#9fc3ff;margin:18px 0 6px}",
         ".note{background:#262b33;border-left:4px solid #e8a;padding:8px 12px;margin:8px 0;font-size:13px}",
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
         "<h1>fam44 重做批目检 <small>批C %d 家 · 批A %d 家 · 批B %d 卡 · 已隐藏 %d 项「可以」</small></h1>" % (
             len(c_show), len(a_show), len(b_show), n_ok),
         "<div class=note><b>看什么</b>：批C ① f1 火光是否落在<b>武器轴线枪口</b>（f1z 放大格）② f0/f9 闭环 ③ GIF 节奏。",
         "批A 行读<b>现役 assets</b>（已部署态）：看 12 帧朝向一致/火光端/无截断。批B 看新卡身份与朝向、敌我镜像正确。</div>",
         "<div class=note><b>未列行</b>：ww1_mark4 / ww1_105mm 视频域网络受阻（DNS 污染）待重试；",
         "AI 生图批 4 家（quantum_mobile_base / quantum_repair_drone / void_dimensional_soldier / fe_frontier_veteran）未开始；",
         "接线批 5 家（bmp1_x / metis / p18 / himars=main，growler=alt）未开始。</div>"]

    def verdict_cell(rowid):
        vd = verdict.get(rowid, {})
        pre = ""
        if vd.get("status") == "要修":
            pre = "<div class=pre>前判定：要修%s</div>" % (
                " · " + vd["note"] if vd.get("note") else "")
        tag = "" if rowid in verdict else "<span class=new>新</span>"
        return pre, tag

    # ── 批C ──
    h.append("<h2>批C · codeanim 26 家（staging 未部署）</h2>")
    h.append("<table><tr><th>单位</th><th>锚定</th><th>f0</th><th>f1</th><th>f1 放大</th><th>f2</th><th>f9</th><th>GIF</th><th>判定</th></tr>")
    for k, has_anch in c_rows:
        if k not in c_show:
            continue
        pre, tag = verdict_cell(k)
        h.append("<tr><td class=kk>%s%s%s</td>" % (k, tag, pre))
        h.append("<td>%s</td>" % ("<img src='fam44_review_web/%s_anch.jpg'>" % k
                                  if has_anch else "—"))
        for f in (0, 1):
            h.append("<td><img src='fam44_review_web/%s_f%d.jpg'></td>" % (k, f))
        h.append("<td><img src='fam44_review_web/%s_f1z.jpg'></td>" % k)
        for f in (2, 9):
            h.append("<td><img src='fam44_review_web/%s_f%d.jpg'></td>" % (k, f))
        h.append("<td><img src='codeanim/%s_codeanim_anim.gif' width=200></td>" % k)
        h.append(("<td><textarea id='nt_%s' placeholder='问题…'></textarea>"
                  "<div class=btns><button onclick=\"mark('%s','可以')\">可以</button>"
                  "<button onclick=\"mark('%s','要修')\">要修</button><span id='st_%s'></span></div></td></tr>")
                 % (k, k, k, k))
    h.append("</table>")

    # ── 批A ──
    h.append("<h2>批A · 视频分帧重做（现役 assets，已部署）</h2>")
    h.append("<table><tr><th>单位</th><th>f0</th><th>f1</th><th>f1 放大</th><th>f2</th><th>f9</th><th>GIF(12帧)</th><th>判定</th></tr>")
    for k, n in a_rows:
        rid = "A:" + k
        if k not in a_show:
            continue
        pre, tag = verdict_cell(rid)
        h.append("<tr><td class=kk>%s%s%s<div class=pre>attack=%d帧</div></td>" % (k, tag, pre, n))
        for f in (0, 1):
            h.append("<td><img src='fam44_review_web/%s_af%d.jpg'></td>" % (k, f))
        h.append("<td><img src='fam44_review_web/%s_af1z.jpg'></td>" % k)
        for f in (2, 9):
            h.append("<td><img src='fam44_review_web/%s_af%d.jpg'></td>" % (k, f))
        h.append("<td><img src='fam44_review_web/%s_asset.gif' width=220></td>" % k)
        h.append(("<td><textarea id='nt_%s' placeholder='问题…'></textarea>"
                  "<div class=btns><button onclick=\"mark('%s','可以')\">可以</button>"
                  "<button onclick=\"mark('%s','要修')\">要修</button><span id='st_%s'></span></div></td></tr>")
                 % (rid.replace(":", "_"), rid, rid, rid.replace(":", "_")))
    h.append("</table>")

    # ── 批B ──
    h.append("<h2>批B · 卡图推导（新 vs 旧，敌我成对）</h2>")
    h.append("<table><tr><th>单位</th><th>旧 cardE</th><th>新 cardE</th><th>旧 cardP</th><th>新 cardP</th><th>判定</th></tr>")
    for k in b_rows:
        rid = "B:" + k
        if k not in b_show:
            continue
        pre, tag = verdict_cell(rid)
        h.append("<tr><td class=kk>%s%s%s</td>" % (k, tag, pre))
        for side in ("enemy", "player"):
            h.append("<td><img src='fam44_review_web/%s_old_%s.jpg'></td>" % (k, side))
            h.append("<td><img src='fam44_review_web/%s_new_%s.jpg'></td>" % (k, side))
        h.append(("<td><textarea id='nt_%s' placeholder='问题…'></textarea>"
                  "<div class=btns><button onclick=\"mark('%s','可以')\">可以</button>"
                  "<button onclick=\"mark('%s','要修')\">要修</button><span id='st_%s'></span></div></td></tr>")
                 % (rid.replace(":", "_"), rid, rid, rid.replace(":", "_")))
    h.append("</table>")

    h.append("<div class=bar><button onclick=exp()>导出 JSON（+复制）</button><span id=saved></span></div>")
    h.append("<script>var KEY='fam44_review';var KEYS=%s;" % json.dumps(
        c_show + ["A:" + k for k in a_show] + ["B:" + k for k in b_show]))
    h.append("var VERDICT=%s;" % json.dumps(verdict, ensure_ascii=False))
    h.append("""
var S=Object.assign({},VERDICT,JSON.parse(localStorage.getItem(KEY)||'{}'));
function save(){localStorage.setItem(KEY,JSON.stringify(S));document.getElementById('saved').textContent='已保存 '+new Date().toLocaleTimeString();}
KEYS.forEach(function(k){var t=document.getElementById('nt_'+k.replace(':','_'));
 if(!t)return;
 t.addEventListener('input',function(){S[k]=S[k]||{};S[k].note=t.value;clearTimeout(window._d);window._d=setTimeout(save,300);});
 if(S[k]&&S[k].note)t.value=S[k].note;chip(k);});
function chip(k){var st=document.getElementById('st_'+k.replace(':','_'));var v=S[k]&&S[k].status;
 st.innerHTML=v?'<span class="okchip '+(v=='可以'?'ok':'bad')+'">'+v+'</span>':'';}
function mark(k,v){S[k]=S[k]||{};S[k].status=v;save();chip(k);}
function exp(){var b=new Blob([JSON.stringify(S,null,1)],{type:'application/json'});
 var a=document.createElement('a');a.href=URL.createObjectURL(b);a.download='fam44_review.json';a.click();
 navigator.clipboard.writeText(JSON.stringify(S,null,1));}
</script></body></html>""")
    open(os.path.join(ROOT, ".godot", "unit_review", "fam44_review.html"), "w",
         encoding="utf-8").write("\n".join(h))
    print("wrote fam44_review.html · 批C %d/%d 批A %d/%d 批B %d/%d" % (
        len(c_show), len(c_rows), len(a_show), len(a_rows), len(b_show), len(b_rows)))


if __name__ == "__main__":
    main()
