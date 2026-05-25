extends RefCounted
class_name AffixDefinitions
## 词条配置表 - 所有可用词条的静态定义
##
## 词条分三大类：
##   base_property   - 基础属性（血量、伤害、速度、射程、攻速）
##   combat_feature  - 战斗特性（暴击、溅射、吸血、穿甲）
##   special_mechanic - 特殊机制（连锁、护盾、灵魂汲取）
##
## card_type_filter:  0=仅平台卡, 1=仅武器卡, 2=平台/武器均可
## weapon_type_filter: -1=所有武器, 其他值=GameConstants.WeaponType
##
## unlock_condition: 解锁条件
##   - "none": 默认解锁
##   - "unlock_XXX": 需要解锁特定内容（如 unlock_enemy_boss_1）
##   - "win_level_X": 通关特定关卡

## 词条槽位限制（每张卡最多携带词条数）= 强化次数上限
const MAX_AFFIX_SLOTS: int = 9

## 词条等级上限
const MAX_AFFIX_LEVEL: int = 5

## 变异触发概率（词条升到5级时）
const MUTATION_CHANCE: float = 0.25

## 强化触发等级（每5级强化一次）
const ENHANCE_TRIGGER_LEVELS: Array = [5, 10, 15, 20, 25]

## 词条升级概率（每次强化）
const AFFIX_UPGRADE_CHANCE: float = 0.20

## 重随消耗（每级递增）
const REROLL_COSTS: Array = [500, 800, 1200, 1800, 2500, 3500, 5000, 7000, 10000]

## 锁定倍率（本次锁定k个词条 -> 额外纳米倍率）
## 口径：extra_lock_cost = round_to_10(base_reroll_cost * LOCK_MULTIPLIER[k])
## base_reroll_cost 通常为“本次将重随的槽位成本之和”
const LOCK_MULTIPLIER: Dictionary = {
	0: 0.0,
	1: 2.5,
	2: 3.3,
	3: 4.4,
	4: 6.0,
}

static func get_lock_multiplier(locked_count: int) -> float:
	return float(LOCK_MULTIPLIER.get(clampi(locked_count, 0, 4), 0.0))

static func round_to_10(value: float) -> int:
	# 四舍五入到10的倍数
	return int(round(value / 10.0) * 10.0)

