# -*- coding: utf-8 -*-
"""MK7 开火位总手术（2026-10-04，marks 第二批机械修复）。

病根：一批单位共用同一枚贴死的「橙色飞镖弹道贴片」（左缘 x5-18, y~158-170），
无视各单位真实炮口位置；另有黑盒键化后火光脱离枪口（t55/bmp1_x/hummel 等）、
攻击卷镜像违约（ww2_arty_m81）、机尾火光（multirole/dive_bomber）、
整卷调色错（mark4/105mm）、无火光（cavalry）、贴边（colossus）、贴顶（phase_lance idle）。

模式：
  relocate     亮核(含 tier2)→枪口 tip（刚体跟随车体），其余离体垃圾擦除
  erase_paste  擦离体+亮核，贴 stinger 库火光于 tip
  cores_paste  只擦亮核（保暗色烟雾），贴 stinger（himars）
  cores_erase  只擦亮核（thunder_field 离体能量球）
  paste_only   不擦只贴（cavalry 无火光）
  mirror_paste 整卷镜像(朝左契约)→擦→贴（arty_m81）
  shift        整卷平移（colossus 枪管贴边）
  recolor      idle 采样盒增益转移（mark4/105mm 整卷调色错）
  top_margin   idle 0.97 重锚定留头顶余量（phase_lance）
用法: python tools/_mk7_fire_surgery.py [unit ...]   # 缺省=全表
"""
import io
import os
import shutil
import sys
import types

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UA = os.path.join(ROOT, "assets", "effects", "unit_anims")
STG = os.path.join(ROOT, ".godot", "unit_review", "mk6_staging")
STINGER = os.path.join(ROOT, ".godot", "unit_review", "img25_vfx", "mod_stinger_c2.png")

_src = open(os.path.join(ROOT, "tools", "_mk6_mech_batch.py"), encoding="utf-8").read()
_src = _src.replace('if __name__ == "__main__":\n    main()', '')
_src = '\n'.join(l for l in _src.splitlines()
                 if not l.strip().startswith('sys.stdout = io.TextIOWrapper'))
mk = types.ModuleType('mk')
mk.__file__ = os.path.join(ROOT, "tools", "_mk6_mech_batch.py")
exec(compile(_src, '_mk6_mech_batch.py', 'exec'), mk.__dict__)

STG_IMG = Image.open(STINGER).convert("RGBA")
BAK = os.path.join(ROOT, ".godot", "art_backup_mk7_20261004")


def backup_once(unit, *files):
    """if-not-exists 备份——arty_m81 二次跑卷冲掉原状的事故教训。"""
    d = os.path.join(BAK, unit)
    os.makedirs(d, exist_ok=True)
    for f in files:
        src = os.path.join(UA, unit, f)
        dst = os.path.join(d, f)
        if os.path.exists(src) and not os.path.exists(dst):
            shutil.copy2(src, dst)
            print("  [bak] %s/%s" % (unit, f))

