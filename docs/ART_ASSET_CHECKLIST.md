# 相位战争（Phase War）美术资源补全明细清单

> 生成日期：2026-04-27 | 基于代码实际定义提取  
> **修订**：2026-05-02 — 对齐当前设定：战斗内**无独立武器实体**；**我方战场单位复用敌方单位视觉资源**（见下文「设计前提」）。  
> **修订**：2026-05-03 — 下列「绿底规范」类目在仓库内 PNG **已完成色键、透明底入仓**（见文首「透明底入仓」）；表格中旧「待生成/缺」已按此对齐（势力 **32px** 若仍无文件则单列「缺 PNG」与抠图无关）。

---

## 设计前提（当前版本，与代码一致）

1. **无武器版战斗**：不向战场要求「挂载武器精灵」「`assets/unit_sprites/weapons/`」等资源；旧清单中「我方武器精灵 12 种」**不再作为待补项**。
2. **我方单位 = 敌方视觉**：`scenes/units/construct_unit.gd` 通过 `PLAYER_MIRROR_ARCHETYPE_BY_PLATFORM` 与 `EnemyArchetypes.get_visual_archetype_id_for_card` 将平台映射到**敌方原型 id**，与 `enemy_unit.gd` 相同，仅从 `res://assets/enemies` 加载 `SpriteFrames` / 单帧贴图（**不再**使用 `player_from_enemy`）；仅 **全装型** 等少数仍使用 `assets/unit_sprites/omega_platform.png` 等独立资源。
3. **战场美术优先级**：补全/提质应落在 **`assets/enemies/`**（及 `SpriteSheet` 帧动画）与映射表中的原型，而不是为每种平台再画一套 `unit_sprites/hound.png` 式战场精灵。

**绿底导出明细（文件名含中文、规格表）**：见 `docs/ART_EXPORT_CHECKLIST_GREENSCREEN.md`。

### 透明底入仓（2026-05-03）

以下目录中 **已入库 PNG 均为抠绿后的透明底**（与外包「先绿底再色键」流程对齐后的终稿）：

- `assets/card_icons/`（含按 `card_id` 的法则 / 能量 / 平台卡面等）
- `assets/cards/frames/`（稀有度卡框）
- `assets/ui/icons/`
- `assets/ui/factions/`（当前仓库以 `*_128.png` 为主；**`*_32.png` 若缺失属未入库文件**，需另补 PNG）
- `assets/ui/stars/`
- `assets/ui/instruments/`（除 **`pi_r_free_deploy.png`** 若仍缺则单独补图）
- `assets/enemies/` 下序列帧 / `SpriteSheet/` 单帧（按目录已抠版本）

---

## 无武器版本最小待补清单（第三波，2026-04-30）

> 本清单聚焦无武器版本的最小资产子集，按优先级排序，确保游戏基础可玩性。  
> 目录路径已与代码实际引用路径对齐确认；**平台类型卡面小图**以 `assets/card_icons/` 为准（与战场精灵解耦）。

### 已生成资产（确认有效）

| 文件 | 目录 | 说明 |
|------|------|------|
| `hound.png` 等 12 种平台键名 | `assets/card_icons/` | 与 `PlatformType` 对应的卡面小图（背包/UI 使用 `res://assets/card_icons/<键>.png`） |
| `law.png`、`energy.png` | `assets/card_icons/` | 法则卡 / 能量卡类展示用 |
| `icon_arrow_left.png` | `assets/ui/icons/` | 左箭头 |

### A. 卡牌图标（第一优先）→ `assets/card_icons/`

尺寸：512×512 PNG，透明底，主体居中，边缘留 8-12% 安全区。  
**说明**：下列为 UI/背包用**卡面图标**，与战场走 `assets/enemies` 的精灵**不是同一套文件**。

| # | 文件名 | 中文名 | 说明 | 状态 |
|---|--------|--------|------|------|
| 1 | hound.png | 侦察型 | 轻型高速单位卡图 | **已有** |
| 2 | guard.png | 护卫型 | 中近程防护单位卡图 | **已有** |
| 3 | titan.png | 泰坦型 | 重型主战单位卡图 | **已有** |
| 4 | fortress.png | 要塞型 | 阵地防御单位卡图 | **已有** |
| 5 | radar.png | 雷达型 | 侦测/增益单位卡图 | **已有** |
| 6 | scout.png | 轻侦察型 | 前出探路单位卡图 | **已有** |
| 7 | raider.png | 突击型 | 快速突破单位卡图 | **已有** |
| 8 | siege.png | 攻城型 | 远程重火力单位卡图 | **已有** |
| 9 | carrier.png | 母舰型 | 高成本核心单位卡图 | **已有** |
| 10 | medic.png | 维修型 | 回复支援单位卡图 | **已有** |
| 11 | stealth.png | 隐匿型 | 潜行干扰单位卡图 | **已有** |
| 12 | omega_platform.png | 全装型 | 终端/王牌单位卡图 | **已有** |

**小计：平台类型卡图 12/12 已有**（若需按 `card_id` 逐张平台卡/时代变体，另见 4.1 与 `default_cards.gd`）

