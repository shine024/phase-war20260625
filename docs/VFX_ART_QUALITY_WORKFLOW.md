# VFX / 美术质量检查与调整工作流（跨机器接续手册）

> 本文件是「单位战斗特效美术质量」的完整工作流参考——如何在两台开发机器间无缝接续检查/调整/实现 VFX。
> 沉淀自 2026-08-13/14 一轮全面 VFX 改造（签名特效 + 贴图修复 + 护盾罩设计）。
> **改任何战斗特效/贴图前先读本文。**
>
> **方法论升级（2026-08-14 复盘）**：本文是「系统性审查」在**美术领域**的实例。任何领域（数值/关卡/AI/UI）的审查
> 都应先走「情景定义→一般分析(缺陷分类)→标准→针对性检查」，不要反应式逐个修——通用提示词模板见
> **`docs/SYSTEMATIC_REVIEW_PROMPT.md`**（新会话/新客户端直接复制使用）。本文 §3 的 5 类问题分类
> 即该模板第 2 步在美术领域的产出。

---

## 0. 一句话总览

游戏是**斜俯视/立绘 billboard** 视角（单位站地面，脚在 y=0 原点，身体往上负 Y）。所有特效都要遵循：**贴图必须抠图干净**、**特效要消散（不能硬切）**、**向下要尊重地面**、**能量/重型武器要有独立签名（不能共用同一张贴图）**。

---

## 1. 视角约定（最重要，先建立心智模型）

| 事实 | 含义 |
|---|---|
| **不是纯侧视**，是斜俯视 billboard（像植物大战僵尸/皇室战争） | 单位是立绘 sprite，「站」在地面上 |
| 单位脚部对齐**地面线 = 节点原点 y=0** | 身体在 y 负方向往上（头在负 Y） |
| `data/card_foot_anchors.gd` 是脚/头/缩放**单一真理源** | `FOOT_FRAC`（脚距纹理底比例）、`HEAD_FRAC`（头）、`VISUAL_SCALE`（战场缩放 0.62~2.0） |
| `entity_top_y_for_sprite(spr)` 返回实体顶 Y（负值，脚上方） | 算护盾/头顶 UI 锚点用 |
| **向下要考虑地面** | 碎片/粒子不该穿过脚部往屏幕底掉（侧视重力假设是错的） |
| **向上/左右开放** | 碎片飞出、烟上升 = OK |

**踩过的坑**：签名特效一开始用了 `gravity=(0,260)`（侧视重力），碎片穿过地面掉到屏幕底。正确做法见 §5.3。

---

## 2. 工具链（检查/抓帧/重导入）

### 2.1 Godot 可执行文件（两台机器不同！）

```bash
# 自动探测（bash，复制即用，跨机器无需改路径）
GODOT=""
for c in \
  "/d/Downloads/Godot/Godot_v4.5.1-stable/Godot_v4.5.1-stable_win64_console.exe" \
  "/d/Downloads/Godot/Godot_v4.5.1-stable_win64_console.exe" \
  "/d/Downloads/Godot/Godot_v4.5.1-stable/Godot_v4.5.1-stable_win64.exe" \
  "/d/Downloads/Godot/Godot_v4.5.1-stable_win64.exe" \
  "/d/Downloads/Godot/Godot_v4.5.1.exe"; do
  [ -x "$c" ] && GODOT="$c" && break
done
"$GODOT" --version
```

- **机器 B（2026-08 实测）**：`D:/Downloads/Godot/Godot_v4.5.1-stable/Godot_v4.5.1-stable_win64_console.exe`（多一层 `-stable/`，console 版排错友好）
- **机器 A**：`D:/Downloads/Godot/Godot_v4.5.1-stable_win64.exe`（顶层无子目录）
- **踩坑**：旧文档只记机器 A 路径，在机器 B 报 `No such file or directory` → 用自动探测

### 2.2 VFX 展示场（抓帧用）

