# -*- coding: utf-8 -*-
"""单位美术资源审查工单页构建器 v2（记录4，用户需求 2026-09-26/27）：
每个单位一行 = [卡图敌][卡图我][idle 循环播放][attack 循环播放] + 问题输入框 + 保存。
帧条滚动到可视区才开始循环播放（idle ping-pong / attack 正向，与引擎一致；点击暂停，顶栏全局暂停）。
卡图配对四层解析：同名直配 → GD manifest dump（.godot/unit_review/gd_icon_map.json，
由 tests/_tmp_dump_icon_map.gd headless 生成，139 archetype 全量）→ unit_animations_extra.json
art 字段 → legacy .godot/anim_icon_map.json。
导出 JSON（含资产路径/帧数/配对来源/自动体检项=修复依据）+ Markdown 修复单；localStorage 自动保存。

用法：python tools/build_unit_review_page.py
输出：tools/unit_art_review.html（自 tools/ 双击打开即用）+ .godot/unit_review/ 预览小图
"""
import hashlib
import io
import json
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIM = os.path.join(ROOT, "assets", "effects", "unit_anims")
ICONS = os.path.join(ROOT, "assets", "card_icons")
PV = os.path.join(ROOT, ".godot", "unit_review")
MAP_PATH = os.path.join(ROOT, ".godot", "anim_icon_map.json")
GD_PATH = os.path.join(PV, "gd_icon_map.json")
EXTRA_PATH = os.path.join(ROOT, "tools", "unit_animations_extra.json")
OUT = os.path.join(ROOT, "tools", "unit_art_review.html")
STRIP_W = 1024


def md5(path):
    return hashlib.md5(open(path, "rb").read()).hexdigest()


def shrink(src, dst, width):
    im = Image.open(src).convert("RGBA")
    if im.width <= width:
        im.save(dst)
        return
    h = max(1, round(im.height * width / im.width))
    im.resize((width, h), Image.LANCZOS).save(dst)


