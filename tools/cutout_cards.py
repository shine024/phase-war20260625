#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
批量抠图工具：去除卡图的纯色背景（白底/绿幕），保留主体，边缘羽化。

算法：
1. 检测背景色（四角平均）
2. 洪水填充（flood fill）：从四角/四边出发，把与背景色相近的连通区域标记为背景
3. 对剩余的"主体边缘"像素做羽化：根据与背景色的距离设置半透明 alpha
4. 输出 RGBA PNG

洪水填充比全局色键更安全：只会去除"从边缘连通进来"的背景，
不会误删主体内部与背景色相近的孤立区域。

用法：
  python tools/cutout_cards.py --dry-run   # 仅预览，不写文件
  python tools/cutout_cards.py --apply     # 执行抠图（先备份原图）
"""
import sys
import shutil
from pathlib import Path
from PIL import Image

ROOT = Path(r"F:\godot fair duet\create\phase-war\assets\card_icons")
BACKUP_DIR = ROOT / "_uncut_backup"

# 需处理的文件清单（白底95 + 绿幕4 = 99张）
WHITE_BG = [
    "cold_ak47.png", "cold_bmp1.png", "cold_bradley.png", "cold_btr60.png",
    "cold_chieftain.png", "cold_f4.png", "cold_leo1.png", "cold_m1.png",
    "cold_m113.png", "cold_m14.png", "cold_m60.png", "cold_m60t.png",
    "cold_mig21.png", "cold_rpg.png", "cold_rpk.png", "cold_sam7.png",
    "cold_spetsnaz.png", "cold_t55.png", "cold_t62.png", "cold_t72.png",
    "cold_zsu23.png",
    "fut_aa_hover.png", "fut_assault_mech.png", "fut_attack_drone.png",
    "fut_colossus.png", "fut_cyborg.png", "fut_heavy_mech.png",
    "fut_heavy_trooper.png", "fut_hovertank.png", "fut_howitzer.png",
    "fut_nano_drone.png", "fut_prism.png", "fut_scout_drone.png",
    "fut_scout_mech.png", "fut_shield.png", "fut_space_fighter.png",
    "fut_spectre.png", "fut_stealth_bomber.png", "fut_stormcore.png",
    "fut_swarm.png",
    "mod_ah1.png", "mod_ah64.png", "mod_challenger2.png", "mod_hummer_m2.png",
    "mod_hummer_tow.png", "mod_javelin.png", "mod_leo2a6.png", "mod_m1a1.png",
    "mod_m1a2.png", "mod_m270.png", "mod_m6.png", "mod_marine.png",
    "mod_ranger.png", "mod_stinger.png", "mod_stryker_m2.png",
    "mod_stryker_mgs.png", "mod_t90.png", "mod_uh60.png",
    "ww1_105mm.png", "ww1_37mm.png", "ww1_a7v.png", "ww1_enfield.png",
    "ww1_flame.png", "ww1_ft17.png", "ww1_lanchest.png", "ww1_m76.png",
    "ww1_m81.png", "ww1_mark4.png", "ww1_mauser.png", "ww1_mg08.png",
    "ww1_mp18.png", "ww1_saint.png", "ww1_storm.png", "ww1_vickers.png",
    "ww2_bazooka.png", "ww2_browning.png", "ww2_garand.png", "ww2_hellcat.png",
    "ww2_is2.png", "ww2_kingtiger.png", "ww2_m120.png", "ww2_m81.png",
    "ww2_mg42.png", "ww2_mp40.png", "ww2_panther.png", "ww2_panzerschrek.png",
    "ww2_ppsh.png", "ww2_pz3.png", "ww2_pz4.png", "ww2_sherman.png",
    "ww2_t34_76.png", "ww2_t34_85.png", "ww2_thompson.png",
    "vis_player_003.png", "vis_player_012.png",
]
GREEN_SCREEN = [
    "fut_nexus.png", "mod_m1a2sep.png", "mod_technical.png", "ww2_tiger.png",
]


def detect_bg_color(rgb_img):
    """取四角 + 四边中点平均作为背景色。"""
    w, h = rgb_img.size
    samples = [
        rgb_img.getpixel((2, 2)), rgb_img.getpixel((w-3, 2)),
        rgb_img.getpixel((2, h-3)), rgb_img.getpixel((w-3, h-3)),
        rgb_img.getpixel((w//2, 2)), rgb_img.getpixel((w//2, h-3)),
        rgb_img.getpixel((2, h//2)), rgb_img.getpixel((w-3, h//2)),
    ]
    return tuple(sum(s[i] for s in samples) // len(samples) for i in range(3))


def color_dist_sq(a, b):
    """颜色欧氏距离平方。"""
    return (a[0]-b[0])**2 + (a[1]-b[1])**2 + (a[2]-b[2])**2


def flood_fill_background(rgb_img, bg_color, tolerance_sq):
    """
    洪水填充：从四边所有边缘像素出发，标记所有与 bg_color 距离 < tolerance 的连通区域为背景。
    返回 mask (同尺寸 2D list)：True=背景(透明)，False=主体(保留)。
    """
    w, h = rgb_img.size
    px = rgb_img.load()
    mask = [[False] * w for _ in range(h)]  # True=背景
    # 边缘种子点：整个外圈一圈
    from collections import deque
    queue = deque()
    # 添加四边所有像素作为种子
    for x in range(w):
        for y in (0, h-1):
            if color_dist_sq(px[x, y], bg_color) < tolerance_sq:
                mask[y][x] = True
                queue.append((x, y))
    for y in range(h):
        for x in (0, w-1):
            if color_dist_sq(px[x, y], bg_color) < tolerance_sq:
                mask[y][x] = True
                queue.append((x, y))
    # BFS 扩散
    while queue:
        x, y = queue.popleft()
        for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
            nx, ny = x+dx, y+dy
            if 0 <= nx < w and 0 <= ny < h and not mask[ny][nx]:
                if color_dist_sq(px[nx, ny], bg_color) < tolerance_sq:
                    mask[ny][nx] = True
                    queue.append((nx, ny))
    return mask, w, h


def apply_cutout_with_feather(orig_img, rgb_img, mask, w, h, bg_color, feather_thresh_sq):
    """
    根据mask生成RGBA图。mask标记的背景→透明。
    对主体边缘做羽化：靠近背景色但不连通的像素，按距离渐变alpha。
    """
    px_orig = orig_img.convert("RGBA").load() if orig_img.mode != "RGBA" else orig_img.load()
    px_rgb = rgb_img.load()
    out = Image.new("RGBA", (w, h))
    out_px = out.load()
    for y in range(h):
        for x in range(w):
            if mask[y][x]:
                # 背景：全透明
                out_px[x, y] = (0, 0, 0, 0)
            else:
                r, g, b = px_rgb[x, y][:3]
                a = px_orig[x, y][3] if orig_img.mode == "RGBA" else 255
                # 羽化：计算与背景色距离，距离越近越透明
                dist_sq = (r-bg_color[0])**2 + (g-bg_color[1])**2 + (b-bg_color[2])**2
                if dist_sq < feather_thresh_sq:
                    # 在羽化带内，alpha按距离线性渐变
                    import math
                    ratio = math.sqrt(dist_sq) / math.sqrt(feather_thresh_sq)
                    alpha = max(0, min(255, int(a * (ratio ** 1.5))))
                    if alpha < 8:
                        alpha = 0
                    out_px[x, y] = (r, g, b, alpha)
                else:
                    out_px[x, y] = (r, g, b, a)
    return out


def process_file(name, bg_type, apply):
    """处理单个文件。bg_type: 'white' 或 'green'。"""
    src = ROOT / name
    if not src.exists():
        return f"NOT FOUND: {name}"

    img = Image.open(src)
    img.load()
    rgb = img.convert("RGB")
    w, h = rgb.size
    bg = detect_bg_color(rgb)

    # 容差：白底用较小容差（白色范围窄），绿幕用较大容差（绿幕有渐变）
    if bg_type == "white":
        tolerance_sq = 60 ** 2      # 与纯白距离<60 视为背景
        feather_thresh_sq = 90 ** 2  # 羽化带
    else:  # green
        tolerance_sq = 120 ** 2     # 绿幕容差大
        feather_thresh_sq = 160 ** 2

    mask, w, h = flood_fill_background(rgb, bg, tolerance_sq)
    # 统计背景占比
    bg_count = sum(sum(1 for v in row if v) for row in mask)
    bg_ratio = bg_count / (w * h)

    # 安全检查：背景占比异常（>98% 说明几乎全是背景，可能误判；<5% 说明没抠到）
    if bg_ratio > 0.98:
        return f"SKIP {name}: 背景占比 {bg_ratio:.1%} 过高(疑似误判)"
    if bg_ratio < 0.03:
        return f"SKIP {name}: 背景占比 {bg_ratio:.1%} 过低(未抠到)"

    out = apply_cutout_with_feather(img, rgb, mask, w, h, bg, feather_thresh_sq)

    if apply:
        # 备份原图
        BACKUP_DIR.mkdir(exist_ok=True)
        backup = BACKUP_DIR / name
        if not backup.exists():
            shutil.copy2(src, backup)
        # 写入抠图结果（覆盖原图）
        out.save(src, "PNG")

    return f"OK {name}: {w}x{h} bg=RGB{bg} 背景占比 {bg_ratio:.1%} {'[已写入]' if apply else '[预览]'}"


def main():
    apply = "--apply" in sys.argv
    dry = "--dry-run" in sys.argv or not apply

    print("=" * 60)
    print(f"卡图批量抠图 {'[执行模式]' if apply else '[预览模式]'}")
    print("=" * 60)

    if apply:
        print("⚠️  执行模式：将备份原图到 _uncut_backup/ 并覆盖原图")
        # Non-interactive: auto-confirm in --apply mode (already confirmed by user before invoking)

    total = len(WHITE_BG) + len(GREEN_SCREEN)
    print(f"\n待处理: 白底 {len(WHITE_BG)} 张 + 绿幕 {len(GREEN_SCREEN)} 张 = {total} 张\n")

    ok, skip, fail = 0, 0, 0
    print("--- 白底卡 ---")
    for name in WHITE_BG:
        result = process_file(name, "white", apply)
        print(f"  {result}")
        if result.startswith("OK"): ok += 1
        elif result.startswith("SKIP"): skip += 1
        else: fail += 1

    print("\n--- 绿幕卡 ---")
    for name in GREEN_SCREEN:
        result = process_file(name, "green", apply)
        print(f"  {result}")
        if result.startswith("OK"): ok += 1
        elif result.startswith("SKIP"): skip += 1
        else: fail += 1

    print(f"\n{'=' * 60}")
    print(f"完成: 成功 {ok}, 跳过 {skip}, 失败 {fail}")
    if apply:
        print(f"原图已备份到: {BACKUP_DIR}")
    print(f"{'=' * 60}")


if __name__ == "__main__":
    main()
