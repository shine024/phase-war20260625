# -*- coding: utf-8 -*-
"""批量重做攻击帧（按 API 精灵图新工作流 v1）——11 家缺陷单位。
每家用自己的卡图当 i2i 锚点，按单位类型(人形/载具)套 4 帧开火循环,
键控 + 脚部锚定 + 反帧门 + 贴边检查, 合成 6 帧进各自暂存位 .godot/unit_review/api_<unit>/。
用法: python tools/api_sprite_pipeline/batch_regen.py [unit_id ...]   (不传=全 11 家)
"""
import base64, json, os, subprocess, sys, time
from collections import deque
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
WS = os.path.abspath(os.path.join(HERE, "..", ".."))
_BATCH_ARGS = sys.argv[1:]            # 先取本脚本的参
sys.argv = [sys.argv[0]]              # 复位: 让 generate_attack_api 走默认 UNIT(garand_para)
sys.path.insert(0, HERE)
import generate_attack_api as P
sys.argv = [sys.argv[0]] + _BATCH_ARGS  # 恢复

FS = 256
MODEL = P.MODEL
REF_H_FRAC = 0.89          # 目标内容高占比(与 card4 一致)
STANCe_FRAC = 0.60        # 躯干靠右锚定
CFG = json.load(open(os.path.join(WS, ".godot", "unit_review", "batch_regen_config.json"), encoding="utf-8"))
BYUID = {v["id"]: v for v in CFG.values()}
UNITS = {
  "ww2_inf_bazooka":      ("humanoid", "a World War Two infantryman", "bazooka anti-tank rocket"),
  "ww2_arty_m81":         ("platform", "an 81mm field mortar on its tripod", "mortar barrel"),
  "ww1_inf_storm_e":      ("humanoid", "a World War One infantryman", "bolt-action rifle"),
  "cold_inf_spetsnaz_e":  ("humanoid", "a cold-war special-operations soldier", "assault rifle"),
  "cold_boss_mig":        ("platform", "a MiG-29 fighter jet", "cannons"),
  "mod_inf_marine":       ("humanoid", "a modern United States Marine", "M16 rifle"),
  "mod_arm_stryker_e":    ("platform", "a Stryker armored vehicle", "main gun"),
  "fut_arm_mech_e":       ("platform", "a near-future combat mech", "main gun"),
  "fut_inf_spectre_e":    ("humanoid", "a near-future special-operations soldier", "rifle"),
  "ww1_inf_mp18_x":       ("humanoid", "a World War One infantryman", "MP18 submachine gun"),
  "mod_sup_m4_carbine":   ("humanoid", "a modern soldier", "M4 carbine"),
  "ww1_arm_ft17":         ("platform", "a World War One Renault FT-17 light tank", "main gun"),
  "ww2_inf_panzerschrek": ("platform", "a modern six-wheeled armored vehicle", "roof-mounted turret weapon"),
}
GRID_POS4 = ["top-left", "top-right", "bottom-left", "bottom-right"]
# 顽固主体漂移单位: 改 idle f0 当锚点(比卡图简净, i2i 四格一致性更好)
# ww1_inf_storm_e: 卡图电弧在生成卷里勾出双兵轮廓(用户报"重影"), idle 锚 + 电光收敛措辞
IDLE_ANCHOR = {"ww2_inf_bazooka", "ww2_arty_m81", "cold_boss_mig", "fut_arm_mech_e", "ww1_inf_storm_e"}
# 专属加固单位(只对本单生效, 其他单位 prompt 字节不变——单变量纪律):
# ww2_inf_panzerschrek: 卡图蓝色电光纹(§7.7 重影风险) + 旧卷三缺陷(焰悬车顶=武器位错认 /
# 焰贴左缘裁断 / 炮管越车体)——电光收敛 + 焰锁炮口 + 整卷不出格 三句专属
GLOW_UNITS = {"ww2_inf_panzerschrek"}
# 卡图朝向与游戏口径(朝左 sheet)相反的单位: 锚卡图水平镜像后再进底稿/书挡
# ww2_inf_panzerschrek: 玩家卡图车头朝右, 直贴书挡=f1/f6 朝右与动作帧朝左打架(用户报"1,6帧方向反")
FLIP_CARD_UNITS = {"ww2_inf_panzerschrek"}