### B. 卡牌边框（第二优先）→ `assets/cards/frames/`

尺寸：512×512 PNG，透明底，仅边框层，中心留空。

| # | 文件名 | 中文名 | 颜色 | 状态 |
|---|--------|--------|------|------|
| 1 | common.png | 普通边框 | 灰 #BFBFBF | **已有** |
| 2 | uncommon.png | 优秀边框 | 绿 #66E680 | **已有** |
| 3 | rare.png | 稀有边框 | 蓝 #66A6FF | **已有** |
| 4 | epic.png | 史诗边框 | 紫 #BF66FF | **已有** |
| 5 | legendary.png | 传说边框 | 金 #FFB34D | **已有**（透明底） |

**小计：5/5 已有**（运行时代码仍以 ColorRect 边框为主；PNG 框为可选增强，叠卡 UI 另议）

### C. 功能UI图标（第二优先）→ `assets/ui/icons/`

尺寸：256×256 PNG，单色深色 UI 适配。

| # | 文件名 | 中文名 | 状态 |
|---|--------|--------|------|
| 1 | icon_shop.png | 商店 | **已有**（透明底） |
| 2 | icon_quest.png | 任务 | **已有**（透明底） |
| 3 | icon_leaderboard.png | 排行榜 | **已有**（透明底） |
| 4 | icon_settings.png | 设置 | **已有**（透明底） |
| 5 | icon_help.png | 帮助 | **已有**（透明底） |
| 6 | icon_close.png | 关闭 | **已有**（透明底） |
| 7 | icon_arrow_left.png | 左箭头 | **已有** |
| 8 | icon_arrow_right.png | 右箭头 | **已有**（透明底） |
| 9 | icon_filter.png | 筛选 | **已有**（透明底） |
| 10 | icon_sort.png | 排序 | **已有**（透明底） |

> 其余 `icon_backpack` / `icon_blueprint` / `icon_law` / `icon_save` / `icon_lock` / `icon_upgrade` / `icon_equip` / `icon_remove` / `icon_coin` / `icon_phase_instrument` 等见 `assets/ui/icons/`，**均已透明底入仓**。

**小计：功能图标集已齐（透明底）**

### D. 势力Logo（第三优先）→ `assets/ui/factions/`

每个势力两版：32×32 与 128×128。

| # | 势力ID | 中文名 | 风格 | 32px | 128px |
|---|--------|--------|------|------|-------|
| 1 | iron_wall_corp | 钢壁防务公司 | 盾牌/钢铁纹理 | **缺 PNG** | **已有**（透明底） |
| 2 | nova_arms | 新星兵工制造 | 火焰/枪械交叉 | **缺 PNG** | **已有**（透明底） |
| 3 | aether_dynamics | 以太动力重工 | 引擎/相位推进 | **缺 PNG** | **已有**（透明底） |
| 4 | quantum_logistics | 量子后勤集团 | 数据流/箱子 | **缺 PNG** | **已有**（透明底） |
| 5 | helix_recon | 螺旋侦察系统 | 螺旋/雷达扫描 | **缺 PNG** | **已有**（透明底） |
| 6 | void_research | 虚空相位研究所 | 虚空裂纹/眼睛 | **缺 PNG** | **已有**（透明底） |
| 7 | frontier_union | 边境联合公司 | 多元交叉/旗帜 | **缺 PNG** | **已有**（透明底） |

**小计**：128 版 **7/7 已有**；32 版 **待补 7 个文件**（抠图规格已满足时，补齐 `*_32.png` 即可）。

### E. 星级图标（第三优先）→ `assets/ui/stars/`

尺寸：128×128 PNG，系列风格统一，金色 #FFD700。

| # | 文件名 | 中文名 | 状态 |
|---|--------|--------|------|
| 1 | star_1.png | 1星 | **已有**（透明底） |
| 2 | star_2.png | 2星 | **已有**（透明底） |
| 3 | star_3.png | 3星 | **已有**（透明底） |
| 4 | star_4.png | 4星 | **已有**（透明底） |
| 5 | star_5.png | 5星 | **已有**（透明底） |
| 6 | star_6.png | 6星 | **已有**（透明底） |
| 7 | star_7.png | 7星 | **已有**（透明底） |

**小计：7/7 已有**（另有 `star_8.png` 可视为扩展资源）

### F. 音频最小包（第三优先）→ `assets/music/` + `assets/sfx/`

音频暂缓生成，建议尽快补充。

**小计：待生成 0（暂缓）**

---

**最小待补清单小计（不含音频）**：绿底类目 PNG **已透明底入仓**；本节旧「待生成」以 **2026-05-03** 状态为准已上修。仍可能缺的仅为 **非抠图项**（例：势力 32px 文件、`pi_r_free_deploy`、音频/特效等）。

生成脚本：`scripts/batch_gen_v2.py`（共 47 个任务，含音频占位）

---

## P0 — 核心视觉（无此不可上线）

### 1. 字体（2-3套）

