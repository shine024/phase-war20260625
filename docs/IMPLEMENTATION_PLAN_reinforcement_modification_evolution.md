# 强化、改造与进化系统修订实施计划

> **文档版本**：v1.0  
> **创建日期**：2026-06-01  
> **参考文档**：`重新构建强化改造与进化20260601.md`  
> **适用引擎**：Godot 4.5 / GDScript

---

## 一、修订目标

将文档《重新构建强化改造与进化20260601.md》中的设计方案集成到现有游戏系统，实现：

1. **真实军衔强化系统**：Lv1-Lv10 映射到真实军事称号（征召兵→战斗大师）
2. **历史武器改造模块**：140+ 改造模块，每个对应真实军事技术
3. **完整进化路径**：主线+隐藏分支，基于情报解锁

---

## 二、现有系统分析

### 2.1 现有组件

| 组件 | 路径 | 职责 | 需要修订的内容 |
|------|------|------|----------------|
| BlueprintManager | `managers/blueprint_manager.gd` | 蓝图星级、副本管理 | 添加军衔称号映射、强化效果文案 |
| ModManager | `managers/evolution/mod_manager.gd` | 改造系统 | 添加兵种专属改造模块、冲突组 |
| CardEvolutionManager | `managers/evolution/card_evolution_manager.gd` | 进化系统 | 添加隐藏分支、情报门禁 |
| IntelEvolutionManager | `scripts/systems/intel_evolution_manager.gd` | 情报进化 | 添加情报驱动进化条件 |
| BlueprintStarConfig | `data/blueprint_star_config.gd` | 星级配置 | 添加军衔称号表 |
| ModEffects | `data/mod_effects.gd` | 改造效果 | 添加兵种专属改造定义 |

### 2.2 现有数据结构

```gdscript
# BlueprintManager 当前状态
- blueprint_stars: Dictionary = {}  # 卡牌ID → 星级
- blueprint_copies: Dictionary = {}  # 卡牌ID → 副本数
- blueprint_mods: Dictionary = {}   # 卡牌ID → 已装改造列表
- blueprint_inherit_bonus: Dictionary = {}  # 继承加成
```

---

## 三、修订计划

### 阶段一：强化等级军衔化（优先级：高）

#### 1.1 新增数据文件

**文件**：`data/unit_rank_titles.gd`

