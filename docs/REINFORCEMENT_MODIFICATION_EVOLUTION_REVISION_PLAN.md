# 强化改造与进化系统修订计划

**文档版本**: v1.0
**创建日期**: 2026-06-01
**基于文档**: 重新构建强化改造与进化20260601.md
**状态**: Proposed

---

## 执行摘要

将现有的通用强化/改造系统（火力改造、射程改造等）重构为基于真实军事历史的设计。核心改进：
- 强化等级使用真实军衔替代数字（Lv1-Lv10 → 征召兵-战斗大师）
- 改造模块使用真实军事技术名称（穿甲弹、光学瞄准镜、复合装甲等）
- 进化路径映射真实武器代差（MP18→汤普森→AK-47→M16→机械步兵）
- 所有效果精确映射到现有9字段攻击防御体系

---

## 一、现有系统分析

### 1.1 当前强化系统位置

```
managers/
  blueprint_manager.gd          # 强化、升星、改造入口
  blueprint_star_config.gd       # 强化等级消耗
  data/
    affix_definitions.gd          # 词条定义（15个）
    battle_card_v3.gd            # 时代倍率
    level_eras.gd                # 级别-时代映射
resources/
  card_resource.gd               # 卡牌数据模型
  affix_resource.gd              # 词条资源
```

### 1.2 当前改造系统（需要替换）

| 当前名称 | 问题 | 替换为 |
|---------|-----|--------|
| 火力改造 | 无代入感 | 突击步枪化、穿甲弹、滑膛炮等 |
| 射程改造 | 无代入感 | 光学瞄准镜、膛线强化等 |
| 装甲改造 | 无代入感 | 复合装甲、防弹插板等 |
| 机动改造 | 无代入感 | 涡扇发动机、燃气轮机等 |
| 防空改造 | 无代入感 | 相控阵雷达、炮瞄雷达等 |

### 1.3 可重用的现有机制

- ✅ 9字段攻击防御体系已存在（`attack_light/attack_armor/attack_air`）
- ✅ 词条系统框架完整（15个词条）
- ✅ 槽位系统（9槽）已实现
- ✅ 冲突组机制已存在（可用于弹药类型、光学设备等）
- ✅ 时代系统（WW1/WW2/冷战/现代/近未来）已映射
- ✅ 稀有度系统（common-rare-epic-legendary）已存在

---

## 二、核心机制澄清（已确认）

### 2.1 军衔计算逻辑
- **军衔不由等级决定，而是由当前战力（Power）动态计算**
- 玩家看到的是："当前战力XXX → 军衔称号YYY"
- 同一张卡牌，随着强化/改造提升战力，军衔会自动晋升

**计算公式**：
```gdscript
# 战力 → 军衔等级映射（示例，需平衡调整）
func get_rank_by_power(power: int, base_power: int) -> int:
    var ratio = float(power) / float(base_power)
    if ratio < 1.05: return 1  # 征召兵
    elif ratio < 1.15: return 2 # 合格步兵
    elif ratio < 1.30: return 3 # 老兵
    # ... Lv1-Lv10
    else: return 10  # 战斗大师
```

### 2.2 进化机制
- **改造保留到新卡牌**（不是继承加成）
- 卡牌ID变为新卡牌
- 源卡牌从背包移除

**进化流程**：
```
旧卡牌（ww1_mp18）
  ├─ 强化等级：Lv5
  ├─ 已安装改造：[inf_02, inf_07, inf_11]
  ├─ 当前战力：180
  └─ 军衔：士官（基于180战力）

     ↓ 进化（满足条件：Lv5 + 2改造 + 情报≥50% + 战力≥目标×0.8）

新卡牌（ww2_thompson）
  ├─ 强化等级：Lv5（继承）
  ├─ 已安装改造：[inf_02, inf_07, inf_11]（完整保留）
  ├─ 当前战力：240（新卡牌基础更高）
  └─ 军衔：精锐（基于240战力自动晋升）
```

### 2.3 改造与进化条件
- **战力门槛**：当前战力必须 ≥ 目标卡牌基础战力 × 系数
- **情报维度**：目标卡牌的情报进度（基础/战术/机密/素材）