| # | 用途 | 规格要求 | 存放路径 | 状态 |
|---|------|---------|---------|------|
| 1 | 标题字体 | 厚重/科技感，中文+英文 | `assets/fonts/title_font.ttf` | 文件可已有；**全局 Theme/UI 引用待统一** |
| 2 | 正文字体 | 清晰可读，中文+数字+英文混排 | `assets/fonts/body_font.otf` | **已用作** `project.godot` → `theme/custom_font` |
| 3 | 数据字体 | 等宽/数字友好（伤害、资源数） | `assets/fonts/data_font.ttf` | 文件可已有；**全局 UI 引用待统一** |

建议来源：思源黑体(Noto Sans SC) + 1款特色标题字体

---

### 2. 战场单位视觉（我方 = 敌方资源 + 少数例外）

> **不再**按「每种平台一张 `assets/unit_sprites/<platform>.png`」列缺。  
> 代码：`scenes/units/construct_unit.gd` → `PLAYER_MIRROR_ARCHETYPE_BY_PLATFORM`、`ENEMY_VISUAL_ASSET_BASE`（`res://assets/enemies`）、可选 `PLAYER_FROM_ENEMY_ROOT`。  
> **例外**：`PlatformType.OMEGA_PLATFORM` 等仍可使用 `assets/unit_sprites/omega_platform.png`（及 `-1` 帧等）。

**平台类型 → 当前用于显示的敌方原型 id（便于查 `assets/enemies` 是否齐）**

| # | PlatformType | 映射 archetype_id |
|---|----------------|-------------------|
| 1 | HOUND | `enemy_ww1_infantry_basic` |
| 2 | GUARD | `enemy_ww2_infantry` |
| 3 | TITAN | `elite_ww1_armored` |
| 4 | FORTRESS | `enemy_ww1_mg_nest` |
| 5 | RADAR | `enemy_modern_stryker` |
| 6 | SCOUT | `enemy_cold_btr` |
| 7 | RAIDER | `enemy_future_hovertank` |
| 8 | SIEGE | `enemy_ww1_mortar` |
| 9 | CARRIER | `enemy_cold_m113` |
| 10 | MEDIC | `enemy_modern_marine` |
| 11 | STEALTH | `elite_future_spectre` |
| 12 | OMEGA_PLATFORM | `enemy_future_mech`（战场可走敌方帧；卡面另用 `omega_platform.png`） |

**待补含义**：上述 archetype 在 `assets/enemies/`（及 `SpriteSheet`）内是否具备 **idle / run / attack** 等动画与合理 `visual_scale`，见 **P2 §16 敌人动画帧补全**。

---

### 3. ~~我方武器精灵图（12种）~~ **已废止**

当前设定下**不向战场交付**独立武器精灵目录（如 `assets/unit_sprites/weapons/`）。  
若数据层仍保留 `WeaponType` / 武器卡 id，仅用于**数值或 UI 文案**，美术清单不再单列「12 武器战场贴图」。

---

### 4. 卡牌图标（60+张）

> 代码定义：`data/default_cards.gd`
> 需要区分星级/稀有度边框颜色
> 建议做法：卡牌框架模板(5种稀有度) + 单位小图
> 存放路径：`assets/card_icons/`

#### 4.1 平台卡图标（12张）

| # | card_id | 名称 | 状态 |
|---|---------|------|------|
| 1 | hound | 侦察型 | **已有** |
| 2 | guard | 护卫型 | **已有** |
| 3 | titan | 泰坦型 | **已有** |
| 4 | fortress | 要塞型 | **已有** |
| 5 | radar | 雷达型 | **已有** |
| 6 | scout | 轻侦察型 | **已有** |
| 7 | raider | 突击型 | **已有** |
| 8 | siege | 攻城型 | **已有** |
| 9 | carrier | 母舰型 | **已有** |
| 10 | medic | 维修型 | **已有** |
| 11 | stealth | 隐匿型 | **已有** |
| 12 | omega_platform | 全装型 | **已有** |

> 各时代 **platform_*** 具体 `card_id`（如 `platform_ww1_light`）若需独立卡图，可按 `res://assets/card_icons/<card_id>.png` 扩展；当前 UI 多回退到**平台类型键名**图标。

#### 4.2 武器卡图标（不设战场精灵；卡面可选）

无武器版战斗**不要求**为 `smg` / `rifle` 等单独准备 12 张战场精灵。若背包/图鉴仍展示武器卡，可二选一：  
- 使用**通用占位图**（如扩展名一致的单张 `weapon_generic.png`，需改代码引用）；或  
- 仍按 `card_id` 逐张补 `assets/card_icons/<card_id>.png`（**非 P0**，与战场表现解耦）。

#### 4.3 能量卡图标（10张）

> 代码定义：`data/default_cards.gd` 行128-143