```gdscript
extends RefCounted
## 强化等级军衔称号表
## 为 BlueprintManager 提供真实军事称号映射

const RANK_TITLES_BY_COMBAT_KIND: Dictionary = {
    # 步兵/轻装兵 (LIGHT)
    0: {  # LIGHT
        1: {"id": "conscript", "name": "征召兵", "name_en": "Conscript", "desc": "完成基础训练，配发标准装备"},
        2: {"id": "qualified", "name": "合格步兵", "name_en": "Qualified Infantry", "desc": "通过战术考核，熟悉班组配合"},
        3: {"id": "veteran", "name": "老兵", "name_en": "Veteran", "desc": "经历过实战，战场直觉形成"},
        4: {"id": "elite", "name": "精锐", "name_en": "Elite", "desc": "连队尖子，可担任火力组长"},
        5: {"id": "sergeant", "name": "士官", "name_en": "Sergeant", "desc": "获得军士军衔，领导一个火力组"},
        6: {"id": "battle_veteran", "name": "战斗老兵", "name_en": "Battle Veteran", "desc": "多次实战部署，全战术精通"},
        7: {"id": "sergeant_major_3", "name": "三级军士长", "name_en": "Sgt.Major 3rd", "desc": "可训练新兵，担任排士官长"},
        8: {"id": "sergeant_major_2", "name": "二级军士长", "name_en": "Sgt.Major 2nd", "desc": "营级特等射手/战斗教官"},
        9: {"id": "sergeant_major_1", "name": "一级军士长", "name_en": "Sgt.Major 1st", "desc": "军士长中的军士长"},
        10: {"id": "battle_master", "name": "战斗大师", "name_en": "Battle Master", "desc": "超越常规军衔的战场传说"},
    },
    # 装甲兵 (ARMOR)
    1: {
        1: {"id": "loader", "name": "装填手", "name_en": "Loader", "desc": "基础训练，弹药管理"},
        2: {"id": "driver", "name": "驾驶员", "name_en": "Driver", "desc": "机动操作，地形适应"},
        3: {"id": "gunner", "name": "炮手", "name_en": "Gunner", "desc": "火控系统，瞄准打击"},
        4: {"id": "commander", "name": "车长", "name_en": "Commander", "desc": "车组指挥，战术决策"},
        5: {"id": "platoon_leader", "name": "排长", "name_en": "Platoon Leader", "desc": "领导三车组"},
        6: {"id": "company_leader", "name": "连长", "name_en": "Company Leader", "desc": "连级战术指挥"},
        7: {"id": "battalion_leader", "name": "营长", "name_en": "Battalion Leader", "desc": "营级作战协调"},
        8: {"id": "armor_director", "name": "装甲兵总监", "name_en": "Armor Director", "desc": "装甲部队总监"},
        9: {"id": "armor_general", "name": "装甲兵上将", "name_en": "Armor General", "desc": "装甲兵种最高军衔"},
        10: {"id": "steel_god", "name": "钢铁战神", "name_en": "Steel God", "desc": "传说中的装甲指挥官"},
    },
    # 支援兵 (SUPPORT) - 炮兵/防空/工程
    2: {
        1: {"id": "gunner_basic", "name": "炮手", "name_en": "Gunner", "desc": "基础火炮操作"},
        2: {"id": "aimer", "name": "瞄准手", "name_en": "Aimer", "desc": "精确瞄准技术"},
        3: {"id": "squad_leader", "name": "炮班长", "name_en": "Squad Leader", "desc": "炮组指挥"},
        4: {"id": "fire_director", "name": "射击指挥官", "name_en": "Fire Director", "desc": "火力协调指挥"},
        5: {"id": "platoon_leader_art", "name": "炮兵排长", "name_en": "Platoon Leader", "desc": "排级炮兵指挥"},
        6: {"id": "company_leader_art", "name": "炮兵连长", "name_en": "Company Leader", "desc": "连级火力指挥"},
        7: {"id": "battalion_leader_art", "name": "炮兵营长", "name_en": "Battalion Leader", "desc": "营级炮击指挥"},
        8: {"id": "fire_master", "name": "射击大师", "name_en": "Fire Master", "desc": "炮击技术专家"},
        9: {"id": "artillery_commander", "name": "炮兵司令", "name_en": "Artillery Commander", "desc": "炮兵兵种最高军衔"},
        10: {"id": "steel_storm", "name": "钢铁风暴", "name_en": "Steel Storm", "desc": "传说中的火力大师"},
    },
    # 空中兵 (AIR)
    3: {
        1: {"id": "flight_cadet", "name": "飞行学员", "name_en": "Flight Cadet", "desc": "基础飞行训练"},
        2: {"id": "pilot", "name": "飞行员", "name_en": "Pilot", "desc": "合格飞行员"},
        3: {"id": "pilot_3rd", "name": "三级飞行员", "name_en": "Pilot 3rd Class", "desc": "中级飞行员"},
        4: {"id": "pilot_2nd", "name": "二级飞行员", "name_en": "Pilot 2nd Class", "desc": "高级飞行员"},
        5: {"id": "pilot_1st", "name": "一级飞行员", "name_en": "Pilot 1st Class", "desc": "王牌预备"},
        6: {"id": "ace", "name": "王牌飞行员", "name_en": "Ace Pilot", "desc": "击落5架以上"},
        7: {"id": "double_ace", "name": "双料王牌", "name_en": "Double Ace", "desc": "击落10架以上"},
        8: {"id": "flight_instructor", "name": "飞行教官", "name_en": "Flight Instructor", "desc": "飞行训练专家"},
        9: {"id": "ace_of_aces", "name": "王牌中的王牌", "name_en": "Ace of Aces", "desc": "传说中的飞行员"},
        10: {"id": "sky_legend", "name": "天空传奇", "name_en": "Sky Legend", "desc": "超越天空的传说"},
    },
}

## 战力倍率表（与现有系统对齐）
const POWER_MULTIPLIERS: Dictionary = {
    1: 1.00,
    2: 1.05,
    3: 1.10,
    4: 1.15,
    5: 1.20,
    6: 1.25,
    7: 1.30,
    8: 1.35,
    9: 1.50,
    10: 1.60,
}

## 消耗倍率表（纳米材料）
const COST_MULTIPLIERS: Dictionary = {
    1: 0.0,  # Lv1无需升级
    2: 0.5,
    3: 1.0,
    4: 1.5,
    5: 2.0,
    6: 2.5,
    7: 3.0,
    8: 3.5,
    9: 4.5,
    10: 6.0,
}

## 根据兵种类型和等级获取军衔称号
static func get_rank_title(combat_kind: int, level: int) -> Dictionary:
    if combat_kind < 0 or combat_kind > 3:
        combat_kind = 0
    var level_clamped: int = clampi(level, 1, 10)
    var kind_table: Dictionary = RANK_TITLES_BY_COMBAT_KIND.get(combat_kind, {})
    return kind_table.get(level_clamped, {})

## 获取战力倍率
static func get_power_multiplier(level: int) -> float:
    var level_clamped: int = clampi(level, 1, 10)
    return float(POWER_MULTIPLIERS.get(level_clamped, 1.0))

## 获取消耗倍率
static func get_cost_multiplier(level: int) -> float:
    var level_clamped: int = clampi(level, 1, 10)
    return float(COST_MULTIPLIERS.get(level_clamped, 1.0))
```