- 场景：`scenes/tools/vfx_showcase.tscn` + 脚本 `scenes/tools/vfx_showcase.gd`
- 作用：程序化生成 31+ 个特效条目（12 武器命中 / 威力档 / 特殊伤害 / 核爆 / 技能 / 炮口 / 护盾罩预览），逐个 spawn→等峰值帧→截图
- 输出：`user://vfx_shots/` = `%APPDATA%/Godot/app_userdata/phase-war/vfx_shots/`（manifest.json + impact_wtN_M.png 等）
- **背景**：真实战场贴图 `bg_level_05` + 暗化；目标 `mod_arm_himars`（装甲，foot_frac=0.27）；步兵参照 `cold_inf_metis`；可加空中单位 `fe_helix_phantom`

**抓帧命令（必须带 GUI，不能 --headless）**：
```bash
"$GODOT" --rendering-driver opengl3 --path "." res://scenes/tools/vfx_showcase.tscn
# ⚠️ 不要加 --headless：dummy 渲染器 get_image() 返回 null → captures=0
```

### 2.3 重导入（改了贴图后）

```bash
"$GODOT" --headless --rendering-driver opengl3 --path "." --import
# 改 .png 后必须跑(或直接跑展示场,Godot 会按 md5 自动重导入;新增无 .import 的 png 需 --import 两次)
```

### 2.4 改展示场抓帧峰值

`vfx_showcase.gd` 里每个 entry 的 `"peaks": [帧号]`（60fps，帧8≈0.13s）。改特效节奏后要重选峰值帧（特效最快的瞬间）。签名武器当前峰值：wt8激光=8、wt10欧米茄=7、wt11轨道炮=8。

**抓动图（GIF）**：临时把 `peaks` 改成序列 `[0,2,4,...,22]`（每2帧，12帧≈0.4s），抓完用 PIL 合成：
```python
frames=[Image.open(f'impact_wtN_{i}.png').resize((640,360),Image.LANCZOS) for i in range(12)]
frames[0].save('out.gif',save_all=True,append_images=frames[1:],duration=50,loop=0,optimize=True,disposal=2)
```

---

## 3. 美术质量检查（5 类问题 + 诊断方法）

### 3.1 五类常见问题

| # | 问题 | 现象 | 根因 |
|---|---|---|---|
| ① | **不透明方块** | 整张贴图是方的，盖住背景 | 贴图没抠图（角落 alpha=255） |
| ② | **矩形边框光晕** | 贴图四周有半透明矩形框 | 抠图阈值太松，角落残留半透明 |
| ③ | **内容顶框露边** | 烟尘/火球顶到贴图边沿，放大播放时矩形框可见 | 贴图内容逼近边沿（外圈边距内有内容） |
| ④ | **画错内容** | 贴图里是个人/物件而非纯效果 | AI 生成 prompt 跑偏（如 "berserk"→画了人） |
| ⑤ | **死圆/固定/无消散** | 爆炸纯圆无变化、粒子每次一样、冲击波开到位置就没了 | 缺随机性 + 缺淡出 |

### 3.2 诊断脚本（Python/PIL，复制即用）

**贴图审计**——扫 `assets/effects/` 所有贴图，查 ①②③：
```python
from PIL import Image
import glob, os
def audit(path):
    im=Image.open(path).convert('RGBA'); w,h=im.size; px=im.load()
    corners=max(px[2,2][3],px[w-3,2][3],px[2,h-3][3],px[w-3,h-3][3])  # 角落 alpha
    # 外圈 6% 边距内 alpha>90 的占比(③内容顶框)
    mx=max(2,int(w*0.06)); total=content=0
    for y in range(h):
        for x in range(w):
            if x<mx or x>=w-mx or y<mx or y>=h-mx:
                total+=1
                if px[x,y][3]>90: content+=1
    return corners, 100*content//max(1,total)
for p in glob.glob('assets/effects/**/*.png',recursive=True):
    if '_backup' in p or 'preview' in p or 'sheet' in p: continue
    ca,mc=audit(p)
    flag=[]
    if ca>150: flag.append('SQUARE!')        # ①
    elif ca>100: flag.append('BORDER')       # ②
    if mc>8: flag.append('EDGE-CONTENT')     # ③
    if flag: print(os.path.basename(p), 'corner=%d margin=%d%%'%(ca,mc), flag)
```