## 全部词条定义表
## 结构：{ affix_id: { 所有字段... } }
## unlock_condition: 解锁条件（默认 "none" = 初始可用）
##   "none" - 初始解锁
##   "boss_1" - 击败头目1解锁
##   "boss_2" - 击败头目2解锁
##   ...以此类推
const AFFIX_TABLE: Dictionary = {

	# ─── 基础属性：平台（初始可用）────────────────────────────
	"platform_hp_up": {
		"affix_name":         "铁甲强化",
		"description":        "平台最大生命值提升",
		"affix_type":         "base_property",
		"effect_key":         "max_hp",
		"base_value":         0.12,    # +12% HP (Lv1)
		"card_type_filter":   0,       # 仅平台
		"weapon_type_filter": -1,
		"rarity_pool":        ["common", "rare", "epic", "legendary"],
		"unlock_condition":   "none",
	},
	"platform_speed_up": {
		"affix_name":         "疾行引擎",
		"description":        "平台移动速度提升",
		"affix_type":         "base_property",
		"effect_key":         "move_speed",
		"base_value":         0.10,
		"card_type_filter":   0,
		"weapon_type_filter": -1,
		"rarity_pool":        ["common", "rare", "epic", "legendary"],
		"unlock_condition":   "none",
	},
	"platform_armor": {
		"affix_name":         "纳米装甲",
		"description":        "平台受到伤害减少",
		"affix_type":         "base_property",
		"effect_key":         "damage_reduction",
		"base_value":         0.08,
		"card_type_filter":   0,
		"weapon_type_filter": -1,
		"rarity_pool":        ["common", "rare", "epic", "legendary"],
		"unlock_condition":   "none",
	},

	# ─── 基础属性：武器（初始可用）────────────────────────────
	"weapon_dmg_up": {
		"affix_name":         "穿透弹芯",
		"description":        "武器攻击伤害提升",
		"affix_type":         "base_property",
		"effect_key":         "attack_damage",
		"base_value":         0.15,    # +15% 伤害 (Lv1)
		"card_type_filter":   1,       # 仅武器
		"weapon_type_filter": -1,
		"rarity_pool":        ["common", "rare", "epic", "legendary"],
		"unlock_condition":   "none",
	},
	"weapon_range_up": {
		"affix_name":         "延伸枪管",
		"description":        "武器攻击射程提升",
		"affix_type":         "base_property",
		"effect_key":         "attack_range",
		"base_value":         0.12,
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["common", "rare", "epic", "legendary"],
		"unlock_condition":   "none",
	},
	"weapon_atkspd_up": {
		"affix_name":         "速射改装",
		"description":        "武器攻击间隔缩短（加快攻速）",
		"affix_type":         "base_property",
		"effect_key":         "attack_interval",
		"base_value":         0.12,    # 攻击间隔 ×(1-0.12) = -12%（攻速加快）
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["common", "rare", "epic", "legendary"],
		"unlock_condition":   "none",
	},

	# ─── 战斗特性（部分初始，部分需要解锁）────────────────────────────
	"crit_chance": {
		"affix_name":         "精准打击",
		"description":        "攻击附加暴击几率（暴击造成1.5倍伤害）",
		"affix_type":         "combat_feature",
		"effect_key":         "crit_chance",
		"base_value":         0.08,    # 8% 暴击率 (Lv1)
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["common", "rare", "epic", "legendary"],
		"unlock_condition":   "none",
	},
	"lifesteal": {
		"affix_name":         "汲能吸血",
		"description":        "攻击时恢复造成伤害一定比例的生命",
		"affix_type":         "combat_feature",
		"effect_key":         "lifesteal",
		"base_value":         0.05,    # 5% 吸血 (Lv1)
		"card_type_filter":   2,
		"weapon_type_filter": -1,
		"rarity_pool":        ["common", "rare", "epic", "legendary"],
		"unlock_condition":   "boss_1",
	},
	"splash_dmg": {
		"affix_name":         "爆裂弹头",
		"description":        "攻击造成范围溅射伤害（溅射伤害为原始伤害百分比）",
		"affix_type":         "combat_feature",
		"effect_key":         "splash_damage",
		"base_value":         0.20,    # 20% 溅射 (Lv1)
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["common", "rare", "epic", "legendary"],
		"unlock_condition":   "boss_1",
	},
	"armor_break": {
		"affix_name":         "穿甲射击",
		"description":        "攻击忽视目标伤害减免",
		"affix_type":         "combat_feature",
		"effect_key":         "armor_penetration",
		"base_value":         0.15,
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["common", "rare", "epic", "legendary"],
		"unlock_condition":   "boss_2",
	},

	# ─── 特殊机制（需要击败特定头目解锁）────────────────────────────
	"chain_lightning": {
		"affix_name":         "链式放电",
		"description":        "攻击有几率对附近敌人触发连锁伤害",
		"affix_type":         "special_mechanic",
		"effect_key":         "chain_chance",
		"base_value":         0.12,
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["common", "rare", "epic", "legendary"],
		"unlock_condition":   "boss_3",
	},
	"shield_on_kill": {
		"affix_name":         "歼灭护盾",
		"description":        "每次击杀获得一层护盾（每层抵挡部分伤害）",
		"affix_type":         "special_mechanic",
		"effect_key":         "shield_on_kill",
		"base_value":         0.05,    # 5% 最大HP的护盾值 (Lv1)
		"card_type_filter":   0,
		"weapon_type_filter": -1,
		"rarity_pool":        ["common", "rare", "epic", "legendary"],
		"unlock_condition":   "boss_2",
	},
	"nano_regen": {
		"affix_name":         "纳米自愈",
		"description":        "战斗中缓慢回复生命值",
		"affix_type":         "special_mechanic",
		"effect_key":         "hp_regen",
		"base_value":         0.005,   # 每秒回复 0.5% 最大HP (Lv1)
		"card_type_filter":   0,
		"weapon_type_filter": -1,
		"rarity_pool":        ["common", "rare", "epic", "legendary"],
		"unlock_condition":   "boss_1",
	},

	# ─── 重平衡新增词条 ────────────────────────────────────────────
	"platform_def_up": {
		"affix_name":         "复合装甲",
		"description":        "平台防御值提升（直接增加护甲）",
		"affix_type":         "base_property",
		"effect_key":         "defense",
		"base_value":         2.0,     # +2 DEF (Lv1), 每级+2 → Lv5=+10 DEF
		"card_type_filter":   0,       # 仅平台
		"weapon_type_filter": -1,
		"rarity_pool":        ["common", "rare", "epic", "legendary"],
		"unlock_condition":   "none",
	},
	"dodge_chance": {
		"affix_name":         "相位闪避",
		"description":        "平台获得闪避几率（完全回避一次攻击）",
		"affix_type":         "combat_feature",
		"effect_key":         "dodge_chance",
		"base_value":         0.05,    # +5% 闪避 (Lv1), 每级+5% → Lv5=+25%
		"card_type_filter":   0,       # 仅平台
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "boss_1",
	},
	"crit_dmg_up": {
		"affix_name":         "致命一击",
		"description":        "暴击伤害倍率提升（基础暴击1.5倍，每级+0.2倍）",
		"affix_type":         "combat_feature",
		"effect_key":         "crit_damage_bonus",
		"base_value":         0.20,    # +0.2x 暴击倍率 (Lv1), 每级+0.2 → Lv5=+1.0x (总暴击2.5x)
		"card_type_filter":   1,       # 仅武器
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "boss_2",
	},
}

