# 势力高级功能系统 — 详细实施计划（四合一）

> 版本：v1.0
> 日期：2026-05-30
> 依赖：势力卡牌变体系统（Phase 1-4 已实施）

---

## 总览

| 功能 | 核心概念 | 新增文件 | 修改文件 |
|------|---------|---------|---------|
| A. 势力专属卡 | 仅该势力可用的特殊卡牌 | `data/faction_exclusive_cards.gd` | BlueprintManager, card_resource.gd |
| B. 势力技能树 | 势力等级解锁被动技能 | `data/faction_skill_tree.gd`, `managers/faction/faction_skill_manager.gd` | faction_system_manager, unit_stats.gd |
| C. 势力战争事件 | 动态事件影响势力关系与加成 | `data/faction_war_events.gd`, `managers/faction/faction_event_manager.gd` | faction_system_manager, quest_manager |
| D. 势力合成台 | 跨势力合成混血变体 | `data/synthesis_recipes.gd`, `managers/synthesis/synthesis_manager.gd` | BlueprintManager, faction_card_generator |

---

# ═══════════════════════════════════════════════════════════
# A. 势力专属卡
# ═══════════════════════════════════════════════════════════

## A1. 设计概述

### 核心思路

势力专属卡是**不属于 `default_cards.gd` 基础列表的特殊卡牌**，每张卡绑定一个势力。玩家只有在**激活对应势力**且**势力等级达标**时才能使用该卡。

- 专属卡有自己的 `card_id`（如 `fe_iron_wall_bastion`）
- 专属卡作为 `default_cards.gd` 的**补充**，在 `create_all()` 末尾追加
- 专属卡也享受势力变体加成（该势力自己的专属卡获得二次加成，但加成减半）
- 专属卡可进化、强化、改造，与基础卡完全一致

### 数量规划

| 势力 | 专属卡数量 | 定位 |
|------|-----------|------|
| 钢壁防务 | 2 | 超级堡垒 + 反装甲步兵 |
| 新星兵工 | 2 | 超级火炮 + 精英狙击 |
| 以太动力 | 2 | 高速战车 + 无人机群 |
| 量子后勤 | 2 | 移动基地 + 维修车 |
| 螺旋侦察 | 2 | 隐形侦察 + 精确打击 |
| 虚空相位 | 2 | 法则炮台 + 虚空步兵 |
| 边境联合 | 2 | 万能步兵 + 多用途载具 |
| **合计** | **14** | |

### 解锁条件

- **最低要求**：激活该势力 + 势力等级 ≥ 3
- **获取方式**：势力商店购买（声望消耗）或势力任务奖励
- **切换势力后**：专属卡不可使用（灰色显示），但数据保留
- **重新激活势力后**：立即恢复可用

## A2. 数据结构设计

### `data/faction_exclusive_cards.gd`