**棋盘格总览**（肉眼快速找方形）——把所有贴图拼到棋盘格底，盖住棋盘=没抠图：
```python
# 见 docs/vfx_realism_shots/ALL_ORIGINAL_TEXTURES.png 的生成逻辑
```

### 3.3 视觉模型评审（打分，注意偏差）

- **`analyze_image` 工具**（mcp__4_5v_mcp__analyze_image）：给远程图 URL + prompt，返回文字分析+评分。
  - ⚠️ **只收远程 URL**，本地路径直接塞会报「图片输入格式/解析错误」。要先 `Read` 文件（上传 CDN 拿 URL），再喂 URL。
  - ⚠️ **prompt 有确认偏误**：描述越细（「这该有穿透光迹」），模型越顺着确认→分数虚高。可信的是**盲评**。
  - ⚠️ 是**一个模型**，非真相。agnes-2.5-flash 给 2D 特效均分 ~3.8（严苛）；DeepSeek 识图给**相同图**均分 ~7.1（公允，用户信）。差 3.3 分。
- **DeepSeek 盲评**（最可信）：把 PNG 打包成编号文件（不标武器名），写盲评 prompt，手动上传 DeepSeek 识图模式。
  - 打包脚本思路：`tools/package_vfx_shots_for_review.py`（扁平编号 PNG + `打分提示词.md`）

**结论**：`analyze_image` 适合**快速迭代肉眼把关**（方向判断可信：能区分「穿透 vs 烧灼 vs 迸发」）；**拍板分数必须 DeepSeek 盲评**。

---

## 4. 贴图修复方法（按问题对症）

> 所有修复前**先备份**到 `_backup_v12e/`（或对应版本目录）。原贴图 gitignore（*.png），靠脚本+备份回滚。

### 4.1 黑底抠图（修①不透明方块 + 残留背景）

适用：AI 生成时强制纯黑底，主体高对比（蘑菇云、dot、spell_burst）。
```python
def cutout_black_bg(path):
    from PIL import Image
    im=Image.open(path).convert('RGBA'); w,h=im.size; px=im.load()
    for y in range(h):
        for x in range(w):
            r,g,b,a=px[x,y]; bri=(r+g+b)//3
            if bri<18: a=0           # 纯黑全透
            elif bri<45: a=int(255*(bri-18)/27)  # 羽化
            px[x,y]=(r,g,b,a)
    im.save(path)
```

### 4.2 边沿羽化（修②边框 + ③内容顶框）

适用：贴图已抠图但有边框光晕，或内容逼近边沿。
```python
def feather_edges(path, margin_frac=0.14):
    from PIL import Image
    im=Image.open(path).convert('RGBA'); w,h=im.size; px=im.load()
    mx=w*margin_frac; my=h*margin_frac
    for y in range(h):
        for x in range(w):
            dx=min(x,w-1-x); dy=min(y,h-1-y)
            f=min(1.0,(dx/mx if mx>0 else 1.0),(dy/my if my>0 else 1.0))
            t=max(0.0,min(1.0,f/0.6)); mult=t*t*(3-2*t)  # smoothstep
            r,g,b,a=px[x,y]; px[x,y]=(r,g,b,int(a*mult))
    im.save(path)
```
- 蘑菇云：先用 4.1 亮度抠图，再叠 13% 羽化（`nuke_mushroom_f*.png`）。
- 爆炸帧：14% 羽化（`explosion_conv_f*.png` / `explosion_energy_f*.png`，修内容顶框露方边）。

### 4.3 整体透明度（让贴图变薄，看清内部）

