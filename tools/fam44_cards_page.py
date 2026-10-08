# -*- coding: utf-8 -*-
"""fam44 生图批目检页：7 案 raw + 推导卡预览 + m1a2sep 三路线对比。

用法: python tools/fam44_cards_page.py
读: .godot/unit_review/fam44_cards_redo/<key>_raw.png（生图，朝右）
    + mod_arm_m1a2sep_cardE/P_local.png（锚定本地推导，朝左）
产物: .godot/unit_review/fam44_cards.html + fam44_cards_web/
导出: fam44_cards.json → {key: {status, note}}
"""
import glob
import json
import os
import re

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAGE = os.path.join(ROOT, ".godot", "unit_review", "fam44_cards_redo")
WEB = os.path.join(ROOT, ".godot", "unit_review", "fam44_cards_web")
CARD_MAX = 450

# (key, 显示名, 用途注)
UNITS = [
    ("fe_quantum_mobile_base", "移动堡垒基地", "卡图+待机+攻击全重做（新锚定→codeanim）"),
    ("fe_quantum_repair_drone", "纳米修复蜂群", "卡图+待机+攻击全重做（新锚定→codeanim）"),
    ("fe_void_dimensional_soldier", "次元行者", "卡图+待机+攻击全重做（新锚定→codeanim）"),
    ("fe_frontier_veteran", "边境老兵", "改攻击姿势（据枪瞄准）→新锚定→codeanim"),
    ("fe_iron_wall_juggernaut", "重装先驱", "抬枪动作图（枪口上抬）→新锚定→codeanim"),
    ("mod_arm_stryker_e", "斯特赖克(敌)", "正侧视重生成→换卡+换锚定"),
    ("mod_arm_m1a2sep", "M1A2 SEP", "三路线对比：现役(批B idle f0) / 本地推导(img25 批板锚定) / API 重生成"),
]


def white_to_alpha(im):
    """白底 raw → RGBA：边缘连通泛洪抠底（10-06 修）。

    全局白距抠图会把单位内部的白/亮部（补给舱/高光/白发）也抠空——首版预览
    蛀洞 1~7 万 px，目检「全不行」实为算法病。现只抠与画布外缘连通的背景白；
    边界 AA 用近白带渐变 alpha，内部一律实心。"""
    import numpy as np
    from scipy import ndimage as ndi
    rgb = np.asarray(im.convert("RGB")).astype(int)
    d = np.sqrt(((rgb - 255) ** 2).sum(axis=2))
    near = d < 90  # 近白（背景+AA带）
    # 从四条边在近白掩膜内泛洪 → 真背景
    bg = np.zeros_like(near)
    bg[0, :] = near[0, :]
    bg[-1, :] = near[-1, :]
    bg[:, 0] = near[:, 0]
    bg[:, -1] = near[:, -1]
    bg = ndi.binary_propagation(bg, mask=near)
    # 软边：背景外扩 2px 的近白带按色距渐变；其余全实心
    band = ndi.binary_dilation(bg, np.ones((5, 5), bool)) & ~bg
    alpha = np.full(rgb.shape[:2], 255, np.uint8)
    alpha[bg] = 0
    g = np.clip((d[band] / 90.0) * 255, 0, 255)  # 越白越透（band 内 d<90）
    alpha[band] = g.astype(np.uint8)
    out = np.dstack([rgb.astype(np.uint8), alpha])
    # 透明区 RGB 回填邻色，防缩放渗白
    m = alpha == 0
    if m.any() and (~m).any():
        _, (iy, ix) = ndi.distance_transform_edt(m, return_indices=True)
        out[..., :3] = out[iy, ix, :3]
    return Image.fromarray(out, "RGBA")


# DARK 案预览提亮（raw 原样目检画，cardE 预览按此提亮读身份；正式锚定走 load_anchor gain）
GAIN = {"fe_void_dimensional_soldier": 1.9, "fe_frontier_veteran": 1.6, "fe_iron_wall_juggernaut": 1.8}


def gain_rgb(rgba, g):
    import numpy as np
    a = np.asarray(rgba).copy()
    m = a[:, :, 3] > 0
    a[..., :3][m] = np.clip(a[..., :3][m].astype(np.float32) * g, 0, 255).astype(np.uint8)
    return Image.fromarray(a)


