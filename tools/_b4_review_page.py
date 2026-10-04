# -*- coding: utf-8 -*-
"""B4 审阅页 v2：staging 全量 → review.html。
v2：中文名（unit_manifest_full 同源 dump）+ 问题快标（描线/半身/星战风）+ 重掷勾选 + 重掷清单导出。
标注存 localStorage('b4_regen_marks_v1')；导出 b4_regen_list.json 交回给 agent 重跑。
用法: python tools/_b4_review_page.py
"""
import html as H
import json
import os, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
from PIL import Image
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAGE = os.path.join(ROOT, ".godot", "b4_card_staging")
MANI = os.path.join(ROOT, "_anim_review", "unit_manifest_full.json")

PLAT = ["%s_%s" % (f, t) for f in ("flame_raider", "flame_siege", "steel_fortress", "steel_titan",
                                   "thunter_striker", "thunter_sniper", "void_stealth", "void_mage")
        for t in ("basic", "advanced", "expert")]
TIER_CN = {"basic": "基础", "advanced": "进阶", "expert": "专家"}
REGEN = ["mod_arm_stryker_e", "fut_arm_prism", "ww1_arm_rolls", "ww1_inf_mp18_x", "fe_helix_phantom",
         "mod_inf_scout_drone"]
DERIVE = [  # (staging新文件, 中文名, 说明, 现役旧文件)
    ("vis_player_060.png", "mlrs_e（缴获）", "mlrs_e 缴获侧 ← m270 家族卡", "assets/card_icons/player/vis_player_060.png"),
    ("vis_enemy_060.png", "mlrs_e（敌侧）", "mlrs_e 敌侧 ← 敌 021", "assets/card_icons/enemy/vis_enemy_060.png"),
    ("vis_player_065.png", "fut_air_drone（缴获）", "air_drone 缴获侧 ← attack_drone 卡", "assets/card_icons/player/vis_player_065.png"),
    ("vis_enemy_065.png", "fut_air_drone（敌侧）", "air_drone 敌侧 ← attack_drone 翻转", "assets/card_icons/enemy/vis_enemy_065.png"),
    ("vis_player_061.png", "delta_e（缴获）", "delta_e/ranger 共用 ← ranger sheet f0 上采样", "assets/card_icons/player/vis_player_061.png"),
    ("vis_enemy_061.png", "delta_e（敌侧）", "delta_e 敌侧 ← 同上翻转", "assets/card_icons/enemy/vis_enemy_061.png"),
]
TAGS = ["描线", "半身", "星战风", "其他"]


def load_names():
    names = {}
    try:
        d = json.load(open(MANI, encoding="utf-8"))
        for sec in ("enemies", "players", "captured", "platforms"):
            for row in d.get(sec, []):
                nm = row.get("name") or ""
                if row.get("id") and nm:
                    names[row["id"]] = nm
    except Exception as e:
        print("名字表载入失败:", e)
    return names


def lit_info(path):
    try:
        im = Image.open(path).convert("RGB")
    except Exception:
        return "读取失败"
    a = np.asarray(im).astype(int)
    border = np.concatenate([a[:3].reshape(-1, 3), a[-3:].reshape(-1, 3),
                             a[:, :3].reshape(-1, 3), a[:, -3:].reshape(-1, 3)])
    bg = np.median(border, axis=0)
    dist = np.sqrt(((a - bg) ** 2).sum(axis=2))
    body = dist > 100
    if body.sum() < 4000:
        return "空图?"
    rgb = a[body]
    return "mean=%.0f lit=%.2f" % (float(rgb.mean()), float((rgb.max(axis=1) > 100).mean()))


def img_tag(path, size=240):
    if not os.path.isfile(path):
        return '<div class="miss">缺</div>'
    rel = os.path.relpath(path, STAGE).replace("\\", "/")
    return '<img src="%s" style="max-width:%dpx;max-height:%dpx">' % (rel, size, size)