适用：护盾罩等需要透出底下单位的效果。**直接乘 alpha**（保留纹路不挖空）：
```python
FACTOR=0.60  # 烤入贴图本身;代码侧 modulate 用 1.0 不双重削弱
for y in range(h):
    for x in range(w):
        r,g,b,a=px[x,y]; px[x,y]=(r,g,b,int(a*FACTOR))
```
- 护盾罩 `player_fortress.png` 烤 ×0.6（内容 alpha 中位 ~52，薄但可见）。

### 4.4 AI 重生（修④画错内容）

修 prompt（强制纯能量、禁人物/物件）+ 调 `tools/generate_spell_burst_vfx.py`：
```bash
cd tools && python generate_spell_burst_vfx.py player_rage player_fortress
# 脚本支持「指定 ID 重生」(传 ID 名即强制重生那几个,不动其他)
# 然后 python -c 调 remove_spell_burst_background.py 的 process() 抠图
```
- **prompt 铁律**：能量效果 prompt 必须加 `NO human NO character NO person NO creature NO face NO body`、`NO solid metal NO wall NO building NO object`，否则 AI 会画人/物件（player_rage 画了人、player_fortress 画了金属块，都因 prompt 缺禁词）。

---

## 5. 特效实现模式（代码侧）

工厂：`scripts/battle/vfx_impact_factory.gd`（静态 RefCounted，spawn_* 第一参 `parent: Node2D`，第二参位置 Vector2）。分派入口：`scripts/weapon_projectile_vfx.gd` 的 `spawn_impact_with_kind`。

### 5.1 签名特效（让每把武器有独立辨识度）

**问题**：激光(8)/欧米茄(10)/轨道炮(11) 原共用同一张 OMEGA 贴图+能量帧 → 读成「通用能量团」。
**做法**：在 `spawn_impact_with_kind` 顶部加独立分派（早 return，跳过通用路径），各自调专属工厂函数：

| 武器 | 函数 | 视觉身份 | 分数(analyze_image) |
|---|---|---|---|
| 轨道炮(11) | `spawn_railgun_penetration` | 白闪+贯穿光迹+出口spall+入口回溅+速度线（动能穿透） | 9/10 |
| 激光(8) | `spawn_laser_burn` | 来弹光束+紧焦斑+焦痕+熔融火星上升（表面烧灼） | 8/10 |
| 欧米茄(10) | `spawn_omega_discharge` | 来弹粒子流+大核+星芒射线+外向电火花（径向迸发） | 8/10 |

**关键**：三把刻意区分（穿透 vs 烧灼 vs 迸发；白热 vs 青白/红橙 vs 紫罗兰/酸绿）。

### 5.2 消散感（修⑤硬切）

- **冲击波** `spawn_shockwave`：原来「扩到固定半径就消失」。改：扩到 **1.22× 半径**（继续外散不撞墙）+ **ease 全程渐淡**（`alpha = base × (1 - t^1.6)`）+ duration 0.40→0.52s 留尾。
- **爆炸火球** `spawn_impact_sprite`：已有 scale-up + alpha EASE_IN 淡出（OK）。

### 5.3 变化（修⑤死圆/固定）

`spawn_impact_sprite` 加随机旋转 + 缩放抖动（每次爆炸形态不同）：
```gdscript
var rot: float = randf() * TAU               # 随机旋转(破轴对齐死圆)
var sc_jit: float = 0.90 + randf() * 0.22    # 缩放 ±10%
# glow 和主体略错开旋转(更不规则)
```

### 5.4 地面感知重力（修侧视假设，§1）

签名特效原来 `gravity=(0,130~260)` → 碎片穿地。改成弱沉降（飞出后 gently 落回，不穿透）：
| 特效 | 原 | 改 |
|---|---|---|
| 轨道炮出口spall | (0,260) | (0,55) |
| 入口回溅 | (0,130) | (0,45) |
| 激光熔融火星 | (0,180) | (0,55) |
| 欧米茄电火花 | (0,60) | (0,35) |

