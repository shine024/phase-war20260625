#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v26 美术预览页生成：卡图 8 + 改造图标 12 + 帧动画 8 单位×idle/attack。
输出 docs/v26_美术预览.html（相对路径引用原图/帧，用户浏览器打开预览）。
动画区带 JS 逐帧播放器（8fps），透明帧铺深色战场底。"""
import json
import os
import urllib.parse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "docs")
CARD_DIR = os.path.join(DOCS, "待生成卡图_v26飞机")
ICON_DIR = os.path.join(DOCS, "待生成改造图标_v26")
ANIM_ROOT = os.path.join(ROOT, "资料", "单位分帧动画")
OUT = os.path.join(DOCS, "v26_美术预览.html")

UNITS = [
    ("ww2_air_bomber", "B-17 空中堡垒", "era1 战略轰炸"),
    ("ww2_air_dive_bomber", "Ju 87 斯图卡", "era1 俯冲轰炸"),
    ("cold_air_strike_fighter", "F-111 战斗轰炸机", "era2 多用途雏形"),
    ("cold_air_bomber", "图-95 战略轰炸机", "era2 战略轰炸"),
    ("mod_air_multirole", "F-15E 攻击鹰", "era3 多用途空优+对地"),
    ("mod_air_bomber", "B-52 同温层堡垒", "era3 地毯轰炸"),
    ("fut_air_stealth_multirole", "六代隐身战机", "era4 隐身多用途"),
    ("fut_air_stealth_bomber", "B-21 隐身轰炸机", "era4 隐身轰炸"),
]

ICON_NAMES = {
    "air_17_bombsight": "轰炸瞄准具", "air_18_heavy_rack": "重载挂架",
    "air_19_cluster_dispenser": "集束布撒器", "air_20_standoff_missile": "防区外导弹",
    "air_21_terrain_radar": "地形跟随雷达", "air_22_countermeasure": "干扰弹布撒器",
    "arm_17_spacer_armor": "附加钢板", "arm_18_gun_mantlet": "厚重炮盾",
    "aa_14_searchlight": "探照灯组", "aa_15_flak_burst": "定时引信防空弹",
    "for_14_bomb_shelter": "防空洞加固", "gen_stealth_coating": "雷达吸波涂层",
}


def rel_url(path_from_docs: str) -> str:
    return urllib.parse.quote(path_from_docs.replace("\\", "/"))


def find_anim_dir(unit_id: str):
    for d in sorted(os.listdir(ANIM_ROOT)):
        if unit_id in d and os.path.isdir(os.path.join(ANIM_ROOT, d)):
            return d
    return None


def card_cell(fname: str, cn: str, note: str) -> str:
    return (
        '<figure class="cell"><img src="%s" loading="lazy">'
        "<figcaption><b>%s</b><span>%s</span><code>%s</code></figcaption></figure>"
        % (rel_url("待生成卡图_v26飞机/" + fname), cn, note, fname.replace(".png", ""))
    )


def icon_cell(fname: str, cn: str) -> str:
    return (
        '<figure class="cell ic"><img src="%s" loading="lazy">'
        "<figcaption><b>%s</b><code>%s</code></figcaption></figure>"
        % (rel_url("待生成改造图标_v26/" + fname), cn, fname.replace(".png", ""))
    )


def anim_block(unit_id: str, cn: str, note: str) -> str:
    d = find_anim_dir(unit_id)
    if d is None:
        return '<section class="unit missing"><h3>%s（%s）</h3><p class="miss">⚠ 未找到帧目录</p></section>' % (cn, note)
    parts = ['<section class="unit"><h3>%s <code>%s</code><span class="note">%s</span></h3>' % (cn, unit_id, note)]
    for anim in ("idle", "attack"):
        adir = os.path.join(ANIM_ROOT, d, anim)
        meta_p = os.path.join(adir, "meta.json")
        frames = []
        fps = 8
        if os.path.isfile(meta_p):
            with open(meta_p, "r", encoding="utf-8") as f:
                meta = json.load(f)
            frames = meta.get("frame_files", [])
            fps = int(meta.get("suggested_fps", 8))
        else:
            frames = sorted(x for x in os.listdir(adir) if x.startswith("f") and x.endswith(".png")) if os.path.isdir(adir) else []
        if not frames:
            parts.append('<div class="anim miss">⚠ %s 无帧</div>' % anim)
            continue
        base = rel_url("../资料/单位分帧动画/%s/%s/" % (d, anim))
        imgs = "".join('<img src="%s%s" loading="lazy">' % (base, fn) for fn in frames)
        strip = "".join(
            '<figure class="fr"><img src="%s%s" loading="lazy"><figcaption>%s</figcaption></figure>' % (base, fn, fn.replace(".png", ""))
            for fn in frames
        )
        parts.append(
            '<div class="anim"><div class="label">%s · %d 帧 · %dfps</div>'
            '<div class="player" data-fps="%d">%s</div>'
            '<div class="strip">%s</div></div>' % (anim, len(frames), fps, fps, imgs, strip)
        )
    parts.append("</section>")
    return "".join(parts)


def main() -> None:
    cards = sorted(x for x in os.listdir(CARD_DIR) if x.endswith(".png"))
    icons = sorted(x for x in os.listdir(ICON_DIR) if x.endswith(".png"))

    card_map = {u: f for f in cards for u in UNITS if f.startswith(u[0])}
    # 卡图文件名即 card_id.png
    sec_cards = []
    for uid, cn, note in UNITS:
        f = uid + ".png"
        if f in cards:
            sec_cards.append(card_cell(f, cn, note))
        else:
            sec_cards.append('<figure class="cell missing"><p class="miss">⚠ 缺 %s</p></figure>' % uid)

    sec_icons = [icon_cell(f, ICON_NAMES.get(f.replace(".png", ""), f)) for f in icons]
    sec_anims = "".join(anim_block(u, c, n) for u, c, n in UNITS)

    html = """<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<title>v26 美术预览——8 新飞机卡图 / 12 改造图标 / 帧动画</title>
