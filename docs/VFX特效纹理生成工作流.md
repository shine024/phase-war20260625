# VFX 特效纹理生成工作流（核爆 VFX 实战总结）

> 基于 2026-08-03 核爆 VFX（战术核武 + 核子轰炸）完整制作流程整理。
> 下次给任何战斗特效做 AI 纹理 + 帧动画时，照此流程走，可避开本次踩的所有坑。

## 总览：6 步流水线

```
1. AI 生成纹理（agnes-ai，强制黑底）
   ↓
2. 客观验证背景色（Python PIL，不靠主观看图）
   ↓
3. 黑底阈值抠图（亮度<20 透明）
   ↓
4. Agent Tools 导入（editor.reload_filesystem）
   ↓
5. 代码接入（按目标像素反算 scale，非裸倍数）
   ↓
6. 实机验证（诊断 print 定位 + VFX parent 确认）
```

---

## 步骤1：AI 生成纹理（强制黑底）

### 关键经验：永远要求「纯黑背景 #000000」

agnes-ai **不会**输出透明背景（即使 prompt 要求 `transparent background`，它也返回实底：白/灰/黑）。
- ❌ `transparent background` → 返回灰底/白底，主体和背景颜色接近时抠图误伤严重
- ✅ `solid pure black background #000000, high contrast` → 返回接近纯黑底（亮度 1-2/255），主体高对比，抠图可靠

### 生成脚本模板

参考 `tools/generate_nuclear_vfx_textures.py` / `tools/generate_nuke_spritesheet.py`。

**核心 API 调用**（复用 `generate_level1_bg_candidates.py` 结构）：
```python
BASE_URL = "https://apihub.agnes-ai.cn/v1"
MODEL = "agnes-image-2.0-flash"
KEY_FILE = "tools/_api_key.txt"  # 3 个 key 轮换

payload = json.dumps({"model": MODEL, "prompt": prompt, "size": "1024x1024", "n": 1})
# curl POST /images/generations，响应 data[0].url 或 data[0].b64_json
```

### Prompt 模板（VFX 特效专用）

```
<主体描述>, top-down view, perfectly centered, symmetrical,
solid pure black background #000000, high contrast,
game VFX sprite texture, high detail, clean edges
```

主体描述要点：
- 火球：`nuclear explosion fireball, bright white-yellow glowing core, orange-red outer glow`
- 冲击波环：`expanding shockwave ring, single bright white-blue energy ring, hollow center`
- 蘑菇云：`nuclear mushroom cloud seen from above, bright white-gray smoke column`
- 焦痕：`scorched earth burn mark, dark charred circle, ash texture`
- 导弹：`ICBM missile, bright glowing white-orange metallic body, flame trail`

### 输出位置

`assets/effects/<分类>/`（本次是 `assets/effects/nuclear/`）。无现成分类就建新目录。

---

## 步骤2：客观验证背景色（不靠主观看图）

> ⚠️ **视觉模型（analyze_image）判断"透明/不透明"不可靠**，本次多次误判。必须用 Python PIL 客观测 alpha 通道。

```python
from PIL import Image
img = Image.open(path).convert("RGBA")
w, h = img.size
px = img.load()
# 四角 RGB（判断背景色）
corners = [px[0,0][:3], px[w-1,0][:3], px[0,h-1][:3], px[w-1,h-1][:3]]
# 背景平均亮度（黑底应 <10）
edge_pts = [(0,0),(w-1,0),(0,h-1),(w-1,h-1),(w//2,0),(w//2,h-1),(0,h//2),(w-1,h//2)]
bg_brightness = sum(sum(px[x,y][:3])//3 for x,y in edge_pts)//len(edge_pts)
```

**合格标准**：背景平均亮度 < 10（接近纯黑）。> 30 说明 AI 没遵循黑底要求，需重新生成。

---

## 步骤3：黑底阈值抠图

黑底主体的抠图非常简单可靠（主体几乎不会是纯黑）：