#### 1.2 修改 BlueprintManager

**文件**：`managers/blueprint_manager.gd`

**新增方法**：

```gdscript
## 获取卡牌当前军衔称号（UI显示用）
func get_card_rank_title(card_id: String) -> Dictionary:
    var card: CardResource = DefaultCards.get_card_by_id(card_id)
    if card == null:
        return {}
    var level: int = get_card_level(card_id)
    var kind: int = card.combat_kind if card.has_method("get") else 0
    return UnitRankTitles.get_rank_title(kind, level)

## 获取强化提升预览（返回 Dictionary 包含称号、战力、属性变化）
func get_level_up_preview(card_id: String) -> Dictionary:
    var current_level: int = get_card_level(card_id)
    if current_level >= MAX_BLUEPRINT_LEVEL:
        return {"error": "已满级"}
    var next_level: int = current_level + 1
    var card: CardResource = DefaultCards.get_card_by_id(card_id)
    if card == null:
        return {"error": "卡牌不存在"}
    
    var kind: int = card.combat_kind
    var current_rank: Dictionary = UnitRankTitles.get_rank_title(kind, current_level)
    var next_rank: Dictionary = UnitRankTitles.get_rank_title(kind, next_level)
    var power_mult: float = UnitRankTitles.get_power_multiplier(next_level)
    
    return {
        "current_level": current_level,
        "next_level": next_level,
        "current_rank": current_rank,
        "next_rank": next_rank,
        "power_multiplier": power_mult,
        "nano_cost": calculate_nano_cost_for_level_up(card_id),
        "manual_cost": 1,  # 固定消耗1本强化手册
    }
```

#### 1.3 UI 文案更新

**文件**：`scenes/ui/backpack_card_item.gd` 或相关 UI

更新等级显示逻辑，从 "Lv.5" 改为显示军衔简称，如 "士官"。

---

### 阶段二：兵种专属改造模块（优先级：高）

#### 2.1 新增数据文件

**文件**：`data/unit_modifications.gd`

