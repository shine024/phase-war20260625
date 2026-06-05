# 堡垒卡 / Omega 卡面生成工作流

> 用于在另一台机器上重新生成 Phase War 游戏中 11 张堡垒/omega 战斗卡的独立卡面素材。
> 所有卡图统一规格：正侧视、主体居中、白底抠透明、1024×1024 RGBA PNG。

## 一、前置条件

### 1.1 硬件/软件环境

| 项目 | 要求 |
|------|------|
| Python | 3.10+ |
| PIL / Pillow | `pip install Pillow` |
| 网络连接 | 能访问 `https://apihub.agnes-ai.com`（如需要代理需配置） |

### 1.2 API 密钥

项目使用 **agnes-ai**（OpenAI 兼容接口）的 `agnes-image-2.0-flash` 模型生成图片。

**密钥来源**：`~/.hermes/config.yaml` 或 `~/.hermes/.env`

- `config.yaml` 中的 `api_key` 字段（格式 `sk-...`）
- 或 `.env` 中的 `OPENAI_API_KEY` 字段

密钥在脚本中自动读取，无需手动配置。

### 1.3 项目路径

假设项目根目录为 `$PROJECT_ROOT`，默认路径：

```
F:\godot fair duet\create\phase-war
```

在 Windows 上请替换为实际路径。所有路径使用反斜杠 `\`。

## 二、文件清单

生成 11 张卡图，按时代/类型分两类：

### 2.1 堡垒卡（10 张）

| card_id | 中文名称 | 时代 | 兵种 |
|---------|----------|------|------|
| fort_ww1_pillbox | 混凝土机枪碉堡 | WW1 | 要塞 |
| fort_ww1_artillery | 要塞炮台 | WW1 | 要塞 |
| fort_ww2_bunker | 混凝土碉堡 | WW2 | 要塞 |
| fort_ww2_flak | 88mm防空塔 | WW2 | 要塞 |
| fort_cold_missile | 导弹发射井 | 冷战 | 要塞 |
| fort_cold_radar | 雷达站 | 冷战 | 雷达 |
| fort_modern_citadel | 要塞核心 | 现代 | 要塞 |
| fort_modern_phalanx | 近防炮系统 | 现代 | 近防 |
| fort_future_ion | 离子炮台 | 未来 | 要塞 |
| fort_future_shield | 能量护盾发生器 | 未来 | 支援 |

### 2.2 Omega 卡（1 张）

| card_id | 中文名称 | 时代 | 兵种 |
|---------|----------|------|------|
| omega_platform | Omega终极平台 | 未来 | 终极 |

## 三、生成步骤

### Step 1：安装依赖

```bash
pip install Pillow
```

### Step 2：复制脚本

将本目录下的 `generate_fortress_icons.py` 和 `deploy_fortress_icons.py` 复制到项目：

```
$PROJECT_ROOT/scripts/generate_fortress_icons.py
$PROJECT_ROOT/scripts/deploy_fortress_icons.py
```

### Step 3：运行生成脚本

```bash
cd $PROJECT_ROOT
python scripts/generate_fortress_icons.py
```

**生成过程：**

1. 脚本从 `~/.hermes/config.yaml` 自动读取 API 密钥
2. 对每张卡调用 `https://apihub.agnes-ai.com/v1/images/generations`
3. 模型使用 `agnes-image-2.0-flash`
4. 参数：`image_size=1024x1024`, `response_format` **不能带**（会导致 400 错误）
5. 返回 URL，下载 PNG 到 `$PROJECT_ROOT/assets/card_icons/`
6. 每张图片之间间隔 3 秒，避免频率限制

**关键 API 调用参数：**

```json
{
    "model": "agnes-image-2.0-flash",
    "prompt": "<具体描述，见 Step 4>",
    "image_size": "1024x1024"
}
```

**重要：** 不要传 `response_format` 参数，否则会返回 400 错误。

### Step 4：Prompt 模板

每张卡的 prompt 遵循统一格式：

```
军事卡牌图标艺术, <主体描述>, 严格正侧视图 - 仅可见侧面, 非正面, 非四分之三视角, 非45度角. 纯白背景. 居中构图. 无地面, 无阴影, 无场景, 无底座, 无地板. 1024x1024. 无文字, 无水印.
```

**各卡具体 prompt（英文，直接用于 API）：**