## 变异配置（词条 Lv5 时有概率触发，为词条额外添加特殊效果描述）
const MUTATION_TABLE: Dictionary = {
	"platform_hp_up":    "血量超过80%时，受到伤害额外减少10%",
	"weapon_dmg_up":     "攻击时有15%概率造成双倍伤害",
	"weapon_atkspd_up":  "连续攻击3次后，下次攻击伤害+50%",
	"crit_chance":       "暴击时额外恢复5%最大生命值",
	"lifesteal":         "生命值低于30%时，吸血效果翻倍",
	"splash_dmg":        "溅射击杀时触发额外一次溅射",
	"chain_lightning":   "连锁最多延伸至5个目标",
	"shield_on_kill":    "护盾层数上限+2",
	"nano_regen":        "生命值低于50%时，回复速度翻倍",
	"platform_def_up":   "受到暴击时，额外减免30%暴击伤害",
	"dodge_chance":      "成功闪避后，下次攻击必定暴击",
	"crit_dmg_up":       "暴击击杀时，恢复10%最大生命值",
}

# ─────────────────────────────────────────────
#  静态查询方法
# ─────────────────────────────────────────────

## 获取词条定义（返回 Dictionary，不存在则返回 {}）
static func get_definition(affix_id: String) -> Dictionary:
	if AFFIX_TABLE.has(affix_id):
		return (AFFIX_TABLE[affix_id] as Dictionary).duplicate(true)
	return {}

## 获取所有词条ID
static func get_all_ids() -> Array:
	return AFFIX_TABLE.keys()

## 按稀有度过滤词条ID列表
static func get_ids_by_rarity(rarity: String) -> Array:
	var result: Array = []
	for id in AFFIX_TABLE.keys():
		var def: Dictionary = AFFIX_TABLE[id]
		var pool: Array = def.get("rarity_pool", []) as Array
		if pool.has(rarity):
			result.append(id)
	return result

## 按卡牌类型过滤可用词条（0=平台, 1=武器）
static func get_ids_for_card_type(card_type: int) -> Array:
	var result: Array = []
	for id in AFFIX_TABLE.keys():
		var def: Dictionary = AFFIX_TABLE[id]
		var filter: int = int(def.get("card_type_filter", 2))
		if filter == 2 or filter == card_type:
			result.append(id)
	return result

## 获取变异描述
static func get_mutation_description(affix_id: String) -> String:
	if MUTATION_TABLE.has(affix_id):
		return String(MUTATION_TABLE[affix_id])
	return ""

## 按稀有度权重随机抽取一个词条ID（card_type: 0=平台, 1=武器）
static func roll_random_affix_id(card_type: int, rarity_override: String = "") -> String:
	var pool: Array = get_ids_for_card_type(card_type)
	if pool.is_empty():
		return ""
	# 根据稀有度权重过滤
	var weighted: Array = []
	for id in pool:
		var def: Dictionary = AFFIX_TABLE[id] as Dictionary
		var rarity_pool: Array = def.get("rarity_pool", ["common"]) as Array
		if not rarity_override.is_empty():
			if rarity_pool.has(rarity_override):
				weighted.append(id)
		else:
			# 自动权重：common=4, rare=3, epic=2, legendary=1
			var w: int = 1
			if rarity_pool.has("common"):   w = 4
			elif rarity_pool.has("rare"):   w = 3
			elif rarity_pool.has("epic"):   w = 2
			for _i in range(w):
				weighted.append(id)
	if weighted.is_empty():
		return ""
	return String(weighted[randi() % weighted.size()])

## 根据定义构建一个 AffixResource 实例
static func build_affix(affix_id: String, rarity: String = "common", level: int = 1) -> AffixResource:
	var def: Dictionary = get_definition(affix_id)
	if def.is_empty():
		return null
	var a := AffixResource.new()
	a.affix_id            = affix_id
	a.affix_name          = str(def.get("affix_name", affix_id))
	a.description         = str(def.get("description", ""))
	a.affix_type          = str(def.get("affix_type", "base_property"))
	a.effect_key          = str(def.get("effect_key", ""))
	a.base_value          = float(def.get("base_value", 0.0))
	a.card_type_filter    = int(def.get("card_type_filter", 2))
	a.weapon_type_filter  = int(def.get("weapon_type_filter", -1))
	a.rarity              = rarity
	a.level               = clampi(level, 1, 5)
	a.recalculate()
	# 检查是否触发变异（仅 Lv5）
	if a.level >= 5 and randf() < 0.25:
		var mut: String = get_mutation_description(affix_id)
		if not mut.is_empty():
			a.is_mutated = true
			a.mutation_description = mut
	return a