```gdscript
extends RefCounted
class_name FactionExclusiveCards

const GC = preload("res://resources/game_constants.gd")

## 专属卡定义：14张
const EXCLUSIVE_CARDS: Array[Dictionary] = [
    # ─── 钢壁防务 ───
    {
        "id": "fe_iron_wall_bastion",
        "name": "不朽堡垒",
        "faction_id": "iron_wall_corp",
        "min_faction_level": 3,
        "rarity": "epic",
        "era": 4,           # 近未来外观
        "combat_kind": 4,   # 堡垒
        # 属性（与 _unit() 相同格式）
        "power": 1800, "deploy_speed": 0, "range": 6,
        "energy_cost": 35, "hp": 3200,
        "atk_light": 0, "atk_armor": 40, "atk_air": 80,
        "atk_light_speed": 0, "atk_armor_speed": 1.5, "atk_air_speed": 2.0,
        "atk_light_windup": 0, "atk_armor_windup": 0.2, "atk_air_windup": 0.1,
        "atk_light_active": 0, "atk_armor_active": 0.15, "atk_air_active": 0.08,
        "def_light": 120, "def_armor": 120, "def_air": 200,
        "description": "钢壁防务的最高杰作。三层复合装甲，双联防空系统。\n仅限钢壁防务势力使用。",
        "flavor_text": "\"这是我们的最终防线。\"",
    },
    {
        "id": "fe_iron_wall_juggernaut",
        "name": "重装先驱",
        "faction_id": "iron_wall_corp",
        "min_faction_level": 5,
        "rarity": "legendary",
        "era": 4,
        "combat_kind": 0,   # 轻装（重步兵）
        "power": 900, "deploy_speed": 1, "range": 2,
        "energy_cost": 25, "hp": 1800,
        "atk_light": 60, "atk_armor": 120, "atk_air": 30,
        "atk_light_speed": 0.8, "atk_armor_speed": 0.5, "atk_air_speed": 1.0,
        "atk_light_windup": 0.3, "atk_armor_windup": 0.5, "atk_air_windup": 0.2,
        "atk_light_active": 0.15, "atk_armor_active": 0.3, "atk_air_active": 0.1,
        "def_light": 100, "def_armor": 180, "def_air": 40,
        "description": "装备实验性反应装甲的超级步兵。移动缓慢但几乎无法击穿。\n仅限钢壁防务势力使用。",
        "flavor_text": "\"一步一步，碾碎一切。\"",
    },

    # ─── 新星兵工 ───
    {
        "id": "fe_nova_devastator",
        "name": "歼灭者自行火炮",
        "faction_id": "nova_arms",
        "min_faction_level": 3,
        "rarity": "epic",
        "era": 4,
        "combat_kind": 2,   # 支援
        "power": 1200, "deploy_speed": 1, "range": 99,
        "energy_cost": 40, "hp": 400,
        "atk_light": 200, "atk_armor": 160, "atk_air": 100,
        "atk_light_speed": 0.2, "atk_armor_speed": 0.2, "atk_air_speed": 0.2,
        "atk_light_windup": 1.0, "atk_armor_windup": 1.0, "atk_air_windup": 1.0,
        "atk_light_active": 0.3, "atk_armor_active": 0.3, "atk_air_active": 0.3,
        "def_light": 10, "def_armor": 15, "def_air": 20,
        "description": "新星兵工的终极火力平台。单轮齐射覆盖半个战场。\n仅限新星兵工势力使用。",
        "flavor_text": "\"口径不够大，就加更多管子。\"",
    },
    {
        "id": "fe_nova_ghost_sniper",
        "name": "幽灵狙击组",
        "faction_id": "nova_arms",
        "min_faction_level": 5,
        "rarity": "legendary",
        "era": 3,
        "combat_kind": 0,
        "power": 650, "deploy_speed": 4, "range": 8,
        "energy_cost": 22, "hp": 280,
        "atk_light": 180, "atk_armor": 250, "atk_air": 60,
        "atk_light_speed": 0.33, "atk_armor_speed": 0.25, "atk_air_speed": 0.5,
        "atk_light_windup": 0.5, "atk_armor_windup": 0.8, "atk_air_windup": 0.3,
        "atk_light_active": 0.2, "atk_armor_active": 0.4, "atk_air_active": 0.1,
        "def_light": 20, "def_armor": 15, "def_air": 30,
        "description": "装备电磁轨道步枪的精英狙手。一击必杀轻装甲目标。\n仅限新星兵工势力使用。",
        "flavor_text": "\"在你看到闪光之前，子弹已经到了。\"",
    },

    # ─── 以太动力 ───
    {
        "id": "fe_aether_hover_cavalry",
        "name": "以太骑兵",
        "faction_id": "aether_dynamics",
        "min_faction_level": 3,
        "rarity": "epic",
        "era": 4,
        "combat_kind": 0,
        "power": 700, "deploy_speed": 6, "range": 3,
        "energy_cost": 18, "hp": 450,
        "atk_light": 80, "atk_armor": 50, "atk_air": 30,
        "atk_light_speed": 1.5, "atk_armor_speed": 1.0, "atk_air_speed": 1.2,
        "atk_light_windup": 0.1, "atk_armor_windup": 0.2, "atk_air_windup": 0.15,
        "atk_light_active": 0.08, "atk_armor_active": 0.12, "atk_air_active": 0.08,
        "def_light": 25, "def_armor": 20, "def_air": 15,
        "description": "以太悬浮摩托突击队。极快部署，高速穿插。\n仅限以太动力势力使用。",
        "flavor_text": "\"速度就是最好的装甲。\"",
    },
    {
        "id": "fe_aether_swarm_queen",
        "name": "蜂群母机",
        "faction_id": "aether_dynamics",
        "min_faction_level": 5,
        "rarity": "legendary",
        "era": 4,
        "combat_kind": 3,   # 空中
        "power": 1000, "deploy_speed": 5, "range": 5,
        "energy_cost": 30, "hp": 500,
        "atk_light": 100, "atk_armor": 80, "atk_air": 60,
        "atk_light_speed": 3.0, "atk_armor_speed": 2.5, "atk_air_speed": 2.0,
        "atk_light_windup": 0.05, "atk_armor_windup": 0.08, "atk_air_windup": 0.1,
        "atk_light_active": 0.05, "atk_armor_active": 0.06, "atk_air_active": 0.08,
        "def_light": 20, "def_armor": 20, "def_air": 30,
        "description": "指挥蜂群无人机的空中母舰。超高射速覆盖攻击。\n仅限以太动力势力使用。",
        "flavor_text": "\"蜂群思维，无处不在。\"",
    },

    # ─── 量子后勤 ───
    {
        "id": "fe_quantum_mobile_base",
        "name": "移动堡垒基地",
        "faction_id": "quantum_logistics",
        "min_faction_level": 3,
        "rarity": "epic",
        "era": 4,
        "combat_kind": 4,   # 堡垒
        "power": 1500, "deploy_speed": 0, "range": 99,
        "energy_cost": 45, "hp": 2500,
        "atk_light": 30, "atk_armor": 50, "atk_air": 40,
        "atk_light_speed": 0.5, "atk_armor_speed": 0.5, "atk_air_speed": 0.8,
        "atk_light_windup": 0.2, "atk_armor_windup": 0.2, "atk_air_windup": 0.15,
        "atk_light_active": 0.1, "atk_armor_active": 0.1, "atk_air_active": 0.08,
        "def_light": 80, "def_armor": 80, "def_air": 80,
        "description": "量子后勤的移动指挥中心。为周围友军持续回复HP。\n仅限量子后勤势力使用。",
        "flavor_text": "\"只要有我们在，前线就不会断。\"",
    },
    {
        "id": "fe_quantum_repair_drone",
        "name": "纳米修复蜂群",
        "faction_id": "quantum_logistics",
        "min_faction_level": 5,
        "rarity": "legendary",
        "era": 4,
        "combat_kind": 3,   # 空中
        "power": 400, "deploy_speed": 5, "range": 4,
        "energy_cost": 15, "hp": 200,
        "atk_light": 0, "atk_armor": 0, "atk_air": 20,
        "atk_light_speed": 0, "atk_armor_speed": 0, "atk_air_speed": 1.5,
        "atk_light_windup": 0, "atk_armor_windup": 0, "atk_air_windup": 0.2,
        "atk_light_active": 0, "atk_armor_active": 0, "atk_air_active": 0.1,
        "def_light": 15, "def_armor": 15, "def_air": 25,
        "description": "纳米修复无人机群。每秒为范围内友军回复5%最大HP。\n仅限量子后勤势力使用。",
        "flavor_text": "\"没有修不好的，只有来不及修的。\"",
    },

    # ─── 螺旋侦察 ───
    {
        "id": "fe_helix_phantom",
        "name": "幻影特工",
        "faction_id": "helix_recon",
        "min_faction_level": 3,
        "rarity": "epic",
        "era": 4,
        "combat_kind": 0,
        "power": 680, "deploy_speed": 7, "range": 4,
        "energy_cost": 20, "hp": 380,
        "atk_light": 120, "atk_armor": 80, "atk_air": 40,
        "atk_light_speed": 2.0, "atk_armor_speed": 1.5, "atk_air_speed": 1.8,
        "atk_light_windup": 0.08, "atk_armor_windup": 0.12, "atk_air_windup": 0.1,
        "atk_light_active": 0.06, "atk_armor_active": 0.08, "atk_air_active": 0.06,
        "def_light": 30, "def_armor": 20, "def_air": 35,
        "description": "装备光学迷彩的超级侦察兵。超高闪避率。\n仅限螺旋侦察势力使用。",
        "flavor_text": "\"你看不到我，但我知道你的一切。\"",
    },
    {
        "id": "fe_helix_orbital_strike",
        "name": "轨道打击引导组",
        "faction_id": "helix_recon",
        "min_faction_level": 5,
        "rarity": "legendary",
        "era": 4,
        "combat_kind": 2,   # 支援
        "power": 1100, "deploy_speed": 3, "range": 99,
        "energy_cost": 35, "hp": 300,
        "atk_light": 250, "atk_armor": 200, "atk_air": 150,
        "atk_light_speed": 0.15, "atk_armor_speed": 0.12, "atk_air_speed": 0.18,
        "atk_light_windup": 1.5, "atk_armor_windup": 1.8, "atk_air_windup": 1.2,
        "atk_light_active": 0.5, "atk_armor_active": 0.6, "atk_air_active": 0.4,
        "def_light": 10, "def_armor": 10, "def_air": 15,
        "description": "呼叫轨道炮精确打击。超远射程超高伤害，但部署慢。\n仅限螺旋侦察势力使用。",
        "flavor_text": "\"坐标已锁定。天基武器，发射。\"",
    },

    # ─── 虚空相位 ───
    {
        "id": "fe_void_phase_cannon",
        "name": "相位炮台",
        "faction_id": "void_research",
        "min_faction_level": 3,
        "rarity": "epic",
        "era": 4,
        "combat_kind": 4,   # 堡垒
        "power": 1400, "deploy_speed": 0, "range": 7,
        "energy_cost": 32, "hp": 800,
        "atk_light": 150, "atk_armor": 120, "atk_air": 180,
        "atk_light_speed": 0.8, "atk_armor_speed": 0.8, "atk_air_speed": 1.2,
        "atk_light_windup": 0.3, "atk_armor_windup": 0.3, "atk_air_windup": 0.15,
        "atk_light_active": 0.2, "atk_armor_active": 0.2, "atk_air_active": 0.1,
        "def_light": 50, "def_armor": 50, "def_air": 100,
        "description": "虚空研究所的相位武器平台。攻击附带法则共鸣效果。\n仅限虚空相位势力使用。",
        "flavor_text": "\"在相位层面，装甲毫无意义。\"",
    },
    {
        "id": "fe_void_dimensional_soldier",
        "name": "次元行者",
        "faction_id": "void_research",
        "min_faction_level": 5,
        "rarity": "legendary",
        "era": 4,
        "combat_kind": 0,
        "power": 750, "deploy_speed": 5, "range": 3,
        "energy_cost": 22, "hp": 500,
        "atk_light": 90, "atk_armor": 70, "atk_air": 50,
        "atk_light_speed": 1.2, "atk_armor_speed": 1.0, "atk_air_speed": 1.0,
        "atk_light_windup": 0.15, "atk_armor_windup": 0.2, "atk_air_windup": 0.18,
        "atk_light_active": 0.08, "atk_armor_active": 0.1, "atk_air_active": 0.08,
        "def_light": 40, "def_armor": 40, "def_air": 50,
        "description": "经过虚空改造的超级步兵。可短暂进入次元获得无敌。\n仅限虚空相位势力使用。",
        "flavor_text": "\"我在两个维度之间行走。\"",
    },

    # ─── 边境联合 ───
    {
        "id": "fe_frontier_veteran",
        "name": "边境老兵",
        "faction_id": "frontier_union",
        "min_faction_level": 3,
        "rarity": "epic",
        "era": 3,
        "combat_kind": 0,
        "power": 500, "deploy_speed": 4, "range": 3,
        "energy_cost": 16, "hp": 600,
        "atk_light": 50, "atk_armor": 40, "atk_air": 25,
        "atk_light_speed": 1.2, "atk_armor_speed": 1.0, "atk_air_speed": 1.0,
        "atk_light_windup": 0.15, "atk_armor_windup": 0.2, "atk_air_windup": 0.2,
        "atk_light_active": 0.08, "atk_armor_active": 0.1, "atk_air_active": 0.08,
        "def_light": 30, "def_armor": 35, "def_air": 20,
        "description": "身经百战的老兵。各项属性均衡，无短板。\n仅限边境联合势力使用。",
        "flavor_text": "\"什么都会一点，什么都不怕。\"",
    },
    {
        "id": "fe_frontier_mixed_company",
        "name": "混编突击队",
        "faction_id": "frontier_union",
        "min_faction_level": 5,
        "rarity": "legendary",
        "era": 4,
        "combat_kind": 1,   # 装甲
        "power": 1100, "deploy_speed": 4, "range": 4,
        "energy_cost": 28, "hp": 1100,
        "atk_light": 70, "atk_armor": 60, "atk_air": 50,
        "atk_light_speed": 1.2, "atk_armor_speed": 1.0, "atk_air_speed": 1.0,
        "atk_light_windup": 0.1, "atk_armor_windup": 0.15, "atk_air_windup": 0.12,
        "atk_light_active": 0.08, "atk_armor_active": 0.1, "atk_air_active": 0.08,
        "def_light": 50, "def_armor": 60, "def_air": 45,
        "description": "边境联合的王牌部队。步兵、装甲、防空三位一体。\n仅限边境联合势力使用。",
        "flavor_text": "\"不挑敌人，什么都能打。\"",
    },
]

## 获取专属卡 CardResource
static func create_card(cfg: Dictionary) -> CardResource:
    var c := CardResource.new()
    c.card_id = cfg.get("id", "")
    c.display_name = cfg.get("name", "")
    c.card_type = GC.CardType.COMBAT_UNIT
    c.era = cfg.get("era", 0)
    c.combat_kind = cfg.get("combat_kind", 0)
    c.power = cfg.get("power", 0)
    c.deploy_speed = cfg.get("deploy_speed", 3)
    c.range_value = cfg.get("range", 3)
    c.energy_cost = float(cfg.get("energy_cost", 10))
    c.base_hp = float(cfg.get("hp", 100))
    c.attack_light = float(cfg.get("atk_light", 0))
    c.attack_armor = float(cfg.get("atk_armor", 0))
    c.attack_air = float(cfg.get("atk_air", 0))
    c.attack_light_speed = float(cfg.get("atk_light_speed", 1.0))
    c.attack_armor_speed = float(cfg.get("atk_armor_speed", 1.0))
    c.attack_air_speed = float(cfg.get("atk_air_speed", 1.0))
    c.attack_light_windup = float(cfg.get("atk_light_windup", 0.2))
    c.attack_armor_windup = float(cfg.get("atk_armor_windup", 0.2))
    c.attack_air_windup = float(cfg.get("atk_air_windup", 0.2))
    c.attack_light_active = float(cfg.get("atk_light_active", 0.1))
    c.attack_armor_active = float(cfg.get("atk_armor_active", 0.1))
    c.attack_air_active = float(cfg.get("atk_air_active", 0.1))
    c.defense_light = float(cfg.get("def_light", 0))
    c.defense_armor = float(cfg.get("def_armor", 0))
    c.defense_air = float(cfg.get("def_air", 0))
    c.rarity = cfg.get("rarity", "rare")
    c.description = cfg.get("description", "")
    c.flavor_text = cfg.get("flavor_text", "")
    # 推断类型行
    var era_names = ["一战", "二战", "冷战", "现代", "近未来"]
    var kind_names = ["轻装", "装甲", "支援", "空中", "堡垒"]
    c.type_line = "%s — %s · 势力专属" % [era_names[c.era], kind_names[c.combat_kind]]
    c.summary_line = "战力 %d｜势力专属" % c.power
    # 元数据
    c.faction_id = cfg.get("faction_id", "")
    c.faction_level = 0
    c.base_card_id = c.card_id
    c.is_faction_variant = false
    c.is_faction_exclusive = true
    # v5.0 默认值
    c.enhance_level = 0
    c.mods = []
    c.evolution_paths = []
    c.evolution_stage = 0
    c.intel_progress = 0.0
    c.is_unlocked = false
    return c

## 检查卡牌是否为势力专属
static func is_exclusive_card(card_id: String) -> bool:
    return card_id.begins_with("fe_")

## 获取专属卡所属势力
static func get_exclusive_faction(card_id: String) -> String:
    if not card_id.begins_with("fe_"):
        return ""
    for cfg in EXCLUSIVE_CARDS:
        if cfg.get("id", "") == card_id:
            return cfg.get("faction_id", "")
    return ""

## 获取专属卡最低势力等级
static func get_min_faction_level(card_id: String) -> int:
    for cfg in EXCLUSIVE_CARDS:
        if cfg.get("id", "") == card_id:
            return cfg.get("min_faction_level", 1)
    return 1

## 按势力过滤专属卡
static func get_exclusives_for_faction(faction_id: String) -> Array:
    var out: Array = []
    for cfg in EXCLUSIVE_CARDS:
        if cfg.get("faction_id", "") == faction_id:
            out.append(cfg.duplicate(true))
    return out
```

