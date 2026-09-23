#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成卡图视觉锚点元数据（card_foot_anchors.gd 的 FOOT_FRAC/HEAD_FRAC/CONTENT_BBOX 字典块）。

背景：战场单位卡图的抠图精灵，"脚（最低非透明像素）距画布底部"的比例
在全库浮动（步兵贴底、坦克偏高、飞机最高，同类还不一致）。
渲染时把整张纹理按中心居中会参差不齐，需要按"脚"对齐地面线。

本脚本遍历 assets/card_icons/*.png，读 alpha 通道找非透明 bbox：
- foot_frac = 脚距底比例、head_frac = 头距顶比例（地面对齐 + 头顶 UI 锚定）
- CONTENT_BBOX = 内容宽/高占画布比例（v6.14.8 起内容感知缩放的几何基础：
  战场立绘按"内容宽"而非"画布宽"归一，画布留白不再吃缩放）
就地更新 data/card_foot_anchors.gd 的三个字典块。

⚠️ 重要（2026-08-08 修复，2026-09-16 扩展）：本脚本只更新 FOOT_FRAC/HEAD_FRAC/
CONTENT_BBOX 三块，保留文件其余部分（KIND_SCALE_FACTOR / VISUAL_SCALE_OVERRIDE /
PLAYER_PLATFORM_TO_SCALE_ARCHETYPE / 查询函数等手工维护内容）。
早期版本会整体覆盖文件，冲掉这些手工内容导致全单位缩放崩溃。

用法：python tools/generate_card_foot_anchors.py
新增/替换卡图后需重跑本脚本（卡图换血后旧扫描数据全部失真）。
"""
import re
from pathlib import Path
from PIL import Image

# 相对脚本自身定位项目根目录（跨机器通用，2026-08-08 修正硬编码 F 盘路径）
ROOT = Path(__file__).resolve().parent.parent / "assets" / "card_icons"
OUT = Path(__file__).resolve().parent.parent / "data" / "card_foot_anchors.gd"

# alpha 阈值：大于此值视为非透明（去除边缘半透明噪声）
ALPHA_THRESH = 10
# 仅当脚距底比例超过此值才记录 foot/head（贴边的图用默认 0.0 即可，省表体积）
MIN_FRAC_TO_RECORD = 0.02

# 预生成阈值查找表（255 字节 → point() 走 C 速，比逐像素快两个量级）
_THRESH_TABLE = bytes(255 if i > ALPHA_THRESH else 0 for i in range(256))


def bbox_of(path: Path):
    """读 PNG alpha 通道，返回 (foot_frac, head_frac, w_frac, h_frac)。
    foot_frac = 脚（最低非透明像素）距纹理底部的比例（0.0~0.5）。
    head_frac = 头（最高非透明像素）距纹理顶部的比例（0.0~0.5）。
    w_frac/h_frac = 非透明内容宽/高占画布比例（全透明返回 None）。
    """
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    if h == 0 or w == 0:
        return None
    alpha = img.getchannel("A").point(_THRESH_TABLE)
    box = alpha.getbbox()  # (l, t, r, b)，全透明 None
    if box is None:
        return None
    left, top, right, bottom = box
    foot_px_from_bot = (h - 1) - bottom
    head_px_from_top = top
    return (
        foot_px_from_bot / float(h),
        head_px_from_top / float(h),
        (right - left) / float(w),
        (bottom - top) / float(h),
    )


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
    # 文件名 → (foot_frac, head_frac, w_frac, h_frac)（同名覆盖，值相同）
    anchor_map = {}
    for p in files:
        try:
            res = bbox_of(p)
        except Exception as e:
            print(f"  跳过 {p.name}: {e}")
            skipped += 1
            continue
        if res is None:
            skipped += 1
            continue
        anchor_map[p.stem] = tuple(round(v, 3) for v in res)
        recorded += 1

    print(f"记录 {recorded} 张，跳过 {skipped} 张（全透明/异常）")
    entries = sorted(anchor_map.items())

    # 生成字典块文本
    def build_block(dict_name: str, fmt) -> str:
        lines = ['const %s: Dictionary = {' % dict_name]
        for key, vals in entries:
            lines.append('\t"%s": %s,' % (key, fmt(vals)))
        lines.append('}')
        return "\n".join(lines)

    def frac_fmt(vals):
        return '%.3f' % vals

    def bbox_fmt(vals):
        return '[%.3f, %.3f]' % (vals[2], vals[3])

    foot_block = build_block("FOOT_FRAC", lambda v: '%.3f' % v[0])
    head_block = build_block("HEAD_FRAC", lambda v: '%.3f' % v[1])
    bbox_block = build_block("CONTENT_BBOX", lambda v: '[%.3f, %.3f]' % (v[2], v[3]))

    # 就地更新：读现有文件，用正则替换三个字典块，保留其余内容。
    # ⚠️ 这避免了早期版本"整体覆盖"冲掉 VISUAL_SCALE / 查询函数的致命 bug。
    if OUT.exists():
        content = OUT.read_text(encoding="utf-8")
        foot_pattern = re.compile(r'const FOOT_FRAC: Dictionary = \{[^}]*\}', re.DOTALL)
        head_pattern = re.compile(r'const HEAD_FRAC: Dictionary = \{[^}]*\}', re.DOTALL)
        bbox_pattern = re.compile(r'const CONTENT_BBOX: Dictionary = \{[^}]*\}', re.DOTALL)
        if not (foot_pattern.search(content) and head_pattern.search(content)):
            print(f"[错误] {OUT} 未找到 FOOT_FRAC/HEAD_FRAC 字典块，文件结构异常，跳过写入避免破坏。")
            return
        content = foot_pattern.sub(foot_block, content)
        content = head_pattern.sub(head_block, content)
        if bbox_pattern.search(content):
            content = bbox_pattern.sub(bbox_block, content)
        else:
            # 首次生成 CONTENT_BBOX：插在 HEAD_FRAC 块之后
            content = content.replace(head_block, head_block + "\n\n" + bbox_block, 1)
        OUT.write_text(content, encoding="utf-8")
        print(f"\n已就地更新 {OUT}（FOOT_FRAC/HEAD_FRAC/CONTENT_BBOX 三块，保留其余手工内容）")
    else:
        # 文件不存在 → 生成最小骨架（仅首次创建用；正常项目里文件已存在）
        lines = ['extends RefCounted', 'class_name CardFootAnchors', '']
        lines.append(foot_block)
        lines.append('')
        lines.append(head_block)
        lines.append('')
        lines.append(bbox_block)
        lines.append('')
        lines.append('static func get_foot_frac(file_name: String) -> float:')
        lines.append('\treturn float(FOOT_FRAC.get(file_name, 0.0))')
        lines.append('')
        OUT.write_text("\n".join(lines), encoding="utf-8")
        print(f"\n已创建 {OUT}（首次生成骨架，请手工补充缩放模型等表）")
    print(f"表项数：{len(entries)}")

    # 打印分布统计
    if entries:
        foot_fracs = [v[0] for _, v in entries]
        head_fracs = [v[1] for _, v in entries]
        w_fracs = [v[2] for _, v in entries]
        print(f"foot_frac 分布：min={min(foot_fracs):.3f} max={max(foot_fracs):.3f} avg={sum(foot_fracs)/len(foot_fracs):.3f}")
        print(f"head_frac 分布：min={min(head_fracs):.3f} max={max(head_fracs):.3f} avg={sum(head_fracs)/len(head_fracs):.3f}")
        print(f"内容宽占比分布：min={min(w_fracs):.3f} max={max(w_fracs):.3f} avg={sum(w_fracs)/len(w_fracs):.3f}")
        # 内容宽极值抽样（模型敏感项：占比越小、同等档位下放大越多）
        by_w = sorted(entries, key=lambda kv: kv[1][2])
        print("\n内容宽最小 8 张（留白最大）：")
        for key, v in by_w[:8]:
            print(f"  {key}: w={v[2]:.3f} h={v[3]:.3f} foot={v[0]:.3f}")
        print("内容宽最大 8 张（几乎满画布）：")
        for key, v in by_w[-8:]:
            print(f"  {key}: w={v[2]:.3f} h={v[3]:.3f} foot={v[0]:.3f}")


if __name__ == "__main__":
    main()
