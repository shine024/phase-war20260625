# Phase War (相位战争：构装纪元) - 项目完整说明文档

> **版本**: 1.0  
> **最后更新**: 2026-06-07  
> **引擎**: Godot 4.5  
> **语言**: GDScript  
> **分辨率**: 1280×720, 60fps

---

## 目录

1. [项目概述](#1-项目概述)
2. [技术栈](#2-技术栈)
3. [项目架构](#3-项目架构)
4. [核心系统详解](#4-核心系统详解)
5. [游戏机制](#5-游戏机制)
6. [数据结构](#6-数据结构)
7. [UI系统](#7-ui系统)
8. [战斗系统](#8-战斗系统)
9. [存档系统](#9-存档系统)
10. [开发指南](#10-开发指南)
11. [测试框架](#11-测试框架)
12. [文件结构](#12-文件结构)
13. [配置说明](#13-配置说明)

---

## 1. 项目概述

### 1.1 游戏简介

**Phase War (相位战争：构装纪元)** 是一款基于 Godot 4.5 的 **横版自动对战策略游戏**。

- **核心玩法**: 玩家通过装配构装卡（平台、武器、能量、法则）定义自动作战的武器平台，在保护己方相位场核心的前提下击败敌人
- **时代跨度**: 从一战到近未来的5个时代，共100关卡
- **自动战斗**: 单位自动移动和开火，侧重战前构筑与资源/法则时机管理

### 1.2 世界观设定

- **题材**: 硬核军事装备感与科幻元素并存
- **时代**: 一战 → 二战 → 冷战 → 现代 → 近未来
- **核心概念**: 相位仪、构装卡、相位法则、相位场驱动器

### 1.3 游戏循环

```
战前准备（背包管理+相位仪装配）
    ↓
进入战斗（自动对战+资源管理）
    ↓
胜负结算（资源奖励+成长）
    ↓
回到准备/继续推进关卡
```

---

## 2. 技术栈

### 2.1 核心技术

| 技术 | 版本 | 用途 |
|------|------|------|
| **Godot Engine** | 4.5 | 游戏引擎 |
| **GDScript** | - | 主要脚本语言 |
| **GL Compatibility** | - | 渲染驱动（跨平台兼容） |
| **GdUnit4** | - | 单元测试框架 |

### 2.2 项目配置

- **分辨率**: 1280×720
- **帧率上限**: 60fps
- **入口场景**: `res://scenes/title_screen.tscn`
- **主场景**: `res://scenes/main.tscn`
- **渲染模式**: `gl_compatibility`

### 2.3 自动加载单例（26个）

```
1.  SignalBus               - 全局信号总线（80+信号）
2.  BattleInputState        - 战斗输入状态
3.  EnergyManager           - 战斗能量系统
4.  PhaseInstrumentManager  - 相位仪装备系统
5.  BattleManager          - 战斗流程管理
6.  GameManager            - 游戏流程控制
7.  BlueprintManager       - 蓝图系统
8.  DropManager            - 掉落系统
9.  SaveManager            - 存档系统
10. AudioManager          - 音频管理
11. PhaseLawManager       - 法则系统
12. BasicResourceManager  - 基础资源管理
13. ObjectPoolManager     - 对象池
14. UILazyLoader          - UI懒加载
15. ManagerLazyLoader     - 管理器懒加载
16. PerformanceMetricsManager - 性能监控
17. IntelManual           - 情报手册系统（v6.0）
18. IntelItemBag          - 情报道具背包（v6.0）
19. IntelDiscoveryManager - 情报发现系统（v6.0）
20. EnemyOriginModManager - 敌源改造管理（v6.0）
21. IntelEvolutionManager - 情报进化系统（v6.0）
22. ModificationRegistry  - 改造模块注册
23. MilitaryTitleRegistry - 军衔系统
24. EvolutionPathRegistry - 进化路径注册
25. CardEnhancementManager - 卡牌强化
26. AffixManager          - 词条系统
```

---

## 3. 项目架构

### 3.1 架构原则

1. **信号解耦**: 所有跨系统通信通过 SignalBus
2. **数据驱动**: 游戏数据为静态类，无JSON/CSV文件
3. **懒加载**: UI和非核心管理器按需加载
4. **单一职责**: 每个管理器专注单一领域

### 3.2 依赖关系图

```
GameManager
    ├── BattleManager
    │   ├── BattleSpawnSystem
    │   ├── BattleDamageSystem
    │   ├── EnergyManager
    │   └── ObjectPoolManager
    ├── BlueprintManager
    ├── PhaseInstrumentManager
    ├── PhaseLawManager
    ├── BasicResourceManager
    └── DropManager

SaveManager
    └── [所有管理器] (保存/加载)
```

### 3.3 信号总线

SignalBus 提供80+信号，涵盖：

| 分类 | 信号数量 | 示例 |
|------|----------|------|
| **能量** | 2 | `energy_changed`, `energy_insufficient` |
| **相位仪** | 4 | `card_equipped`, `phase_slots_changed` |
| **战斗** | 4 | `battle_started`, `battle_ended` |
| **单位** | 5 | `unit_spawned`, `unit_died` |
| **蓝图** | 3 | `blueprint_unlocked`, `blueprint_star_upgraded` |
| **成就** | 3 | `achievement_unlocked`, `milestone_reached` |
| **势力** | 5 | `faction_reputation_changed`, `faction_level_up` |
| **情报** | 3 | `intel_updated`, `intel_unlocked` |

---

## 4. 核心系统详解

### 4.1 GameManager（游戏管理器）

**职责**: 游戏流程控制（准备→战斗→战后）

```gdscript
enum GamePhase {
    PRE_BATTLE,    # 准备阶段
    BATTLE,        # 战斗阶段
    POST_BATTLE    # 战后结算
}
```

**关键功能**:
- `go_to_battle()`: 进入战斗
- `check_phase_master_encounter()`: 检查相位师遭遇（15%概率）
- `_grant_basic_resources_for_current_level()`: 发放关卡奖励
- `_grant_phase_master_victory_reward()`: 相位师战胜奖励

### 4.2 BattleManager（战斗管理器）

**职责**: 战斗流程控制、胜负判定、刷新管理

**子系统**:
- `BattleSpawnSystem`: 敌我单位刷新
- `BattleDamageSystem`: 伤害计算与掉落处理

**关键功能**:
```gdscript
start_battle(battle_scene)     # 开始战斗
end_battle(player_won)          # 结束战斗
check_win_lose()                 # 检查胜负
recount_enemy_units_on_field()   # 重新计数敌人
```

**胜负条件**:
- **胜利**: 所有波次刷完 + 场上无敌方单位
- **失败**: 相位场驱动器被摧毁

### 4.3 BlueprintManager（蓝图管理器）

**职责**: 蓝图解锁、碎片管理、星星升级

**数据结构**:
```gdscript
_blueprints: Dictionary = {
    card_id: {
        "unlocked": bool,
        "stars": int,           # 0-5星
        "fragments": int,       # 当前碎片
        "modifications": Array,  # 已安装改造
        "inherit_bonus": float   # 继承加成
    }
}
```

**关键功能**:
- `unlock_blueprint(card_id)`: 解锁蓝图
- `add_fragments(card_id, count)`: 添加碎片
- `upgrade_star(card_id)`: 升星
- `get_blueprint_copies(card_id)`: 获取复制数

### 4.4 PhaseInstrumentManager（相位仪管理器）

**职责**: 相位仪槽位管理、能量计算

**槽位结构**:
```gdscript
_slots: Array[4] = [
    {card_id, card_type, energy_cost, ...},
    {card_id, card_type, energy_cost, ...},
    {card_id, card_type, energy_cost, ...},
    {card_id, card_type, energy_cost, ...}
]
```

**能量计算**:
```gdscript
初始能量 = 基础(10) + Σenergy_start_*
每秒回复 = Σenergy_regen_* - 基础消耗(0.5)
```

### 4.5 DropManager（掉落管理器）

**职责**: 掉落表管理、掉落计算、奖励领取

**掉落类型**（13种）:
1. 蓝图碎片
2. 纳米材料
3. 能量块
4. 合金
5. 水晶
6. 改造模块
7. 进化材料
8. 关键道具
9. 情报道具
10. 法则碎片
11. 经验值
12. 声望值
13. 特殊奖励

---

## 5. 游戏机制

### 5.1 战前准备

**背包卡牌类型**:

| 类型 | 说明 | 示例 |
|------|------|------|
| **平台卡** | 决定单位底盘、血量、移速 | 威克斯侦察车、马克V型重型坦克 |
| **武器卡** | 决定伤害、射程、攻速 | MP18冲锋枪、马克沁机枪 |
| **战前能量卡** | 增加开局能量 | 战前能量 I ~ VII |
| **能量收集卡** | 增加战斗中能量回复 | 能量收集 I ~ VII |
| **即时能量卡** | 背包中点击立刻获得能量 | 即时能量 |
| **合成卡** | 平台+武器组合 | 突击坦克·合成 |

**相位仪槽位**:
- 4个槽位，可拖入卡牌
- 装备消耗准备阶段能量
- 平台+武器组合构成前线构装

### 5.2 战斗阶段

**单位刷新规则**:
```
我方:
- 每10秒从已装备组合中随机生成
- 场上单位上限: 5

敌方:
- 按关卡配置波次刷新
- 波次数与时代相关
- 波次间隔与关卡相关
```

**自动战斗**:
- 双方相向移动
- 进入射程后自动攻击
- 攻速分离计算（每目标独立攻速）

**能量系统**:
```
基础自然回复: +1⚡/秒
相位仪消耗: -0.5⚡/秒
净回复 = Σregen_cards - 0.5
```

### 5.3 战后结算

**胜利奖励**:
1. 基础资源（纳米材料、能量块等）
2. 蓝图碎片（战斗中敌人死亡掉落）
3. 纳米材料（用于解析蓝图）
4. 关卡进度推进
5. 势力声望（如有）

**相位师战胜额外奖励**:
- 额外纳米材料（+50）
- 额外能量块（+10）
- 敌方平台卡缴获
- 势力法则卡（随机3条）
- 势力声望（+30）

---

## 6. 数据结构

### 6.1 CardResource（卡牌资源）

**核心属性**:
```gdscript
card_id: String              # 卡牌ID
card_type: CardType         # 类型(PLATFORM/WEAPON/ENERGY/LAW)
display_name: String         # 显示名称
era: Era                     # 时代(0-4)
combat_kind: CombatKind     # 战斗类型
platform_type: PlatformType # 平台类型

# 战斗属性
hp: int                     # 生命值
move_speed: float           # 移速
attack_light: float         # 对轻装伤害
attack_armor: float         # 对装甲伤害
attack_air: float           # 对空伤害
defense_light: float        # 对轻装防御
defense_armor: float        # 对装甲防御
defense_air: float          # 对空防御

# 每目标攻速(v5.0)
attack_light_speed: float   # 对轻装攻速
attack_armor_speed: float   # 对装甲攻速
attack_air_speed: float     # 对空攻速

# 攻击时机
attack_light_windup: float  # 对轻装前摇
attack_armor_windup: float  # 对装甲前摇
attack_air_windup: float   # 对空前摇
attack_light_active: float  # 对轻装 active
attack_armor_active: float # 对装甲 active
attack_air_active: float   # 对空 active
```

### 6.2 UnitStats（单位属性）

**来源**: `UnitStatsTable.build_stats_from_card()`

**时代缩放**:
```gdscript
# 一战基准
hp_mult = 1.0
dmg_mult = 1.0

# 时代加成
era0(一战): 1.0, 1.0
era1(二战): 1.4, 1.6
era2(冷战): 1.8, 2.2
era3(现代): 2.2, 2.8
era4(未来): 2.6, 3.4
```

### 6.3 时代与关卡

**LevelEras数据**:
```gdscript
# 每时代20关 (1-100)
era0: 关卡1-20   (一战)
era1: 关卡21-40  (二战)
era2: 关卡41-60  (冷战)
era3: 关卡61-80  (现代)
era4: 关卡81-100 (近未来)

# 每关参数
wave_total: int          # 总波次数
spawn_count_per_wave: int # 每波单位数
wave_interval: float      # 波次间隔
drop_rate_multiplier: float # 掉落倍率
```

---

## 7. UI系统

### 7.1 UI懒加载（UILazyLoader）

**按需加载的UI面板**（30+）:

| 面板ID | 节点名 | 说明 |
|--------|--------|------|
| `backpack` | BackpackPanel | 背包面板 |
| `phase_instrument` | PhaseInstrumentPanel | 相位仪面板 |
| `store` | StorePanel | 商店面板 |
| `upgrade` | UpgradePanel | 升级面板 |
| `battle_result` | BattleResultPanel | 战斗结果 |
| `faction` | FactionPanel | 势力面板 |
| `achievement` | AchievementPanel | 成就面板 |
| `manufacture` | ManufacturePanel | 制造面板 |
| `evolution` | EvolutionPanel | 进化面板 |
| `affix` | AffixPanel | 词条面板 |
| `modification` | ModificationPanel | 改造面板 |
| `reinforcement` | ReinforcementPanel | 强化面板 |
| `card_enhancement` | CardEnhancementPanel | 卡牌强化 |
| `intelligence_hub` | IntelligenceHubPanel | 情报中心 |
| `leaderboard` | LeaderboardPanel | 排行榜 |

### 7.2 主要场景

| 场景 | 路径 | 说明 |
|------|------|------|
| **标题屏** | `scenes/title_screen.tscn` | 游戏入口 |
| **主场景** | `scenes/main.tscn` | 战斗+UI容器 |
| **战场** | `scenes/battlefield/battlefield.tscn` | 战斗渲染 |

### 7.3 UI图层

```
Main
├── BattleContainer (战斗场景)
├── HudLayer (CanvasLayer 40)
│   ├── BattleHud
│   ├── ResourceBar
│   └── ...
└── PopupLayer (CanvasLayer 100)
    ├── BackpackOverlay
    ├── BattleResultDialog
    └── ...
```

---

## 8. 战斗系统

### 8.1 伤害计算（AttackCalculator）

**完整公式**:
```gdscript
# 1. 根据目标类型选择攻击值
base_damage = get_attack_vs(attacker_stats, target_combat_kind)

# 2. 击穿检查
if base_damage <= defense:
    return 0.0

# 3. 射程衰减 (仅直射)
if weapon_type == DIRECT:
    base_damage *= calculate_attenuation(distance, max_range, sub_type)

# 4. 防御减免
final_damage = base_damage * (100.0 / (100.0 + defense))

# 5. 强化加成
if enhance_level > 0:
    enhance_mult = 1.0 + level * 0.05  # Lv1-8
    if level >= 9: enhance_mult = 1.50  # Lv9
    if level >= 10: enhance_mult = 1.60 # Lv10
    final_damage *= enhance_mult

# 6. 改造加成
final_damage *= get_mod_damage_multiplier(mods, target_combat_kind)
```

### 8.2 攻速计算（v5.0）

**每目标独立攻速**:
```gdscript
# 攻速参数
speed: float      # 攻击频率（次/秒）
windup: float     # 前摇时间
active: float     # active窗口

# 计算
cycle = 1.0 / speed
cooldown = maxf(0.0, cycle - windup - active)

# 状态机
PRE_WINDUP → WINDUP → ACTIVE → COOLDOWN → PRE_WINDUP
```

### 8.3 词条系统（Affix）

**词条效果**:
- 生命: `hp_percent`, `hp_flat`
- 移速: `move_speed_percent`, `move_speed_flat`
- 伤害: `damage_percent`, `damage_flat`
- 射程: `range_percent`, `range_flat`
- 攻速: `attack_speed_percent`
- 减伤: `damage_reduction_percent`
- 暴击: `crit_chance`, `crit_damage`
- 吸血: `life_steal_percent`
- 溅射: `splash_damage`, `splash_radius`

**词条稀有度**:
```
COMMON (1级) → UNCOMMON (3级) → RARE (5级) → EPIC (7级) → LEGENDARY (9级)
```

---

## 9. 存档系统

### 9.1 存档结构

**文件**: `user://save.json`（3存档位支持）

**Schema版本**: 5

**数据结构**:
```json
{
  "schema_version": 5,
  "blueprint": {...},
  "basic_resources": {...},
  "phase_law": {...},
  "quest": {...},
  "faction_system": {...},
  "affix_data": {...},
  "level_progress": {...},
  "drop_manager": {...},
  "intel_item_bag": {...},
  "game": {
    "current_level": 1
  },
  "phase_slots": [...],
  "phase_instrument": {...},
  "backpack_extra_ids": [...]
}
```

### 9.2 存档流程

**保存**:
```
1. 收集各管理器状态
2. 数据清洗（inf/-inf/nan修复）
3. JSON序列化
4. 原子写入（先写.tmp再rename）
5. 自动备份（每15秒）
```

**加载**:
```
1. 多路径查找（slot→backup→legacy）
2. JSON解析
3. 数据迁移（v1→v2→v3→v4→v5）
4. 关键管理器同步加载
5. 延迟管理器分批加载
```

### 9.3 管理器加载顺序

**关键管理器**（立即加载）:
1. BlueprintManager
2. PhaseInstrumentManager
3. PhaseLawManager
4. QuestManager
5. BasicResourceManager
6. FactionSystemManager
7. AffixManager
8. LevelProgressManager
9. DropManager
10. IntelItemBag

**延迟管理器**（分批加载，每批5个）:
- LoreManager, StatBoostManager, AchievementManager
- DailyTaskManager, StatisticsManager, CardEnhancementManager
- TutorialProgressionManager, StoryManager, CharacterManager
- ChallengeModeManager, CardCollectionManager, LeaderboardManager

---

## 10. 开发指南

### 10.1 运行项目

**方法1: Godot编辑器**
```
1. 打开 Godot 4.5
2. 打开项目根目录
3. 按F5运行
```

**方法2: 命令行**
```bash
# Windows
"E:\下载\Godot_4.41\Godot_v4.5-stable_win64.exe" --path "D:/godotplay/godot fair duel/phase-war"

# 带渲染驱动指定
"E:\下载\Godot_4.41\Godot_v4.5-stable_win64.exe" --rendering-driver opengl3 --path "."
```

### 10.2 语法检查

```bash
# 无UI模式语法检查
"E:\下载\Godot_4.41\Godot_v4.5-stable_win64.exe" --headless --rendering-driver opengl3 --path "." --check-only
```

### 10.3 测试运行

```bash
# 快速烟雾测试
"E:\下载\Godot_4.41\Godot_v4.5-stable_win64.exe" --headless --rendering-driver opengl3 --path "." --script "tests/star_config_smoke.gd"

# 完整测试套件
"E:\下载\Godot_4.41\Godot_v4.5-stable_win64.exe" --headless --rendering-driver opengl3 --path "." --script "tests/gdunit4_runner.gd"
```

### 10.4 代码规范

**命名约定**:
- 类名: `PascalCase` (例: `CardResource`)
- 函数名: `snake_case` (例: `get_card_by_id`)
- 常量: `UPPER_SNAKE_CASE` (例: `MAX_HP`)
- 私有变量: `_snake_case` (例: `_cached_data`)

**注释风格**:
```gdscript
## 简短功能描述
## 可选: 详细说明
func function_name():
    pass
```

### 10.5 信号连接

**安全连接模式**:
```gdscript
# 检查信号是否存在
if SignalBus and SignalBus.has_signal("signal_name"):
    if not SignalBus.signal_name.is_connected(callback):
        SignalBus.signal_name.connect(callback)
```

---

## 11. 测试框架

### 11.1 GdUnit4

**目录**: `addons/gdunit4/`

**测试目录结构**:
```
tests/
├── unit/
│   ├── blueprint/      # 蓝图系统测试
│   ├── combat/         # 战斗计算测试
│   ├── data/           # 数据验证测试
│   ├── economy/        # 经济系统测试
│   ├── energy/         # 能量系统测试
│   ├── progression/    # 进度系统测试
│   ├── resources/      # 资源管理测试
│   └── save/          # 存档系统测试
├── star_config_smoke.gd       # 快速烟雾测试
├── syntax_check.gd             # 语法验证
└── gdunit4_runner.gd          # CI测试入口
```

### 11.2 测试编写

**示例**:
```gdscript
extends GdUnitTestSuite

func test_blueprint_upgrade():
    # Given
    var card_id = "smg"
    BlueprintManager.unlock_blueprint(card_id)
    var initial_stars = BlueprintManager.get_blueprint_stars(card_id)
    
    # When
    BlueprintManager.upgrade_star(card_id)
    
    # Then
    assert_int(BlueprintManager.get_blueprint_stars(card_id)).is_equal(initial_stars + 1)
```

---

## 12. 文件结构

### 12.1 核心目录

```
phase-war/
├── scenes/              # 场景文件
│   ├── main.tscn        # 主场景
│   ├── title_screen.tscn # 标题屏
│   ├── battlefield/     # 战场相关
│   ├── units/          # 单位场景
│   ├── ui/             # UI场景（60+）
│   └── effects/        # 特效场景
├── scripts/            # 脚本文件
│   ├── signal_bus.gd   # 信号总线
│   ├── battle/         # 战斗脚本
│   ├── systems/        # 系统脚本
│   └── utils/          # 工具脚本
├── managers/          # 管理器
│   ├── battle/        # 战斗管理器
│   ├── faction/       # 势力系统
│   ├── evolution/     # 进化系统
│   └── synthesis/     # 合成系统
├── data/             # 数据定义（静态类）
│   ├── default_cards.gd       # 默认卡牌
│   ├── enemy_archetypes.gd    # 敌人原型
│   ├── phase_laws.gd          # 相位法则
│   ├── level_eras.gd          # 关卡时代
│   ├── modification_modules/  # 改造模块
│   └── evolution_paths/       # 进化路径
├── resources/        # 资源定义
│   ├── card_resource.gd      # 卡牌资源类
│   ├── game_constants.gd      # 游戏常量
│   ├── drop_tables.gd         # 掉落表
│   └── game_config.gd         # 游戏配置
├── tests/            # 测试文件
├── addons/           # 插件
│   ├── gdunit4/      # 测试框架
│   └── godot-mcp/    # MCP支持
└── docs/             # 文档
```

### 12.2 数据文件统计

| 类型 | 数量 | 说明 |
|------|------|------|
| 默认卡牌 | 110+ | 涵盖5时代 |
| 敌人原型 | 50+ | 按时代分类 |
| 相位法则 | 40+ | 4大家族 |
| 改造模块 | 140+ | 9种单位类型 |
| 进化路径 | 8条 | 主线+隐藏分支 |
| 敌源改造 | 9个 | v6.0新增 |

---

## 13. 配置说明

### 13.1 游戏配置（GameConfig）

**战斗配置**:
```gdscript
first_wave_delay: 3.0秒           # 第一波延迟
default_enemy_wave_interval: 12秒  # 波次间隔
player_deploy_cooldown: 1.0秒     # 部署冷却
```

**数值平衡**:
```gdscript
nano_bonus_base: 5                # 纳米基础奖励
nano_bonus_per_level: 2            # 每级额外纳米
blueprint_drop_chance_base: 0.15   # 蓝图掉落基础概率
```

**相位师配置**:
```gdscript
phase_master_encounter_chance: 0.15  # 遭遇概率
phase_master_boss_level: 49           # BOSS关卡
```

### 13.2 性能配置

**对象池**:
```gdscript
bullets: 初始2个, 最大100个
damage_numbers: 初始4个, 最大40个
```

**节流缓存**:
```gdscript
GROUP_TARGET_CACHE_INTERVAL: 0.28秒  # 目标查找缓存
```

### 13.3 显示配置

**分辨率**: 1280×720  
**拉伸模式**: `canvas_items`  
**渲染方法**: `gl_compatibility`

---

## 附录A: 时代对照表

| 时代 | 关卡范围 | 时代ID | 典型单位 |
|------|----------|--------|----------|
| 一战 | 1-20 | 0 | MP18突击班、FT-17坦克 |
| 二战 | 21-40 | 1 | 汤普森班、虎式坦克 |
| 冷战 | 41-60 | 2 | AK-47班、T-72坦克 |
| 现代 | 61-80 | 3 | M14班、M1坦克 |
| 近未来 | 81-100 | 4 | 光束步枪、粒子炮 |

---

## 附录B: 战斗类型对照

| CombatKind | 平台类型示例 | 武器类型示例 |
|------------|--------------|--------------|
| LIGHT (0) | 步兵、侦察车 | 冲锋枪、步枪 |
| ARMOR (1) | 坦克、装甲车 | 反坦克火箭、火炮 |
| AIR (2) | 战机、直升机 | 防空炮、导弹 |
| SUPPORT (3) | 维修车、补给车 | 机枪、迫击炮 |
| FORT (4) | 火炮阵地、要塞 | 火炮、导弹 |

---

## 附录C: 相位法则家族

| 家族 | 代表法则 | 效果类型 |
|------|----------|----------|
| STEEL (钢铁) | 钢铁·相位装甲、堡垒之墙 | 防御、护盾 |
| FLAME (烈焰) | 热能过载、前线火力压制 | 灼烧、伤害 |
| THUNDER (雷霆) | 电磁风暴、链式放电 | EMP、连锁 |
| VOID (虚空) | 时空涟漪、护盾转移 | 时间、控制 |

---

## 附录D: 改造模块类型

| 单位类型 | 模块文件 | 模块数量 |
|----------|----------|----------|
| 步兵 | `infantry_mods.gd` | 20+ |
| 装甲 | `armor_mods.gd` | 20+ |
| 火炮 | `artillery_mods.gd` | 15+ |
| 防空 | `anti_air_mods.gd` | 10+ |
| 空中 | `air_mods.gd` | 15+ |
| 侦察 | `recon_mods.gd` | 10+ |
| 工程 | `engineer_mods.gd` | 10+ |
| 堡垒 | `fort_mods.gd` | 15+ |
| 通用 | `universal_mods.gd` | 25+ |

---

## 附录E: 资源类型

| 资源ID | 名称 | 用途 |
|--------|------|------|
| 0 | 纳米材料 | 蓝图解析 |
| 1 | 合金 | 制造 |
| 2 | 水晶 | 制造 |
| 3 | 能量块 | 特殊操作 |
| 4 | 研究点 | 法则研究 |
| 5 | 许可 | 高级操作 |

---

## 附录F: 快速命令参考

```bash
# 运行游戏
godot --path "D:/godotplay/godot fair duel/phase-war"

# 语法检查
godot --headless --rendering-driver opengl3 --path "." --check-only

# 单元测试
godot --headless --rendering-driver opengl3 --path "." --script "tests/gdunit4_runner.gd"

# 导出项目
godot --headless --export-release "Windows Desktop" "phase-war.exe"
```

---

**文档维护**: 本文档应随项目更新而维护。如有重大变更，请及时更新相关章节。

**最后更新**: 2026-06-07  
**文档版本**: 1.0