def main():
    os.makedirs(os.path.join(PV, "strips"), exist_ok=True)
    for sub in ("enemy", "player"):
        os.makedirs(os.path.join(PV, "icons", sub), exist_ok=True)
    icon_map = json.load(open(MAP_PATH, encoding="utf-8")) if os.path.exists(MAP_PATH) else {}
    gd_id = {}
    if os.path.exists(GD_PATH):
        gd_id = json.load(open(GD_PATH, encoding="utf-8"))
    gd_rev = {}
    if os.path.exists(GD_PATH):
        for arch, v in json.load(open(GD_PATH, encoding="utf-8")).items():
            k = String_or(v.get("anim", ""))
            if k:
                gd_rev.setdefault(k, []).append((arch, v.get("e", ""), v.get("p", "")))
    extra_art = {}
    if os.path.exists(EXTRA_PATH):
        for uid, v in json.load(open(EXTRA_PATH, encoding="utf-8")).items():
            art = String_or(v.get("art", ""))
            if art:
                extra_art[uid] = art
    # 机检旗标（tools/art_auto_inspect.py 产物）并入行旗标
    auto = {}
    ap = os.path.join(PV, "auto_inspect_v2.json")
    if os.path.exists(ap):
        auto = json.load(open(ap, encoding="utf-8"))
    # 被引用动画键全集（gdmap 每个 id 的解析结果）——判定孤儿动画目录
    used_anim_keys = set()
    if os.path.exists(GD_PATH):
        for v in json.load(open(GD_PATH, encoding="utf-8")).values():
            k = String_or(v.get("anim", ""))
            if k:
                used_anim_keys.add(k)

    used_icons = set()

    def pick(base, side):
        """base 文件名（无扩展）在指定侧存在则返回名字，否则 None，并记账。"""
        if base and os.path.exists(os.path.join(ICONS, side, base + ".png")):
            used_icons.add(side + "/" + base)
            return base
        return None

    def resolve_icons(key):
        """anim key → (enemy_base, player_base, archstr)。四层解析。"""
        e = pick(key, "enemy")
        p = pick(key, "player")
        if e and p:
            return e, p, "同名直配"
        # ② GD manifest dump 反查——多候选跨条目合并（敌图/我图可能来自不同 arch：
        # 冒烟实踩 ww1_mauser 敌图在 ww1_inf_rifle 条目、我图在自身 UCT 条目，
        # 首候选早退会丢另一侧）
        def clean_arch(a):
            if a.startswith("foe_"):
                a = a[4:]
            if a.startswith("captured_"):
                a = a[9:]
            return a

        ranked = sorted(gd_rev.get(key, []), key=lambda t: 0 if clean_arch(t[0]) == key else 1)
        e2, p2, src = e, p, ("同名直配" if (e or p) else "")
        for arch, ep, pp in ranked:
            if e2 and p2:
                break
            ebase = os.path.basename(ep)[:-4] if ep else None
            pbase = os.path.basename(pp)[:-4] if pp else None
            if not e2 and ebase:
                got = pick(ebase, "enemy")
                if got:
                    e2, src = got, "via archetype " + arch
            if not p2 and pbase:
                got = pick(pbase, "player")
                if got and not p2:
                    p2 = got
                    if src == "":
                        src = "via archetype " + arch
            # arch 自名单侧补（敌方卡图常按卡 id 命名而非 vis 编号，如 enemy/ww1_sup_vickers.png）
            ca = clean_arch(arch)
            if not e2:
                got = pick(ca, "enemy")
                if got:
                    e2, src = got, ("via arch 自名 " + ca)
            if not p2:
                got = pick(ca, "player")
                if got:
                    p2 = got
                    if src == "":
                        src = "via arch 自名 " + ca
        # vis 镜像互推（约定：vis_enemy_NNN=敌原图 / vis_player_NNN=其水平翻转，编号同轴）
        if p2 and not e2 and "vis_player_" in p2:
            got = pick(p2.replace("vis_player_", "vis_enemy_", 1), "enemy")
            if got:
                e2 = got
        if e2 and not p2 and "vis_enemy_" in e2:
            got = pick(e2.replace("vis_enemy_", "vis_player_", 1), "player")
            if got:
                p2 = got
        if e2 or p2:
            return e2, p2, src
        # ③ unit_animations_extra.json art 字段（敌版；我版按 vis_player 换算）
        art = extra_art.get(key, "")
        if art:
            ebase = os.path.basename(art)[:-4]
            e2 = e or pick(ebase, "enemy")
            pbase = ebase.replace("vis_enemy_", "vis_player_", 1)
            p2 = p or pick(pbase, "player")
            if e2 or p2:
                return e2, p2, "via extra art"
        # ④ legacy anim_icon_map.json
        mi = icon_map.get(key, {}).get("icon", "")
        if mi:
            pbase = os.path.basename(mi)[:-4]
            ebase = pbase.replace("vis_player_", "vis_enemy_", 1)
            e2 = e or pick(ebase, "enemy")
            p2 = p or pick(pbase, "player")
            if e2 or p2:
                return e2, p2, "via anim_icon_map"
        return e, p, "无配对"

    units = []
    for key in sorted(os.listdir(ANIM)):
        d = os.path.join(ANIM, key)
        if not os.path.isdir(d):
            continue
        u = {"key": key, "kind": "anim"}
        counts, fs, fps = {}, 256, 8
        aj = os.path.join(d, "anim.json")
        if os.path.exists(aj):
            j = json.load(open(aj, encoding="utf-8"))
            counts = j.get("counts", {})
            fs = int(j.get("frame_size", 256))
            fps = j.get("fps", 8)
        u["counts"], u["frame_size"], u["fps"] = counts, fs, fps
        flags = []
        si, sa = os.path.join(d, "sheet_idle.png"), os.path.join(d, "sheet_attack.png")
        if os.path.exists(si):
            w, h = Image.open(si).size
            u["idle_sheet"] = "assets/effects/unit_anims/%s/sheet_idle.png" % key
            u["idle_w"] = w
            decl = int(counts.get("idle", 0))
            if decl and w != decl * fs:
                flags.append("IDLE帧数不配: 声明%d帧×%d=%dpx 但图宽%dpx" % (decl, fs, decl * fs, w))
            dst_i = os.path.join(PV, "strips", "%s_idle.png" % key)
            if not os.path.exists(dst_i) or os.path.getmtime(si) > os.path.getmtime(dst_i):
                shrink(si, dst_i, STRIP_W)
        if os.path.exists(sa):
            w, h = Image.open(sa).size
            u["attack_sheet"] = "assets/effects/unit_anims/%s/sheet_attack.png" % key
            u["attack_w"] = w
            decl = int(counts.get("attack", 0))
            if decl and w != decl * fs:
                flags.append("ATTACK帧数不配: 声明%d帧×%d=%dpx 但图宽%dpx" % (decl, fs, decl * fs, w))
            if os.path.exists(si) and md5(si) == md5(sa):
                flags.append("attack=idle 复制（fix3 用户拍板设计，非缺陷）")
                u["attack_same"] = True
            dst_a = os.path.join(PV, "strips", "%s_attack.png" % key)
            if not os.path.exists(dst_a) or os.path.getmtime(sa) > os.path.getmtime(dst_a):
                shrink(sa, dst_a, STRIP_W)
        f0 = os.path.join(d, "attack_f0.png")
        bf0 = os.path.join(d, "idle_f0.png")
        if not os.path.exists(si) and os.path.exists(f0):
            u["attack_f0"] = "assets/effects/unit_anims/%s/attack_f0.png" % key
            shared = String_or(gd_id.get(key, {}).get("anim", ""))
            if shared and shared != key:
                u["arch"] = "共享动画 via %s（运行时播共享链动画；本目录仅攻击姿态帧）" % shared
                flags.append("共享动画 via %s + 攻击姿态帧（合法）" % shared)
            else:
                flags.append("AttackPoseAnim 仅姿态帧（合法，非 sheet 型）")
        elif not os.path.exists(si) and os.path.exists(bf0):
            # BossIdleAnim 头目单帧序列系统（idle_f0..N 直读，不经 UnitFrameAnim 解析链）——非孤儿
            bfs = sorted(x for x in os.listdir(d) if x.startswith("idle_f") and x.endswith(".png"))
            if bfs:
                im0 = Image.open(os.path.join(d, bfs[0])).convert("RGBA")
                fw, fh = im0.size
                strip = Image.new("RGBA", (fw * len(bfs), fh), (0, 0, 0, 0))
                for i, x in enumerate(bfs):
                    strip.alpha_composite(Image.open(os.path.join(d, x)).convert("RGBA"), (i * fw, 0))
                dst_i = os.path.join(PV, "strips", "%s_idle.png" % key)
                strip.resize((STRIP_W, max(1, round(fh * STRIP_W / strip.width))), Image.LANCZOS).save(dst_i)
                u["counts"]["idle"] = len(bfs)
                u["frame_size"] = fw
                u["idle_w"] = fw * len(bfs)
                u["boss_frames"] = True
                flags.append("BossIdleAnim 头目单帧序列 %d 帧（合法，非 sheet 型）" % len(bfs))
        e, p, arch = resolve_icons(key)
        u["enemy_icon"], u["player_icon"], u["arch"] = e, p, arch
        if u.get("attack_f0"):
            # AttackPoseAnim 走独立姿态系统（不经 UnitFrameAnim 解析链），非孤儿
            u["arch"] = "AttackPoseAnim（攻击姿态系统引用）"
        elif u.get("boss_frames"):
            u["arch"] = "BossIdleAnim（头目单帧序列系统引用）"
        elif key not in used_anim_keys:
            u["arch"] = "孤儿动画目录：无任何单位解析至此"
            flags.append("孤儿动画目录（疑似退役资产，无单位引用）")
        if e is None and p is None:
            if u.get("attack_f0"):
                pass  # 姿态帧型无卡图属正常（系统用 attack_f0.png 渲染）
            elif key in used_anim_keys:
                flags.append("被引用但四层解析均未配到卡图（真映射缺口，需人工补 vis 映射）")
            else:
                flags.append("无卡图（随孤儿目录，无需配对）")
        a = auto.get(key, {})
        if "shadow" in a:
            flags.append("机检:动画待机帧疑阴影/残留(%.2f)" % a["shadow"])
        if "sway" in a:
            flags.append("机检:待机摆幅偏大(%.3f)" % a["sway"])
        if "flash_mis" in a:
            fm = a["flash_mis"]
            flags.append("机检:开火亮块离枪口锚点远(帧%d d=%.2f)" % (fm[0], fm[3]))
        u["flags"] = flags
        units.append(u)

    # 孤儿卡图（未被任何动画行消费）：按底名聚合敌我
    orphan = {}
    for sub in ("enemy", "player"):
        d = os.path.join(ICONS, sub)
        for f in sorted(os.listdir(d)):
            if not f.endswith(".png"):
                continue
            rel = sub + "/" + f[:-4]
            if rel in used_icons:
                continue
            orphan.setdefault(f[:-4], {})[sub] = rel
    for base, sides in sorted(orphan.items()):
        u = {"key": base, "kind": "icon_only"}
        u["enemy_icon"] = base if "enemy" in sides else None
        u["player_icon"] = base if "player" in sides else None
        shared = String_or(gd_id.get(base, {}).get("anim", ""))
        if shared:
            u["arch"] = "共享动画 via %s（EnemyCardModMap/visual 链，无独立 sheet）" % shared
            u["flags"] = ["共享他卡动画（运行时有动画；本页无独立条带）"]
        else:
            u["arch"] = "纯卡图行（无对应动画行消费）"
            u["flags"] = ["无帧动画（静态卡图回退或纯 UI 引用）"]
        units.append(u)

    for u in units:
        for side in ("enemy", "player"):
            b = u.get(side + "_icon")
            if b:
                src = os.path.join(ICONS, side, b + ".png")
                dst = os.path.join(PV, "icons", side, b + ".png")
                if not os.path.exists(dst) or os.path.getmtime(src) > os.path.getmtime(dst):
                    shrink(src, dst, 128)

    # 处理意见种子（机检/待办结论预填，用户编辑后成为正式批注）
    seed_path = os.path.join(PV, "review_notes_seed.json")
    seed_notes = {}
    if os.path.exists(seed_path):
        seed_notes = json.load(open(seed_path, encoding="utf-8"))
    for u in units:
        if u["key"] in seed_notes:
            u["note_seed"] = seed_notes[u["key"]]
    data = json.dumps(units, ensure_ascii=False, separators=(",", ":"))
    html = TEMPLATE.replace("__DATA__", data)
    io.open(OUT, "w", encoding="utf-8", newline="\n").write(html)
    n_anim = sum(1 for u in units if u["kind"] == "anim")
    no_pair = sum(1 for u in units if u["kind"] == "anim" and not u["enemy_icon"] and not u["player_icon"])
    print("units=%d (anim=%d icon_only=%d) anim缺卡图=%d -> %s (%.1f KB)" % (
        len(units), n_anim, len(units) - n_anim, no_pair, OUT, os.path.getsize(OUT) / 1024))


