#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""img25 三方式决策台生成器（本地静态 HTML，file:// 直接打开）。

每单位一行：原卡图 | 方式1 生图批产(终版/R1-R3 可切换) | 方式2 special10 | 方式3 codeanim
点选采用哪种方式 + 重掷方式下拉 + 特殊指定备注。
决定存 localStorage，可导出/导入 .godot/unit_review/img25_route_decisions.json。

用法：
    python -X utf8 tools/img25_decision_console.py          # 生成 .godot/unit_review/img25_决策台.html
    python -X utf8 tools/img25_decision_console.py --open   # 生成后用默认浏览器打开
"""
import datetime
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UR = os.path.join(ROOT, ".godot", "unit_review")
DOC = os.path.join(ROOT, "docs", "img25_重做清单_20260929.md")
OUT = os.path.join(UR, "img25_决策台.html")
ANIM = os.path.join(ROOT, "assets", "effects", "unit_anims")
PREV = os.path.join(UR, "img25_console_prev")


def deployed_attack(key):
    """三路产物皆无时的兜底口径：现役部署攻击帧（原库资产，早于 img25 批）。
    返回 (预览相对路径, 帧数)；无攻击帧/attack=idle 借位返回 ("", 0)。"""
    sh_p = os.path.join(ANIM, key, "sheet_attack.png")
    aj_p = os.path.join(ANIM, key, "anim.json")
    if not os.path.isfile(sh_p):
        return "", 0
    try:
        aj = json.load(open(aj_p, encoding="utf-8"))
        n = (aj.get("counts") or {}).get("attack", 0)
    except Exception:
        return "", 0
    if not n:
        return "", 0
    from PIL import Image
    os.makedirs(PREV, exist_ok=True)
    im = Image.open(sh_p).convert("RGBA")
    fw = 256
    picks = [f for f in (0, 1, 3) if f < max(1, im.width // fw)]
    strip = Image.new("RGBA", (fw * len(picks) + 4 * (len(picks) - 1), fw), (40, 40, 44, 255))
    for i, f in enumerate(picks):
        strip.alpha_composite(im.crop((f * fw, 0, (f + 1) * fw, fw)), (i * (fw + 4), 0))
    name = f"{key}_dep.png"
    strip.convert("RGB").save(os.path.join(PREV, name))
    return f"img25_console_prev/{name}", n


def parse_doc():
    """从重做清单解析 88 单位底表。"""
    txt = open(DOC, encoding="utf-8").read()
    units = []
    pat = re.compile(r"^\| (\d+) \| ([a-z0-9_]+) \| ([^|]+) \| ([^|]+) \| ([^|]+) \| ([^|]+) \|", re.M)
    for m in pat.finditer(txt):
        idx, key, channel, weapon, card, _src = [g.strip() for g in m.groups()]
        units.append(dict(idx=int(idx), key=key, channel=channel, weapon=weapon, card=card))
    return units


def load_json(path):
    try:
        return json.load(open(path, encoding="utf-8"))
    except Exception:
        return None


def exists(rel):
    return os.path.isfile(os.path.join(UR, rel))


def main():
    units = parse_doc()

    # ---- 台账来源 ----
    manifest = load_json(os.path.join(UR, "img25_approved", "_manifest.json")) or []
    approved = set(manifest)
    besteffort = load_json(os.path.join(UR, "img25_staging", "_finalize_besteffort.json")) or {}
    reroll = set(besteffort)
    decisions = load_json(os.path.join(UR, "img25_staging", "_finalize_decisions.json")) or {}
    round2 = load_json(os.path.join(UR, "img25_staging", "_finalize_round2.json")) or {}
    round3 = load_json(os.path.join(UR, "img25_staging", "_finalize_round3.json")) or {}
    roll_of = {}
    for d in (decisions, round2, round3):
        for k, v in d.items():
            roll_of[k] = v.get("roll", roll_of.get(k, ""))

    # ---- 10-02 黑剪影换装批：这批单位的 route3 终产物 = codeanim 新 GIF，
    #      方式1 里的"终版/R3"是黑锚时代的旧掷，只能当对照，不许占行首
    swapped = set(load_json(os.path.join(UR, "codeanim_configs",
                                         "_configs_swapped_20261002.json")) or {})
    swapped.add("guardian_ww2_blitzkrieg")

    # ---- 每单位产物盘点 ----
    n1 = n2 = n3 = 0
    rows = []
    for u in units:
        key, card = u["key"], u["card"]
        # 原卡图（相对 .godot/unit_review/）
        card_url = "../../assets/card_icons/" + card

        # 方式1：批产终版 + R1-R3 掷
        variants = []  # (label, url)
        if exists(f"img25_approved/{key}_attack_anim.gif"):
            variants.append(("终版", f"img25_approved/{key}_attack_anim.gif"))
        elif exists(f"img25_approved/{key}_attack_FINAL.gif"):
            variants.append(("终版", f"img25_approved/{key}_attack_FINAL.gif"))
        rolls = [r for r in ("R1", "R2", "R3") if exists(f"img25_staging/{key}_{r}_attack_anim.gif")]
        if rolls:
            pref = roll_of.get(key)
            ordered = ([pref] if pref in rolls else []) + [r for r in rolls if r != pref]
            variants += [(r, f"img25_staging/{key}_{r}_attack_anim.gif") for r in ordered]
        sheet1 = f"img25_approved/{key}_attack_sheet_832.png" if exists(
            f"img25_approved/{key}_attack_sheet_832.png") else (
            f"img25_approved/{key}_attack_FINAL_cells.png" if exists(
                f"img25_approved/{key}_attack_FINAL_cells.png") else (
                    f"img25_staging/{key}_{rolls[0]}_attack_sheet_832.png" if rolls else ""))
        has1 = bool(variants)

        # 方式2：special10
        has2 = exists(f"img25_staging/_special10/{key}_attack_anim.gif")
        url2 = f"img25_staging/_special10/{key}_attack_anim.gif" if has2 else ""
        sheet2 = f"img25_staging/_special10/{key}_attack_sheet_832.png" if exists(
            f"img25_staging/_special10/{key}_attack_sheet_832.png") else ""
        cmp2 = f"img25_staging/_special10/{key}_cmp_identity.png" if exists(
            f"img25_staging/_special10/{key}_cmp_identity.png") else ""

        # 方式3：codeanim（19 批产 + 1 PoC）
        if exists(f"codeanim/{key}_codeanim_anim.gif"):
            url3, sheet3 = f"codeanim/{key}_codeanim_anim.gif", f"codeanim/{key}_codeanim_sheet.png"
        elif exists(f"codeanim/{key}_codepoc_anim.gif"):
            url3, sheet3 = f"codeanim/{key}_codepoc_anim.gif", f"codeanim/{key}_codepoc_sheet.png"
        else:
            url3 = sheet3 = ""
        has3 = bool(url3)

        n1 += has1
        n2 += has2
        n3 += has3

        # 兜底：无三路产物但有现役部署攻击帧（原库资产）——不再亮"未生成"
        dep_url, dep_n = ("", 0)
        if not (has1 or has2 or has3):
            dep_url, dep_n = deployed_attack(key)
        has_dep = bool(dep_url)

        # 状态章
        chips = []
        if key in approved:
            chips.append(("已转正", "ok"))
        if key in reroll:
            chips.append(("挂起重掷", "warn"))
        if has2:
            chips.append(("special10", "sp"))
        if has3:
            chips.append(("codeanim", "ca"))
        if not (has1 or has2 or has3):
            chips.append((f"现役攻击帧×{dep_n}", "dep") if has_dep else ("未生成", "na"))

        rows.append(dict(u=u, card_url=card_url, variants=variants, sheet1=sheet1,
                         has1=has1, has2=has2, has3=has3, url2=url2, sheet2=sheet2,
                         cmp2=cmp2, url3=url3, sheet3=sheet3, chips=chips,
                         dep_url=dep_url, dep_n=dep_n, has_dep=has_dep))

    # ---- 10-02 换装批行首矫正 + 缓存穿透（file:// 同路径覆盖旧图，浏览器会吃缓存）----
    def cb(u):
        return f"{u}?v=1002c" if u else u

    for r in rows:
        key = r["u"]["key"]
        if key in swapped and r["url3"]:
            r["variants"].insert(0, ("10-02新锚(部署即此)", r["url3"]))
            r["chips"].insert(0, ("10-02换装", "ca"))
        r["variants"] = [(lbl, cb(url)) for lbl, url in r["variants"]]
        r["card_url"] = cb(r["card_url"])
        for f in ("sheet1", "url2", "sheet2", "cmp2", "url3", "sheet3", "dep_url"):
            r[f] = cb(r[f])

    # ---- HTML 拼装 ----
    def esc(s):
        return (s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                 .replace('"', "&quot;"))

    parts = []
    for r in rows:
        u, key = r["u"], r["u"]["key"]
        tags = " ".join(c[0] for c in r["chips"])
        chip_html = "".join(f'<span class="chip {c[1]}">{c[0]}</span>' for c in r["chips"])

        # 方式1 cell（多掷切换）
        if r["has1"]:
            vs = r["variants"]
            btns = "".join(
                f'<button class="tab{" on" if i == 0 else ""}" data-img="i1_{key}" '
                f'data-src="{esc(url)}">{lbl}</button>' for i, (lbl, url) in enumerate(vs))
            sheet_link = (f'<a href="{esc(r["sheet1"])}" target="_blank">832静帧</a>'
                          if r["sheet1"] else "")
            c1 = (f'<div class="cell"><div class="tabs">{btns}</div>'
                  f'<a href="{esc(vs[0][1])}" target="_blank">'
                  f'<img id="i1_{key}" loading="lazy" src="{esc(vs[0][1])}"></a>'
                  f'<div class="sub">{len(vs)}掷可用 {sheet_link}</div>'
                  f'<label class="pick"><input type="radio" name="sel_{key}" value="route1">用方式1</label></div>')
        elif r["has_dep"]:
            c1 = (f'<div class="cell"><div class="tabs"><span class="tag">现役部署（早于 img25 批的原库资产）</span></div>'
                  f'<img loading="lazy" src="{esc(r["dep_url"])}">'
                  f'<div class="sub">部署表 {r["dep_n"]} 帧·sheet_attack.png</div>'
                  f'<label class="pick off"><input type="radio" name="sel_{key}" value="route1" disabled>用方式1</label></div>')
        else:
            c1 = ('<div class="cell na">—<div class="sub">无产物</div>'
                  '<label class="pick off"><input type="radio" name="sel_%s" value="route1" disabled>用方式1</label></div>' % key)

        # 方式2 cell
        if r["has2"]:
            cmp_link = (f' <a href="{esc(r["cmp2"])}" target="_blank">身份对比</a>' if r["cmp2"] else "")
            sheet_link = (f' <a href="{esc(r["sheet2"])}" target="_blank">832静帧</a>' if r["sheet2"] else "")
            c2 = (f'<div class="cell"><div class="tabs"><span class="tag">指定掷精修</span></div>'
                  f'<a href="{esc(r["url2"])}" target="_blank">'
                  f'<img loading="lazy" src="{esc(r["url2"])}"></a>'
                  f'<div class="sub">special10{cmp_link}{sheet_link}</div>'
                  f'<label class="pick"><input type="radio" name="sel_{key}" value="route2">用方式2</label></div>')
        else:
            c2 = ('<div class="cell na">—<div class="sub">无产物</div>'
                  '<label class="pick off"><input type="radio" name="sel_%s" value="route2" disabled>用方式2</label></div>' % key)

        # 方式3 cell
        if r["has3"]:
            sheet_link = (f' <a href="{esc(r["sheet3"])}" target="_blank">静帧</a>' if r["sheet3"] else "")
            c3 = (f'<div class="cell"><div class="tabs"><span class="tag">代码驱动</span></div>'
                  f'<a href="{esc(r["url3"])}" target="_blank">'
                  f'<img loading="lazy" src="{esc(r["url3"])}"></a>'
                  f'<div class="sub">codeanim{sheet_link}</div>'
                  f'<label class="pick"><input type="radio" name="sel_{key}" value="route3">用方式3</label></div>')
        else:
            c3 = ('<div class="cell na">—<div class="sub">无产物</div>'
                  '<label class="pick off"><input type="radio" name="sel_%s" value="route3" disabled>用方式3</label></div>' % key)

        parts.append(f'''<div class="u" data-key="{key}" data-tags="{esc(tags)}" data-r1="{int(r['has1'])}" data-r2="{int(r['has2'])}" data-r3="{int(r['has3'])}" data-dep="{int(r['has_dep'])}">
  <div class="head"><span class="idx">#{u["idx"]:02d}</span><span class="k">{key}</span>{chip_html}
    <span class="meta">{esc(u["channel"])}·{esc(u["weapon"])}·{esc(u["card"])}</span></div>
  <div class="grid">
    <div class="cell card"><a href="{esc(r["card_url"])}" target="_blank"><img loading="lazy" src="{esc(r["card_url"])}"></a><div class="sub">原卡图</div></div>
    {c1}{c2}{c3}
    <div class="cell decide">
      <div class="drow">重掷方式
        <select id="rr_{key}"><option value="">（不重掷）</option>
          <option value="1">方式1 生图3掷</option><option value="2">方式2 指定掷精修</option>
          <option value="3">方式3 代码驱动</option></select></div>
      <textarea id="nt_{key}" placeholder="特殊指定：组成/配色/朝向/抬枪/开火位置…（三种都不满意时填）"></textarea>
    </div>
  </div>
</div>''')

    total = len(units)
    html_doc = '''<!DOCTYPE html>
<html lang="zh"><head><meta charset="utf-8">
<title>img25 三方式决策台</title>
<style>
:root{color-scheme:dark}
*{box-sizing:border-box}
body{margin:0;background:#141416;color:#ddd;font:14px/1.5 system-ui,"Microsoft YaHei",sans-serif}
header{position:sticky;top:0;z-index:9;background:#1b1b1f;padding:10px 16px;border-bottom:1px solid #2c2c31}
header h1{font-size:16px;margin:0 0 6px}
.bar{display:flex;gap:8px;flex-wrap:wrap;align-items:center}
.bar button,.bar select{background:#2a2a30;color:#ddd;border:1px solid #3c3c44;border-radius:6px;padding:4px 10px;cursor:pointer}
.bar button:hover{background:#3a3a42}
.bar .cnt{color:#8aa;font-size:12px}
.fbtn.on{background:#3d6ea5;border-color:#5a8cc4}
#q{background:#222;color:#ddd;border:1px solid #3c3c44;border-radius:6px;padding:4px 8px;width:180px}
.u{margin:10px 16px;background:#1b1b1f;border:1px solid #2c2c31;border-radius:10px;padding:8px 10px}
.head{display:flex;gap:8px;align-items:center;flex-wrap:wrap;margin-bottom:6px}
.idx{color:#667;font-size:12px}
.k{font-weight:700;color:#eee}
.chip{font-size:11px;padding:1px 7px;border-radius:9px;border:1px solid}
.chip.ok{color:#7c7;border-color:#4a4}
.chip.warn{color:#f96;border-color:#c73}
.chip.sp{color:#6bf;border-color:#48a}
.chip.ca{color:#c9f;border-color:#75a}
.chip.na{color:#999;border-color:#555}
.chip.dep{color:#7cc;border-color:#3a7}
.meta{color:#778;font-size:12px;margin-left:auto}
.grid{display:grid;grid-template-columns:110px repeat(3,minmax(300px,1fr)) 250px;gap:10px;align-items:start}
@media(max-width:1200px){.grid{grid-template-columns:1fr 1fr}}
.cell{background:#222226;border-radius:8px;padding:6px;min-width:0}
.cell img{width:100%;max-width:340px;display:block;background:#18181b;border-radius:4px;cursor:zoom-in}
.cell.na{color:#555;text-align:center;padding:24px 6px}
.cell.card img{max-width:100px}
.tabs{display:flex;gap:4px;margin-bottom:4px;flex-wrap:wrap}
.tab{background:#2a2a30;color:#bbb;border:1px solid #3c3c44;border-radius:5px;padding:1px 8px;cursor:pointer;font-size:12px}
.tab.on{background:#3d6ea5;color:#fff;border-color:#5a8cc4}
.tag{font-size:11px;color:#99a}
.sub{font-size:11px;color:#778;margin:3px 0}
.sub a{color:#6ae}
.pick{display:block;margin-top:4px;font-size:13px;cursor:pointer}
.pick.off{color:#555;cursor:not-allowed}
.decide{display:flex;flex-direction:column;gap:6px}
.drow{font-size:13px}
.decide select{background:#2a2a30;color:#ddd;border:1px solid #3c3c44;border-radius:6px;padding:3px 6px}
.decide textarea{width:100%;min-height:64px;background:#18181b;color:#ddd;border:1px solid #3c3c44;border-radius:6px;padding:6px;font:12px/1.5 inherit;resize:vertical}
footer{padding:14px 16px;color:#667;font-size:12px}
</style></head><body>
<header><h1>img25 三方式决策台 — 88 单位（方式1 生图3掷 · 方式2 指定掷精修 · 方式3 代码驱动）</h1>
<div class="bar">
  <span class="cnt" id="stats"></span>
  <button class="fbtn on" data-f="all">全部</button>
  <button class="fbtn" data-f="r1">有方式1</button>
  <button class="fbtn" data-f="r2">有方式2</button>
  <button class="fbtn" data-f="r3">有方式3</button>
  <button class="fbtn" data-f="none">未生成</button>
  <button class="fbtn" data-f="picked">已点选</button>
  <input id="q" placeholder="搜索单位 key…">
  <span style="flex:1"></span>
  <button id="exp">导出决定 JSON</button>
  <button id="cpy">复制 JSON</button>
  <label class="bar" style="cursor:pointer"><input type="file" id="imp" accept=".json" hidden>导入 JSON</label>
</div></header>
__ROWS__
<footer>决定自动存浏览器 localStorage（本机本浏览器）；「导出」= 下载 img25_route_decisions.json 到浏览器下载目录并同步复制到剪贴板，
把文件挪进 .godot/unit_review/ 或直接把 JSON 发回会话即可交给管线消费。
图片点击新标签放大；832静帧/身份对比为目检辅助链接。</footer>
<script>
const KEY='img25_route_decisions_v1';
let S={};try{S=JSON.parse(localStorage.getItem(KEY)||'{}')}catch(e){}
const $=s=>document.querySelectorAll(s), $$=s=>document.querySelector(s);
function save(){localStorage.setItem(KEY,JSON.stringify(S));stats()}
function bind(){
 $('input[type=radio]').forEach(r=>r.addEventListener('change',()=>{if(r.checked){(S[r.name.slice(4)]??={});S[r.name.slice(4)].sel=r.value;save()}}));
 $('select[id^=rr_]').forEach(s=>s.addEventListener('change',()=>{(S[s.id.slice(3)]??={}).reroll=s.value;save()}));
 $('textarea[id^=nt_]').forEach(t=>{let d;t.addEventListener('input',()=>{clearTimeout(d);d=setTimeout(()=>{(S[t.id.slice(3)]??={}).note=t.value;save()},300)})});
}
function fill(){for(const[k,v]of Object.entries(S)){
 if(v.sel){const r=document.querySelector(`input[name=sel_${k}][value=${v.sel}]`);if(r)r.checked=true;}
 const s=$$('#rr_'+k);if(s&&v.reroll)s.value=v.reroll;
 const t=$$('#nt_'+k);if(t&&v.note)t.value=v.note;}}
function stats(){let p=0;$('.u').forEach(u=>{if(S[u.dataset.key]&&(S[u.dataset.key].sel||S[u.dataset.key].reroll||S[u.dataset.key].note))p++});
 $$('#stats').textContent=`88 单位 | 方式1 ${__N1__} | 方式2 ${__N2__} | 方式3 ${__N3__} | 已表态 ${p}`;}
/* 方式1 掷次切换 */
document.addEventListener('click',e=>{const b=e.target.closest('.tab');if(!b)return;
 const img=$$('#'+b.dataset.img);if(img)img.src=b.dataset.src;
 b.parentElement.querySelectorAll('.tab').forEach(x=>x.classList.toggle('on',x===b));});
/* 筛选 */
let F='all';
function filt(){const q=$$('#q').value.trim().toLowerCase();
 $('.u').forEach(u=>{const k=u.dataset.key,r=[u.dataset.r1==='1',u.dataset.r2==='1',u.dataset.r3==='1'];
  let ok=F==='all'||(F==='r1'&&r[0])||(F==='r2'&&r[1])||(F==='r3'&&r[2])||(F==='none'&&!r[0]&&!r[1]&&!r[2]&&u.dataset.dep!=='1')||(F==='picked'&&S[k]&&(S[k].sel||S[k].reroll||S[k].note));
  if(q)ok=ok&&k.includes(q);u.style.display=ok?'':'none';});}
$('.fbtn').forEach(b=>b.addEventListener('click',()=>{F=b.dataset.f;$('.fbtn').forEach(x=>x.classList.toggle('on',x===b));filt();}));
$$('#q').addEventListener('input',filt);
/* 导出/导入/复制 */
function blob(){return new Blob([JSON.stringify(S,null,2)],{type:'application/json'})}
$$('#exp').addEventListener('click',async()=>{const s=JSON.stringify(S,null,2);
 const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([s],{type:'application/json'}));
 a.download='img25_route_decisions.json';a.click();
 let ok='';try{await navigator.clipboard.writeText(s);ok='+剪贴板'}catch(e){}
 const b=$$('#exp');b.textContent='已导出✓（下载目录'+ok+'）';setTimeout(()=>b.textContent='导出决定 JSON',3000);});
$$('#cpy').addEventListener('click',async()=>{try{await navigator.clipboard.writeText(JSON.stringify(S,null,2));
 $$('#cpy').textContent='已复制✓';setTimeout(()=>$$('#cpy').textContent='复制 JSON',1200);}catch(e){alert('复制失败，请用导出')}});
$$('#imp').addEventListener('change',e=>{const f=e.target.files[0];if(!f)return;const rd=new FileReader();
 rd.onload=()=>{try{S=JSON.parse(rd.result);localStorage.setItem(KEY,JSON.stringify(S));location.reload()}catch(x){alert('JSON 解析失败')}};rd.readAsText(f);});
bind();fill();stats();
</script></body></html>'''
    html_doc = html_doc.replace("__ROWS__", "\n".join(parts))
    html_doc = html_doc.replace("__N1__", str(n1)).replace("__N2__", str(n2)).replace("__N3__", str(n3))

    os.makedirs(UR, exist_ok=True)
    open(OUT, "w", encoding="utf-8").write(html_doc)
    print(f"units={total} route1={n1} route2={n2} route3={n3}")
    print("OK ->", OUT)
    return OUT


if __name__ == "__main__":
    p = main()
    if "--open" in __import__("sys").argv:
        os.startfile(p)
