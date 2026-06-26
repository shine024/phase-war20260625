extends RefCounted
class_name RuneDefinitions
## 符文定义（33个，参考暗黑2经典数量）
##
## 符文插在相位仪的符文槽位上，提供基础数值加成。
## 多个符文组合可激活「符文之语」，提供额外强力加成。
##
## 符文分类：
##   attack     — 攻击符文（8个）：攻击力/攻速/穿透
##   defense    — 防御符文（8个）：HP/防御/减伤
##   energy     — 能量符文（6个）：能量恢复/上限/消耗减免
##   mobility   — 机动符文（5个）：部署速度/闪避/移速
##   special    — 特殊符文（6个）：概率触发特殊效果
##
## 稀有度阶梯：
##   common(10) — 战斗掉落所有Wave
##   rare(12)   — 势力商店 + 中高阶掉落
##   epic(7)    — 势力声望兑换 + 相位大师
##   legendary(4) — 相位大师掉落 + 高声望兑换

# ── 分类常量 ─────────────────────────────────────────────────────────

const CAT_ATTACK: String = "attack"
const CAT_DEFENSE: String = "defense"
const CAT_ENERGY: String = "energy"
const CAT_MOBILITY: String = "mobility"
const CAT_SPECIAL: String = "special"

const ALL_CATEGORIES: Array[String] = [CAT_ATTACK, CAT_DEFENSE, CAT_ENERGY, CAT_MOBILITY, CAT_SPECIAL]

# ── 稀有度常量 ──────────────────────────────────────────────────────

const RARITY_COMMON: String = "common"
const RARITY_RARE: String = "rare"
const RARITY_EPIC: String = "epic"
const RARITY_LEGENDARY: String = "legendary"

const RARITY_ORDER: Array[String] = [RARITY_COMMON, RARITY_RARE, RARITY_EPIC, RARITY_LEGENDARY]

const RARITY_COLORS: Dictionary = {
	RARITY_COMMON: Color(0.85, 0.85, 0.85),    # 灰色
	RARITY_RARE: Color(0.2, 0.5, 0.95),         # 蓝色
	RARITY_EPIC: Color(0.65, 0.25, 0.9),        # 紫色
	RARITY_LEGENDARY: Color(0.95, 0.65, 0.15),  # 金色
}

const RARITY_NAMES: Dictionary = {
	RARITY_COMMON: "常见",
	RARITY_RARE: "稀有",
	RARITY_EPIC: "史诗",
	RARITY_LEGENDARY: "传说",
}

# ── 属性类型常量 ───────────────────────────────────────────────────

const STAT_ATTACK: String = "attack"
const STAT_DEFENSE: String = "defense"
const STAT_HP: String = "hp"
const STAT_ATTACK_SPEED: String = "attack_speed"
const STAT_DEPLOY_SPEED: String = "deploy_speed"
const STAT_ENERGY_REGEN: String = "energy_regen"
const STAT_ENERGY_COST_REDUCTION: String = "energy_cost_reduction"
const STAT_RANGE: String = "range"
const STAT_DODGE: String = "dodge"
const STAT_CRIT: String = "crit"
const STAT_ACCURACY: String = "accuracy"
const STAT_HP_REGEN: String = "hp_regen"
const STAT_DAMAGE_REDUCTION: String = "damage_reduction"
const STAT_ATTACK_PENETRATION: String = "attack_penetration"

# ── 特殊效果常量 ───────────────────────────────────────────────────

const SPECIAL_ON_KILL_REGEN_ENERGY: String = "on_kill_regen_energy"
const SPECIAL_ON_HIT_CHAIN_LIGHTNING: String = "on_hit_chain_lightning"
const SPECIAL_ON_DEATH_RESPAWN: String = "on_death_respawn"
const SPECIAL_ON_DEPLOY_SPEED_UP: String = "on_deploy_speed_up"
const SPECIAL_ON_ATTACK_PENETRATION: String = "on_attack_penetration"
const SPECIAL_ON_AREA_DAMAGE: String = "on_area_damage"
const SPECIAL_ON_DAMAGE_REDUCTION: String = "on_damage_reduction"
const SPECIAL_ON_ENERGY_SHIELD: String = "on_energy_shield"
const SPECIAL_ON_EXPLORE_BONUS: String = "on_explore_bonus"
const SPECIAL_ON_RESOURCE_YIELD: String = "on_resource_yield"

const ALL_SPECIALS: Array[String] = [
	SPECIAL_ON_KILL_REGEN_ENERGY,
	SPECIAL_ON_HIT_CHAIN_LIGHTNING,
	SPECIAL_ON_DEATH_RESPAWN,
	SPECIAL_ON_DEPLOY_SPEED_UP,
	SPECIAL_ON_ATTACK_PENETRATION,
	SPECIAL_ON_AREA_DAMAGE,
	SPECIAL_ON_DAMAGE_REDUCTION,
	SPECIAL_ON_ENERGY_SHIELD,
	SPECIAL_ON_EXPLORE_BONUS,
	SPECIAL_ON_RESOURCE_YIELD,
]

# ── 势力ID ─────────────────────────────────────────────────────────

const FACTION_GENERIC: String = "generic"

# ── 符文名称表 ─────────────────────────────────────────────────────

