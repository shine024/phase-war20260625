#!/usr/bin/env python3
"""程序化生成 21 张缺失改造模块图标（v9.1 组合技套路配套改造）。
不依赖网络/AI API，用 PIL 矢量绘制，风格统一可控。

设计：
- 512x512 RGB 白底（对齐现有改造图标规格）
- 套路主题色圆角方块底板（70% 占比，6 套路 6 主题色一眼可辨）
- 中央白色机械感矢量图形（每张独立几何造型，模拟扁平机械拟物）
- 主题色局部高光发光（呼应现有图标能量发光元素）
- 无文字无字母（避免与 UI 字母占位混淆）

输出到 docs/待生成改造图标_21张/，审核通过后用 deploy_mod_icons.py 部署。
"""
import os
import math
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_DIR = os.path.join(ROOT, "docs", "待生成改造图标_21张")
SIZE = 512

# 6 套路主题色（RGB）——燃烧橙红/电磁蓝紫/纳米青绿/光束亮黄/侦察灰蓝/化学黄绿
THEME_COLORS = {
    "burn":     (210,  80,  40),   # 助燃燃烧链 橙红
    "emp":      ( 90,  70, 200),   # 电磁脉冲链 蓝紫
    "nano":     ( 40, 180, 150),   # 纳米浓度场 青绿
    "beam":     (220, 180,  50),   # 光束谐振链 亮黄
    "recon":    ( 90, 130, 180),   # 侦察链式 灰蓝
    "chem":     (150, 180,  50),   # 化学污染场 黄绿
}

# 亮色变体（用于发光高光）
def lighten(c, amt=80):
    return tuple(min(255, x + amt) for x in c)

# 暗色变体（用于阴影描边）
def darken(c, amt=60):
    return tuple(max(0, x - amt) for x in c)


def new_canvas():
    """新建 512x512 纯白底画布。"""
    return Image.new("RGB", (SIZE, SIZE), (255, 255, 255))


def draw_rounded_panel(draw, theme, alpha_pct=18):
    """画圆角方块底板（半透明主题色）。
    PIL 的 RGB 模式无 alpha，用主题色与白底混合模拟淡色底板。
    """
    # 混合：主题色 * alpha + 白 * (1-alpha)
    a = alpha_pct / 100.0
    tc = THEME_COLORS[theme]
    panel_color = tuple(int(tc[i] * a + 255 * (1 - a)) for i in range(3))
    margin = int(SIZE * 0.10)  # 10% 边距
    radius = int(SIZE * 0.12)
    bbox = [margin, margin, SIZE - margin, SIZE - margin]
    draw.rounded_rectangle(bbox, radius=radius, fill=panel_color)
    # 描边（主题色加深）
    draw.rounded_rectangle(bbox, radius=radius, outline=darken(tc, 30), width=3)