```python
from PIL import Image
img = Image.open(path).convert("RGBA")
w, h = img.size
px = img.load()
for y in range(h):
    for x in range(w):
        p = px[x,y]
        b = (p[0]+p[1]+p[2])//3
        if b < 20:           # 完全透明
            px[x,y] = (p[0],p[1],p[2],0)
        elif b < 50:         # 羽化带（去锯齿）
            px[x,y] = (p[0],p[1],p[2],int(255*(b-20)/30))
img.save(path)
```

**参数**：THRESHOLD=20，FEATHER=30。对 1024×1024 图约 2-3 秒完成。

**抠图后验证主体保留**（防误抠）：
```python
# 中心区域不透明像素占比（应 >50%）
cx, cy = w//2, h//2
opaque = sum(1 for yy in range(cy-30,cy+30) for xx in range(cx-30,cx+30) if px[xx,yy][3]>200)
print(f'中心不透明占比={opaque*100//3600}%')
```

参考脚本：`tools/remove_nuclear_vfx_background.py`（黑底版，替代了失败的颜色距离版）。

> ❌ **不要用「色彩距离」抠图**：灰金属主体（导弹）+ 灰背景时，主体会被整个抠没。本次踩坑：导弹主体 100% 被误抠透明。

---

## 步骤4：Agent Tools 导入纹理

> ⚠️ Godot 编辑器只在窗口获得 OS 焦点时扫描文件系统。外部写入的 png 不会自动导入。

### 用 Agent Tools 触发导入

```python
import socket, json
def call(method, params=None, port=9920, timeout=30.0):
    req = {'id': 1, 'method': method}
    if params is not None: req['params'] = params
    s = socket.socket(); s.settimeout(timeout)
    s.connect(('127.0.0.1', port)); s.sendall((json.dumps(req)+'\n').encode())
    buf = b''
    while b'\n' not in buf:
        c = s.recv(8192)
        if not c: break
        buf += c
    s.close(); return json.loads(buf.decode().strip())

# 触发文件系统重扫（关键方法）
call('editor.reload_filesystem', {})  # 返回 {'scanned': True}
```

**前提**：编辑器在跑（`tasklist | grep godot` 且 `netstat | grep 9920` 有 LISTENING）。
**端口**：默认 9920，被占用顺延到 9921..9929。

### 验证导入成功

```python
# 方法1：检查 .import 文件生成（硬指标）
import os
os.path.exists("assets/effects/nuclear/nuke_fireball.png.import")  # True = 导入成功

# 方法2：Agent Tools load 验证（get_width 返回实际尺寸）
r = call('resource.call_method', {
    'path': 'res://assets/effects/nuclear/nuke_fireball.png',
    'method': 'get_width', 'args': [], 'save': False
})
# r['result']['return'] = 1024（有值=加载成功）
```

**导入产物**：`.import`（文本配置）+ `.godot/imported/*.ctex`（压缩纹理）+ 自动分配 uid。

> ⚠️ `editor.reload_filesystem` 后偶尔会导致编辑器进程退出（Godot 4.5.1 稳定性问题），与代码无关，重开编辑器即可。

---

## 步骤5：代码接入（按目标像素反算 scale）

> ⚠️ **最大的坑**：AI 生成的纹理都是 1024×1024 大图，但战场单位才几十像素。裸 scale 倍数会失控。

### ❌ 错误做法（裸 scale）

```gdscript
sprite.scale = Vector2(0.6, 0.6)  # 1024px × 0.6 = 614px！比坦克还大
```

火球 scale 4.0 × 1024 = 4096px，蘑菇云 scale 6.0 × 1024 = 6144px——整个屏幕被一个超大贴图填满，看起来就是一片色块，等于"看不到"。

### ✅ 正确做法（按目标像素反算）

```gdscript
var tex_w: float = float(texture.get_width())  # 贴图原始宽度（1024）
var peak_scale: float = target_width / tex_w   # target_width=320 → scale≈0.31
sprite.scale = Vector2(peak_scale, peak_scale)
```

