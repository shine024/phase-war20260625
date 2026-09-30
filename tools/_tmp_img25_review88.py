# -*- coding: utf-8 -*-
"""img25 重生成 88 单位验收页生成器（2026-09-30）。

复刻 tools/unit_art_review.html 形式（条带动画+批注+导出），只装本次重做的 88 单位：
- 每行：单位信息（武器/通道/特殊处理标注）| 卡图（身份锚对照）| idle 动画 | attack 动画 | 批注框
- 特殊处理标注：废单重掷 / SKIP 兜底格 / FLIP 镜像格 / 自定义回文序 / enemy 朝右镜像
- 动画：部署后的 sheet 正向循环（sheet 本身回文，正播=往返）
- 批注：localStorage 自动保存 + 导出 JSON / Markdown 修复单

用法：python tools/_tmp_img25_review88.py  →  tools/img25_redo_review.html
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import _tmp_img25_redo_88 as R

OUT_HTML = os.path.join(ROOT, "tools", "img25_redo_review.html")

REGEN_ATTACK = {"cold_f4", "cold_rpk", "cold_arm_p18", "drop_phase_lance", "fut_space_fighter",
                "fut_sup_ps9", "mod_ah64", "mod_air_bomber", "mod_arty_rq7", "mod_challenger2",
                "platform_cold_scout", "ww2_air_me262", "ww2_air_meteor_e", "ww2_arm_tiger",
                "ww1_lanchest"}
REGEN_IDLE = {"cold_f4", "cold_rpk", "mod_ah64", "mod_air_bomber", "mod_stinger", "mod_uh60"}
DEFENSIVE_NOTE = "防御性单位：attack 用轻动作变体（脉冲/微光），不强求开火"


def build_data():
    from PIL import Image
    out = []
    for (key, rel, weapon, energy, defensive) in R.U:
        rel_d = "assets/effects/unit_anims/" + key       # 文件系统侧（项目根相对）
        web_d = "../assets/effects/unit_anims/" + key    # 页面侧（html 在 tools/ 下）
        jp = os.path.join(ROOT, rel_d, "anim.json")
        meta = json.load(open(jp, encoding="utf-8")) if os.path.exists(jp) else {}
        u = {
            "key": key, "weapon": weapon,
            "energy": energy, "defensive": defensive,
            "card": "../assets/card_icons/" + rel,
            "counts": meta.get("counts", {}), "fps": meta.get("fps", 8),
            "frame_size": meta.get("frame_size", 256),
            "idle_sheet": web_d + "/sheet_idle.png", "attack_sheet": web_d + "/sheet_attack.png",
            "tags": [],
        }
        if key in REGEN_ATTACK:
            u["tags"].append("attack 重掷")
        if key in REGEN_IDLE:
            u["tags"].append("idle 重掷")
        if defensive:
            u["tags"].append(DEFENSIVE_NOTE)
        if energy:
            u["tags"].append("能量通道（蓝白光）")
        for i in sorted(R.SKIP_CELLS.get(key, {}).get("attackC", set())):
            u["tags"].append("attack 格%d 兜底卡图" % i)
        for i in sorted(R.SKIP_CELLS.get(key, {}).get("idle", set())):
            u["tags"].append("idle 格%d 兜底卡图" % i)
        for i in sorted(R.FLIP_CELLS.get(key, {}).get("attackC", set())):
            u["tags"].append("attack 格%d 镜像" % i)
        if key in R.FORCE_FLIP_F0:
            u["tags"].append("enemy 卡图朝右已镜像")
        pal = R.PAL_OVERRIDE.get((key, "idle")) or R.PAL_OVERRIDE.get((key, "attack"))
        if pal:
            u["tags"].append("自定义回文序 %s" % pal)
        out.append(u)
    return out


HTML = """<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>img25 重生成验收工单（88 单位 2026-09-30）</title>
<style>
body{font-family:"Microsoft YaHei",sans-serif;background:#141419;color:#ddd;margin:0;padding:12px}
.bar{position:sticky;top:0;z-index:9;background:#1b1b24;padding:8px 12px;border-bottom:2px solid #35455f;display:flex;gap:10px;align-items:center;flex-wrap:wrap}
.bar h1{font-size:16px;color:#6cf;margin:0 8px 0 0}
.bar input[type=text]{background:#0e0e14;border:1px solid #345;color:#eee;padding:5px 8px;border-radius:4px;width:200px}
button{background:#27405e;border:1px solid #4af;color:#cde;border-radius:4px;padding:5px 10px;cursor:pointer;font-size:13px}
button:hover{background:#33547c}
button.on{background:#7a4a1f;border-color:#f80;color:#fed}
.note{font-size:12px;color:#89a;margin:0 6px}
.row{display:flex;gap:10px;padding:8px;border-bottom:1px solid #26262e;align-items:flex-start;background:#191920}
.row:hover{background:#1d1d27}
.meta{width:185px;min-width:185px}
.meta .k{font-weight:bold;color:#8df;font-size:13px;word-break:break-all}
.meta .sub{font-size:11px;color:#789;margin-top:3px;line-height:1.5}
.tag{display:inline-block;background:#1f2a4a;color:#9cf;border:1px solid #4af;border-radius:3px;padding:1px 5px;font-size:10px;margin:2px 2px 0 0;font-weight:bold}
.tag.warn{background:#3a2a10;color:#ecb;border-color:#a86;font-weight:normal}
.cell{width:132px;min-width:132px;text-align:center}
.cell img{max-width:100%;max-height:120px;object-fit:contain;background:#20202a;border:1px solid #333;cursor:zoom-in;display:block;margin:0 auto}
.anim{display:inline-block;width:120px;height:120px;background-repeat:no-repeat;background-color:#20202a;border:1px solid #333;cursor:pointer;max-width:100%}
.anim.paused{outline:2px solid #f80;outline-offset:-2px}
.cell .cap{font-size:10px;color:#678;margin-top:2px}
.missing{width:120px;height:60px;line-height:60px;background:#20202a;border:1px dashed #433;color:#645;font-size:11px;text-align:center;margin:0 auto}
.edit{flex:1;min-width:220px}
.edit textarea{width:100%;height:56px;background:#0e0e14;border:1px solid #345;color:#eee;border-radius:4px;padding:5px 8px;font-size:12px;box-sizing:border-box;resize:vertical}
.edit .st{font-size:11px;color:#678;margin-top:3px}
.dot{display:inline-block;width:8px;height:8px;border-radius:50%;background:#345;margin-right:5px}
.dot.dirty{background:#f80}.dot.saved{background:#4a4}
#zoom{position:fixed;inset:0;background:rgba(0,0,0,.85);display:none;align-items:center;justify-content:center;z-index:99;cursor:zoom-out}
#zoom img{max-width:92vw;max-height:92vh}
h1 small{color:#789;font-size:12px;font-weight:normal}
</style></head><body>
<div class="bar">
  <h1>img25 重生成验收工单 <small>88 单位 · 2026-09-30 · 部署后实图 · 蓝标=特殊处理</small></h1>
  <input type="text" id="filter" placeholder="过滤单位…">
  <span class="note" id="cnt2"></span>
  <button id="toggleAnim" class="on">⏸ 动画播放中（点击全局暂停）</button>
  <button id="saveAll">导出批注 JSON</button>
  <button id="exportMd">导出 Markdown 修复单</button>
</div>
<div id="list"></div>
<div id="zoom"><img id="zoomImg"></div>
<script>
const DATA = __DATA__;
const LS = "img25_redo_review_notes";
let notes = {};
try{ notes = JSON.parse(localStorage.getItem(LS) || "{}"); }catch(e){ notes = {}; }
const $ = s => document.querySelector(s);
const esc = s => String(s||"").replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));

function animCell(u, tag){
  const sheet = tag === "idle" ? u.idle_sheet : u.attack_sheet;
  const n = (u.counts||{})[tag] || 0;
  if(!sheet || !n) return '<div class="cell"><div class="missing">无</div><div class="cap">—</div></div>';
  const fw = 120;  /* 显示帧宽=高（正方形帧 256²） */
  return '<div class="cell"><div class="anim" data-sheet="'+esc(sheet)+'" data-n="'+n+'" data-fw="'+fw+'" '
    + 'data-fps="'+(u.fps||8)+'" style="background-image:url(\\''+esc(sheet)+'\\');background-size:auto 120px;background-position:0 0"></div>'
    + '<div class="cap">'+tag+' '+n+'帧</div></div>';
}

function render(){
  const q = $("#filter").value.trim().toLowerCase();
  const list = $("#list"); list.innerHTML = "";
  let shown = 0;
  for(const u of DATA){
    const note = (notes[u.key]||{}).note || "";
    if(q && !(u.key.toLowerCase().includes(q) || note.toLowerCase().includes(q))) continue;
    shown++;
    const tags = (u.tags||[]).map(f=>{
      const warn = f.startsWith("attack 格") || f.startsWith("idle 格") || f.includes("重掷");
      return '<span class="tag'+(warn?" warn":"")+'">'+esc(f)+'</span>';
    }).join("");
    const sub = u.weapon+" · "+(u.energy?"能量":"动能")+" · idle "+((u.counts||{}).idle||0)+"帧 / attack "+((u.counts||{}).attack||0)+"帧 @ "+u.fps+"fps";
    const div = document.createElement("div");
    div.className = "row"; div.dataset.key = u.key;
    div.innerHTML =
      '<div class="meta"><div class="k">'+esc(u.key)+'</div><div class="sub">'+esc(sub)+'</div><div>'+tags+'</div></div>'
      + '<div class="cell"><img src="'+esc(u.card)+'" loading="lazy"><div class="cap">卡图（身份锚）</div></div>'
      + animCell(u,"idle") + animCell(u,"attack")
      + '<div class="edit"><textarea placeholder="批注（问题/建议），自动保存… " data-k="'+esc(u.key)+'">'+esc(note)+'</textarea>'
      + '<div class="st"><span class="dot" id="dot-'+esc(u.key)+'"></span><span id="st-'+esc(u.key)+'">'+(note?"有批注":"")+'</span></div></div>';
    list.appendChild(div);
  }
  $("#cnt2").textContent = "显示 "+shown+" / "+DATA.length;
  if(!shown){ list.innerHTML = '<div style="padding:30px;color:#667">无匹配单位</div>'; }
  setupAnims();
}

/* ── 动画循环：单 rAF + 可视区步进（sheet 已回文，正向循环即往返） ── */
let animOn = true;
const visEls = new Set();
let io = null;
function setupAnims(){
  visEls.clear();
  const els = document.querySelectorAll(".anim");
  if(io) io.disconnect();
  if(!("IntersectionObserver" in window)){ els.forEach(el=>visEls.add(el)); return; }
  io = new IntersectionObserver(es=>{
    for(const en of es){
      if(en.isIntersecting) visEls.add(en.target); else visEls.delete(en.target);
    }
  }, {rootMargin:"150px"});
  els.forEach(el=>io.observe(el));
}
let _lastT = performance.now();
function _tick(now){
  const dt = Math.min(0.1, (now - _lastT) / 1000); _lastT = now;
  if(animOn){
    visEls.forEach(el=>{
      if(el._userPaused) return;
      const n = +el.dataset.n; if(!(n > 1)) return;
      const fps = +el.dataset.fps || 8, fw = +el.dataset.fw || 120;
      el._acc = (el._acc || 0) + dt * fps;
      const i = Math.floor(el._acc) % n;
      if(i !== el._last){ el._last = i; el.style.backgroundPosition = (-i * fw) + "px 0"; }
    });
  }
  requestAnimationFrame(_tick);
}
requestAnimationFrame(_tick);
$("#toggleAnim").onclick = ()=>{
  animOn = !animOn;
  $("#toggleAnim").textContent = animOn ? "⏸ 动画播放中（点击全局暂停）" : "▶ 动画已全局暂停（点击恢复）";
  $("#toggleAnim").classList.toggle("on", animOn);
};

/* ── 批注 ── */
let t = null;
document.addEventListener("input", e=>{
  if(e.target.tagName!=="TEXTAREA") return;
  const k = e.target.dataset.k;
  notes[k] = notes[k]||{}; notes[k].note = e.target.value;
  notes[k].updated = new Date().toISOString();
  const dot = document.getElementById("dot-"+CSS.escape(k)), st = document.getElementById("st-"+esc(k));
  if(dot) dot.className = "dot dirty";
  clearTimeout(t);
  t = setTimeout(()=>{ persist(); markRow(k,"saved","已保存"); }, 500);
});
document.addEventListener("click", e=>{
  if(e.target.classList && e.target.classList.contains("anim")){
    e.target._userPaused = !e.target._userPaused;
    e.target.classList.toggle("paused", e.target._userPaused);
    return;
  }
  if(e.target.tagName === "IMG" && e.target.src.includes("card_icons")){
    $("#zoomImg").src = e.target.src; $("#zoom").style.display = "flex"; return;
  }
  if(e.target.id === "zoom" || e.target.id === "zoomImg"){ $("#zoom").style.display = "none"; return; }
});
function markRow(k, cls, txt){
  const dot = document.getElementById("dot-"+CSS.escape(k)), st = document.getElementById("st-"+CSS.escape(k));
  if(dot) dot.className = "dot "+cls;
  if(st) st.textContent = txt + " · " + new Date().toLocaleTimeString();
}
function persist(){ try{ localStorage.setItem(LS, JSON.stringify(notes)); }catch(e){ alert("浏览器存储失败："+e); } }
function payload(){
  const units = {};
  for(const u of DATA){
    const n = notes[u.key];
    units[u.key] = {
      note: (n&&n.note)||"", updated: (n&&n.updated)||null,
      weapon: u.weapon, tags: u.tags,
      card: u.card, idle_sheet: u.idle_sheet, attack_sheet: u.attack_sheet,
      anim: {fps:u.fps, frame_size:u.frame_size, counts:u.counts}
    };
  }
  return {_meta:{tool:"img25_redo_review", exported:new Date().toISOString(), units_total:DATA.length,
                 filled:Object.values(notes).filter(n=>n.note&&n.note.trim()).length}, units};
}
function download(name, text){
  const a = document.createElement("a");
  a.href = URL.createObjectURL(new Blob([text], {type:"application/octet-stream"}));
  a.download = name; a.click();
}
$("#saveAll").onclick = ()=>{ persist();
  download("img25_review_notes_"+new Date().toISOString().slice(0,10)+".json", JSON.stringify(payload(),null,1)); };
function markdown(){
  let out = [];
  out.push("# img25 重生成修复单（"+new Date().toLocaleString()+"）");
  for(const u of DATA){
    const n = notes[u.key];
    const note = (n&&n.note)||"";
    if(!note.trim()) continue;
    out.push("\\n## "+u.key);
    out.push("- "+u.weapon+" · tags: "+(u.tags||[]).join("；")||"无");
    out.push("- 动画: "+u.idle_sheet+" ｜ "+u.attack_sheet);
    out.push("- 问题: "+note.trim().replace(/\\n/g,"\\n  "));
  }
  if(out.length<=1){ alert("还没有任何批注"); return null; }
  return out.join("\\n");
}
$("#exportMd").onclick = ()=>{ const m = markdown(); if(m) download("img25_fix_ticket_"+new Date().toISOString().slice(0,10)+".md", m); };
$("#filter").oninput = render;
render();
</script></body></html>
"""


def main():
    data = build_data()
    html = HTML.replace("__DATA__", json.dumps(data, ensure_ascii=False, separators=(",", ":")))
    open(OUT_HTML, "w", encoding="utf-8").write(html)
    print("已生成:", OUT_HTML, "单位:", len(data))


if __name__ == "__main__":
    main()