JOBS = {
    # ── 黑盒键化 10 ──
    "cold_arm_t55":            dict(mode="relocate", tip=(28, 183)),
    "cold_t72":                dict(mode="relocate", tip=(20, 188)),
    "cold_inf_btr60":          dict(mode="relocate", tip=(103, 127)),
    "cold_sup_bmp1_x":         dict(mode="relocate", tip=(52, 150)),
    "cold_sup_zsu23":          dict(mode="erase_paste", tip=(34, 60), scale=0.5,
                                    force_frames=(2, 3, 4, 5)),  # 二次：首跑核落炮管中段
    "ww1_arm_rolls":           dict(mode="paste_only", tip=(16, 138), scale=0.5,
                                    frames=(2, 3, 4, 5)),  # 飞镖渣已擦净，补开火表现
    "ww2_arty_hummel":         dict(mode="erase_paste", tip=(14, 150), scale=0.85),
    "ww2_fort_flak":           dict(mode="relocate", tip=(28, 86)),
    "mod_arm_himars":          dict(mode="cores_paste", tip=(150, 120), scale=0.85,
                                    keep_box=(0, 0, 140, 256)),
    "guardian_ww1_ironclad":   dict(mode="paste_only", tip=(15, 140), scale=0.55,
                                    frames=(2, 3, 4, 5)),  # 同 rolls
    # ── 透明卷 ──
    "drop_smg_mk2":            dict(mode="erase_paste", tip=(36, 88), scale=0.4),
    "drop_thunder_field":      dict(mode="erase_paste", tier=2, junk_alpha=8),  # 只擦尘不贴
    # ww2_arty_m81: 不手术——2026-10-04 已从 art_backup_b2_rebuild_20261003 恢复正确版
    # （管朝左上与 idle 一致+炮口自带火光）；当日错版是 B2 后某批覆盖，二次镜像事故教训。
    "ww2_inf_bazooka":         dict(mode="erase_paste", tip=(70, 88), scale=0.5),
    "fut_nano_drone":          dict(mode="erase_paste", tier=2, junk_alpha=8,
                                    tip=(248, 105), scale=0.35, force_frames=(4, 5)),  # 炮朝右!
    "mod_stryker_m2":          dict(mode="erase_paste", tier=2, junk_alpha=8,
                                    tip=(68, 140), scale=0.45, force_frames=(4, 5, 6)),
    "fe_aether_hover_cavalry": dict(mode="erase_paste", tier=2, junk_alpha=8,
                                    tip=(38, 95), scale=0.5, force_frames=(4, 5, 6)),
    "fe_aether_swarm_queen":   dict(mode="erase_paste", tier=2, junk_alpha=8,
                                    tip=(20, 128), scale=0.55, force_frames=(4, 5, 6)),
    "fe_frontier_mixed_company": dict(mode="erase_paste", tier=2, junk_alpha=8,
                                      tip=(92, 88), scale=0.55, force_frames=(4, 5, 6)),
    "fe_quantum_mobile_base":  dict(mode="erase_paste", tier=2, junk_alpha=8,
                                    tip=(40, 116), scale=0.5, force_frames=(4, 5, 6)),
    "cold_bradley":            dict(mode="erase_paste", tier=2, junk_alpha=8,
                                    tip=(95, 110), scale=0.45, force_frames=(4, 5, 6)),
    "cold_arm_btr_e":          dict(mode="erase_paste", tip=(84, 165), scale=0.5),
    "mod_air_multirole":       dict(mode="erase_paste", tier=2, tip=(18, 162), scale=0.5,
                                    force_frames=(3, 5, 7, 8),
                                    fire_wipe=(145, 160, 215, 190)),  # 中腹错位火条→机鼻
    "fut_space_fighter":       dict(mode="erase_paste", tip=(15, 122), scale=0.5),
    "ww1_inf_cavalry":         dict(mode="paste_only", tip=(27, 79), scale=0.5,
                                    frames=(1, 2, 3, 4), no_shift=True),  # 位移失真修正
    "ww2_air_dive_bomber":     dict(mode="bomb", tip=(100, 152)),
    "ww1_boss_av7":            dict(mode="paste_only", tip=(12, 128), scale=0.5,
                                    frames=(4, 5, 6), no_shift=True,
                                    fire_wipe=(18, 168, 64, 208)),  # 炮口贴+车前火渣
    "ww1_arty_m81":            dict(mode="relocate", tip=(17, 58)),  # 黑盒键化后火光移炮口
    "fut_colossus":            dict(mode="shift", dx=12),
    "ww1_mark4":               dict(mode="red_desat", tip=(36, 158), scale=0.6,
                                    frames=(1,)),  # 红染去染+贴回橙火光
    "ww1_105mm":               dict(mode="recolor", box=(150, 150, 210, 180), bmax=1.8),
    "drop_phase_lance":        dict(mode="top_margin"),
}