def draw_glow_dot(draw, center, radius, color):
    """画一个发光圆点（中心亮色 + 外环主题色）。"""
    x, y = center
    # 外环
    draw.ellipse([x - radius, y - radius, x + radius, y + radius],
                 fill=lighten(color, 40))
    # 内核
    r2 = max(2, radius // 2)
    draw.ellipse([x - r2, y - r2, x + r2, y + r2], fill=(255, 255, 255))


def cx():
    return SIZE // 2


# ============ 21 个图标的绘制函数 ============
# 每个函数签名: draw_icon(draw, theme) —— theme 用于取主题色
# 图形主体用白色 + 主题色描边/高光，模拟机械部件

def _shell_body(draw, cx_, cy_, length=200, width=70, color=(255,255,255), outline=(60,60,60)):
    """画一个竖直炮弹主体（锥头朝上 + 圆柱身 + 尾翼）。"""
    half_w = width // 2
    top = cy_ - length // 2
    bot = cy_ + length // 2
    nose_h = int(length * 0.35)
    # 锥头
    draw.polygon([(cx_, top), (cx_ - half_w, top + nose_h), (cx_ + half_w, top + nose_h)],
                 fill=color, outline=outline)
    # 圆柱身
    body_top = top + nose_h
    draw.rectangle([cx_ - half_w, body_top, cx_ + half_w, bot - int(length*0.12)],
                   fill=color, outline=outline)
    # 尾翼（左右两个三角）
    fin_h = int(length * 0.18)
    fin_w = int(width * 0.45)
    draw.polygon([(cx_ - half_w, bot - fin_h), (cx_ - half_w - fin_w, bot),
                  (cx_ - half_w, bot)], fill=color, outline=outline)
    draw.polygon([(cx_ + half_w, bot - fin_h), (cx_ + half_w + fin_w, bot),
                  (cx_ + half_w, bot)], fill=color, outline=outline)
    return top, bot, body_top  # 返回关键 y 坐标供高光定位


# --- 套路1 助燃燃烧链（橙红）4 张 ---
def draw_thermolite(draw, theme):
    """温压弹：粗壮弹体 + 弹头燃烧核心。"""
    c = THEME_COLORS[theme]
    _, _, body_top = _shell_body(draw, cx(), cx(), length=260, width=110)
    # 弹头燃烧发光（橙红）
    draw_glow_dot(draw, (cx(), body_top + 30), 22, c)
    # 弹身环带（云爆剂扩散环）
    draw.line([(cx()-55, body_top+90), (cx()+55, body_top+90)], fill=darken(c,20), width=4)

def draw_ammo_incendiary(draw, theme):
    """助燃剂弹：弹体 + 窗口内镁粉灼热。"""
    c = THEME_COLORS[theme]
    top, bot, body_top = _shell_body(draw, cx(), cx(), length=250, width=90)
    # 观察窗（椭圆）
    wx, wy = cx(), body_top + 70
    draw.ellipse([wx-25, wy-18, wx+25, wy+18], fill=darken(c,40), outline=(60,60,60), width=2)
    # 窗内镁粉发光
    draw_glow_dot(draw, (wx, wy), 12, c)

def draw_ammo_phosphorus(draw, theme):
    """白磷弹：弹体 + 侧释放孔冒烟。"""
    c = THEME_COLORS[theme]
    _, _, body_top = _shell_body(draw, cx(), cx(), length=250, width=90)
    # 弹身标识带（橙黄，白磷燃烧色）
    draw.rectangle([cx()-45, body_top+50, cx()+45, body_top+70], fill=lighten(c,30), outline=(60,60,60))
    # 释放孔（3个小圆）
    for dy in [100, 130]:
        draw_glow_dot(draw, (cx()+50, body_top+dy), 8, lighten(c,40))

def draw_combustion_catalyst(draw, theme):
    """燃烧催化剂：圆筒反应舱 + 内部催化燃烧核心。"""
    c = THEME_COLORS[theme]
    # 圆筒舱
    draw.rounded_rectangle([cx()-70, cx()-110, cx()+70, cx()+110], radius=30,
                           fill=(255,255,255), outline=(60,60,60), width=3)
    # 顶部注入阀
    draw.rectangle([cx()-15, cx()-125, cx()+15, cx()-110], fill=(180,180,180), outline=(60,60,60))
    # 内部催化核心发光
    draw_glow_dot(draw, (cx(), cx()), 35, c)
    # 反应环
    draw.ellipse([cx()-50, cx()-50, cx()+50, cx()+50], outline=darken(c,10), width=3)


# --- 套路2 电磁脉冲链（蓝紫）4 张 ---
def draw_emp_warhead(draw, theme):
    """电磁战斗部：弹体 + 前端电弧环。"""
    c = THEME_COLORS[theme]
    _, _, body_top = _shell_body(draw, cx(), cx(), length=250, width=90)
    # 前端电弧环（同心圆）
    for r, w in [(28,3),(18,2)]:
        draw.ellipse([cx()-r, body_top+10-r+15, cx()+r, body_top+10+r+15],
                     outline=c, width=w)
    draw_glow_dot(draw, (cx(), body_top+25), 10, c)
    # 弹身电弧纹（锯齿线）
    pts = []
    for i in range(5):
        x = cx() - 30 + i*15
        y = body_top + 80 + (0 if i%2==0 else 15)
        pts.append((x,y))
    draw.line(pts, fill=c, width=3)

def draw_antiradiation(draw, theme):
    """反辐射导弹：细长导弹 + 导引头传感阵列。"""
    c = THEME_COLORS[theme]
    _, _, body_top = _shell_body(draw, cx(), cx(), length=300, width=64)
    # 导引头传感阵列（前端小圆点矩阵）
    for dx in [-12, 0, 12]:
        draw_glow_dot(draw, (cx()+dx, body_top+18), 6, c)
    # 弹身中部弹翼标识
    draw.rectangle([cx()-30, body_top+100, cx()+30, body_top+112], fill=lighten(c,40), outline=(60,60,60))

def draw_ammo_graphite(draw, theme):
    """石墨纤维弹：弹体剖开处碳纤维线团 + 导电电弧。"""
    c = THEME_COLORS[theme]
    _, _, body_top = _shell_body(draw, cx(), cx(), length=250, width=90)
    # 剖开窗口
    draw.rectangle([cx()-40, body_top+60, cx()+40, body_top+130], fill=(40,40,40), outline=(60,60,60))
    # 碳纤维线团（乱线）
    import random
    rng = random.Random(42)
    for _ in range(8):
        x1 = cx() + rng.randint(-30,30)
        y1 = body_top + 60 + rng.randint(0,70)
        x2 = x1 + rng.randint(-15,15)
        y2 = y1 + rng.randint(-10,10)
        draw.line([(x1,y1),(x2,y2)], fill=(200,200,200), width=1)
    # 导电电弧微光
    draw_glow_dot(draw, (cx(), body_top+95), 12, c)

def draw_overload(draw, theme):
    """过载电容：电容阵列方盒 + 强烈电弧。"""
    c = THEME_COLORS[theme]
    # 方盒外壳
    draw.rounded_rectangle([cx()-100, cx()-90, cx()+100, cx()+90], radius=15,
                           fill=(255,255,255), outline=(60,60,60), width=3)
    # 顶部接线柱（2个）
    for dx in [-35, 35]:
        draw.rectangle([cx()+dx-8, cx()-105, cx()+dx+8, cx()-90], fill=(180,180,180), outline=(60,60,60))
    # 电容阵列（3个圆柱）
    for dx in [-45, 0, 45]:
        draw.ellipse([cx()+dx-18, cx()-55, cx()+dx+18, cx()-25], fill=(220,220,220), outline=(60,60,60))
        draw.rectangle([cx()+dx-18, cx()-40, cx()+dx+18, cx()+40], fill=(220,220,220), outline=(60,60,60))
        draw.ellipse([cx()+dx-18, cx()+25, cx()+dx+18, cx()+55], fill=(200,200,200), outline=(60,60,60))
    # 过载电弧（锯齿，电容间）
    for dx in [-22, 22]:
        pts = [(cx()+dx, cx()-15), (cx()+dx+8, cx()), (cx()+dx-4, cx()+15)]
        draw.line(pts, fill=c, width=3)


# --- 套路3 纳米浓度场（青绿）3 张 ---
def draw_nano_amp(draw, theme):
    """纳米放大器：球面谐振腔 + 纳米粒子云旋涡。"""
    c = THEME_COLORS[theme]
    # 外环谐振线圈
    draw.ellipse([cx()-110, cx()-110, cx()+110, cx()+110], outline=darken(c,20), width=4)
    # 球面腔
    draw.ellipse([cx()-80, cx()-80, cx()+80, cx()+80], fill=(255,255,255), outline=(60,60,60), width=3)
    # 顶部聚焦透镜
    draw.rectangle([cx()-12, cx()-125, cx()+12, cx()-110], fill=(180,180,180), outline=(60,60,60))
    # 纳米粒子云旋涡（螺旋点）
    import random
    rng = random.Random(7)
    for i in range(24):
        ang = i * 0.5
        r = 15 + i * 2.2
        if r > 65: break
        x = cx() + int(math.cos(ang) * r)
        y = cx() + int(math.sin(ang) * r)
        draw_glow_dot(draw, (x, y), 4, c)

def draw_nano_seeder(draw, theme):
    """纳米播种机：圆筒储罐 + 顶部喷嘴喷雾。"""
    c = THEME_COLORS[theme]
    # 圆筒储罐
    draw.rounded_rectangle([cx()-65, cx()-70, cx()+65, cx()+100], radius=20,
                           fill=(255,255,255), outline=(60,60,60), width=3)
    # 顶部喷嘴（3个）
    for dx in [-25, 0, 25]:
        draw.rectangle([cx()+dx-6, cx()-85, cx()+dx+6, cx()-70], fill=(180,180,180), outline=(60,60,60))
    # 喷雾流（向上扩散的点）
    import random
    rng = random.Random(11)
    for dx0 in [-25, 0, 25]:
        for i in range(6):
            x = cx()+dx0 + rng.randint(-12,12)
            y = cx()-90 - i*8
            draw_glow_dot(draw, (x, y), 3, c)
    # 观察窗
    draw.ellipse([cx()-20, cx()+10, cx()+20, cx()+50], fill=darken(c,60), outline=(60,60,60))

def draw_nano_catalyst(draw, theme):
    """纳米催化剂：六边形反应核心 + 增殖轨道。"""
    c = THEME_COLORS[theme]
    # 外环增殖轨道
    draw.ellipse([cx()-120, cx()-120, cx()+120, cx()+120], outline=darken(c,30), width=3)
    # 六边形核心
    def hexagon(cx_, cy_, r):
        return [(cx_ + r*math.cos(math.radians(60*i)), cy_ + r*math.sin(math.radians(60*i))) for i in range(6)]
    draw.polygon(hexagon(cx(), cx(), 70), fill=(255,255,255), outline=(60,60,60))
    # 核心发光
    draw_glow_dot(draw, (cx(), cx()), 30, c)
    # 三个能量护盾节点
    for i in range(3):
        ang = math.radians(90 + i*120)
        x = cx() + int(math.cos(ang)*95)
        y = cx() + int(math.sin(ang)*95)
        draw_glow_dot(draw, (x,y), 10, lighten(c,40))


# --- 套路4 光束谐振链（亮黄）4 张 ---
def _laser_emitter(draw, cx_, cy_, length, width, color):
    """通用激光发射筒：长筒 + 前端透镜光束。"""
    half_w = width // 2
    draw.rounded_rectangle([cx_-half_w, cy_-length//2, cx_+half_w, cy_+length//2],
                           radius=half_w, fill=(255,255,255), outline=(60,60,60), width=3)
    # 前端透镜
    draw.ellipse([cx_-half_w-5, cy_+length//2-half_w-5, cx_+half_w+5, cy_+length//2+half_w+5],
                 fill=lighten(color,40), outline=(60,60,60), width=2)

def draw_targeting_laser(draw, theme):
    """瞄准激光：长筒吊舱 + 前端激光束。"""
    c = THEME_COLORS[theme]
    # 横置长筒
    draw.rounded_rectangle([cx()-140, cx()-30, cx()+120, cx()+30], radius=25,
                           fill=(255,255,255), outline=(60,60,60), width=3)
    # 散热栅格
    for i in range(4):
        x = cx() - 100 + i*20
        draw.line([(x, cx()-20),(x, cx()+20)], fill=(180,180,180), width=3)
    # 前端透镜 + 激光束
    draw.ellipse([cx()+110, cx()-35, cx()+150, cx()+35], fill=lighten(c,40), outline=(60,60,60), width=2)
    # 光束（向右发射）
    draw.line([(cx()+130, cx()),(cx()+200, cx())], fill=c, width=6)
    draw_glow_dot(draw, (cx()+130, cx()), 14, c)

def draw_beam_splitter(draw, theme):
    """光束分裂器：中央立方棱镜 + 入射主光束分裂为多道。"""
    c = THEME_COLORS[theme]
    # 立方棱镜（菱形透视）
    draw.polygon([(cx(), cx()-70),(cx()+70, cx()),(cx(), cx()+70),(cx()-70, cx())],
                 fill=(255,255,255), outline=(60,60,60))
    # 棱镜内分光线
    draw.line([(cx(), cx()-70),(cx(), cx()+70)], fill=(180,180,180), width=2)
    draw.line([(cx()-70, cx()),(cx()+70, cx())], fill=(180,180,180), width=2)
    # 入射主光束（左侧）
    draw.line([(cx()-160, cx()),(cx()-70, cx())], fill=c, width=6)
    # 分裂次级光束（右上、右下）
    draw.line([(cx()+70, cx()),(cx()+160, cx()-60)], fill=c, width=4)
    draw.line([(cx()+70, cx()),(cx()+160, cx()+60)], fill=c, width=4)
    # 入射发光点
    draw_glow_dot(draw, (cx()-70, cx()), 10, c)

def draw_reflector(draw, theme):
    """反射阵列：多面反射镜 + 反射光束。"""
    c = THEME_COLORS[theme]
    # 中央支柱
    draw.rectangle([cx()-6, cx()-120, cx()+6, cx()+120], fill=(180,180,180), outline=(60,60,60))
    # 三面反射镜（不同角度）
    mirrors = [(-50, -60, 1), (50, -60, -1), (0, 60, 0)]  # (dx, dy, 方向)
    for dx, dy, sgn in mirrors:
        mx, my = cx()+dx, cx()+dy
        draw.polygon([(mx-30, my-20),(mx+30, my-20),(mx+30, my+20),(mx-30, my+20)],
                     fill=(240,240,250), outline=lighten(c,20), width=3)
    # 反射光束
    draw.line([(cx(), cx()-180),(cx()-50, cx()-60)], fill=c, width=4)
    draw.line([(cx()+50, cx()-60),(cx()+180, cx()-120)], fill=c, width=4)
    draw_glow_dot(draw, (cx(), cx()-180), 10, c)

def draw_optical_fiber(draw, theme):
    """光纤链路：终端盒 + 盘绕光纤线圈发光。"""
    c = THEME_COLORS[theme]
    # 终端盒
    draw.rounded_rectangle([cx()-90, cx()-50, cx()+90, cx()+50], radius=12,
                           fill=(255,255,255), outline=(60,60,60), width=3)
    # 面板指示灯（3个小圆）
    for dx in [-40, 0, 40]:
        draw_glow_dot(draw, (cx()+dx, cx()-30), 6, c)
    # 盘绕光纤线圈（右侧，同心椭圆）
    for r in [25, 40, 55]:
        draw.ellipse([cx()+100-r, cx()-r//2, cx()+100+r, cx()+r//2],
                     outline=c, width=2)
    # 光信号脉冲点
    import random
    rng = random.Random(3)
    for _ in range(6):
        ang = rng.uniform(0, 6.28)
        r = rng.choice([25,40,55])
        x = cx()+100 + int(math.cos(ang)*r)
        y = cx() + int(math.sin(ang)*r//2)
        draw_glow_dot(draw, (x,y), 4, lighten(c,50))


# --- 套路5 侦察链式（灰蓝）2 张 ---
def draw_targeting_drone(draw, theme):
    """目标指示无人机：四旋翼机体 + 吊舱标定十字。"""
    c = THEME_COLORS[theme]
    # 机体（中央方块）
    draw.rounded_rectangle([cx()-35, cx()-25, cx()+35, cx()+25], radius=8,
                           fill=(255,255,255), outline=(60,60,60), width=3)
    # 四旋翼臂 + 螺旋桨
    for dx, dy in [(-55,-40),(55,-40),(-55,40),(55,40)]:
        ax, ay = cx()+dx, cx()+dy
        draw.line([(cx() + (35 if dx>0 else -35), cx() + (dy//2)), (ax, ay)], fill=(60,60,60), width=4)
        # 螺旋桨（椭圆）
        draw.ellipse([ax-18, ay-4, ax+18, ay+4], fill=(200,200,200), outline=(120,120,120))
    # 吊舱（机腹下方）
    draw.ellipse([cx()-18, cx()+25, cx()+18, cx()+55], fill=(220,220,220), outline=(60,60,60), width=2)
    # 标定十字光斑（再下方）
    draw.line([(cx(), cx()+55),(cx(), cx()+90)], fill=c, width=3)
    draw.line([(cx()-15, cx()+72),(cx()+15, cx()+72)], fill=c, width=3)
    draw_glow_dot(draw, (cx(), cx()+72), 8, c)

def draw_weakpoint(draw, theme):
    """弱点分析仪：方形主机 + 全息弱点红框锁定。"""
    c = THEME_COLORS[theme]
    # 方形主机
    draw.rounded_rectangle([cx()-100, cx()-80, cx()+100, cx()+80], radius=15,
                           fill=(255,255,255), outline=(60,60,60), width=3)
    # 面板屏幕
    draw.rounded_rectangle([cx()-70, cx()-55, cx()+70, cx()+30], radius=8,
                           fill=(245,245,250), outline=(120,120,120), width=2)
    # 全息目标弱点扫描（屏幕内：目标轮廓 + 红框锁定）
    # 目标轮廓（简化坦克侧视）
    draw.rectangle([cx()-35, cx()-15, cx()+35, cx()+5], fill=(200,200,210), outline=(120,120,120))
    draw.ellipse([cx()-30, cx(), cx()-15, cx()+15], fill=(120,120,120))
    draw.ellipse([cx()+15, cx(), cx()+30, cx()+15], fill=(120,120,120))
    # 弱点红框（锁定标记）
    draw.rectangle([cx()-12, cx()-25, cx()+12, cx()-8], outline=(220,60,40), width=3)
    draw_glow_dot(draw, (cx(), cx()-16), 5, (220,80,60))


# --- 套路6 化学污染场（黄绿）4 张 ---
def draw_acid(draw, theme):
    """酸液战斗部：弹体 + 酸液储罐滴落。"""
    c = THEME_COLORS[theme]
    _, _, body_top = _shell_body(draw, cx(), cx(), length=250, width=90)
    # 酸液储罐窗口（绿色）
    draw.rounded_rectangle([cx()-35, body_top+60, cx()+35, body_top+120], radius=10,
                           fill=lighten(c,40), outline=(60,60,60), width=2)
    # 酸液滴落（底部）
    for dx in [-20, 0, 20]:
        draw.ellipse([cx()+dx-5, body_top+145, cx()+dx+5, body_top+160],
                     fill=lighten(c,30))
    # 蒸气（上方小点）
    import random
    rng = random.Random(5)
    for _ in range(5):
        x = cx() + rng.randint(-30,30)
        y = body_top + 40 + rng.randint(-15,0)
        draw_glow_dot(draw, (x,y), 3, lighten(c,60))

def draw_ammo_chem(draw, theme):
    """化学集束弹：母弹 + 内含小子弹 + 毒剂云。"""
    c = THEME_COLORS[theme]
    _, _, body_top = _shell_body(draw, cx(), cx(), length=250, width=95)
    # 子弹阵列（窗口内）
    draw.rectangle([cx()-35, body_top+50, cx()+35, body_top+120], fill=(60,60,60), outline=(60,60,60))
    for i in range(3):
        for j in range(2):
            bx = cx() - 25 + j*30
            by = body_top + 60 + i*22
            draw.ellipse([bx-8, by-10, bx+8, by+10], fill=(200,200,200), outline=(120,120,120))
    # 毒剂云扩散（底部）
    import random
    rng = random.Random(8)
    for _ in range(8):
        x = cx() + rng.randint(-40,40)
        y = body_top + 140 + rng.randint(0,25)
        draw_glow_dot(draw, (x,y), 5, lighten(c,40))

def draw_chem_sprayer(draw, theme):
    """化学喷洒器：储罐 + 前端喷枪喷雾锥。"""
    c = THEME_COLORS[theme]
    # 储罐（卧式圆筒）
    draw.rounded_rectangle([cx()-110, cx()-55, cx()+40, cx()+55], radius=30,
                           fill=(255,255,255), outline=(60,60,60), width=3)
    # 喷枪（右侧）
    draw.rectangle([cx()+40, cx()-15, cx()+90, cx()+15], fill=(180,180,180), outline=(60,60,60), width=2)
    draw.rectangle([cx()+85, cx()-20, cx()+100, cx()+20], fill=(160,160,160), outline=(60,60,60))
    # 喷雾锥（向右扩散，收紧范围确保在底板内）
    import random
    rng = random.Random(13)
    for i in range(9):
        x = cx()+105 + i*9
        spread = max(4, i*7)
        for _ in range(2):
            y = cx() + rng.randint(-spread, spread)
            draw_glow_dot(draw, (x, y), 3, lighten(c,50))
    # 储罐指示窗
    draw_glow_dot(draw, (cx()-40, cx()), 12, lighten(c,40))

def draw_pollution(draw, theme):
    """污染蓄能器：球形浓缩舱 + 旋涡污染物。"""
    c = THEME_COLORS[theme]
    # 外环循环管
    draw.ellipse([cx()-115, cx()-115, cx()+115, cx()+115], outline=darken(c,30), width=3)
    # 球形舱
    draw.ellipse([cx()-85, cx()-85, cx()+85, cx()+85], fill=(255,255,255), outline=(60,60,60), width=3)
    # 顶部均衡阀
    draw.rectangle([cx()-15, cx()-100, cx()+15, cx()-85], fill=(180,180,180), outline=(60,60,60))
    # 污染物旋涡（螺旋线）
    import random
    rng = random.Random(17)
    for i in range(28):
        ang = i * 0.45
        r = 10 + i * 2.0
        if r > 70: break
        x = cx() + int(math.cos(ang) * r)
        y = cx() + int(math.sin(ang) * r)
        draw_glow_dot(draw, (x, y), 4, lighten(c,30))


# 图标注册表：文件名 -> (绘制函数, 套路主题)
ICONS = [
    # 套路1 燃烧（橙红）
    ("mod_thermolite",          draw_thermolite,          "burn"),
    ("mod_ammo_incendiary",     draw_ammo_incendiary,     "burn"),
    ("mod_ammo_phosphorus",     draw_ammo_phosphorus,     "burn"),
    ("mod_combustion_catalyst", draw_combustion_catalyst, "burn"),
    # 套路2 电磁（蓝紫）
    ("mod_emp_warhead",         draw_emp_warhead,         "emp"),
    ("mod_antiradiation",       draw_antiradiation,       "emp"),
    ("mod_ammo_graphite",       draw_ammo_graphite,       "emp"),
    ("mod_overload",            draw_overload,            "emp"),
    # 套路3 纳米（青绿）
    ("mod_nano_amp",            draw_nano_amp,            "nano"),
    ("mod_nano_seeder",         draw_nano_seeder,         "nano"),
    ("mod_nano_catalyst",       draw_nano_catalyst,       "nano"),
    # 套路4 光束（亮黄）
    ("mod_targeting_laser",     draw_targeting_laser,     "beam"),
    ("mod_beam_splitter",       draw_beam_splitter,       "beam"),
    ("mod_reflector",           draw_reflector,           "beam"),
    ("mod_optical_fiber",       draw_optical_fiber,       "beam"),
    # 套路5 侦察（灰蓝）
    ("mod_targeting_drone",     draw_targeting_drone,     "recon"),
    ("mod_weakpoint",           draw_weakpoint,           "recon"),
    # 套路6 化学（黄绿）
    ("mod_acid",                draw_acid,                "chem"),
    ("mod_ammo_chem",           draw_ammo_chem,           "chem"),
    ("mod_chem_sprayer",        draw_chem_sprayer,        "chem"),
    ("mod_pollution",           draw_pollution,           "chem"),
]


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print("Output dir: " + OUTPUT_DIR)
    print("Procedurally generating " + str(len(ICONS)) + " mod icons...\n")

    ok = 0
    for i, (fname, draw_fn, theme) in enumerate(ICONS):
        out = os.path.join(OUTPUT_DIR, fname + ".png")
        # 新画布
        img = new_canvas()
        draw = ImageDraw.Draw(img)
        # 1. 圆角主题色底板
        draw_rounded_panel(draw, theme)
        # 2. 中央机械图形（白色主体 + 主题色高光）
        draw_fn(draw, theme)
        img.save(out, "PNG")
        size = os.path.getsize(out)
        print("[" + str(i+1).zfill(2) + "/" + str(len(ICONS)) + "] " + fname + ".png  (" + str(size) + " bytes)  theme=" + theme)
        ok += 1

    print("\nDone: " + str(ok) + "/" + str(len(ICONS)) + " icons generated.")
    print("Review at: " + OUTPUT_DIR)


if __name__ == "__main__":
    main()