| card_id | Prompt |
|---------|--------|
| `fort_ww1_pillbox` | `A WW1 concrete machine gun pillbox viewed from the EXACT side - ONLY the long rectangular side face is visible, NOT the front. One flat rectangular wall with a square machine gun firing slit, a small rectangular metal door, and stacked sandbag parapet along the top edge. Gray concrete with weathering cracks. Pure white background. Centered. No ground, no shadow, no perspective depth. Flat side elevation view.` |
| `fort_ww1_artillery` | `A WW1 artillery gun shield emplacement viewed from the EXACT side - ONLY the side profile is visible. Long gun barrel pointing left with curved concrete gun shield, rectangular concrete base wall, side profile of the emplacement. Gray weathered concrete. Pure white background. Centered. No ground, no shadow. Flat side elevation view.` |
| `fort_ww2_bunker` | `A WW2 concrete bunker MG position viewed from the EXACT side - ONLY one flat rectangular wall face is visible. Firing embrasures along the side wall, riveted steel door on the left edge, sandbag parapet along top. Gray concrete. Pure white background. Centered. No ground, no shadow. Strict flat side elevation.` |
| `fort_ww2_flak` | `A German 88mm Flak tower viewed from the EXACT side - ONLY side profile visible. Long gun barrel pointing left, rotating platform base, rectangular concrete armor plate structure behind the gun. Weathered gray concrete and steel. Pure white background. Centered. No ground, no shadow. Strict flat side elevation.` |
| `fort_cold_missile` | `A Cold War missile silo viewed from the EXACT side - ONLY side profile visible. Tall cylindrical concrete dome with vertical seam, rectangular blast door housing on the side, metallic launch rails running vertically, olive-drab painted steel surfaces. Pure white background. Centered. No ground, no shadow. Strict flat side elevation.` |
| `fort_cold_radar` | `A Cold War military radar station viewed from the EXACT side - ONLY side profile visible. Large parabolic dish antenna seen from the edge as a thin arc, supporting tower structure, rectangular equipment shelter. Military green paint. Pure white background. Centered. No ground, no shadow. Strict flat side elevation.` |
| `fort_modern_citadel` | `A modern armored fortress command center viewed from the EXACT side - ONLY one flat armor panel face is visible. Angular composite armor layers stacked vertically, rectangular steel door, communication antenna array on top, dark military gray composite panels. Pure white background. Centered. No ground, no shadow. Strict flat side elevation.` |
| `fort_modern_phalanx` | `A Phalanx CIWS gun system viewed from the EXACT side - ONLY side profile visible. Multi-barrel Gatling gun assembly seen as a long cylinder, stabilized rectangular mount base, protective armored housing box, sensor dome. Dark gray military finish. Pure white background. Centered. No ground, no shadow. Strict flat side elevation.` |
| `fort_future_ion` | `A futuristic ion cannon platform viewed from the EXACT side - ONLY side profile visible. Cylindrical white-gold armored body, circular blue energy rings visible as flat rings along the side, hexagonal armor panel pattern on the side face, glowing blue energy coils. Pure white background. Centered. No ground, no shadow. Strict flat side elevation.` |
| `fort_future_shield` | `A futuristic energy shield generator dome viewed from the EXACT side - ONLY side profile visible. Large curved dome structure, hexagonal blue force field pattern glowing on the surface, metallic silver housing base, vertical glowing energy conduits. Pure white background. Centered. No ground, no shadow. Strict flat side elevation.` |
| `omega_platform` | `An Omega-class floating warship viewed from the EXACT side - ONLY side profile visible. Massive hexagonal hull seen from the side with angular armor plating, white-gold composite panels, deck turrets visible as small towers on top, glowing blue energy cores embedded in hull. Pure white background. Centered. No ground, no shadow, no water, no battlefield. Strict flat side elevation.` |

### Step 5：运行部署脚本

```bash
python scripts/deploy_fortress_icons.py
```

**部署过程：**

1. 对每张卡读取 `assets/card_icons/<card_id>.png`（白底）
2. 用 Pillow 遍历像素：RGB 三通道都 > 240 的像素设为透明
3. 原地保存为 RGBA 透明 PNG
4. 复制到以下位置：
   - `assets/card_icons/<card_id>.png` （原位，已抠图）
   - `assets/card_icons/units/<card_id>.png` （敌方战场渲染）
5. 额外映射到 `units/vis_player_XXX.png`：

| 源文件 | 部署目标 | 用途 |
|--------|----------|------|
| `fort_ww1_pillbox.png` | `vis_player_003.png` | WW1 堡垒 archetype 战场渲染 |
| `fort_ww2_bunker.png` | `vis_player_012.png` | WW2 堡垒 archetype 战场渲染 |
| `fort_future_ion.png` | `vis_player_013.png` | 未来堡垒 archetype 战场渲染 |
| `omega_platform.png` | `vis_player_030.png` | fut_nexus → omega 战场渲染 |