const RUNE_NAMES: Dictionary = {
	# 攻击符文（8个）
	"attack_01": "力量",
	"attack_02": "锐锋",
	"attack_03": "疾风",
	"attack_04": "破甲",
	"attack_05": "爆裂",
	"attack_06": "精准",
	"attack_07": "狂暴",
	"attack_08": "致命",
	# 防御符文（8个）
	"defense_01": "坚韧",
	"defense_02": "守护",
	"defense_03": "壁垒",
	"defense_04": "磐石",
	"defense_05": "铁壁",
	"defense_06": "不屈",
	"defense_07": "圣盾",
	"defense_08": "不朽",
	# 能量符文（6个）
	"energy_01": "涌动",
	"energy_02": "源泉",
	"energy_03": "节制",
	"energy_04": "充盈",
	"energy_05": "超载",
	"energy_06": "永恒",
	# 机动符文（5个）
	"mobility_01": "迅捷",
	"mobility_02": "幻影",
	"mobility_03": "诡步",
	"mobility_04": "瞬移",
	"mobility_05": "风行",
	# 特殊符文（6个）
	"special_01": "掠夺",
	"special_02": "重生",
	"special_03": "连锁",
	"special_04": "庇护",
	"special_05": "洞察",
	"special_06": "丰收",
	# 势力专属符文（18个）
	# aether_dynamics（神盾）
	"aether_01": "神盾壁垒",
	"aether_02": "神盾穹顶",
	"aether_03": "神盾圣光",
	# helix_recon（螺旋）
	"helix_01": "螺旋疾行",
	"helix_02": "螺旋神经",
	"helix_03": "螺旋幻影",
	# nova_arms（新星）
	"nova_01": "新星炽焰",
	"nova_02": "新星裂变",
	"nova_03": "新星湮灭",
	# iron_wall_corp（铁幕）
	"iron_01": "铁幕铸甲",
	"iron_02": "铁幕王座",
	"iron_03": "铁幕铸魂",
	# void_research（虚空）
	"void_01": "虚空低语",
	"void_02": "虚空深渊",
	"void_03": "虚空裂隙",
	# quantum_logistics（量子物流）
	"quantum_01": "量子工蜂",
	"quantum_02": "量子枢纽",
	"quantum_03": "量子矩阵",
	# frontier_union（边境联盟）
	"frontier_01": "边境均衡",
	"frontier_02": "边境终式",
	"frontier_03": "边境共鸣",
}

# ── 符文定义列表（33个） ──────────────────────────────────────────

