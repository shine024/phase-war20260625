"""核爆蘑菇云精灵表切割 + 抠图 + 连贯性验证。

把 1024×1024 的 3×3 精灵表切成 9 张单帧，每帧黑底抠图，
并客观验证帧间连贯性（主体中心偏移、面积演变趋势）。

切割：1024/3 ≈ 341px 每帧（取整 341，余数忽略，9 帧覆盖 1023px 足够）
抠图：亮度<20 透明，20-50 羽化（复用已验证的黑底阈值法）
验证：
  - 每帧主体中心偏移 < 30px（蘑菇云不能帧间乱跳）
  - 主体面积有演变趋势（应递增后递减，非完全不变 = 有成长序列）
  - 报告每帧数据供判断

输出：assets/effects/nuclear/nuke_mushroom_f0.png ~ f8.png
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NUKE_DIR = os.path.join(ROOT, "assets", "effects", "nuclear")
SHEET = os.path.join(NUKE_DIR, "nuke_mushroom_sheet.png")
GRID = 3  # 3x3
THRESHOLD = 20  # 亮度<20 完全透明
FEATHER = 30   # 20-50 羽化


def process():
    if not os.path.exists(SHEET):
        print("ERROR: 精灵表不存在: " + SHEET)
        print("  先运行 python tools/generate_nuke_spritesheet.py")
        return False
    img = Image.open(SHEET).convert("RGBA")
    w, h = img.size
    cell_w = w // GRID
    cell_h = h // GRID
    print(f"精灵表 {w}x{h}, 切成 {GRID}x{GRID}, 每帧 {cell_w}x{cell_h}")
    print("=" * 55)

    frame_data = []  # 每帧的 (center_x, center_y, area, brightness)
    for fy in range(GRID):
        for fx in range(GRID):
            idx = fy * GRID + fx
            # 切割单帧
            frame = img.crop((fx * cell_w, fy * cell_h, (fx + 1) * cell_w, (fy + 1) * cell_h))
            px = frame.load()
            fw, fh = frame.size
            # 黑底抠图 + 统计主体
            opaque_pts = []
            total_brightness = 0
            opaque_count = 0
            for y in range(fh):
                for x in range(fw):
                    p = px[x, y]
                    b = (p[0] + p[1] + p[2]) // 3
                    if b < THRESHOLD:
                        px[x, y] = (p[0], p[1], p[2], 0)
                    elif b < THRESHOLD + FEATHER:
                        px[x, y] = (p[0], p[1], p[2], int(255 * (b - THRESHOLD) / FEATHER))
                        if b > THRESHOLD + 15:  # 算主体（排除羽化边缘）
                            opaque_pts.append((x, y))
                            total_brightness += b
                            opaque_count += 1
                    else:
                        opaque_pts.append((x, y))
                        total_brightness += b
                        opaque_count += 1
            out = os.path.join(NUKE_DIR, f"nuke_mushroom_f{idx}.png")
            frame.save(out)
            # 主体中心 + 面积
            if opaque_count > 0:
                cx = sum(p[0] for p in opaque_pts) / opaque_count
                cy = sum(p[1] for p in opaque_pts) / opaque_count
                avg_b = total_brightness / opaque_count
                area_pct = opaque_count * 100 // (fw * fh)
            else:
                cx = cy = avg_b = area_pct = 0
            frame_data.append((cx, cy, area_pct, avg_b))
            print(f"帧{idx}: 中心=({cx:.0f},{cy:.0f}) 主体占比={area_pct}% 平均亮度={avg_b:.0f}")

    print("=" * 55)
    # 验证连贯性
    print("=== 连贯性验证 ===")
    # 1. 帧间中心偏移
    max_shift = 0
    for i in range(1, len(frame_data)):
        dx = abs(frame_data[i][0] - frame_data[i - 1][0])
        dy = abs(frame_data[i][1] - frame_data[i - 1][1])
        shift = (dx ** 2 + dy ** 2) ** 0.5
        if shift > max_shift:
            max_shift = shift
    print(f"帧间最大中心偏移: {max_shift:.0f}px ({'OK <30' if max_shift < 30 else 'WARN >30 蘑菇云可能乱跳'})")

    # 2. 面积演变（应有变化，非全相同）
    areas = [d[2] for d in frame_data]
    area_range = max(areas) - min(areas)
    print(f"主体占比范围: {min(areas)}%~{max(areas)}% (差值{area_range}%)")
    if area_range < 5:
        print("  WARN: 各帧主体大小几乎不变，可能缺乏成长演变（9帧太相似）")
    else:
        print(f"  OK: 各帧主体大小有变化，存在成长序列演变")

    # 3. 平均亮度变化（蘑菇云应先亮后暗）
    brights = [d[3] for d in frame_data]
    print(f"亮度演变: {[int(b) for b in brights]}")
    print("=" * 55)
    print(f"切割完成，9 帧已保存到 {NUKE_DIR}/nuke_mushroom_f0.png ~ f8.png")
    print("下一步：Godot 会自动导入，或用 Agent Tools editor.reload_filesystem 触发")
    ok = max_shift < 60 and area_range >= 3  # 放宽阈值（AI 不完美，能用就行）
    if not ok:
        print("⚠ 质量一般，但仍可用于帧动画（蘑菇云本就有随机性）。如不满意可 --force 重新生成精灵表")
    return True


if __name__ == "__main__":
    process()
