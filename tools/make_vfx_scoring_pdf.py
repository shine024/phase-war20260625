#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 VFX 展示场截图 + 说明做成 PDF 评分册(给 DeepSeek 识图打分用)。

每页:一张特效截图 + 类别/时代/参考武器/描述 + "评分:___/10"。
首页:打分任务说明 + 真实感参考基准。
【盲评】不显示 agnes 的分数,避免偏见 —— 事后可与 docs/vfx_realism_report.json 对比。

用法:
  python tools/make_vfx_scoring_pdf.py
输出: docs/VFX真实度评分册_DeepSeek.pdf
"""
import json
import os
import textwrap

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHOTS = os.path.join(os.environ["APPDATA"], "Godot", "app_userdata", "phase-war", "vfx_shots")
MANIFEST = os.path.join(SHOTS, "manifest.json")
OUT_PDF = os.path.join(ROOT, "docs", "VFX真实度评分册_DeepSeek.pdf")

FONT_REG = "C:/Windows/Fonts/msyh.ttc"
FONT_BOLD = "C:/Windows/Fonts/msyhbd.ttc"

PAGE_W = 1280
IMG_H = 720
CAP_H = 200
PAGE_H = IMG_H + CAP_H


def font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except Exception:
        return ImageFont.load_default()


def wrap_cjk(text, max_chars):
    """中文按字符数换行(兼顾英文)。"""
    lines = []
    for para in text.split("\n"):
        cur = ""
        for ch in para:
            cur += ch
            if len(cur) >= max_chars:
                lines.append(cur)
                cur = ""
        lines.append(cur)
    return lines


def build_cover():
    img = Image.new("RGB", (PAGE_W, PAGE_H), (250, 250, 252))
    d = ImageDraw.Draw(img)
    f_title = font(FONT_BOLD, 46)
    f_h = font(FONT_BOLD, 26)
    f_b = font(FONT_REG, 21)
    y = 40
    d.text((60, y), "Phase War — VFX 真实度评分册", font=f_title, fill=(20, 20, 30))
    y += 70
    d.text((60, y), "(供 DeepSeek 识图模式独立打分 · 盲评,不含其他模型分数)", font=f_b, fill=(90, 90, 110))
    y += 50

    blocks = [
        ("【任务】", "对后续每一页的战斗特效截图打分(1-10 整数,10 最真实)。"),
        ("【重要】",
         "每张是 2D 战术游戏的实战截图:特效叠在战场背景 + 装甲目标之上。背景、载具、"
         "阴影是场景上下文,非评估对象——只评估特效本身在该场景中是否读起来像一次真实"
         "的命中/开火/爆裂。特效叠在目标上、读起来像\"打中了装甲\"才是高分。"),
        ("【不要因 2D 画风直接给低分】",
         "请以\"同风格 2D 军事游戏的高水准 VFX\"为基准。画风是 2D 不等于低分;孤立漂浮、"
         "与场景脱节、缺层次(无烟/无碎片/无闪光)才是低分。"),
        ("【真实感参考基准】", ""),
    ]
    for head, body in blocks:
        d.text((60, y), head, font=f_h, fill=(180, 50, 30))
        y += 34
        for ln in wrap_cjk(body, 52):
            d.text((80, y), ln, font=f_b, fill=(40, 40, 50))
            y += 30
        y += 8

    rubric = [
        "• 爆炸/地面爆裂:体积感火球(非平面圆盘)、翻滚黑/灰烟柱、扩散尘土环、地面焦痕、",
        "  四散碎片、瞬时强光;核心 白→黄→橙→暗红 渐变。",
        "• 子弹/动能命中金属:明亮金属火花锥(细长、向上扇散)、少量烟、破片。",
        "• 能量武器/激光:高亮核心 + 辉光晕 + 残留电弧/余晖。",
        "• 穿透/闪电:锐利线状光迹 + 分支 + 末端闪光。",
        "• 蘑菇云/核爆:明显蘑菇形(茎+冠)、翻滚烟尘、火光、冲击波环、地面大面积焦痕。",
    ]
    for ln in rubric:
        d.text((80, y), ln, font=f_b, fill=(40, 40, 50))
        y += 28
    y += 14
    d.text((60, y), "每页底部有\"评分:___/10\",请逐页给出分数与一句总评。", font=f_h, fill=(20, 80, 40))
    return img


def build_effect_page(png_path, idx, total, shot, cap_file):
    try:
        screenshot = Image.open(png_path).convert("RGB").resize((PAGE_W, IMG_H), Image.LANCZOS)
    except Exception:
        screenshot = Image.new("RGB", (PAGE_W, IMG_H), (200, 60, 60))
    page = Image.new("RGB", (PAGE_W, PAGE_H), (245, 245, 248))
    page.paste(screenshot, (0, 0))
    # caption strip
    cap_top = IMG_H
    d = ImageDraw.Draw(page)
    d.rectangle([0, cap_top, PAGE_W, PAGE_H], fill=(26, 28, 36))
    f_h = font(FONT_BOLD, 27)
    f_b = font(FONT_REG, 21)
    f_s = font(FONT_BOLD, 26)
    x = 40
    y = cap_top + 18
    header = "#%d/%d  %s   |   %s   |   %s   |   参考:%s" % (
        idx, total, shot["id"], shot.get("category", ""), shot.get("era", ""), shot.get("ref_weapon", ""))
    d.text((x, y), header, font=f_h, fill=(255, 210, 120))
    y += 40
    desc = shot.get("description", "")
    for ln in wrap_cjk(desc, 56):
        d.text((x, y), ln, font=f_b, fill=(220, 222, 230))
        y += 28
    y += 10
    d.text((x, y), "DeepSeek 评分: ____________  / 10      一句总评: ____________________________________",
           font=f_s, fill=(120, 230, 150))
    return page


def main():
    if not os.path.isfile(MANIFEST):
        sys_exit("manifest 不存在: " + MANIFEST)
    m = json.load(open(MANIFEST, encoding="utf-8"))
    shots = m.get("shots", [])
    # 展平为 (shot, capture_file)
    flats = []
    for s in shots:
        for c in s.get("captures", []):
            flats.append((s, c["file"]))
    total = len(flats)
    print("构建 PDF: 封面 + %d 个特效页" % total)

    pages = [build_cover()]
    for i, (s, cap_file) in enumerate(flats, 1):
        png = os.path.join(SHOTS, cap_file)
        pages.append(build_effect_page(png, i, total, s, cap_file))
        print("  [%d/%d] %s" % (i, total, cap_file))

    pages[0].save(OUT_PDF, "PDF", save_all=True, append_images=pages[1:], resolution=100.0)
    sz = os.path.getsize(OUT_PDF) // 1024
    print("\n[OK] PDF 已生成: %s  (%d 页, %d KB)" % (OUT_PDF, len(pages), sz))


def sys_exit(msg):
    import sys
    print("[FATAL] " + msg)
    sys.exit(1)


if __name__ == "__main__":
    main()
