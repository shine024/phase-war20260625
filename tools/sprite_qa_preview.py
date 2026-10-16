# -*- coding: utf-8 -*-
"""sprite_qa_preview.py — 照 anim_preview.html 形式生成带 QA 指标预览页。

数据源: .godot/unit_review/sprite_qa_report.json (sprite_qa_check.py 产物)
输出:   .godot/unit_review/anim_preview_qa.html
每家: 循环动画 + 逐帧定格 + 7 项指标徽章(PASS 绿 / FAIL 红 + 数字)。
用法: python tools/sprite_qa_preview.py
"""
import io, json, os, sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
HERE = os.path.dirname(os.path.abspath(__file__))
WS = os.path.abspath(os.path.join(HERE, ".."))
RS = os.path.join(WS, ".godot", "unit_review")

# seq/中文名对照(与 anim_preview.html 一致)
NAMES = {
    "ww2_inf_bazooka": (9, "巴祖卡组"),
    "ww2_arty_m81": (11, "81mm迫击炮"),
    "ww1_inf_storm_e": (39, "暴风突击队"),
    "cold_inf_spetsnaz_e": (53, "特种部队"),
    "cold_boss_mig": (55, "米格-29"),
    "mod_inf_marine": (56, "海军陆战队"),
    "mod_arm_stryker_e": (58, "斯特赖克装甲车"),
    "fut_arm_mech_e": (66, "机甲步兵"),
    "fut_inf_spectre_e": (68, "幽灵特工"),
    "ww1_inf_mp18_x": (75, "MP18 突击队"),
    "mod_sup_m4_carbine": (86, "M4 卡宾特遣班"),
    "ww2_arm_garand_para": (76, "M1 加兰德伞兵班"),
}


def badges(rep):
    """7 项指标 → 徽章 html。"""
    def b(name, ok, txt):
        cls = "ok" if ok else "bad"
        return '<span class="bdg %s">%s %s</span>' % (cls, name, txt)
    out = []
    s = rep["size"]
    out.append(b("大小", s["pass"], "dh%.2f dw%.2f" % (s["dh"], s["dw"])))
    f = rep["facing"]
    out.append(b("方向", f["pass"], "bk%.0f drift%.0f" % (f["bookend"], f["drift"])))
    fr = rep["fire"]
    ftxt = ("焰f%d@x%d" % (fr["frames"][0][0] + 1, fr["frames"][0][1])) if fr["frames"] else "无焰?"
    out.append(b("开火", fr["pass"], ftxt))
    ft = rep["foot"]
    out.append(b("脚部", ft["pass"], "span%d" % ft["span"]))
    m = rep["motion"]
    out.append(b("动画", m["pass"], "IoU%.2f" % m["min"]))
    out.append(b("循环", rep["loop"]["pass"], "%.2f" % rep["loop"]["iou"]))
    c = rep["clutter"]
    ctxt = "mag%d" % c["magenta"] if c["magenta"] else "stray%d" % c["stray_blocks"]
    out.append(b("杂物", c["pass"], ctxt))
    return "".join(out)


