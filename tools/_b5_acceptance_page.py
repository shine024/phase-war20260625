# -*- coding: utf-8 -*-
"""B5 验收台生成（2026-10-04）：staging 出 b5_验收台.html。
三段：WaveA 现役已修四案（备份 vs 现役并排）/ stalker 修复 / WaveB 十三案+105mm 候选（radio 拍板导出）。
产物只落 .godot/unit_review/img25_staging/。用法: python tools/_b5_acceptance_page.py
"""
import glob
import io
import json
import os
import sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
UA = os.path.join(ROOT, "assets", "effects", "unit_anims")
PROBE = os.path.join(ROOT, ".godot", "unit_review", "b5_probe")

WAVEA = [
    ("ww2_fort_bunker", "待机去灯（青蓝信标+吊杆摘除）", "sheet_idle.png", ".godot/art_backup_b5_waveA_20261004"),
    ("mod_inf_marine", "待机去地渍（脚底灰白拖抹摘除）", "sheet_idle.png", ".godot/art_backup_b5_waveA_20261004"),
    ("cold_spetsnaz", "待机摆幅过大→f基微呼吸环", "sheet_idle.png", ".godot/art_backup_b5_waveA_20261004"),
    ("mod_apache_e", "待机摆幅过大→f基微呼吸环", "sheet_idle.png", ".godot/art_backup_b5_waveA_20261004"),
]

WAVEB = [
    ("cold_inf_m60", "idle 重出", 0),
    ("fut_arm_mech_e", "idle 重出", 0),
    ("ww1_sup_mg_nest", "idle 重出", 0),
    ("ww2_sup_mg42", "idle+攻击重出", 2),
    ("ww2_boss_kingtiger", "idle+攻击重出（部署落 ww2_kingtiger 目录）", 3),
    ("ww2_air_bomber", "攻击重出（投弹）", 3),
    ("ww1_arty_mortar", "攻击重出（曲射）", 2),
    ("ww1_a7v", "攻击重出（侧射）", 2),
    ("ww1_lanchest", "攻击重出（炮塔机枪）", 2),
    ("ww1_mark4", "idle+攻击重出（艏炮）", 3),
    ("mod_arm_m1a2sep", "idle+攻击重出（主炮）", 3),
    ("mod_air_technical_e", "攻击重出（机枪扫射）", 2),
    ("ww1_arty_77mm", "idle+攻击重出（野炮齐射）", 3),
]

# 2026-10-04 拍板 JSON v3 已回：预选 radio（localStorage 优先于种子）
SEED_DECISIONS = {
    "cold_inf_m60": "弃",
    "fut_arm_mech_e": "idle",
    "ww1_sup_mg_nest": "idle",
    "ww2_sup_mg42": "ww2_sup_mg42_SF",
    "ww2_boss_kingtiger": "ww2_boss_kingtiger_SF",
    "ww2_air_bomber": "ww2_air_bomber_R2",
    "ww1_arty_mortar": "ww1_arty_mortar_SF",
    "ww1_a7v": "ww1_a7v_SF",
    "ww1_lanchest": "ww1_lanchest_SF",
    "ww1_mark4": "ww1_mark4_SF",
    "mod_arm_m1a2sep": "mod_arm_m1a2sep_SF",
    "mod_air_technical_e": "mod_air_technical_e_SF",
    "ww1_arty_77mm": "ww1_arty_77mm_SF",
    "ww1_105mm": "ww1_105mm_SF",
}