## A3. CardResource 扩展

```gdscript
# 在 card_resource.gd 中新增字段：
var is_faction_exclusive: bool = false  # 是否为势力专属卡
```

## A4. BlueprintManager 修改

```gdscript
# 在 BlueprintManager 中修改 can_manufacture / manufacture_card：

## 检查势力专属卡是否可用
func _is_exclusive_card_available(card_id: String) -> bool:
    if not FactionExclusiveCards.is_exclusive_card(card_id):
        return true  # 非专属卡，始终可用
    var faction_id: String = FactionExclusiveCards.get_exclusive_faction(card_id)
    var min_lv: int = FactionExclusiveCards.get_min_faction_level(card_id)
    var fsm: Node = get_node_or_null("/root/FactionSystemManager")
    if fsm == null:
        return false
    if fsm.get_active_faction() != faction_id:
        return false
    return fsm.get_faction_level(faction_id) >= min_lv
```

## A5. default_cards.gd 集成

在 `default_cards.gd` 的 `create_all()` 末尾追加专属卡：

```gdscript
# 在 create_all() 的 return list 之前追加：
var ExclusiveCards = preload("res://data/faction_exclusive_cards.gd")
for cfg in ExclusiveCards.EXCLUSIVE_CARDS:
    list.append(ExclusiveCards.create_card(cfg))
```

## A6. UI 表现

- 专属卡在背包中显示**势力颜色边框** + **势力图标**
- 不可用时显示为**灰色 + 锁图标**，tooltip 提示 "需要激活 XX 势力且等级 ≥ N"
- 卡牌类型行显示 `"近未来 — 堡垒 · 势力专属"` 标签

---

# ═══════════════════════════════════════════════════════════
# B. 势力技能树
# ═══════════════════════════════════════════════════════════

## B1. 设计概述

### 核心思路

每个势力有独立的**天赋树**，玩家通过势力等级 + 声望点数解锁技能节点。每个技能节点提供**永久被动加成**，影响该势力下的所有变体卡和专属卡。

- 技能树以**势力等级为门槛**（不是自由加点）
- 到达等级后需消耗**声望点**解锁对应技能
- 每级通常有**2-3个可选技能**，玩家只能选其中**1个**（分支选择）
- 已解锁技能永久生效，即使切换势力也不丢失

### 技能点来源

| 来源 | 点数 |
|------|------|
| 势力升级 (Lv→Lv+1) | 1 点/级 |
| 势力任务完成 | 1-3 点/任务 |
| 势力事件奖励 | 0-2 点/事件 |
| 总可用上限 | 与等级相关：Lv1=0, Lv2=1, Lv5=5, Lv10=15 |

### 技能分类

| 分类 | 效果范围 | 示例 |
|------|---------|------|
| **战斗强化** | 所有该势力变体卡的属性加成 | 全体HP+5%, 攻击+8% |
| **部署优化** | 部署相关机制 | 首次部署-10%能量, 部署速度+1 |
| **资源加成** | 掉落/经验/声望 | 战后声望+10%, 掉落率+5% |
| **特殊能力** | 独特机制效果 | 防御单位死亡回复周围HP, 攻击单位击杀回复能量 |