## 四、文件输出

生成完成后，文件结构如下：

```
assets/card_icons/
├── fort_ww1_pillbox.png          ← 1024x1024 RGBA, 透明背景
├── fort_ww1_artillery.png
├── fort_ww2_bunker.png
├── fort_ww2_flak.png
├── fort_cold_missile.png
├── fort_cold_radar.png
├── fort_modern_citadel.png
├── fort_modern_phalanx.png
├── fort_future_ion.png
├── fort_future_shield.png
├── omega_platform.png
└── units/
    ├── fort_ww1_pillbox.png      ← 副本（敌方战场渲染）
    ├── fort_ww1_artillery.png
    ├── ...
    ├── omega_platform.png
    ├── vis_player_003.png        ← fort_ww1_pillbox 的副本（Fortress archetype）
    ├── vis_player_012.png        ← fort_ww2_bunker 的副本
    ├── vis_player_013.png        ← fort_future_ion 的副本
    └── vis_player_030.png        ← omega_platform 的副本 (fut_nexus)
```

## 五、Godot 资源缓存刷新

文件部署后，Godot 编辑器不会自动检测到新文件。需要：

1. **方法 A**：在 Godot 编辑器中按 `Ctrl+Shift+R` 刷新资源
2. **方法 B**：关闭并重新打开 Godot 编辑器
3. **方法 C**：在 Godot 的 FileSystem 面板右键项目 → Refresh

## 六、常见问题

### Q1：API 返回 400 错误

**原因**：传了 `response_format` 参数。
**解决**：去掉 `response_format`，只传 `model`、`prompt`、`image_size`。

### Q2：API 返回 503 错误

**原因**：agnes-image-2.0-flash 模型通道不可用。
**解决**：等待几秒后重试。

### Q3：API 返回连接超时

**原因**：无法直接访问 `apihub.agnes-ai.com`。
**解决**：配置 HTTP 代理。修改脚本中的 `proxy_url = "http://127.0.0.1:10808"` 为你的代理地址。

### Q4：图片不是正侧视

**原因**：AI 模型默认容易生成 3/4 视角。
**解决**：在 prompt 中强调 "EXACT side - ONLY side visible, NOT front, NOT three-quarter angle, NOT 45 degrees"。本工作流中的 prompt 已包含此约束。

### Q5：透明背景不是预期的

**原因**：白底阈值 `240` 可能过高或过低。
**解决**：修改 `deploy_fortress_icons.py` 中的 `remove_white_bg()` 函数，调整 `threshold` 参数（默认 240，范围 0-255）。值越高，越多像素被设为透明。

### Q6：API 密钥错误

**原因**：`~/.hermes/config.yaml` 中读取失败。
**解决**：手动在脚本中设置 `API_KEY = "your-actual-key-here"`。

## 七、脚本说明

### generate_fortress_icons.py

```
功能：通过 agnes-image-2.0-flash API 生成 11 张卡图
输入：无（prompt 硬编码在脚本中）
输出：assets/card_icons/<card_id>.png（白底，1024x1024）
依赖：requests（用于 HTTP 调用）
```

### deploy_fortress_icons.py

```
功能：抠去白底背景 → 透明 PNG + 部署到 3 个目录
输入：assets/card_icons/<card_id>.png（白底）
输出：
  1. assets/card_icons/<card_id>.png（原地替换，透明）
  2. assets/card_icons/units/<card_id>.png（副本）
  3. assets/card_icons/units/vis_player_XXX.png（archetype 映射）
依赖：Pillow (PIL)
```

## 八、快速复用（另一台机器）

```bash
# 1. 复制项目文件
cp $THIS_WORKFLOW_DIR/generate_fortress_icons.py $PROJECT_ROOT/scripts/
cp $THIS_WORKFLOW_DIR/deploy_fortress_icons.py $PROJECT_ROOT/scripts/

# 2. 安装依赖
pip install Pillow

# 3. 确认 API 密钥可访问
#    检查 ~/.hermes/config.yaml 中的 api_key 是否有效

# 4. 运行
cd $PROJECT_ROOT
python scripts/generate_fortress_icons.py   # 生成 11 张卡图
python scripts/deploy_fortress_icons.py    # 抠图 + 部署

# 5. Godot 中刷新资源
#    Ctrl+Shift+R
```