# 目验标注（会写进各案标题下的提示行）
FLAGS = {
    "cold_inf_m60": "【已拍板 v3：弃（维持现状）】R2 攻击卷不再采用（文件留档）；R1/R3 早前已入备份。",
    "fut_arm_mech_e": "待机卷未逐格目验（洗涤量小，锚定 pass）。【已拍板 2026-10-04】idle 采纳。",
    "ww1_sup_mg_nest": "【已拍板 v3：idle 采纳＋备注「抠阴影」已做】三脚架间半透明灰影清除 52056px，腿完好，派生已重建（备份 _b5_backup_shadow_20261004/）。",
    "ww2_sup_mg42": "【已拍板 v3：SF 采纳（v2 弃 → v3 改回）】f2 曾半身截断→f2←f4 副本（fix3），全卷 RGBA 透明。",
    "ww2_boss_kingtiger": "【已拍板 v3：SF 采纳（v2 弃 → v3 改回）】部署时落 ww2_kingtiger 目录（ANIM_ALIAS）。",
    "ww2_air_bomber": "【已拍板 v3：R2 采纳（v2 弃 → v3 改回）】机腹灰块=用户手抠模板映射回源表（Desktop RGBA 版 0 偏差对位，50531px 清除，六格目验过）——自动谓词两轮均否（首轮吃出豁口/次轮不适用），手抠为准。SF 卷已移备份（deletes2）。",
    "ww1_arty_mortar": "【已拍板 SF（v3 维持）】火光截断已修（fix3 重掷 f2-f5，无炮弹无影）。R2 卷已按 deletes 移备份。",
    "ww1_a7v": "【已拍板 v3：SF 采纳】VID 12 帧卷已按 deletes 移备份（_b5_backup_deletes3_20261004/）——v2 的采纳/删除矛盾就此解决。",
    "ww1_lanchest": "SF 卷 6/6 朝左正侧视、抠图净。【已拍板 SF（v3 维持）】跨帧暖色漂移仍在——知情采纳。R3 卷已按 deletes 移备份。",
    "ww1_mark4": "【已拍板 SF（v3 维持）】v3 备注「1，6帧 转方向」系旧备注重导出——fix3 已将 f1/f6 原位镜像，现 6/6 朝左一致（已核实），无需再动。",
    "mod_arm_m1a2sep": "SF 卷 6/6 朝左正侧视、身份稳。【已拍板 SF（v3 维持）】表已转 RGBA（fix3）。",
    "mod_air_technical_e": "SF 卷 6/6 车头朝左、枪口左伸。【已拍板 SF（v3 维持）】已知偏差：皮卡 2 轴（卡图 3 轴）。",
    "ww1_arty_77mm": "【已拍板 SF（v3 维持）】攻击卷 fix4 重掷 f2（针尖微光）+f3（白热星芒）+边缘净化（fringe 1495px）。【待机卷】用户重抠 anchor_raw（底透化+灰影手删）后按 build_idle 配方从净版 anchor 重建 8 帧微呼吸（tools/_b5_77idle_rebuild.py，跳过键控防黑底键黑；depink+主体保留补刀）——轮底灰影已除。",
    "ww1_105mm": "【已拍板 SF（v3 维持）】fix4 重掷 f2（针尖微光）+f3（白热焰心放射星芒）；f4 硝烟帧已修（fix3）+鱼腹带。",
}