def main():
    report = json.load(open(os.path.join(RS, "sprite_qa_report.json"), encoding="utf-8"))
    units = []
    for rep in report:
        uid = rep["unit"]
        seq, name = NAMES[uid]
        units.append({"seq": seq, "id": uid, "name": name, "n": rep["frames"],
                      "rel": "api_%s/sheet_attack_api.png" % uid, "rep": rep})

    cards = []
    for u in units:
        rep = u["rep"]
        verdict = "PASS" if rep["all_pass"] else "FAIL"
        vcls = "vok" if rep["all_pass"] else "vbad"
        cards.append('''<div class="unit">
  <div class="head"><b>%d</b> %s <span class="dim">%s · %d 帧 · 8fps 循环</span>
    <span class="verdict %s">%s</span></div>
  <div class="bdgrow">%s</div>
  <div class="mainrow">
    <div class="chk big"><canvas id="a%d" width="512" height="512"></canvas></div>
    <div class="thumbs" id="t%d"></div>
  </div>
</div>''' % (u["seq"], u["name"], u["id"], u["n"], vcls, verdict,
             badges(rep), u["seq"], u["seq"]))

    data = [{"seq": u["seq"], "n": u["n"], "rel": u["rel"]} for u in units]
    html = '''<!DOCTYPE html><html><head><meta charset="utf-8"><title>12 家 QA 验收预览（2026-10-13 定标口径）</title>
<style>
body{background:#14161b;color:#e8e8ea;font-family:"Microsoft YaHei",system-ui;margin:0;padding:14px}
h1{font-size:19px;margin:0 0 4px}
.meta{color:#8b98a8;font-size:12px;margin-bottom:10px}
.controls{position:sticky;top:0;background:#1e2129;border:1px solid #333a44;border-radius:8px;
 padding:8px 12px;display:flex;gap:10px;align-items:center;margin-bottom:14px;z-index:9}
.controls button{background:#2a2f3a;color:#e8e8ea;border:1px solid #3a4150;border-radius:5px;padding:4px 14px;cursor:pointer}
.controls button.on{background:#4aa8ff;color:#fff;border-color:#4aa8ff;font-weight:700}
#fidx{color:#f5c542;min-width:60px}
.unit{background:#1c1f27;border:1px solid #2e343f;border-radius:10px;padding:10px;margin-bottom:14px}
.head{font-size:14px;margin-bottom:6px}
.head .dim{color:#8b98a8;font-size:11px;font-family:Consolas,monospace}
.verdict{float:right;font-weight:700;font-size:13px;padding:1px 10px;border-radius:10px}
.vok{background:#123f1e;color:#5fe08a}.vbad{background:#4a1414;color:#ff7b72}
.bdgrow{margin-bottom:8px}
.bdg{display:inline-block;font-size:11px;font-family:Consolas,monospace;border-radius:4px;
 padding:1px 7px;margin-right:5px;background:#232833;color:#9aa7b8}
.bdg.ok{background:#12301c;color:#5fe08a}
.bdg.bad{background:#3d1212;color:#ff8a80}
.mainrow{display:flex;gap:14px;align-items:flex-start}
.chk{background:conic-gradient(#2a313a 25%%,#1c222a 0 50%%,#2a313a 0 75%%,#1c222a 0);background-size:16px 16px}
.chk.big canvas{display:block;width:512px;height:512px;image-rendering:pixelated}
.thumbs{display:flex;flex-direction:column;gap:6px;flex-wrap:wrap}
.thumbs canvas{width:120px;height:120px;image-rendering:pixelated;background:#1a1e25;border:1px solid #333a44;display:block}
.tlabel{font-size:11px;color:#8b98a8;text-align:center;width:120px}
</style></head><body>
<h1>12 家 QA 验收预览</h1>
<div class="meta">暂存 sheet（未部署）。徽章口径 2026-10-13 定标：大小=剔焰烟净高差·方向=书挡回归·开火=焰帧唯一+焰心左半·脚部=主体底缘差·动画=剔焰烟IoU·杂物=品红硬门(stray部署三刀清)。
FAIL 项红标——待目检定性：真缺陷重生成 / 表现合法放行。</div>
<div class="controls">
  <span style="color:#8b98a8">速度:</span>
  <button data-fps="4">4fps</button><button data-fps="8" class="on">8fps</button><button data-fps="16">16fps</button>
  <button id="pause">⏸ 暂停</button><span id="fidx">帧 1/6</span>
</div>
%s
<script>
const DATA = %s;
let t = 0, fps = 8, timer = null, paused = false;
const R = DATA.map(u => ({
  img: new Image(), u,
  a: document.getElementById('a'+u.seq).getContext('2d'),
  box: document.getElementById('t'+u.seq)
}));
R.forEach(o => { o.img.src = o.u.rel; });
function draw(){
  R.forEach(o => {
    if (!(o.img.complete && o.img.naturalWidth)) return;
    const n = o.u.n;
    const i = t %% n;
    o.a.clearRect(0,0,512,512);
    o.a.drawImage(o.img, i*256, 0, 256, 256, 0, 0, 512, 512);
  });
  const first = R[0].u;
  document.getElementById('fidx').textContent = '帧 ' + (t %% first.n + 1) + '/' + first.n;
}
function step(){ if(!paused){ t++; draw(); } }
function start(){ if(timer) clearInterval(timer); timer = setInterval(step, 1000/fps); }
document.querySelectorAll('.controls button[data-fps]').forEach(b => b.onclick = () => {
  document.querySelectorAll('.controls button[data-fps]').forEach(x=>x.classList.remove('on'));
  b.classList.add('on'); fps = +b.dataset.fps; start();
});
document.getElementById('pause').onclick = () => { paused = !paused; document.getElementById('pause').textContent = paused?'▶ 播放':'⏸ 暂停'; };
let loaded = 0;
R.forEach(o => {
  const done = () => {
    loaded++;
    if (loaded >= R.length){
      R.forEach(o => {
        for (let i=0;i<o.u.n;i++){
          const cv = document.createElement('canvas'); cv.width=256; cv.height=256;
          cv.style.width='120px'; cv.style.height='120px';
          cv.getContext('2d').drawImage(o.img, i*256,0,256,256, 0,0,256,256);
          const w = document.createElement('div');
          w.appendChild(cv);
          const lab = document.createElement('div'); lab.className='tlabel'; lab.textContent = 'f'+(i+1);
          w.appendChild(lab);
          o.box.appendChild(w);
        }
      });
      draw(); start();
    }
  };
  if (o.img.complete && o.img.naturalWidth) done();
  else { o.img.addEventListener('load', done); o.img.addEventListener('error', done); }
});
</script></body></html>''' % ("\n".join(cards), json.dumps(data, ensure_ascii=False))

    out = os.path.join(RS, "anim_preview_qa.html")
    open(out, "w", encoding="utf-8").write(html)
    print("[done] %s" % out)


if __name__ == "__main__":
    main()