```gdscript
extends RefCounted
## 兵种专属改造模块定义
## 按 CombatKind 分类：步兵(0)、装甲兵(1)、支援兵(2)、空中兵(3)

const GC = preload("res://resources/game_constants.gd")

## 改造模块定义表
const MODIFICATIONS_BY_COMBAT_KIND: Dictionary = {
    # 步兵改造（22个）
    0: [
        # 武器改造（10个）
        {
            "id": "INF_01",
            "name": "冲锋枪改装",
            "name_en": "Submachine Gun Mod",
            "description": "缩短枪管+大容量弹鼓，近战火力压制",
            "military_prototype": "MP18/汤普森",
            "effects": {"attack_interval": -0.15},  # -15%
            "conflict_group": "fire_rate",
            "slot": "weapon",
        },
        {
            "id": "INF_02",
            "name": "突击步枪化",
            "name_en": "Assault Rifle Conversion",
            "description": "中间威力弹革命，中距离火力提升",
            "military_prototype": "STG44",
            "effects": {"attack_light": 0.15},  # +15%
            "conflict_group": "damage",
            "slot": "weapon",
        },
        # ... 其余20个步兵改造
    ],
    
    # 装甲兵改造（15个）
    1: [
        {
            "id": "ARM_01",
            "name": "倾斜装甲",
            "name_en": "Sloped Armor",
            "description": "T-34革命设计，增加跳弹概率",
            "military_prototype": "T-34",
            "effects": {"defense_armor": 0.20},  # +20%
            "conflict_group": "armor",
            "slot": "armor",
        },
        # ... 其余14个装甲兵改造
    ],
    
    # 支援兵改造（12个）
    2: [
        # 炮兵/防空/工程改造定义
    ],
    
    # 空中兵改造（14个）
    3: [
        # 战斗机/直升机改造定义
    ],
}

## 根据兵种类型获取可用改造列表
static func get_available_modifications(combat_kind: int) -> Array:
    var kind: int = clampi(combat_kind, 0, 3)
    return MODIFICATIONS_BY_COMBAT_KIND.get(kind, [])

## 根据改造ID获取定义
static func get_modification_by_id(mod_id: String) -> Dictionary:
    for kind_mods in MODIFICATIONS_BY_COMBAT_KIND.values():
        for mod in kind_mods:
            if String(mod.get("id", "")) == mod_id:
                return mod
    return {}

## 获取冲突组的所有改造ID
static func get_conflicting_mods(conflict_group: String) -> Array:
    var result: Array = []
    for kind_mods in MODIFICATIONS_BY_COMBAT_KIND.values():
        for mod in kind_mods:
            if String(mod.get("conflict_group", "")) == conflict_group:
                result.append(mod.get("id", ""))
    return result
```

#### 2.2 修改 ModManager

**文件**：`managers/evolution/mod_manager.gd`

**新增方法**：

```gdscript
## 根据卡牌类型获取专属改造选项（覆盖原有通用选项）
static func get_mod_options(card_id: String) -> Array[Dictionary]:
    if card_id.is_empty():
        return []
    var card: CardResource = DefaultCards.get_card_by_id(card_id)
    if card == null:
        return []
    
    var combat_kind: int = card.combat_kind
    return UnitModifications.get_available_modifications(combat_kind)

## 检查改造冲突（同 conflict_group 不可共存）
static func check_mod_conflict(card_id: String, option_id: String, bpm_ref: Node) -> bool:
    var current_mods: Array = bpm_ref.blueprint_mods.get(card_id, [])
    var new_mod: Dictionary = UnitModifications.get_modification_by_id(option_id)
    var new_group: String = new_mod.get("conflict_group", "")
    
    if new_group.is_empty():
        return true  # 无冲突组，可安装
    
    for mod_id in current_mods:
        var existing_mod: Dictionary = UnitModifications.get_modification_by_id(mod_id)
        if existing_mod.get("conflict_group", "") == new_group:
            return false  # 冲突
    return true
```

#### 2.3 修改改造效果计算

**文件**：`data/mod_effects.gd`

新增兵种专属改造效果计算逻辑。

---

### 阶段三：完整进化路径（优先级：中）