def controls(cid):
    cb = ('<label class="rg"><input type="checkbox" class="rgbox" data-id="%s" onchange="saveState(\'%s\')">重掷</label>'
          % (cid, cid))
    tags = "".join('<button class="tag" data-id="%s" data-t="%s" onclick="toggleTag(this)">%s</button>'
                   % (cid, t, t) for t in TAGS)
    return '<div class="ctl">%s%s</div>' % (cb, tags)


def card(cid, title_cn, inner, note, sub=""):
    h = '<div class="card" data-cid="%s"><h3>%s <small>%s</small>%s</h3>' % (
        cid, H.escape(title_cn or cid), H.escape(cid),
        ('<div class="sub">%s</div>' % H.escape(sub)) if sub else "")
    h += '<div class="row">%s</div><div class="note">%s</div>%s</div>' % (
        inner, H.escape(note), controls(cid))
    return h


TEMPLATE_HEAD = """<!doctype html><meta charset="utf-8"><title>B4 生图批审阅 v2</title>
<style>
body{background:#15161c;color:#ddd;font-family:Microsoft YaHei,sans-serif;padding:16px}
h2{color:#ffd766;border-bottom:1px solid #333;padding-bottom:6px}
#bar{position:sticky;top:0;background:#15161cee;padding:8px 12px;border:1px solid #34363f;border-radius:8px;margin-bottom:14px;z-index:9}
#bar b{color:#ffd766}
.grid{display:flex;flex-wrap:wrap;gap:14px}
.card{background:#1f2129;border:1px solid #34363f;border-radius:8px;padding:10px;max-width:560px}
.card.rged{outline:2px solid #e64}
.row{display:flex;gap:10px;align-items:flex-end;flex-wrap:wrap}
.note{font-size:12px;color:#9aa;margin-top:6px;max-width:520px}
.sub{font-size:12px;color:#bb9;display:inline;margin-left:8px}
.ctl{margin-top:8px;display:flex;gap:6px;flex-wrap:wrap;align-items:center}
.rg{cursor:pointer;user-select:none}
.tag{background:#2a2c36;border:1px solid #454756;color:#bbc;border-radius:4px;padding:2px 8px;cursor:pointer;font-size:12px}
.tag.on{background:#7a4a2a;border-color:#c86;color:#ffd7aa}
.miss{width:120px;height:120px;border:1px dashed #644;display:flex;align-items:center;justify-content:center;color:#a66}
img{background:#fff;border-radius:4px}
.dark1{outline:2px solid #a33}
</style>
<div id="bar">重掷清单：<b id="cnt">0</b> 张
 <button onclick="exportList()">导出 b4_regen_list.json</button>
 <button onclick="if(confirm('清空全部标记?')){localStorage.removeItem(LSK);restore();}">清空</button>
 <span style="color:#89a;font-size:12px">（点「描线/半身/星战风/其他」即标记问题并自动勾选重掷；导出的 JSON 交回给 Claude 重跑）</span>
</div>
<script>
const LSK='b4_regen_marks_v1';
let state={};try{state=JSON.parse(localStorage.getItem(LSK)||'{}');}catch(e){state={};}
function saveState(cid){const box=document.querySelector('.rgbox[data-id="'+cid+'"]');
  if(!state[cid])state[cid]={rg:false,tags:[]};state[cid].rg=box&&box.checked;persist();paint(cid);}
function toggleTag(btn){const cid=btn.dataset.id,t=btn.dataset.t;
  if(!state[cid])state[cid]={rg:false,tags:[]};
  const arr=state[cid].tags;const i=arr.indexOf(t);
  if(i>=0)arr.splice(i,1);else arr.push(t);
  state[cid].rg=arr.length>0||(state[cid].rg&&!!document.querySelector('.rgbox[data-id="'+cid+'"]:checked'));
  persist();paint(cid);}
function persist(){try{localStorage.setItem(LSK,JSON.stringify(state));}catch(e){}refreshBar();}
function paint(cid){const card=document.querySelector('.card[data-cid="'+cid+'"]');if(!card)return;
  const st=state[cid]||{rg:false,tags:[]};
  card.classList.toggle('rged',!!st.rg);
  const box=card.querySelector('.rgbox');if(box)box.checked=!!st.rg;
  card.querySelectorAll('.tag').forEach(b=>b.classList.toggle('on',(st.tags||[]).indexOf(b.dataset.t)>=0));}
function refreshBar(){let n=0;Object.values(state).forEach(s=>{if(s.rg)n++;});
  document.getElementById('cnt').textContent=n;}
function exportList(){const out={exported:new Date().toLocaleString(),regen:[]};
  for(const k in state)if(state[k].rg)out.regen.push({id:k,tags:state[k].tags||[]});
  if(!out.regen.length){alert('还没勾任何重掷');return;}
  const a=document.createElement('a');
  a.href=URL.createObjectURL(new Blob([JSON.stringify(out,null,1)],{type:'application/json'}));
  a.download='b4_regen_list.json';a.click();}
function restore(){document.querySelectorAll('.card').forEach(c=>paint(c.dataset.cid));refreshBar();}
</script>
"""