def dilate(mask, r):
    m = mask.copy()
    for _ in range(r):
        m2 = m.copy()
        m2[1:, :] |= m[:-1, :]; m2[:-1, :] |= m[1:, :]
        m2[:, 1:] |= m[:, :-1]; m2[:, :-1] |= m[:, 1:]
        m = m2
    return m


def erode(mask, r):
    return ~dilate(~mask, r)


def hsv_of(arr):
    return np.asarray(Image.fromarray(arr[:, :, :3].astype(np.uint8)).convert('HSV')).astype(int)


def ccs_of(mask, min_area=25):
    H, W = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    out = []
    ys, xs = np.nonzero(mask)
    if len(ys) == 0:
        return out
    for y0, x0 in zip(ys.tolist(), xs.tolist()):
        if seen[y0, x0]:
            continue
        stack = [(y0, x0)]; seen[y0, x0] = True; pix = []
        while stack:
            y, x = stack.pop(); pix.append((y, x))
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = y + dy, x + dx
                if 0 <= ny < H and 0 <= nx < W and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True; stack.append((ny, nx))
        if len(pix) >= min_area:
            out.append(pix)
    return out


def body_shift(arr, idle_arr):
    """右缘/底缘百分位刚体位移 (dx,dy)，抗离体火光污染。"""
    ax = np.nonzero(arr[:, :, 3] > 40)[1]; ay = np.nonzero(arr[:, :, 3] > 40)[0]
    ix = np.nonzero(idle_arr[:, :, 3] > 40)[1]; iy = np.nonzero(idle_arr[:, :, 3] > 40)[0]
    if len(ax) < 50 or len(ix) < 50:
        return 0, 0
    dx = int(np.percentile(ax, 99.5)) - int(np.percentile(ix, 99.5))
    dy = int(np.percentile(ay, 99.5)) - int(np.percentile(iy, 99.5))
    return dx, dy


def core_mask_of(arr, extra, tier):
    hsv = hsv_of(arr)
    V = hsv[:, :, 2]; S = hsv[:, :, 1]
    if tier >= 2:
        bright = (V > 120) & (S > 30) & extra
    else:
        bright = (V > 150) & (S > 40) & extra
    cm = np.zeros_like(bright)
    for pix in ccs_of(bright, min_area=25):
        cm[[p[0] for p in pix], [p[1] for p in pix]] = True
    return cm


def move_core(arr, cm, tip):
    ys, xs = np.nonzero(cm)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    reg = arr[y0:y1 + 1, x0:x1 + 1].copy()
    m = cm[y0:y1 + 1, x0:x1 + 1]
    arr[y0:y1 + 1, x0:x1 + 1][m] = 0
    w, h = x1 - x0 + 1, y1 - y0 + 1
    tx, ty = tip
    nx = int(round(tx - w * 0.25)); ny = int(round(ty - h / 2))
    H, W = arr.shape[:2]
    nx = max(0, min(W - w, nx)); ny = max(0, min(H - h, ny))
    sub = arr[ny:ny + h, nx:nx + w]
    sub[m] = np.maximum(sub[m], reg[m])
    return arr


def paste_stinger(arr, tip, scale, alpha):
    st = STG_IMG
    w = max(2, int(st.width * scale)); h = max(2, int(st.height * scale))
    s = st.resize((w, h), Image.LANCZOS)
    if alpha < 1.0:
        a = s.getchannel("A").point(lambda v: int(v * alpha))
        s.putalpha(a)
    tx, ty = tip
    nx = int(tx - w * 0.75); ny = int(ty - h / 2)
    arr_img = Image.fromarray(arr)
    arr_img.alpha_composite(s, (max(0, nx), max(0, ny)))
    return np.asarray(arr_img).copy()


