# -*- coding: utf-8 -*-
"""v6.17 视觉修复批重生成器（用户裁决 2026-09-19）：
任务① 16 张攻击姿态帧 → 单兵构图（对齐各兄弟待机美术的制服/配色）
任务② ww1_sup_engineer 异体帧 f7 → 重生成同制服单帧（QC 不过则删帧兜底）
任务③ pi_special_nova → 深色底板徽章（对齐 aegis 家族）+ thumb128
boss fut_boss_nexus 不走 AI——用 f0 黑塔做程序化脉冲帧（见 _boss_pulse.py）。
原图备份 .godot/art_backup_pose_20260919/。断点可续（已完成的跳过）。
"""
import json, os, re, subprocess, sys, time
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _tmp_gen_modicon_pilot import KEYS, call_api  # noqa: E402
from _tmp_visual_audit import white_metrics, components, alpha_mask_small  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIM = os.path.join(ROOT, "assets", "effects", "unit_anims")
BACKUP = os.path.join(ROOT, ".godot", "art_backup_pose_20260919")
RAW = os.path.join(BACKUP, "raw_rolls")
os.makedirs(RAW, exist_ok=True)

# 姿态清单：uid -> (兄弟待机描述, 动作词, 目标内容高)
# 制服描述取自各待机集条带目视；目标高取自旧姿态帧实测 content_h
POSE_JOBS = {
    "ww1_inf_rifle":     ("一战德军步兵，石灰色原野灰野战制服，戴钢盔，绑腿与背囊", "举步枪抵肩射击，枪口朝右", 448),
    "ww1_inf_mp18":      ("一战德军突击队员，灰绿色野战制服，戴钢盔，腰间手榴弹袋", "持MP18冲锋枪抵腰射击", 448),
    "ww1_inf_storm_e":   ("一战风暴突击队员，灰绿制服，钢盔，携带弹药背囊", "持冲锋枪前倾射击", 448),
    "ww1_arty_mortar":   ("一战炮兵，石灰色制服，戴钢盔", "单膝跪地操作轻型迫击炮装填", 328),
    "ww1_sup_mg_nest":   ("一战机枪手，石灰色制服，戴钢盔", "蹲伏在水冷重机枪三脚架后射击", 322),
    "ww2_inf_garand":    ("二战美军步兵，橄榄绿野战制服，戴M1钢盔，作战背心", "举M1加兰德步枪抵肩射击", 448),
    "ww2_inf_thompson":  ("二战美军士兵，橄榄绿制服，戴M1钢盔", "持汤普森冲锋枪抵腰射击", 448),
    "ww2_inf_para_e":    ("二战美军空降兵，卡其色跳伞服，戴M1钢盔，腿袋与背带", "持卡宾枪抵肩射击", 448),
    "ww2_sup_mg42":      ("二战德军机枪手，原野灰制服，戴钢盔", "卧姿趴在MG42机枪后射击", 198),
    "cold_inf_ak":       ("冷战苏军步兵，卡其色长大衣，戴SSh-68钢盔，帆布装具", "持AK步枪抵肩射击", 448),
    "cold_inf_m60":      ("冷战美军步兵，橄榄绿作战服，戴钢盔，弹链背具", "持M60通用机枪抵腰射击", 448),
    "cold_inf_spetsnaz_e": ("冷战苏军特种兵，深藏青色紧身作战服，面罩", "持短突击步枪抵肩射击", 448),
    "mod_inf_marine":    ("现代美军陆战队队员，沙漠数码迷彩，戴战术头盔与风镜", "持M4卡宾枪抵肩射击", 448),
    "mod_inf_delta_e":   ("现代特种部队队员，深灰色作战服与战术背心，全装具", "持短步枪抵肩射击", 448),
    "fut_inf_cyborg":    ("未来半机械士兵，深色机械义体与装甲板，蓝色能量脉络", "抬起机械武器臂射击", 448),
    "fut_inf_spectre_e": ("未来幽灵特战士兵，深色作战服，披着发光的青蓝色能量斗篷", "持相位步枪抵肩射击", 448),
}

PROMPT_SKEL = ("横版2D游戏士兵精灵立绘，单一士兵，只有一个人，全身完整可见，"
               "侧视角朝右，{uniform}，{action}，动感姿态，"
               "手绘数字绘画风格，深色描边，细节丰富，"
               "纯白色背景，背景完全干净无任何杂物，无文字无水印无logo")

ENGINEER_PROMPT = ("横版2D游戏士兵精灵立绘，单一士兵，只有一个人，全身完整可见，"
                   "侧视角朝右，一战德军工兵，石灰色原野灰野战制服，戴钢盔，"
                   "背工具背囊与铁丝网卷，举步枪抵肩射击，动感姿态，"
                   "手绘数字绘画风格，深色描边，纯白色背景，无文字无水印")