## B2. 数据结构设计

### `data/faction_skill_tree.gd`

```gdscript
extends RefCounted
class_name FactionSkillTree

## 技能节点数据结构
## id:          唯一ID
## name:        显示名称
## desc:        描述
## faction_id:  所属势力
## tier:        等级门槛（势力等级 ≥ tier 才能解锁）
## cost:        声望点消耗
## branch:      分支ID（同tier同branch只能选1个）
## effect_type: 效果类型（combat/deploy/resource/special）
## effects:     效果字典
## icon:        图标标识

const SKILL_TREE: Dictionary = {
    # ─── 钢壁防务技能树 ───
    "iron_wall_corp": [
        # Tier 2 (入门)
        {"id": "sk_iron_def1", "name": "钢铁意志", "desc": "所有钢壁变体HP+8%",
         "tier": 2, "cost": 1, "branch": "A", "effect_type": "combat",
         "effects": {"stat_bonus": {"hp": 0.08}}},
        {"id": "sk_iron_def2", "name": "快速部署", "desc": "所有钢壁变体部署速度+1",
         "tier": 2, "cost": 1, "branch": "B", "effect_type": "deploy",
         "effects": {"deploy_speed": 1}},
        # Tier 3
        {"id": "sk_iron_def3", "name": "复合装甲", "desc": "所有钢壁变体三维防御+12%",
         "tier": 3, "cost": 1, "branch": "A", "effect_type": "combat",
         "effects": {"stat_bonus": {"def_light": 0.12, "def_armor": 0.12, "def_air": 0.12}}},
        {"id": "sk_iron_res1", "name": "声望加成", "desc": "战后钢壁声望+15%",
         "tier": 3, "cost": 1, "branch": "B", "effect_type": "resource",
         "effects": {"reputation_bonus": 0.15}},
        # Tier 4
        {"id": "sk_iron_def4", "name": "不屈防线", "desc": "HP低于30%时防御+25%",
         "tier": 4, "cost": 2, "branch": "A", "effect_type": "special",
         "effects": {"conditional": {"hp_below": 0.3, "stat_bonus": {"def_light": 0.25, "def_armor": 0.25}}}},
        {"id": "sk_iron_res2", "name": "纳米回收", "desc": "钢壁变体死亡返还15%部署能量",
         "tier": 4, "cost": 2, "branch": "B", "effect_type": "special",
         "effects": {"on_death_energy_return": 0.15}},
        # Tier 5
        {"id": "sk_iron_def5", "name": "壁垒强化", "desc": "所有钢壁变体HP+15%, 三维防御+10%",
         "tier": 5, "cost": 2, "branch": "A", "effect_type": "combat",
         "effects": {"stat_bonus": {"hp": 0.15, "def_light": 0.10, "def_armor": 0.10, "def_air": 0.10}}},
        {"id": "sk_iron_dep1", "name": "要塞模式", "desc": "堡垒类部署-20%能量",
         "tier": 5, "cost": 2, "branch": "B", "effect_type": "deploy",
         "effects": {"energy_reduction": {"combat_kind": 4, "amount": 0.20}}},
        # Tier 7
        {"id": "sk_iron_sp1", "name": "钢铁壁垒", "desc": "钢壁变体周围2格友军防御+15%",
         "tier": 7, "cost": 3, "branch": "A", "effect_type": "special",
         "effects": {"aura": {"radius": 2.0, "stat_bonus": {"def_light": 0.15, "def_armor": 0.15}}}},
        {"id": "sk_iron_res3", "name": "军工效率", "desc": "声望获取+25%, 商店价格-10%",
         "tier": 7, "cost": 3, "branch": "B", "effect_type": "resource",
         "effects": {"reputation_bonus": 0.25, "shop_discount": 0.10}},
        # Tier 10
        {"id": "sk_iron_ult1", "name": "不可摧毁", "desc": "钢壁变体每60秒获得10%HP护盾",
         "tier": 10, "cost": 5, "branch": "A", "effect_type": "special",
         "effects": {"periodic_shield": {"interval": 60.0, "pct": 0.10}}},
        {"id": "sk_iron_ult2", "name": "钢铁洪流", "desc": "同时场上每多1个钢壁变体, 全体攻防+5%",
         "tier": 10, "cost": 5, "branch": "B", "effect_type": "special",
         "effects": {"stacking_bonus": {"per_unit": 1, "max": 5, "stat_bonus": {"atk_light": 0.05, "atk_armor": 0.05, "def_light": 0.05, "def_armor": 0.05}}}},
    ],

    # ─── 新星兵工技能树 ───
    "nova_arms": [
        {"id": "sk_nova_atk1", "name": "火力全开", "desc": "新星变体三维攻击+10%",
         "tier": 2, "cost": 1, "branch": "A", "effect_type": "combat",
         "effects": {"stat_bonus": {"atk_light": 0.10, "atk_armor": 0.10, "atk_air": 0.10}}},
        {"id": "sk_nova_spd1", "name": "快速装填", "desc": "新星变体攻击速度+8%",
         "tier": 2, "cost": 1, "branch": "B", "effect_type": "combat",
         "effects": {"stat_bonus": {"attack_speed": 0.08}}},
        {"id": "sk_nova_atk2", "name": "穿甲弹头", "desc": "新星变体对装甲伤害+15%",
         "tier": 3, "cost": 1, "branch": "A", "effect_type": "combat",
         "effects": {"stat_bonus": {"atk_armor": 0.15}}},
        {"id": "sk_nova_res1", "name": "战利品猎人", "desc": "战后掉落率+12%",
         "tier": 3, "cost": 1, "branch": "B", "effect_type": "resource",
         "effects": {"drop_bonus": 0.12}},
        {"id": "sk_nova_atk3", "name": "过载射击", "desc": "攻击速度>1.5时暴击率+10%",
         "tier": 4, "cost": 2, "branch": "A", "effect_type": "special",
         "effects": {"conditional": {"atk_speed_above": 1.5, "crit_bonus": 0.10}}},
        {"id": "sk_nova_dep1", "name": "突击部署", "desc": "新星轻装/装甲部署-15%能量",
         "tier": 4, "cost": 2, "branch": "B", "effect_type": "deploy",
         "effects": {"energy_reduction": {"combat_kind": [0, 1], "amount": 0.15}}},
        {"id": "sk_nova_atk4", "name": "弹幕理论", "desc": "新星变体攻击+12%, 攻速+5%",
         "tier": 5, "cost": 2, "branch": "A", "effect_type": "combat",
         "effects": {"stat_bonus": {"atk_light": 0.12, "atk_armor": 0.12, "attack_speed": 0.05}}},
        {"id": "sk_nova_sp1", "name": "击杀续能", "desc": "新星变体击杀敌人回复2%最大能量",
         "tier": 5, "cost": 2, "branch": "B", "effect_type": "special",
         "effects": {"on_kill_energy": 0.02}},
        {"id": "sk_nova_atk5", "name": "火力压制", "desc": "新星变体攻击使目标攻速-15%,持续3秒",
         "tier": 7, "cost": 3, "branch": "A", "effect_type": "special",
         "effects": {"on_hit_debuff": {"attack_speed_reduction": 0.15, "duration": 3.0}}},
        {"id": "sk_nova_res2", "name": "军工革新", "desc": "经验+20%, 强化成本-10%",
         "tier": 7, "cost": 3, "branch": "B", "effect_type": "resource",
         "effects": {"xp_bonus": 0.20, "enhance_discount": 0.10}},
        {"id": "sk_nova_ult1", "name": "末日火力", "desc": "新星变体首次攻击伤害+50%",
         "tier": 10, "cost": 5, "branch": "A", "effect_type": "special",
         "effects": {"first_hit_damage": 0.50}},
        {"id": "sk_nova_ult2", "name": "弹雨如注", "desc": "新星变体每次攻击有15%概率触发额外攻击",
         "tier": 10, "cost": 5, "branch": "B", "effect_type": "special",
         "effects": {"extra_attack_chance": 0.15}},
    ],

    # ─── 以太动力、量子后勤、螺旋侦察、虚空相位、边境联合 ───
    # 结构相同，每个势力约12-15个技能节点
    # 此处省略完整列表，按相同格式定义
    "aether_dynamics": [ /* ... */ ],
    "quantum_logistics": [ /* ... */ ],
    "helix_recon": [ /* ... */ ],
    "void_research": [ /* ... */ ],
    "frontier_union": [ /* ... */ ],
}

## 获取势力技能列表
static func get_skills_for_faction(faction_id: String) -> Array:
    return SKILL_TREE.get(faction_id, []).duplicate(true)

## 获取指定tier的技能
static func get_skills_at_tier(faction_id: String, tier: int) -> Array:
    var all: Array = get_skills_for_faction(faction_id)
    var out: Array = []
    for s in all:
        if int(s.get("tier", 0)) == tier:
            out.append(s)
    return out

## 获取技能定义
static func get_skill(faction_id: String, skill_id: String) -> Dictionary:
    for s in get_skills_for_faction(faction_id):
        if s.get("id", "") == skill_id:
            return s.duplicate(true)
    return {}

## 计算势力可用技能点总数
static func max_skill_points_at_level(level: int) -> int:
    # Lv1=0, Lv2=1, Lv3=2, Lv4=3, Lv5=5, Lv6=7, Lv7=9, Lv8=11, Lv9=13, Lv10=15
    match level:
        0, 1: return 0
        2: return 1
        3: return 2
        4: return 3
        5: return 5
        6: return 7
        7: return 9
        8: return 11
        9: return 13
        10: return 15
        _: return 15
```