| # | card_id | 名称 | 效果 | 状态 |
|---|---------|------|------|------|
| 1 | energy_start_1 | 战前能量 I | 初始+5能量 | **已有**（透明底） |
| 2 | energy_start_2 | 战前能量 II | 初始+10能量 | **已有**（透明底） |
| 3 | energy_start_3 | 战前能量 III | 初始+15能量 | **已有**（透明底） |
| 4 | energy_regen_1 | 能量收集 I | +0.2/秒 | **已有**（透明底） |
| 5 | energy_regen_2 | 能量收集 II | +0.5/秒 | **已有**（透明底） |
| 6 | energy_regen_3 | 能量收集 III | +0.8/秒 | **已有**（透明底） |
| 7 | energy_instant_s | 小型能量包 | +15即时 | **已有**（透明底） |
| 8 | energy_instant_m | 中型能量包 | +30即时 | **已有**（透明底） |
| 9 | energy_instant_l | 大型能量包 | +50即时 | **已有**（透明底） |
| 10 | energy_hybrid | 混合能量核心 | 初始+15 +0.3/秒 | **已有**（透明底） |

#### 4.4 法则卡图标（25张）

> 代码定义：`data/phase_laws.gd`

**钢铁家族（Steel）- 7张**
| # | law_id | 名称 | kind | 状态 |
|---|--------|------|------|------|
| 1 | steel_phase_armor | 钢铁·相位装甲 | passive | **已有**（透明底） |
| 2 | steel_bastion_wall | 钢铁·堡垒之墙 | active | **已有**（透明底） |
| 3 | steel_quick_repair | 钢铁·快速维修 | passive | **已有**（透明底） |
| 4 | steel_aegis_link | 钢铁·护阵联结 | passive | **已有**（透明底） |
| 5 | steel_anchor_field | 钢铁·锚定力场 | active | **已有**（透明底） |
| 6 | steel_fortify_protocol | 钢铁·固壁协议 | passive | **已有**（透明底） |
| 7 | steel_resonant_plate | 钢铁·共振装甲 | passive | **已有**（透明底） |

**烈焰家族（Flame）- 7张**
| # | law_id | 名称 | kind | 状态 |
|---|--------|------|------|------|
| 8 | flame_heat_overload | 烈焰·热能过载 | passive | **已有**（透明底） |
| 9 | flame_front_bombard | 烈焰·前线火力压制 | active | **已有**（透明底） |
| 10 | flame_mark | 烈焰·灼烧印记 | active | **已有**（透明底） |
| 11 | flame_scorch_wave | 烈焰·灼浪推进 | active | **已有**（透明底） |
| 12 | flame_ember_screen | 烈焰·灰烬幕障 | active | **已有**（透明底） |
| 13 | flame_core_rupture | 烈焰·核心破裂 | active | **已有**（透明底） |
| 14 | flame_afterburn | 烈焰·余烬加燃 | passive | **已有**（透明底） |

**雷霆家族（Thunder）- 6张**
| # | law_id | 名称 | kind | 状态 |
|---|--------|------|------|------|
| 15 | thunder_emp_storm | 雷霆·电磁风暴 | active | **已有**（透明底） |
| 16 | thunder_chain_discharge | 雷霆·链式放电 | active | **已有**（透明底） |
| 17 | thunder_ion_net | 雷霆·离子网 | active | **已有**（透明底） |
| 18 | thunder_arc_beacon | 雷霆·弧光信标 | active | **已有**（透明底） |
| 19 | thunder_surge_drive | 雷霆·激涌驱动 | passive | **已有**（透明底） |
| 20 | thunder_static_domain | 雷霆·静电域 | passive | **已有**（透明底） |

**虚空家族（Void）- 5张**
| # | law_id | 名称 | kind | 状态 |
|---|--------|------|------|------|
| 21 | void_time_ripple | 虚空·时空涟漪 | active | **已有**（透明底） |
| 22 | void_barrier_shift | 虚空·护盾转移 | active | **已有**（透明底） |
| 23 | void_phase_cloak | 虚空·相位披幕 | active | **已有**（透明底） |
| 24 | void_entropy_lens | 虚空·熵镜 | passive | **已有**（透明底） |
| 25 | void_gravity_well | 虚空·引力井 | active | **已有**（透明底） |

#### 4.5 卡牌边框模板（5种稀有度）

> 代码定义：`resources/game_constants.gd` get_rarity_color (行182-188)
> 存放路径：`assets/cards/frames/`（规划目录，当前运行时代码未直接引用）

| # | 稀有度 | 中文名 | 颜色 | 状态 |
|---|--------|--------|------|------|
| 1 | common | 普通 | 灰 #BFBFBF | **已有** |
| 2 | uncommon | 优秀 | 绿 #66E680 | **已有** |
| 3 | rare | 稀有 | 蓝 #66A6FF | **已有** |
| 4 | epic | 史诗 | 紫 #BF66FF | **已有** |
| 5 | legendary | 传说 | 金 #FFB34D | **已有**（透明底） |

**卡牌图标小计（粗算）**：平台类型 12 + 能量 10 + 法则 25 + 边框 5 + 各时代平台卡等增量；**不再计入**「武器卡 12 张」为 P0 必补。

---

### 5. 法则施放特效（25组）

> 代码定义：`data/phase_laws.gd` 25条法则
> 每条法则需：施放动画 + 持续效果 + 目标指示器
> 已有代码框架：`cast_effect.tscn`、`law_target_indicator.tscn`
> 存放路径：`assets/effects/laws/`