def sheet_grid(path, fs=256, cell=256):
    """横条雪碧图 → 深底网格 PNG（probe 落盘），返回文件名。"""
    im = Image.open(path).convert("RGBA")
    n = im.width // fs
    cols = min(n, 8)
    rows = (n + cols - 1) // cols
    g = Image.new("RGB", (cols * cell, rows * cell), (40, 44, 52))
    for i in range(n):
        fr = im.crop((i * fs, 0, (i + 1) * fs, fs))
        if cell != fs:
            fr = fr.resize((cell, cell), Image.LANCZOS)
        g.paste(fr, (i % cols * cell, i // cols * cell), fr)
    name = "BA_%s_%s" % (os.path.basename(os.path.dirname(path)), os.path.basename(path).replace(".png", "_grid.png"))
    g.save(os.path.join(PROBE, name))
    return name


def wavea_pairs():
    """备份 vs 现役 并排图。"""
    items = []
    for dirname, desc, sheet, bkdir in WAVEA:
        bak = os.path.join(ROOT, bkdir, "assets/effects/unit_anims", dirname, sheet)
        cur = os.path.join(UA, dirname, sheet)
        bak_grid = sheet_grid(bak) if os.path.isfile(bak) else None
        cur_grid = sheet_grid(cur)
        items.append((dirname, desc, bak_grid, cur_grid))
    # stalker 攻击表
    bak = os.path.join(ROOT, ".godot", "art_backup_b5_stalker_20261004", "sheet_attack.png")
    cur = os.path.join(UA, "vis_xeno_stalker", "sheet_attack.png")
    items.append(("vis_xeno_stalker", "攻击 f2-f5 裁切坏帧→全身扑击序列（fs=256 半宽显示）",
                  sheet_grid(bak, fs=256, cell=170) if os.path.isfile(bak) else None,
                  sheet_grid(cur, fs=256, cell=170)))
    return items


def main():
    pairs = wavea_pairs()
    css = ("body{background:#181b21;color:#d8dce4;font:14px/1.5 'Segoe UI',sans-serif;margin:0;padding:16px}"
           "h1{font-size:20px}h2{font-size:17px;border-bottom:1px solid #3a4048;padding-bottom:6px;margin-top:28px}"
           "h3{font-size:15px;margin:18px 0 6px}"
           ".case{background:#20242c;border:1px solid #333945;border-radius:8px;padding:12px;margin:10px 0}"
           ".row{display:flex;gap:12px;flex-wrap:wrap;align-items:flex-start}"
           ".col{flex:1;min-width:280px}.col img{width:100%;image-rendering:auto;border-radius:4px;background:#282c34}"
           ".cap{color:#9aa3af;font-size:12px;margin:2px 0 8px}"
           ".tag{display:inline-block;background:#2d3a4d;color:#8fc1ff;border-radius:4px;padding:1px 8px;font-size:12px;margin-left:6px}"
           "label.opt{margin-right:14px;cursor:pointer;white-space:nowrap}"
           "button{background:#2d5aa8;color:#fff;border:0;border-radius:6px;padding:8px 18px;font-size:14px;cursor:pointer}"
           "button.del{background:#7a3b3b;padding:1px 8px;font-size:11px;margin-left:8px;vertical-align:middle}"
           "input.note{width:100%;box-sizing:border-box;background:#1b1f26;color:#d8dce4;border:1px solid #3a4048;"
           "border-radius:4px;padding:4px 8px;margin-top:8px;font-size:13px}"
           ".col.deleted{opacity:.15}.col.deleted img{filter:grayscale(1)}"
           ".gif img{background:#282c34;max-width:100%}")
    h = ["<!doctype html><html><head><meta charset='utf-8'><title>B5 验收台</title><style>%s</style></head><body>" % css]
    h.append("<h1>B5 动画遗留批 验收台 <span class='tag'>2026-10-04</span></h1>")
    h.append("<p class='cap'>WaveA/曾修案已直接落 assets（有备份可回滚）；WaveB 十三案+105mm 为 staging 候选，拍板后再部署。品红残底已统一洗涤。"
             "VID=视频关键帧路线重出卷（agnes-video-2.5-flash keyframe，卡图白底 ref 锁身份，12帧512表）。"
             "SF=单帧直出卷（锚定帧当身份+朝向双锚，逐帧单生成 6 帧表）——网格朝向漂移的解法，试点 12/12 朝左正侧视。<br>"
             "每列可点<b>删除</b>标记废卷（变灰可撤销），每案底部有<b>备注框</b>；选择/删除/备注只自动存在本页（<b>不下载任何文件</b>），"
             "要交拍板时点「导出拍板 JSON」手动下载（deletes/notes 字段）——删除经 JSON 回来我才动文件（移备份，不硬删）。<br>"
             "<b>2026-10-04 拍板 JSON v3 已回（终版）</b>：radio 已按 v3 预选。采纳 10 攻击（mg42/kingtiger/bomber(R2)/mortar/a7v/lanchest/mark4/m1a2sep/technical_e/77mm/105mm 中 "
             "bomber=R2、其余 SF）+ 两 idle；m60 弃（维持现状）。三案备注「抠阴影」已做（mg_nest/bomber/77mm，备份 _b5_backup_shadow_20261004/）；"
             "mark4 备注「1，6帧 转方向」已核实为旧备注（fix3 已镜像，6/6 朝左）。deletes：a7v_VID 三件移 _b5_backup_deletes3_20261004/（前五项在 deletes2）。"
             "SF 表黑底 bug 已修（全卷 RGBA 透明）。</p>")
    DEL = "<button class='del' onclick='del(this)'>删除</button>"

    h.append("<h2>一、现役已修（备份 vs 现状）</h2>")
    for dirname, desc, bak, cur in pairs:
        h.append("<div class='case'><h3>%s <span class='tag'>%s</span></h3><div class='row'>" % (dirname, desc))
        if bak:
            h.append("<div class='col'><div class='cap'>备份（修前）</div><img src='../b5_probe/%s'></div>" % bak)
        h.append("<div class='col'><div class='cap'>现状（已落 assets）</div><img src='../b5_probe/%s'></div>" % cur)
        h.append("</div></div>")

    h.append("<h2>二、WaveB 十三案 + 105mm（staging 候选，逐案拍板）</h2>")
    keys = [k for k, _, _ in WAVEB] + ["ww1_105mm"]
    h.append("<div id='cases'>")
    for key in keys:
        desc = dict((k, d) for k, d, _ in WAVEB).get(key, "背景清洗+动画重出（视觉批候选+新锚定）")
        idle = "%s_idle_grid_preview.png" % key
        idle_ok = os.path.isfile(os.path.join(OUT, idle))
        rolls = sorted(glob.glob(os.path.join(OUT, "%s_R*_attack_sheet_832.png" % key)))
        extra = os.path.join(OUT, "%s_attack_sheet_832.png" % key)
        h.append("<div class='case' id='case_%s'><h3>%s <span class='tag'>%s</span></h3>" % (key, key, desc))
        if key in FLAGS:
            h.append("<div class='cap' style='color:#e8b96f'>目验：%s</div>" % FLAGS[key])
        h.append("<div class='row'>")
        if idle_ok:
            h.append("<div class='col' data-cand='idle'><div class='cap'>待机（锚定帧微呼吸，512 表）%s</div><img src='%s'></div>" % (DEL, idle))
        for r in rolls:
            rb = os.path.basename(r).replace("_attack_sheet_832.png", "")
            cells = "%s_attack_cells_dark.png" % rb
            gif = "%s_attack_anim_pal8.gif" % rb
            gif_rel = gif if os.path.isfile(os.path.join(OUT, gif)) else (
                "%s_attack_anim.gif" % rb if os.path.isfile(os.path.join(OUT, "%s_attack_anim.gif" % rb)) else None)
            h.append("<div class='col gif' data-cand='%s'><div class='cap'>%s 动图 %s</div>" % (rb, rb, DEL))
            if gif_rel:
                h.append("<img src='%s'>" % gif_rel)
            h.append("<div class='cap'>六格静帧</div><img src='%s'></div>" % cells)
        if os.path.isfile(extra) and not rolls:
            cells = "%s_attack_cells_dark.png" % key
            gif = "%s_attack_anim_pal8.gif" % key
            gif_rel = gif if os.path.isfile(os.path.join(OUT, gif)) else (
                "%s_attack_anim.gif" % key if os.path.isfile(os.path.join(OUT, "%s_attack_anim.gif" % key)) else None)
            h.append("<div class='col gif' data-cand='%s'><div class='cap'>攻击（视觉批卷）动图 %s</div>" % (key, DEL))
            if gif_rel:
                h.append("<img src='%s'>" % gif_rel)
            h.append("<div class='cap'>六格静帧</div><img src='%s'></div>" % cells)
        vid_gif = "%s_VID_attack_anim.gif" % key
        if os.path.isfile(os.path.join(OUT, "%s_VID_attack_sheet_512.png" % key)):
            h.append("<div class='col gif' data-cand='%s_VID'><div class='cap'>VID 视频路线（agnes-video keyframe 12帧）动图 %s</div>" % (key, DEL))
            if os.path.isfile(os.path.join(OUT, vid_gif)):
                h.append("<img src='%s'>" % vid_gif)
            h.append("<div class='cap'>12格静帧</div><img src='%s_VID_attack_cells_dark.png'></div>" % key)
        if os.path.isfile(os.path.join(OUT, "%s_SF_attack_sheet_512.png" % key)):
            h.append("<div class='col gif' data-cand='%s_SF'><div class='cap'>SF 单帧直出（锚定帧双锚逐帧，6帧）动图 %s</div>" % (key, DEL))
            if os.path.isfile(os.path.join(OUT, "%s_SF_attack_anim.gif" % key)):
                h.append("<img src='%s_SF_attack_anim.gif'>" % key)
            h.append("<div class='cap'>6格静帧</div><img src='%s_SF_attack_cells_dark.png'></div>" % key)
        h.append("</div>")
        # radio 行
        opts = []
        for r in rolls:
            rb = os.path.basename(r).replace("_attack_sheet_832.png", "")
            opts.append(("label.opt", rb))
        if os.path.isfile(extra) and not rolls:
            opts.append(("", key))
        if os.path.isfile(os.path.join(OUT, "%s_VID_attack_sheet_512.png" % key)):
            opts.append(("", key + "_VID"))
        if os.path.isfile(os.path.join(OUT, "%s_SF_attack_sheet_512.png" % key)):
            opts.append(("", key + "_SF"))
        if opts:
            h.append("<div style='margin-top:8px'>攻击采用：<label class='opt'><input type='radio' name='%s' value='弃' checked>弃（维持现状）</label>" % key)
            for _, rb in opts:
                h.append("<label class='opt'><input type='radio' name='%s' value='%s'>%s</label>" % (key, rb, rb))
            h.append("</div>")
        elif idle_ok:
            h.append("<div style='margin-top:8px'>本案仅待机：<label class='opt'><input type='radio' name='%s' value='idle' checked>采用新待机</label>"
                     "<label class='opt'><input type='radio' name='%s' value='弃'>弃</label></div>" % (key, key))
        h.append("<input class='note' placeholder='备注（随拍板 JSON 导出）…' oninput='save()'>")
        h.append("</div>")
    h.append("</div>")
    h.append("<p><button onclick=\"export_json()\">导出拍板 JSON</button> <span class='cap'>→ 手动点按钮才下载 b5_decisions.json（放 staging 或 Downloads 均可，回来说一声即可）；平时改动只自动存本页，不触发下载</span></p>")
    h.append(("""<script>
window.SEED_DECISIONS=__SEED_DECISIONS__;
function state(){
  const out={source:'b5_验收台',date:'2026-10-04',decisions:{},notes:{},deletes:{}};
  document.querySelectorAll('.case').forEach(c=>{
    const key=c.id.replace('case_','');
    const r=c.querySelector('input[type=radio]:checked');
    if(r) out.decisions[key]=r.value;
    const n=c.querySelector('input.note');
    if(n&&n.value.trim()) out.notes[key]=n.value.trim();
    const d=[...c.querySelectorAll('.col.deleted')].map(x=>x.dataset.cand).filter(Boolean);
    if(d.length) out.deletes[key]=d;
  });
  return out;
}
function del(b){
  const col=b.closest('.col');
  const off=col.classList.toggle('deleted');
  b.textContent=off?'已删·撤销':'删除';
  persist();
}
function persist(){
  try{localStorage.setItem('b5_state_v1',JSON.stringify(state()))}catch(e){}
}
function restore(){
  try{
    const s=JSON.parse(localStorage.getItem('b5_state_v1')||'{}');
    const D=Object.assign({},window.SEED_DECISIONS||{},s.decisions||{});
    document.querySelectorAll('.case').forEach(c=>{
      const key=c.id.replace('case_','');
      if(D[key]!==undefined){
        const r=c.querySelector("input[type=radio][value=\\""+D[key]+"\\"]");
        if(r)r.checked=true;
      }
      if(s.notes&&s.notes[key]){const n=c.querySelector('input.note');if(n)n.value=s.notes[key];}
      ((s.deletes&&s.deletes[key])||[]).forEach(cd=>{
        const col=c.querySelector(".col[data-cand=\\""+cd+"\\"]");
        if(col){col.classList.add('deleted');const b=col.querySelector('button.del');if(b)b.textContent='已删·撤销';}
      });
    });
  }catch(e){}
}
function save(){
  persist();
}
function export_json(){
  const out=state();
  persist();
  const b=new Blob([JSON.stringify(out,null,1)],{type:'application/json'});
  const a=document.createElement('a');a.href=URL.createObjectURL(b);a.download='b5_decisions.json';a.click();
}
document.addEventListener('change',e=>{if(e.target.matches('input[type=radio]'))persist();});
restore();
</script></body></html>""".replace("__SEED_DECISIONS__", json.dumps(SEED_DECISIONS, ensure_ascii=False))))
    with open(os.path.join(OUT, "b5_验收台.html"), "w", encoding="utf-8") as f:
        html = "\n".join(h)
        # 缓存击穿：改动后旧图可能被浏览器缓存顶住（mark4 备注悬案嫌疑），全部 img 加版本参数
        html = html.replace(".png'", ".png?v=8'").replace(".gif'", ".gif?v=8'")
        f.write(html)
    print("验收台 →", os.path.join(OUT, "b5_验收台.html"))
    print("案件数：现役已修 %d + staging %d" % (len(pairs), len(keys)))


if __name__ == "__main__":
    main()