def main():
    names = load_names()
    parts = [TEMPLATE_HEAD]
    # plat
    parts.append("<h2>平台 24（文生图）</h2><div class='grid'>")
    for pid in PLAT:
        raw = os.path.join(STAGE, "%s_raw.png" % pid)
        d1 = os.path.join(STAGE, "%s_raw_dark1.png" % pid)
        prev = os.path.join(STAGE, "%s_raw_prev.png" % pid)
        inner = img_tag(raw)
        if os.path.isfile(prev):
            inner += '<div style="text-align:center;color:#997">旧</div>' + img_tag(prev, 110)
        if os.path.isfile(d1):
            inner += '<div class="dark1">' + img_tag(d1, 110) + "</div>"
        cn = names.get(pid, "")
        sub = "亮门: %s" % (lit_info(raw) if os.path.isfile(raw) else "未生成")
        parts.append(card(pid, cn, inner, "", sub))
    parts.append("</div>")
    # regen
    parts.append("<h2>参考重绘（img2img）</h2><div class='grid'>")
    for cid in REGEN:
        raw = os.path.join(STAGE, "%s_raw.png" % cid)
        prev = os.path.join(STAGE, "%s_raw_prev.png" % cid)
        inner = img_tag(raw)
        if os.path.isfile(prev):
            inner += '<div style="text-align:center;color:#997">旧</div>' + img_tag(prev, 110)
        cn = names.get(cid, "")
        sub = "亮门: %s" % (lit_info(raw) if os.path.isfile(raw) else "未生成")
        parts.append(card(cid, cn, inner, "", sub))
    parts.append("</div>")
    # derive
    parts.append("<h2>派生制卡（左=staging 新图，右=现役旧图；确定性拷贝，一般无需重掷）</h2><div class='grid'>")
    for f, cn, note, old in DERIVE:
        cid = f[:-len(".png")]
        inner = img_tag(os.path.join(STAGE, f)) + "<div style='color:#777'>→</div>" + \
                img_tag(os.path.join(ROOT, old))
        prev = os.path.join(STAGE, f.replace(".png", "_prev.png"))
        if cid in ("vis_player_061", "vis_enemy_061") and os.path.isfile(prev):
            inner += '<div style="text-align:center;color:#997">旧</div>' + img_tag(prev, 110)
        parts.append(card(cid, cn, inner, note))
    parts.append("</div>")
    out = os.path.join(STAGE, "review.html")
    open(out, "w", encoding="utf-8").write("".join(parts))
    print("审阅页 →", out, "名字表 %d 条" % len(names))


if __name__ == "__main__":
    main()