无论贴图是 512 还是 1024px，渲染尺寸都一致（如 320px）。本次所有核爆贴图都改成此模式。

### 常见目标尺寸（战场 1280×720 参考）

| 特效 | 目标宽度 | 说明 |
|---|---|---|
| 火球 | 360px | 醒目，约屏幕 1/3 |
| 冲击波 | 307px | 略大于伤害半径视觉 |
| 蘑菇云 | 320px | 约屏幕 1/4，有体积感 |
| 焦痕 | 90px 半径 | 地面痕迹，不挡视线 |
| 导弹 | 56px | 像坦克炮弹大小 |

---

## 步骤6：实机验证（诊断 print + VFX parent）

### 核爆/特效看不到时的排查清单

按顺序检查（用诊断 print 定位）：

```gdscript
# 1. 机制是否触发（meta 是否打上）
print("[DIAG] 单位激活，初始CD=", cd)

# 2. CD 是否到期
print("[DIAG] CD到期，准备触发")

# 3. 信号是否发出
print("[DIAG] emit signal, victims=", victims.size())

# 4. 接收方是否收到
print("[DIAG] 收到信号! from=", from_pos)

# 5. VFX parent 是否找到（最常见失败点）
print("[DIAG] VFX parent=", parent, " (null=找不到战场节点!)")
```

### VFX parent=null 的修复

> 本次核爆"看不到"的根因：`_get_vfx_parent()` 找不到战场节点。

Battlefield 节点嵌在 `BattleContainer/SubViewportContainer/SubViewport` 里，**没有加 group**，也不是 root 直接子节点。group 查找和 root 遍历都失效。

**修复**：增加从 BattleManager 显式持有的 battlefield 获取的回退路径：
```gdscript
var bm: Node = get_node_or_null("/root/BattleManager")
if bm != null:
    var bf: Variant = bm.get("battlefield")
    if bf is Node2D and is_instance_valid(bf):
        return bf
```

---

## 帧动画：精灵表（Sprite Sheet）流程

当单 sprite + tween 不够流畅时（如蘑菇云升腾消散），用帧动画。

### 1. AI 生成精灵表（3×3 = 9 帧）

prompt 关键（防 AI 画成 9 个独立爆炸）：
```
sprite sheet of ONE <主体> growing animation sequence,
3x3 grid layout with 9 frames arranged left-to-right top-to-bottom,
frame 1: <初始状态> → frame 9: <结束状态>,
the SAME single <主体> evolving across all 9 frames, NOT 9 separate explosions,
consistent centered position within each grid cell,
clear thin black grid lines separating each cell,
solid pure black background #000000, high contrast
```

参考：`tools/generate_nuke_spritesheet.py`

### 2. 切割 + 抠图 + 连贯性验证

```python
from PIL import Image
img = Image.open("nuke_mushroom_sheet.png").convert("RGBA")
GRID = 3
cell_w, cell_h = img.width // GRID, img.height // GRID
for fy in range(GRID):
    for fx in range(GRID):
        idx = fy * GRID + fx
        frame = img.crop((fx*cell_w, fy*cell_h, (fx+1)*cell_w, (fy+1)*cell_h))
        # 黑底抠图（同步骤3）
        frame.save(f"nuke_mushroom_f{idx}.png")
```

**客观验证连贯性**（不靠主观看图）：
- 每帧主体中心偏移 < 60px（蘑菇云不乱跳；地面闪光→升起的跳变算合理）
- 主体面积有演变（如 11%→45%→10%，成长后消散）
- 亮度先升后降（闪光→消散）

参考：`tools/split_nuke_spritesheet.py`

### 3. 代码建 SpriteFrames + AnimatedSprite2D

> VFX 是临时节点（爆炸完销毁），代码建帧动画比 .tres 资源灵活，不占项目资源树。