NOVA_PROMPT = ("科幻策略游戏相位仪徽章图标，正方形纹章构图，"
               "深空黑到深灰蓝的深底径向渐变背景，"
               "中心是炽热的金色新星核爆球体，白热核心外层金橙等离子火焰，"
               "环绕一圈碎裂的暗金属环，金色霓虹发光勾线，金色电弧与火花粒子向四方迸溅，"
               "金色能量光晕，对称构图，主体完整居中，无文字无水印无logo")


def flood_alpha(im, thresh=238):
    """白底转透明（generate_bunker_bg_v3 同款泛洪，防误伤主体内部白色）"""
    from collections import deque
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    seen = bytearray(w * h)
    dq = deque()
    def white(pt): return pt[0] >= thresh and pt[1] >= thresh and pt[2] >= thresh
    for x in range(w):
        for y in (0, h - 1):
            if white(px[x, y]): dq.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if white(px[x, y]): dq.append((x, y))
    while dq:
        x, y = dq.popleft()
        if x < 0 or x >= w or y < 0 or y >= h: continue
        i = y * w + x
        if seen[i]: continue
        pt = px[x, y]
        if not white(pt): continue
        seen[i] = 1
        px[x, y] = (0, 0, 0, 0)
        dq.append((x + 1, y)); dq.append((x - 1, y)); dq.append((x, y + 1)); dq.append((x, y - 1))
    return im


def matte_white_tiered(im):
    """部分 AI 白底带渐变（边缘 ~220-235），单阈值 238 抠不动 → 分级降阈值，
    取第一个"内容 bbox 非全幅"的档；全档全幅则原样返回（交 matte_bg_distance 兜底）。"""
    best = None
    for th in (238, 228, 218, 208):
        m = flood_alpha(im, th)
        bb = m.getchannel("A").getbbox()
        if bb is None:
            continue
        full = (bb[2] - bb[0]) >= 0.97 * im.width or (bb[3] - bb[1]) >= 0.97 * im.height  # 任一维顶满=未抠净
        if not full:
            return m
        if best is None or (bb[2] - bb[0]) * (bb[3] - bb[1]) < best[1]:
            best = (m, (bb[2] - bb[0]) * (bb[3] - bb[1]))
    return best[0] if best else im


def keep_largest_component(im):
    """只保留最大不透明连通域——清纸纹噪点散斑/漂浮速度线（scipy.ndimage）"""
    from scipy import ndimage
    a = np.asarray(im).copy()
    op = a[..., 3] > 10
    lab, n = ndimage.label(op)
    if n <= 1:
        return im
    sizes = ndimage.sum(op, lab, range(1, n + 1))
    keep = 1 + int(sizes.argmax())
    a[..., 3][lab != keep] = 0
    return Image.fromarray(a)