### `managers/faction/faction_skill_manager.gd`

```gdscript
extends RefCounted
class_name FactionSkillManager

const SkillTree = preload("res://data/faction_skill_tree.gd")

## 运行时状态（由 FactionSystemManager 持有）
## faction_id → { "unlocked_skills": [skill_id, ...], "spent_points": int, "bonus_points": int }

## 创建默认状态
static func create_default_state(faction_id: String) -> Dictionary:
    return {
        "unlocked_skills": [],
        "spent_points": 0,
        "bonus_points": 0,  # 来自任务/事件奖励的额外点数
    }

## 能否解锁技能
static func can_unlock_skill(state: Dictionary, faction_id: String, skill_id: String, faction_level: int) -> Dictionary:
    var skill: Dictionary = SkillTree.get_skill(faction_id, skill_id)
    if skill.is_empty():
        return {"ok": false, "reason": "skill_not_found"}
    if skill_id in state["unlocked_skills"]:
        return {"ok": false, "reason": "already_unlocked"}
    var tier: int = int(skill.get("tier", 99))
    if faction_level < tier:
        return {"ok": false, "reason": "level_not_enough"}
    var cost: int = int(skill.get("cost", 1))
    var total_spent: int = int(state["spent_points"])
    var max_pts: int = SkillTree.max_skill_points_at_level(faction_level) + int(state["bonus_points"])
    if total_spent + cost > max_pts:
        return {"ok": false, "reason": "not_enough_points"}
    # 检查分支互斥
    var branch: String = skill.get("branch", "")
    if not branch.is_empty():
        var same_tier: Array = SkillTree.get_skills_at_tier(faction_id, tier)
        for other in same_tier:
            if other.get("branch", "") == branch and other.get("id", "") != skill_id:
                if other.get("id", "") in state["unlocked_skills"]:
                    return {"ok": false, "reason": "branch_conflict"}
    return {"ok": true, "cost": cost}

## 解锁技能
static func unlock_skill(state: Dictionary, faction_id: String, skill_id: String) -> bool:
    var can: Dictionary = can_unlock_skill(state, faction_id, skill_id, 0)
    # 需要从外部传入 faction_level，这里简化
    # 实际实现由 FactionSystemManager 调用
    return false

## 获取所有已解锁技能效果（合并计算）
static func get_active_effects(state: Dictionary, faction_id: String) -> Dictionary:
    var merged: Dictionary = {"stat_bonus": {}, "deploy": {}, "resource": {}, "special": []}
    for sid in state["unlocked_skills"]:
        var skill: Dictionary = SkillTree.get_skill(faction_id, sid)
        var fx: Dictionary = skill.get("effects", {})
        # 合并 stat_bonus
        if fx.has("stat_bonus"):
            for k in fx["stat_bonus"]:
                var v: float = float(fx["stat_bonus"][k])
                if not merged["stat_bonus"].has(k):
                    merged["stat_bonus"][k] = 0.0
                merged["stat_bonus"][k] += v
        # 收集 special 效果
        if skill.get("effect_type", "") == "special":
            merged["special"].append(fx)
    return merged
```

## B3. 属性注入管线

在 `battle_spawn_system.gd` 中，势力变体加成之后追加技能树加成：

```gdscript
# 在势力变体注入之后：
# === 势力技能树加成 ===
var fsm_skill = _get_autoload_node("FactionSystemManager")
if fsm_skill and fsm_skill.has_method("get_active_faction_skill_effects"):
    var skill_effects: Dictionary = fsm_skill.get_active_faction_skill_effects()
    if not skill_effects.is_empty():
        FactionSkillApplier.apply_to_stats(stats, skill_effects)
```

## B4. 存档集成

```gdscript
# FactionSystemManager.save_state() 中新增：
"faction_skill_states": {
    "iron_wall_corp": {"unlocked_skills": ["sk_iron_def1"], "spent_points": 1, "bonus_points": 0},
    "nova_arms": {...},
    ...
}
```

## B5. UI 设计

- **技能树面板**：垂直树状图，每层2个节点，已选高亮，未选灰色，锁定显示锁图标
- **技能tooltip**：显示效果描述、消耗、前置条件
- **入口**：势力面板 → 技能树按钮

---

# ═══════════════════════════════════════════════════════════
# C. 势力战争事件
# ═══════════════════════════════════════════════════════════

## C1. 设计概述

### 核心思路

动态生成的势力间冲突事件，定期触发，玩家通过选择支持某个势力来获得奖励并影响势力关系。

### 事件类型

| 类型 | 描述 | 示例 |
|------|------|------|
| **领土争夺** | 两势力争夺某关卡控制权 | 钢壁 vs 新星争夺第15关 |
| **资源争夺** | 两势力争夺稀有资源 | 虚空 vs 螺旋争夺纳米矿脉 |
| **间谍事件** | 势力间间谍活动暴露 | 新星在边境安插间谍 |
| **联盟邀请** | 势力请求玩家支持 | 以太邀请玩家加入联盟行动 |
| **内部危机** | 势力内部出现问题 | 量子后勤供应链断裂 |
| **对外扩张** | 势力对外发起进攻 | 钢壁发起大规模推进 |

### 事件生命周期

```
触发（每5场战斗或定时器30分钟）
  → 事件生成（从事件池随机选取）
  → 显示事件面板（玩家选择支持方/中立）
  → 结算奖励 + 势力声望变化
  → 事件历史记录
```

### 玩家选择

| 选择 | 效果 |
|------|------|
| **支持A方** | A方声望+20, B方声望-15, 获得A方奖励, A方→玩家关系+1 |
| **支持B方** | B方声望+20, A方声望-15, 获得B方奖励, B方→玩家关系+1 |
| **中立** | 双方声望-5, 获得少量通用资源 |
| **拒绝参与** | 无变化 |

### 影响势力加成

- 连续支持同一势力 → 该势力对玩家的**忠诚度**上升
- 忠诚度高时触发**特殊事件**（专属卡获取、技能点奖励）
- 支持敌对势力 → 忠诚度下降，可能触发**惩罚事件**

## C2. 数据结构设计

### `data/faction_war_events.gd`