```gdscript
var frames := SpriteFrames.new()
frames.add_animation("grow")
frames.set_animation_loop("grow", false)
frames.set_animation_speed("grow", 8.0)  # 8fps × 9帧 = 1.125s
for tex in frame_textures:
    frames.add_frame("grow", tex)

var anim := AnimatedSprite2D.new()
anim.sprite_frames = frames
anim.play("grow")
parent.add_child(anim)
# 播完 queue_free（帧动画不进对象池——低频特效无需池化）
```

参考：`vfx_impact_factory.gd` 的 `spawn_animated_nuclear`。

---

## 复用模式：spawn_nuclear_explosion 公共方法

当多个系统需要同一套特效（如战术核武 + 核子轰炸都需要核爆），抽公共方法：

```gdscript
# VFX 工厂
static func spawn_nuclear_explosion(parent, pos, textures: Dictionary, colors: Dictionary) -> void:
    # textures = {"fireball":Tex, "shockwave":Tex, "burn":Tex, "mushroom_frames":Tex[]}
    # colors = {"shock":Color, "aftershock":Color, "smoke":Color}
    # 封装：火球+冲击波+蘑菇云帧动画+焦痕
```

调用方负责：
- 预加载贴图包（循环外加载一次，循环内复用）
- 全局效果（闪白/震屏/标题）只在首个位置触发（多点时避免叠加闪瞎）

参考：`vfx_impact_factory.gd:spawn_nuclear_explosion`、`phase_instrument_abilities.gd:_load_nuke_texture_pack`。

---

## 本次涉及的脚本/文件清单（参考实现）

| 文件 | 用途 |
|---|---|
| `tools/generate_nuclear_vfx_textures.py` | 生成 5 张单帧核爆纹理（火球/冲击波/蘑菇云/焦痕/导弹） |
| `tools/generate_nuke_spritesheet.py` | 生成蘑菇云 3×3 精灵表 |
| `tools/split_nuke_spritesheet.py` | 切割精灵表 + 抠图 + 连贯性验证 |
| `tools/remove_nuclear_vfx_background.py` | 黑底阈值抠图（单帧） |
| `scripts/battle/vfx_impact_factory.gd` | VFX 工厂：spawn_animated_nuclear / spawn_nuclear_explosion / spawn_smoke_column / spawn_ground_burn |
| `managers/battle/battle_spectacle.gd` | 战术核武核爆编排 + _get_vfx_parent 修复 + _load_nuclear_frames |
| `managers/battle/phase_instrument_abilities.gd` | 核子轰炸复用核爆 VFX + _load_nuke_texture_pack |

---

## 常见坑速查

| 现象 | 根因 | 解决 |
|---|---|---|
| 纹理背景不透明 | agnes-ai 不输出透明 | prompt 要求纯黑底 + 阈值抠图 |
| 导弹主体被抠没 | 颜色距离抠图误伤灰主体 | 用黑底 + 亮度阈值（非颜色距离） |
| 特效"看不到"（一片色块） | 1024px 贴图 × 裸 scale = 几千像素 | 按目标像素反算 scale |
| VFX parent=null | Battlefield 在 SubViewport 里无 group | 从 BattleManager.battlefield 获取 |
| 多点核爆蘑菇云重叠 | cd 同步 + 落点相同 | cd 随机偏移 + 落点±40px 扰动 |
| 精灵表帧间不连贯 | AI 理解偏差 | prompt 强调 ONE 主体 evolving + 客观验证 |
| 编辑器进程退出 | reload_filesystem 偶发触发 | 重开编辑器，与代码无关 |
| 两个核系统雷同 | 都用☢+蘑菇云+同配色 | 差异化（核武橙白写实 / 轰炸紫青能量，或统一靠多点vs单点区分） |

---

## API Key 管理

- 文件：`tools/_api_key.txt`（每行一个 key，支持轮换）
- 文档：`docs/生图API.txt`（agnes-ai 免费 API + 3 个 key）
- ⚠️ key 会进 git。若非项目长期共享，用完轮换
- 限速：每张生成间隔 3s（脚本内 `time.sleep(3)`）