def derive_card(frame):
    import numpy as np
    a = np.asarray(frame)
    m = a[:, :, 3] >= 16
    ys, xs = np.where(m)
    sub = frame.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
    w, h = sub.size
    sc = CARD_MAX / float(max(w, h))
    nw, nh = max(1, int(round(w * sc))), max(1, int(round(h * sc)))
    sub = sub.resize((nw, nh), Image.LANCZOS)
    cv = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    cv.alpha_composite(sub, ((512 - nw) // 2, (512 - nh) // 2))
    return cv


def on_dark(im, size=256):
    bg = Image.new("RGBA", im.size, (24, 24, 28, 255))
    bg.alpha_composite(im.convert("RGBA"))
    return bg.convert("RGB").resize((size, size), Image.LANCZOS)


def qc_raw(im):
    import numpy as np
    a = np.asarray(im.convert("RGB")).astype(int)
    border = np.concatenate([a[:3].reshape(-1, 3), a[-3:].reshape(-1, 3),
                             a[:, :3].reshape(-1, 3), a[:, -3:].reshape(-1, 3)])
    bg = np.median(border, axis=0)
    d = np.sqrt(((a - bg) ** 2).sum(axis=2))
    body = d > 100
    n = int(body.sum())
    info = {"body_px": n}
    if n < 4000:
        info["问题"] = "主体过小/空"
        return info
    ys, xs = np.where(body)
    info["bbox"] = "x[%d,%d] y[%d,%d]" % (xs.min(), xs.max(), ys.min(), ys.max())
    # 触边检查
    touch = []
    if xs.min() <= 2:
        touch.append("左")
    if xs.max() >= 1021:
        touch.append("右")
    if ys.min() <= 2:
        touch.append("上")
    if ys.max() >= 1021:
        touch.append("下")
    if touch:
        info["触边"] = "+".join(touch)
    # 朝向：主体左右两半的纵向展幅（车辆枪炮侧轮廓更长碎）
    lm = body[:, :512]
    rm = body[:, 512:]
    lh = float((lm.sum(axis=1) > 0).sum())
    rh = float((rm.sum(axis=1) > 0).sum())
    # 亮度
    rgb = a[body]
    info["mean"] = round(float(rgb.mean()), 1)
    return info


def load_verdicts():
    v = {}
    ps = glob.glob(os.path.join(ROOT, "tools", "fam44_cards*.json"))
    ps.sort(key=lambda p: (int(re.findall(r"\((\d+)\)", p)[-1]) if re.search(r"\(\d+\)", p) else -1))
    for p in ps:
        try:
            v.update(json.load(open(p, encoding="utf-8")))
            print("[verdict] %s" % os.path.basename(p))
        except Exception:
            pass
    return v


def main():
    os.makedirs(WEB, exist_ok=True)
    verdict = load_verdicts()
    rows = []
    for key, name, use in UNITS:
        raw_p = os.path.join(STAGE, "%s_raw.png" % key)
        if not os.path.exists(raw_p):
            print("[skip] %s 无 raw" % key)
            continue
        raw = Image.open(raw_p)
        info = qc_raw(raw)
        # 目检素材：raw 缩略 + 暗底大图
        raw.resize((300, 300), Image.LANCZOS).save(os.path.join(WEB, "%s_raw.jpg" % key), quality=90)
        # 推导卡预览（生成朝右 → cardE=镜像朝左）
        rgba = white_to_alpha(raw)
        if key in GAIN:
            rgba = gain_rgb(rgba, GAIN[key])
            info["预览提亮"] = "x%.1f" % GAIN[key]
        cardE = derive_card(rgba).transpose(Image.FLIP_LEFT_RIGHT)
        cardE.save(os.path.join(WEB, "%s_cardE_prev.png" % key))
        on_dark(cardE).save(os.path.join(WEB, "%s_cardE.jpg" % key), quality=88)
        local = None
        if key == "mod_arm_m1a2sep":
            cur = Image.open(os.path.join(ROOT, "assets/card_icons/enemy/vis_enemy_023.png"))
            on_dark(cur).save(os.path.join(WEB, "m1a2_cur_cardE.jpg"), quality=88)
            lp = os.path.join(STAGE, "mod_arm_m1a2sep_cardE_local.png")
            if os.path.exists(lp):
                on_dark(Image.open(lp)).save(os.path.join(WEB, "m1a2_local_cardE.jpg"), quality=88)
                local = True
        rows.append((key, name, use, info, bool(local)))
        print("[row] %s %s" % (key, json.dumps(info, ensure_ascii=False)))

    h = ["<!DOCTYPE html><html><head><meta charset='utf-8'><title>fam44 生图批目检</title><style>",
         "body{font:14px/1.5 'Microsoft YaHei',sans-serif;background:#1b1e24;color:#ddd;margin:0;padding:14px}",
         "h1{font-size:18px;color:#fff}",
         ".note{background:#262b33;border-left:4px solid #e8a;padding:8px 12px;margin:8px 0;font-size:13px}",
         "table{border-collapse:collapse;width:100%;table-layout:fixed}",
         "th{position:sticky;top:0;background:#22262e;color:#9fc3ff;padding:6px;border:1px solid #3a4150}",
         "td{border:1px solid #3a4150;padding:5px;vertical-align:top;background:#20242b;text-align:center}",
         "td img{width:100%;display:block;background:#111} td.kk{font-weight:bold;color:#ffd479;width:150px;font-size:13px;text-align:left}",
         ".qc{font:11px monospace;color:#9ab;text-align:left;white-space:pre-line}",
         "textarea{width:100%;height:48px;background:#161a20;color:#eee;border:1px solid #444;font:12px sans-serif;box-sizing:border-box}",
         ".btns{margin-top:4px} button{background:#31405a;color:#cfe3ff;border:1px solid #4a5f80;padding:2px 10px;cursor:pointer;border-radius:3px}",
         ".okchip{display:inline-block;padding:1px 8px;border-radius:8px;font-size:12px} .ok{background:#1d3a1d;color:#8f8}.bad{background:#3a2a1d;color:#fa8}",
         ".bar{position:sticky;bottom:0;background:#22262e;padding:8px;border-top:1px solid #3a4150}",
         "</style></head><body>",
         "<h1>fam44 生图批目检（7 案）</h1>",
         "<div class=note><b>怎么看</b>：raw=API 原图（应朝右·正侧视·白底）；cardE=镜像后敌方卡预览（暗底）。",
         "m1a2sep 三联：现役=批B(idle f0) / 本地=img25 批板锚定推导 / API=本轮重生成。",
         "通过后流程：新 raw → 品红锚定 → codeanim（fe 三家+juggernaut+veteran+stryker_e）或直接换卡（m1a2sep/stryker_e）。</div>",
         "<table><tr><th>单位</th><th>raw(朝右)</th><th>cardE 预览</th><th>m1a2 对比</th><th>机检</th><th>判定</th></tr>"]
    for key, name, use, info, has_local in rows:
        vd = verdict.get(key, {})
        m1a2cell = "—"
        if key == "mod_arm_m1a2sep":
            parts = ["<div style='font-size:11px;color:#9ab'>现役(批B)</div><img src='fam44_cards_web/m1a2_cur_cardE.jpg'>"]
            if has_local:
                parts.append("<div style='font-size:11px;color:#9ab'>本地推导</div><img src='fam44_cards_web/m1a2_local_cardE.jpg'>")
            parts.append("<div style='font-size:11px;color:#9ab'>API 重生成</div><img src='fam44_cards_web/%s_cardE.jpg'>" % key)
            m1a2cell = "<div style='display:flex;gap:4px'>%s</div>" % "".join(
                "<div style='flex:1'>%s</div>" % p for p in parts)
        qc = "\n".join("%s: %s" % kv for kv in info.items())
        pre = ""
        if vd.get("status") == "要修":
            pre = "<div style='font-size:11px;color:#fa8'>前判定：要修%s</div>" % (
                " · " + vd["note"] if vd.get("note") else "")
        h.append(("<tr><td class=kk>%s<br><small style='color:#9ab'>%s</small><br>"
                  "<small style='color:#8ac'>%s</small>%s</td>"
                  "<td><img src='fam44_cards_web/%s_raw.jpg'></td>"
                  "<td><img src='fam44_cards_web/%s_cardE.jpg'></td>"
                  "<td>%s</td><td class=qc>%s</td>"
                  "<td><textarea id='nt_%s' placeholder='问题…'></textarea>"
                  "<div class=btns><button onclick=\"mark('%s','可以')\">可以</button>"
                  "<button onclick=\"mark('%s','要修')\">要修</button><span id='st_%s'></span></div></td></tr>")
                 % (key, name, use, pre, key, key, m1a2cell, qc, key, key, key, key))
    h.append("</table>")
    h.append("<div class=bar><button onclick=exp()>导出 JSON（+复制）</button><span id=saved></span></div>")
    h.append("<script>var KEY='fam44_cards';var KEYS=%s;" % json.dumps([r[0] for r in rows]))
    h.append("var VERDICT=%s;" % json.dumps(verdict, ensure_ascii=False))
    h.append("""
var S=Object.assign({},VERDICT,JSON.parse(localStorage.getItem(KEY)||'{}'));
function save(){localStorage.setItem(KEY,JSON.stringify(S));document.getElementById('saved').textContent='已保存 '+new Date().toLocaleTimeString();}
KEYS.forEach(function(k){var t=document.getElementById('nt_'+k);
 if(!t)return;
 t.addEventListener('input',function(){S[k]=S[k]||{};S[k].note=t.value;clearTimeout(window._d);window._d=setTimeout(save,300);});
 if(S[k]&&S[k].note)t.value=S[k].note;chip(k);});
function chip(k){var st=document.getElementById('st_'+k);var v=S[k]&&S[k].status;
 st.innerHTML=v?'<span class="okchip '+(v=='可以'?'ok':'bad')+'">'+v+'</span>':'';}
function mark(k,v){S[k]=S[k]||{};S[k].status=v;save();chip(k);}
function exp(){var b=new Blob([JSON.stringify(S,null,1)],{type:'application/json'});
 var a=document.createElement('a');a.href=URL.createObjectURL(b);a.download='fam44_cards.json';a.click();
 navigator.clipboard.writeText(JSON.stringify(S,null,1));}
</script></body></html>""")
    open(os.path.join(ROOT, ".godot", "unit_review", "fam44_cards.html"), "w",
         encoding="utf-8").write("\n".join(h))
    print("wrote fam44_cards.html · %d 行" % len(rows))


if __name__ == "__main__":
    main()