⚠️ **现有项目代码（非签名特效）仍用 150-260 侧视重力**（`_spawn_impact_debris` L1885、破片 L1994 等）。推广到全部 VFX 是待定项（动 shipped 代码，需用户确认）。

### 5.5 攻击方向性（重要 bug 修复）

**bug**：`bullet.gd` 原来只在穿透技能时传 `opts["direction"]` → 普通轨道炮/激光/欧米茄命中方向恒为默认右。
**修复**（`bullet.gd:_spawn_tex_impact_at`）：直射命中**始终** `opts["direction"] = _direction`（弹丸飞行方向）。
**分派**：`spawn_impact_with_kind` 统一 `var atk_d = opts.get("direction", Vector2.RIGHT)`，三签名特效都用它定向（贯穿/来弹光束朝射手反方向）。

---

## 6. 护盾罩设计（player_fortress 转常驻单位效果）

### 6.1 设计决策（已用户确认）

- **替换**原青色程序环（`_shield_aura`，`fort_shield_aura.gd` 画的固定 52px 环）→ 用 `player_fortress.png` 贴图罩。
- **薄**：贴图烤 ×0.6 透明度，能看清内部单位（不挖空，保留能量纹路）。
- **尺寸 = max(单位宽, 单位高) × 1.2**：宽坦克按宽、高步兵按高，左右+上下都罩住（**不能只按高度**，否则宽坦克罩太窄）。
- **地面单位**：罩底贴**脚位**（card_foot_anchors foot_frac 算，非阴影），球坐在地上不穿地。
- **空中单位**：整球居中（`platform_type`/`is_aircraft`/`CombatKind.AIR` 判断），空中无地面限制。
- **敌方**：红色调（区别我方钢蓝）。
- **显隐**：`shield > 0` 显示，耗尽隐藏，透明度随护盾比例衰减 + 受击承压闪亮（复用 `_shield_aura_hit_boost`）。

### 6.2 几何（贴脚/居中的算法）

alpha 扫描单位贴图真实内容边界 → `直径 = max(content_w, content_h) × 1.2`：
- 地面：`罩中心 = (单位x, 脚Y - 直径/2)`（底贴脚）
- 空中：`罩中心 = 内容中心`（整球）

参考实现（展示场 mockup）：`vfx_showcase.gd` 的 `_content_bbox_world()` + `_spawn_shield_on()`。

### 6.3 ⚠️ 状态：仅展示场 mockup，**未接入真实单位代码**

- 已确认长相（`docs/vfx_realism_shots/shield_bubble_v4.png`），用户说「护盾先就这样」→ **暂停接线**。
- **接线待办**（用户确认后做）：
  1. `construct_unit.gd`：preload player_fortress；`shield>0` 时 spawn 罩子节点（替换 `_shield_aura` 环），按 platform_type 判空地，尺寸用 card_foot_anchors 真实边界。
  2. `enemy_unit.gd`：同上，红色调。
  3. `player_fortress` 原是孤儿贴图（`fortress_bulwark` 能力被并入 `mega_shield`→用 player_shield），现用作通用护盾罩。

---

## 7. 当前状态 / 待办（跨机器接续点）

### 7.1 已完成（已随 2026-08-14 提交入库；**贴图 PNG 因 `*.png` gitignore 不进版本库，跨机器需整项目拷贝**；原贴图备份在各 `_backup_v12e/` 目录可回滚）

- ✅ 轨道炮/激光/欧米茄 三签名特效（8-9/10，analyze_image 评分，**未经 DeepSeek 盲评**）
- ✅ 攻击方向 bug 修复（bullet.gd 始终传 _direction）
- ✅ 贴图修复：蘑菇云抠图、爆炸帧边沿羽化（14%）、player_rage/player_fortress AI 重生+抠图、player_fortress 薄壳化（×0.6）
- ✅ 消散感（冲击波）+ 变化（爆炸随机旋转/缩放）+ 地面感知重力（3 签名特效）
- ✅ 展示场改进：方向指示器、步兵大小参照、护盾罩预览入口
- ✅ 护盾罩设计确认（mockup）