def matte_bg_distance(im, tol=52):
    """v4：非纯白底（纸纹渐变灰白）→ 边框中值色 + 色距泛洪（PIL floodfill，深描边挡内部）"""
    from PIL import ImageDraw
    rgb_im = im.convert("RGB")
    w, h = rgb_im.size
    work = rgb_im.copy()
    MAGENTA = (255, 0, 255)
    seeds = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1),
             (w // 2, 0), (w // 2, h - 1), (0, h // 2), (w - 1, h // 2)]
    for s in seeds:
        px = work.getpixel(s)
        if abs(px[0] - MAGENTA[0]) + abs(px[1] - MAGENTA[1]) + abs(px[2] - MAGENTA[2]) < 8:
            continue
        try:
            ImageDraw.floodfill(work, s, MAGENTA, thresh=tol)
        except Exception:
            pass
    arr = np.asarray(work)
    bg = (arr[..., 0] == 255) & (arr[..., 1] == 0) & (arr[..., 2] == 255)
    out = im.convert("RGBA")
    a = np.asarray(out).copy()
    a[..., 3][bg] = 0
    return Image.fromarray(a)


def matte_lum_key(im):
    """v5 终极兜底：亮度+低饱和键控（灰白纸纹底连渐变带全键出）+ 边缘连通判定
    （不连边的内部浅色块——白布章/浅装具——幸存）。scipy.ndimage.label。"""
    from scipy import ndimage
    im = im.convert("RGBA")
    arr = np.asarray(im).astype(np.int16)
    rgb = arr[..., :3]
    lum = (rgb[..., 0] * 3 + rgb[..., 1] * 6 + rgb[..., 2]) // 10
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    key = (lum > 150) & (sat < 30)
    lab, n = ndimage.label(key)
    if n == 0:
        return im
    border = set(lab[0]) | set(lab[-1]) | set(lab[:, 0]) | set(lab[:, -1])
    border.discard(0)
    if not border:
        return im
    bg = np.isin(lab, list(border))
    a = np.asarray(im).copy()
    a[..., 3][bg] = 0
    return keep_largest_component(Image.fromarray(a))


def matte_auto(im):
    """白阈值链（纯白底，精确）→ 亮度低饱和键控（灰白纸纹底）→ 色距泛洪。
    终段一律保留最大连通域（清斑点/漂浮线）。"""
    m = matte_white_tiered(im)
    bb = m.getchannel("A").getbbox()
    if bb is not None:
        full = (bb[2] - bb[0]) >= 0.97 * im.width or (bb[3] - bb[1]) >= 0.97 * im.height  # 任一维顶满=未抠净
        if not full:
            return keep_largest_component(m)
    m = matte_lum_key(im)
    bb = m.getchannel("A").getbbox()
    if bb is not None:
        full = (bb[2] - bb[0]) >= 0.97 * im.width or (bb[3] - bb[1]) >= 0.97 * im.height  # 任一维顶满=未抠净
        if not full:
            return m
    return keep_largest_component(matte_bg_distance(im, tol=110))


def audit_generated(path, target_h):
    """生成图 QC：先分级抠图再审。
    白残留 / 单主体 / 内容高比例（低姿态单位——卧姿/跪姿——下限放宽）。返回 (ok, info)"""
    im = matte_auto(Image.open(path))
    a = analyze_simple(im)
    frac_min = 0.22 if target_h < 330 else 0.45
    if a["multi"] != 1:
        return False, f"multi={a['multi']}"
    if a["white"] > 0.02:
        return False, f"white_residue={a['white']:.2f}"
    frac_h = a["h"] / 128.0  # ⚠️ a["h"] 是 alpha_mask_small 的 128 网格坐标（v2 曾误除原图高 1024）
    if not (frac_min <= frac_h <= 1.0):  # 上限放开到 1.0：顶天立地构图合法（v5 曾 0.98 误杀满高立绘）
        return False, f"content_frac_h={frac_h:.2f}"
    return True, f"h={a['h']}"


def analyze_simple(im):
    m, md = alpha_mask_small(im)
    if not m.any():
        return {"multi": 0, "white": 1.0, "h": 0}
    big = [c for c in components(md) if c[0] >= 0.10 * 128 * 128]
    ys, xs = np.nonzero(m)
    wm = white_metrics(im)
    return {"multi": len(big), "white": max(wm["corner_white"], wm["border_white"]),
            "h": int(ys.max() - ys.min() + 1), "bbox": (xs.min(), ys.min(), xs.max(), ys.max())}


def gen_with_retries(prompt, unit_tag, rolls=2, size="1024x1024"):
    """3-key 轮换掷 N 次，返回 [(path,score_info)] 列表"""
    outs = []
    for i in range(rolls):
        out = os.path.join(RAW, f"{unit_tag}_r{i}.png")
        if os.path.isfile(out) and os.path.getsize(out) > 1000:
            outs.append(out)
            continue
        key = KEYS[(i + abs(hash(unit_tag))) % len(KEYS)]
        ok = call_api(prompt, key, out) if call_api.__code__.co_argcount == 3 else call_api(prompt, key, size, out)
        if ok:
            outs.append(out)
        time.sleep(2)
    return outs


def process_pose(uid, uniform, action, target_h):
    p = os.path.join(ANIM, uid, "attack_f0.png")
    bak = os.path.join(BACKUP, f"{uid}_attack_f0.png")
    if os.path.isfile(p) and not os.path.isfile(bak):
        os.replace(p, bak)  # 首跑备份并腾位；重跑（断点）时 p 可能已不存在
    prompt = PROMPT_SKEL.format(uniform=uniform, action=action)
    outs = gen_with_retries(prompt, uid, rolls=2)
    best, best_info = None, None
    for o in outs:
        ok, info = audit_generated(o, target_h)
        print(f"  [{uid}] roll {os.path.basename(o)}: {'OK' if ok else 'FAIL'} {info}")
        if ok:
            best, best_info = o, info
            break
    if best is None and outs:  # 补掷
        outs2 = gen_with_retries(prompt, uid + "_x", rolls=1)
        for o in outs2:
            ok, info = audit_generated(o, target_h)
            if ok:
                best, best_info = o, info
                break
    if best is None:
        print(f"  [{uid}] 全掷失败——回退旧图")
        os.replace(bak, p)  # 回退
        return False
    assemble_pose(best, p, target_h)
    return True


def assemble_pose(src, dst, target_h):
    """分级白底转透明 -> 裁内容 -> 缩放到目标高 -> 512 画布底部居中（贴旧锚位）"""
    im = matte_auto(Image.open(src))
    bbox = im.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError("empty matte")
    im = im.crop(bbox)
    scale = target_h / im.height
    im = im.resize((max(1, int(im.width * scale)), target_h), Image.LANCZOS)
    canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    canvas.paste(im, ((512 - im.width) // 2, 512 - 24 - im.height), im)
    canvas.save(dst)
    print(f"  -> assembled {dst}")


def process_engineer():
    uid = "ww1_sup_engineer"
    sp = os.path.join(ANIM, uid, "sheet_idle.png")
    meta_p = os.path.join(ANIM, uid, "anim.json")
    meta = json.load(open(meta_p, encoding="utf-8"))
    fs = int(meta["frame_size"])
    bak_sp = os.path.join(BACKUP, f"{uid}_sheet_idle.png")
    if not os.path.isfile(bak_sp):
        import shutil
        shutil.copy2(sp, bak_sp)
    outs = gen_with_retries(ENGINEER_PROMPT, uid + "_f7", rolls=2, size="1024x1024")
    for o in outs:
        im = matte_auto(Image.open(o))  # v6.17: 先抠图再审（原版审未抠原图，白底必挂）
        a = analyze_simple(im)
        if a["multi"] == 1 and a["white"] <= 0.02:
            # 裁剪到 256 帧：内容居中，高度约 200px（对齐兄弟帧占比 ~0.35*256=90?? 用旧 f6 实测）
            ref = Image.open(sp).convert("RGBA").crop((6 * fs, 0, 7 * fs, fs))
            rb = ref.getchannel("A").getbbox()
            ref_h = rb[3] - rb[1] if rb else 176
            bbox = im.getchannel("A").getbbox()
            im2 = im.crop(bbox)
            scale = ref_h / im2.height
            im2 = im2.resize((max(1, int(im2.width * scale)), ref_h), Image.LANCZOS)
            canvas = Image.new("RGBA", (fs, fs), (0, 0, 0, 0))
            canvas.paste(im2, ((fs - im2.width) // 2, min(fs - 8 - im2.height, (fs - im2.height) // 2 + 20)), im2)
            # 直接改写 sheet 第 8 格
            sheet = Image.open(sp).convert("RGBA")
            sheet.paste(canvas, (7 * fs, 0))
            sheet.save(sp)
            print(f"  [{uid}] f7 重生成并写入 sheet")
            return True
    print(f"  [{uid}] 重生成 QC 未过——回退旧 sheet")
    import shutil
    shutil.copy2(bak_sp, sp)
    return False


def process_nova():
    p = os.path.join(ROOT, "assets", "ui", "instruments", "pi_special_nova.png")
    tp = os.path.join(ROOT, "assets", "ui", "instruments", "_thumb128", "pi_special_nova.png")
    bak = os.path.join(BACKUP, "pi_special_nova.png")
    bak_t = os.path.join(BACKUP, "pi_special_nova_thumb.png")
    if not os.path.isfile(bak):
        os.replace(p, bak)
    if os.path.isfile(tp) and not os.path.isfile(bak_t):
        import shutil
        shutil.copy2(tp, bak_t)
    outs = gen_with_retries(NOVA_PROMPT, "pi_special_nova", rolls=2)
    for o in outs:
        im = Image.open(o).convert("RGBA")
        arr = np.asarray(im).astype(np.int16)
        mn = arr[..., :3].min(axis=2)
        a = arr[..., 3]
        H = im.height
        cmax = 0.0
        for cy in (0, H - 16):
            for cx in (0, H - 16):
                cmax = max(cmax, float(((mn[cy:cy+16, cx:cx+16] >= 235) &
                                         (a[cy:cy+16, cx:cx+16] >= 200)).mean()))
        if cmax < 0.05:  # 四角不是白底 = 深底板达成
            im = im.resize((1024, 1024), Image.LANCZOS)
            im.save(p)
            tp_dir = os.path.dirname(tp)
            if os.path.isdir(tp_dir):
                im.resize((128, 128), Image.LANCZOS).save(tp)
            print("  [nova] 深底板版已写入 + thumb128")
            return True
    print("  [nova] 重生成 QC 未过——回退旧图")
    os.replace(bak, p)
    return False


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "all"
    results = {}
    if mode in ("all", "pose"):
        print("== 任务①：16 张姿态帧 ==")
        for uid, (uni, act, th) in POSE_JOBS.items():
            print(f"[{uid}]")
            results[uid] = process_pose(uid, uni, act, th)
    if mode in ("all", "engineer"):
        print("== 任务②：engineer f7 ==")
        results["ww1_sup_engineer_f7"] = process_engineer()
    if mode in ("all", "nova"):
        print("== 任务③：nova ==")
        results["pi_special_nova"] = process_nova()
    print("\n==== 结果汇总 ====")
    for k, v in results.items():
        print(f"  {'PASS' if v else 'FAIL/fallback'}  {k}")
    ok_n = sum(1 for v in results.values() if v)
    print(f"POSE_REGEN_DONE {ok_n}/{len(results)}")