def String_or(v):
    return v if isinstance(v, str) else ""


TEMPLATE = r'''<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>单位美术资源审查工单</title>
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
.meta{width:175px;min-width:175px}
.meta .k{font-weight:bold;color:#8df;font-size:13px;word-break:break-all}
.meta .sub{font-size:11px;color:#789;margin-top:3px;line-height:1.5}
.meta .arch{font-size:10px;color:#5a7;margin-top:3px;word-break:break-all}
.flag{display:inline-block;background:#4a1f1f;color:#fba;border:1px solid #a54;border-radius:3px;padding:1px 5px;font-size:10px;margin:2px 2px 0 0}
.flag.ok{background:#1f3a24;color:#bd9;border-color:#5a6}
.cell{width:112px;min-width:112px;text-align:center}
.cell.strip{width:300px;min-width:300px;text-align:center}
.cell img{max-width:100%;max-height:120px;object-fit:contain;background:#20202a;border:1px solid #333;cursor:zoom-in;display:block;margin:0 auto}
.anim{display:inline-block;background-repeat:no-repeat;background-size:1024px auto;background-color:#20202a;border:1px solid #333;cursor:pointer;max-width:100%}
.anim.paused{outline:2px solid #f80;outline-offset:-2px}
.cell .cap{font-size:10px;color:#678;margin-top:2px}
.cell .missing{width:80px;height:96px;background:#222;border:1px dashed #444;display:flex;align-items:center;justify-content:center;color:#556;font-size:10px;margin:0 auto}
.edit{flex:1;min-width:280px}
.edit textarea{width:100%;height:64px;background:#0e0e14;color:#eee;border:1px solid #345;border-radius:4px;padding:6px;font-size:13px;font-family:inherit;box-sizing:border-box}
.edit textarea:focus{border-color:#4af}
.edit .st{font-size:11px;color:#678;margin-top:3px;display:flex;gap:8px;align-items:center}
.dot{width:8px;height:8px;border-radius:50%;background:#556;display:inline-block}
.dot.saved{background:#2b5}
.dot.dirty{background:#f80}
h1.page{color:#6cf;font-size:18px;margin:10px 4px}
.count{color:#fa0}
</style></head><body>
<div class="bar">
<h1>单位美术资源审查工单</h1>
<input type="text" id="filter" placeholder="筛选：单位名 / 已填问题…">
<span class="note">已填 <b class="count" id="cnt">0</b> / <span id="total"></span></span>
<button id="toggleAnim" class="on">⏸ 动画播放中（点击全局暂停）</button>
<button id="saveAll">💾 保存全部（下载 JSON）</button>
<button id="copyAll">📋 复制 JSON</button>
<label style="cursor:pointer"><input type="file" id="importFile" accept=".json" style="display:none"><button onclick="document.getElementById('importFile').click()" type="button">⬆ 导入 JSON</button></label>
<button id="exportMd">📄 导出修复单（Markdown）</button>
<button id="copyMd">📋 复制修复单</button>
<span class="note">帧条滚动到可视区即循环播放（idle 往返 / attack 正向，点击单条可暂停）；输入自动存浏览器；「保存全部」下载 JSON=修复依据。</span>
</div>
<h1 class="page">每行一个单位：卡图敌 · 卡图我 · IDLE 循环 · ATTACK 循环 —— 行尾写问题</h1>
<div class="note" style="margin:0 12px 8px">「孤儿动画目录」旗标口径=解析链五步全 miss（id 全集含 UCT 卡 ∪ manifest 条目 ∪ 敌形映射 ∪ 相位师平台 id），共 19 个真孤儿；分类与去留建议见 <b>docs/孤儿动画目录审计_2026-09-28.md</b>。BossIdleAnim（头目单帧序列）与 AttackPoseAnim（攻击姿态帧）走独立系统，不计孤儿。</div>
<div id="list"></div>
<script>
const DATA = __DATA__;
const LS = "unit_art_review_notes_v1";
let notes = {};
try { notes = JSON.parse(localStorage.getItem(LS) || "{}"); } catch(e) { notes = {}; }
const $ = s => document.querySelector(s);
function esc(s){return String(s||"").replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;")}

function iconRel(u, side){ const b = u[side+"_icon"]; return b ? ("../.godot/unit_review/icons/"+side+"/"+b+".png") : null; }
function origIcon(u, side){ const b = u[side+"_icon"]; return b ? ("../assets/card_icons/"+side+"/"+b+".png") : null; }

function iconCell(u, side){
  const o = origIcon(u, side), r = iconRel(u, side);
  if(!o) return '<div class="cell"><div class="missing">无'+(side==="enemy"?"敌":"我")+'版</div><div class="cap">—</div></div>';
  return '<div class="cell"><a href="'+o+'" target="_blank"><img loading="lazy" src="'+r+'"></a><div class="cap">'+(side==="enemy"?"卡图·敌":"卡图·我")+'</div></div>';
}
function animCell(u, side){
  const sheet = u[side+"_sheet"];
  const c = u.counts || {};   // icon_only 行无 counts——冒烟实测在此崩断导致全页动画失效
  const n = side==="idle" ? (c.idle||0) : (c.attack||0);
  if(sheet && n>0){
    const fw = 1024/n;
    const src = "../.godot/unit_review/strips/"+u.key+"_"+side+".png";
    const mode = side==="idle" ? "pingpong" : "loop";
    return '<div class="cell strip"><div class="anim" data-n="'+n+'" data-fps="'+(u.fps||8)+'" data-fw="'+fw.toFixed(2)+'" data-mode="'+mode+'" style="width:'+fw.toFixed(1)+'px;height:'+fw.toFixed(1)+'px;background-image:url(\''+src+'\')" title="IDLE '+(side==="idle"?u.idle_w:"")+' · 点击暂停/播放"></div><div class="cap">'+side.toUpperCase()+' '+n+'帧 '+(mode==="pingpong"?"往返":"正向")+'</div></div>';
  }
  if(u.attack_f0 && side==="attack"){
    return '<div class="cell strip"><a href="../'+u.attack_f0+'" target="_blank"><img loading="lazy" style="max-height:120px" src="../'+u.attack_f0+'"></a><div class="cap">ATTACK_F0 静态</div></div>';
  }
  return '<div class="cell strip"><div class="missing">无</div><div class="cap">—</div></div>';
}

function render(){
  const q = $("#filter").value.trim().toLowerCase();
  const list = $("#list"); list.innerHTML = "";
  let shown = 0;
  for(const u of DATA){
    const seed = u.note_seed || "";
    const note = (notes[u.key]||{}).note || seed;
    if(q && !(u.key.toLowerCase().includes(q) || note.toLowerCase().includes(q))) continue;
    shown++;
    const flags = (u.flags||[]).map(f=>{
      const ok = f.includes("非缺陷") || f.includes("合法");
      return '<span class="flag'+(ok?" ok":"")+'">'+esc(f)+'</span>';
    }).join("");
    const sub = u.kind==="anim"
      ? "动画 "+(u.fps||8)+"fps · idle "+((u.counts||{}).idle||0)+"帧 · attack "+((u.counts||{}).attack||0)+"帧 · 帧格"+(u.frame_size||"?")+"px"
      : "纯卡图（无帧动画目录）";
    const div = document.createElement("div");
    div.className = "row"; div.dataset.key = u.key;
    div.innerHTML =
      '<div class="meta"><div class="k">'+esc(u.key)+'</div><div class="sub">'+sub+'</div><div class="arch">'+esc(u.arch||"")+'</div><div>'+flags+'</div></div>'
      + iconCell(u,"enemy") + iconCell(u,"player") + animCell(u,"idle") + animCell(u,"attack")
      + '<div class="edit"><textarea placeholder="在此写明该单位美术资源的问题（改什么/为什么/参考哪个单位）…" data-k="'+esc(u.key)+'">'+esc(note)+'</textarea>'
      + '<div class="st"><span class="dot" id="dot-'+esc(u.key)+'"></span><span id="st-'+esc(u.key)+'">'+(note?"有批注（浏览器已存）":"")+'</span>'
      + '<button data-save="'+esc(u.key)+'">保存本行</button></div></div>';
    list.appendChild(div);
  }
  $("#total").textContent = DATA.length;
  updateCnt();
  if(!shown){ list.innerHTML = '<div style="padding:30px;color:#667">无匹配单位</div>'; }
  setupAnims();
}

/* ── 动画循环：单 rAF 驱动，滚动到可视区才步进（idle 往返 / attack 正向）── */
let animOn = true;
const visEls = new Set();
let io = null;
function setupAnims(){
  visEls.clear();
  const els = document.querySelectorAll(".anim");
  if(!("IntersectionObserver" in window)){ els.forEach(el=>visEls.add(el)); return; }
  if(io) io.disconnect();
  io = new IntersectionObserver(es=>{
    for(const en of es){
      if(en.isIntersecting) visEls.add(en.target); else visEls.delete(en.target);
    }
  }, {rootMargin:"150px"});
  els.forEach(el=>io.observe(el));
  console.log("[review] 动画元素:", els.length, "（滚动到行即播放；全部静止=点顶栏检查全局暂停态）");
}
let _lastT = performance.now();
function _tick(now){
  const dt = Math.min(0.1, (now - _lastT) / 1000); _lastT = now;
  if(animOn){
    visEls.forEach(el=>{
      if(el._userPaused) return;
      const n = +el.dataset.n; if(!(n > 1)) return;
      const fps = +el.dataset.fps || 8;
      const fw = +el.dataset.fw || 1;
      el._acc = (el._acc || 0) + dt * fps;
      let i;
      if(el.dataset.mode === "loop"){ i = Math.floor(el._acc) % n; }
      else { const period = 2*n - 2; const t = Math.floor(el._acc) % period; i = (t < n) ? t : period - t; }
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
function updateCnt(){ $("#cnt").textContent = Object.values(notes).filter(n=>n.note && n.note.trim()).length; }
let t = null;
document.addEventListener("input", e=>{
  if(e.target.tagName!=="TEXTAREA") return;
  const k = e.target.dataset.k;
  notes[k] = notes[k]||{}; notes[k].note = e.target.value;
  notes[k].updated = new Date().toISOString();
  const dot = document.getElementById("dot-"+CSS.escape(k)), st = document.getElementById("st-"+CSS.escape(k));
  if(dot) dot.className = "dot dirty";
  if(st) st.textContent = "未保存到浏览器…";
  clearTimeout(t);
  t = setTimeout(()=>{ persist(); markRow(k,"saved","已自动保存（浏览器）"); }, 500);
});
document.addEventListener("click", e=>{
  if(e.target.classList && e.target.classList.contains("anim")){
    e.target._userPaused = !e.target._userPaused;
    e.target.classList.toggle("paused", e.target._userPaused);
    return;
  }
  const b = e.target.closest("button"); if(!b) return;
  if(b.dataset.save){ persist(); markRow(b.dataset.save,"saved","已保存（浏览器）"); }
});
function markRow(k, cls, txt){
  const dot = document.getElementById("dot-"+CSS.escape(k)), st = document.getElementById("st-"+CSS.escape(k));
  if(dot) dot.className = "dot "+cls;
  if(st) st.textContent = txt + " · " + new Date().toLocaleTimeString();
  updateCnt();
}
function persist(){ try{ localStorage.setItem(LS, JSON.stringify(notes)); }catch(e){ alert("浏览器存储失败："+e); } }
function payload(){
  const units = {};
  for(const u of DATA){
    const n = notes[u.key];
    units[u.key] = {
      note: (n&&n.note)||"",
      updated: (n&&n.updated)||null,
      kind: u.kind,
      mapping: u.arch||"",
      assets: {
        enemy_icon: u.enemy_icon ? "assets/card_icons/enemy/"+u.enemy_icon+".png" : null,
        player_icon: u.player_icon ? "assets/card_icons/player/"+u.player_icon+".png" : null,
        idle_sheet: u.idle_sheet||null, attack_sheet: u.attack_sheet||null, attack_f0: u.attack_f0||null
      },
      anim: {fps:u.fps, frame_size:u.frame_size, counts:u.counts},
      auto_flags: u.flags
    };
  }
  return {_meta:{tool:"unit_art_review", exported:new Date().toISOString(), units_total:DATA.length,
                 filled:Object.values(notes).filter(n=>n.note&&n.note.trim()).length}, units};
}
function download(name, text){
  const a = document.createElement("a");
  a.href = URL.createObjectURL(new Blob([text], {type:"application/octet-stream"}));
  a.download = name; a.click();
}
$("#saveAll").onclick = ()=>{ persist();
  download("art_review_notes_"+new Date().toISOString().slice(0,10)+".json", JSON.stringify(payload(),null,1));
};
$("#copyAll").onclick = ()=>{ persist(); navigator.clipboard.writeText(JSON.stringify(payload(),null,1))
  .then(()=>alert("JSON 已复制——可直接粘贴给修复方或存为 tools/art_review_notes.json")); };
$("#importFile").onchange = e=>{
  const f = e.target.files[0]; if(!f) return;
  const r = new FileReader();
  r.onload = ()=>{ try{
      const j = JSON.parse(r.result);
      const units = j.units||j;
      let n = 0;
      for(const k in units){ if(units[k] && units[k].note){ notes[k] = {note:units[k].note, updated:units[k].updated}; n++; } }
      persist(); render();
      alert("已导入 "+n+" 条批注");
    }catch(err){ alert("导入失败："+err); } };
  r.readAsText(f);
};
function markdown(){
  let out = [];
  out.push("# 美术资源修复单（"+new Date().toLocaleString()+"）");
  out.push("> 来源：tools/unit_art_review.html 导出；每个单位一行问题，资产路径可直接定位文件。");
  for(const u of DATA){
    const n = notes[u.key];
    const note = (n&&n.note)||"";
    if(!note.trim()) continue;
    out.push("\n## "+u.key);
    out.push("- 配对: "+(u.arch||""));
    out.push("- 卡图敌: "+(u.enemy_icon?"assets/card_icons/enemy/"+u.enemy_icon+".png":"无")+" ｜ 卡图我: "+(u.player_icon?"assets/card_icons/player/"+u.player_icon+".png":"无"));
    out.push("- 动画: "+(u.idle_sheet||u.attack_f0||"无")+(u.attack_sheet?" ｜ attack: "+u.attack_sheet:""));
    if(u.kind==="anim") out.push("- 帧数: idle "+(u.counts.idle||0)+" / attack "+(u.counts.attack||0)+" @ "+(u.fps||8)+"fps 帧格"+u.frame_size);
    const fl = (u.flags||[]).filter(f=>!f.includes("非缺陷")&&!f.includes("合法"));
    if(fl.length) out.push("- 自动体检: "+fl.join("；"));
    out.push("- 问题: "+note.trim().replace(/\n/g,"\n  "));
  }
  if(out.length<=2){ alert("还没有任何批注"); return null; }
  return out.join("\n");
}
$("#exportMd").onclick = ()=>{ const m = markdown(); if(m) download("art_fix_ticket_"+new Date().toISOString().slice(0,10)+".md", m); };
$("#copyMd").onclick = ()=>{ const m = markdown(); if(m) navigator.clipboard.writeText(m).then(()=>alert("修复单已复制")); };
$("#filter").oninput = render;
render();
</script></body></html>
'''

if __name__ == "__main__":
    main()