def poses_for(typ, desc, weapon):
    if typ == "humanoid":
        return [
            "raising the %s: both hands easing the %s up from his side toward his shoulder, muzzle rising to the left, one small step into the aim" % (weapon, weapon),
            "firing: the %s braced at his shoulder with a compact star-shaped muzzle flash at the muzzle, orange-yellow with a white core, body braced against the shot" % weapon,
            "recoil: the muzzle lifting only slightly upward, the upper body leaning gently back, both hands still gripping the %s" % weapon,
            "lowering the %s: both hands easing the %s back down toward his side, muzzle pointing down-left, returning to the ready carry" % (weapon, weapon),
        ]
    return [
        "ready: %s in a stable stance, the %s pointing to the left" % (desc, weapon),
        "firing: the %s discharging with a compact star-shaped muzzle flash at the muzzle, orange-yellow with a white core" % weapon,
        "recoil: the %s recoiling slightly back, %s braced on its tracks and wheels" % (weapon, desc),
        "settling: the %s returning to the ready position" % weapon,
    ]

def poses_for_uid(typ, desc, weapon, uid):
    """单变量纪律: 专属句只挂专属单位, 通用骨架不动。
    panzerschrek: settling 两连卷被读成二次开火(f5 第二焰)——终态描述改 ready 同姿态
    (正向无否定, §6.1 条6 循环闭合也更好)"""
    poses = poses_for(typ, desc, weapon)
    if uid in GLOW_UNITS:
        # panzerschrek v5: recoil 帧曾被画歪(非纯正侧视, 车体带透视/上仰, 净高失真)——
        # 锁正侧视+直后坐; "tracks"履带词对轮式车去除防误读
        poses = poses[:2] + [
            "recoil: the %s recoiling straight back along the ground, kept in the exact same flat side profile view as the ready pose, with the exact same equipment and roof layout as the ready pose" % weapon,
            "settling: the exact same stable stance as the ready pose, the %s back at rest pointing to the left, identical to the first panel" % weapon,
        ]
    return poses

def make_transparent(card):
    card = card.convert("RGBA")
    a = np.asarray(card)[:, :, 3]
    if int(a[2, 2]) < 40 or int(a[2, card.width - 3]) < 40:
        return card
    rgb = np.asarray(card).astype(int)
    white = (rgb[:, :, 0] > 225) & (rgb[:, :, 1] > 225) & (rgb[:, :, 2] > 225)
    H, W = a.shape
    seen = np.zeros((H, W), bool); q = deque()
    for x in range(0, W, 2):
        for y in (0, H - 1):
            if white[y, x] and not seen[y, x]: seen[y, x] = True; q.append((y, x))
    for y in range(0, H, 2):
        for x in (0, W - 1):
            if white[y, x] and not seen[y, x]: seen[y, x] = True; q.append((y, x))
    while q:
        y, x = q.popleft()
        for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if 0 <= ny < H and 0 <= nx < W and white[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True; q.append((ny, nx))
    a[seen] = 0
    return Image.fromarray(np.dstack([np.asarray(card)[:, :, :3], a]).astype(np.uint8))

def i2i(prompt, ref_b64, keys, tag, out_raw="."):
    body = {"model": MODEL, "prompt": prompt, "image_size": "1024x1024",
            "extra_body": {"image": ["data:image/png;base64," + ref_b64], "response_format": "url"}}
    pf = os.path.join(out_raw, "payload_%s.json" % tag)
    json.dump(body, open(pf, "w"))
    for att in range(6):
        key = keys[att % len(keys)]
        r = subprocess.run(["curl", "--http1.1", "-sS", "-m", "300", "-X", "POST",
                             "https://apihub.agnes-ai.com/v1/images/generations",
                             "-H", "Authorization: Bearer " + key, "-H", "Content-Type: application/json",
                             "-d", "@" + pf, "-w", "\nHTTP_CODE:%{http_code}"],
                            capture_output=True, text=True, encoding="utf-8", errors="replace")
        try:
            js = json.loads(r.stdout.rsplit("\nHTTP_CODE:", 1)[0])
        except Exception:
            time.sleep(5); continue
        if "data" in js and js["data"] and js["data"][0].get("url"):
            url = js["data"][0]["url"]
            if "/i2i/" in url:
                return url, key[:12]
            time.sleep(5); continue
        time.sleep(6)
    raise RuntimeError("i2i failed: " + tag)

def place_to_frame(rgba, foot_frac, target_h, center=False):
    """内容 → 256 帧: 缩放到目标高 + 脚线对齐。人形=躯干靠右锚定, 宽载具(center)=居中+限宽。"""
    a = rgba[:, :, 3]
    ys, xs = np.where(a > 20)
    if len(xs) == 0:
        return Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
    crop = Image.fromarray(rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1])
    s = target_h / crop.height
    max_w = int(FS * (0.88 if center else 0.94))
    if crop.width * s > max_w:
        s = max_w / crop.width
    crop = crop.resize((max(1, int(crop.width * s)), int(crop.height * s)), Image.LANCZOS)
    out = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
    if center:
        px = (FS - crop.width) // 2
    else:
        sx = P.stance_x_of(np.asarray(crop))
        px = (int(FS * STANCe_FRAC) - sx) if sx is not None else (FS - crop.width) // 2
        px = max(0, min(px, FS - crop.width))
    out.paste(crop, (px, FS - int(crop.height) - int(round(foot_frac * FS))), crop)
    return out