const ALL_RUNES: Array[Dictionary] = [
	# ═══════════ 攻击符文（8个，10个常见中的5个） ═══════════

	# attack_01 — 力量（常见）
	{
		"id": "attack_01",
		"category": CAT_ATTACK,
		"rarity": RARITY_COMMON,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 1,
		"primary_effect": {
			"stat": STAT_ATTACK,
			"value": 0.15,
			"scaling": 0.03,
		},
		"secondary_effect": null,
		"desc_primary": "攻击力 +15%",
		"desc_secondary": null,
	},

	# attack_02 — 锐锋（常见）
	{
		"id": "attack_02",
		"category": CAT_ATTACK,
		"rarity": RARITY_COMMON,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 1,
		"primary_effect": {
			"stat": STAT_ATTACK,
			"value": 0.12,
			"scaling": 0.04,
		},
		"secondary_effect": {
			"stat": STAT_ATTACK_SPEED,
			"value": 0.05,
		},
		"desc_primary": "攻击力 +12%",
		"desc_secondary": "攻击速度 +5%",
	},

	# attack_03 — 疾风（常见）
	{
		"id": "attack_03",
		"category": CAT_ATTACK,
		"rarity": RARITY_COMMON,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 1,
		"primary_effect": {
			"stat": STAT_ATTACK_SPEED,
			"value": 0.18,
			"scaling": 0.02,
		},
		"secondary_effect": null,
		"desc_primary": "攻击速度 +18%",
		"desc_secondary": null,
	},

	# attack_04 — 破甲（稀有）
	{
		"id": "attack_04",
		"category": CAT_ATTACK,
		"rarity": RARITY_RARE,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 2,
		"primary_effect": {
			"stat": STAT_ATTACK,
			"value": 0.18,
			"scaling": 0.03,
		},
		"secondary_effect": {
			"stat": STAT_ATTACK_PENETRATION,
			"value": 0.15,
		},
		"desc_primary": "攻击力 +18%",
		"desc_secondary": "穿透 +15%",
	},

	# attack_05 — 爆裂（稀有）
	{
		"id": "attack_05",
		"category": CAT_ATTACK,
		"rarity": RARITY_RARE,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 2,
		"primary_effect": {
			"stat": STAT_ATTACK,
			"value": 0.20,
			"scaling": 0.02,
		},
		"secondary_effect": {
			"stat": STAT_CRIT,
			"value": 0.08,
		},
		"desc_primary": "攻击力 +20%",
		"desc_secondary": "暴击率 +8%",
	},

	# attack_06 — 精准（史诗）
	{
		"id": "attack_06",
		"category": CAT_ATTACK,
		"rarity": RARITY_EPIC,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 3,
		"primary_effect": {
			"stat": STAT_ACCURACY,
			"value": 0.25,
			"scaling": 0.02,
		},
		"secondary_effect": {
			"stat": STAT_ATTACK,
			"value": 0.12,
		},
		"desc_primary": "命中率 +25%",
		"desc_secondary": "攻击力 +12%",
	},

	# attack_07 — 狂暴（史诗）
	{
		"id": "attack_07",
		"category": CAT_ATTACK,
		"rarity": RARITY_EPIC,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 3,
		"primary_effect": {
			"stat": STAT_ATTACK,
			"value": 0.25,
			"scaling": 0.02,
		},
		"secondary_effect": {
			"stat": STAT_ATTACK_SPEED,
			"value": 0.10,
		},
		"desc_primary": "攻击力 +25%",
		"desc_secondary": "攻击速度 +10%",
	},

	# attack_08 — 致命（传说）
	{
		"id": "attack_08",
		"category": CAT_ATTACK,
		"rarity": RARITY_LEGENDARY,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 4,
		"primary_effect": {
			"stat": STAT_ATTACK,
			"value": 0.30,
			"scaling": 0.03,
		},
		"secondary_effect": {
			"stat": STAT_CRIT,
			"value": 0.15,
		},
		"desc_primary": "攻击力 +30%",
		"desc_secondary": "暴击率 +15%",
	},

	# ═══════════ 防御符文（8个） ═══════════

	# defense_01 — 坚韧（常见）
	{
		"id": "defense_01",
		"category": CAT_DEFENSE,
		"rarity": RARITY_COMMON,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 1,
		"primary_effect": {
			"stat": STAT_HP,
			"value": 0.20,
			"scaling": 0.03,
		},
		"secondary_effect": null,
		"desc_primary": "生命值 +20%",
		"desc_secondary": null,
	},

	# defense_02 — 守护（常见）
	{
		"id": "defense_02",
		"category": CAT_DEFENSE,
		"rarity": RARITY_COMMON,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 1,
		"primary_effect": {
			"stat": STAT_DEFENSE,
			"value": 0.15,
			"scaling": 0.03,
		},
		"secondary_effect": {
			"stat": STAT_HP,
			"value": 0.10,
		},
		"desc_primary": "防御力 +15%",
		"desc_secondary": "生命值 +10%",
	},

	# defense_03 — 壁垒（常见）
	{
		"id": "defense_03",
		"category": CAT_DEFENSE,
		"rarity": RARITY_COMMON,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 1,
		"primary_effect": {
			"stat": STAT_DAMAGE_REDUCTION,
			"value": 0.08,
			"scaling": 0.01,
		},
		"secondary_effect": null,
		"desc_primary": "伤害减免 +8%",
		"desc_secondary": null,
	},

	# defense_04 — 磐石（稀有）
	{
		"id": "defense_04",
		"category": CAT_DEFENSE,
		"rarity": RARITY_RARE,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 2,
		"primary_effect": {
			"stat": STAT_HP,
			"value": 0.25,
			"scaling": 0.03,
		},
		"secondary_effect": {
			"stat": STAT_DEFENSE,
			"value": 0.12,
		},
		"desc_primary": "生命值 +25%",
		"desc_secondary": "防御力 +12%",
	},

	# defense_05 — 铁壁（稀有）
	{
		"id": "defense_05",
		"category": CAT_DEFENSE,
		"rarity": RARITY_RARE,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 2,
		"primary_effect": {
			"stat": STAT_DEFENSE,
			"value": 0.20,
			"scaling": 0.02,
		},
		"secondary_effect": {
			"stat": STAT_DAMAGE_REDUCTION,
			"value": 0.05,
		},
		"desc_primary": "防御力 +20%",
		"desc_secondary": "伤害减免 +5%",
	},

	# defense_06 — 不屈（稀有）
	{
		"id": "defense_06",
		"category": CAT_DEFENSE,
		"rarity": RARITY_RARE,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 2,
		"primary_effect": {
			"stat": STAT_HP,
			"value": 0.22,
			"scaling": 0.03,
		},
		"secondary_effect": {
			"stat": STAT_HP_REGEN,
			"value": 0.05,
		},
		"desc_primary": "生命值 +22%",
		"desc_secondary": "生命恢复 +5%",
	},

	# defense_07 — 圣盾（史诗）
	{
		"id": "defense_07",
		"category": CAT_DEFENSE,
		"rarity": RARITY_EPIC,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 3,
		"primary_effect": {
			"stat": STAT_DAMAGE_REDUCTION,
			"value": 0.12,
			"scaling": 0.01,
		},
		"secondary_effect": {
			"stat": STAT_HP,
			"value": 0.15,
		},
		"desc_primary": "伤害减免 +12%",
		"desc_secondary": "生命值 +15%",
	},

	# defense_08 — 不朽（传说）
	{
		"id": "defense_08",
		"category": CAT_DEFENSE,
		"rarity": RARITY_LEGENDARY,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 4,
		"primary_effect": {
			"stat": STAT_HP,
			"value": 0.35,
			"scaling": 0.03,
		},
		"secondary_effect": {
			"stat": STAT_DAMAGE_REDUCTION,
			"value": 0.10,
		},
		"desc_primary": "生命值 +35%",
		"desc_secondary": "伤害减免 +10%",
	},

	# ═══════════ 能量符文（6个） ═══════════

	# energy_01 — 涌动（常见）
	{
		"id": "energy_01",
		"category": CAT_ENERGY,
		"rarity": RARITY_COMMON,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 1,
		"primary_effect": {
			"stat": STAT_ENERGY_REGEN,
			"value": 0.20,
			"scaling": 0.02,
		},
		"secondary_effect": null,
		"desc_primary": "能量恢复 +20%",
		"desc_secondary": null,
	},

	# energy_02 — 源泉（常见）
	{
		"id": "energy_02",
		"category": CAT_ENERGY,
		"rarity": RARITY_COMMON,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 1,
		"primary_effect": {
			"stat": STAT_ENERGY_COST_REDUCTION,
			"value": 0.10,
			"scaling": 0.01,
		},
		"secondary_effect": null,
		"desc_primary": "能量消耗 -10%",
		"desc_secondary": null,
	},

	# energy_03 — 节制（常见）
	{
		"id": "energy_03",
		"category": CAT_ENERGY,
		"rarity": RARITY_COMMON,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 1,
		"primary_effect": {
			"stat": STAT_ENERGY_REGEN,
			"value": 0.15,
			"scaling": 0.02,
		},
		"secondary_effect": {
			"stat": STAT_ENERGY_COST_REDUCTION,
			"value": 0.05,
		},
		"desc_primary": "能量恢复 +15%",
		"desc_secondary": "能量消耗 -5%",
	},

	# energy_04 — 充盈（稀有）
	{
		"id": "energy_04",
		"category": CAT_ENERGY,
		"rarity": RARITY_RARE,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 2,
		"primary_effect": {
			"stat": STAT_ENERGY_REGEN,
			"value": 0.25,
			"scaling": 0.02,
		},
		"secondary_effect": {
			"stat": STAT_ENERGY_COST_REDUCTION,
			"value": 0.08,
		},
		"desc_primary": "能量恢复 +25%",
		"desc_secondary": "能量消耗 -8%",
	},

	# energy_05 — 超载（史诗）
	{
		"id": "energy_05",
		"category": CAT_ENERGY,
		"rarity": RARITY_EPIC,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 3,
		"primary_effect": {
			"stat": STAT_ENERGY_REGEN,
			"value": 0.30,
			"scaling": 0.02,
		},
		"secondary_effect": {
			"stat": STAT_ATTACK,
			"value": 0.10,
		},
		"desc_primary": "能量恢复 +30%",
		"desc_secondary": "攻击力 +10%",
	},

	# energy_06 — 永恒（传说）
	{
		"id": "energy_06",
		"category": CAT_ENERGY,
		"rarity": RARITY_LEGENDARY,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 4,
		"primary_effect": {
			"stat": STAT_ENERGY_REGEN,
			"value": 0.40,
			"scaling": 0.02,
		},
		"secondary_effect": {
			"stat": STAT_ENERGY_COST_REDUCTION,
			"value": 0.15,
		},
		"desc_primary": "能量恢复 +40%",
		"desc_secondary": "能量消耗 -15%",
	},

	# ═══════════ 机动符文（5个） ═══════════

	# mobility_01 — 迅捷（常见）
	{
		"id": "mobility_01",
		"category": CAT_MOBILITY,
		"rarity": RARITY_COMMON,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 1,
		"primary_effect": {
			"stat": STAT_DEPLOY_SPEED,
			"value": 0.20,
			"scaling": 0.02,
		},
		"secondary_effect": null,
		"desc_primary": "部署速度 +20%",
		"desc_secondary": null,
	},

	# mobility_02 — 幻影（稀有）
	{
		"id": "mobility_02",
		"category": CAT_MOBILITY,
		"rarity": RARITY_RARE,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 2,
		"primary_effect": {
			"stat": STAT_DODGE,
			"value": 0.12,
			"scaling": 0.01,
		},
		"secondary_effect": {
			"stat": STAT_DEPLOY_SPEED,
			"value": 0.10,
		},
		"desc_primary": "闪避率 +12%",
		"desc_secondary": "部署速度 +10%",
	},

	# mobility_03 — 诡步（稀有）
	{
		"id": "mobility_03",
		"category": CAT_MOBILITY,
		"rarity": RARITY_RARE,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 2,
		"primary_effect": {
			"stat": STAT_DODGE,
			"value": 0.15,
			"scaling": 0.01,
		},
		"secondary_effect": null,
		"desc_primary": "闪避率 +15%",
		"desc_secondary": null,
	},

	# mobility_04 — 瞬移（史诗）
	{
		"id": "mobility_04",
		"category": CAT_MOBILITY,
		"rarity": RARITY_EPIC,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 3,
		"primary_effect": {
			"stat": STAT_DEPLOY_SPEED,
			"value": 0.25,
			"scaling": 0.02,
		},
		"secondary_effect": {
			"stat": STAT_DODGE,
			"value": 0.10,
		},
		"desc_primary": "部署速度 +25%",
		"desc_secondary": "闪避率 +10%",
	},

	# mobility_05 — 风行（传说）
	{
		"id": "mobility_05",
		"category": CAT_MOBILITY,
		"rarity": RARITY_LEGENDARY,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 4,
		"primary_effect": {
			"stat": STAT_DEPLOY_SPEED,
			"value": 0.30,
			"scaling": 0.02,
		},
		"secondary_effect": {
			"stat": STAT_DODGE,
			"value": 0.15,
		},
		"desc_primary": "部署速度 +30%",
		"desc_secondary": "闪避率 +15%",
	},

	# ═══════════ 特殊符文（6个） ═══════════

	# special_01 — 掠夺（稀有）
	{
		"id": "special_01",
		"category": CAT_SPECIAL,
		"rarity": RARITY_RARE,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 2,
		"primary_effect": {
			"stat": STAT_ATTACK,
			"value": 0.10,
			"scaling": 0.02,
		},
		"secondary_effect": {
			"stat": SPECIAL_ON_KILL_REGEN_ENERGY,
			"chance": 0.30,
			"value": 50,
		},
		"desc_primary": "攻击力 +10%",
		"desc_secondary": "击杀时30%概率恢复50能量",
	},

	# special_02 — 重生（稀有）
	{
		"id": "special_02",
		"category": CAT_SPECIAL,
		"rarity": RARITY_RARE,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 2,
		"primary_effect": {
			"stat": STAT_HP,
			"value": 0.15,
			"scaling": 0.02,
		},
		"secondary_effect": {
			"stat": SPECIAL_ON_DEATH_RESPAWN,
			"chance": 0.10,
			"value": 100,
		},
		"desc_primary": "生命值 +15%",
		"desc_secondary": "死亡时10%概率原地复活",
	},

	# special_03 — 连锁（史诗）
	{
		"id": "special_03",
		"category": CAT_SPECIAL,
		"rarity": RARITY_EPIC,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 3,
		"primary_effect": {
			"stat": STAT_ATTACK,
			"value": 0.15,
			"scaling": 0.02,
		},
		"secondary_effect": {
			"stat": SPECIAL_ON_HIT_CHAIN_LIGHTNING,
			"chance": 0.15,
			"value": 10,
		},
		"desc_primary": "攻击力 +15%",
		"desc_secondary": "攻击时15%概率触发闪电链",
	},

	# special_04 — 庇护（史诗）
	{
		"id": "special_04",
		"category": CAT_SPECIAL,
		"rarity": RARITY_EPIC,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 3,
		"primary_effect": {
			"stat": STAT_DAMAGE_REDUCTION,
			"value": 0.08,
			"scaling": 0.01,
		},
		"secondary_effect": {
			"stat": SPECIAL_ON_ENERGY_SHIELD,
			"chance": 0.15,
			"value": 100,
		},
		"desc_primary": "伤害减免 +8%",
		"desc_secondary": "受击时15%概率生成护盾",
	},

	# special_05 — 洞察（史诗）
	{
		"id": "special_05",
		"category": CAT_SPECIAL,
		"rarity": RARITY_EPIC,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 3,
		"primary_effect": {
			"stat": STAT_ACCURACY,
			"value": 0.20,
			"scaling": 0.02,
		},
		"secondary_effect": {
			"stat": SPECIAL_ON_EXPLORE_BONUS,
			"chance": 1.0,
			"value": 25,
		},
		"desc_primary": "命中率 +20%",
		"desc_secondary": "探索奖励 +25%",
	},

	# special_06 — 丰收（传说）
	{
		"id": "special_06",
		"category": CAT_SPECIAL,
		"rarity": RARITY_LEGENDARY,
		"faction_id": FACTION_GENERIC,
		"star_requirement": 4,
		"primary_effect": {
			"stat": STAT_ATTACK,
			"value": 0.15,
			"scaling": 0.02,
		},
		"secondary_effect": {
			"stat": SPECIAL_ON_RESOURCE_YIELD,
			"chance": 1.0,
			"value": 30,
		},
		"desc_primary": "攻击力 +15%",
		"desc_secondary": "资源产出 +30%",
	},

	# ═══════════ 势力专属符文（18个，每势力2-3个） ═══════════
	# 需要对应势力声望达到 unlock_requirement.min_reputation 才能解锁

	# ── aether_dynamics（神盾）防御特化 3个 ──

	# aether_01 — 神盾壁垒（稀有）
	{
		"id": "aether_01",
		"category": CAT_DEFENSE,
		"rarity": RARITY_RARE,
		"faction_id": "aether_dynamics",
		"star_requirement": 2,
		"unlock_requirement": {"faction_id": "aether_dynamics", "min_reputation": 800},
		"primary_effect": {"stat": STAT_HP, "value": 0.28, "scaling": 0.03},
		"secondary_effect": {"stat": STAT_DAMAGE_REDUCTION, "value": 0.06},
		"desc_primary": "生命值 +28%",
		"desc_secondary": "伤害减免 +6%",
	},

	# aether_02 — 神盾穹顶（史诗）
	{
		"id": "aether_02",
		"category": CAT_DEFENSE,
		"rarity": RARITY_EPIC,
		"faction_id": "aether_dynamics",
		"star_requirement": 3,
		"unlock_requirement": {"faction_id": "aether_dynamics", "min_reputation": 2000},
		"primary_effect": {"stat": STAT_DAMAGE_REDUCTION, "value": 0.14, "scaling": 0.01},
		"secondary_effect": {"stat": STAT_HP, "value": 0.20},
		"desc_primary": "伤害减免 +14%",
		"desc_secondary": "生命值 +20%",
	},

	# aether_03 — 神盾圣光（传说）
	{
		"id": "aether_03",
		"category": CAT_DEFENSE,
		"rarity": RARITY_LEGENDARY,
		"faction_id": "aether_dynamics",
		"star_requirement": 4,
		"unlock_requirement": {"faction_id": "aether_dynamics", "min_reputation": 4000},
		"primary_effect": {"stat": STAT_HP, "value": 0.38, "scaling": 0.03},
		"secondary_effect": {"stat": SPECIAL_ON_ENERGY_SHIELD, "chance": 0.25, "value": 180},
		"desc_primary": "生命值 +38%",
		"desc_secondary": "受击25%概率生成护盾",
	},

	# ── helix_recon（螺旋）侦察机动 2个 ──

	# helix_01 — 螺旋疾行（稀有）
	{
		"id": "helix_01",
		"category": CAT_MOBILITY,
		"rarity": RARITY_RARE,
		"faction_id": "helix_recon",
		"star_requirement": 2,
		"unlock_requirement": {"faction_id": "helix_recon", "min_reputation": 800},
		"primary_effect": {"stat": STAT_DEPLOY_SPEED, "value": 0.28, "scaling": 0.02},
		"secondary_effect": {"stat": STAT_DODGE, "value": 0.12},
		"desc_primary": "部署速度 +28%",
		"desc_secondary": "闪避率 +12%",
	},

	# helix_02 — 螺旋神经（史诗）
	{
		"id": "helix_02",
		"category": CAT_MOBILITY,
		"rarity": RARITY_EPIC,
		"faction_id": "helix_recon",
		"star_requirement": 3,
		"unlock_requirement": {"faction_id": "helix_recon", "min_reputation": 2000},
		"primary_effect": {"stat": STAT_DODGE, "value": 0.22, "scaling": 0.01},
		"secondary_effect": {"stat": STAT_DEPLOY_SPEED, "value": 0.20},
		"desc_primary": "闪避率 +22%",
		"desc_secondary": "部署速度 +20%",
	},

	# helix_03 — 螺旋幻影（传说）
	{
		"id": "helix_03",
		"category": CAT_MOBILITY,
		"rarity": RARITY_LEGENDARY,
		"faction_id": "helix_recon",
		"star_requirement": 4,
		"unlock_requirement": {"faction_id": "helix_recon", "min_reputation": 4000},
		"primary_effect": {"stat": STAT_DODGE, "value": 0.30, "scaling": 0.01},
		"secondary_effect": {"stat": STAT_DEPLOY_SPEED, "value": 0.28},
		"desc_primary": "闪避率 +30%",
		"desc_secondary": "部署速度 +28%",
	},

	# ── nova_arms（新星）火力特化 3个 ──

	# nova_01 — 新星炽焰（稀有）
	{
		"id": "nova_01",
		"category": CAT_ATTACK,
		"rarity": RARITY_RARE,
		"faction_id": "nova_arms",
		"star_requirement": 2,
		"unlock_requirement": {"faction_id": "nova_arms", "min_reputation": 800},
		"primary_effect": {"stat": STAT_ATTACK, "value": 0.22, "scaling": 0.03},
		"secondary_effect": {"stat": STAT_CRIT, "value": 0.06},
		"desc_primary": "攻击力 +22%",
		"desc_secondary": "暴击率 +6%",
	},

	# nova_02 — 新星裂变（史诗）
	{
		"id": "nova_02",
		"category": CAT_ATTACK,
		"rarity": RARITY_EPIC,
		"faction_id": "nova_arms",
		"star_requirement": 3,
		"unlock_requirement": {"faction_id": "nova_arms", "min_reputation": 2000},
		"primary_effect": {"stat": STAT_ATTACK, "value": 0.28, "scaling": 0.02},
		"secondary_effect": {"stat": SPECIAL_ON_AREA_DAMAGE, "chance": 0.18, "value": 15},
		"desc_primary": "攻击力 +28%",
		"desc_secondary": "攻击18%概率溅射",
	},

	# nova_03 — 新星湮灭（传说）
	{
		"id": "nova_03",
		"category": CAT_ATTACK,
		"rarity": RARITY_LEGENDARY,
		"faction_id": "nova_arms",
		"star_requirement": 4,
		"unlock_requirement": {"faction_id": "nova_arms", "min_reputation": 4000},
		"primary_effect": {"stat": STAT_ATTACK, "value": 0.35, "scaling": 0.03},
		"secondary_effect": {"stat": SPECIAL_ON_HIT_CHAIN_LIGHTNING, "chance": 0.25, "value": 22},
		"desc_primary": "攻击力 +35%",
		"desc_secondary": "攻击25%概率闪电链",
	},

	# ── iron_wall_corp（铁幕）坦克特化 2个 ──

	# iron_01 — 铁幕铸甲（稀有）
	{
		"id": "iron_01",
		"category": CAT_DEFENSE,
		"rarity": RARITY_RARE,
		"faction_id": "iron_wall_corp",
		"star_requirement": 2,
		"unlock_requirement": {"faction_id": "iron_wall_corp", "min_reputation": 800},
		"primary_effect": {"stat": STAT_HP, "value": 0.30, "scaling": 0.03},
		"secondary_effect": {"stat": STAT_HP_REGEN, "value": 0.04},
		"desc_primary": "生命值 +30%",
		"desc_secondary": "生命恢复 +4%",
	},

	# iron_02 — 铁幕王座（传说）
	{
		"id": "iron_02",
		"category": CAT_DEFENSE,
		"rarity": RARITY_LEGENDARY,
		"faction_id": "iron_wall_corp",
		"star_requirement": 4,
		"unlock_requirement": {"faction_id": "iron_wall_corp", "min_reputation": 4000},
		"primary_effect": {"stat": STAT_HP, "value": 0.40, "scaling": 0.03},
		"secondary_effect": {"stat": SPECIAL_ON_DEATH_RESPAWN, "chance": 0.15, "value": 100},
		"desc_primary": "生命值 +40%",
		"desc_secondary": "死亡15%概率复活",
	},

	# iron_03 — 铁幕铸魂（史诗）
	{
		"id": "iron_03",
		"category": CAT_DEFENSE,
		"rarity": RARITY_EPIC,
		"faction_id": "iron_wall_corp",
		"star_requirement": 3,
		"unlock_requirement": {"faction_id": "iron_wall_corp", "min_reputation": 2000},
		"primary_effect": {"stat": STAT_DAMAGE_REDUCTION, "value": 0.15, "scaling": 0.01},
		"secondary_effect": {"stat": STAT_HP_REGEN, "value": 0.08},
		"desc_primary": "伤害减免 +15%",
		"desc_secondary": "生命恢复 +8%",
	},

	# ── void_research（虚空）神秘特化 2个 ──

	# void_01 — 虚空低语（稀有）
	{
		"id": "void_01",
		"category": CAT_SPECIAL,
		"rarity": RARITY_RARE,
		"faction_id": "void_research",
		"star_requirement": 2,
		"unlock_requirement": {"faction_id": "void_research", "min_reputation": 800},
		"primary_effect": {"stat": STAT_ATTACK, "value": 0.12, "scaling": 0.02},
		"secondary_effect": {"stat": SPECIAL_ON_ATTACK_PENETRATION, "chance": 1.0, "value": 15},
		"desc_primary": "攻击力 +12%",
		"desc_secondary": "攻击无视15%防御",
	},

	# void_02 — 虚空深渊（传说）
	{
		"id": "void_02",
		"category": CAT_SPECIAL,
		"rarity": RARITY_LEGENDARY,
		"faction_id": "void_research",
		"star_requirement": 4,
		"unlock_requirement": {"faction_id": "void_research", "min_reputation": 4000},
		"primary_effect": {"stat": STAT_ATTACK, "value": 0.18, "scaling": 0.02},
		"secondary_effect": {"stat": SPECIAL_ON_ATTACK_PENETRATION, "chance": 1.0, "value": 28},
		"desc_primary": "攻击力 +18%",
		"desc_secondary": "攻击无视28%防御",
	},

	# void_03 — 虚空裂隙（史诗）
	{
		"id": "void_03",
		"category": CAT_SPECIAL,
		"rarity": RARITY_EPIC,
		"faction_id": "void_research",
		"star_requirement": 3,
		"unlock_requirement": {"faction_id": "void_research", "min_reputation": 2000},
		"primary_effect": {"stat": STAT_ATTACK, "value": 0.15, "scaling": 0.02},
		"secondary_effect": {"stat": SPECIAL_ON_HIT_CHAIN_LIGHTNING, "chance": 0.20, "value": 18},
		"desc_primary": "攻击力 +15%",
		"desc_secondary": "攻击20%概率闪电链",
	},

	# ── quantum_logistics（量子物流）资源特化 2个 ──

	# quantum_01 — 量子工蜂（稀有）
	{
		"id": "quantum_01",
		"category": CAT_ENERGY,
		"rarity": RARITY_RARE,
		"faction_id": "quantum_logistics",
		"star_requirement": 2,
		"unlock_requirement": {"faction_id": "quantum_logistics", "min_reputation": 800},
		"primary_effect": {"stat": STAT_ENERGY_REGEN, "value": 0.22, "scaling": 0.02},
		"secondary_effect": {"stat": SPECIAL_ON_RESOURCE_YIELD, "chance": 1.0, "value": 15},
		"desc_primary": "能量恢复 +22%",
		"desc_secondary": "资源产出 +15%",
	},

	# quantum_02 — 量子枢纽（传说）
	{
		"id": "quantum_02",
		"category": CAT_ENERGY,
		"rarity": RARITY_LEGENDARY,
		"faction_id": "quantum_logistics",
		"star_requirement": 4,
		"unlock_requirement": {"faction_id": "quantum_logistics", "min_reputation": 4000},
		"primary_effect": {"stat": STAT_ENERGY_REGEN, "value": 0.35, "scaling": 0.02},
		"secondary_effect": {"stat": SPECIAL_ON_EXPLORE_BONUS, "chance": 1.0, "value": 30},
		"desc_primary": "能量恢复 +35%",
		"desc_secondary": "探索奖励 +30%",
	},

	# quantum_03 — 量子矩阵（史诗）
	{
		"id": "quantum_03",
		"category": CAT_ENERGY,
		"rarity": RARITY_EPIC,
		"faction_id": "quantum_logistics",
		"star_requirement": 3,
		"unlock_requirement": {"faction_id": "quantum_logistics", "min_reputation": 2000},
		"primary_effect": {"stat": STAT_ENERGY_REGEN, "value": 0.28, "scaling": 0.02},
		"secondary_effect": {"stat": SPECIAL_ON_RESOURCE_YIELD, "chance": 1.0, "value": 20},
		"desc_primary": "能量恢复 +28%",
		"desc_secondary": "资源产出 +20%",
	},

	# ── frontier_union（边境联盟）均衡特化 2个 ──

	# frontier_01 — 边境均衡（稀有）
	{
		"id": "frontier_01",
		"category": CAT_ATTACK,
		"rarity": RARITY_RARE,
		"faction_id": "frontier_union",
		"star_requirement": 2,
		"unlock_requirement": {"faction_id": "frontier_union", "min_reputation": 800},
		"primary_effect": {"stat": STAT_ATTACK, "value": 0.15, "scaling": 0.02},
		"secondary_effect": {"stat": STAT_ENERGY_REGEN, "value": 0.12},
		"desc_primary": "攻击力 +15%",
		"desc_secondary": "能量恢复 +12%",
	},

	# frontier_02 — 边境终式（传说）
	{
		"id": "frontier_02",
		"category": CAT_SPECIAL,
		"rarity": RARITY_LEGENDARY,
		"faction_id": "frontier_union",
		"star_requirement": 4,
		"unlock_requirement": {"faction_id": "frontier_union", "min_reputation": 4000},
		"primary_effect": {"stat": STAT_ATTACK, "value": 0.20, "scaling": 0.02},
		"secondary_effect": {"stat": STAT_ENERGY_REGEN, "value": 0.20},
		"desc_primary": "攻击力 +20%",
		"desc_secondary": "能量恢复 +20%",
	},

	# frontier_03 — 边境共鸣（史诗）
	{
		"id": "frontier_03",
		"category": CAT_ATTACK,
		"rarity": RARITY_EPIC,
		"faction_id": "frontier_union",
		"star_requirement": 3,
		"unlock_requirement": {"faction_id": "frontier_union", "min_reputation": 2000},
		"primary_effect": {"stat": STAT_ATTACK, "value": 0.18, "scaling": 0.02},
		"secondary_effect": {"stat": STAT_HP, "value": 0.12},
		"desc_primary": "攻击力 +18%",
		"desc_secondary": "生命值 +12%",
	},
]

