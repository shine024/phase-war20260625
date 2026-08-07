import os

html_content = r'''<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<title>敌方单位·弹道起始点标注工具</title>
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
body { background:#0e1117; color:#e2e8f0; font-family:sans-serif; font-size:13px; }
h1 { text-align:center; padding:16px; color:#58a6ff; font-size:20px; }
.toolbar { display:flex; gap:8px; justify-content:center; padding:10px; flex-wrap:wrap; border-bottom:1px solid #2a2f3a; margin-bottom:16px; }
.btn { padding:5px 12px; border:1px solid #2a2f3a; border-radius:6px; background:#161b26; color:#e2e8f0; cursor:pointer; font-size:12px; }
.btn:hover { border-color:#58a6ff; }
.btn.active { background:#58a6ff; color:#000; }
.grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(420px,1fr)); gap:14px; padding:0 20px 40px; max-width:1800px; margin:0 auto; }
.card { background:#161b26; border:1px solid #2a2f3a; border-radius:8px; overflow:hidden; }
.card-header { display:flex; align-items:center; gap:10px; padding:10px 12px; border-bottom:1px solid #2a2f3a; }
.card-icon { width:64px; height:64px; object-fit:cover; border-radius:4px; background:#1e2430; border:1px solid #333; }
.card-info { flex:1; }
.card-name { font-size:14px; font-weight:600; }
.card-id { font-size:10px; color:#8892a4; font-family:monospace; margin-top:2px; }
.card-body { display:flex; gap:10px; padding:10px 12px; }
.canvas-wrap { position:relative; flex-shrink:0; }
.canvas-wrap canvas { display:block; border-radius:4px; cursor:crosshair; background:#0d1117; }
.stats { flex:1; min-width:0; }
.stat-row { display:flex; justify-content:space-between; padding:2px 0; font-size:11px; border-bottom:1px solid rgba(255,255,255,0.04); }
.stat-label { color:#8892a4; }
.stat-value { font-weight:600; }
.wt-badge { display:inline-block; padding:1px 5px; border-radius:3px; font-size:10px; font-weight:700; color:#000; }
.edit-section { margin-top:6px; padding-top:6px; border-top:1px solid #2a2f3a; }
.edit-row { display:flex; align-items:center; gap:5px; padding:1px 0; }
.edit-row label { color:#8892a4; font-size:10px; min-width:50px; }
.edit-row input { width:55px; background:#0d1117; border:1px solid #2a2f3a; color:#e2e8f0; border-radius:3px; padding:1px 4px; font-size:10px; }
.edit-row input:focus { outline:none; border-color:#58a6ff; }
.card-footer { padding:6px 12px; border-top:1px solid #2a2f3a; font-size:10px; color:#8892a4; }
.formula { text-align:center; color:#8892a4; font-size:11px; padding:8px 20px; border-bottom:1px solid #2a2f3a; }
.formula code { background:#21262d; padding:1px 4px; border-radius:3px; color:#58a6ff; font-size:10px; }
.toast { position:fixed; top:20px; right:20px; padding:8px 16px; border-radius:6px; font-size:12px; z-index:999; opacity:0; transition:opacity .3s; pointer-events:none; }
.toast.show { opacity:1; }
.toast.ok { background:#3fb950; color:#000; }
.toast.info { background:#58a6ff; color:#000; }
</style>
</head>
<body>
<h1>敌方单位·弹道起始点标注工具</h1>
<p class="formula">
  <span style="color:#50c878">■ 绿点</span> = 脚部/头部锚点（拖动调整实体范围） |
  <span style="color:#ff4040">● 红点</span> = 弹道起始点（拖动独立调整）<br>
  公式：<code>fire_pos = global_position + UP × (entity_top_y × 0.5)</code>
</p>
<div class="toolbar">
  <button class="btn active" onclick="filterEra('all')">全部 (36)</button>
  <button class="btn" onclick="filterEra('一战')">一战 (7)</button>
  <button class="btn" onclick="filterEra('二战')">二战 (7)</button>
  <button class="btn" onclick="filterEra('冷战')">冷战 (7)</button>
  <button class="btn" onclick="filterEra('现代')">现代 (8)</button>
  <button class="btn" onclick="filterEra('近未来')">近未来 (7)</button>
  <span style="flex:1"></span>
  <button class="btn" onclick="exportJSON()">导出JSON</button>
  <button class="btn" onclick="exportGD()">导出GDScript</button>
</div>
<div class="grid" id="grid"></div>
<div id="toast" class="toast"></div>

<script>
const ERA_COLOR = {一战:'#a08060',二战:'#80a060',冷战:'#6080c0',现代:'#c08060',近未来:'#c060c0'};
const WT = [
  {t:0,name:'SMG',c:'#f5e642'},{t:1,name:'RIFLE',c:'#f5e642'},
  {t:2,name:'MG',c:'#e6d44a'},{t:3,name:'ROCKET',c:'#e8943a'},
  {t:4,name:'PISTOL',c:'#f5e642'},{t:5,name:'SHOTGUN',c:'#e6c84a'},
  {t:6,name:'SNIPER',c:'#5ce8a8'},{t:7,name:'FLAK',c:'#d4a030'},
  {t:8,name:'LASER',c:'#40d8f0'},{t:9,name:'MISSILE',c:'#e86030'},
  {t:10,name:'OMEGA',c:'#8060f0'},{t:11,name:'RAIL',c:'#6090f0'}
];
const ICON_BASE = 'enemy_fire_icons/';

const enemies = [
  {id:'ww1_inf_mp18',name:'步兵班·MP18',era:'一战',wt:0,rng:80,dmg:8,scale:0.70,ff:0.061,hf:0.061,fire_pct:50.0,icon:'vis_036.png'},
  {id:'ww1_inf_rifle',name:'步兵班·步枪',era:'一战',wt:1,rng:150,dmg:12,scale:0.74,ff:0.061,hf:0.061,fire_pct:50.0,icon:'vis_037.png'},
  {id:'ww1_sup_mg_nest',name:'机枪巢',era:'一战',wt:2,rng:120,dmg:10,scale:0.83,ff:0.209,hf:0.209,fire_pct:50.0,icon:'vis_038.png'},
  {id:'ww1_arty_mortar',name:'迫击炮组',era:'一战',wt:3,rng:180,dmg:20,scale:0.82,ff:0.061,hf:0.061,fire_pct:50.0,icon:'vis_039.png'},
  {id:'ww1_inf_storm_e',name:'暴风突击队',era:'一战',wt:0,rng:80,dmg:12,scale:0.62,ff:0.061,hf:0.061,fire_pct:50.0,icon:'vis_040.png'},
  {id:'ww1_arm_rolls_e',name:'装甲车',era:'一战',wt:2,rng:120,dmg:15,scale:1.11,ff:0.254,hf:0.252,fire_pct:49.9,icon:'vis_041.png'},
  {id:'ww1_boss_av7',name:'圣沙蒙坦克',era:'一战',wt:3,rng:150,dmg:25,scale:1.45,ff:0.061,hf:0.061,fire_pct:50.0,icon:'vis_042.png'},
  {id:'ww2_inf_thompson',name:'步兵班·汤普森',era:'二战',wt:0,rng:85,dmg:10,scale:0.70,ff:0.061,hf:0.061,fire_pct:50.0,icon:'vis_043.png'},
  {id:'ww2_inf_garand',name:'步枪班·加兰德',era:'二战',wt:1,rng:160,dmg:15,scale:0.76,ff:0.064,hf:0.064,fire_pct:50.0,icon:'vis_044.png'},
  {id:'ww2_sup_mg42',name:'MG42机枪组',era:'二战',wt:2,rng:130,dmg:14,scale:1.01,ff:0.061,hf:0.061,fire_pct:50.0,icon:'vis_045.png'},
  {id:'ww2_inf_panzerschreck_e',name:'反坦克组',era:'二战',wt:3,rng:140,dmg:30,scale:0.85,ff:0.061,hf:0.061,fire_pct:50.0,icon:'vis_046.png'},
  {id:'ww2_inf_para_e',name:'伞兵精英',era:'二战',wt:0,rng:90,dmg:16,scale:0.70,ff:0.061,hf:0.061,fire_pct:50.0,icon:'vis_047.png'},
  {id:'ww2_arm_panther_e',name:'黑豹坦克',era:'二战',wt:3,rng:150,dmg:35,scale:1.67,ff:0.061,hf:0.061,fire_pct:50.0,icon:'vis_048.png'},
  {id:'ww2_boss_kingtiger',name:'虎王坦克',era:'二战',wt:3,rng:160,dmg:40,scale:1.82,ff:0.061,hf:0.061,fire_pct:50.0,icon:'vis_049.png'},
  {id:'cold_inf_ak',name:'苏军步兵',era:'冷战',wt:1,rng:140,dmg:14,scale:0.87,ff:0.250,hf:0.250,fire_pct:50.0,icon:'vis_050.png'},
  {id:'cold_inf_m60',name:'美军步兵',era:'冷战',wt:2,rng:150,dmg:15,scale:0.82,ff:0.250,hf:0.250,fire_pct:50.0,icon:'vis_051.png'},
  {id:'cold_arm_btr_e',name:'BTR装甲车',era:'冷战',wt:2,rng:130,dmg:18,scale:1.47,ff:0.314,hf:0.381,fire_pct:53.4,icon:'vis_052.png'},
  {id:'cold_air_m113_e',name:'M113装甲车',era:'冷战',wt:2,rng:120,dmg:12,scale:1.29,ff:0.314,hf:0.381,fire_pct:53.4,icon:'vis_053.png'},
  {id:'cold_inf_spetsnaz_e',name:'特种部队',era:'冷战',wt:6,rng:220,dmg:20,scale:0.85,ff:0.250,hf:0.250,fire_pct:50.0,icon:'vis_054.png'},
  {id:'cold_arm_t72_e',name:'T-72坦克',era:'冷战',wt:3,rng:160,dmg:40,scale:2.00,ff:0.326,hf:0.367,fire_pct:52.1,icon:'vis_055.png'},
  {id:'cold_boss_mig',name:'米格-29',era:'冷战',wt:9,rng:210,dmg:55,scale:2.00,ff:0.367,hf:0.367,fire_pct:50.0,icon:'vis_056.png'},
  {id:'mod_inf_marine',name:'海军陆战队',era:'现代',wt:1,rng:150,dmg:16,scale:0.84,ff:0.252,hf:0.250,fire_pct:49.9,icon:'vis_057.png'},
  {id:'mod_air_technical_e',name:'皮卡武装',era:'现代',wt:2,rng:130,dmg:18,scale:1.54,ff:0.250,hf:0.250,fire_pct:50.0,icon:'vis_058.png'},
  {id:'mod_arm_stryker_e',name:'斯特赖克装甲车',era:'现代',wt:2,rng:150,dmg:22,scale:1.67,ff:0.270,hf:0.270,fire_pct:50.0,icon:'vis_059.png'},
  {id:'mod_arty_mlrs_e',name:'火箭炮车',era:'现代',wt:3,rng:250,dmg:35,scale:1.81,ff:0.285,hf:0.285,fire_pct:50.0,icon:'vis_060.png'},
  {id:'mod_inf_delta_e',name:'三角洲部队',era:'现代',wt:1,rng:150,dmg:24,scale:0.93,ff:0.252,hf:0.250,fire_pct:49.9,icon:'vis_061.png'},
  {id:'mod_arm_abrams_e',name:'M1A2坦克',era:'现代',wt:3,rng:200,dmg:45,scale:2.00,ff:0.270,hf:0.270,fire_pct:50.0,icon:'vis_062.png'},
  {id:'mod_air_apache_e',name:'阿帕奇直升机',era:'现代',wt:9,rng:250,dmg:38,scale:2.00,ff:0.285,hf:0.285,fire_pct:50.0,icon:'vis_063.png'},
  {id:'mod_boss_command',name:'指挥中枢',era:'现代',wt:2,rng:220,dmg:70,scale:2.00,ff:0.270,hf:0.270,fire_pct:50.0,icon:'vis_064.png'},
  {id:'fut_air_drone',name:'无人机群',era:'近未来',wt:8,rng:180,dmg:12,scale:1.25,ff:0.061,hf:0.061,fire_pct:50.0,icon:'vis_065.png'},
  {id:'fut_inf_cyborg',name:'机械步兵',era:'近未来',wt:8,rng:160,dmg:22,scale:1.05,ff:0.061,hf:0.061,fire_pct:50.0,icon:'vis_066.png'},
  {id:'fut_arm_mech_e',name:'机甲步兵',era:'近未来',wt:8,rng:150,dmg:30,scale:1.57,ff:0.307,hf:0.307,fire_pct:50.0,icon:'vis_067.png'},
  {id:'fut_arm_hovertank_e',name:'悬浮坦克',era:'近未来',wt:8,rng:250,dmg:40,scale:1.82,ff:0.307,hf:0.307,fire_pct:50.0,icon:'vis_068.png'},
  {id:'fut_inf_spectre_e',name:'幽灵特工',era:'近未来',wt:8,rng:210,dmg:35,scale:1.01,ff:0.061,hf:0.061,fire_pct:50.0,icon:'vis_069.png'},
  {id:'fut_arm_colossus_e',name:'巨神机甲',era:'近未来',wt:8,rng:250,dmg:55,scale:1.98,ff:0.307,hf:0.307,fire_pct:50.0,icon:'vis_070.png'},
  {id:'fut_boss_nexus',name:'风暴核心',era:'近未来',wt:10,rng:300,dmg:90,scale:2.00,ff:0.199,hf:0.199,fire_pct:50.0,icon:'vis_071.png'}
];

let currentEra = 'all';
let dragState = null;

function getWT(wt) { return WT.find(w => w.t === wt) || WT[0]; }
function calcFirePct(e) { return e.hf * 100 + (1 - e.hf - e.ff) * 50; }

function render(eraFilter) {
  const grid = document.getElementById('grid');
  grid.innerHTML = '';
  const list = eraFilter === 'all' ? enemies : enemies.filter(e => e.era === eraFilter);
  list.forEach((e, li) => {
    const idx = enemies.indexOf(e);
    const wt = getWT(e.wt);
    const firePct = calcFirePct(e);
    const card = document.createElement('div');
    card.className = 'card';
    card.dataset.idx = idx;
    card.innerHTML = `
      <div class="card-header" style="border-top:3px solid ${ERA_COLOR[e.era]}">
        <img class="card-icon" src="${ICON_BASE}${e.icon}" alt="${e.name}">
        <div class="card-info">
          <div class="card-name">${e.name}<span style="display:inline-block;font-size:9px;padding:1px 5px;border-radius:8px;background:${ERA_COLOR[e.era]}33;color:${ERA_COLOR[e.era]};margin-left:3px;">${e.era}</span></div>
          <div class="card-id">${e.id} → vis_enemy_${String(idx+36).padStart(3,'0')}</div>
        </div>
      </div>
      <div class="card-body">
        <div class="canvas-wrap">
          <canvas id="cv${idx}" width="160" height="200"></canvas>
        </div>
        <div class="stats">
          <div class="stat-row"><span class="stat-label">武器</span><span><span class="wt-badge" style="background:${wt.c}">${wt.name}</span></span></div>
          <div class="stat-row"><span class="stat-label">射程</span><span class="stat-value">${e.rng}px</span></div>
          <div class="stat-row"><span class="stat-label">伤害</span><span class="stat-value">${e.dmg}</span></div>
          <div class="stat-row"><span class="stat-label">缩放</span><span class="stat-value">×${e.scale.toFixed(2)}</span></div>
          <div class="stat-row"><span class="stat-label">弹道起点</span><span class="stat-value" style="color:#ff6b6b">顶部${firePct.toFixed(1)}%</span></div>
          <div class="edit-section">
            <div class="edit-row"><label style="color:#50c878">脚部ff</label><input type="number" step="0.001" min="0" max="1" value="${e.ff.toFixed(3)}" data-idx="${idx}" data-field="ff"></div>
            <div class="edit-row"><label style="color:#50c878">头部hf</label><input type="number" step="0.001" min="0" max="1" value="${e.hf.toFixed(3)}" data-idx="${idx}" data-field="hf"></div>
            <div class="edit-row"><label style="color:#ff6b6b">弹道起点</label><input type="number" step="1" min="0" max="100" value="${firePct.toFixed(1)}" data-idx="${idx}" data-field="fire_pct"></div>
          </div>
        </div>
      </div>
      <div class="card-footer">
        <span style="color:#50c878">■ 绿点</span>拖拽=脚部/头部 &nbsp;|&nbsp; <span style="color:#ff4040">● 红点</span>拖拽=弹道起点
      </div>
    `;
    grid.appendChild(card);
    setTimeout(() => drawCanvas(idx, e), 10);
  });

  document.querySelectorAll('canvas').forEach(cv => {
    const idx = parseInt(cv.id.replace('cv',''));
    cv.addEventListener('mousedown', e => onCanvasMouseDown(idx, e, cv));
  });
  document.addEventListener('mousemove', e => onCanvasMouseMove(e));
  document.addEventListener('mouseup', () => onCanvasMouseUp());

  document.querySelectorAll('.edit-row input').forEach(inp => {
    inp.addEventListener('change', e => {
      const idx = parseInt(e.target.dataset.idx);
      const field = e.target.dataset.field;
      const val = parseFloat(e.target.value);
      if (isNaN(val)) return;
      if (field === 'fire_pct') {
        const en = enemies[idx];
        const midPct = Math.max(0, Math.min(100, val));
        en.hf = Math.max(en.ff, Math.min(1, (midPct - 50 + en.ff * 50) / 50));
        en.fire_pct = calcFirePct(en);
      } else {
        if (val < 0 || val > 1) { toast('值必须在 0~1 之间','err'); return; }
        enemies[idx][field] = val;
        enemies[idx].fire_pct = calcFirePct(enemies[idx]);
      }
      syncInputs(idx);
      redrawAll();
      toast(enemies[idx].name + ' 已更新','ok');
    });
  });
}

function drawCanvas(idx, e) {
  const cv = document.getElementById('cv' + idx);
  if (!cv) return;
  const ctx = cv.getContext('2d');
  const W = 160, H = 200;
  ctx.clearRect(0, 0, W, H);

  const texH = 160, texW = 64;
  const texX = (W - texW) / 2, texTop = 10;
  const texBot = texTop + texH;

  const footY = texBot - e.ff * texH;
  const headY = texTop + e.hf * texH;
  const entityTop = headY, entityBot = footY;
  const entityH = entityBot - entityTop;
  const fireY = entityTop + entityH * 0.5;
  const firePct = calcFirePct(e);
  const centerX = texX + texW / 2;

  ctx.fillStyle = '#0d1117';
  ctx.fillRect(0, 0, W, H);

  const card = document.querySelector(`.card[data-idx="${idx}"]`);
  const img = card ? card.querySelector('.card-icon') : null;
  if (img && img.naturalWidth > 0) {
    const scale = Math.min(texW / img.naturalWidth, texH / img.naturalHeight);
    const dw = img.naturalWidth * scale, dh = img.naturalHeight * scale;
    ctx.drawImage(img, texX + (texW-dw)/2, texTop + (texH-dh)/2, dw, dh);
  }

  ctx.strokeStyle = '#333'; ctx.lineWidth = 1; ctx.setLineDash([3,3]);
  ctx.strokeRect(texX, texTop, texW, texH);
  ctx.setLineDash([]);

  ctx.fillStyle = 'rgba(80,200,120,0.08)';
  ctx.fillRect(texX, entityTop, texW, entityH);
  ctx.strokeStyle = '#50c878'; ctx.lineWidth = 1.5;
  ctx.strokeRect(texX, entityTop, texW, entityH);

  ctx.strokeStyle = '#50c878'; ctx.lineWidth = 1; ctx.setLineDash([2,2]);
  ctx.beginPath(); ctx.moveTo(texX-4, footY); ctx.lineTo(texX+texW+4, footY); ctx.stroke();
  ctx.setLineDash([]);
  ctx.fillStyle = '#50c878'; ctx.font = '9px sans-serif';
  ctx.fillText('脚部 y='+footY.toFixed(0), texX+texW+4, footY+3);

  ctx.beginPath(); ctx.moveTo(texX-4, headY); ctx.lineTo(texX+texW+4, headY); ctx.stroke();
  ctx.fillText('头部 y='+headY.toFixed(0), texX+texW+4, headY+3);

  ctx.fillStyle = '#ff6b6b'; ctx.font = 'bold 10px sans-serif';
  ctx.fillText('弹道起点', texX+texW+4, fireY-8);
  ctx.font = '9px monospace';
  ctx.fillText('顶部 '+firePct.toFixed(1)+'%', texX+texW+4, fireY+4);

  // Green points - foot and head (larger drag targets)
  ctx.fillStyle = 'rgba(80,200,120,0.3)';
  ctx.beginPath(); ctx.arc(centerX, footY, 14, 0, Math.PI*2); ctx.fill();
  ctx.fillStyle = '#50c878';
  ctx.beginPath(); ctx.arc(centerX, footY, 7, 0, Math.PI*2); ctx.fill();
  ctx.strokeStyle = '#fff'; ctx.lineWidth = 2; ctx.stroke();
  
  ctx.fillStyle = 'rgba(80,200,120,0.3)';
  ctx.beginPath(); ctx.arc(centerX, headY, 14, 0, Math.PI*2); ctx.fill();
  ctx.fillStyle = '#50c878';
  ctx.beginPath(); ctx.arc(centerX, headY, 7, 0, Math.PI*2); ctx.fill();
  ctx.strokeStyle = '#fff'; ctx.lineWidth = 2; ctx.stroke();
  
  // Red point - fire spawn
  ctx.fillStyle = 'rgba(255,64,64,0.25)';
  ctx.beginPath(); ctx.arc(centerX, fireY, 16, 0, Math.PI*2); ctx.fill();
  ctx.fillStyle = '#ff4040';
  ctx.beginPath(); ctx.arc(centerX, fireY, 8, 0, Math.PI*2); ctx.fill();
  ctx.strokeStyle = '#fff'; ctx.lineWidth = 2; ctx.stroke();

  ctx.fillStyle = ERA_COLOR[e.era];
  ctx.fillRect(0, 0, 3, H);
}

function getPointInfo(idx, clickX, clickY) {
  const en = enemies[idx];
  const texH = 160, texW = 64;
  const texX = (160 - texW) / 2, texTop = 10;
  const texBot = texTop + texH;
  
  const footY = texBot - en.ff * texH;
  const headY = texTop + en.hf * texH;
  const entityTop = headY, entityBot = footY;
  const entityH = entityBot - entityTop;
  const fireY = entityTop + entityH * 0.5;
  const centerX = texX + texW / 2;
  
  const distToFoot = Math.sqrt((clickX-centerX)**2 + (clickY-footY)**2);
  const distToHead = Math.sqrt((clickX-centerX)**2 + (clickY-headY)**2);
  const distToFire = Math.sqrt((clickX-centerX)**2 + (clickY-fireY)**2);
  
  if (distToFire < 20) return { type: 'fire' };
  if (distToFoot < 16) return { type: 'ff' };
  if (distToHead < 16) return { type: 'hf' };
  return null;
}

function onCanvasMouseDown(idx, e, cv) {
  const rect = cv.getBoundingClientRect();
  const scaleX = cv.width / rect.width;
  const scaleY = cv.height / rect.height;
  const clickX = (e.clientX - rect.left) * scaleX;
  const clickY = (e.clientY - rect.top) * scaleY;
  
  const point = getPointInfo(idx, clickX, clickY);
  if (point) {
    dragState = { idx, type: point.type };
    e.preventDefault();
  }
}

function onCanvasMouseMove(e) {
  if (!dragState) return;
  
  const canvases = document.querySelectorAll('canvas');
  for (const cv of canvases) {
    const rect = cv.getBoundingClientRect();
    if (e.clientX >= rect.left && e.clientX <= rect.right &&
        e.clientY >= rect.top && e.clientY <= rect.bottom) {
      const idx = parseInt(cv.id.replace('cv',''));
      if (idx === dragState.idx) {
        const scaleX = cv.width / rect.width;
        const scaleY = cv.height / rect.height;
        const clickX = (e.clientX - rect.left) * scaleX;
        const clickY = (e.clientY - rect.top) * scaleY;
        
        const en = enemies[idx];
        const texH = 160, texW = 64;
        const texX = (160 - texW) / 2, texTop = 10;
        const texBot = texTop + texH;
        const centerX = texX + texW / 2;
        
        if (dragState.type === 'ff') {
          const newFF = Math.max(0, Math.min(1, (texBot - clickY) / texH));
          if (Math.abs(newFF - en.ff) > 0.001) {
            en.ff = newFF;
            en.fire_pct = calcFirePct(en);
            syncInputs(idx);
            drawCanvas(idx, en);
          }
        } else if (dragState.type === 'hf') {
          const newHF = Math.max(en.ff, Math.min(1, (clickY - texTop) / texH));
          if (Math.abs(newHF - en.hf) > 0.001) {
            en.hf = newHF;
            en.fire_pct = calcFirePct(en);
            syncInputs(idx);
            drawCanvas(idx, en);
          }
        } else if (dragState.type === 'fire') {
          const midPct = (clickY - texTop) / texH * 100;
          const newHF = Math.max(en.ff, Math.min(1, (midPct - 50 + en.ff * 50) / 50));
          if (Math.abs(newHF - en.hf) > 0.001) {
            en.hf = newHF;
            en.fire_pct = calcFirePct(en);
            syncInputs(idx);
            drawCanvas(idx, en);
          }
        }
      }
    }
  }
}

function onCanvasMouseUp() {
  if (dragState) {
    toast(enemies[dragState.idx].name + ' 已调整','ok');
    dragState = null;
  }
}

function syncInputs(idx) {
  const card = document.querySelector(`.card[data-idx="${idx}"]`);
  if (!card) return;
  const en = enemies[idx];
  card.querySelector('input[data-field="ff"]').value = en.ff.toFixed(3);
  card.querySelector('input[data-field="hf"]').value = en.hf.toFixed(3);
  card.querySelector('input[data-field="fire_pct"]').value = en.fire_pct.toFixed(1);
}

function filterEra(era) {
  currentEra = era;
  document.querySelectorAll('.btn').forEach(b => b.classList.remove('active'));
  event.target.classList.add('active');
  render(era);
}

function redrawAll() {
  enemies.forEach((e, i) => { const cv = document.getElementById('cv'+i); if(cv) drawCanvas(i,e); });
}

function toast(msg, type='info') {
  const t = document.getElementById('toast');
  t.textContent = msg; t.className = 'toast ' + type + ' show';
  setTimeout(() => t.classList.remove('show'), 2000);
}

function exportJSON() {
  const data = JSON.stringify(enemies.map(e => ({
    id:e.id, name:e.name, era:e.era, wt:e.wt,
    rng:e.rng, dmg:e.dmg, scale:e.scale,
    ff:e.ff, hf:e.hf, fire_pct:e.fire_pct
  })), null, 2);
  const blob = new Blob([data], {type:'application/json'});
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a'); a.href = url; a.download = 'enemy_fire_spawn.json'; a.click();
  URL.revokeObjectURL(url);
  toast('JSON 已导出','ok');
}

function exportGD() {
  const lines = ['// 弹道起始点数据 - 来源：enemy_fire_spawn.html','// 使用：var cfg = ENEMY_FIRE_SPAWN.get(archetype_id, {});','const ENEMY_FIRE_SPAWN: Dictionary = {'];
  enemies.forEach(e => {
    lines.push('  "' + e.id + '": {"ff": ' + e.ff.toFixed(4) + ', "hf": ' + e.hf.toFixed(4) + ', "fire_pct": ' + e.fire_pct.toFixed(2) + '},');
  });
  lines.push('};');
  const blob = new Blob([lines.join('\n')], {type:'text/plain'});
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a'); a.href = url; a.download = 'enemy_fire_spawn.gd'; a.click();
  URL.revokeObjectURL(url);
  toast('GDScript 已导出','ok');
}

render('all');
</script>
</body>
</html>'''

with open(r'F:/godot fair duet/create/phase-war/docs/enemy_fire_spawn.html', 'w', encoding='utf-8') as f:
    f.write(html_content)

print('HTML written successfully')
print('Size:', len(html_content), 'chars')