def run_unit(uid, keys, do_i2i=True):
    cfg = BYUID[uid]
    typ, desc, weapon = UNITS[uid]
    foot = cfg["foot_frac"]
    target_h = int(FS * REF_H_FRAC)
    out = os.path.join(WS, ".godot", "unit_review", "api_" + uid)
    raw = os.path.join(out, "raw"); os.makedirs(raw, exist_ok=True)
    os.makedirs(os.path.join(out, "frames"), exist_ok=True)
    # 锚点: 卡图去白底 / 顽固漂移单位改 idle f0
    if uid in IDLE_ANCHOR:
        ims = Image.open(os.path.join(WS, "assets/effects/unit_anims", cfg["anim_key"], "sheet_idle.png")).convert("RGBA")
        card = ims.crop((0, 0, FS, FS))
        card = card.crop(card.getbbox())
        card.save(os.path.join(out, "anchor_idle.png"))
    else:
        card = make_transparent(Image.open(os.path.join(WS, cfg["icon_rel"].replace("\\", "/"))))
        card = card.crop(card.getbbox())
        if uid in FLIP_CARD_UNITS:
            card = card.transpose(Image.FLIP_LEFT_RIGHT)
        card.save(os.path.join(out, "anchor_card.png"))
    rec = {"unit": uid, "type": typ, "desc": desc, "weapon": weapon, "anchor": cfg["icon_rel"]}
    if do_i2i:
        tpl = P.build_grid_template_4_card(card, FS)
        tpl.save(os.path.join(out, "grid_template_4.png"))
        tpl_b64 = base64.b64encode(open(os.path.join(out, "grid_template_4.png"), "rb").read()).decode()
        prompt = P.SKELETON.replace("{SUBJECT}",
            "the same %s as in the reference image, with the %s, " % (desc, weapon) +
            ("his gear shows only small electric-glow accents, the soldier silhouette is single and clear, no second figure outline, "
             if uid in IDLE_ANCHOR else "") +
            ("small blue electric-glow accents only on its armor panels, the vehicle silhouette is single and clear, no second outline, "
             "the muzzle flash appears exactly at the tip of the %s at its exact position in the reference image, "
             "the entire vehicle and the full flash fit comfortably inside each panel with generous magenta margins, nothing touches or crosses the panel edges, "
             % weapon
             if uid in GLOW_UNITS else "") +
            "shown in a regular grid of exactly 4 flat panels, 2 columns and 2 rows, "
            "all 4 panels showing THE SAME unit, identical scale/colors/rendering, NO shadow under any figure. " +
            " ".join("%s: the same unit %s, facing LEFT in profile, never mirrored, holding the %s (never empty-handed), NO scope;"
                     % (GRID_POS4[i], p, weapon) for i, p in enumerate(poses_for_uid(typ, desc, weapon, uid))) +
            " The star-shaped muzzle flash appears in ONLY ONE panel, the firing panel (top-right). No other panel has any flash. "
            "Keep the exact 4-panel grid layout and spacing of the reference image unchanged, changing only the pose. "
            "One complete figure centered in each panel, generous empty magenta spacing, no borders, no grid lines, no labels, no numbers.")
        url, kh = i2i(prompt, tpl_b64, keys, uid, out_raw=raw)
        rec.update(url=url[:80], key=kh)
        subprocess.run(["curl", "-sS", "-m", "120", "-o", os.path.join(raw, "grid4.png"), url], check=True)
    grid = Image.open(os.path.join(raw, "grid4.png")).convert("RGB")
    alpha_full, labels, comps = P.grid4_to_frames(grid)
    if alpha_full is None:
        rec["audit"] = "FAIL: " + str(comps); json.dump(rec, open(os.path.join(out, "batch_result.json"), "w"), ensure_ascii=False, indent=1); return rec
    flipped, fmsgs = P.grid4_flip_check(grid, alpha_full, labels, comps)
    if flipped:
        rec["audit"] = "FAIL: 反帧 " + " ".join(fmsgs)
        json.dump(rec, open(os.path.join(out, "batch_result.json"), "w"), ensure_ascii=False, indent=1); return rec
    idr = P.identity_gate(grid, comps, P.ref_sig)
    rec["pair"] = round(idr["mx_pair"], 3)
    if idr["mx_pair"] > 0.6:
        rec["audit"] = "FAIL: 异体 pair=%.2f>0.6" % idr["mx_pair"]
        json.dump(rec, open(os.path.join(out, "batch_result.json"), "w"), ensure_ascii=False, indent=1)
        return rec
    h_aim = comps[0][1][3] - comps[0][1][1]
    scale = (REF_H_FRAC * FS) / h_aim
    center = (typ == "platform")
    # 4 动作帧
    for i, (npx, bbox, cid) in enumerate(comps):
        x0, y0, x1, y1 = bbox
        pad = 2
        x0, y0 = max(0, x0 - pad), max(0, y0 - pad)
        x1, y1 = min(alpha_full.shape[1] - 1, x1 + pad), min(alpha_full.shape[0] - 1, y1 + pad)
        mask = labels[y0:y1 + 1, x0:x1 + 1] == cid
        a2 = np.where(mask, alpha_full[y0:y1 + 1, x0:x1 + 1], 0).astype(np.uint8)
        rgba = np.dstack([np.asarray(grid)[y0:y1 + 1, x0:x1 + 1], a2])
        comp, _ = P.largest_component(rgba[:, :, 3])
        if comp is not None: rgba[:, :, 3] = comp
        fr = Image.fromarray(rgba)
        fa = np.asarray(fr)[:, :, 3]
        fyy, fxx = np.where(fa > 20)
        crop = fr.crop((fxx.min(), fyy.min(), fxx.max() + 1, fyy.max() + 1))
        ch_want = int(crop.height * scale)
        max_ch = int(FS * (1 - foot)) - 4
        s = scale if ch_want <= max_ch else max_ch / crop.height
        max_w = int(FS * (0.88 if center else 0.94))
        if crop.width * s > max_w:
            s = max_w / crop.width
        crop = crop.resize((max(1, int(crop.width * s)), int(crop.height * s)), Image.LANCZOS)
        frame = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
        if center:
            px = (FS - crop.width) // 2
        else:
            sx = P.stance_x_of(np.asarray(crop))
            px = (int(FS * STANCe_FRAC) - sx) if sx is not None else (FS - crop.width) // 2
            px = max(0, min(px, FS - crop.width))
        frame.paste(crop, (px, FS - int(crop.height) - int(round(foot * FS))), crop)
        frame.save(os.path.join(out, "frames", "f%d.png" % (i + 2)))
    # 书挡 f1/f6 = 干净卡图
    book = place_to_frame(np.asarray(card.convert("RGBA")), foot, target_h, center=center)
    book.save(os.path.join(out, "frames", "f1.png")); book.save(os.path.join(out, "frames", "f6.png"))
    # 合 6 帧 sheet
    sheet = Image.new("RGBA", (FS * 6, FS), (0, 0, 0, 0))
    for i in range(6):
        sheet.paste(Image.open(os.path.join(out, "frames", "f%d.png" % (i + 1))), (i * FS, 0))
    sheet.save(os.path.join(out, "sheet_attack_api.png"))
    # 贴边检查
    clip = 0
    for i in range(6):
        fa = np.asarray(Image.open(os.path.join(out, "frames", "f%d.png" % (i + 1))))[:, :, 3]
        if fa[:3, :].any() or fa[-3:, :].any() or fa[:, :3].any() or fa[:, -3:].any():
            clip += 1
    rec["clip_frames"] = clip
    rec["audit"] = "pass" if clip == 0 else "pass(贴边%d帧)" % clip
    json.dump(rec, open(os.path.join(out, "batch_result.json"), "w"), ensure_ascii=False, indent=1)
    return rec

if __name__ == "__main__":
    keys = P.load_keys()
    ids = sys.argv[1:] or [u for u in UNITS]
    for uid in ids:
        if uid not in UNITS:
            print("%s 未配置, 跳过" % uid); continue
        for attempt in range(1, 6):
            print("[batch] %s (试%d) ..." % (uid, attempt), flush=True)
            try:
                rec = run_unit(uid, keys, do_i2i=True)
            except RuntimeError as e:
                print("   × %s" % e, flush=True); time.sleep(20); continue
            audit = rec.get("audit", "")
            ok = audit.startswith("pass") and rec.get("clip_frames", 0) == 0
            print("   → %s pair=%s 贴边=%s" % (audit, rec.get("pair", "-"), rec.get("clip_frames")), flush=True)
            if ok:
                break
            time.sleep(8)
    print("done")
