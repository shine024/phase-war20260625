#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
v17d 锐利粒子贴图生成（PIL 程序化，非 AI——粒子贴图要的是锐边/可控，AI 出的是软斑）
================================================================
产物（assets/effects/particle_textures/，覆盖旧软圆斑的"新文件不改旧名"三张）：
  muzzle_star.png  128×128  轻武器枪口火星：白热核 + 4 细星芒（硬边）
  flame_star.png   160×160  重型枪口火焰：8 放射火舌（白核→橙→红，锐利三角舌）
  spark_streak.png 128×24   火花拖痕：白热头 + 橙尾的锥形条（指向 +X）
生成后打印内容 bbox（消费方按实寸标定 scale 的依据，v17b 教训）。
"""
import os
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "assets", "effects", "particle_textures")

def report(name):
    im = Image.open(os.path.join(OUT, name))
    bbox = im.getbbox()
    print("%-18s canvas=%s 内容=%s" % (name, im.size, bbox))

# ── 1. muzzle_star：白热核 + 4 细星芒（±X/±Y，硬边线性衰减） ──
def gen_muzzle_star():
    S = 128
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = cy = S // 2
    # 星芒：两条正交细楔形（X 向稍长——枪口方向暗示），三层嵌套递减 alpha 模拟衰减
    for (dx, dy, length) in [(1, 0, 52), (-1, 0, 40), (0, 1, 36), (0, -1, 36)]:
        for i, (col, frac, halfw) in enumerate([
                ((255, 235, 170, 255), 1.0, 2.2),
                ((255, 190, 90, 200), 0.68, 1.6),
                ((255, 130, 40, 120), 0.40, 1.1)]):
            L = length * frac
            d.polygon([(cx, cy),
                       (cx + dx * L, cy + dy * L - halfw),
                       (cx + dx * L, cy + dy * L + halfw)],
                      fill=col)
    # 白热核：两层小圆
    d.ellipse([cx - 9, cy - 9, cx + 9, cy + 9], fill=(255, 250, 225, 255))
    d.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], fill=(255, 255, 255, 255))
    img = img.filter(ImageFilter.GaussianBlur(0.6))  # 极轻抗锯齿，保持锐度
    img.save(os.path.join(OUT, "muzzle_star.png"))

# ── 2. flame_star：8 放射火舌（长短交替），三层色温（白核→橙→红）+ 白热基核 ──
def gen_flame_star():
    S = 160
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = cy = S // 2
    import math
    for k in range(8):
        ang = k * math.tau / 8 + (0.18 if k % 2 else 0.0)  # 略去对称死板感
        long_t = (k % 2 == 0)
        for (col, frac, halfw) in [
                ((255, 240, 190, 255), 1.00, 3.4),
                ((255, 160, 40, 235), 0.66, 5.2),
                ((220, 60, 15, 170), 0.34, 6.6)]:
            L = (74 if long_t else 48) * frac
            tipx, tipy = cx + math.cos(ang) * L, cy + math.sin(ang) * L
            px, py = -math.sin(ang), math.cos(ang)  # 法向
            d.polygon([(cx, cy),
                       (tipx + px * halfw, tipy + py * halfw),
                       (tipx - px * halfw, tipy - py * halfw)],
                      fill=col)
    d.ellipse([cx - 13, cy - 13, cx + 13, cy + 13], fill=(255, 245, 215, 255))
    d.ellipse([cx - 8, cy - 8, cx + 8, cy + 8], fill=(255, 255, 255, 255))
    img = img.filter(ImageFilter.GaussianBlur(0.8))
    img.save(os.path.join(OUT, "flame_star.png"))

# ── 3. spark_streak：白热头（右）+ 橙锥尾（左），指向 +X，硬边 ──
def gen_spark_streak():
    W, H = 128, 24
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cy = H // 2
    # 尾：三级锥形（长而细，alpha 递减）
    for (x_end, col, halfh) in [
            (10, (255, 120, 30, 70), 1.2),
            (40, (255, 170, 60, 160), 2.2),
            (82, (255, 210, 110, 220), 3.4)]:
        d.polygon([(118, cy), (x_end, cy - halfh), (x_end, cy + halfh)], fill=col)
    # 头：白热椭圆核（最亮最实）
    d.ellipse([102, cy - 6, 124, cy + 6], fill=(255, 250, 230, 255))
    d.ellipse([108, cy - 3.5, 120, cy + 3.5], fill=(255, 255, 255, 255))
    img = img.filter(ImageFilter.GaussianBlur(0.5))
    img.save(os.path.join(OUT, "spark_streak.png"))

def gen_shard_metal():
    S = 128
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # 不规则七边形破片轮廓（手工定的棱角顶点——避免对称/圆润）
    pts = [(38, 30), (72, 22), (94, 44), (98, 72), (78, 100), (46, 104), (26, 66)]
    d.polygon(pts, fill=(58, 63, 72, 255))          # 本体暗钢
    # 上部面片（受光更亮）——沿轮廓上半切一层
    d.polygon([(38, 30), (72, 22), (94, 44), (78, 56), (48, 52), (30, 46)],
              fill=(96, 103, 116, 255))
    # 下部面片（背光更暗）
    d.polygon([(26, 66), (48, 52), (78, 56), (78, 100), (46, 104)],
              fill=(38, 41, 48, 255))
    # 撕裂面炽热边（右下缘一层橙白描边 = 刚从爆炸撕下来的高温断面）
    d.line([(94, 44), (98, 72), (78, 100), (46, 104)], fill=(255, 200, 120, 235), width=4)
    d.line([(94, 44), (98, 72), (78, 100), (46, 104)], fill=(255, 245, 210, 255), width=2)
    # 两点高光闪烁（金属反光）
    d.ellipse([56, 36, 63, 43], fill=(220, 228, 240, 255))
    d.ellipse([70, 70, 75, 75], fill=(200, 208, 222, 255))
    img = img.filter(ImageFilter.GaussianBlur(0.5))
    img.save(os.path.join(OUT, "shard_metal.png"))

# ── 4a. muzzle_jet：侧视前向喷流（右白热核 + 左橙尾焰，非四向对称）──
def gen_muzzle_jet():
    W, H = 100, 46
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = W - 16, H // 2
    # 白热核（右端）
    d.ellipse([cx - 10, cy - 8, cx + 10, cy + 8], fill=(255, 250, 230, 255))
    d.ellipse([cx - 6, cy - 5, cx + 6, cy + 5], fill=(255, 255, 255, 255))
    # 三层橙尾锥（向左递减）
    for (x_end, col, halfh) in [
            (18, (255, 220, 100, 230), 6),
            (42, (255, 170, 50, 180), 9),
            (70, (255, 120, 30, 100), 12)]:
        d.polygon([(cx, cy - 4), (x_end, cy - halfh), (x_end, cy + halfh), (cx, cy + 4)],
                  fill=col)
    img = img.filter(ImageFilter.GaussianBlur(0.4))
    img.save(os.path.join(OUT, "muzzle_jet.png"))

# ── 4b/4c/4d 三种形态各异的破片（随机选 → 视觉多样性）──
def gen_shard_v1():
    """三角碎片：瘦长等腰，炽热尖端"""
    S = 128
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pts = [(64, 12), (104, 100), (24, 100)]
    d.polygon(pts, fill=(72, 78, 88, 255))
    d.polygon([(64, 12), (84, 60), (44, 60)], fill=(110, 118, 130, 255))  # 受光
    d.polygon([(104, 100), (64, 88), (24, 100)], fill=(42, 46, 52, 255))  # 背光
    d.line([(64, 12), (104, 100), (24, 100)], fill=(255, 200, 120, 255), width=3)
    d.ellipse([58, 18, 68, 28], fill=(255, 252, 240, 255))
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    img.save(os.path.join(OUT, "shard_metal_v1.png"))

def gen_shard_v2():
    """不规则四边形：扁平薄片，撕裂边在右"""
    S = 128
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pts = [(28, 36), (96, 24), (108, 88), (36, 96)]
    d.polygon(pts, fill=(60, 66, 76, 255))
    d.polygon([(28, 36), (96, 24), (70, 60), (36, 56)], fill=(100, 108, 122, 255))
    d.polygon([(36, 56), (70, 60), (108, 88), (36, 96)], fill=(38, 42, 50, 255))
    d.line([(96, 24), (108, 88)], fill=(255, 190, 100, 240), width=4)
    d.ellipse([80, 34, 90, 44], fill=(230, 238, 250, 255))
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    img.save(os.path.join(OUT, "shard_metal_v2.png"))

def gen_shard_v3():
    """锐角碎块：近似菱形，多面朝"""
    S = 128
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pts = [(64, 10), (108, 58), (76, 112), (20, 64)]
    d.polygon(pts, fill=(56, 62, 72, 255))
    d.polygon([(64, 10), (108, 58), (64, 50)], fill=(104, 112, 128, 255))
    d.polygon([(20, 64), (64, 50), (64, 112)], fill=(36, 40, 48, 255))
    d.line([(108, 58), (76, 112)], fill=(255, 180, 90, 240), width=4)
    d.ellipse([84, 34, 94, 44], fill=(240, 248, 255, 255))
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    img.save(os.path.join(OUT, "shard_metal_v3.png"))

# ── 5. flame_jet_sym：重型枪口水平火舌（对称，指向 ±X）──
# v18-R5：flame_star 的 8 臂放射星形被 AI 读成"径向爆散/无方向扩散的火花炸散"
# （火箭/导弹枪口 2-4 分主诉）。粒子不随速度旋转 + spawn_impact_sprite 随机旋转，
# 故贴图必须对称（同 muzzle_jet_sym 范式）。水平拉长的火舌 + 白热核 = 定向喷射读感。
def gen_flame_jet_sym():
    W, H = 160, 56
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = W // 2, H // 2
    # 双侧三层锥（内亮黄短宽 → 中橙 → 外红长淡），水平延伸 = 喷射方向
    for sgn in (1, -1):
        for (L, col, halfh) in [
                (30, (255, 235, 160, 255), 10),
                (52, (255, 165, 50, 225), 7),
                (72, (225, 70, 20, 150), 4)]:
            tip = cx + sgn * L
            d.polygon([(cx + sgn * 6, cy - 5), (tip, cy - halfh), (tip, cy + halfh), (cx + sgn * 6, cy + 5)], fill=col)
    # 白热核（中心，双层）
    d.ellipse([cx - 12, cy - 9, cx + 12, cy + 9], fill=(255, 248, 220, 255))
    d.ellipse([cx - 7, cy - 5, cx + 7, cy + 5], fill=(255, 255, 255, 255))
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    img.save(os.path.join(OUT, "flame_jet_sym.png"))

os.makedirs(OUT, exist_ok=True)
gen_muzzle_star()
gen_flame_star()
gen_spark_streak()
gen_shard_metal()
gen_muzzle_jet()
gen_shard_v1()
gen_shard_v2()
gen_shard_v3()
gen_flame_jet_sym()
for n in ["muzzle_star.png", "flame_star.png", "spark_streak.png", "shard_metal.png",
           "muzzle_jet.png", "shard_metal_v1.png", "shard_metal_v2.png", "shard_metal_v3.png",
           "flame_jet_sym.png"]:
    report(n)
print("done →", OUT)