def draw_bomb(arr, tip):
    """小炸弹：椭圆弹体+尾翼，朝下落。"""
    im = Image.fromarray(arr)
    d = ImageDraw.Draw(im)
    tx, ty = tip
    d.ellipse((tx - 11, ty, tx + 11, ty + 16), fill=(64, 66, 70, 255),
              outline=(30, 31, 34, 255))
    d.polygon([(tx - 11, ty + 12), (tx + 11, ty + 12), (tx + 14, ty + 22),
               (tx - 14, ty + 22)], fill=(52, 54, 58, 255))
    d.ellipse((tx - 7, ty + 2, tx - 1, ty + 8), fill=(120, 124, 130, 255))
    return np.asarray(im).copy()


def top_margin_rescale(unit):
    meta, fs, frs = mk.load_frames(unit, "idle")
    a0 = np.asarray(frs[0])
    ys = np.nonzero(a0[:, :, 3] > 40)[0]
    top, bot = int(ys.min()), int(ys.max())
    if top > 4:
        print("  [skip] 顶余量 %dpx 已够" % top)
        return
    ground = bot
    h = bot - top + 1
    sc = 0.97
    nh = int(round(h * sc))
    body = frs[0].crop((0, top, fs, bot + 1)).resize((fs, nh), Image.LANCZOS)
    base = Image.new("RGBA", (fs, fs), (0, 0, 0, 0))
    base.paste(body, (0, ground - nh + 1), body)
    a0n = np.asarray(base).copy()
    up = np.roll(a0n, -2, axis=0); up[-2:, :] = 0
    loop = [a0n, a0n, up, up, a0n, a0n, a0n, a0n][:len(frs)]
    while len(loop) < len(frs):
        loop.append(a0n)
    mk.save_strip(unit, "idle", [Image.fromarray(f) for f in loop], meta, fs)
    print("  [refit] 顶 y=%d → %d，脚线 %d 保持" % (top, ground - nh + 1, ground))


def recolor(unit, box, bmax):
    """整卷调色对齐 idle。box 弃用：全剪影中位数——采样盒会被攻击帧 recoil 位移带偏。"""
    _, fs, idl = mk.load_frames(unit, "idle")
    meta, _, atk = mk.load_frames(unit, "attack")
    ai = np.asarray(idl[0]); m_i = ai[:, :, 3] > 200
    med_i = np.median(ai[:, :, :3][m_i], axis=0)
    out = []
    for fr in atk:
        arr = np.asarray(fr).copy()
        m = arr[:, :, 3] > 200
        med_a = np.median(arr[:, :, :3][m], axis=0)
        gain = med_i / np.maximum(med_a, 1)
        gain = np.clip(gain, 0.5, bmax)
        arr[:, :, :3] = np.clip(arr[:, :, :3].astype(float) * gain, 0, 255).astype(np.uint8)
        out.append(Image.fromarray(arr))
    mk.save_strip(unit, "attack", out, meta, fs)
    print("  [recolor] med_i=%s gain=%s" % (med_i.round(0), gain.round(2)))


def red_desat_recolor(unit, tip, scale, frames):
    """红染整卷去染：红主导像素(R>1.15G且>1.15B)按亮度重映射到 idle 车体色向量。
    线性增益会连火光/白烟一起染色（mark4 一代教训），色相选择性只修车体。"""
    _, fs, idl = mk.load_frames(unit, "idle")
    meta, _, atk = mk.load_frames(unit, "attack")
    ai = np.asarray(idl[0]); m_i = ai[:, :, 3] > 200
    med_i = np.median(ai[:, :, :3][m_i], axis=0)
    chroma = med_i / max(float(med_i.mean()), 1)
    out = []
    for i, fr in enumerate(atk):
        arr = np.asarray(fr).astype(float)
        m = (arr[:, :, 3] > 100) & (arr[:, :, 0] > arr[:, :, 1] * 1.15) \
            & (arr[:, :, 0] > arr[:, :, 2] * 1.15)
        lum = 0.3 * arr[:, :, 0] + 0.59 * arr[:, :, 1] + 0.11 * arr[:, :, 2]
        for c in range(3):
            ch = arr[:, :, c]
            ch[m] = np.clip(lum[m] * chroma[c], 0, 255)
            arr[:, :, c] = ch
        arr = arr.astype(np.uint8)
        if i in frames and tip:
            arr = paste_stinger(arr, tip, scale, 1.0)
        out.append(Image.fromarray(arr))
    mk.save_strip(unit, "attack", out, meta, fs)
    print("  [red_desat] 染色n=%d chroma=%s" % (int(m.sum()), chroma.round(2)))
    return idl, out