### 7.2 待办（优先级排）

1. **DeepSeek 盲评交叉验证**（签名特效真实分数，analyze_image 可能虚高）
2. **护盾罩接真实代码**（§6.3，用户确认长相后）
3. **地面感知重力推广到全部 VFX**（现有 shipped 代码仍 150-260 侧视重力，需用户确认才动）
4. **签名特效推广到剩余武器**（狙击=精准点命中、霰弹=散射多点等）
5. **审计剩余 spell_burst 贴图**（apocalypse_*/inferno/chain_lightning 等有无人物/物件问题）

### 7.3 关键文件清单

| 文件 | 改动 |
|---|---|
| `scripts/battle/vfx_impact_factory.gd` | +3 签名函数（railgun/laser/omega）+ 冲击波消散 + 爆炸变化 + 重力调整 |
| `scripts/weapon_projectile_vfx.gd` | `spawn_impact_with_kind` wt8/10/11 独立分派 + 统一 attack direction |
| `scenes/units/bullet.gd` | `_spawn_tex_impact_at` 始终传 `opts["direction"]=_direction` |
| `scenes/tools/vfx_showcase.gd` | 峰值帧、方向指示、步兵参照、护盾罩预览、GIF 序列抓帧 |
| `assets/effects/nuclear/nuke_mushroom_f*.png` | 亮度抠图+羽化（备份 `_backup_v12e/`） |
| `assets/effects/explosion_frames/explosion_*.png` | 14% 边沿羽化（备份 `_backup_v12e_pre_feather/`） |
| `assets/effects/spell_burst/player_rage.png` `player_fortress.png` | AI 重生+抠图（备份 `_backup_v12e/`、`_original_backup/`） |
| `tools/generate_spell_bust_vfx.py` | 修 2 prompt（禁人物/物件）+ 支持 ID 指定重生 |
| `tools/remove_spell_burst_background.py` | 支持 ID 指定抠图 |

---

## 8. 速查命令

```bash
# 自动探测 Godot(跨机器)
GODOT=$(for c in /d/Downloads/Godot/Godot_v4.5.1-stable/Godot_v4.5.1-stable_win64_console.exe /d/Downloads/Godot/Godot_v4.5.1-stable_win64_console.exe /d/Downloads/Godot/Godot_v4.5.1-stable/Godot_v4.5.1-stable_win64.exe /d/Downloads/Godot/Godot_v4.5.1-stable_win64.exe; do [ -x "$c" ] && echo "$c" && break; done)

# 抓帧(必须 GUI,不能 headless)
"$GODOT" --rendering-driver opengl3 --path "." res://scenes/tools/vfx_showcase.tscn

# 重导入(改贴图后)
"$GODOT" --headless --rendering-driver opengl3 --path "." --import

# 抓的帧位置
ls "$APPDATA/Godot/app_userdata/phase-war/vfx_shots/"

# 复制某帧到 docs 看
cp "$APPDATA/Godot/app_userdata/phase-war/vfx_shots/impact_wt3_0.png" docs/vfx_realism_shots/
```

## 9. 黄金法则（记不住时看这）

1. **贴图必须抠图干净**——角落 alpha=0、内容不顶边沿（§3-4）。
2. **特效要消散**——扩过峰值+全程渐淡，不能硬切（§5.2）。
3. **向下尊重地面**——斜俯视，别用侧视重力让碎片穿地（§5.4）。
4. **能量武器要有独立签名**——别共用贴图，每把武器一个辨识度（§5.1）。
5. **护盾按 max(宽,高) 罩**——宽单位按宽、高单位按高，整包住（§6）。
6. **评分信 DeepSeek 盲评**，analyze_image 只做快速迭代把关（§3.3）。
7. **改前备份、改后重导入**——贴图 gitignore，靠脚本+备份回滚（§4）。