```gdscript
extends RefCounted
class_name FactionWarEvents

## 事件模板池
const EVENT_TEMPLATES: Array[Dictionary] = [
    # ─── 领土争夺 ───
    {
        "type": "territory",
        "name": "领土争夺：{faction_a} vs {faction_b}",
        "desc": "{faction_a}与{faction_b}在第{level}关发生激烈冲突。",
        "duration_minutes": 30,
        "weight": 30,       # 生成权重
        "conditions": {},    # 触发条件
        "rewards": {
            "support_a": {"reputation": 20, "skill_points": 1, "nano": 500},
            "support_b": {"reputation": 20, "skill_points": 1, "nano": 500},
            "neutral": {"nano": 100},
        },
    },
    # ─── 资源争夺 ───
    {
        "type": "resource",
        "name": "资源争夺：{faction_a}的补给线",
        "desc": "{faction_a}的补给线遭到{faction_b}的袭击。支持哪一方？",
        "duration_minutes": 20,
        "weight": 20,
        "conditions": {"min_level": 10},
        "rewards": {
            "support_a": {"reputation": 25, "research_points": 200},
            "support_b": {"reputation": 15, "nanomaterial": 300},
            "neutral": {"research_points": 50},
        },
    },
    # ─── 间谍事件 ───
    {
        "type": "spy",
        "name": "间谍暴露：{faction_a}的秘密行动",
        "desc": "{faction_a}被发现试图在{faction_b}内部安插间谍。",
        "duration_minutes": 15,
        "weight": 10,
        "conditions": {"min_faction_level": 3},
        "rewards": {
            "support_a": {"reputation": 10, "energy_block": 2},
            "support_b": {"reputation": 15, "intel": 2},
            "neutral": {"intel": 1},
        },
    },
    # ─── 联盟邀请 ───
    {
        "type": "alliance",
        "name": "联盟邀请：{faction_a}的邀请",
        "desc": "{faction_a}希望与你建立更紧密的合作关系。",
        "duration_minutes": 60,
        "weight": 15,
        "conditions": {"min_reputation": 3000, "target_faction": "any"},
        "rewards": {
            "support_a": {"reputation": 30, "skill_points": 2, "exclusive_card": "random"},
            "neutral": {"nano": 200},
        },
    },
    # ─── 内部危机 ───
    {
        "type": "crisis",
        "name": "内部危机：{faction_a}的困境",
        "desc": "{faction_a}遭遇内部问题，需要你的帮助。",
        "duration_minutes": 45,
        "weight": 10,
        "conditions": {"min_faction_level": 5},
        "rewards": {
            "support_a": {"reputation": 35, "skill_points": 2, "faction_bonus_duration": 3},
            "neutral": {},
        },
    },
    # ─── 对外扩张 ───
    {
        "type": "expansion",
        "name": "扩张行动：{faction_a}的进攻",
        "desc": "{faction_a}正发起大规模进攻，{faction_b}请求支援。",
        "duration_minutes": 40,
        "weight": 15,
        "conditions": {"min_level": 20},
        "rewards": {
            "support_a": {"reputation": 25, "exclusive_card": "random"},
            "support_b": {"reputation": 25, "nanomaterial": 500},
            "neutral": {"nanomaterial": 100},
        },
    },
]

## 势力临时加成事件（影响势力变体加成）
const BONUS_EVENTS: Array[Dictionary] = [
    {"name": "军工增产", "faction_bonus_mult": 1.10, "duration_battles": 3},
    {"name": "全民动员", "faction_bonus_mult": 1.15, "duration_battles": 5},
    {"name": "研究突破", "skill_point_reward": 1, "one_time": true},
    {"name": "资源富余", "energy_cost_reduce": 0.10, "duration_battles": 3},
    {"name": "士气高涨", "deploy_speed_bonus": 1, "duration_battles": 4},
]
```

### `managers/faction/faction_event_manager.gd`

```gdscript
extends Node
class_name FactionEventManager

signal event_generated(event: Dictionary)
signal event_resolved(event_id: String, choice: String, rewards: Dictionary)
signal bonus_event_active(faction_id: String, bonus: Dictionary)

const FactionWarEvents = preload("res://data/faction_war_events.gd")
const CompanyDefinitions = preload("res://data/company_definitions.gd")
const FACTION_RELATIONS = preload("res://res://managers/faction_system_manager.gd").FACTION_RELATIONS

## 运行时状态
var active_event: Dictionary = {}          # 当前活跃事件
var active_bonus_events: Dictionary = {}    # faction_id → {bonus, remaining}
var event_history: Array = []               # 事件历史
var battle_count_since_last: int = 0        # 自上次事件以来的战斗数
var loyalty: Dictionary = {}                 # faction_id → float (0-100)

## 初始化忠诚度
func _ready() -> void:
    for c in CompanyDefinitions.get_all():
        loyalty[c.get("id", "")] = 50.0  # 初始50

## 每场战斗结束后检查
func on_battle_ended() -> void:
    battle_count_since_last += 1
    _check_event_trigger()
    _tick_bonus_events()

## 检查是否触发新事件
func _check_event_trigger() -> void:
    if not active_event.is_empty():
        return  # 已有活跃事件
    if battle_count_since_last < 5:
        return
    battle_count_since_last = 0
    _generate_event()

## 生成新事件
func _generate_event() -> void:
    # 按权重随机选择模板
    var pool: Array = []
    var total_weight: int = 0
    for tmpl in FactionWarEvents.EVENT_TEMPLATES:
        if _check_conditions(tmpl):
            pool.append(tmpl)
            total_weight += int(tmpl.get("weight", 10))
    if pool.is_empty():
        return
    # 加权随机
    var roll: int = randi() % total_weight
    var cumul: int = 0
    for tmpl in pool:
        cumul += int(tmpl.get("weight", 10))
        if roll < cumul:
            _instantiate_event(tmpl)
            return

## 实例化事件（填充势力A/B）
func _instantiate_event(template: Dictionary) -> void:
    var factions: Array = CompanyDefinitions.get_all()
    var fid_a: String = factions[randi() % factions.size()].get("id", "")
    # 根据关系选择对立势力
    var candidates: Array = []
    for fid in factions:
        if fid.get("id", "") != fid_a:
            candidates.append(fid.get("id", ""))
    var fid_b: String = candidates[randi() % candidates.size()].get("id", "") if not candidates.is_empty() else ""
    active_event = {
        "id": "evt_%d_%d" % [Time.get_unix_time_from_system(), randi() % 10000],
        "template": template,
        "faction_a": fid_a,
        "faction_b": fid_b,
        "generated_at": Time.get_unix_time_from_system(),
        "resolved": false,
    }
    event_generated.emit(active_event.duplicate(true))

## 玩家做出选择
func resolve_event(choice: String) -> Dictionary:
    if active_event.is_empty():
        return {}
    var rewards: Dictionary = _calculate_rewards(choice)
    _apply_reputation_changes(choice)
    _apply_loyalty_changes(choice)
    event_history.append(active_event.duplicate(true))
    var result = {"event_id": active_event.get("id", ""), "choice": choice, "rewards": rewards}
    event_resolved.emit(active_event.get("id", ""), choice, rewards)
    active_event = {}
    return result

## 应用声望变化
func _apply_reputation_changes(choice: String) -> void:
    var fsm = get_node_or_null("/root/FactionSystemManager")
    if fsm == null: return
    var tmpl_rewards = active_event["template"].get("rewards", {})
    var rewards: Dictionary = tmpl_rewards.get(choice, {})
    var fid_a: String = active_event.get("faction_a", "")
    var fid_b: String = active_event.get("faction_b", "")
    if choice == "support_a":
        fsm.add_faction_reputation(fid_a, int(rewards.get("reputation", 0)))
        fsm.add_faction_reputation(fid_b, -15)
    elif choice == "support_b":
        fsm.add_faction_reputation(fid_b, int(rewards.get("reputation", 0)))
        fsm.add_faction_reputation(fid_a, -15)
    else:  # neutral
        fsm.add_faction_reputation(fid_a, -5)
        fsm.add_faction_reputation(fid_b, -5)
```

## C3. 存档

```gdscript
# FactionSystemManager 中：
"faction_event_state": {
    "battle_count_since_last": 0,
    "loyalty": {"iron_wall_corp": 50.0, ...},
    "event_history": [...],
}
```

## C4. 集成点

- **每场战斗结束**：调用 `FactionEventManager.on_battle_ended()`
- **UI入口**：主界面新增"势力动态"图标，有新事件时显示红色通知
- **事件面板**：显示事件描述、双方势力信息、奖励预览、选择按钮

---

# ═══════════════════════════════════════════════════════════
# D. 势力合成台
# ═══════════════════════════════════════════════════════════

