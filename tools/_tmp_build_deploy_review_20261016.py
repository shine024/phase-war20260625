# -*- coding: utf-8 -*-
"""现役攻击帧终态检查页(2026-10-16):布置恢复后 assets 实况逐卡帧动画。

与 attk_review.html(raw 卷四拍评审页)互补:本页读 assets/effects/unit_anims/
sheet_attack.png+anim.json 终态——恢复多帧 23 卡+程序合成 2 卡(nexus/citadel)+
mp18_x 重拼,全量帧动画预览+counts/baked 标注。
产物:docs/卡图API重生成_20261014/attk_deploy_review.html(图走相对路径)
用法:python -I -u -X utf8 tools/_tmp_build_deploy_review_20261016.py
"""
import json
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIM = os.path.join(ROOT, "assets", "effects", "unit_anims")

# 070 真目标=fut_nexus(attach 走 ANIM_ALIAS,详见交接 §四.070 修正)
CARDS = [
    ("011", "ww2_arty_m81"), ("012", "ww1_arty_m81"), ("017", "cold_sup_zsu23"),
    ("019", "mod_arm_m1a1"), ("026", "fut_arm_prism"), ("030", "fut_arm_titan_mk2"),
    ("032", "fut_air_heavy_carrier"), ("037", "ww1_sup_mg_nest"), ("038", "ww1_arty_mortar"),
    ("039", "ww1_inf_storm_e"), ("041", "ww1_boss_av7"), ("053", "cold_inf_spetsnaz_e"),
    ("056", "mod_inf_marine"), ("057", "mod_air_technical_e"), ("059", "mod_arty_mlrs_e"),
    ("060", "mod_inf_delta_e"), ("064", "fut_air_drone"), ("066", "fut_arm_mech_e"),
    ("068", "fut_inf_spectre_e"), ("069", "fut_arm_colossus_e"), ("070", "fut_nexus"),
    ("073", "ww1_sup_vickers"), ("074", "ww1_sup_ford_ambulance"), ("075", "ww1_inf_mp18_x"),
    ("078", "ww2_arty_pak40"), ("086", "mod_sup_m4_carbine"), ("087", "mod_inf_patriot"),
    ("093", "fut_arty_hel30"), ("094", "fut_sup_nrepair"), ("095", "fut_inf_x9"),
    ("110", "ww1_fort_pillbox"), ("113", "ww2_fort_flak"), ("116", "mod_fort_citadel"),
    ("128", "xeno_tripod"), ("146", "ww1_saint"), ("149", "ww2_mg42"),
]

cards = []
miss = []
for no, uid in CARDS:
    d = os.path.join(ANIM, uid)
    jp = os.path.join(d, "anim.json")
    sp = os.path.join(d, "sheet_attack.png")
    if not (os.path.isfile(jp) and os.path.isfile(sp)):
        miss.append("%s %s" % (no, uid))
        continue
    meta = json.load(open(jp, encoding="utf-8"))
    fs = int(meta.get("frame_size", 256))
    w = Image.open(sp).size[0]
    n = w // fs
    cards.append({
        "no": no, "uid": uid, "fps": meta.get("fps", 8),
        "counts": meta.get("counts", {}), "n": n, "fs": fs,
        "baked": bool(meta.get("outline", {}).get("baked", False)),
        "ff": meta.get("foot_frac", -1),
        "src": "../../assets/effects/unit_anims/%s/sheet_attack.png" % uid,
    })

print("卡 %d,缺 %s" % (len(cards), miss or "无"))
mism = [c for c in cards if c["n"] != int(c["counts"].get("attack", 0))]
print("帧数!=counts:", [(c["no"], c["n"], c["counts"]) for c in mism] or "无")