---

## 三、数据结构重构方案

### 3.1 新增数据文件

```
data/
  military_titles/               # 新增：军事称号数据
    __init__.gd
    infantry_titles.gd          # 步兵军衔（征召兵→战斗大师）
    armor_titles.gd              # 装甲兵军衔（装填手→钢铁战神）
    artillery_titles.gd         # 炮兵军衔（炮手→钢铁风暴）
    anti_air_titles.gd           # 防空兵军衔（测距手→苍穹之盾）
    air_titles.gd                # 航空兵军衔（飞行学员→天空传奇）
    recon_titles.gd              # 侦察兵军衔（侦察兵→战场之眼）
    engineer_titles.gd           # 工程兵军衔（学徒工→战场建筑师）
    fort_titles.gd               # 要塞兵军衔（要塞兵→不落要塞）

  modification_modules/         # 新增：改造模块数据
    __init__.gd
    infantry_mods.gd            # 22个步兵改造
    armor_mods.gd               # 15个装甲改造
    artillery_mods.gd           # 12个炮兵改造
    anti_air_mods.gd            # 12个防空改造
    air_mods.gd                 # 14个空中改造
    recon_mods.gd              # 12个侦察改造
    engineer_mods.gd             # 10个工程改造
    fort_mods.gd                # 10个堡垒改造
    universal_mods.gd           # 10个通用改造

  evolution_paths/              # 新增：进化路径数据
    __init__.gd
    infantry_evolution.gd       # 步兵进化（主线+3隐藏分支）
    armor_evolution.gd         # 装甲进化（2主线+隐藏）
    artillery_evolution.gd      # 炮兵进化
    anti_air_evolution.gd       # 防空进化
    air_evolution.gd            # 空中进化
    recon_evolution.gd          # 侦察进化
    engineer_evolution.gd       # 工程进化
    fort_evolution.gd           # 堡垒进化
```

### 3.2 改造模块数据结构

```gdscript
# data/modification_modules/infantry_mods.gd
extends RefCounted
class_name InfantryModifications

# 改造ID常量
const INF_01_SUBMACHINE_GUN = "inf_01_submachine_gun"
const INF_02_ASSAULT_RIFLE = "inf_02_assault_rifle"
# ... 共22个

# 改造数据表
static var DATA: Dictionary = {
    INF_01_SUBMACHINE_GUN = {
        id = INF_01_SUBMACHINE_GUN,
        name = "冲锋枪改装",
        name_en = "Submachine Gun Conversion",
        prototype = "MP18/汤普森",
        description = "缩短枪管+大容量弹鼓，提升近战压制能力",
        icon = "res://textures/icons/mods/inf_01_submachine_gun.png",
        rarity = "rare",
        cost_research = 100,  # 研究点消耗
        cost_install = 50,   # 安装消耗
        slot_type = "weapon", # weapon/armor/special/universal
        conflict_group = "fire_rate", # 同组不可共存
        effects = {
            attack_interval = -0.15,  # -15%
        },
        unlock_conditions = {
            required_level = 1,
            required_card_id = "",  # 空表示通用
        }
    },
    INF_05_AP_AMMO = {
        id = INF_05_AP_AMMO,
        name = "穿甲弹",
        name_en = "Armor-Piercing Ammunition",
        prototype = "M993钨芯弹",
        description = "钨芯穿透弹头，专为应对现代复合装甲设计",
        icon = "res://textures/icons/mods/inf_05_ap_ammo.png",
        rarity = "epic",
        cost_research = 200,
        cost_install = 100,
        slot_type = "ammunition",
        conflict_group = "ammunition",
        effects = {
            attack_armor = 0.25,    # +25%
            attack_light = -0.10,   # -10% 副作用
        },
        unlock_conditions = {
            required_level = 3,
        }
    },
    # ... 其余19个
}

# 兵种过滤器
static func get_for_unit_type(unit_type: int) -> Array:
    """返回特定兵种可用的改造ID列表"""
    match unit_type:
        GameConstants.CombatKind.LIGHT:
            return DATA.keys()
        _:
            return []
```

### 2.3 军衔系统数据结构