## D1. 设计概述

### 核心思路

将**不同势力的变体卡**放入合成台，产出**混血变体卡**——同时具有两个势力特色的全新卡牌。

- 输入：2张同基础卡的不同势力变体
- 输出：1张混血变体卡（新card_id）
- 混血变体同时拥有两个势力的加成（各取50%）
- 混血变体不可再合成（终端产品）
- 合成消耗：研究点 + 纳米材料 + 合成许可函

### 合成规则

```
输入卡A: 钢壁·虎式坦克 III型 (iron_wall_corp, Lv3)
输入卡B: 新星·虎式坦克 II型  (nova_arms, Lv2)
  ↓ 合成
输出卡: 混血·虎式坦克 (hybrid:iron_wall_corp+nova_arms)
  钢壁加成 × 50% + 新星加成 × 50%
```

### 限制

- 两张输入卡必须是**同一基础卡**的不同势力变体（或一张基础卡+一张变体卡）
- 两张输入卡势力必须**不同**
- 合成后**消耗**两张输入卡（蓝图副本 -1）
- 合成后产出卡为**独立变体**，跟随当前激活势力
- 产出卡**不可再次合成**（防止无限嵌套）

## D2. 数据结构设计

### `data/synthesis_recipes.gd`

```gdscript
extends RefCounted
class_name SynthesisRecipes

## 合成规则（程序化匹配，无需手写配方）
## 匹配条件：两张卡 base_card_id 相同 && faction_id 不同

## 合成费用公式
static func get_synthesis_cost(base_card_id: String, faction_a: String, faction_b: String) -> Dictionary:
    var base_card: CardResource = DefaultCards.get_card_by_id(base_card_id)
    if base_card == null:
        return {}
    var base_power: int = base_card.power
    return {
        "research_points": int(base_power * 2.5),
        "nanomaterial": int(base_power * 1.5),
        "synthesis_permit": 1,  # 通用合成许可函
    }

## 生成混血卡ID
static func generate_hybrid_id(base_card_id: String, faction_a: String, faction_b: String) -> String:
    # 排序势力ID确保唯一性
    var pair: Array = [faction_a, faction_b]
    pair.sort()
    return "hybrid_%s_%s_%s" % [base_card_id, pair[0], pair[1]]

## 计算混血加成（两势力各取50%）
static func calculate_hybrid_bonus(base_card_id: String, faction_a: String, faction_b: String, level_a: int, level_b: int) -> Dictionary:
    var bonus_a: Dictionary = FactionCardBonuses.get_bonus(faction_a, level_a)
    var bonus_b: Dictionary = FactionCardBonuses.get_bonus(faction_b, level_b)
    var hybrid: Dictionary = {}
    # 所有数值字段取50%平均
    var numeric_keys: Array = [
        "hp_bonus", "atk_light_bonus", "atk_armor_bonus", "atk_air_bonus",
        "def_light_bonus", "def_armor_bonus", "def_air_bonus",
        "energy_cost_reduce", "attack_speed_bonus",
        "dodge_bonus", "crit_chance_bonus", "crit_damage_bonus",
        "accuracy_bonus", "hp_regen_pct", "damage_reduction_bonus", "effect_bonus",
    ]
    for key in numeric_keys:
        var va: float = float(bonus_a.get(key, 0.0)) * 0.5
        var vb: float = float(bonus_b.get(key, 0.0)) * 0.5
        hybrid[key] = va + vb
    # 整数字段取平均后取整
    hybrid["deploy_speed_bonus"] = roundi(
        (float(bonus_a.get("deploy_speed_bonus", 0)) * 0.5) + (float(bonus_b.get("deploy_speed_bonus", 0)) * 0.5)
    )
    hybrid["range_bonus"] = roundi(
        (float(bonus_a.get("range_bonus", 0)) * 0.5) + (float(bonus_b.get("range_bonus", 0)) * 0.5)
    )
    # 名称
    var name_a: String = FactionCardBonuses.FACTION_NAMES.get(faction_a, "")
    var name_b: String = FactionCardBonuses.FACTION_NAMES.get(faction_b, "")
    hybrid["name_prefix"] = "混血·%s" % name_a
    hybrid["name_suffix"] = "×%s" % name_b
    return hybrid

## 检查是否为混血卡
static func is_hybrid_card(card_id: String) -> bool:
    return card_id.begins_with("hybrid_")
```

### `managers/synthesis/synthesis_manager.gd`

```gdscript
extends Node
class_name SynthesisManager

const SynthesisRecipes = preload("res://data/synthesis_recipes.gd")
const FactionCardBonuses = preload("res://data/faction_card_bonuses.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const FactionCardGenerator = preload("res://managers/faction/faction_card_generator.gd")

signal synthesis_completed(hybrid_card_id: String)
signal synthesis_failed(reason: String)

## 存档
var hybrid_cards: Array = []  # 已合成的混血卡ID列表

## 检查合成可行性
func can_synthesize(card_id_a: String, card_id_b: String) -> Dictionary:
    # 检查是否已有混血版本
    var base_a: String = _get_base_card_id(card_id_a)
    var base_b: String = _get_base_card_id(card_id_b)
    if base_a.is_empty() or base_b.is_empty():
        return {"ok": false, "reason": "invalid_card"}
    if base_a != base_b:
        return {"ok": false, "reason": "different_base"}
    var fac_a: String = _get_faction_id(card_id_a)
    var fac_b: String = _get_faction_id(card_id_b)
    if fac_a == fac_b:
        return {"ok": false, "reason": "same_faction"}
    if fac_a.is_empty() or fac_b.is_empty():
        return {"ok": false, "reason": "not_variant"}
    # 检查是否已存在
    var hybrid_id: String = SynthesisRecipes.generate_hybrid_id(base_a, fac_a, fac_b)
    if hybrid_id in hybrid_cards:
        return {"ok": false, "reason": "already_exists"}
    return {"ok": true, "hybrid_id": hybrid_id, "base_card_id": base_a, "faction_a": fac_a, "faction_b": fac_b}

## 执行合成
func synthesize(card_id_a: String, card_id_b: String) -> Dictionary:
    var check: Dictionary = can_synthesize(card_id_a, card_id_b)
    if not check.get("ok", false):
        synthesis_failed.emit(check.get("reason", "unknown"))
        return check
    # 消耗资源（检查 + 扣除）
    var costs: Dictionary = SynthesisRecipes.get_synthesis_cost(
        check["base_card_id"], check["faction_a"], check["faction_b"]
    )
    # ... 资源检查与扣除逻辑 ...
    # 生成混血卡
    var level_a: int = _get_faction_level(card_id_a)
    var level_b: int = _get_faction_level(card_id_b)
    var hybrid_bonus: Dictionary = SynthesisRecipes.calculate_hybrid_bonus(
        check["base_card_id"], check["faction_a"], check["faction_b"], level_a, level_b
    )
    # 创建混血 CardResource
    var base_card: CardResource = DefaultCards.get_card_by_id(check["base_card_id"])
    var hybrid: CardResource = base_card.clone()
    hybrid.card_id = check["hybrid_id"]
    var base_name: String = FactionCardBonuses.FACTION_NAMES.get(check["faction_a"], "")
    var sec_name: String = FactionCardBonuses.FACTION_NAMES.get(check["faction_b"], "")
    hybrid.display_name = "混血·%s × %s · %s" % [base_name, sec_name, base_card.display_name]
    FactionCardGenerator.apply_faction_bonus(hybrid, hybrid_bonus)
    hybrid.power = base_card.power  # 基于原始战力
    hybrid.is_faction_variant = true
    hybrid.faction_id = check["faction_a"]  # 主势力
    hybrid.base_card_id = check["base_card_id"]
    hybrid.faction_level = max(level_a, level_b)
    hybrid.is_faction_hybrid = true  # 新字段
    hybrid.hybrid_second_faction = check["faction_b"]  # 新字段
    hybrid_cards.append(check["hybrid_id"])
    synthesis_completed.emit(check["hybrid_id"])
    return {"ok": true, "hybrid_card": hybrid, "hybrid_id": check["hybrid_id"]}
```

## D3. CardResource 扩展