#### 3.1 新增数据文件

**文件**：`data/evolution_paths.gd`

```gdscript
extends RefCounted
## 进化路径定义
## 主线 + 隐藏分支，基于情报解锁

## 进化节点定义
class EvolutionNode:
    var id: String
    var name: String
    var era: int
    var combat_kind: int
    var power: int
    var hp: int
    var attack_light: int
    var attack_armor: int
    var attack_air: int
    var defense_light: int
    var defense_armor: int
    var defense_air: int
    var parent_id: String
    var unlock_conditions: Dictionary
    var is_hidden: bool
    var special_ability: String
    
    func _init(p_id: String, p_name: String, p_era: int, p_kind: int,
                p_power: int, p_hp: int,
                p_atk_l: int, p_atk_a: int, p_atk_air: int,
                p_def_l: int, p_def_a: int, p_def_air: int,
                p_parent: String = "", p_unlock: Dictionary = {}, p_hidden: bool = false):
        id = p_id
        name = p_name
        era = p_era
        combat_kind = p_kind
        power = p_power
        hp = p_hp
        attack_light = p_atk_l
        attack_armor = p_atk_a
        attack_air = p_atk_air
        defense_light = p_def_l
        defense_armor = p_def_a
        defense_air = p_def_air
        parent_id = p_parent
        unlock_conditions = p_unlock
        is_hidden = p_hidden

## 步兵进化主线
const INFANTRY_MAIN_PATH: Array = [
    # E0 → E1 → E2 → E3 → E4 → E5
    EvolutionNode._init("ww1_mp18", "MP18突击班", 0, 0, 15, 100, 35, 0, 0, 8, 5, 3),
    EvolutionNode._init("ww2_thompson", "汤普森班", 1, 0, 60, 140, 55, 0, 0, 15, 10, 6, "ww1_mp18",
        {"level": 5, "mods": 2, "intel": 0.5}),
    EvolutionNode._init("cold_ak47", "AK-47步兵班", 2, 0, 160, 200, 90, 0, 0, 30, 20, 12, "ww2_thompson",
        {"level": 8, "mods": 5, "intel": 0.75, "eom": 1}),
    EvolutionNode._init("mod_marine", "海军陆战队", 3, 0, 320, 300, 140, 0, 0, 50, 35, 20, "cold_ak47",
        {"level": 10, "mods": 8, "intel": 0.90, "eom": 2}),
    EvolutionNode._init("fut_cyborg", "机械步兵", 4, 0, 500, 400, 200, 50, 0, 80, 60, 40, "mod_marine",
        {"level": 10, "mods": 9, "intel": 1.00, "eom": 3}),
    EvolutionNode._init("fut_colossus", "巨神机甲", 5, 1, 1590, 2000, 100, 550, 0, 150, 250, 0, "fut_cyborg",
        {"level": 10, "mods": 9, "intel": 1.00, "hidden_branch": true}),
]

## 隐藏分支：特种作战
const INFANTRY_HIDDEN_SPECIAL: Array = [
    EvolutionNode._init("mod_ranger", "游骑兵", 3, 0, 340, 320, 160, 20, 0, 55, 38, 22, "cold_ak47",
        {"level": 8, "mods": 5, "intel": 0.75, "hidden": true, "intel_type": "special"}),
    EvolutionNode._init("fe_nova_ghost_sniper", "幽灵狙击组", 4, 0, 450, 350, 180, 30, 0, 60, 45, 25, "mod_ranger",
        {"level": 10, "mods": 7, "intel": 0.90, "hidden": true},
    EvolutionNode._init("fut_spectre", "幽灵特工", 5, 0, 530, 350, 220, 80, 0, 60, 50, 40, "fe_nova_ghost_sniper",
        {"level": 10, "mods": 9, "intel": 1.00, "hidden": true, "ability": "stealth"}),
]

## 获取完整进化树
static func get_evolution_tree(base_card_id: String) -> Dictionary:
    var tree: Dictionary = {
        "main": [],
        "hidden": [],
    }
    
    # 根据基础卡牌ID查找路径
    match base_card_id:
        "ww1_mp18":
            tree["main"] = INFANTRY_MAIN_PATH
            tree["hidden"] = INFANTRY_HIDDEN_SPECIAL
        # 其他兵种路径...
    
    return tree

## 检查进化条件
static func check_evolution_requirements(node: EvolutionNode, current_state: Dictionary) -> bool:
    var req: Dictionary = node.unlock_conditions
    
    # 强化等级检查
    if current_state.get("level", 1) < req.get("level", 1):
        return false
    
    # 改造数量检查
    if current_state.get("mods", 0) < req.get("mods", 0):
        return false
    
    # 情报进度检查
    var intel_req: float = req.get("intel", 0.0)
    if intel_req > 0.0:
        var current_intel: float = IntelManual.get_overall_progress()
        if current_intel < intel_req:
            return false
    
    # EOM检查
    if req.get("eom", 0) > current_state.get("eom_count", 0):
        return false
    
    return true
```