分4个家族色系：钢铁(银灰)、烈焰(橙红)、雷霆(蓝白)、虚空(暗紫)

| # | 法则ID | 家族 | kind | 特效需求 | 状态 |
|---|--------|------|------|---------|------|
| 1 | steel_phase_armor | 钢铁 | passive | 装甲覆盖银色护盾光效 | 缺 |
| 2 | steel_bastion_wall | 钢铁 | active | 墙壁从地面升起的金属壁垒 | 缺 |
| 3 | steel_quick_repair | 钢铁 | passive | 修复火花粒子 + 绿色回血光 | 缺 |
| 4 | steel_aegis_link | 钢铁 | passive | 单位间银色能量链连接 | 缺 |
| 5 | steel_anchor_field | 钢铁 | active | 地面锚定光环扩散 | 缺 |
| 6 | steel_fortify_protocol | 钢铁 | passive | 金属硬化闪光 | 缺 |
| 7 | steel_resonant_plate | 钢铁 | passive | 共振波纹扩散 | 缺 |
| 8 | flame_heat_overload | 烈焰 | passive | 红色过热光环 | 缺 |
| 9 | flame_front_bombard | 烈焰 | active | 前方扇形火焰喷射 | 缺 |
| 10 | flame_mark | 烈焰 | active | 目标标记灼烧印记 | 缺 |
| 11 | flame_scorch_wave | 烈焰 | active | 火浪推进波浪 | 缺 |
| 12 | flame_ember_screen | 烈焰 | active | 灰烬幕障粒子墙 | 缺 |
| 13 | flame_core_rupture | 烈焰 | active | 核心爆炸球体 | 缺 |
| 14 | flame_afterburn | 烈焰 | passive | 尾焰增强拖尾 | 缺 |
| 15 | thunder_emp_storm | 雷霆 | active | 电磁风暴区域闪电 | 缺 |
| 16 | thunder_chain_discharge | 雷霆 | active | 链式闪电弹跳 | 缺 |
| 17 | thunder_ion_net | 雷霆 | active | 离子网覆盖区域 | 缺 |
| 18 | thunder_arc_beacon | 雷霆 | active | 弧光信标光柱 | 缺 |
| 19 | thunder_surge_drive | 雷霆 | passive | 电涌加速拖尾 | 缺 |
| 20 | thunder_static_domain | 雷霆 | passive | 静电场闪烁区域 | 缺 |
| 21 | void_time_ripple | 虚空 | active | 时空涟漪扭曲波 | 缺 |
| 22 | void_barrier_shift | 虚空 | active | 护盾转移流动效果 | 缺 |
| 23 | void_phase_cloak | 虚空 | active | 相位隐身半透明披风 | 缺 |
| 24 | void_entropy_lens | 虚空 | passive | 熵镜紫色聚焦光 | 缺 |
| 25 | void_gravity_well | 虚空 | active | 引力井漩涡吸入效果 | 缺 |

**小计：缺 25 组特效**

> **（2026-05-03）** 上表「缺」指 **战场/施法 VFX**，与 `assets/card_icons/<law_id>.png` **法则卡静帧**无关；静帧卡面已 **透明底入仓**（见 §4.4）。

---

## P1 — 系统图标与UI美化

### 6. 势力Logo（7个）

> 代码定义：`data/company_definitions.gd`
> 需要小尺寸(32x32)和大尺寸(128x128)两个版本
> 存放路径：`assets/ui/factions/`

| # | ID | 名称 | 风格建议 | 状态 |
|---|-----|------|---------|------|
| 1 | iron_wall_corp | 钢壁防务公司 | 盾牌/钢铁纹理 | 128 **已有** / 32 **缺 PNG** |
| 2 | nova_arms | 新星兵工制造 | 火焰/枪械交叉 | 128 **已有** / 32 **缺 PNG** |
| 3 | aether_dynamics | 以太动力重工 | 引擎/相位推进 | 128 **已有** / 32 **缺 PNG** |
| 4 | quantum_logistics | 量子后勤集团 | 数据流/箱子 | 128 **已有** / 32 **缺 PNG** |
| 5 | helix_recon | 螺旋侦察系统 | 螺旋/雷达扫描 | 128 **已有** / 32 **缺 PNG** |
| 6 | void_research | 虚空相位研究所 | 虚空裂纹/眼睛 | 128 **已有** / 32 **缺 PNG** |
| 7 | frontier_union | 边境联合公司 | 多元交叉/旗帜 | 128 **已有** / 32 **缺 PNG** |

---

### 7. 星级图标（7级）

> 代码定义：星级分界 1★(0-250) ~ 7★(6000+)
> 存放路径：`assets/ui/stars/`

| # | 星级 | 文件名 | 状态 |
|---|------|--------|------|
| 1 | 1星 | star_1.png | **已有**（透明底） |
| 2 | 2星 | star_2.png | **已有**（透明底） |
| 3 | 3星 | star_3.png | **已有**（透明底） |
| 4 | 4星 | star_4.png | **已有**（透明底） |
| 5 | 5星 | star_5.png | **已有**（透明底） |
| 6 | 6星 | star_6.png | **已有**（透明底） |
| 7 | 7星 | star_7.png | **已有**（透明底） |