# ── 按ID索引的快速查找表 ──────────────────────────────────────────

static func _build_id_map() -> Dictionary:
	var result: Dictionary = {}
	for rune in ALL_RUNES:
		result[rune["id"]] = rune
	return result

static var _ID_MAP: Dictionary = _build_id_map()

## 通过ID获取符文定义
static func get_rune(rune_id: String) -> Dictionary:
	if _ID_MAP.has(rune_id):
		return _ID_MAP[rune_id]
	return {}

## 按分类过滤
static func get_runes_by_category(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for rune in ALL_RUNES:
		if rune["category"] == category:
			result.append(rune)
	return result

## 按稀有度过滤
static func get_runes_by_rarity(rarity: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for rune in ALL_RUNES:
		if rune["rarity"] == rarity:
			result.append(rune)
	return result

## 按势力过滤（不含通用）
static func get_runes_by_faction(faction_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for rune in ALL_RUNES:
		if rune["faction_id"] == faction_id:
			result.append(rune)
	return result

## 通用符文列表
static func get_generic_runes() -> Array[Dictionary]:
	return get_runes_by_faction(FACTION_GENERIC)

## 获取符文名称
## 注意：不能命名为 get_name，因为与 Object.get_name()（0参）冲突，
## 在 Godot 4.5 中静态方法会被基类方法覆盖导致 "Expected 0 argument(s)" 错误。
static func get_rune_name(rune_id: String) -> String:
	if RUNE_NAMES.has(rune_id):
		return RUNE_NAMES[rune_id]
	return rune_id

## 获取符文颜色（按稀有度）
static func get_color(rune_id: String) -> Color:
	var rune = get_rune(rune_id)
	var rarity = rune.get("rarity", RARITY_COMMON)
	return RARITY_COLORS.get(rarity, Color.WHITE)

## 获取符文描述
static func get_description(rune_id: String) -> String:
	var rune = get_rune(rune_id)
	var primary = rune.get("desc_primary", "")
	var secondary = rune.get("desc_secondary", "")
	if secondary:
		return "%s\n%s" % [primary, secondary]
	return primary

## 符文图标路径：res://assets/runes/{rarity}/rune_{id}.png
## 稀有度从符文定义读取；自身稀有度文件夹查不到时按 rarity 顺序回退（部分符文 PNG 落在了与
## 自身稀有度不一致的文件夹，legendary 是全套兜底）；全部找不到才返回 ""。
static func icon_path_for(rune_id: String) -> String:
	var rune: Dictionary = get_rune(rune_id)
	if rune.is_empty():
		return ""
	var rarity: String = String(rune.get("rarity", RARITY_COMMON))
	var path: String = "res://assets/runes/%s/rune_%s.png" % [rarity, rune_id]
	if ResourceLoader.exists(path, "Texture2D"):
		return path
	# 跨稀有度文件夹回退查找（legendary 为全套兜底）
	for alt_rarity in ["legendary", "common", "rare", "epic"]:
		if alt_rarity == rarity:
			continue
		path = "res://assets/runes/%s/rune_%s.png" % [alt_rarity, rune_id]
		if ResourceLoader.exists(path, "Texture2D"):
			return path
	return ""

## 获取所有符文ID列表
static func get_all_ids() -> Array[String]:
	var ids: Array[String] = []
	for rune in ALL_RUNES:
		ids.append(rune["id"])
	return ids

# ── 统计信息 ───────────────────────────────────────────────────────

static func get_count_by_category() -> Dictionary:
	var counts: Dictionary = {}
	for cat in ALL_CATEGORIES:
		counts[cat] = len(get_runes_by_category(cat))
	return counts

static func get_count_by_rarity() -> Dictionary:
	var counts: Dictionary = {}
	for rar in RARITY_ORDER:
		counts[rar] = len(get_runes_by_rarity(rar))
	return counts

# ── 加成显示工具（v6.2 公共方法，供 rune_panel/bottom_instrument_bar/battle_hud 复用） ──

## 符文属性 key → 中文显示名映射（14 项）
const STAT_DISPLAY_NAMES: Dictionary = {
	"attack": "攻击力", "defense": "防御力", "hp": "生命值",
	"attack_speed": "攻击速度", "deploy_speed": "部署速度",
	"energy_regen": "能量恢复", "energy_cost_reduction": "能量消耗",
	"range": "射程", "dodge": "闪避率", "crit": "暴击率",
	"accuracy": "命中率", "hp_regen": "生命恢复", "damage_reduction": "伤害减免",
	"attack_penetration": "攻击穿透",
}

## 符文特殊效果 key → 中文显示名映射（10 项）
const SPECIAL_DISPLAY_NAMES: Dictionary = {
	"on_kill_regen_energy": "击杀回能", "on_hit_chain_lightning": "闪电链",
	"on_death_respawn": "死亡复活", "on_deploy_speed_up": "部署加速",
	"on_attack_penetration": "攻击穿透", "on_area_damage": "溅射伤害",
	"on_damage_reduction": "伤害减免", "on_energy_shield": "能量护盾",
	"on_explore_bonus": "探索奖励", "on_resource_yield": "资源产出",
}

## 符文属性 key → 简短显示名（用于空间受限的统计行/HUD，2-3字）
const STAT_SHORT_NAMES: Dictionary = {
	"attack": "攻", "defense": "防", "hp": "生",
	"attack_speed": "攻速", "deploy_speed": "部署",
	"energy_regen": "能回", "energy_cost_reduction": "能耗",
	"range": "射程", "dodge": "闪避", "crit": "暴击",
	"accuracy": "命中", "hp_regen": "回血", "damage_reduction": "减伤",
	"attack_penetration": "穿透",
}

## 获取符文属性的完整中文名（找不到时回退到 key 本身）
static func stat_display_name(stat: String) -> String:
	return STAT_DISPLAY_NAMES.get(stat, stat)

## 获取符文特殊效果的完整中文名（找不到时回退到 key 本身）
static func special_display_name(special: String) -> String:
	return SPECIAL_DISPLAY_NAMES.get(special, special)

## 获取符文属性的简短中文名（用于 HUD/统计行，找不到时回退到完整名）
static func stat_short_name(stat: String) -> String:
	return STAT_SHORT_NAMES.get(stat, stat_display_name(stat))

## 格式化属性加成值为显示字符串
## 对于减免类（energy_cost_reduction / damage_reduction）显示 -X%，其余显示 +X%
static func format_stat_bonus(stat: String, value: float) -> String:
	var pct := int(round(value * 100.0))
	if pct == 0:
		return ""
	if stat == "energy_cost_reduction" or stat == "damage_reduction":
		return "%s -%d%%" % [stat_short_name(stat), pct]
	return "%s +%d%%" % [stat_short_name(stat), pct]
