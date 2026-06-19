extends RefCounted
class_name RunewordDefinitions
## 符文之语定义（参考暗黑2机制）
##
## 触发条件三要素：
##   1. 相位仪符文槽位中插入了指定组合的符文
##   2. 槽位总数满足 min_slot_count 要求
##   3. （可选）势力声望达到 unlock_requirement
##
## 层级分布（共65种）：
##   2符文之语（25种）— 最常见，2槽位即可触发
##   3符文之语（20种）— 中等稀有，需3槽位
##   4符文之语（15种）— 稀有，需4槽位
##   5符文之语（5种）  — 传说，需5槽位
##
## 效果类型：
##   - 数值加成：attack/defense/hp/attack_speed/energy_regen 等（占大多数）
##   - 特殊效果：on_kill_regen_energy/on_hit_chain_lightning 等（顶级符文之语才有）

const RuneDefinitions = preload("res://data/runes.gd")

# ── 层级常量 ─────────────────────────────────────────────────────────

const TIER_2: int = 2  # 2符文之语
const TIER_3: int = 3  # 3符文之语
const TIER_4: int = 4  # 4符文之语
const TIER_5: int = 5  # 5符文之语

const ALL_TIERS: Array[int] = [TIER_2, TIER_3, TIER_4, TIER_5]

const TIER_NAMES: Dictionary = {
	TIER_2: "2符文之语",
	TIER_3: "3符文之语",
	TIER_4: "4符文之语",
	TIER_5: "5符文之语",
}

const TIER_COLORS: Dictionary = {
	TIER_2: Color(0.75, 0.75, 0.78),   # 银色
	TIER_3: Color(0.35, 0.75, 0.95),   # 青蓝
	TIER_4: Color(0.7, 0.35, 0.95),    # 紫色
	TIER_5: Color(0.98, 0.72, 0.18),   # 金色
}

# ── 符文之语名称表 ─────────────────────────────────────────────────

const RUNEWORD_NAMES: Dictionary = {
	# 2符文之语（25种）
	"rw_2_01": "锐利",
	"rw_2_02": "厚甲",
	"rw_2_03": "涌泉",
	"rw_2_04": "疾走",
	"rw_2_05": "强袭",
	"rw_2_06": "坚壁",
	"rw_2_07": "充能",
	"rw_2_08": "闪避",
	"rw_2_09": "穿透",
	"rw_2_10": "再生",
	"rw_2_11": "破阵",
	"rw_2_12": "壁垒",
	"rw_2_13": "回响",
	"rw_2_14": "迅捷",
	"rw_2_15": "共鸣",
	"rw_2_16": "锋刃",
	"rw_2_17": "铁幕",
	"rw_2_18": "循环",
	"rw_2_19": "风暴前奏",
	"rw_2_20": "潜行",
	"rw_2_21": "专注",
	"rw_2_22": "护佑",
	"rw_2_23": "积聚",
	"rw_2_24": "激流",
	"rw_2_25": "稳态",
	# 3符文之语（20种）
	"rw_3_01": "三相之力",
	"rw_3_02": "战阵",
	"rw_3_03": "守护者",
	"rw_3_04": "灵能",
	"rw_3_05": "破甲者",
	"rw_3_06": "坚不可摧",
	"rw_3_07": "能量风暴",
	"rw_3_08": "幻影刺客",
	"rw_3_09": "雷霆",
	"rw_3_10": "再生壁垒",
	"rw_3_11": "疾风怒涛",
	"rw_3_12": "磐石之心",
	"rw_3_13": "永动",
	"rw_3_14": "致命精准",
	"rw_3_15": "圣盾守卫",
	"rw_3_16": "深渊",
	"rw_3_17": "光辉",
	"rw_3_18": "暗影",
	"rw_3_19": "烈焰",
	"rw_3_20": "冰封",
	# 4符文之语（15种）
	"rw_4_01": "战神",
	"rw_4_02": "不灭",
	"rw_4_03": "永恒能量",
	"rw_4_04": "幻象大师",
	"rw_4_05": "破灭者",
	"rw_4_06": "神圣壁垒",
	"rw_4_07": "雷霆之怒",
	"rw_4_08": "再生之灵",
	"rw_4_09": "风暴召唤",
	"rw_4_10": "深渊之握",
	"rw_4_11": "光辉圣殿",
	"rw_4_12": "暗影契约",
	"rw_4_13": "烈焰风暴",
	"rw_4_14": "冰封王座",
	"rw_4_15": "命运",
	# 5符文之语（5种）
	"rw_5_01": "诸神黄昏",
	"rw_5_02": "永生",
	"rw_5_03": "创世",
	"rw_5_04": "湮灭",
	"rw_5_05": "无限",
}

# ── 符文之语定义（65种） ──────────────────────────────────────────

