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


def foot_frac_of(path: Path) -> float:
    """读 PNG alpha 通道，返回脚距底部比例（0.0~0.5）。"""
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    if h == 0:
        return 0.0
    alpha = img.getchannel("A")
    # 从底部向上找第一个有非透明像素的行
    px = alpha.load()
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
    if bottom_y >= h:
        return 0.0
    # bottom_y 是最低非透明像素的 y 坐标（0=顶, h-1=底）
    # 脚距底（像素）= h - 1 - bottom_y
    foot_px_from_bot = (h - 1) - bottom_y
    return foot_px_from_bot / float(h)


def main():
    entries = []
    files = sorted(ROOT.glob("*.png"))
    print(f"扫描 {len(files)} 张卡图...")
    recorded = 0
    skipped = 0
    for p in files:
        try:
            frac = foot_frac_of(p)
        except Exception as e:
            print(f"  跳过 {p.name}: {e}")
            skipped += 1
            continue
        if frac < MIN_FRAC_TO_RECORD:
            skipped += 1
            continue
        # GDScript 字典项：文件名（去扩展名）→ 比例（保留 3 位小数）
        key = p.stem
        entries.append((key, round(frac, 3)))
        recorded += 1

    print(f"记录 {recorded} 张（脚位偏离），跳过 {skipped} 张（贴底或异常）")

    # 生成 .gd 文件内容
    lines = []
    lines.append('extends RefCounted')
    lines.append('class_name CardFootAnchors')
    lines.append('## 卡图脚部锚点表（自动生成，勿手改）')
    lines.append('## key = 卡图文件名（assets/card_icons/ 下，去扩展名）')
    lines.append('## value = 脚距纹理底部的比例（0.0=脚贴底，0.3=脚悬在底部上方30%）')
    lines.append('## 渲染时立绘 position.y = -tex_h*|scale.y|*(0.5 - foot_frac)，让脚对齐地面线。')
    lines.append('## 脚贴底的图（foot_frac<%.2f）不在此表，按默认 0.0 处理。' % MIN_FRAC_TO_RECORD)
    lines.append('## 重新生成：python tools/generate_card_foot_anchors.py')
    lines.append('')
    lines.append('const FOOT_FRAC: Dictionary = {')
    for key, frac in entries:
        lines.append('\t"%s": %.3f,' % (key, frac))
    lines.append('}')
    lines.append('')
    lines.append('static func get_foot_frac(file_name: String) -> float:')
    lines.append('\treturn float(FOOT_FRAC.get(file_name, 0.0))')
    lines.append('')

    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"\n已写入 {OUT}")
    print(f"表项数：{len(entries)}")

    # 打印分布统计
    if entries:
        fracs = [f for _, f in entries]
        print(f"foot_frac 分布：min={min(fracs):.3f} max={max(fracs):.3f} avg={sum(fracs)/len(fracs):.3f}")
        # 抽样展示
        print("\n抽样（前 15 项）：")
        for key, frac in entries[:15]:
            print(f"  {key}: {frac:.3f}")


if __name__ == "__main__":
    main()