---

### 8. 资源图标（4种）

> 代码定义：`data/basic_resources.gd`
> 存放路径：`assets/resources/`（代码已引用此路径）

| # | ID | 名称 | 代码引用路径 | 状态 |
|---|-----|------|------------|------|
| 1 | nano_materials | 纳米材料 | `assets/resources/basic_nano.png`（代码内 id 为 `nano_materials` 等） | **多半已有**，与 UI 一致即可 |
| 2 | alloy | 合金 | `assets/resources/alloy.png` | **多半已有** |
| 3 | crystal | 晶体 | `assets/resources/crystal.png` | **多半已有** |
| 4 | energy_block | 能量块 | `assets/resources/energy_block.png` | **多半已有** |

---

### 9. 相位仪属性图标（26种）

> 代码定义：`data/phase_instruments.gd` 行9-36
> 存放路径：`assets/ui/instruments/`

**基础属性（12种 Common/Uncommon）**

| # | ID | 名称 | 稀有度 | 状态 |
|---|-----|------|--------|------|
| 1 | pi_atk | 卡牌伤害+% | Common | **已有**（透明底） |
| 2 | pi_def | 防御+% | Common | **已有**（透明底） |
| 3 | pi_hp | 生命+% | Common | **已有**（透明底） |
| 4 | pi_xp | 经验+% | Common | **已有**（透明底） |
| 5 | pi_drop | 掉落+% | Common | **已有**（透明底） |
| 6 | pi_energy_out | 能量输出+% | Common | **已有**（透明底） |
| 7 | pi_energy_rec | 能量恢复+% | Common | **已有**（透明底） |
| 8 | pi_energy_cost | 能量消耗-X | Uncommon | **已有**（透明底） |
| 9 | pi_deploy_range | 部署范围+% | Common | **已有**（透明底） |
| 10 | pi_crit | 暴击率+% | Uncommon | **已有**（透明底） |
| 11 | pi_crit_dmg | 暴击伤害+% | Uncommon | **已有**（透明底） |
| 12 | pi_move_speed | 移速+% | Uncommon | **已有**（透明底） |
| 13 | pi_attack_speed | 攻速+% | Uncommon | **已有**（透明底） |

**稀有属性（13种 Rare/Epic/Legendary）**

| # | ID | 名称 | 稀有度 | 状态 |
|---|-----|------|--------|------|
| 14 | pi_r_first_deploy | 初次部署 | Rare | **已有**（透明底） |
| 15 | pi_r_kill_energy | 战斗续能 | Rare | **已有**（透明底） |
| 16 | pi_r_law_boost | 法则共鸣 | Rare | **已有**（透明底） |
| 17 | pi_r_energy_fountain | 能量涌泉 | Rare | **已有**（透明底） |
| 18 | pi_r_dmg_reflect | 伤害反射 | Rare | **已有**（透明底） |
| 19 | pi_r_respawn | 相位重生 | Epic | **已有**（透明底） |
| 20 | pi_r_shield | 初始护盾 | Epic | **已有**（透明底） |
| 21 | pi_r_cascade | 连锁反应 | Epic | **已有**（透明底） |
| 22 | pi_r_overload | 过载强化 | Epic | **已有**（透明底） |
| 23 | pi_r_last_stand | 最后意志 | Epic | **已有**（透明底） |
| 24 | pi_r_energy_burst | 能量爆发 | Epic | **已有**（透明底） |
| 25 | pi_r_scale | 越战越强 | Legendary | **已有**（透明底） |
| 26 | pi_r_free_deploy | 零成本部署 | Legendary | **缺 PNG** |

---

### 10. 功能UI图标（~20个）

> 存放路径：`assets/ui/icons/`

| # | 图标 | 用途场景 | 状态 |
|---|------|---------|------|
| 1 | icon_backpack | 背包按钮 | **已有**（透明底） |
| 2 | icon_blueprint | 蓝图/合成按钮 | **已有**（透明底） |
| 3 | icon_phase_instrument | 相位仪按钮 | **已有**（透明底） |
| 4 | icon_law | 法则按钮 | **已有**（透明底） |
| 5 | icon_shop | 商店 | **已有**（透明底） |
| 6 | icon_quest | 任务/委托 | **已有**（透明底） |
| 7 | icon_leaderboard | 排行榜 | **已有**（透明底） |
| 8 | icon_settings | 设置 | **已有**（透明底） |
| 9 | icon_save | 保存 | **已有**（透明底） |
| 10 | icon_help | 帮助/教程 | **已有**（透明底） |
| 11 | icon_close | 关闭按钮(X) | **已有**（透明底） |
| 12 | icon_arrow_left | 左箭头/返回 | **已有**（透明底） |
| 13 | icon_arrow_right | 右箭头/下一页 | **已有**（透明底） |
| 14 | icon_lock | 锁定/未解锁 | **已有**（透明底） |
| 15 | icon_filter | 筛选 | **已有**（透明底） |
| 16 | icon_sort | 排序 | **已有**（透明底） |
| 17 | icon_upgrade | 升级箭头 | **已有**（透明底） |
| 18 | icon_equip | 装备 | **已有**（透明底） |
| 19 | icon_remove | 移除/卸下 | **已有**（透明底） |
| 20 | icon_coin | 金币/通用货币 | **已有**（透明底） |