<style>
 body{background:#101319;color:#dde3ec;font:14px/1.5 "Microsoft YaHei",sans-serif;margin:24px;max-width:1500px}
 h1{font-size:22px} h2{margin-top:36px;border-left:4px solid #4da3ff;padding-left:10px;font-size:18px}
 .sub{color:#8b95a5;font-size:13px;margin:4px 0 14px}
 .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:14px}
 .grid.icons{grid-template-columns:repeat(auto-fill,minmax(170px,1fr))}
 .cell{margin:0;background:#fff;border-radius:8px;padding:8px;text-align:center}
 .cell img{width:100%;height:auto;border-radius:4px}
 .cell.ic img{width:150px;height:150px;object-fit:contain}
 figcaption b{display:block;color:#1c2230;font-size:14px}
 figcaption span{color:#5a6474;font-size:12px;display:block}
 figcaption code{color:#7a8496;font-size:11px}
 .unit{background:#1a1f2a;border-radius:10px;padding:14px;margin:14px 0}
 .unit h3{margin:0 0 10px;font-size:16px} .unit .note{color:#8b95a5;font-weight:normal;font-size:12px;margin-left:8px}
 .anim{margin:10px 0} .anim .label{color:#9fb0c8;font-size:12px;margin-bottom:6px}
 .player{position:relative;width:256px;height:256px;background:#232a38;border:1px solid #33405a;border-radius:8px;overflow:hidden}
 .player img{position:absolute;inset:0;width:100%;height:100%;object-fit:contain;opacity:0;transition:none}
 .player img.on{opacity:1}
 .strip{display:flex;flex-wrap:wrap;gap:6px;margin-top:8px}
 .fr{margin:0;background:#232a38;border-radius:6px;padding:4px;text-align:center}
 .fr img{width:110px;height:110px;object-fit:contain;display:block}
 .fr figcaption{color:#77839a;font-size:10px}
 .miss{color:#ff9d66}
 code{font-family:Consolas,monospace}
</style></head><body>
<h1>v26 美术预览（未部署——确认后执行 deploy）</h1>
<p class="sub">卡图/图标为 API 白底原图；部署时白底转透明 + 512²（卡图）/图标落位。动画帧已抠透明，深色底模拟战场。</p>

<h2>一、新飞机卡图（8 张，D 段 card_id 命名）</h2>
<p class="sub">生成原图朝左（敌方），部署时我方版=水平翻转。数量/数值已入 UCT 与 manifest。</p>
<div class="grid">__CARDS__</div>

<h2>二、新改造图标（12 张）</h2>
<p class="sub">部署到 assets/ui/icons/mod_icons/&lt;mod_id&gt;.png 并挂到 12 条新改造条目 icon 字段。</p>
<div class="grid icons">__ICONS__</div>

<h2>三、帧动画（8 单位 × idle/attack，自动播放 8fps）</h2>
<p class="sub">部署时经 deploy_unit_anims.py 进 assets/effects/unit_anims/。</p>
__ANIMS__

<script>
document.querySelectorAll('.player').forEach(function(p){
  var imgs=p.querySelectorAll('img');var i=0;
  if(imgs.length){imgs[0].classList.add('on');}
  var fps=parseInt(p.dataset.fps||'8',10);
  setInterval(function(){
    if(!imgs.length)return;
    imgs[i].classList.remove('on');i=(i+1)%imgs.length;imgs[i].classList.add('on');
  },1000/fps);
});
</script>
</body></html>"""
    html = html.replace("__CARDS__", "".join(sec_cards)).replace("__ICONS__", "".join(sec_icons)).replace("__ANIMS__", sec_anims)

    with open(OUT, "w", encoding="utf-8") as f:
        f.write(html)
    print("预览页：%s（卡 %d / 图标 %d）" % (OUT, len(cards), len(icons)))


if __name__ == "__main__":
    main()
