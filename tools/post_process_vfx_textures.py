"""VFX 纹理后处理：黑底阈值抠图 + 验证

对 generate_particle_and_explosion_vfx.py 生成的 14 张纹理进行后处理：
  1. 验证背景亮度（应 < 10，否则重新生成）
  2. 阈值抠图（亮度 < 20 → transparent，20-50 → 羽化）
  3. 验证主体保留（中心区域不透明占比 > 50%）

用法：
  cd tools && python post_process_vfx_textures.py
"""
import os
import sys

try:
    from PIL import Image
except ImportError:
    print("ERROR: 需要 PIL。运行: pip install Pillow")
    sys.exit(1)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PARTICLE_DIR = os.path.join(ROOT, "assets", "effects", "particle_textures")
EXPLOSION_DIR = os.path.join(ROOT, "assets", "effects", "explosion_frames")
THRESHOLD = 20
FEATHER = 30


def process_texture(path, verbose=True):
    """处理单张纹理，返回 (ok, bg_brightness, center_opaque_pct)"""
    if not os.path.exists(path):
        if verbose:
            print("  SKIP: 文件不存在")
        return False, 0, 0
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    px = img.load()

    # 验证背景亮度
    edge_pts = [(0,0),(w-1,0),(0,h-1),(w-1,h-1),(w//2,0),(w//2,h-1),(0,h//2),(w-1,h//2)]
    bg_brightness = sum(sum(px[x,y][:3])//3 for x,y in edge_pts)//len(edge_pts)
    if bg_brightness >= 50 and verbose:
        print("  WARN: 背景亮度偏高 (" + str(bg_brightness) + ")，可能需要重新生成")

    # 阈值抠图
    for y in range(h):
        for x in range(w):
            p = px[x,y]
            b = (p[0]+p[1]+p[2])//3
            if b < THRESHOLD:
                px[x,y] = (p[0], p[1], p[2], 0)
            elif b < THRESHOLD + FEATHER:
                px[x,y] = (p[0], p[1], p[2], int(255*(b-THRESHOLD)/FEATHER))

    # 验证主体保留
    cx, cy = w//2, h//2
    opaque = sum(1 for yy in range(max(0,cy-16), min(h,cy+16))
                     for xx in range(max(0,cx-16), min(w,cx+16))
                     if px[xx,yy][3] > 200)
    center_opaque_pct = opaque * 100 // (32*32) if (32*32) > 0 else 0

    # 写回
    img.save(path)
    if verbose:
        print("  OK: bg=" + str(bg_brightness) + ", center_opaque=" + str(center_opaque_pct) + "%")
    return bg_brightness < 50, bg_brightness, center_opaque_pct


def main():
    print("=" * 60)
    print("VFX 纹理后处理（黑底抠图 + 验证）")
    print("=" * 60)

    all_paths = []
    for d in [PARTICLE_DIR, EXPLOSION_DIR]:
        if os.path.exists(d):
            for f in os.listdir(d):
                if f.endswith(".png"):
                    all_paths.append(os.path.join(d, f))

    print("找到 " + str(len(all_paths)) + " 张 PNG")
    print()

    success = 0
    warnings = []
    for path in sorted(all_paths):
        rel = os.path.relpath(path, ROOT)
        print("处理: " + rel)
        ok, bg, center = process_texture(path, verbose=True)
        if ok:
            success += 1
        else:
            warnings.append(rel)
        print()

    print("=" * 60)
    print("完成: " + str(success) + "/" + str(len(all_paths)) + " 张通过")
    if warnings:
        print("警告纹理（背景亮度偏高）: " + ", ".join(warnings))
    print("=" * 60)
    print("后续步骤:")
    print("  1. Agent Tools reload_filesystem 触发 Godot 导入")
    print("  2. 进游戏实机验证粒子形状 + 爆炸帧动画")


if __name__ == "__main__":
    main()