---

### 11. BGM（~10首）

> 存放路径：`assets/music/`
> AudioManager 已在代码中实现

| # | 曲目 | 风格 | 时长建议 | 状态 |
|---|------|------|---------|------|
| 1 | main_menu | 科技感主菜单 | 2-3分钟循环 | 缺 |
| 2 | battle_ww1 | 一战战壕/军乐 | 2-3分钟循环 | 缺 |
| 3 | battle_ww2 | 二战机械/行军 | 2-3分钟循环 | 缺 |
| 4 | battle_cold_war | 冷战紧张/电子 | 2-3分钟循环 | 缺 |
| 5 | battle_modern | 现代重低音/电子摇滚 | 2-3分钟循环 | 缺 |
| 6 | battle_near_future | 近未来赛博/合成器 | 2-3分钟循环 | 缺 |
| 7 | boss_fight | Boss战高燃 | 2-3分钟循环 | 缺 |
| 8 | tower_mode | 爬塔模式悬疑 | 2-3分钟循环 | 缺 |
| 9 | victory | 胜利欢快 | 10-15秒 | 缺 |
| 10 | defeat | 失败沉重 | 10-15秒 | 缺 |

---

### 12. 战斗音效（~30个）

> 存放路径：`assets/sfx/`

| # | 音效 | 描述 | 状态 |
|---|------|------|------|
| 1 | sfx_deploy | 部署单位 | 缺 |
| 2 | sfx_hit_generic | 通用受击 | 缺 |
| 3 | sfx_explosion_small | 小爆炸 | 缺 |
| 4 | sfx_explosion_medium | 中爆炸 | 缺 |
| 5 | sfx_explosion_large | 大爆炸 | 缺 |
| 6 | sfx_unit_death | 单位死亡 | 缺 |
| 7 | sfx_fire_ww1 | 一战武器开火 | 缺 |
| 8 | sfx_fire_ww2 | 二战武器开火 | 缺 |
| 9 | sfx_fire_cold_war | 冷战武器开火 | 缺 |
| 10 | sfx_fire_modern | 现代武器开火 | 缺 |
| 11 | sfx_fire_near_future | 近未来武器开火(激光) | 缺 |
| 12 | sfx_energy_spend | 能量消耗 | 缺 |
| 13 | sfx_energy_gain | 能量获取 | 缺 |
| 14 | sfx_law_cast | 法则施放 | 缺 |
| 15 | sfx_shield_hit | 护盾受击 | 缺 |
| 16 | sfx_heal | 治疗 | 缺 |
| 17 | sfx_boss_enter | Boss出场 | 缺 |
| 18 | sfx_warning | 警告(敌方来袭) | 缺 |
| 19 | sfx_wave_start | 波次开始 | 缺 |
| 20 | sfx_wave_clear | 波次清除 | 缺 |

---

### 13. UI音效（~15个）

> 存放路径：`assets/sfx/ui/`

| # | 音效 | 描述 | 状态 |
|---|------|------|------|
| 1 | ui_click | 按钮点击 | 缺 |
| 2 | ui_hover | 悬停 | 缺 |
| 3 | ui_page_turn | 翻页 | 缺 |
| 4 | ui_upgrade | 升级成功 | 缺 |
| 5 | ui_craft_success | 合成成功 | 缺 |
| 6 | ui_craft_fail | 合成失败 | 缺 |
| 7 | ui_purchase | 商店购买 | 缺 |
| 8 | ui_unlock | 解锁 | 缺 |
| 9 | ui_card_draw | 抽卡 | 缺 |
| 10 | ui_equip | 装备 | 缺 |
| 11 | ui_unequip | 卸下 | 缺 |
| 12 | ui_sell | 出售 | 缺 |
| 13 | ui_error | 错误提示 | 缺 |
| 14 | ui_reward | 奖励领取 | 缺 |
| 15 | ui_notification | 通知弹窗 | 缺 |

---

### 14. 粒子特效（~15种）

> 存放路径：`assets/particles/`

| # | 特效 | 用途 | 状态 |
|---|------|------|------|
| 1 | fx_burn | 燃烧DOT | 缺 |
| 2 | fx_electric | 电击/雷电 | 缺 |
| 3 | fx_void_corrode | 虚空腐蚀 | 缺 |
| 4 | fx_steel_shield | 钢铁护盾 | 缺 |
| 5 | fx_upgrade_glow | 升级光芒 | 缺 |
| 6 | fx_craft_flash | 合成闪光 | 缺 |
| 7 | fx_resource_pickup | 资源获取 | 缺 |
| 8 | fx_fragment_drop | 碎片掉落 | 缺 |
| 9 | fx_deploy_smoke | 部署烟雾 | 缺 |
| 10 | fx_explosion | 通用爆炸 | 缺 |
| 11 | fx_muzzle_flash | 枪口火焰 | 缺 |
| 12 | fx_laser_beam | 激光光束 | 缺 |
| 13 | fx_missile_trail | 导弹拖尾 | 缺 |
| 14 | fx_energy_drain | 能量抽取 | 缺 |
| 15 | fx_phase_shift | 相位转移 | 缺 |