```gdscript
# data/military_titles/infantry_titles.gd
extends RefCounted
class_name InfantryMilitaryTitles

const TITLES: Dictionary = {
    1 = {  # 强化等级
        name = "征召兵",
        name_en = "Conscript",
        description = "完成基础训练，配发标准装备",
        power_multiplier = 1.00,
        cost_multiplier = 0.0,  # 首次强化无消耗
    },
    2 = {
        name = "合格步兵",
        name_en = "Qualified Infantry",
        description = "通过战术考核，熟悉班组配合",
        power_multiplier = 1.05,
        cost_multiplier = 0.5,
    },
    3 = {
        name = "老兵",
        name_en = "Veteran",
        description = "经历过实战，战场直觉形成",
        power_multiplier = 1.10,
        cost_multiplier = 1.0,
    },
    # ... Lv4-Lv10
    10 = {
        name = "战斗大师",
        name_en = "Combat Master",
        description = "超越常规军衔的战场传说",
        power_multiplier = 1.60,
        cost_multiplier = 6.0,
    }
}

static func get_title(level: int) -> Dictionary:
    return TITLES.get(level, TITLES[1])

static func get_name(level: int) -> String:
    return get_title(level).name
```

---

## 三、核心系统修改清单

### 3.1 CardResource 变更（基于新理解）

```gdscript
# resources/card_resource.gd 变更

# 军衔系统（动态计算，无需存储）
# ❌ 删除：var military_title_key: String
# ❌ 删除：var display_level: int
# ✅ 新增函数：get_military_rank() -> String  # 动态计算军衔称号

# 改造记录（新结构）
var installed_modifications: Array = []  # 存储改造ID
# [
#   {
#     "id": "inf_05_ap_ammo",
#     "installed_at": time,
#   }
# ]

# 进化相关（新增，用于追溯）
var original_card_id: String = ""       # 记录最初卡牌ID（用于统计）
var evolution_history: Array = []      # 进化历史记录
# [
#   {
#     "from_id": "ww1_mp18",
#     "to_id": "ww2_thompson",
#     "at_time": 1234567890,
#     "preserved_mods": ["inf_02", "inf_07", "inf_11"]
#   }
# ]
```

### 3.2 军衔计算函数（新增到CardResource）

```gdscript
# resources/card_resource.gd 新增方法

func get_current_power() -> int:
    """获取当前战力（基础属性 + 强化 + 改造加成）"""
    var base_power = power  # 基础战力
    var level_bonus = get_level_bonus()
    var mod_bonus = get_modifications_bonus()
    return int(base_power * level_bonus) + mod_bonus

func get_military_rank() -> Dictionary:
    """根据战力动态计算军衔"""
    var current_power = get_current_power()
    var base_power = power
    var ratio = float(current_power) / float(base_power)

    var rank_level = MilitaryTitleRegistry.get_rank_by_ratio(ratio)
    var unit_type = combat_kind  # LIGHT/ARMOR/SUPPORT/AIR/FORT
    var title_info = MilitaryTitleRegistry.get_title(unit_type, rank_level)

    return {
        level = rank_level,      # 1-10
        name = title_info.name,  # "征召兵"、"士官"等
        ratio = ratio            # 当前战力/基础战力
    }
```

### 3.3 BlueprintManager 接口变更

```gdscript
# managers/blueprint_manager.gd 修改

# 旧接口（标记为废弃）
# func apply_upgrade_modification(card: CardResource, mod_type: String, slot: int)

# 新接口
func apply_reinforcement(card: CardResource, target_level: int) -> Dictionary:
    """
    强化卡牌到指定等级
    现在会设置对应的军事称号
    """
    var titles = MilitaryTitleRegistry.get_for_card(card)
    var title_data = titles.get(target_level)
    # ... 实现逻辑

func install_modification(card: CardResource, mod_id: String, slot: int) -> Dictionary:
    """
    安装改造模块
    使用新的改造ID系统
    """
    var mod_data = ModificationRegistry.get_data(mod_id)
    # 检查冲突组
    # 检查槽位类型
    # 应用效果

func get_available_modifications(card: CardResource) -> Array:
    """
    返回卡牌可用的改造列表
    根据兵种、时代、等级过滤
    """

func check_evolution_requirements(card: CardResource, target_card_id: String) -> Dictionary:
    """
    检查进化条件
    - 强化等级
    - 改造数量
    - EOM需求
    - 情报需求
    - 战力门槛
    """
```

