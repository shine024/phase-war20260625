#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成卡图脚部锚点元数据（card_foot_anchors.gd 的字典内容）。

背景：战场单位卡图的抠图精灵，"脚（最低非透明像素）距画布底部"的比例
在全库 0% ~ 37.5% 浮动（步兵贴底、坦克偏高、飞机最高，同类还不一致）。
渲染时把整张纹理按中心居中会参差不齐，需要按"脚"对齐地面线。

本脚本遍历 assets/card_icons/*.png，读 alpha 通道找非透明 bbox，
算出脚距底比例 foot_frac = (tex_h - bbox_bottom) / tex_h，
输出 data/card_foot_anchors.gd 的字典内容（控制台打印 + 写文件）。

用法：python tools/generate_card_foot_anchors.py
新增卡图后需重跑本脚本。
"""
from pathlib import Path
from PIL import Image

ROOT = Path(r"F:\godot fair duet\create\phase-war\assets\card_icons")
OUT = Path(r"F:\godot fair duet\create\phase-war\data\card_foot_anchors.gd")

# alpha 阈值：大于此值视为非透明（去除边缘半透明噪声）
ALPHA_THRESH = 10
# 仅当脚距底比例超过此值才记录（贴底的图用默认 0.0 即可，省表体积）
MIN_FRAC_TO_RECORD = 0.02


def anchors_of(path: Path):
    """读 PNG alpha 通道，返回 (foot_frac, head_frac)。
    foot_frac = 脚（最低非透明像素）距纹理底部的比例（0.0~0.5）。
    head_frac = 头（最高非透明像素）距纹理顶部的比例（0.0~0.5）。
    """
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    if h == 0:
        return (0.0, 0.0)
    alpha = img.getchannel("A")
    px = alpha.load()
    # 从底部向上找第一个有非透明像素的行（脚）
    bottom_y = h  # 默认全透明
    for y in range(h - 1, -1, -1):
        row_has = False
        for x in range(0, w, 2):  # 隔像素采样加速
            if px[x, y] > ALPHA_THRESH:
                row_has = True
                break
        if row_has:
            bottom_y = y
            break
    # 从顶部向下找第一个有非透明像素的行（头）
    top_y = -1  # 默认全透明
    for y in range(0, h):
        row_has = False
        for x in range(0, w, 2):
            if px[x, y] > ALPHA_THRESH:
                row_has = True
                break
        if row_has:
            top_y = y
            break
    if bottom_y >= h or top_y < 0:
        return (0.0, 0.0)  # 全透明
    foot_px_from_bot = (h - 1) - bottom_y
    head_px_from_top = top_y
    return (foot_px_from_bot / float(h), head_px_from_top / float(h))


def main():
    # 递归扫描 enemy/ 和 player/ 子目录（翻转不改变 y，同名图脚位/头位相同可覆盖）
    files = []
    for sub in ("enemy", "player"):
        sub_dir = ROOT / sub
        if sub_dir.is_dir():
            files.extend(sorted(sub_dir.glob("*.png")))
    print(f"扫描 {len(files)} 张卡图...")
    recorded = 0
    skipped = 0
    # 文件名 → (foot_frac, head_frac)（同名覆盖，值相同）
    anchor_map = {}
    for p in files:
        try:
            foot_frac, head_frac = anchors_of(p)
        except Exception as e:
            print(f"  跳过 {p.name}: {e}")
            skipped += 1
            continue
        # 脚距底或头距顶比例过小（贴边）用默认 0.0，省表体积
        if foot_frac < MIN_FRAC_TO_RECORD and head_frac < MIN_FRAC_TO_RECORD:
            skipped += 1
            continue
        anchor_map[p.stem] = (round(foot_frac, 3), round(head_frac, 3))
        recorded += 1

    print(f"记录 {recorded} 张（脚位/头位偏离），跳过 {skipped} 张（贴边或异常）")
    entries = sorted(anchor_map.items())

    # 生成 .gd 文件内容
    lines = []
    lines.append('extends RefCounted')
    lines.append('class_name CardFootAnchors')
    lines.append('## 卡图锚点表（自动生成，勿手改）。扫描 alpha 通道找实体边界。')
    lines.append('## key = 卡图文件名（assets/card_icons/enemy|player/ 下，去扩展名）')
    lines.append('## FOOT_FRAC: 脚（最低非透明像素）距纹理底部的比例（0.0=脚贴底，0.3=脚悬在底部上方30%）')
    lines.append('## HEAD_FRAC: 头（最高非透明像素）距纹理顶部的比例（0.0=头贴顶）')
    lines.append('## 脚对齐地面：立绘 offset.y = -(0.5 - foot_frac) * tex_h')
    lines.append('## 头顶 UI 锚定实体顶部：实体顶 y = -(1 - head_frac - foot_frac) * tex_h * scale（相对脚部）')
    lines.append('## 贴边的图（比例<%.2f）不在此表，按默认 0.0 处理。' % MIN_FRAC_TO_RECORD)
    lines.append('## 重新生成：python tools/generate_card_foot_anchors.py')
    lines.append('')
    lines.append('const FOOT_FRAC: Dictionary = {')
    for key, (foot_frac, head_frac) in entries:
        lines.append('\t"%s": %.3f,' % (key, foot_frac))
    lines.append('}')
    lines.append('')
    lines.append('const HEAD_FRAC: Dictionary = {')
    for key, (foot_frac, head_frac) in entries:
        lines.append('\t"%s": %.3f,' % (key, head_frac))
    lines.append('}')
    lines.append('')
    lines.append('static func get_foot_frac(file_name: String) -> float:')
    lines.append('\treturn float(FOOT_FRAC.get(file_name, 0.0))')
    lines.append('')
    lines.append('static func get_head_frac(file_name: String) -> float:')
    lines.append('\treturn float(HEAD_FRAC.get(file_name, 0.0))')
    lines.append('')

    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"\n已写入 {OUT}")
    print(f"表项数：{len(entries)}")

    # 打印分布统计
    if entries:
        foot_fracs = [f for _, (f, _) in entries]
        head_fracs = [h for _, (_, h) in entries]
        print(f"foot_frac 分布：min={min(foot_fracs):.3f} max={max(foot_fracs):.3f} avg={sum(foot_fracs)/len(foot_fracs):.3f}")
        print(f"head_frac 分布：min={min(head_fracs):.3f} max={max(head_fracs):.3f} avg={sum(head_fracs)/len(head_fracs):.3f}")
        # 抽样展示
        print("\n抽样（前 15 项）：")
        for key, (foot_frac, head_frac) in entries[:15]:
            print(f"  {key}: foot={foot_frac:.3f} head={head_frac:.3f}")


if __name__ == "__main__":
    main()
