# 相位战争 (Phase War) — 项目架构完整文档

> 自动生成日期: 2026-06-13
> 引擎: Godot 4.x | 语言: GDScript
> 项目路径: `D:\godotplay\godot fair duel\phase-war`

---

## 目录

1. [游戏设计概述](#1-游戏设计概述)
2. [A. 游戏设计设置（资源层）](#a-游戏设计设置资源层)
3. [B. 数据文件](#b-数据文件)
4. [C. 管理器架构](#c-管理器架构)
5. [D. 主场景架构](#d-主场景架构)
6. [E. 战斗系统架构](#e-战斗系统架构)
7. [F. 卡牌系统架构](#f-卡牌系统架构)

---

## 1. 游戏设计概述

### 1.1 核心概念

**相位战争**是一款以时代推进为核心机制的军事策略游戏，玩家跨越5个历史时代（一战→近未来）指挥军事单位进行战斗。

- **5个时代**：一战(1-20关)、二战(21-40关)、冷战(41-60关)、现代(61-80关)、近未来(81-100关)
- **110+ 张默认战斗卡**：每个时代约20+张
- **143 个敌人蓝图**：平台54 + 武器89
- **7大势力阵营**：苍穹动力、边境联盟、虚空研究所、铁壁集团、新星军火、螺旋侦察、量子后勤
- **11条进化路线**：轻装/装甲/空中/支援/堡垒等
- **140+ 改造模块**：8个兵种分类 + 通用
- **法则系统**：钢铁/烈焰/雷霆/虚空四大法则家族

### 1.2 卡牌类型 (CardType)

| 枚举值 | 名称 | 说明 |
|--------|------|------|
| 0 | `COMBAT_UNIT` | 战斗卡（主要类型） |
| 1 | `ENERGY` | 能量卡 |
| 2 | `LAW` | 法则卡 |
| 3-5 | PLATFORM/WEAPON/COMBINED | 已废弃，仅存档兼容 |

### 1.3 战斗定位 (CombatKind)

| 枚举值 | 名称 | 固有特性 |
|--------|------|----------|
| 0 | LIGHT (轻装) | 高闪避 18% |
| 1 | ARMOR (装甲) | 防御+4 全类型 |
| 2 | SUPPORT (支援) | HP×1.08 |
| 3 | AIR (空中) | 闪避12%+防御+2 |
| 4 | FORT (堡垒) | 防御+8全类型+HP×1.15 |

### 1.4 武器攻击方式 (WeaponType)

| 枚举值 | 名称 | 说明 |
|--------|------|------|
| 0 | DIRECT (直射) | 坦克炮、步枪等，攻击最近敌人，有射程衰减 |
| 1 | INDIRECT (曲射) | 迫击炮、榴弹炮，全图攻击被克制类型 |
| 2 | AERIAL (空射) | 战斗机、无人机，全图攻击，可被防空拦截 |
| 3 | SUPPORT (辅助) | 无攻击力，不参与攻击 |

### 1.5 稀有度系统

| 稀有度 | 颜色 | 十六进制 |
|--------|------|----------|
| common (普通) | 灰色 | #BFBFBF |
| uncommon (优秀) | 绿色 | #66E680 |
| rare (稀有) | 蓝色 | #66A6FF |
| epic (史诗) | 紫色 | #7B68EE |
| legendary (传说) | 金色 | #FFB34D |
| mythic (神话) | 粉金 | #FF6B9D |

---

## A. 游戏设计设置（资源层）

### A.1 `resources/game_constants.gd` — 游戏常量

**能量系统:**
- `ENERGY_MAX = 100.0` — 最大能量
- `ENERGY_START = 100.0` — 初始能量
- `ENERGY_REGEN_PER_SEC = 1.0` — 每秒回复
- `PHASE_BASE_DRAIN_PER_SEC = 0.5` — 相位基础消耗

**单位限制:**
- `PLAYER_SPAWN_INTERVAL = 10.0s`
- `PLAYER_MAX_UNITS = 5`
- `ENEMY_SPAWN_INTERVAL = 12.0s`
- `ENEMY_WAVE_INTERVAL = 12.0s`
- `ENEMY_MAX_UNITS = 5`

**侦察加成:**
- `RECON_FRAGMENT_BONUS_PER_UNIT = 0.10` — 每名侦察/隐匿单位
- `RECON_FRAGMENT_BONUS_CAP = 0.50` — 上限50%

**相位仪:**
- `PHASE_SLOT_COUNT = 4` — 4个槽位

**格子战术基准:**
- `CARD_GRID_REFERENCE_SCREEN_WIDTH_PX = 1280`
- `CARD_GRID_REFERENCE_SCREEN_HEIGHT_PX = 720`
- `CARD_GRID_BATTLE_VIEWPORT_HEIGHT_PX = 580.0`

**新游戏初始法则:**
- 主动: `flame_front_bombard`, `thunder_chain_discharge`
- 被动: `steel_fortify_protocol`, `flame_afterburn`
- 初始知识值: 50

**情报驱动系统常量:**
- `ENABLE_INTEL_DIMENSIONS = true`
- `ENABLE_ENEMY_ORIGIN_MODS = true`
- `INTEL_DIMENSION_WEIGHTS`: basic=0.30, tactical=0.30, material=0.25, secret=0.15
- `PERFECT_VICTORY_INTEL_BONUS = 0.10`

**经济系统:**
- `NANO_MATERIAL_BASE_REWARD = 5`
- `NANO_MATERIAL_PER_LEVEL_EARLY = 1.5`
- `NANO_MATERIAL_MAX_REWARD = 150`

**时代划分:** 1-20→一战, 21-40→二战, 41-60→冷战, 61-80→现代, 81-100→近未来

### A.2 `resources/game_config.gd` — 游戏配置

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| `first_wave_delay` | 3.0s | 第一波敌人延迟 |
| `default_enemy_wave_interval` | 12.0s | 敌人生成间隔 |
| `player_deploy_cooldown` | 1.0s | 玩家部署冷却 |
| `nano_bonus_base` | 5 | 纳米基础奖励 |
| `blueprint_drop_chance_base` | 0.15 | 蓝图掉落概率 |
| `exp_base_amount` | 10 | 基础经验 |
| `phase_master_encounter_chance` | 0.15 | 相位师遭遇率 |
| `phase_master_boss_level` | 49 | 相位师BOSS关卡 |
| `object_pool_size` | 9 | 对象池大小 |
| `max_particle_effects` | 50 | 最大粒子数 |
| `target_find_interval` | 0.3s | 目标查找间隔 |

### A.3 `resources/unit_stats_table.gd` — 数值表

**v3 主入口:** `build_stats_from_card(card, era_override)`

构建流程:
1. 从 CardResource 读取 base_hp, attack_*, defense_*, speed 等
2. 多维攻防透传 (attack_light/armor/air, defense_light/armor/air)
3. 时代缩放 (HP倍率, 伤害倍率, 射程倍率)
4. 武器槽位系统初始化 (WeaponResource[])
5. 改造效果应用 (ModificationRegistry)
6. 战斗定位修正 (combat_kind modifiers)
7. 强化词条效果 (apply_module_effects)

**战斗定位成长倾斜:**

| 定位 | HP偏 | 伤害偏 | 防御偏 | 闪避偏 | 速度偏 |
|------|------|--------|--------|--------|--------|
| LIGHT | 0.04 | 0.05 | — | 0.03 | — |
| ARMOR | 0.06 | 0.04 | 0.04 | — | — |
| SUPPORT | 0.05 | — | — | — | — |
| AIR | 0.03 | 0.06 | — | — | 0.05 |
| FORT | 0.08 | 0.02 | 0.06 | — | — |

**旧平台基础数据 (PlatformType→Speed/HP/Stationary):**

| PlatformType | 名称 | 速度 | HP | 固定 |
|---|---|---|---|---|
| 0 HOUND | 威克斯装甲侦察车 | 115 | 65 | ✗ |
| 1 GUARD | 雷诺装甲护卫车 | 75 | 110 | ✗ |
| 2 TITAN | 马克V型重型坦克 | 40 | 200 | ✗ |
| 3 FORTRESS | 要塞固定炮 | 0 | 260 | ✓ |
| 4 RADAR | 雷达指挥车 | 0 | 180 | ✓ |
| 5 SCOUT | 轻型侦察车 | 135 | 50 | ✗ |
| 6 RAIDER | 雷诺FT突击坦克 | 100 | 90 | ✗ |
| 7 SIEGE | 攻城重炮 | 0 | 300 | ✓ |
| 8 CARRIER | 载机母舰 | 50 | 140 | ✗ |
| 9 MEDIC | 野战维修车 | 75 | 80 | ✗ |
| 10 STEALTH | 渗透侦察型 | 115 | 50 | ✗ |
| 11 OMEGA_PLATFORM | 全装型机动舱 | 30 | 240 | ✗ |
| 12 COMMAND | 指挥车 | 0 | 150 | ✓ |

### A.4 `resources/design_tokens.gd` — 设计令牌

**色彩系统 (Neon Battle HUD):**
- `COLOR_BG`: 深空黑 (0.04, 0.07, 0.12)
- `COLOR_PANEL`: 面板 (0.15, 0.17, 0.25)
- `COLOR_TEXT`: 白色 (0.95, 0.95, 0.98)
- `COLOR_ACCENT_CYAN`: 霓虹青 (0, 0.94, 1)
- `COLOR_ACCENT_PURPLE`: 霓虹紫 (0.55, 0.35, 0.96)
- `COLOR_HEALTH`: 生命绿 (0.2, 0.9, 0.4)
- `COLOR_ENERGY`: 能量橙 (0.9, 0.6, 0.1)
- `COLOR_DANGER`: 危险红 (0.9, 0.2, 0.2)

**排版:** 12/16/20/32/48 五级字号
**间距:** 角半径6, 边框宽2, 内距8/16/24
**发光:** 强度0.8, 模糊8

### A.5 `resources/display_names.gd` — 显示名称翻译

覆盖范围:
- 环境标签: 天气(晴朗/降雨/风暴/迷雾)、地形(平原/城市/山地/森林)、能量场(常规场/高能场/纳米雾/虚空裂隙)、时段(白天/黄昏/夜晚)
- 单位类型: 步兵/载具/阵地/支援/航空/坦克/装甲/前线/后方/精英/头目/持续/快速/隐匿/反坦克
- 词条类型: 基础属性/战斗特性/特殊机制
- 稀有度: 普通/优秀/稀有/史诗/传说/神话
- 法则家族: 钢铁/烈焰/雷霆/虚空
- 资源: 纳米材料/合金/晶体/能量块/研究点
- 时代: 一战/二战/冷战/现代/近未来

### A.6 `resources/affix_resource.gd` — 词条资源

**词条属性:**
- affix_id, affix_name, description
- rarity: common/rare/epic/legendary
- level: 1-5
- is_mutated: 变异标记
- affix_type: base_property / combat_feature / special_mechanic
- effect_key: max_hp/attack_damage/crit_chance/lifesteal等
- card_type_filter: 0=PLATFORM, 1=WEAPON, 2=BOTH
- weapon_type_filter: 对应WeaponType, -1=全部

**等级加成系数:** Lv1=1.0, Lv2=1.25, Lv3=1.55, Lv4=1.95, Lv5=2.50

**稀有度倍率:** common=1.0, rare=1.3, epic=1.7, legendary=2.2

**平衡上限:** crit_chance≤35%, lifesteal≤25%, armor_penetration≤50%, splash_radius≤120px

### A.7 `resources/module_slot.gd` — 词条槽位 (v6.0)

替代旧AffixResource，每张卡最多5个词条槽（对应强化Lv10）。

- `module_id`: 词条ID (如 "module_crit")
- `level`: 1-3 (偶数级强化升级)
- `slot_index`: 0-4

效果查询委托给 `ModuleDefinitions`。

### A.8 `resources/weapon_resource.gd` — 武器槽位资源

**武器属性:**
- `weapon_id`, `display_name`, `weapon_label`
- `slot_type`: 0=轻装, 1=装甲, 2=对空
- `damage`, `attack_speed`, `windup`, `active`
- `weapon_type`: DIRECT(0)/INDIRECT(1)/AERIAL(2)
- `range_value`: 格
- `projectile_scene`, `hit_effect_scene`, `sound_id`

关键方法: `get_attack_cycle()`, `get_cooldown()`, `clone()`

### A.9 `resources/drop_tables.gd` — 掉落表系统

**DropType 枚举 (13种):** MATERIAL, CARD_DATA, DROPPED_CARD, LORE_PAGE, CARD_REWARD, ENERGY_CARD, STAT_BOOST, LAW_CARD, LAW_DATA, ENERGY_DATA, BLUEPRINT_FRAGMENT, LAW_BLUEPRINT, ENERGY_BLUEPRINT

**时代蓝图ID映射 (ERA_BLUEPRINT_IDS):**
- 一战 (18 IDs): ww1_mp18, ww1_mauser, ww1_enfield, ww1_mg08, ww1_vickers, ww1_m81, ww1_storm, ww1_rolls, ww1_ft17, ww1_saint, ww1_a7v, ww1_mark4, ww1_77mm, ww1_105mm, ww1_37mm, ww1_cavalry, ww1_flame, ww1_engineer
- 二战 (20 IDs): ww2_thompson, ww2_garand, ww2_mp40, ww2_ppsh, ww2_mg42, ww2_browning, ww2_panzerschrek, ww2_bazooka, ww2_m81, ww2_m120, ww2_pz3, ww2_pz4, ww2_panther, ww2_tiger, ww2_kingtiger, ww2_t34_76, ww2_t34_85, ww2_is2, ww2_sherman, ww2_hellcat
- 冷战 (21 IDs): cold_rpg, cold_ak47, cold_m14, cold_m60, cold_rpk, cold_btr60, cold_m113, cold_bmp1, cold_bradley, cold_t55, cold_t62, cold_t72, cold_m60t, cold_m1, cold_leo1, cold_chieftain, cold_zsu23, cold_sam7, cold_mig21, cold_f4, cold_spetsnaz
- 现代 (20 IDs): mod_marine, mod_ranger, mod_javelin, mod_stinger, mod_technical, mod_stryker_mgs, mod_stryker_m2, mod_hummer_tow, mod_hummer_m2, mod_m1a1, mod_m1a2, mod_m1a2sep, mod_t90, mod_leo2a6, mod_challenger2, mod_ah64, mod_ah1, mod_uh60, mod_m270, mod_m6
- 近未来 (20 IDs): fut_swarm, fut_scout_drone, fut_attack_drone, fut_cyborg, fut_heavy_trooper, fut_scout_mech, fut_assault_mech, fut_heavy_mech, fut_hovertank, fut_howitzer, fut_prism, fut_aa_hover, fut_stealth_bomber, fut_space_fighter, fut_spectre, fut_nano_drone, fut_shield, fut_colossus + 3

---

## B. 数据文件

### B.1 `data/default_cards.gd` — 默认战斗卡

**总计: 110+ 张战斗卡，每时代 20+ 张**

每张卡的参数结构: `(id, name, era, combat_kind, power, deploy_speed, range, energy_cost, hp, atk_l, atk_l_speed, atk_l_windup, atk_l_active, atk_a, atk_a_speed, atk_a_windup, atk_a_active, atk_air, atk_air_speed, atk_air_windup, atk_air_active, def_l, def_a, def_air, w_light, w_armor, w_air)`

#### 一战单位 (20个, Era 0)

| Card ID | 显示名称 | combat_kind | power | HP | 对轻装攻 | 对装甲攻 | 对空攻 | 防御(轻/装/空) |
|---------|----------|-------------|-------|-----|----------|----------|--------|----------------|
| ww1_mp18 | MP18突击班 | 0(轻装) | 15 | 100 | 35@1.5 | 0 | 0 | 8/5/3 |
| ww1_mauser | 毛瑟步枪班 | 0 | 15 | 95 | 30@0.67 | 0 | 0 | 8/5/3 |
| ww1_enfield | 李恩菲尔德班 | 0 | 15 | 95 | 30@0.83 | 0 | 0 | 8/5/3 |
| ww1_mg08 | MG08机枪巢 | 2(支援) | 23 | 90 | 45@2.0 | 0 | 75@6.0 | 12/8/10 |
| ww1_vickers | 维克斯机枪巢 | 2 | 23 | 85 | 40@1.8 | 0 | 66@6.0 | 12/8/10 |
| ww1_m81 | 81mm迫击炮组 | 2 | 23 | 70 | 120@2.0 | 60@2.0 | 0 | 6/5/3 |
| ww1_m76 | 76mm迫击炮组 | 2 | 23 | 65 | 114@2.0 | 54@2.0 | 0 | 6/5/3 |
| ww1_storm | 暴风突击队 | 0 | 20 | 110 | 40@1.5 | 5@0.67 | 0 | 10/6/4 |
| ww1_rolls | 罗尔斯装甲车 | 1(装甲) | 45 | 180 | 25@1.0 | 35@0.83 | 5@0.67 | 18/22/10 |
| ww1_lanchest | 兰彻斯特装甲车 | 1 | 45 | 170 | 22@1.0 | 32@0.83 | 8@0.67 | 18/22/10 |
| ww1_ft17 | FT-17轻型坦克 | 1 | 45 | 200 | 28@0.83 | 40@0.67 | 0 | 20/25/8 |
| ww1_saint | 圣沙蒙坦克 | 1 | 50 | 280 | 20@0.67 | 50@0.5 | 0 | 25/35/8 |
| ww1_a7v | A7V重型坦克 | 1 | 50 | 300 | 18@0.5 | 48@0.33 | 0 | 28/38/8 |
| ww1_mark4 | 马克IV型坦克 | 1 | 48 | 260 | 22@0.67 | 45@0.5 | 0 | 22/30/8 |
| ww1_77mm | 77mm野战炮 | 2 | 23 | 60 | 135@1.32 | 90@1.32 | 0 | 6/8/4 |
| ww1_105mm | 105mm榴弹炮 | 2 | 23 | 55 | 150@1.0 | 105@1.0 | 0 | 6/8/4 |
| ww1_37mm | 37mm高射炮 | 2 | 23 | 70 | 10@1.5 | 24@4.0 | 150@8.0 | 8/8/18 |
| ww1_cavalry | 骑兵斥候 | 0 | 15 | 85 | 20@1.0 | 0 | 0 | 6/4/2 |
| ww1_flame | 火焰喷射兵 | 0 | 18 | 100 | 45@1.0 | 15@0.5 | 0 | 8/5/3 |
| ww1_engineer | 工兵班 | 2 | 20 | 90 | 30@1.0 | 75@2.0 | 0 | 10/8/5 |

#### 二战单位 (20个, Era 1) — 选录

| Card ID | 显示名称 | combat_kind | power | HP |
|---------|----------|-------------|-------|-----|
| ww2_thompson | 汤普森班 | 0 | 60 | 140 |
| ww2_garand | 加兰德班 | 0 | 60 | 135 |
| ww2_pz3 | 三号坦克 | 1 | 180 | 350 |
| ww2_tiger | 虎式坦克 | 1 | 180 | 480 |
| ww2_kingtiger | 虎王坦克 | 1 | 180 | 550 |
| ww2_is2 | IS-2重型坦克 | 1 | 180 | 500 |
| ww2_sherman | M4谢尔曼 | 1 | 180 | 340 |

#### 冷战单位 (21个, Era 2) — 选录

| Card ID | 显示名称 | combat_kind | power | HP |
|---------|----------|-------------|-------|-----|
| cold_ak47 | AK-47步兵班 | 0 | 160 | 200 |
| cold_bmp1 | BMP-1步战车 | 1 | 480 | 600 |
| cold_t72 | T-72坦克 | 1 | 480 | 800 |
| cold_mig21 | 米格-21战机 | 3(空中) | 400 | 250 |
| cold_f4 | F-4鬼怪战机 | 3 | 400 | 280 |

#### 现代单位 (20个, Era 3) — 选录

| Card ID | 显示名称 | combat_kind | power | HP |
|---------|----------|-------------|-------|-----|
| mod_marine | 海军陆战队 | 0 | 320 | 300 |
| mod_m1a2sep | M1A2 SEP | 1 | 960 | 1250 |
| mod_ah64 | AH-64阿帕奇 | 3 | 800 | 350 |
| mod_m270 | M270火箭炮 | 2 | 480 | 250 |

#### 近未来单位 (20个, Era 4) — 选录

| Card ID | 显示名称 | combat_kind | power | HP |
|---------|----------|-------------|-------|-----|
| fut_cyborg | 机械步兵 | 0 | 500 | 400 |
| fut_hovertank | 悬浮坦克 | 1 | 1500 | 1300 |
| fut_heavy_mech | 重装机甲 | 1 | 1580 | 1800 |
| fut_colossus | 巨神机甲 | 1 | 1590 | 2000 |
| fut_shield | 力场发生器 | 2 | 750 | 500 |

### B.2 `data/enemy_archetypes.gd` — 敌人原型

**结构:** 每个原型包含 display_name, hp, speed, attack_damage, attack_range, attack_interval, weapon_type, tags, drops, era, swarm_unit, card_icon_path

**敌人类别 (UnitKind):** INFANTRY(步兵), VEHICLE(载具), TURRET(阵地), SUPPORT(支援)

**命名系统:** 每时代每兵种有独立的前缀/后缀名称库，生成有意义的中文敌人名

**视觉缩放:** 30+ 特定敌人有视觉缩放覆盖值 (如 `enemy_ww1_infantry_basic: 0.378`, `boss_ww2_kingtiger: 0.66`)

**数据源:** JSON文件 + GDScript子模块(_ArchWW, _ArchColdModern, _ArchFuture) + 运行时生成

### B.3 `data/enemy_blueprints.gd` — 敌人蓝图

**总量: 143** (平台54 + 武器89, 含特殊蓝图13 + 生成蓝图130)

**特殊蓝图 (6个命名敌方):**
- `bulwark` (盾卫装甲车, uncommon) — 正面减伤40%
- `titan_mk2` (马克V型·改, rare) — 超重装
- `storm_rider` (突击坦克·风暴型, rare) — 风暴增益
- `heavy_carrier` (重型载机母舰, rare) — 僚机强化
- `regen_frame` (野战维修车·改, uncommon) — 脱战回复
- `abrams_mk2` (艾布拉姆斯坦克·改, rare) — 野战修复

**生成蓝图 (按时代):**
- 每时代: 10个平台蓝图 + 16个武器蓝图 = 26个
- 命名格式: `bp_{era}_{序号}` (如 bp_ww1_001="铁壁 Mk.I 机动装甲")

### B.4 `data/unit_lineage_config.gd` — 进化链配置

**11条主线进化路线，47个节点:**

#### 轻装线 (combat_kind=0):
1. **普通步兵线 (5节):** ww1_mp18(15) → ww2_thompson(60) → cold_ak47(160) → mod_marine(320) → fut_cyborg(500)
2. **反坦克线 (4节):** ww2_panzerschrek(65) → cold_rpg(170) → mod_javelin(330) → fut_cyborg(500)
3. **特种线 (4节):** ww1_storm(20) → cold_spetsnaz(180) → mod_ranger(340) → fut_spectre(530)

#### 装甲线 (combat_kind=1):
4. **主战坦克线 (5节):** ww1_ft17(45) → ww2_pz3(180) → cold_t55(480) → mod_m1a1(950) → fut_hovertank(1500)
5. **重型坦克线 (5节):** ww1_saint(50) → ww2_tiger(180) → cold_t72(480) → mod_m1a2sep(960) → fut_heavy_mech(1580)

#### 空中线 (combat_kind=3):
6. **战斗机线 (3节):** cold_mig21(400) → mod_ah64(800) → fut_space_fighter(1325)
7. **攻击机线 (2节):** mod_ah1(780) → fut_attack_drone(1300)

#### 支援线 (combat_kind=2):
8. **火炮线 (5节):** ww1_m81(23) → ww2_m81(90) → cold_m113(240) → mod_m270(480) → fut_howitzer(795)
9. **防空线 (4节):** ww1_37mm(23) → cold_zsu23(240) → mod_m6(480) → fut_aa_hover(780)

#### 堡垒线 (combat_kind=4):
10. **防御线 (5节):** fort_ww1_pillbox → fort_ww2_bunker → fort_cold_missile → fort_modern_citadel → fort_future_ion
11. **防空线 (3节):** fort_ww2_flak → fort_modern_phalanx → fort_future_shield

**v6.0 进化条件:**
- E1 (基础): 强化≥Lv5, ≥2个MOD, 战力达标, 同类型
- E2 (势力分支): 强化≥Lv8, ≥5个MOD, 1个敌源MOD, 势力Lv3

**势力分支:** 7大势力(aether_dynamics, frontier_union, helix_recon, iron_wall_corp, nova_arms, quantum_logistics, void_research)各自可导向不同的终端进化目标

### B.5 `data/basic_resources.gd` — 基础资源

| 资源ID | 名称 | 用途 |
|--------|------|------|
| nano_materials | 纳米材料 | 基础制造 |
| alloy | 合金 | 装甲武器 |
| crystal | 晶体 | 高级装备 |
| energy_block | 能量块 | 后勤节点 |
| research_points | 研究点 | 卡牌升星 |
| permit_general | 改造许可函·通用 | 改造前置 |
| permit_type_assault | 改造许可函·突击型 | 突击改造 |
| permit_type_heavy | 改造许可函·重装型 | 重装改造 |
| permit_type_support | 改造许可函·支援型 | 支援改造 |
| permit_type_law | 改造许可函·法则型 | 法则改造 |

### B.6 `data/evolution_paths/` — 进化路径模块 (8个文件)

按兵种分类: infantry, armor, artillery, anti_air, air, recon, engineer, fort

每个模块提供: `get_main_line()`, `get_secondary_line()`, `get_hidden_branches()`

### B.7 `data/military_titles/` — 军衔系统

**统一军衔等级 (Lv1-Lv10):**

| 等级 | 战力倍率范围 | 强化消耗倍率 |
|------|-------------|-------------|
| Lv1 | 1.00-1.05 | 0.0 (免费) |
| Lv2 | 1.05-1.10 | 0.5 |
| Lv3 | 1.10-1.15 | 1.0 |
| Lv4 | 1.15-1.20 | 1.5 |
| Lv5 | 1.20-1.25 | 2.0 |
| Lv6 | 1.25-1.30 | 2.5 |
| Lv7 | 1.30-1.35 | 3.0 |
| Lv8 | 1.35-1.50 | 3.5 |
| Lv9 | 1.50-1.60 | 4.5 |
| Lv10 | 1.60-∞ | 6.0 |

### B.8 `data/modification_modules/` — 改造模块 (9个文件, 140+模块)

分类: infantry, armor, artillery, anti_air, air, recon, engineer, fort, universal

每个模块定义: mod_id, name, description, combat_kind_filter, card_id_filter, effects, conflict_group, tier, cost

### B.9 `data/json/` — JSON数据文件 (11个)

| 文件 | 用途 |
|------|------|
| company_store.json | 商店数据 |
| enemy_archetypes.json | 敌人原型 (schema_version 1) |
| enemy_phase_energy_cards.json | 相位师能量卡 |
| enemy_phase_equipment.json | 相位师装备 |
| enemy_phase_instruments.json | 相位师仪器 |
| enemy_phase_masters.json | 相位师配置 |
| enemy_phase_platforms.json | 相位师平台 |
| enemy_phase_weapons.json | 相位师武器 |
| quest_definitions.json | 任务定义 |
| task_definitions_extended.json | 扩展任务定义 |
| task_objective_types.json | 任务目标类型 |

---

## C. 管理器架构

### C.1 管理器清单 (43个文件)

#### 核心游戏流程
| 管理器 | 角色 | Autoload |
|--------|------|----------|
| `game_manager.gd` | 游戏流程: PRE_BATTLE→BATTLE→POST_BATTLE, 关卡管理, 相位师遭遇 | ✓ |
| `level_progress_manager.gd` | 关卡进度跟踪 | ✓ |

#### 卡牌与蓝图
| 管理器 | 角色 |
|--------|------|
| `blueprint_manager.gd` | 蓝图解锁/升星/成长/改造管理 |
| `card_collection_manager.gd` | 玩家卡牌收藏(背包) |
| `card_enhancement_manager.gd` | 卡牌强化(10级) |
| `card_ability_manager.gd` | 卡牌特殊能力 |

#### 战斗系统
| 管理器 | 角色 |
|--------|------|
| `energy_manager.gd` | 战斗能量管理 |
| `aura_manager.gd` | 光环效果系统 |
| `affix_manager.gd` | 词条生成/管理 |
| `affix_combat_handler.gd` | 词条战斗效果处理 |
| `battle_feedback_manager.gd` | 战斗反馈(飘字/特效) |
| `drop_manager.gd` | 掉落物管理 |

#### 法则系统
| 管理器 | 角色 |
|--------|------|
| `phase_law_manager.gd` | 法则装备/施放管理 |
| `phase_instrument_manager.gd` | 相位仪管理 |
| `phase_instrument_loadout_sync.gd` | 相位仪装备同步 |
| `active_law_effects.gd` | 主动法则效果处理 |

#### 势力与经济
| 管理器 | 角色 |
|--------|------|
| `faction_system_manager.gd` | 7大势力阵营系统 |
| `basic_resource_manager.gd` | 基础资源(纳米材料等) |
| `stat_boost_manager.gd` | 属性提升道具 |

#### 任务与进度
| 管理器 | 角色 |
|--------|------|
| `quest_manager.gd` | 任务系统 |
| `daily_task_manager.gd` | 日常任务 |
| `achievement_manager.gd` | 成就系统 |
| `story_manager.gd` | 剧情管理 |
| `tutorial_manager.gd` | 教程系统 |
| `tutorial_progression_manager.gd` | 教程进度 |

#### UI与体验
| 管理器 | 角色 |
|--------|------|
| `toast_manager.gd` | 提示消息 |
| `audio_manager.gd` | 音频管理 |
| `sound_generator.gd` | 音效生成 |
| `ui_lazy_loader.gd` | UI懒加载 |
| `performance_metrics_manager.gd` | 性能指标 |

#### 数据与存档
| 管理器 | 角色 |
|--------|------|
| `save_manager.gd` | 存档管理 |
| `statistics_manager.gd` | 统计数据 |
| `lore_manager.gd` | 世界观情报 |
| `intel_item_bag.gd` | 情报物品背包 |
| `character_manager.gd` | 角色管理 |
| `version_manager.gd` | 版本管理 |
| `leaderboard_manager.gd` | 排行榜 |

#### 系统与工具
| 管理器 | 角色 |
|--------|------|
| `object_pool.gd` | 对象池 |
| `lazy_init_helper.gd` | 延迟初始化 |
| `manager_lazy_loader.gd` | 管理器懒加载 |
| `new_systems_integration.gd` | 新系统集成 |
| `debug_log_manager.gd` | 调试日志 |

### C.2 GameManager 核心状态机

```gdscript
enum GamePhase { PRE_BATTLE, BATTLE, POST_BATTLE }
```

- `current_phase`: 当前游戏阶段
- `current_level`: 当前关卡 (1-100)
- `battle_scene`: 战斗场景引用
- `main_scene`: 主场景引用
- `last_battle_reward_summary`: 上次战斗奖励
- `_is_phase_master_battle`: 是否相位师战斗
- `_current_phase_master`: 当前相位师配置

---

## D. 主场景架构

### D.1 场景层级

```
Main (Control)
├── BattleContainer                    # 战斗SubViewport容器
├── HudLayer (CanvasLayer 40)          # 常驻HUD
│   ├── TopCenterMeta
│   │   └── LevelDisplay               # "第 N 关"
│   └── BattleBottomBar
│       ├── BottomInstrumentBar         # 相位仪/法则槽位
│       └── BottomFunctionBar           # 功能按钮栏
└── PopupLayer (CanvasLayer 100)        # 弹窗层
    ├── QuestOverlay
    ├── StoreOverlay
    ├── PhaseLawOverlay
    ├── BackpackOverlay
    ├── FactionOverlay
    ├── MapOverlay
    ├── SettingsOverlay
    ├── LeaderboardPanel (PopupPanel)
    ├── ManufactureOverlay             # 强化/制造
    ├── IntelligenceOverlay             # 情报中枢
    ├── GrowthOverlay                   # 成长
    ├── EnhancementOverlay              # 强化
    ├── ModificationOverlay             # 改造
    └── EvolutionOverlay                # 进化
```

### D.2 面板系统 (14个Overlay)

| 面板键名 | Overlay变量 | 快捷键 |
|----------|------------|--------|
| backpack | backpack_overlay | 1/B |
| progression | manufacture_overlay | 7 |
| quest | quest_overlay | 5/Q |
| store | store_overlay | 6/T |
| faction | faction_overlay | 4/F |
| map | map_overlay | — |
| settings | settings_overlay | 9 |
| leaderboard | leaderboard_panel | 8/L |
| info | intelligence_overlay | — |
| growth | growth_overlay | — |
| enhancement | enhancement_overlay | — |
| modification | modification_overlay | — |
| evolution | evolution_overlay | — |
| phase_law | phase_law_overlay | — |

### D.3 信号连接

**BottomInstrumentBar:**
- `instrument_area_clicked` → 打开相位仪选择
- `law_area_clicked` → 法则面板(已下线)
- `law_slot_clicked` → 主动法则施放模式
- `phase_level_label_clicked` → 相位仪等级选择

**BottomFunctionBar:**
- 11个按钮信号: backpack, progression, faction, quest, store, leaderboard, info, map, settings, save, start_battle, pause, back_to_title

**SignalBus 全局信号:**
- `blueprint_unlocked` → 蓝图解锁通知
- `active_law_cast_at` → 主动法则施放
- `battle_ended` → 战斗结束
- `player_deploy_failed` → 部署失败

### D.4 状态机流程

```
游戏启动 → _ready()
  ├── 注册到 GameManager
  ├── 连接信号
  ├── 初始化面板
  ├── 新手教程(如新游戏)
  └── 延迟初始化(非关键)

玩家操作:
  ESC → 关闭所有面板
  Space/Enter → 开始战斗
  数字键 → 快速打开面板

战斗中:
  Space → 暂停
```

### D.5 拆分模块

- `MainBattleSetup` — 战斗初始化逻辑
- `MainReward` — 战后奖励逻辑
- `ToastUtils` — 提示消息工具

---

## E. 战斗系统架构

### E.1 战斗脚本清单

| 文件 | class_name | 职责 |
|------|-----------|------|
| `scripts/battle/attack_calculator.gd` | AttackCalculator | 伤害计算 |
| `scripts/battle/target_selection.gd` | TargetSelection | 选敌逻辑 |
| `scripts/battle/construct_unit_ai.gd` | ConstructUnitAI | 单位AI/攻击 |
| `scripts/battle/damage_attenuation.gd` | DamageAttenuation | 射程衰减 |
| `scripts/battle/construct_unit_deploy.gd` | — | 部署逻辑 |
| `scripts/battle/module_effect_handler.gd` | ModuleEffectHandler | 改造效果 |
| `scripts/battle_input_state.gd` | BattleInputState | 输入状态 |
| `scripts/battle_performance_monitor.gd` | — | 性能监控 |
| `scripts/card_grid_damage.gd` | — | 格子战术伤害 |

### E.2 伤害计算流程 (AttackCalculator)

```
1. 获取攻击值 = 按目标类型选择
   轻装→attack_light, 装甲→attack_armor, 空中→attack_air, 支援→attack_light, 堡垒→attack_armor

2. 击穿检查: attack ≤ defense → 伤害=0
   防御值按武器类型穿透: 直射→defense_light, 曲射→defense_armor, 空射→defense_air

3. 射程衰减 (仅直射)
   衰减因子: SMG=0.6, RIFLE=0.4, MG=0.5, TANK=0.3, AT=0.2, SNIPER=0.1
   公式: 1.0 - (超出比例 × 因子)

4. 防御减免: damage × 100/(100+def)

5. 强化加成:
   Lv1-8: 1.0 + level × 0.05
   Lv9: 1.50
   Lv10: 1.60

6. 改造加成: 累乘 attack_multiplier
```

### E.3 攻击状态机 (三阶段)

```
IDLE → (目标在射程内) → WINDUP → (windup时间到) → ACTIVE → (触发do_attack) → COOLDOWN → (冷却到) → IDLE
```

每个武器独立维护状态机（多武器单位）。

### E.4 选敌逻辑 (TargetSelection)

**三种模式:**

| 武器类型 | 选敌规则 |
|----------|----------|
| DIRECT (直射) | 距离最近 → 同距最低HP → 同距同HP最早部署 |
| INDIRECT (曲射) | 优先被克制类型 → 无克制则最近 |
| AERIAL (空射) | 优先空中 → 无空中则克制目标 → 最近 |

**克制优先级:** 攻击最高维度 → 对应类型优先
- attack_light最高 → 优先轻装
- attack_armor最高 → 优先装甲
- attack_air最高 → 优先空中

### E.5 弹道路由规则

```
曲射/空射武器 → MultiMesh 批处理(抛物线弹道)
直射 + 射速 > 2发/秒 → MultiMesh 批处理
直射 + 射速 ≤ 2发/秒 → 独立子弹节点(对象池)
霰弹(wt=5) → 多枚子弹(6发), 伤害均分
```

### E.6 目标查找优化

- 优先使用空间分区系统 (BattleManager.spatial_grid)
- 自适应查找间隔: 敌人>55→0.55s, >35→0.42s, 否则0.3s
- 回退: SceneTree.get_nodes_in_group() + 距离排序

### E.7 相位场系统

- 战斗双方各有相位场
- 所有对方战斗单位死亡后，自动切换为攻击对方相位场
- 相位场被摧毁 = 战败

### E.8 胜利/失败条件

- **胜利:** 摧毁敌方相位场
- **失败:** 己方相位场被摧毁
- **额外奖励:** 3星胜利获得额外掉落和情报加成(+10%)

---

## F. 卡牌系统架构

### F.1 CardResource 结构

**核心字段:**
- `card_id`: 唯一ID (如 "ww1_mp18")
- `display_name`: 显示名称 (如 "MP18突击班")
- `card_type`: 0=战斗卡, 1=能量卡, 2=法则卡
- `era`: 0-4 (时代)
- `combat_kind`: 0=轻装, 1=装甲, 2=支援, 3=空中, 4=堡垒
- `power`: 基础战力值
- `rarity`: 稀有度
- `energy_cost`: 部署费用
- `base_hp`, `base_speed`: 基础属性
- `attack_light/armor/air`: 三维攻击
- `attack_light_speed/armor_speed/air_speed`: 三维攻速
- `attack_light_windup/armor_windup/air_windup`: 前摇
- `attack_light_active/armor_active/air_active`: 动作时间
- `defense_light/armor/air`: 三维防御
- `range_value`: 射程(格)
- `deploy_speed`: 部署速度
- `weapon_type`: 攻击方式(直射/曲射/空射/辅助)
- `weapon_names[3]`: 三把武器名称
- `weapon_slots: Array[WeaponResource]`: 武器槽位
- `module_slots: Array[ModuleSlot]`: 词条槽位
- `mods: Array`: 已装配改造ID
- `enhance_level`: 强化等级(0-10)
- `type_line`, `summary_line`, `description`, `flavor_text`: 描述文本

### F.2 卡牌获取方式

1. **初始解锁:** 一战单位默认解锁
2. **蓝图掉落:** 击败敌人获得 blueprint_fragment → 研究 → 解锁
3. **战斗掉落:** 稀有蓝图碎片
4. **商店购买:** company_store.json
5. **进化产出:** 从低级单位进化获得高级单位
6. **缴获系统:** captured_unit_cards.gd

### F.3 卡牌强化 (Enhancement, Lv1-Lv10)

- 管理器: `CardEnhancementManager`
- 资源消耗: 纳米材料 + 研究点 (随等级递增)
- 词条系统: 每2级解锁1个词条槽 (最高5个, Lv10全属性加成)
- 军衔系统: 根据战力倍率动态计算 (UnifiedRankSystem)
- Lv10解锁全属性加成 (ModuleDefinitions.apply_level10_bonus)

### F.4 卡牌改造 (Modification, MOD系统)

- 管理器: `BlueprintManager` (改造部分)
- 改造模块: 140+, 按8个兵种分类
- 安装条件: 改造许可函 (permit_general/permit_type_*)
- 冲突系统: conflict_group 同组不可共存
- 敌源MOD: 从敌人缴获的特殊改造 (v6.0, D槽)
- 效果应用: ModificationRegistry.apply_to_weapon_slots()

### F.5 卡牌进化 (Evolution)

- 管理器: `BlueprintManager` (进化部分)
- 11条主线 + 7势力分支
- 基础进化(E1): 强化≥Lv5, ≥2个MOD, 同类型, 战力达标
- 势力分支(E2): 强化≥Lv8, ≥5个MOD, 1个敌源MOD, 势力≥Lv3
- 进化规则: 改造完全继承, 强化重置(enhance_level=0)
- 终端单位: fut_cyborg, fut_spectre, fut_hovertank, fut_heavy_mech等

### F.6 法则卡系统

- **四大法则家族:** 钢铁(STEEL), 烈焰(FLAME), 雷霆(THUNDER), 虚空(VOID)
- **两种类型:** 被动(passive) + 主动(active)
- **目标阵营:** 友方(ALLY), 敌方(ENEMY), 双方(BOTH)
- **目标类型:** 全部(ALL), 载具(VEHICLE), 步兵(INFANTRY), 阵地(TURRET), 航空(AIRCRAFT)
- 管理器: `PhaseLawManager`
- 新游戏初始: 2主动 + 2被动 + 50知识值

---

## 附录: 势力阵营系统

| 势力ID | 名称 | 法则映射 |
|--------|------|----------|
| aether_dynamics | 苍穹动力 | steel |
| frontier_union | 边境联盟 | thunder |
| void_research | 虚空研究所 | void |
| iron_wall_corp | 铁壁集团 | steel |
| nova_arms | 新星军火 | flame |
| helix_recon | 螺旋侦察 | thunder |
| quantum_logistics | 量子后勤 | steel |

## 附录: 文件结构总览

```
phase-war/
├── resources/         # 游戏资源定义 (9文件)
├── data/              # 游戏数据 (40+文件)
│   ├── default_cards.gd
│   ├── enemy_archetypes.gd
│   ├── enemy_blueprints.gd
│   ├── unit_lineage_config.gd
│   ├── basic_resources.gd
│   ├── evolution_paths/     (8文件)
│   ├── military_titles/    (3文件)
│   ├── modification_modules/ (10文件)
│   └── json/               (11文件)
├── managers/          # 管理器 (43文件)
├── scenes/            # 场景文件
│   ├── main.gd        (主界面, 812行)
│   └── units/bullet.tscn
├── scripts/           # 游戏脚本
│   ├── battle/        (6文件)
│   ├── systems/       (main_battle_setup, main_reward)
│   ├── combat_targeting.gd
│   ├── combat_feedback.gd
│   └── card_grid_damage.gd
├── assets/            # 美术资源
├── addons/            # 插件 (GDUnit4, godot-mcp)
├── tools/             # 工具脚本
└── test/              # 测试
```

---

*文档结束 — 由 Easy Code AI 自动分析生成*