### 3.3 新增注册表系统

```gdscript
# scripts/systems/modification_registry.gd (新文件)
extends Node

class_name ModificationRegistry

# 改造数据缓存
static var _cache: Dictionary = {}

static func register_all() -> void:
    """注册所有改造模块"""
    _cache.clear()
    _register_modifications(InfantryModifications.DATA, "infantry")
    _register_modifications(ArmorModifications.DATA, "armor")
    # ...

static func get_data(mod_id: String) -> Dictionary:
    """获取改造数据"""
    # 解析ID前缀获取兵种类型
    var prefix = mod_id.split("_")[0]  # "inf", "arm", "art"...
    var type = _prefix_to_type(prefix)
    return _cache.get(type, {}).get(mod_id, {})

static func get_for_unit_type(unit_type: int) -> Array:
    """获取特定兵种的所有改造"""
    var type_key = _combat_kind_to_key(unit_type)
    return _cache.get(type_key, {}).keys()

static func check_conflict(card: CardResource, mod_id: String) -> bool:
    """检查改造冲突"""
    var mod_data = get_data(mod_id)
    var conflict_group = mod_data.get("conflict_group", "")

    if conflict_group.is_empty():
        return false  # 无冲突

    for installed in card.installed_modifications:
        var installed_mod = get_data(installed.id)
        if installed_mod.get("conflict_group", "") == conflict_group:
            return true  # 冲突

    return false
```

---

## 四、UI系统变更

### 4.1 强化界面更新

```
scenes/ui/
  reinforce_panel.gd           # 修改

# 变更点：
# - 显示军事称号而非数字等级
# - 添加历史注记展示区域
# - 显示战力倍率变化
# - 消耗显示（纳米材料+手册）
```

UI文案示例：
```
┌─────────────────────────────────────────┐
│  📈 强化：老兵 → 精锐                    │
│                                         │
│  📜 历史注记：                           │
│  "精锐是连队尖子，可担任火力组长..."     │
│                                         │
│  📊 战力提升：1.10× → 1.15×             │
│  🛡️ 属性加成：HP +5% / 防御 +4%         │
│                                         │
│  🔧 消耗纳米：450                        │
│  📘 消耗手册：强化手册 ×1                │
│                                         │
│  [取消]                    [晋升]       │
└─────────────────────────────────────────┘
```

### 4.2 改造界面更新

```
scenes/ui/
  modification_panel.gd        # 新增或重构

# 功能：
# - 按兵种显示可用改造
# - 显示军事原型和历史背景
# - 冲突组可视化
# - 词条激活提示
# - 预览效果（9字段属性变化）
```

### 4.3 进化界面更新

```
scenes/ui/
  evolution_panel.gd           # 新增

# 功能：
# - 显示进化路径树（主线+隐藏分支）
# - 进化条件检查清单
# - 继承率预览
# - 属性对比
```

---

## 五、实施阶段划分

### 阶段1：数据层搭建（第1-2周）

**目标**：建立新的数据结构，不影响现有系统

- [ ] 创建 `data/military_titles/` 目录和8个军衔文件
- [ ] 创建 `data/modification_modules/` 目录和8个改造文件
- [ ] 创建 `data/evolution_paths/` 目录和8个进化文件
- [ ] 编写数据验证脚本（检查ID唯一性、冲突组完整性）
- [ ] 编写单元测试（GdUnit）
- [ ] **里程碑**：所有140+个改造模块数据录入完成

**交付物**：
- `tests/unit/data/military_titles_test.gd`
- `tests/unit/data/modification_modules_test.gd`
- 数据完整性报告

### 阶段2：注册表系统（第3周）

**目标**：实现改造/军衔/进化注册表

- [ ] 实现 `ModificationRegistry`
- [ ] 实现 `MilitaryTitleRegistry`
- [ ] 实现 `EvolutionPathRegistry`
- [ ] 集成到 `ManagerLazyLoader`
- [ ] 编写单元测试
- [ ] **里程碑**：可通过注册表查询所有数据