---

## P2 — 打磨与差异化（可延后）

### 15. 背景质量审核

> 存放路径：`assets/backgrounds/`

| 类别 | 数量 | 状态 |
|------|------|------|
| bg_level_01~100 | 100张 | 已有，需质量审核 |
| bg_01~03, bg_default | 4张 | 已有(占位/默认) |
| bg_level_1~8 | 8张 | 已有(遗留，建议清理) |

审核要点：无角色/无文字/三层构图/视差滚动兼容

---

### 16. 敌人动画帧补全

> 存放路径：`assets/enemies/SpriteSheet/`
> 当前仅 enemy_ww1_infantry_basic 有独立帧目录(idle/run/attack)
> **2026-05-03**：各套序列帧图在仓库内已为 **透明底**（绿幕已抠）；下表「需补帧」指 **动画条数与 Boss 特殊动作**，与色键无关。

| # | 敌人精灵 | 需补帧 | 状态 |
|---|---------|--------|------|
| 1 | 36套SpriteSheet全部 | idle + run + attack | 仅1套有帧 |
| 2 | 6个Boss | +入场/死亡特殊动画 | 缺 |

---

### 17. Shader效果（~5种）

> 存放路径：`assets/shaders/`

| # | Shader | 用途 | 状态 |
|---|--------|------|------|
| 1 | energy_field | 能量场视觉(8种颜色) | 缺 |
| 2 | damage_flash | 受伤闪红 | 缺 |
| 3 | shield_effect | 护盾效果 | 缺 |
| 4 | phase_shift | 相位转移半透明 | 缺 |
| 5 | rain/fog/sandstorm | 天气效果 | 缺 |

---

## 汇总统计

| 优先级 | 类别 | 需要量 | 已有量 | 缺口 |
|--------|------|--------|--------|------|
| **P0** | 字体（接 UI） | 3 | 1（`body_font.otf` 已进主题） | **2 套待统一引用** |
| **P0** | 战场单位视觉 | 12 套映射原型 | 依 `assets/enemies` 实填 | **以敌方精灵+帧为主**（见 §2、P2§16） |
| ~~**P0**~~ | ~~我方武器精灵~~ | — | — | **已废止**（无武器版战斗） |
| **P0** | 卡牌图标(含边框) | 约 50+ 增量项 | 卡面/能量/法则/边框 PNG **已透明底入仓** | **缺项主要为法则战场 VFX（非静态 PNG）** |
| **P0** | 法则特效 | 25组 | 0 | **25组** |
| **P1** | 势力Logo | 14（7×2 规格） | 128×7 **已有** | **32×7 缺文件**（与抠图独立） |
| **P1** | 星级图标 | 7 | 7 | **0** |
| **P1** | 资源图标 | 4 | 4（常见） | **0～审核** |
| **P1** | 相位仪属性图标 | 26 | 25 | **缺 `pi_r_free_deploy` 等 1 张** |
| **P1** | 功能UI图标 | 20 | 20 | **0** |
| **P1** | BGM | 10 | 0 | **10** |
| **P1** | 战斗音效 | 20 | 0 | **20** |
| **P1** | UI音效 | 15 | 0 | **15** |
| **P1** | 粒子特效 | 15 | 0 | **15** |
| P2 | 背景审核 | 112 | 112 | 需审核 |
| P2 | 敌人动画帧 | 36+6 | 1 | **41套** |
| P2 | Shader | 5 | 0 | **5** |
| **最小待补清单小计** | | | | | **见文首第三节（已扣武器与旧「我方载具」口径）** |

---

## 推荐执行顺序

1. **敌方战场精灵与帧** → 保证 §2 映射表中各 `archetype_id` 在 `assets/enemies/` 有可用 `SpriteFrames` 或单帧（与 P2 §16 合并执行）
2. **字体** → 保留 `body_font.otf` 主题；将 `title_font` / `data_font` 接入 Theme 或主 UI
3. **卡牌边框** → PNG 已齐；按需把 `cards/frames/*.png` **接到卡面 UI**（叠框逻辑）
4. **卡牌图标** → 静帧已齐；按需扩展 `get_shape_key()` 或背包加载逻辑以优先 `card_id` 图
5. **资源图标** → 核对 `basic_resources.gd` 路径与像素风格
6. **功能UI图标** → 已入 `assets/ui/icons/`；持续统一 Theme/场景引用即可
7. **法则特效** → 25 组，工作量最大
8. **音频** → BGM + 音效可并行外包/AI生成  
9. ~~批量生成我方载具/武器战场精灵~~ → **已不适用**当前架构；旧脚本任务需人工筛除武器与重复平台项
