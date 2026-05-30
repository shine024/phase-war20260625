extends RefCounted
class_name FactionExclusiveCards

const GC = preload("res://resources/game_constants.gd")

## 专属卡定义：14张（每势力2张）
## id: 唯一标识（fe_前缀）
## faction_id: 所属势力
## min_faction_level: 最低势力等级要求
## rarity: 稀有度（epic/legendary）
## era: 时代（0-4）
## combat_kind: 战斗类型（0轻装/1装甲/2支援/3空中/4堡垒）
const EXCLUSIVE_CARDS: Array[Dictionary] = [
	# ─── 钢壁防务 ───
	{
		"id": "fe_iron_wall_bastion",
		"name": "不朽堡垒",
		"faction_id": "iron_wall_corp",
		"min_faction_level": 3,
		"rarity": "epic",
		"era": 4,
		"combat_kind": 4,
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
		"combat_kind": 0,
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
		"combat_kind": 2,
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
		"combat_kind": 3,
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
		"combat_kind": 4,
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
		"combat_kind": 3,
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
		"combat_kind": 2,
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
		"combat_kind": 4,
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
		"combat_kind": 1,
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
	# 默认值
	c.enhance_level = 0
	c.mods = []
	c.evolution_paths = []
	c.evolution_stage = 0
	c.intel_progress = 0.0
	c.is_unlocked = false
	return c

## 检查卡牌是否为势力专属卡
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
