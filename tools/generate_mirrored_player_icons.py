"""
翻转贴图生成工具
落实"我方卡 = 敌方图水平反转"——vis_player = vis_enemy 的水平镜像。

两种模式：
  默认（enemy-first）：已有 vis_enemy 原图，翻转生成 vis_player。用于 C/E 段（036-081）。
  --from-player：已有 vis_player 图，先复制为 vis_enemy 原图，再翻转生成新 vis_player。
                 用于 A/B 段（001-035）——原 vis_player 当作"原图"，翻转后覆盖。

用途：
- 输入/输出：assets/card_icons/units/vis_enemy_*.png 与 vis_player_*.png
- 覆盖前会备份到 assets/card_icons/units/_pre_flip_backup_<date>/。

用法：
    python tools/generate_mirrored_player_icons.py                  # 翻转 036-081（enemy-first）
    python tools/generate_mirrored_player_icons.py --from-player --range 1 35  # A/B段：player→enemy+翻转
    python tools/generate_mirrored_player_icons.py --dry-run        # 只打印不写文件
    python tools/generate_mirrored_player_icons.py --range 36 81
"""
import os
import sys
import shutil
from datetime import date
from PIL import Image

# 项目根目录（脚本位于 tools/ 下）
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
UNITS_DIR = os.path.join(PROJECT_ROOT, "assets", "card_icons", "units")

DEFAULT_START = 36
DEFAULT_END = 81  # 包含


def backup_existing(prefix: str, start: int, end: int) -> str:
    """备份将被覆盖的现有文件到日期目录。"""
    backup_dir = os.path.join(
        UNITS_DIR, "_pre_flip_backup_%s" % date.today().isoformat()
    )
    backed = 0
    for n in range(start, end + 1):
        dst = os.path.join(UNITS_DIR, "%s_%03d.png" % (prefix, n))
        if os.path.exists(dst):
            os.makedirs(backup_dir, exist_ok=True)
            shutil.copy2(dst, os.path.join(backup_dir, "%s_%03d.png" % (prefix, n)))
            backed += 1
    return backup_dir if backed > 0 else ""


def flip_one(enemy_path: str, player_path: str, dry_run: bool) -> bool:
    if not os.path.exists(enemy_path):
        print("  [跳过] 缺少敌方原图: %s" % os.path.basename(enemy_path))
        return False
    if dry_run:
        print("  [DRY] %s -> %s" % (
            os.path.basename(enemy_path), os.path.basename(player_path)))
        return True
    img = Image.open(enemy_path)
    if img.mode != "RGBA":
        img = img.convert("RGBA")
    flipped = img.transpose(Image.FLIP_LEFT_RIGHT)
    flipped.save(player_path, "PNG")
    return True


def player_to_enemy_and_flip(player_path: str, enemy_path: str, dry_run: bool) -> bool:
    """A/B 段模式：现有 vis_player 当原图 → 复制为 vis_enemy → 翻转覆盖 vis_player。"""
    if not os.path.exists(player_path):
        print("  [跳过] 缺少现有 vis_player: %s" % os.path.basename(player_path))
        return False
    if dry_run:
        print("  [DRY] %s ->(当原图)-> %s ->(翻转)-> %s" % (
            os.path.basename(player_path), os.path.basename(enemy_path),
            os.path.basename(player_path)))
        return True
    img = Image.open(player_path)
    if img.mode != "RGBA":
        img = img.convert("RGBA")
    # 1) 现有 vis_player 备份为 vis_enemy（作为原图）
    img.save(enemy_path, "PNG")
    # 2) 翻转后覆盖 vis_player
    flipped = img.transpose(Image.FLIP_LEFT_RIGHT)
    flipped.save(player_path, "PNG")
    return True


def main():
    dry_run = "--dry-run" in sys.argv
    from_player = "--from-player" in sys.argv
    start = DEFAULT_START
    end = DEFAULT_END
    if "--range" in sys.argv:
        idx = sys.argv.index("--range")
        start = int(sys.argv[idx + 1])
        end = int(sys.argv[idx + 2])

    if not os.path.isdir(UNITS_DIR):
        print("错误: units 目录不存在: %s" % UNITS_DIR)
        sys.exit(1)

    mode_label = "player→enemy+翻转（A/B段）" if from_player else "enemy→player翻转（C/E段）"
    print("=== 翻转贴图生成 ===")
    print("范围: %03d ~ %03d" % (start, end))
    print("目录: %s" % UNITS_DIR)
    print("模式: %s" % mode_label)
    print("写入: %s" % ("DRY-RUN（不写文件）" if dry_run else "实际写入"))
    print()

    if not dry_run:
        if from_player:
            # A/B段：备份 vis_player，并备份可能已存在的 vis_enemy
            bdir = backup_existing("vis_player", start, end)
            bdir2 = backup_existing("vis_enemy", start, end)
            if bdir:
                print("已备份现有 vis_player 到: %s" % bdir)
            if bdir2:
                print("已备份现有 vis_enemy 到: %s" % bdir2)
        else:
            bdir = backup_existing("vis_player", start, end)
            if bdir:
                print("已备份现有 vis_player 到: %s" % bdir)
            else:
                print("（无需备份：目标范围内无现有 vis_player 文件）")
        print()

    success = 0
    skipped = 0
    for n in range(start, end + 1):
        enemy_path = os.path.join(UNITS_DIR, "vis_enemy_%03d.png" % n)
        player_path = os.path.join(UNITS_DIR, "vis_player_%03d.png" % n)
        if from_player:
            ok = player_to_enemy_and_flip(player_path, enemy_path, dry_run)
        else:
            ok = flip_one(enemy_path, player_path, dry_run)
        if ok:
            success += 1
        else:
            skipped += 1

    print()
    print("=== 完成 ===")
    print("处理: %d 张" % success)
    print("跳过: %d 张" % skipped)
    if not dry_run and skipped > 0:
        print("提示: 跳过的编号缺少源文件，需补齐美术素材")


if __name__ == "__main__":
    main()