# ─────────────────────────────────────────────
#  稀有度概率（基于等级决定）
# ─────────────────────────────────────────────

## 基于卡牌等级计算稀有度
## 等级越高，高稀有度概率越大，但低等级也有小概率出好东西
static func roll_rarity_by_level(card_level: int) -> String:
	# 基础概率（等级决定上限）
	var legendary_base: float = 0.0
	var epic_base: float = 0.0
	var rare_base: float = 0.0

	match card_level:
		1, 2, 3, 4:
			# Lv1-4: 还未达到强化等级，无词条
			legendary_base = 0.0
			epic_base = 0.0
			rare_base = 0.15
		5, 6, 7, 8, 9:
			# Lv5-9: 第1次强化后
			legendary_base = 0.02   # 2% 传说（保底）
			epic_base = 0.08       # 8% 史诗
			rare_base = 0.30       # 30% 稀有
		10, 11, 12, 13, 14:
			# Lv10-14: 第2次强化后
			legendary_base = 0.05   # 5% 传说
			epic_base = 0.15        # 15% 史诗
			rare_base = 0.40        # 40% 稀有
		15, 16, 17, 18, 19:
			# Lv15-19: 第3次强化后
			legendary_base = 0.10   # 10% 传说
			epic_base = 0.25        # 25% 史诗
			rare_base = 0.45        # 45% 稀有
		20, 21, 22, 23, 24:
			# Lv20-24: 第4次强化后
			legendary_base = 0.18   # 18% 传说
			epic_base = 0.35        # 35% 史诗
			rare_base = 0.35        # 35% 稀有
		25:
			# Lv25: 第5次强化后（满级）
			legendary_base = 0.25   # 25% 传说
			epic_base = 0.40        # 40% 史诗
			rare_base = 0.25        # 25% 稀有
		_:
			legendary_base = 0.25
			epic_base = 0.40
			rare_base = 0.25

	# 随机Roll
	var r: float = randf()
	if r < legendary_base:
		return "legendary"
	elif r < legendary_base + epic_base:
		return "epic"
	elif r < legendary_base + epic_base + rare_base:
		return "rare"
	return "common"

## 获取某等级段的强化次数（用于决定可获得的词条槽位数）
static func get_enhance_count_by_level(card_level: int) -> int:
	for i in range(ENHANCE_TRIGGER_LEVELS.size() - 1, -1, -1):
		if card_level >= ENHANCE_TRIGGER_LEVELS[i]:
			return i + 1
	return 0

## 检查词条是否已解锁（根据击败的头目）
static func is_affix_unlocked(affix_id: String, unlocked_bosses: Array) -> bool:
	var def: Dictionary = get_definition(affix_id)
	if def.is_empty():
		return false
	var condition: String = str(def.get("unlock_condition", "none"))
	if condition == "none":
		return true
	return unlocked_bosses.has(condition)

## 获取已解锁的词条列表
static func get_unlocked_affix_ids(card_type: int, unlocked_bosses: Array) -> Array:
	var result: Array = []
	for id in AFFIX_TABLE.keys():
		if is_affix_unlocked(id, unlocked_bosses):
			var def: Dictionary = AFFIX_TABLE[id]
			var filter: int = int(def.get("card_type_filter", 2))
			if filter == 2 or filter == card_type:
				result.append(id)
	return result

## 在已解锁词条中随机抽取一个
static func roll_unlocked_affix_id(card_type: int, rarity: String, unlocked_bosses: Array) -> String:
	var pool: Array = get_unlocked_affix_ids(card_type, unlocked_bosses)
	if pool.is_empty():
		return ""
	# 按稀有度过滤
	var weighted: Array = []
	for id in pool:
		var def: Dictionary = AFFIX_TABLE[id] as Dictionary
		var rarity_pool: Array = def.get("rarity_pool", ["common"]) as Array
		if rarity_pool.has(rarity):
			weighted.append(id)
	# 如果指定稀有度没有合适的，降低要求
	if weighted.is_empty():
		for id in pool:
			weighted.append(id)
	if weighted.is_empty():
		return ""
	return String(weighted[randi() % weighted.size()])