HTML = """<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="utf-8">
<title>现役攻击帧终态检查 2026-10-16</title>
<style>
 body{background:#1b1e24;color:#ccd;font-family:system-ui; margin:16px}
 .card{display:inline-block;vertical-align:top;background:#242830;border-radius:8px;
       padding:10px;margin:6px}
 .card h3{margin:2px 0 6px;font-size:13px;font-weight:600}
 .card canvas{image-rendering:auto;background:#20242b;border-radius:4px}
 .small canvas{image-rendering:pixelated}
 .meta{font-size:11px;color:#89a;margin-top:4px;line-height:1.5}
 .warn{color:#f87}.ok{color:#7c7}
 button{background:#333a46;color:#ccd;border:0;border-radius:4px;padding:2px 8px;
        margin:2px;cursor:pointer;font-size:11px}
 input{width:120px;vertical-align:middle}
 #big{position:fixed;inset:0;background:#000c;display:none;align-items:center;
      justify-content:center;flex-direction:column;z-index:9}
 #big canvas{background:#20242b}
</style>
</head>
<body>
<h2>现役攻击帧终态检查(2026-10-16)—— <span id="stat"></span></h2>
<p>恢复多帧 23 + 程序合成 2(nexus 电光/citadel 闪电球)+ mp18_x 重拼(f5=原图)。
左=256 帧动画,右下=96px 战场像素预览。点动画放大逐帧。</p>
<div id="list"></div>
<div id="big"><canvas id="bigcv" width="512" height="512"></canvas>
 <div><button onclick="bigStep(-1)">◀</button><span id="biglab"></span>
 <button onclick="bigStep(1)">▶</button><button onclick="document.getElementById('big').style.display='none'">关</button></div></div>
<script>
const CARDS = __CARDS__;
let bigC = null, bigF = 0;
for (const c of CARDS) {
  const div = document.createElement('div');
  div.className = 'card';
  const bad = c.n !== (c.counts.attack|0);
  div.innerHTML = `<h3>${c.no} ${c.uid}</h3>
   <div style="display:flex;gap:8px">
    <div><canvas id="cv${c.no}" width="256" height="256"></canvas></div>
    <div class="small"><canvas id="sm${c.no}" width="96" height="96"></canvas></div>
   </div>
   <div class="meta">帧 ${c.n} / counts ${c.counts.attack} ${bad?'<span class="warn">✗错配</span>':'<span class="ok">✓</span>'}
    · ${c.fps}fps · ${c.baked?'描边已烘':'shader 描边'} · ff=${c.ff}<br>
    idle ${c.counts.idle||0} 帧 · <button onclick="pause(${c.no},this)">暂停</button>
    <input type="range" min="2" max="16" value="${c.fps}" oninput="setFps(${c.no},this.value)"></div>`;
  document.getElementById('list').appendChild(div);
  const img = new Image();
  img.onload = () => startCard(c, img);
  img.src = c.src;
}
const S = {};
function startCard(c, img) {
  const cv = document.getElementById('cv' + c.no), sm = document.getElementById('sm' + c.no);
  S[c.no] = { c, img, f: 0, t: 0, fps: c.fps, cv, sm, run: true };
  requestAnimationFrame(ts => tick(c.no, ts));
}
function tick(no, ts) {
  const s = S[no]; if (!s) return;
  if (s.run && ts - s.t > 1000 / s.fps) {
    s.t = ts; s.f = (s.f + 1) % s.c.n; draw(s);
  }
  requestAnimationFrame(t2 => tick(no, t2));
}
function draw(s) {
  const { c, img } = s, fs = c.fs;
  for (const [cvv, sz] of [[s.cv, 256], [s.sm, 96]]) {
    const g = cvv.getContext('2d');
    g.clearRect(0, 0, sz, sz);
    g.drawImage(img, s.f * fs, 0, fs, fs, 0, 0, sz, sz);
  }
}
function pause(no, btn) { const s = S[no]; s.run = !s.run; btn.textContent = s.run ? '暂停' : '播放'; }
function setFps(no, v) { S[no].fps = +v; }
function bigStep(d) { bigF = (bigF + d + bigC.c.n) % bigC.c.n; drawBig(); }
function drawBig() {
  const { c, img } = bigC, fs = c.fs;
  const cv = document.getElementById('bigcv'), g = cv.getContext('2d');
  g.imageSmoothingEnabled = false;
  g.clearRect(0, 0, 512, 512);
  g.drawImage(img, bigF * fs, 0, fs, fs, 0, 0, 512, 512);
  document.getElementById('biglab').textContent = `${bigC.c.no} 帧 ${bigF + 1}/${bigC.c.n}`;
}
for (const c of CARDS)
  document.getElementById('cv' + c.no).parentElement.onclick =
    () => { bigC = S[c.no]; bigF = bigC.f; document.getElementById('big').style.display = 'flex'; drawBig(); };
document.getElementById('stat').textContent = CARDS.length + ' 卡';
</script>
</body></html>"""

out = os.path.join(ROOT, "docs", "卡图API重生成_20261014", "attk_deploy_review.html")
with open(out, "w", encoding="utf-8") as f:
    f.write(HTML.replace("__CARDS__", json.dumps(cards, ensure_ascii=False)))
print("写", os.path.relpath(out, ROOT))