```gdscript
# 新增字段：
var is_faction_hybrid: bool = false        # 是否为混血卡
var hybrid_second_faction: String = ""    # 第二势力ID
```

## D4. 存档

```gdscript
# SaveConstants 新增：
const SK_SYNTHESIS: String = "synthesis"

# SaveManager 注册：
# synthesis_manager → SynthesisManager
```

## D5. UI 设计

### 合成台面板

```
┌─────────────────────────────────────────┐
│         ⚗ 势力合成台                      │
├─────────────────────────────────────────┤
│                                         │
│  [槽位A]              [槽位B]            │
│  ┌─────────┐        ┌─────────┐        │
│  │ 钢壁·   │   +   │ 新星·   │        │
│  │ 虎式    │        │ 虎式    │        │
│  │ III型   │        │ II型   │        │
│  └─────────┘        └─────────┘        │
│                                         │
│            ↓ 合成                        │
│                                         │
│         ┌─────────────┐                │
│         │ 混血·钢壁×新星│                │
│         │ ·虎式坦克    │                │
│         │             │                │
│         │ HP +14%     │                │
│         │ ATK +8%     │                │
│         │ DEF +12%    │                │
│         │ DEPLOY -1   │                │
│         └─────────────┘                │
│                                         │
│  消耗: 研究点 4800 | 纳米 2880 | 许可 1 │
│                                         │
│  [执行合成]              [返回]          │
└─────────────────────────────────────────┘
```

---

# ═══════════════════════════════════════════════════════════
# 实施分阶段计划
# ═══════════════════════════════════════════════════════════

## Phase A：势力专属卡（预计 2-3 小时）

| 步骤 | 任务 | 文件 |
|------|------|------|
| A.1 | 创建 `data/faction_exclusive_cards.gd`（14张专属卡定义） | 新建 |
| A.2 | 扩展 `card_resource.gd`（`is_faction_exclusive` 字段 + clone） | 修改 |
| A.3 | 修改 `default_cards.gd`（`create_all()` 追加专属卡） | 修改 |
| A.4 | 修改 `BlueprintManager`（`_is_exclusive_card_available` 检查） | 修改 |
| A.5 | UI 适配（背包灰色显示 + 势力图标） | 修改 |

**验收标准**：
- [ ] 14张专属卡可通过 `get_card_by_id("fe_...")` 获取
- [ ] 未激活对应势力时，专属卡显示灰色+锁
- [ ] 激活势力且等级达标后，专属卡可正常制造/部署
- [ ] 专属卡享受势力变体加成（加成减半）

## Phase B：势力技能树（预计 4-5 小时）

| 步骤 | 任务 | 文件 |
|------|------|------|
| B.1 | 创建 `data/faction_skill_tree.gd`（7势力×12-15技能节点） | 新建 |
| B.2 | 创建 `managers/faction/faction_skill_manager.gd` | 新建 |
| B.3 | 修改 `faction_system_manager.gd`（技能状态管理） | 修改 |
| B.4 | 修改 `battle_spawn_system.gd`（技能加成注入） | 修改 |
| B.5 | 扩展 `unit_stats.gd`（技能特殊效果字段） | 修改 |
| B.6 | 存档集成（`SaveConstants` + `SaveManager`） | 修改 |
| B.7 | UI：技能树面板（树状图 + 分支选择） | 新建/修改 |

**验收标准**：
- [ ] 势力 Lv2 起可解锁第一个技能
- [ ] 同分支技能互斥（只能选1个）
- [ ] 已解锁技能正确应用到战场属性
- [ ] 存档保存/加载技能状态

## Phase C：势力战争事件（预计 3-4 小时）

| 步骤 | 任务 | 文件 |
|------|------|------|
| C.1 | 创建 `data/faction_war_events.gd`（事件模板池 + 加成事件） | 新建 |
| C.2 | 创建 `managers/faction/faction_event_manager.gd` | 新建 |
| C.3 | 修改 `faction_system_manager.gd`（事件状态集成） | 修改 |
| C.4 | 集成到战斗结束流程（触发事件检查） | 修改 |
| C.5 | 存档集成 | 修改 |
| C.6 | UI：事件面板 + 主界面通知图标 | 新建/修改 |
| C.7 | 任务系统扩展（支持势力事件相关任务目标） | 修改 |

**验收标准**：
- [ ] 每5场战斗自动生成事件
- [ ] 玩家可选择支持方/中立
- [ ] 选择后正确影响声望和忠诚度
- [ ] 加成事件在指定场数内生效
- [ ] 事件历史可查看

## Phase D：势力合成台（预计 3-4 小时）

| 步骤 | 任务 | 文件 |
|------|------|------|
| D.1 | 创建 `data/synthesis_recipes.gd`（配方系统 + 费用公式） | 新建 |
| D.2 | 创建 `managers/synthesis/synthesis_manager.gd` | 新建 |
| D.3 | 扩展 `card_resource.gd`（`is_faction_hybrid` + `hybrid_second_faction`） | 修改 |
| D.4 | 扩展 `FactionCardBonuses`（支持混血加成计算） | 修改 |
| D.5 | 存档集成（`SaveConstants` + `SaveManager`） | 修改 |
| D.6 | UI：合成台面板（双槽位 + 预览 + 执行） | 新建/修改 |
| D.7 | 背包集成（混血卡显示 + 管理） | 修改 |

**验收标准**：
- [ ] 两个不同势力变体可合成混血卡
- [ ] 混血卡加成为两势力各50%
- [ ] 同基础卡同势力对不可重复合成
- [ ] 混血卡不可再次合成
- [ ] 合成消耗正确的资源

---

## 完整文件变更清单

### 新建文件（9个）

| 文件路径 | 职责 |
|---------|------|
| `data/faction_exclusive_cards.gd` | 14张势力专属卡定义 |
| `data/faction_skill_tree.gd` | 7势力技能树节点定义 |
| `managers/faction/faction_skill_manager.gd` | 技能树运行时管理 |
| `data/faction_war_events.gd` | 势力战争事件模板池 |
| `managers/faction/faction_event_manager.gd` | 势力事件运行时管理 |
| `data/synthesis_recipes.gd` | 合成配方 + 费用公式 |
| `managers/synthesis/synthesis_manager.gd` | 合成台运行时管理 |
| `scenes/ui/skill_tree_panel.tscn` | 技能树UI场景 |
| `scenes/ui/synthesis_panel.tscn` | 合成台UI场景 |

### 修改文件（12个）

| 文件路径 | 修改内容 |
|---------|---------|
| `resources/card_resource.gd` | 新增 `is_faction_exclusive`, `is_faction_hybrid`, `hybrid_second_faction` |
| `data/default_cards.gd` | `create_all()` 追加专属卡 |
| `managers/faction_system_manager.gd` | 技能状态、事件状态、合成状态管理 |
| `managers/battle/battle_spawn_system.gd` | 技能加成注入 |
| `resources/unit_stats.gd` | 技能特殊效果字段 |
| `managers/blueprint_manager.gd` | 专属卡可用性检查 |
| `scripts/systems/save_constants.gd` | 新增存档键 |
| `managers/save_manager.gd` | 注册新存档管理器 |
| `scenes/ui/backpack_card_item.gd` | 专属卡/混血卡UI适配 |
| `scenes/ui/faction_panel.gd` | 技能树入口 |
| `managers/quest_manager.gd` | 势力事件任务目标 |
| `scenes/ui/card_info_panel.gd` | 势力标签显示 |

---

## 风险评估

| 风险 | 级别 | 缓解措施 |
|------|------|---------|
| 技能树加成数值崩坏 | 高 | 每个技能加成单独较小（5-15%），多层叠加设置上限 |
| 事件生成影响游戏节奏 | 中 | 可配置触发间隔，事件面板非阻塞（玩家可忽略） |
| 混血卡存档兼容 | 低 | 混血卡ID含所有信息，旧存档无混血卡不影响 |
| 专属卡破坏势力平衡 | 中 | 专属卡数值对标同战力基础卡 + 势力特色，不额外超模 |
| 合成台产出过于强力 | 中 | 混血加成各50%，总和小于单一势力Lv10加成 |