const ALL_RUNEWORDS: Array[Dictionary] = [
	# ═══════════════════════════════════════════════════════════════
	# 2符文之语（25种）— 基础组合，2槽位即可触发
	# ═══════════════════════════════════════════════════════════════

	# rw_2_01 — 锐利（攻击+攻击）
	{
		"id": "rw_2_01",
		"tier": TIER_2,
		"required_runes": ["attack_01", "attack_02"],
		"min_slot_count": 2,
		"effects": [
			{"stat": "attack", "value": 0.25},
		],
		"unlock_requirement": null,
	},

	# rw_2_02 — 厚甲（防御+防御）
	{
		"id": "rw_2_02",
		"tier": TIER_2,
		"required_runes": ["defense_01", "defense_02"],
		"min_slot_count": 2,
		"effects": [
			{"stat": "hp", "value": 0.30},
			{"stat": "defense", "value": 0.15},
		],
		"unlock_requirement": null,
	},

	# rw_2_03 — 涌泉（能量+能量）
	{
		"id": "rw_2_03",
		"tier": TIER_2,
		"required_runes": ["energy_01", "energy_02"],
		"min_slot_count": 2,
		"effects": [
			{"stat": "energy_regen", "value": 0.30},
			{"stat": "energy_cost_reduction", "value": 0.10},
		],
		"unlock_requirement": null,
	},

	# rw_2_04 — 疾走（机动+机动）
	{
		"id": "rw_2_04",
		"tier": TIER_2,
		"required_runes": ["mobility_01", "mobility_02"],
		"min_slot_count": 2,
		"effects": [
			{"stat": "deploy_speed", "value": 0.30},
			{"stat": "dodge", "value": 0.12},
		],
		"unlock_requirement": null,
	},

	# rw_2_05 — 强袭（攻击+防御）
	{
		"id": "rw_2_05",
		"tier": TIER_2,
		"required_runes": ["attack_01", "defense_01"],
		"min_slot_count": 2,
		"effects": [
			{"stat": "attack", "value": 0.18},
			{"stat": "hp", "value": 0.18},
		],
		"unlock_requirement": null,
	},

	# rw_2_06 — 坚壁（防御+能量）
	{
		"id": "rw_2_06",
		"tier": TIER_2,
		"required_runes": ["defense_02", "energy_01"],
		"min_slot_count": 2,
		"effects": [
			{"stat": "defense", "value": 0.18},
			{"stat": "energy_regen", "value": 0.18},
		],
		"unlock_requirement": null,
	},

	# rw_2_07 — 充能（能量+机动）
	{
		"id": "rw_2_07",
		"tier": TIER_2,
		"required_runes": ["energy_01", "mobility_01"],
		"min_slot_count": 2,
		"effects": [
			{"stat": "energy_regen", "value": 0.22},
			{"stat": "deploy_speed", "value": 0.22},
		],
		"unlock_requirement": null,
	},

	# rw_2_08 — 闪避（机动+特殊）
	{
		"id": "rw_2_08",
		"tier": TIER_2,
		"required_runes": ["mobility_02", "special_02"],
		"min_slot_count": 2,
		"effects": [
			{"stat": "dodge", "value": 0.20},
			{"stat": "hp", "value": 0.12},
		],
		"unlock_requirement": null,
	},

	# rw_2_09 — 穿透（攻击+机动）
	{
		"id": "rw_2_09",
		"tier": TIER_2,
		"required_runes": ["attack_03", "mobility_01"],
		"min_slot_count": 2,
		"effects": [
			{"stat": "attack_speed", "value": 0.25},
			{"stat": "deploy_speed", "value": 0.15},
		],
		"unlock_requirement": null,
	},

	# rw_2_10 — 再生（防御+特殊）
	{
		"id": "rw_2_10",
		"tier": TIER_2,
		"required_runes": ["defense_06", "special_02"],
		"min_slot_count": 2,
		"effects": [
			{"stat": "hp", "value": 0.20},
			{"stat": "hp_regen", "value": 0.08},
		],
		"unlock_requirement": null,
	},

	# rw_2_11 — 破阵（攻击+能量）
	{
		"id": "rw_2_11",
		"tier": TIER_2,
		"required_runes": ["attack_05", "energy_03"],
		"min_slot_count": 2,
		"effects": [
			{"stat": "attack", "value": 0.20},
			{"stat": "energy_cost_reduction", "value": 0.12},
		],
		"unlock_requirement": null,
	},

	# rw_2_12 — 壁垒（防御+防御 高级）
	{
		"id": "rw_2_12",
		"tier": TIER_2,
		"required_runes": ["defense_04", "defense_05"],
		"min_slot_count": 2,
		"effects": [
			{"stat": "hp", "value": 0.25},
			{"stat": "damage_reduction", "value": 0.10},
		],
		"unlock_requirement": null,
	},

	# rw_2_13 — 回响（特殊+能量）
	{
		"id": "rw_2_13",
		"tier": TIER_2,
		"required_runes": ["special_01", "energy_04"],
		"min_slot_count": 2,
		"effects": [
			{"stat": "attack", "value": 0.12},
			{"stat": "energy_regen", "value": 0.20},
			{"special": "on_kill_regen_energy", "chance": 0.30, "value": 50},
		],
		"unlock_requirement": null,
	},

	# rw_2_14 — 迅捷（机动+机动 高级）
	{
		"id": "rw_2_14",
		"tier": TIER_2,
		"required_runes": ["mobility_03", "mobility_04"],
		"min_slot_count": 2,
		"effects": [
			{"stat": "dodge", "value": 0.22},
			{"stat": "deploy_speed", "value": 0.22},
		],
		"unlock_requirement": null,
	},

	# rw_2_15 — 共鸣（攻击+特殊）
	{
		"id": "rw_2_15",
		"tier": TIER_2,
		"required_runes": ["attack_02", "special_01"],
		"min_slot_count": 2,
		"effects": [
			{"stat": "attack", "value": 0.15},
			{"stat": "attack_speed", "value": 0.10},
			{"special": "on_kill_regen_energy", "chance": 0.25, "value": 40},
		],
		"unlock_requirement": null,
	},

	# rw_2_16 — 锋刃（攻击+攻击 高级）
	{
		"id": "rw_2_16",
		"tier": TIER_2,
		"required_runes": ["attack_04", "attack_05"],
		"min_slot_count": 2,
		"effects": [
			{"stat": "attack", "value": 0.30},
			{"stat": "crit", "value": 0.08},
		],
		"unlock_requirement": null,
	},

	# rw_2_17 — 铁幕（防御+特殊 防御向）
	{
		"id": "rw_2_17",
		"tier": TIER_2,
		"required_runes": ["defense_07", "special_04"],
		"min_slot_count": 2,
		"effects": [
			{"stat": "damage_reduction", "value": 0.15},
			{"stat": "hp", "value": 0.15},
		],
		"unlock_requirement": null,
	},

	# rw_2_18 — 循环（能量+能量 高级）
	{
		"id": "rw_2_18",
		"tier": TIER_2,
		"required_runes": ["energy_04", "energy_05"],
		"min_slot_count": 2,
		"effects": [
			{"stat": "energy_regen", "value": 0.40},
			{"stat": "energy_cost_reduction", "value": 0.12},
		],
		"unlock_requirement": null,
	},

	# rw_2_19 — 风暴前奏（攻击+特殊 触发型）
	{
		"id": "rw_2_19",
		"tier": TIER_2,
		"required_runes": ["attack_06", "special_03"],
		"min_slot_count": 2,
		"effects": [
			{"stat": "accuracy", "value": 0.20},
			{"special": "on_hit_chain_lightning", "chance": 0.15, "value": 10},
		],
		"unlock_requirement": null,
	},

	# rw_2_20 — 潜行（机动+特殊 闪避向）
	{
		"id": "rw_2_20",
		"tier": TIER_2,
		"required_runes": ["mobility_05", "special_02"],
		"min_slot_count": 2,
		"effects": [
			{"stat": "dodge", "value": 0.25},
			{"stat": "deploy_speed", "value": 0.15},
		],
		"unlock_requirement": null,
	},

	# rw_2_21 — 专注（攻击+特殊 精准向）
	{
		"id": "rw_2_21",
		"tier": TIER_2,
		"required_runes": ["attack_06", "special_05"],
		"min_slot_count": 2,
		"effects": [
			{"stat": "accuracy", "value": 0.25},
			{"stat": "attack", "value": 0.12},
		],
		"unlock_requirement": null,
	},

	# rw_2_22 — 护佑（防御+特殊 护盾向）
	{
		"id": "rw_2_22",
		"tier": TIER_2,
		"required_runes": ["defense_07", "special_04"],
		"min_slot_count": 2,
		"effects": [
			{"stat": "damage_reduction", "value": 0.12},
			{"special": "on_energy_shield", "chance": 0.15, "value": 100},
		],
		"unlock_requirement": null,
	},

	# rw_2_23 — 积聚（能量+特殊 资源向）
	{
		"id": "rw_2_23",
		"tier": TIER_2,
		"required_runes": ["energy_06", "special_06"],
		"min_slot_count": 2,
		"effects": [
			{"stat": "energy_regen", "value": 0.30},
			{"special": "on_resource_yield", "chance": 1.0, "value": 20},
		],
		"unlock_requirement": null,
	},

	# rw_2_24 — 激流（机动+能量 高级）
	{
		"id": "rw_2_24",
		"tier": TIER_2,
		"required_runes": ["mobility_04", "energy_05"],
		"min_slot_count": 2,
		"effects": [
			{"stat": "deploy_speed", "value": 0.25},
			{"stat": "energy_regen", "value": 0.25},
		],
		"unlock_requirement": null,
	},

	# rw_2_25 — 稳态（防御+机动 均衡）
	{
		"id": "rw_2_25",
		"tier": TIER_2,
		"required_runes": ["defense_06", "mobility_03"],
		"min_slot_count": 2,
		"effects": [
			{"stat": "hp", "value": 0.18},
			{"stat": "dodge", "value": 0.15},
		],
		"unlock_requirement": null,
	},

	# ═══════════════════════════════════════════════════════════════
	# 3符文之语（20种）— 中等稀有，需3槽位
	# ═══════════════════════════════════════════════════════════════

	# rw_3_01 — 三相之力（攻防均衡）
	{
		"id": "rw_3_01",
		"tier": TIER_3,
		"required_runes": ["attack_01", "defense_01", "energy_01"],
		"min_slot_count": 3,
		"effects": [
			{"stat": "attack", "value": 0.20},
			{"stat": "hp", "value": 0.20},
			{"stat": "energy_regen", "value": 0.20},
		],
		"unlock_requirement": null,
	},

	# rw_3_02 — 战阵（纯攻击）
	{
		"id": "rw_3_02",
		"tier": TIER_3,
		"required_runes": ["attack_04", "attack_05", "attack_07"],
		"min_slot_count": 3,
		"effects": [
			{"stat": "attack", "value": 0.40},
			{"stat": "attack_speed", "value": 0.15},
		],
		"unlock_requirement": null,
	},

	# rw_3_03 — 守护者（纯防御）
	{
		"id": "rw_3_03",
		"tier": TIER_3,
		"required_runes": ["defense_04", "defense_05", "defense_07"],
		"min_slot_count": 3,
		"effects": [
			{"stat": "hp", "value": 0.45},
			{"stat": "damage_reduction", "value": 0.15},
		],
		"unlock_requirement": null,
	},

	# rw_3_04 — 灵能（纯能量）
	{
		"id": "rw_3_04",
		"tier": TIER_3,
		"required_runes": ["energy_04", "energy_05", "energy_06"],
		"min_slot_count": 3,
		"effects": [
			{"stat": "energy_regen", "value": 0.60},
			{"stat": "energy_cost_reduction", "value": 0.20},
		],
		"unlock_requirement": null,
	},

	# rw_3_05 — 破甲者（攻击+穿透）
	{
		"id": "rw_3_05",
		"tier": TIER_3,
		"required_runes": ["attack_04", "attack_06", "attack_08"],
		"min_slot_count": 3,
		"effects": [
			{"stat": "attack", "value": 0.35},
			{"stat": "accuracy", "value": 0.25},
			{"stat": "crit", "value": 0.15},
		],
		"unlock_requirement": null,
	},

	# rw_3_06 — 坚不可摧（防御+特殊 复活）
	{
		"id": "rw_3_06",
		"tier": TIER_3,
		"required_runes": ["defense_07", "defense_08", "special_02"],
		"min_slot_count": 3,
		"effects": [
			{"stat": "hp", "value": 0.40},
			{"stat": "damage_reduction", "value": 0.15},
			{"special": "on_death_respawn", "chance": 0.10, "value": 100},
		],
		"unlock_requirement": null,
	},

	# rw_3_07 — 能量风暴（能量+特殊 回能）
	{
		"id": "rw_3_07",
		"tier": TIER_3,
		"required_runes": ["energy_05", "special_01", "special_06"],
		"min_slot_count": 3,
		"effects": [
			{"stat": "energy_regen", "value": 0.40},
			{"stat": "attack", "value": 0.15},
			{"special": "on_kill_regen_energy", "chance": 0.40, "value": 80},
		],
		"unlock_requirement": null,
	},

	# rw_3_08 — 幻影刺客（机动+特殊 闪避暴击）
	{
		"id": "rw_3_08",
		"tier": TIER_3,
		"required_runes": ["mobility_04", "mobility_05", "special_03"],
		"min_slot_count": 3,
		"effects": [
			{"stat": "dodge", "value": 0.30},
			{"stat": "deploy_speed", "value": 0.25},
			{"special": "on_hit_chain_lightning", "chance": 0.20, "value": 15},
		],
		"unlock_requirement": null,
	},

	# rw_3_09 — 雷霆（攻击+特殊 闪电链）
	{
		"id": "rw_3_09",
		"tier": TIER_3,
		"required_runes": ["attack_07", "special_03", "special_05"],
		"min_slot_count": 3,
		"effects": [
			{"stat": "attack", "value": 0.30},
			{"stat": "accuracy", "value": 0.20},
			{"special": "on_hit_chain_lightning", "chance": 0.25, "value": 20},
		],
		"unlock_requirement": null,
	},

	# rw_3_10 — 再生壁垒（防御+特殊 持续恢复）
	{
		"id": "rw_3_10",
		"tier": TIER_3,
		"required_runes": ["defense_06", "defense_07", "special_04"],
		"min_slot_count": 3,
		"effects": [
			{"stat": "hp", "value": 0.35},
			{"stat": "hp_regen", "value": 0.12},
			{"special": "on_energy_shield", "chance": 0.20, "value": 120},
		],
		"unlock_requirement": null,
	},

	# rw_3_11 — 疾风怒涛（机动+攻击 速攻流）
	{
		"id": "rw_3_11",
		"tier": TIER_3,
		"required_runes": ["mobility_04", "mobility_05", "attack_03"],
		"min_slot_count": 3,
		"effects": [
			{"stat": "deploy_speed", "value": 0.40},
			{"stat": "attack_speed", "value": 0.25},
		],
		"unlock_requirement": null,
	},

	# rw_3_12 — 磐石之心（防御+防御+防御 极限防御）
	{
		"id": "rw_3_12",
		"tier": TIER_3,
		"required_runes": ["defense_05", "defense_07", "defense_08"],
		"min_slot_count": 3,
		"effects": [
			{"stat": "hp", "value": 0.50},
			{"stat": "defense", "value": 0.30},
			{"stat": "damage_reduction", "value": 0.15},
		],
		"unlock_requirement": null,
	},

	# rw_3_13 — 永动（能量+特殊 无限能量）
	{
		"id": "rw_3_13",
		"tier": TIER_3,
		"required_runes": ["energy_05", "energy_06", "special_01"],
		"min_slot_count": 3,
		"effects": [
			{"stat": "energy_regen", "value": 0.50},
			{"stat": "energy_cost_reduction", "value": 0.18},
			{"special": "on_kill_regen_energy", "chance": 0.35, "value": 60},
		],
		"unlock_requirement": null,
	},

	# rw_3_14 — 致命精准（攻击+特殊 暴击流）
	{
		"id": "rw_3_14",
		"tier": TIER_3,
		"required_runes": ["attack_05", "attack_08", "special_05"],
		"min_slot_count": 3,
		"effects": [
			{"stat": "attack", "value": 0.35},
			{"stat": "crit", "value": 0.20},
			{"stat": "accuracy", "value": 0.20},
		],
		"unlock_requirement": null,
	},

	# rw_3_15 — 圣盾守卫（防御+特殊 完整防护）
	{
		"id": "rw_3_15",
		"tier": TIER_3,
		"required_runes": ["defense_07", "special_02", "special_04"],
		"min_slot_count": 3,
		"effects": [
			{"stat": "hp", "value": 0.35},
			{"stat": "damage_reduction", "value": 0.18},
			{"special": "on_death_respawn", "chance": 0.12, "value": 100},
			{"special": "on_energy_shield", "chance": 0.20, "value": 150},
		],
		"unlock_requirement": null,
	},

	# rw_3_16 — 深渊（攻击+特殊+特殊 破甲溅射）
	{
		"id": "rw_3_16",
		"tier": TIER_3,
		"required_runes": ["attack_07", "special_03", "special_05"],
		"min_slot_count": 3,
		"effects": [
			{"stat": "attack", "value": 0.30},
			{"special": "on_hit_chain_lightning", "chance": 0.20, "value": 18},
			{"special": "on_attack_penetration", "chance": 1.0, "value": 20},
		],
		"unlock_requirement": null,
	},

	# rw_3_17 — 光辉（全属性均衡 高级）
	{
		"id": "rw_3_17",
		"tier": TIER_3,
		"required_runes": ["attack_06", "defense_07", "energy_05"],
		"min_slot_count": 3,
		"effects": [
			{"stat": "attack", "value": 0.22},
			{"stat": "hp", "value": 0.22},
			{"stat": "energy_regen", "value": 0.22},
		],
		"unlock_requirement": null,
	},

	# rw_3_18 — 暗影（机动+特殊 潜行暴击）
	{
		"id": "rw_3_18",
		"tier": TIER_3,
		"required_runes": ["mobility_05", "special_02", "special_03"],
		"min_slot_count": 3,
		"effects": [
			{"stat": "dodge", "value": 0.30},
			{"stat": "attack", "value": 0.18},
			{"special": "on_hit_chain_lightning", "chance": 0.18, "value": 15},
		],
		"unlock_requirement": null,
	},

	# rw_3_19 — 烈焰（攻击+攻击+特殊 燃烧流）
	{
		"id": "rw_3_19",
		"tier": TIER_3,
		"required_runes": ["attack_05", "attack_07", "special_03"],
		"min_slot_count": 3,
		"effects": [
			{"stat": "attack", "value": 0.35},
			{"stat": "attack_speed", "value": 0.15},
			{"special": "on_area_damage", "chance": 0.20, "value": 15},
		],
		"unlock_requirement": null,
	},

	# rw_3_20 — 冰封（防御+机动+特殊 冰冻减伤）
	{
		"id": "rw_3_20",
		"tier": TIER_3,
		"required_runes": ["defense_07", "mobility_04", "special_04"],
		"min_slot_count": 3,
		"effects": [
			{"stat": "hp", "value": 0.30},
			{"stat": "dodge", "value": 0.20},
			{"stat": "damage_reduction", "value": 0.12},
			{"special": "on_energy_shield", "chance": 0.18, "value": 130},
		],
		"unlock_requirement": null,
	},

	# ═══════════════════════════════════════════════════════════════
	# 4符文之语（15种）— 稀有，需4槽位
	# ═══════════════════════════════════════════════════════════════

	# rw_4_01 — 战神（极限攻击）
	{
		"id": "rw_4_01",
		"tier": TIER_4,
		"required_runes": ["attack_05", "attack_07", "attack_08", "special_03"],
		"min_slot_count": 4,
		"effects": [
			{"stat": "attack", "value": 0.55},
			{"stat": "attack_speed", "value": 0.20},
			{"stat": "crit", "value": 0.18},
			{"special": "on_hit_chain_lightning", "chance": 0.25, "value": 22},
		],
		"unlock_requirement": null,
	},

	# rw_4_02 — 不灭（极限防御+复活）
	{
		"id": "rw_4_02",
		"tier": TIER_4,
		"required_runes": ["defense_06", "defense_07", "defense_08", "special_02"],
		"min_slot_count": 4,
		"effects": [
			{"stat": "hp", "value": 0.65},
			{"stat": "damage_reduction", "value": 0.20},
			{"stat": "hp_regen", "value": 0.15},
			{"special": "on_death_respawn", "chance": 0.15, "value": 100},
		],
		"unlock_requirement": null,
	},

	# rw_4_03 — 永恒能量（极限能量）
	{
		"id": "rw_4_03",
		"tier": TIER_4,
		"required_runes": ["energy_04", "energy_05", "energy_06", "special_01"],
		"min_slot_count": 4,
		"effects": [
			{"stat": "energy_regen", "value": 0.80},
			{"stat": "energy_cost_reduction", "value": 0.25},
			{"stat": "attack", "value": 0.18},
			{"special": "on_kill_regen_energy", "chance": 0.45, "value": 100},
		],
		"unlock_requirement": null,
	},

	# rw_4_04 — 幻象大师（极限机动+闪避）
	{
		"id": "rw_4_04",
		"tier": TIER_4,
		"required_runes": ["mobility_02", "mobility_03", "mobility_04", "mobility_05"],
		"min_slot_count": 4,
		"effects": [
			{"stat": "dodge", "value": 0.45},
			{"stat": "deploy_speed", "value": 0.40},
			{"stat": "attack_speed", "value": 0.15},
		],
		"unlock_requirement": null,
	},

	# rw_4_05 — 破灭者（攻击+穿透+溅射）
	{
		"id": "rw_4_05",
		"tier": TIER_4,
		"required_runes": ["attack_04", "attack_07", "attack_08", "special_05"],
		"min_slot_count": 4,
		"effects": [
			{"stat": "attack", "value": 0.50},
			{"stat": "accuracy", "value": 0.30},
			{"stat": "crit", "value": 0.20},
			{"special": "on_attack_penetration", "chance": 1.0, "value": 25},
		],
		"unlock_requirement": null,
	},

	# rw_4_06 — 神圣壁垒（防御+护盾+减伤）
	{
		"id": "rw_4_06",
		"tier": TIER_4,
		"required_runes": ["defense_05", "defense_07", "defense_08", "special_04"],
		"min_slot_count": 4,
		"effects": [
			{"stat": "hp", "value": 0.55},
			{"stat": "damage_reduction", "value": 0.22},
			{"special": "on_energy_shield", "chance": 0.25, "value": 180},
		],
		"unlock_requirement": null,
	},

	# rw_4_07 — 雷霆之怒（攻击+闪电链+溅射）
	{
		"id": "rw_4_07",
		"tier": TIER_4,
		"required_runes": ["attack_07", "attack_08", "special_03", "special_05"],
		"min_slot_count": 4,
		"effects": [
			{"stat": "attack", "value": 0.45},
			{"stat": "accuracy", "value": 0.25},
			{"special": "on_hit_chain_lightning", "chance": 0.30, "value": 25},
			{"special": "on_area_damage", "chance": 0.25, "value": 20},
		],
		"unlock_requirement": null,
	},

	# rw_4_08 — 再生之灵（防御+恢复+复活）
	{
		"id": "rw_4_08",
		"tier": TIER_4,
		"required_runes": ["defense_06", "defense_08", "special_02", "special_04"],
		"min_slot_count": 4,
		"effects": [
			{"stat": "hp", "value": 0.50},
			{"stat": "hp_regen", "value": 0.20},
			{"special": "on_death_respawn", "chance": 0.18, "value": 100},
			{"special": "on_energy_shield", "chance": 0.22, "value": 160},
		],
		"unlock_requirement": null,
	},

	# rw_4_09 — 风暴召唤（全属性+闪电）
	{
		"id": "rw_4_09",
		"tier": TIER_4,
		"required_runes": ["attack_07", "defense_07", "energy_05", "special_03"],
		"min_slot_count": 4,
		"effects": [
			{"stat": "attack", "value": 0.30},
			{"stat": "hp", "value": 0.30},
			{"stat": "energy_regen", "value": 0.30},
			{"special": "on_hit_chain_lightning", "chance": 0.28, "value": 22},
		],
		"unlock_requirement": null,
	},

	# rw_4_10 — 深渊之握（攻击+破甲+溅射+穿透）
	{
		"id": "rw_4_10",
		"tier": TIER_4,
		"required_runes": ["attack_04", "attack_08", "special_03", "special_05"],
		"min_slot_count": 4,
		"effects": [
			{"stat": "attack", "value": 0.45},
			{"stat": "crit", "value": 0.18},
			{"special": "on_attack_penetration", "chance": 1.0, "value": 28},
			{"special": "on_area_damage", "chance": 0.22, "value": 18},
		],
		"unlock_requirement": null,
	},

	# rw_4_11 — 光辉圣殿（防御+能量+恢复+护盾）
	{
		"id": "rw_4_11",
		"tier": TIER_4,
		"required_runes": ["defense_07", "energy_05", "special_04", "special_05"],
		"min_slot_count": 4,
		"effects": [
			{"stat": "hp", "value": 0.40},
			{"stat": "energy_regen", "value": 0.35},
			{"stat": "damage_reduction", "value": 0.15},
			{"special": "on_energy_shield", "chance": 0.25, "value": 170},
		],
		"unlock_requirement": null,
	},

	# rw_4_12 — 暗影契约（机动+攻击+暴击+闪避）
	{
		"id": "rw_4_12",
		"tier": TIER_4,
		"required_runes": ["mobility_05", "attack_08", "special_02", "special_03"],
		"min_slot_count": 4,
		"effects": [
			{"stat": "dodge", "value": 0.35},
			{"stat": "attack", "value": 0.35},
			{"stat": "crit", "value": 0.15},
			{"special": "on_hit_chain_lightning", "chance": 0.22, "value": 20},
		],
		"unlock_requirement": null,
	},

	# rw_4_13 — 烈焰风暴（攻击+攻速+溅射+燃烧）
	{
		"id": "rw_4_13",
		"tier": TIER_4,
		"required_runes": ["attack_05", "attack_07", "special_03", "special_06"],
		"min_slot_count": 4,
		"effects": [
			{"stat": "attack", "value": 0.42},
			{"stat": "attack_speed", "value": 0.22},
			{"special": "on_area_damage", "chance": 0.28, "value": 22},
			{"special": "on_resource_yield", "chance": 1.0, "value": 25},
		],
		"unlock_requirement": null,
	},

	# rw_4_14 — 冰封王座（防御+闪避+护盾+减伤）
	{
		"id": "rw_4_14",
		"tier": TIER_4,
		"required_runes": ["defense_08", "mobility_05", "special_02", "special_04"],
		"min_slot_count": 4,
		"effects": [
			{"stat": "hp", "value": 0.45},
			{"stat": "dodge", "value": 0.25},
			{"stat": "damage_reduction", "value": 0.18},
			{"special": "on_energy_shield", "chance": 0.25, "value": 180},
		],
		"unlock_requirement": null,
	},

	# rw_4_15 — 命运（全属性均衡 极致）
	{
		"id": "rw_4_15",
		"tier": TIER_4,
		"required_runes": ["attack_08", "defense_08", "energy_06", "mobility_05"],
		"min_slot_count": 4,
		"effects": [
			{"stat": "attack", "value": 0.30},
			{"stat": "hp", "value": 0.30},
			{"stat": "energy_regen", "value": 0.30},
			{"stat": "deploy_speed", "value": 0.25},
		],
		"unlock_requirement": null,
	},

	# ═══════════════════════════════════════════════════════════════
	# 5符文之语（5种）— 传说，需5槽位，效果极强
	# ═══════════════════════════════════════════════════════════════

	# rw_5_01 — 诸神黄昏（极致攻击+多重特效）
	{
		"id": "rw_5_01",
		"tier": TIER_5,
		"required_runes": ["attack_05", "attack_07", "attack_08", "special_03", "special_05"],
		"min_slot_count": 5,
		"effects": [
			{"stat": "attack", "value": 0.70},
			{"stat": "attack_speed", "value": 0.25},
			{"stat": "crit", "value": 0.25},
			{"stat": "accuracy", "value": 0.30},
			{"special": "on_hit_chain_lightning", "chance": 0.35, "value": 30},
			{"special": "on_area_damage", "chance": 0.30, "value": 25},
		],
		"unlock_requirement": null,
	},

	# rw_5_02 — 永生（极致防御+复活+恢复）
	{
		"id": "rw_5_02",
		"tier": TIER_5,
		"required_runes": ["defense_06", "defense_07", "defense_08", "special_02", "special_04"],
		"min_slot_count": 5,
		"effects": [
			{"stat": "hp", "value": 0.85},
			{"stat": "damage_reduction", "value": 0.28},
			{"stat": "hp_regen", "value": 0.25},
			{"special": "on_death_respawn", "chance": 0.20, "value": 100},
			{"special": "on_energy_shield", "chance": 0.30, "value": 220},
		],
		"unlock_requirement": null,
	},

	# rw_5_03 — 创世（极致能量+全属性）
	{
		"id": "rw_5_03",
		"tier": TIER_5,
		"required_runes": ["energy_04", "energy_05", "energy_06", "special_01", "special_06"],
		"min_slot_count": 5,
		"effects": [
			{"stat": "energy_regen", "value": 1.00},
			{"stat": "energy_cost_reduction", "value": 0.35},
			{"stat": "attack", "value": 0.30},
			{"stat": "hp", "value": 0.30},
			{"special": "on_kill_regen_energy", "chance": 0.50, "value": 150},
			{"special": "on_resource_yield", "chance": 1.0, "value": 40},
		],
		"unlock_requirement": null,
	},

	# rw_5_04 — 湮灭（极致机动+暴击+多重特效）
	{
		"id": "rw_5_04",
		"tier": TIER_5,
		"required_runes": ["mobility_03", "mobility_04", "mobility_05", "attack_08", "special_03"],
		"min_slot_count": 5,
		"effects": [
			{"stat": "dodge", "value": 0.55},
			{"stat": "deploy_speed", "value": 0.50},
			{"stat": "attack", "value": 0.40},
			{"stat": "crit", "value": 0.25},
			{"special": "on_hit_chain_lightning", "chance": 0.30, "value": 25},
		],
		"unlock_requirement": null,
	},

	# rw_5_05 — 无限（全属性极致+多重特殊效果）
	{
		"id": "rw_5_05",
		"tier": TIER_5,
		"required_runes": ["attack_08", "defense_08", "energy_06", "mobility_05", "special_06"],
		"min_slot_count": 5,
		"effects": [
			{"stat": "attack", "value": 0.45},
			{"stat": "hp", "value": 0.45},
			{"stat": "energy_regen", "value": 0.45},
			{"stat": "deploy_speed", "value": 0.35},
			{"stat": "damage_reduction", "value": 0.20},
			{"special": "on_resource_yield", "chance": 1.0, "value": 50},
			{"special": "on_explore_bonus", "chance": 1.0, "value": 30},
		],
		"unlock_requirement": null,
	},
]