def surgery(unit):
    job = JOBS[unit]
    mode = job["mode"]
    backup_once(unit, "sheet_attack.png", "sheet_idle.png", "anim.json")
    if mode == "top_margin":
        return top_margin_rescale(unit)
    if mode == "recolor":
        return recolor(unit, job["box"], job.get("bmax", 2.0))
    if mode == "red_desat":
        return red_desat_recolor(unit, job.get("tip"), job.get("scale", 0.5),
                                 job.get("frames", ()))
    meta, fs, idl = mk.load_frames(unit, "idle")
    meta_a, _, atk = mk.load_frames(unit, "attack")
    idle_arr = np.asarray(idl[0])
    sky_u = np.zeros((fs, fs), dtype=bool)
    for f in idl:
        sky_u |= np.asarray(f)[:, :, 3] > 40
    sky = erode(~sky_u, 3)
    tier = job.get("tier", 1)
    pb = job.get("protect_bottom", True)
    out = []
    hit_frames = []
    for i, fr in enumerate(atk):
        arr = np.asarray(fr).copy()
        did = []
        if mode == "shift":
            dx = job.get("dx", 0)
            arr = np.roll(arr, dx, axis=1)
            if dx > 0:
                arr[:, :dx, :] = 0
            out.append(Image.fromarray(arr)); continue
        if mode == "mirror_paste":
            arr = arr[:, ::-1].copy()
            did.append("镜像")
        for (bx0, by0, bx1, by1) in job.get("erase_boxes", []):
            bm = np.zeros((fs, fs), dtype=bool)
            bm[by0:by1, bx0:bx1] = True
            hit = bm & (arr[:, :, 3] > 40) & ~dilate(sky_u, 2)
            if hit.any():
                arr[hit] = 0
                did.append("盒擦%d" % int(hit.sum()))
        extra = (arr[:, :, 3] > job.get("junk_alpha", 40)) & sky
        if job.get("fire_wipe"):
            # 色相选择性擦除：盒内橙黄火色像素无条件清（对付贴身幸存的火渣/尾焰），
            # 灰色机体低饱和不受影响
            x0, y0, x1, y1 = job["fire_wipe"]
            hv = hsv_of(arr)
            fw = (hv[:, :, 0] >= 5) & (hv[:, :, 0] <= 55) & (hv[:, :, 1] > 60) & (arr[:, :, 3] > 40)
            bmm = np.zeros_like(fw); bmm[y0:y1, x0:x1] = True
            fw &= bmm
            if fw.any():
                arr[fw] = 0
                did.append("火擦%d" % int(fw.sum()))
        if mode == "paste_only" and i in job.get("frames", ()):
            # 提出 extra 分支：车体 recoil 出 idle 并集的散点不该抑制贴火光
            if job.get("no_shift"):
                tip = job["tip"]  # 百分位位移会失真（骑兵马体摆动），直接用静态 tip
            else:
                dx, dy = body_shift(arr, idle_arr)
                tip = (job["tip"][0] + dx, job["tip"][1] + dy)
            arr = paste_stinger(arr, tip, job.get("scale", 0.5), 1.0)
            hit_frames.append(i); did.append("贴@%s" % (tip,))
        elif extra.any():
            cm = core_mask_of(arr, extra, tier)
            n_core = int(cm.sum())
            dx, dy = body_shift(arr, idle_arr)
            tip = (job["tip"][0] + dx, job["tip"][1] + dy) if job.get("tip") else None
            if mode in ("relocate",) and n_core:
                for pix in ccs_of(cm, min_area=25):
                    one = np.zeros_like(cm)
                    one[[p[0] for p in pix], [p[1] for p in pix]] = True
                    arr = move_core(arr, one, tip)
                hit_frames.append(i); did.append("核→%s" % (tip,))
            elif mode in ("erase_paste", "cores_paste", "mirror_paste") and n_core:
                arr[cm] = 0
                hit_frames.append(i)
                did.append("擦核%d" % n_core)
            elif mode == "cores_erase" and n_core:
                arr[cm] = 0
                did.append("擦离体核%d" % n_core)
            # 其余离体垃圾（relocate/erase_paste/mirror_paste 擦；保暗模式例外）
            if mode in ("relocate", "erase_paste", "mirror_paste"):
                protect = dilate(cm, 3) if mode != "erase_paste" else np.zeros_like(cm)
                solid = dilate(sky_u, 2)  # 以 idle 实体为准——当前帧 alpha 会把垃圾环当实体保下来
                junk = extra & ~protect & ~solid
                kb = job.get("keep_box")
                if kb:
                    kbm = np.zeros_like(junk); kbm[kb[1]:kb[3], kb[0]:kb[2]] = True
                    junk = junk & ~kbm
                if pb:
                    junk = junk & ~(np.arange(fs) >= fs - 46)[:, None]
                n_junk = int(junk.sum())
                if n_junk:
                    arr[junk] = 0
                    did.append("擦渣%d" % n_junk)
            if mode in ("erase_paste", "cores_paste", "mirror_paste") and tip and \
                    (n_core or i in job.get("force_frames", ())):
                arr = paste_stinger(arr, tip, job.get("scale", 0.5), 1.0)
                did.append("贴火光@%s" % (tip,))
        elif mode == "bomb":
            cm = core_mask_of(arr, extra, 1) if extra.any() else np.zeros((fs, fs), bool)
            if int(cm.sum()) > 25:
                arr[cm] = 0
                arr = draw_bomb(arr, job["tip"])
                hit_frames.append(i); did.append("擦尾火光+挂弹")
        if did:
            print("  [f%-2d] %s" % (i, "; ".join(did)))
        out.append(Image.fromarray(arr))
    mk.save_strip(unit, "attack", out, meta_a, fs)
    if mode == "paste_only" and hit_frames == sorted(hit_frames) and not hit_frames:
        pass
    return idl, out