#### 3.2 修改 IntelEvolutionManager

**文件**：`scripts/systems/intel_evolution_manager.gd`

新增隐藏分支解锁检查逻辑。

---

### 阶段四：UI 与文案更新（优先级：中）

#### 4.1 强化界面更新

**文件**：`scenes/ui/backpack_card_item.gd`

更新等级显示逻辑，显示军衔而非纯数字。

#### 4.2 改造界面更新

**文件**：新建 `scenes/ui/modification_panel.gd`

显示兵种专属改造选项，包含军事原型描述和效果说明。

#### 4.3 进化界面更新

**文件**：`scenes/ui/evolution_atlas_view.gd`

显示完整进化路径，包括隐藏分支。

---

### 阶段五：数据录入（优先级：低）

#### 5.1 完整改造模块录入

按文档中的140+改造模块，完整录入数据。

#### 5.2 完整进化路径录入

按文档中的73个进化节点，完整录入数据。

---

## 四、实施顺序

| 阶段 | 任务 | 预计工作量 | 依赖 |
|------|------|-----------|------|
| 1 | 创建 `unit_rank_titles.gd` | 2h | 无 |
| 2 | 修改 `BlueprintManager` 添加军衔方法 | 2h | 1 |
| 3 | 更新 UI 显示军衔 | 3h | 2 |
| 4 | 创建 `unit_modifications.gd` | 4h | 无 |
| 5 | 修改 `ModManager` 支持兵种专属改造 | 3h | 4 |
| 6 | 更新改造界面显示军事原型 | 4h | 5 |
| 7 | 创建 `evolution_paths.gd` | 6h | 无 |
| 8 | 修改进化系统支持隐藏分支 | 4h | 7 |
| 9 | 更新进化界面显示完整路径 | 4h | 8 |
| 10 | 数据录入（改造模块） | 8h | 5 |
| 11 | 数据录入（进化节点） | 6h | 7 |
| 12 | 测试与调试 | 6h | 所有 |

**总预计工作量**：约 48 小时

---

## 五、风险与应对

| 风险 | 影响 | 应对措施 |
|------|------|---------|
| 现有数据格式不兼容 | 高 | 添加数据迁移脚本，保留存档兼容性 |
| UI 空间不足 | 中 | 使用滚动容器或分页显示 |
| 性能影响（140+改造） | 中 | 按兵种懒加载改造选项 |
| 情报系统耦合 | 中 | 使用门禁检查，延迟加载隐藏分支 |

---

## 六、验收标准

1. **强化等级**：Lv1-Lv10 显示对应军衔称号
2. **改造模块**：显示军事原型名称和描述
3. **进化路径**：主线和隐藏分支正确显示，情报门禁生效
4. **数据兼容**：现有存档可正常加载
5. **UI表现**：无显示错乱，文案正确

---

**计划制定日期**：2026-06-01  
**计划执行者**：Claude Code  
**下次审查**：阶段一完成后