# ── 按ID索引的快速查找表 ──────────────────────────────────────────

static func _build_id_map() -> Dictionary:
	var result: Dictionary = {}
	for rw in ALL_RUNEWORDS:
		result[rw["id"]] = rw
	return result

static var _ID_MAP: Dictionary = _build_id_map()

## 通过ID获取符文之语定义
static func get_runeword(rw_id: String) -> Dictionary:
	if _ID_MAP.has(rw_id):
		return _ID_MAP[rw_id]
	return {}

## 按层级过滤
static func get_runewords_by_tier(tier: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for rw in ALL_RUNEWORDS:
		if rw["tier"] == tier:
			result.append(rw)
	return result

## 获取符文之语名称（避免与 Object.get_name 冲突）
static func get_runeword_name(rw_id: String) -> String:
	if RUNEWORD_NAMES.has(rw_id):
		return RUNEWORD_NAMES[rw_id]
	return rw_id

## 获取符文之语颜色（按层级）
static func get_color(rw_id: String) -> Color:
	var rw = get_runeword(rw_id)
	var tier = rw.get("tier", TIER_2)
	return TIER_COLORS.get(tier, Color.WHITE)

## 获取符文之语效果描述
static func get_effects_description(rw_id: String) -> String:
	var rw = get_runeword(rw_id)
	if rw.is_empty():
		return ""
	var desc_lines: PackedStringArray = []
	for effect in rw.get("effects", []):
		if effect.has("stat"):
			var stat_name = _stat_display_name(effect["stat"])
			var value = effect["value"]
			if effect["stat"] in ["energy_cost_reduction", "damage_reduction"]:
				desc_lines.append("%s -%d%%" % [stat_name, int(value * 100)])
			else:
				desc_lines.append("%s +%d%%" % [stat_name, int(value * 100)])
		elif effect.has("special"):
			var special_name = _special_display_name(effect["special"])
			var chance = int(effect.get("chance", 1.0) * 100)
			var value = effect["value"]
			desc_lines.append("%s（%d%%概率）" % [special_name, chance])
	return "\n".join(desc_lines)

## 获取所需符文列表的名称
static func get_required_runes_description(rw_id: String) -> String:
	var rw = get_runeword(rw_id)
	if rw.is_empty():
		return ""
	var rune_names: PackedStringArray = []
	for rune_id in rw.get("required_runes", []):
		rune_names.append(RuneDefinitions.get_rune_name(rune_id))
	return " + ".join(rune_names)

# ── 内部辅助 ───────────────────────────────────────────────────────

static func _stat_display_name(stat: String) -> String:
	const NAMES: Dictionary = {
		"attack": "攻击力",
		"defense": "防御力",
		"hp": "生命值",
		"attack_speed": "攻击速度",
		"deploy_speed": "部署速度",
		"energy_regen": "能量恢复",
		"energy_cost_reduction": "能量消耗",
		"range": "射程",
		"dodge": "闪避率",
		"crit": "暴击率",
		"accuracy": "命中率",
		"hp_regen": "生命恢复",
		"damage_reduction": "伤害减免",
	}
	return NAMES.get(stat, stat)

static func _special_display_name(special: String) -> String:
	const NAMES: Dictionary = {
		"on_kill_regen_energy": "击杀回能",
		"on_hit_chain_lightning": "闪电链",
		"on_death_respawn": "死亡复活",
		"on_deploy_speed_up": "部署加速",
		"on_attack_penetration": "攻击穿透",
		"on_area_damage": "溅射伤害",
		"on_damage_reduction": "伤害减免",
		"on_energy_shield": "能量护盾",
		"on_explore_bonus": "探索奖励",
		"on_resource_yield": "资源产出",
	}
	return NAMES.get(special, special)

# ── 统计信息 ───────────────────────────────────────────────────────

static func get_count_by_tier() -> Dictionary:
	var counts: Dictionary = {}
	for tier in ALL_TIERS:
		counts[tier] = len(get_runewords_by_tier(tier))
	return counts

## 获取所有符文之语ID
static func get_all_ids() -> Array[String]:
	var ids: Array[String] = []
	for rw in ALL_RUNEWORDS:
		ids.append(rw["id"])
	return ids