def main():
    units = sys.argv[1:] or list(JOBS)
    done = []
    for u in units:
        print("── %s" % u)
        try:
            r = surgery(u)
            if r is not None:
                done.append((u,) + r)
        except Exception as e:
            import traceback; traceback.print_exc()
            print("  [err] %s" % e)
    # 验证网格：每单位 idle f0 + 攻击帧
    TH = 96
    per = 8
    for gi in range(0, len(done), per):
        chunk = done[gi:gi + per]
        W = max(len(p) for _, _, p in chunk) + 1
        g = Image.new("RGB", (W * TH, len(chunk) * (TH + 18)), (28, 30, 36))
        d = ImageDraw.Draw(g)
        for ri, (u, idl, pans) in enumerate(chunk):
            y = ri * (TH + 18)
            g.paste(idl[0].resize((TH, TH), Image.LANCZOS), (0, y + 16),
                    idl[0].resize((TH, TH), Image.LANCZOS))
            d.rectangle((0, y + 16, TH - 1, y + 15 + TH), outline=(90, 130, 200))
            for ci, f in enumerate(pans[:W - 1]):
                x = (ci + 1) * TH
                g.paste(f.resize((TH, TH), Image.LANCZOS), (x, y + 16),
                        f.resize((TH, TH), Image.LANCZOS))
            d.text((3, y + 2), u, fill=(255, 220, 120))
        g.save(os.path.join(STG, "verify_mk7_%d.png" % (gi // per)))
        print("[grid] verify_mk7_%d.png" % (gi // per))
    print("完成 %d 单位。下一步: 目验 → foot_frac → 导入门禁" % len(done))


if __name__ == "__main__":
    main()