**交付物**：
- `scripts/systems/modification_registry.gd`
- `scripts/systems/military_title_registry.gd`
- `scripts/systems/evolution_path_registry.gd`

### 阶段3：核心逻辑迁移（第4-5周）

**目标**：修改BlueprintManager，接入新系统

- [ ] 标记旧接口为废弃（@deprecated）
- [ ] 实现新的强化接口（军事称号）
- [ ] 实现新的改造接口（改造ID）
- [ ] 实现进化检查接口
- [ ] 修改属性计算逻辑（整合改造效果）
- [ ] 向下兼容处理（旧数据迁移）
- [ ] 编写集成测试
- [ ] **里程碑**：新系统可独立运行

**交付物**：
- 修改后的 `managers/blueprint_manager.gd`
- `scripts/systems/save_migration.gd` (v3→v4)
- `tests/integration/blueprint_modification_test.gd`

### 阶段4：UI系统更新（第6-7周）

**目标**：更新所有相关UI面板

- [ ] 更新强化界面（`reinforce_panel.gd`）
- [ ] 创建/更新改造界面（`modification_panel.gd`）
- [ ] 创建进化界面（`evolution_panel.gd`）
- [ ] 更新背包界面显示
- [ ] 添加改造预览工具提示
- [ ] 添加词条激活提示动画
- [ ] **里程碑**：所有UI显示新数据

**交付物**：
- 修改后的UI脚本和场景文件
- UI本地化文本文件（中英双语）

### 阶段5：测试与调优（第8周）

**目标**：全面测试、性能优化

- [ ] GdUnit全量测试通过
- [ ] 战斗平衡性测试
- [ ] 改造组合测试
- [ ] 进化路径测试
- [ ] 性能基准测试
- [ ] **里程碑**：系统就绪，可发布

**交付物**：
- 测试报告
- 性能分析报告
- 已知的待优化事项清单

---

## 六、数据迁移策略

### 6.1 保存格式变更（v3→v4）

```json
// 旧格式（v3）
{
  "blueprint": {
    "card_id": "ww1_mp18",
    "level": 5,
    "star": 3,
    "mods": ["fire_damage", "range_upgrade"]
  }
}

// 新格式（v4）
{
  "blueprint": {
    "card_id": "ww1_mp18",
    "level": 5,
    "military_title": "士官",        // 新增
    "star": 3,
    "mods": [                         // 结构变更
      {
        "id": "inf_05_ap_ammo",       // 新ID系统
        "installed_at": 1234567890
      }
    ],
    "evolution_stage": 0,             // 新增
    "evolution_path": "main"          // 新增
  }
}
```

### 6.2 迁移逻辑

```gdscript
# scripts/systems/save_migration.gd (v3→v4)

static func _migrate_blueprint_v3_to_v4(old_data: Dictionary) -> Dictionary:
    var new_data = old_data.duplicate()

    # 迁移军衔显示
    if new_data.has("level"):
        var card = DefaultCards.get_card(new_data.card_id)
        var title_key = _get_title_key_for_card(card)
        new_data.military_title = MilitaryTitleRegistry.get_name(title_key, new_data.level)

    # 迁移改造（旧→新映射）
    var mod_map = _get_legacy_mod_mapping()
    var new_mods = []
    for old_mod in new_data.mods:
        if mod_map.has(old_mod):
            new_mods.append({
                id = mod_map[old_mod],
                installed_at = Time.get_unix_time_from_system()
            })
    new_data.mods = new_mods

    return new_data

# 旧改造→新改造映射表
static func _get_legacy_mod_mapping() -> Dictionary:
    return {
        "fire_damage": "inf_02_assault_rifle",
        "range_upgrade": "inf_07_optical_scope",
        "armor_upgrade": "inf_11_armor_insert",
        "mobility_upgrade": "inf_16_exoskeleton",
        # ... 完整映射
    }
```

---

## 七、待澄清问题

### 7.1 设计决策待确认

