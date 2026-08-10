"""大招专属 VFX 纹理抠图（flood fill 版）：从边缘洪水填充去除连通黑背景。

复用 remove_nuclear_vfx_background.py 的 flood fill 算法（扫描线版，稳定）。
适配 spell_burst 目录：批处理所有 .png，统一 tol（AI 生成时强制纯黑底，
主体高对比，tol=50 通用）；备份原文件到 _original_backup/。

算法：
  1. 采样边缘背景色（应为近纯黑）
  2. BFS 从四条边所有像素开始，色彩距离 < tol 的标记为"外部背景"
  3. 外部背景 alpha 设 0；主体像素保持不透明
  4. 边缘羽化（外部背景邻接的主体像素半透明，去锯齿）

用法：
  cd tools && python remove_spell_burst_background.py
"""
import os
import shutil
from PIL import Image
from collections import deque

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EFFECTS_DIR = os.path.join(ROOT, "assets", "effects", "spell_burst")
BACKUP_DIR = os.path.join(EFFECTS_DIR, "_original_backup")

# 统一容差（AI 生成时强制纯黑底，主体高对比，50 通用）
# spell_burst 贴图主体颜色多样（紫/橙/蓝/绿），用较大 tol 不误伤
DEFAULT_TOL = 50


def color_dist_sq(p1, p2):
    return (p1[0] - p2[0]) ** 2 + (p1[1] - p2[1]) ** 2 + (p1[2] - p2[2]) ** 2


def flood_fill_outside(px, w, h, tol):
    """扫描线 flood fill：标记所有从边缘连通、且色彩接近边缘背景的像素为外部背景。
    返回 bytearray(w*h)，1=外部背景。
    用朴素4邻接 BFS（1024x1024 边缘 flood fill 几秒完成，清晰优先于性能）。
    """
    tol_sq = tol * tol
    outside = bytearray(w * h)  # 0=未访问, 1=外部背景
    q = deque()
    # 种子：四条边所有像素
    for x in range(w):
        q.append((x, 0))
        q.append((x, h - 1))
    for y in range(h):
        q.append((0, y))
        q.append((w - 1, y))
    while q:
        x, y = q.popleft()
        idx = y * w + x
        if outside[idx]:
            continue
        cur = px[x, y]
        # 采样当前像素为基准（适应渐变背景，不依赖单一基准色）
        # 但要求当前像素本身接近"黑"——否则停止扩散（防止主体内部同色被误抠）
        if cur[0] + cur[1] + cur[2] > 90:
            # 非黑像素，不作为背景扩散（但可能被其他路径标记）
            continue
        outside[idx] = 1
        for nx, ny in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]:
            if 0 <= nx < w and 0 <= ny < h:
                nidx = ny * w + nx
                if not outside[nidx]:
                    np = px[nx, ny]
                    if color_dist_sq((cur[0], cur[1], cur[2]), (np[0], np[1], np[2])) <= tol_sq:
                        q.append((nx, ny))
    return outside


def feather_edges(px, outside, w, h):
    """边缘羽化：外部背景邻接的主体像素半透明（去锯齿）。
    只处理"主体像素且至少有一个外部背景4邻接"的像素，alpha 降到 180。
    """
    for y in range(h):
        for x in range(w):
            if outside[y * w + x]:
                continue  # 已是背景
            # 检查4邻接是否有外部背景
            has_bg_neighbor = False
            for nx, ny in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]:
                if 0 <= nx < w and 0 <= ny < h:
                    if outside[ny * w + nx]:
                        has_bg_neighbor = True
                        break
            if has_bg_neighbor:
                p = px[x, y]
                px[x, y] = (p[0], p[1], p[2], 180)


def process(fname, tol=DEFAULT_TOL):
    path = os.path.join(EFFECTS_DIR, fname)
    if not os.path.exists(path):
        print("跳过(不存在):", fname)
        return False
    # 备份原文件（首次处理时）
    os.makedirs(BACKUP_DIR, exist_ok=True)
    backup_path = os.path.join(BACKUP_DIR, fname)
    if not os.path.exists(backup_path):
        shutil.copy2(path, backup_path)
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    px = img.load()
    # 客观验证背景色（核爆工作流步骤2）
    edge_pts = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1), (w // 2, 0), (w // 2, h - 1), (0, h // 2), (w - 1, h // 2)]
    bg_brightness = sum(sum(px[x, y][:3]) // 3 for x, y in edge_pts) // len(edge_pts)
    print(f"{fname}: 背景亮度={bg_brightness} flood fill (tol={tol})...", end=" ", flush=True)
    if bg_brightness > 30:
        print(f"⚠ 背景非纯黑(亮度{bg_brightness})，可能抠图不净，检查生成质量")
    outside = flood_fill_outside(px, w, h, tol)
    # 外部背景设透明
    removed = 0
    for y in range(h):
        for x in range(w):
            if outside[y * w + x]:
                p = px[x, y]
                px[x, y] = (p[0], p[1], p[2], 0)
                removed += 1
    # 边缘羽化
    feather_edges(px, outside, w, h)
    img.save(path)
    print(f"去除背景 {removed * 100 // (w * h)}%")
    return True


def main():
    print("=" * 50)
    print("大招专属 VFX 纹理抠图（flood fill 版）")
    print("目录: " + EFFECTS_DIR)
    print("=" * 50)
    if not os.path.exists(EFFECTS_DIR):
        print("目录不存在，请先运行 generate_spell_burst_vfx.py")
        return
    pngs = [f for f in os.listdir(EFFECTS_DIR) if f.endswith(".png")]
    if not pngs:
        print("无 .png 文件，请先运行 generate_spell_burst_vfx.py")
        return
    for fname in sorted(pngs):
        process(fname)
    print("=" * 50)
    print("完成。原文件备份在 _original_backup/")
    print("Godot 会自动重导入（或编辑器中 Resources → Reimport）")


if __name__ == "__main__":
    main()