| 问题 | 选项A | 选项B | 已确认 |
|-----|-------|-------|--------|
| 旧卡牌如何处理？ | 保留旧系统，仅新卡牌使用新系统 | ✅ **强制迁移所有卡牌** | ✅ 强制迁移 |
| 改造槽位数量 | 按兵种差异化（步兵9槽，装甲7槽） | ✅ **统一9槽** | ✅ 统一9槽 |
| 军衔系统 | 每个兵种独立军衔 | ✅ **跨兵种统一等级系统，不同称号** | ✅ 跨兵种统一 |
| 隐藏分支解锁方式 | 仅情报驱动 | 情报+成就双重条件 | ❓ |
| 改造可拆卸性 | 不可拆卸（永久） | ✅ **进化后继承，新改造可在新槽或替换旧改造** | ✅ 进化继承 |

### 7.2 技术实现待确认

| 问题 | 详情 | 待确认 |
|-----|-----|--------|
| 数据文件格式 | 纯GDScript vs JSON vs .tres | ❓ |
| 图标资源 | 是否需要140+个新图标？ | ❓ |
| 本地化 | 是否需要英文名？ | ❓ |
| 性能 | 改造效果计算频率（每帧 vs 每次） | ❓ |

---

## 八、风险评估

### 高风险项

1. **数据迁移复杂度**：旧玩家数据迁移可能出错
   - 缓解措施：全面测试、回滚机制、备份机制

2. **UI工作量**：多个界面需要重绘
   - 缓解措施：分阶段迭代、复用现有组件

3. **平衡性调整**：新数值可能导致战力失衡
   - 缓解措施：保留旧数值参考、分步调整

### 中风险项

1. **性能影响**：改造效果计算增加CPU负担
   - 缓解措施：缓存计算结果、延迟计算

2. **向后兼容**：旧模组/第三方代码可能失效
   - 缓解措施：保持旧接口存续、发布迁移指南

---

## 九、成功标准

### 9.1 功能性指标

- ✅ 8个兵种完整数据录入（140+改造）
- ✅ 强化等级显示军事称号
- ✅ 改造名称显示真实军事技术
- ✅ 进化路径按真实武器代差
- ✅ 所有改造效果映射到9字段体系
- ✅ 数据迁移成功率 > 99.9%

### 9.2 质量性指标

- ✅ GdUnit单元测试覆盖率 > 80%
- ✅ 性能基准测试通过（60fps稳定）
- ✅ 无崩溃、无数据损坏
- ✅ UI显示正确无错别字

### 9.3 体验性指标

- ✅ 玩家能理解改造含义（无需查看说明）
- ✅ 进化路径清晰可见
- ✅ 军事历史爱好者有共鸣

---

## 十、附录

### 10.1 改造ID命名规范

```
格式: [前缀]_[序号]_[英文标识]

前缀映射:
- inf: 步兵 (Infantry)
- arm: 装甲兵 (Armor)
- art: 炮兵 (Artillery)
- aa:  防空兵 (Anti-Air)
- air: 空中单位 (Air)
- rec: 侦察/特种 (Recon)
- eng: 工程 (Engineer)
- for: 堡垒 (Fortress)
- gen: 通用 (General)

示例:
- inf_01_submachine_gun
- arm_03_reactive_armor
- art_06_fire_control_computer
```

### 10.2 参考文档

- 原始设计文档：`重新构建强化改造与进化20260601.md`
- 现有系统架构：`CLAUDE.md`
- 数据结构参考：`resources/card_resource.gd`
- 词条系统参考：`data/affix_definitions.gd`

### 10.3 术语表

| 术语 | 定义 |
|-----|-----|
| 强化等级 | Lv1-Lv10，对应军事称号 |
| 改造模块 | 安装在槽位的属性增强器 |
| 冲突组 | 同组改造不可共存（如弹药类型） |
| EOM | Evolution-Only Modification，进化专属改造 |
| 情报维度 | Intel系统的4个维度（基础、战术、机密、素材） |
| 继承率 | 进化后保留属性百分比 |
| 9字段体系 | attack_light/armor/air + defense_light/armor/air |

---

**文档维护**：本计划应在实施过程中持续更新
**下一步行动**：等待用户确认后进入阶段1实施
