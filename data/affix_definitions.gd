extends RefCounted
class_name AffixDefinitions
## 模块化词条配置表 - 所有可用词条的静态定义
## [术语] affix = 模块化词条（同义词，设计文档用\"模块化词条\"）
##
## 词条分三大类：
##   base_property   - 基础属性（血量、伤害、速度、射程、攻速）
##   combat_feature  - 战斗特性（暴击、溅射、吸血、穿甲）
##   special_mechanic - 特殊机制（连锁、护盾、灵魂汲取）
##
## card_type_filter:  0=仅平台卡, 1=仅武器卡, 2=平台/武器均可
## weapon_type_filter: -1=所有武器, 其他值=GameConstants.WeaponType
## combat_kinds:      兵种限定（CombatKind 数组：0轻装/1装甲/2支援/3空中/4堡垒；空/缺省=通用词条）
## min_tier:          单位档位门槛（UnifiedCardTable.Tier；0=无门槛，>=3(CHAMPION)=特殊兵种独特词条）
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

## v19: 兵种专属池 roll 概率（两段式：先以此概率走本兵种专属池，空池/未命中走通用池）
const KIND_POOL_CHANCE: float = 0.55

## v19: 特殊兵种独特词条档位门槛（CardResource.tier >= 此值才可 roll；3=CHAMPION/5=ULTIMATE/6=FORT）
const UNIQUE_AFFIX_MIN_TIER: int = 3

## 强化触发等级（每5级强化一次）
const ENHANCE_TRIGGER_LEVELS: Array = [5, 10, 15, 20, 25, 30]  # v27.4 勘误：对齐 affix_manager 权威 6 节点口径（旧 5 节点为 v18 遗留）

## 词条升级概率（每次强化）
const AFFIX_UPGRADE_CHANCE: float = 0.20

## 重随消耗（每级递增）
const REROLL_COSTS: Array = [500, 800, 1200, 1800, 2500, 3500, 5000, 7000, 10000]

## v27.2: 星冥卡洗练计费（星髓）——星髓收入口径：单 run 渗度里程碑合计 350、每周封顶 400，
## 故取纳米档约 1/30 量级；首版曲线，供需实测后调。
const XENO_REROLL_COSTS: Array = [12, 20, 30, 45, 65, 90, 125, 165, 210]

static func get_xeno_reroll_cost(slot_index: int) -> int:
	var idx: int = clampi(slot_index, 0, XENO_REROLL_COSTS.size() - 1)
	return int(XENO_REROLL_COSTS[idx])

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
		"affix_name":         "战场回收",
		"description":        "击杀敌方单位时，回复自身一定比例最大生命值",
		"affix_type":         "combat_feature",
		"effect_key":         "kill_repair",
		"base_value":         0.06,    # 6% 自身最大HP/击杀 (Lv1)
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

	# ─── v19 兵种专属词条（combat_kinds 限定，每兵种 2 个） ─────────────────
	"light_skirmish": {
		"affix_name":         "游击机动",
		"description":        "【轻装专属】平台移动速度提升",
		"affix_type":         "base_property",
		"effect_key":         "move_speed",
		"base_value":         0.15,    # +15% 移速 (Lv1)
		"card_type_filter":   0,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [0],
		"min_tier":           0,
	},
	"light_evasion": {
		"affix_name":         "战术翻滚",
		"description":        "【轻装专属】平台获得闪避几率（完全回避一次攻击）",
		"affix_type":         "combat_feature",
		"effect_key":         "dodge_chance",
		"base_value":         0.08,    # +8% 闪避 (Lv1)
		"card_type_filter":   0,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [0],
		"min_tier":           0,
	},
	"armor_column": {
		"affix_name":         "重装甲列",
		"description":        "【装甲专属】平台最大生命值提升",
		"affix_type":         "base_property",
		"effect_key":         "max_hp",
		"base_value":         0.18,    # +18% HP (Lv1)
		"card_type_filter":   0,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [1],
		"min_tier":           0,
	},
	"armor_plating": {
		"affix_name":         "复合装甲板",
		"description":        "【装甲专属】平台受到伤害减少",
		"affix_type":         "base_property",
		"effect_key":         "damage_reduction",
		"base_value":         0.10,    # -10% 受伤 (Lv1)
		"card_type_filter":   0,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [1],
		"min_tier":           0,
	},
	"air_dive": {
		"affix_name":         "俯冲打击",
		"description":        "【空中专属】武器攻击伤害提升",
		"affix_type":         "base_property",
		"effect_key":         "attack_damage",
		"base_value":         0.18,    # +18% 伤害 (Lv1)
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [3],
		"min_tier":           0,
	},
	"air_supremacy": {
		"affix_name":         "空中优势",
		"description":        "【空中专属】攻击附加暴击几率（暴击造成1.5倍伤害）",
		"affix_type":         "combat_feature",
		"effect_key":         "crit_chance",
		"base_value":         0.10,    # +10% 暴击率 (Lv1)
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [3],
		"min_tier":           0,
	},
	"support_outrange": {
		"affix_name":         "超视距打击",
		"description":        "【支援专属】武器攻击射程提升",
		"affix_type":         "base_property",
		"effect_key":         "attack_range",
		"base_value":         0.18,    # +18% 射程 (Lv1)
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [2],
		"min_tier":           0,
	},
	"support_repair": {
		"affix_name":         "战场维修",
		"description":        "【支援专属】战斗中缓慢回复生命值",
		"affix_type":         "special_mechanic",
		"effect_key":         "hp_regen",
		"base_value":         0.008,   # 每秒回复 0.8% 最大HP (Lv1)
		"card_type_filter":   0,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [2],
		"min_tier":           0,
	},
	"fort_bulwark": {
		"affix_name":         "永备工事",
		"description":        "【堡垒专属】平台防御值提升（直接增加护甲）",
		"affix_type":         "base_property",
		"effect_key":         "defense",
		"base_value":         4.0,     # +4 DEF (Lv1)
		"card_type_filter":   0,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [4],
		"min_tier":           0,
	},
	"fort_crossfire": {
		"affix_name":         "交叉火力网",
		"description":        "【堡垒专属】攻击有几率对附近敌人触发连锁伤害",
		"affix_type":         "special_mechanic",
		"effect_key":         "chain_chance",
		"base_value":         0.15,    # +15% 连锁几率 (Lv1)
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [4],
		"min_tier":           0,
	},

	# ─── v19 特殊兵种独特词条（min_tier >= CHAMPION，每兵种 1 个） ─────────
	"light_executioner": {
		"affix_name":         "斩首猎杀",
		"description":        "【轻装·冠军级独有】暴击伤害倍率提升（基础暴击1.5倍）",
		"affix_type":         "combat_feature",
		"effect_key":         "crit_damage_bonus",
		"base_value":         0.30,    # +0.3x 暴伤 (Lv1)
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [0],
		"min_tier":           3,
	},
	"armor_titan": {
		"affix_name":         "泰坦之躯",
		"description":        "【装甲·冠军级独有】平台最大生命值大幅提升",
		"affix_type":         "base_property",
		"effect_key":         "max_hp",
		"base_value":         0.25,    # +25% HP (Lv1)
		"card_type_filter":   0,
		"weapon_type_filter": -1,
		"rarity_pool":        ["epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [1],
		"min_tier":           3,
	},
	"air_reaper": {
		"affix_name":         "死神俯冲",
		"description":        "【空中·冠军级独有】武器攻击伤害大幅提升",
		"affix_type":         "base_property",
		"effect_key":         "attack_damage",
		"base_value":         0.25,    # +25% 伤害 (Lv1)
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [3],
		"min_tier":           3,
	},
	"support_orbital": {
		"affix_name":         "轨道支援",
		"description":        "【支援·冠军级独有】攻击造成大范围溅射伤害",
		"affix_type":         "combat_feature",
		"effect_key":         "splash_damage",
		"base_value":         0.30,    # +30% 溅射 (Lv1)
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [2],
		"min_tier":           3,
	},
	"fort_protocol": {
		"affix_name":         "堡垒协议",
		"description":        "【堡垒·冠军级独有】每次击杀获得一层更厚的护盾",
		"affix_type":         "special_mechanic",
		"effect_key":         "shield_on_kill",
		"base_value":         0.10,    # 10% 最大HP的护盾值 (Lv1)
		"card_type_filter":   0,
		"weapon_type_filter": -1,
		"rarity_pool":        ["epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [4],
		"min_tier":           3,
	},

	# ─── v21 P3-B（计划 C3）：build-around 传奇词条（5 个 special_mechanic，改玩法不加数值） ─────
	## wired 字段：执行挂点是否已接。
	##   true  = 数值经 AffixManager._apply_card_affixes 写入 UnitStats 字段，
	##           由既有战斗路径消费（kill_repair → module_effect_handler.on_unit_killed；
	##           intercept_chance → module_effect_handler 拦截判定）。
	##   false = 数据就绪、执行挂点待接——roll 池过滤掉（roll_random_affix_id / roll_unlocked_affix_id），
	##           避免玩家抽到"有词条无效果"的死词条；接好挂点后把 wired 改 true 即入池。
	"sm_kill_triage": {
		"affix_name":         "战场急救",
		"description":        "击杀敌方单位后，回复自身 3% 最大生命值",
		"affix_type":         "special_mechanic",
		"effect_key":         "kill_repair",     # 复用战场回收同款字段，消费点：module_effect_handler.on_unit_killed
		"base_value":         0.03,
		"card_type_filter":   2,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"wired":              true,
	},
	"sm_intercept_guard": {
		"affix_name":         "相位格挡",
		"description":        "受到攻击时，有 10% 概率完全格挡该次伤害",
		"affix_type":         "special_mechanic",
		"effect_key":         "intercept_chance", # 消费点：module_effect_handler.try_intercept（既有分支）
		"base_value":         0.10,
		"card_type_filter":   0,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"wired":              true,
		# v21 P3-B deviation 备注：brief 示例文案为"格挡一半伤害"，但既有消费点 try_intercept
		# 的语义是完全免伤（拦截成功跳过 hp 扣减；construct_unit.take_damage 只读不可加半伤分支）。
		# 描述已对齐真实效果；intercept_charges 默认 -1（无限）⇒ 只设 chance 即生效，不耗次数。
	},
	"sm_crit_ensure_hit": {
		"affix_name":         "暴击势能",
		"description":        "打出暴击后，下一次攻击必定命中（无视闪避）",
		"affix_type":         "special_mechanic",
		"effect_key":         "crit_ensure_hit",  # v27.1 已接线：bullet.gd 暴击武装 → 受击侧 take_damage 消费
		"base_value":         1.0,                # 机制开关型：1.0=启用
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["epic", "legendary"],
		"unlock_condition":   "none",
		"wired":              true,
	},
	"sm_fullhp_onslaught": {
		"affix_name":         "满员突击",
		"description":        "生命值全满时，造成的伤害提升 15%",
		"affix_type":         "special_mechanic",
		"effect_key":         "full_hp_damage_bonus",  # v27.1 已接线：construct_unit_ai.do_attack_with_damage 伤害段
		"base_value":         0.15,
		"card_type_filter":   2,
		"weapon_type_filter": -1,
		"rarity_pool":        ["epic", "legendary"],
		"unlock_condition":   "none",
		"wired":              true,
	},
	"sm_double_tap": {
		"affix_name":         "双重齐射",
		"description":        "攻击有 8% 概率造成双倍伤害",
		"affix_type":         "special_mechanic",
		"effect_key":         "double_strike_chance",  # v27.1 已接线：construct_unit_ai.do_attack_with_damage 结算段
		"base_value":         0.08,
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["epic", "legendary"],
		"unlock_condition":   "none",
		"wired":              true,
	},

	# ─── v27.2 星冥专属词条（xeno_only：仅星冥缴获卡 captured_xeno_* 可刷出） ─────
	## 主题取材星冥三机制（灵能护盾/共感/拟时回溯）；全部复用已接线 effect_key（零死词条），
	## 数值较同级通用词条强 20~40%。普通卡 roll 池恒排除（is_affix_available_for 默认拒绝）。
	## 不设 min_tier：星冥缴获卡无 tier 字段（默认 0），设了门槛就永远刷不出来。
	"xeno_veil_step": {
		"affix_name":         "蜃影游走",
		"description":        "【星冥专属】平台获得闪避几率（完全回避一次攻击）",
		"affix_type":         "combat_feature",
		"effect_key":         "dodge_chance",
		"base_value":         0.10,    # +10% 闪避（Lv1），通用相位闪避 5% / 轻装战术翻滚 8%
		"card_type_filter":   0,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"xeno_only":          true,
	},
	"xeno_star_surge": {
		"affix_name":         "星潮涌动",
		"description":        "【星冥专属】武器攻击伤害提升",
		"affix_type":         "base_property",
		"effect_key":         "attack_damage",
		"base_value":         0.20,    # +20% 伤害（Lv1），通用 15% / 空中俯冲 18%
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"xeno_only":          true,
	},
	"xeno_psi_carapace": {
		"affix_name":         "灵能甲壳",
		"description":        "【星冥专属】平台最大生命值提升",
		"affix_type":         "base_property",
		"effect_key":         "max_hp",
		"base_value":         0.20,    # +20% HP（Lv1），铁甲 12% / 重装甲列 18%
		"card_type_filter":   0,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"xeno_only":          true,
	},
	"xeno_communion": {
		"affix_name":         "共感协议",
		"description":        "【星冥专属】每次击杀获得一层护盾（每层抵挡部分伤害）",
		"affix_type":         "special_mechanic",
		"effect_key":         "shield_on_kill",
		"base_value":         0.08,    # 8% 最大HP护盾/击杀（Lv1），歼灭护盾 5% / 堡垒协议 10%
		"card_type_filter":   0,
		"weapon_type_filter": -1,
		"rarity_pool":        ["epic", "legendary"],
		"unlock_condition":   "none",
		"xeno_only":          true,
	},
	"xeno_nova_burst": {
		"affix_name":         "星核爆裂",
		"description":        "【星冥专属】攻击造成大范围溅射伤害",
		"affix_type":         "combat_feature",
		"effect_key":         "splash_damage",
		"base_value":         0.35,    # +35% 溅射（Lv1），爆裂弹头 20% / 轨道支援 30%
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["epic", "legendary"],
		"unlock_condition":   "none",
		"xeno_only":          true,
	},
	"xeno_apex_field": {
		"affix_name":         "威压星场",
		"description":        "【星冥专属】暴击伤害倍率提升（基础暴击1.5倍）",
		"affix_type":         "combat_feature",
		"effect_key":         "crit_damage_bonus",
		"base_value":         0.35,    # +0.35x 暴伤（Lv1），致命一击 0.2 / 斩首猎杀 0.3
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["epic", "legendary"],
		"unlock_condition":   "none",
		"xeno_only":          true,
	},

	# ─── v27.3 兵种专属词条扩充（每兵种 +2 常规 rare+ / +1 冠军 epic+ min_tier 3） ─────
	## 设计原则：词条语义贴合兵种身份（轻装=速射/精准、装甲=破甲/拦截/推进、
	## 支援=弹幕/工事/射程、空中=掠袭/机动/双发、堡垒=火网/自持/超射）；
	## 全部复用已接线 effect_key（零死词条）；同兵种内不重复 effect_key。

	# 轻装步兵（0）——快、灵、先手精准
	"light_blitz": {
		"affix_name":         "闪电速射",
		"description":        "【轻装专属】武器攻击间隔缩短（加快攻速）",
		"affix_type":         "base_property",
		"effect_key":         "attack_interval",
		"base_value":         0.10,    # 攻击间隔 -10%（Lv1）
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [0],
		"min_tier":           0,
	},
	"light_salvage": {
		"affix_name":         "战场搜救",
		"description":        "【轻装专属】击杀敌方单位后，回复自身最大生命值",
		"affix_type":         "combat_feature",
		"effect_key":         "kill_repair",
		"base_value":         0.04,    # 4% 自身最大HP/击杀（Lv1）
		"card_type_filter":   0,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [0],
		"min_tier":           0,
	},
	"light_deadeye": {
		"affix_name":         "神射手训练",
		"description":        "【轻装·冠军级独有】打出暴击后，下一次攻击必定命中（无视闪避）",
		"affix_type":         "special_mechanic",
		"effect_key":         "crit_ensure_hit",
		"base_value":         1.0,     # 机制开关型：1.0=启用
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [0],
		"min_tier":           3,
	},

	# 装甲（1）——硬、破甲、推进
	"armor_ap_shell": {
		"affix_name":         "破甲弹",
		"description":        "【装甲专属】攻击忽视目标伤害减免",
		"affix_type":         "combat_feature",
		"effect_key":         "armor_penetration",
		"base_value":         0.15,    # +15% 破甲（Lv1）
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [1],
		"min_tier":           0,
	},
	"armor_intercept": {
		"affix_name":         "主动拦截",
		"description":        "【装甲专属】受到攻击时，有概率完全格挡该次伤害",
		"affix_type":         "special_mechanic",
		"effect_key":         "intercept_chance",
		"base_value":         0.08,    # 8% 格挡（Lv1）
		"card_type_filter":   0,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [1],
		"min_tier":           0,
	},
	"armor_spearhead": {
		"affix_name":         "钢铁洪流",
		"description":        "【装甲·冠军级独有】生命值全满时，造成的伤害提升",
		"affix_type":         "special_mechanic",
		"effect_key":         "full_hp_damage_bonus",
		"base_value":         0.15,    # 满血 +15% 伤害（Lv1）
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [1],
		"min_tier":           3,
	},

	# 支援（2）——弹幕、工事、超远射程
	"support_ballistics": {
		"affix_name":         "弹道计算机",
		"description":        "【支援专属】攻击附加暴击几率（暴击造成1.5倍伤害）",
		"affix_type":         "combat_feature",
		"effect_key":         "crit_chance",
		"base_value":         0.08,    # +8% 暴击率（Lv1）
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [2],
		"min_tier":           0,
	},
	"support_fortify": {
		"affix_name":         "野战工事",
		"description":        "【支援专属】平台受到伤害减少",
		"affix_type":         "base_property",
		"effect_key":         "damage_reduction",
		"base_value":         0.06,    # -6% 受伤（Lv1）
		"card_type_filter":   0,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [2],
		"min_tier":           0,
	},
	"support_strategic_range": {
		"affix_name":         "战略射程",
		"description":        "【支援·冠军级独有】武器攻击射程大幅提升",
		"affix_type":         "base_property",
		"effect_key":         "attack_range",
		"base_value":         0.30,    # +30% 射程（Lv1），超视距打击 0.18
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [2],
		"min_tier":           3,
	},

	# 空中（3）——掠袭、机动、双发
	"air_strafe": {
		"affix_name":         "掠袭扫射",
		"description":        "【空中专属】武器攻击间隔缩短（加快攻速）",
		"affix_type":         "base_property",
		"effect_key":         "attack_interval",
		"base_value":         0.09,    # 攻击间隔 -9%（Lv1）
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [3],
		"min_tier":           0,
	},
	"air_ecm_detach": {
		"affix_name":         "电子对抗",
		"description":        "【空中专属】平台获得闪避几率（完全回避一次攻击）",
		"affix_type":         "combat_feature",
		"effect_key":         "dodge_chance",
		"base_value":         0.08,    # +8% 闪避（Lv1）
		"card_type_filter":   0,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [3],
		"min_tier":           0,
	},
	"air_double_rack": {
		"affix_name":         "双联挂架",
		"description":        "【空中·冠军级独有】攻击有概率造成双倍伤害",
		"affix_type":         "special_mechanic",
		"effect_key":         "double_strike_chance",
		"base_value":         0.10,    # 10% 双倍伤害（Lv1）
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [3],
		"min_tier":           3,
	},

	# 堡垒（4）——火网、自持、超越射击
	"fort_flaknet": {
		"affix_name":         "防空火网",
		"description":        "【堡垒专属】受到攻击时，有概率完全格挡该次伤害",
		"affix_type":         "special_mechanic",
		"effect_key":         "intercept_chance",
		"base_value":         0.06,    # 6% 格挡（Lv1）
		"card_type_filter":   0,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [4],
		"min_tier":           0,
	},
	"fort_selfrepair": {
		"affix_name":         "自修工事",
		"description":        "【堡垒专属】战斗中缓慢回复生命值",
		"affix_type":         "special_mechanic",
		"effect_key":         "hp_regen",
		"base_value":         0.005,   # 每秒回复 0.5% 最大HP（Lv1）
		"card_type_filter":   0,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [4],
		"min_tier":           0,
	},
	"fort_overwatch": {
		"affix_name":         "超越射击",
		"description":        "【堡垒·冠军级独有】武器攻击射程大幅提升",
		"affix_type":         "base_property",
		"effect_key":         "attack_range",
		"base_value":         0.22,    # +22% 射程（Lv1）
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [4],
		"min_tier":           3,
	},

	# ─── v27.4 兵种专属词条再扩充（每兵种 +3 常规 rare+ / +1 冠军 epic+ min_tier 3） ─────
	## 每兵种累计 10 条专属（7 常规 + 3 冠军）；原则同 v27.3：语义贴兵种身份、
	## 全部已接线 effect_key、同兵种内不重复 effect_key。

	# 轻装步兵——渗透/掩体/反装甲/人海
	"light_penetration": {
		"affix_name":         "渗透突袭",
		"description":        "【轻装专属】武器攻击伤害提升",
		"affix_type":         "base_property",
		"effect_key":         "attack_damage",
		"base_value":         0.12,
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [0],
		"min_tier":           0,
	},
	"light_dig_in": {
		"affix_name":         "临时掩体",
		"description":        "【轻装专属】平台受到伤害减少",
		"affix_type":         "base_property",
		"effect_key":         "damage_reduction",
		"base_value":         0.05,
		"card_type_filter":   0,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [0],
		"min_tier":           0,
	},
	"light_tandem": {
		"affix_name":         "猎杀小组",
		"description":        "【轻装专属】攻击忽视目标伤害减免",
		"affix_type":         "combat_feature",
		"effect_key":         "armor_penetration",
		"base_value":         0.12,    # 步兵反装甲（火箭筒组）
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [0],
		"min_tier":           0,
	},
	"light_swarm": {
		"affix_name":         "蜂群战术",
		"description":        "【轻装·冠军级独有】攻击有概率造成双倍伤害",
		"affix_type":         "special_mechanic",
		"effect_key":         "double_strike_chance",
		"base_value":         0.10,    # 10% 双倍伤害（Lv1）
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [0],
		"min_tier":           3,
	},

	# 装甲——装弹/附加装甲/机动/榴弹
	"armor_autoloader": {
		"affix_name":         "自动装弹机",
		"description":        "【装甲专属】武器攻击间隔缩短（加快攻速）",
		"affix_type":         "base_property",
		"effect_key":         "attack_interval",
		"base_value":         0.08,
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [1],
		"min_tier":           0,
	},
	"armor_def_skirt": {
		"affix_name":         "附加裙板",
		"description":        "【装甲专属】平台防御值提升（直接增加护甲）",
		"affix_type":         "base_property",
		"effect_key":         "defense",
		"base_value":         3.0,     # +3 DEF（Lv1）
		"card_type_filter":   0,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [1],
		"min_tier":           0,
	},
	"armor_offroad": {
		"affix_name":         "越野底盘",
		"description":        "【装甲专属】平台移动速度提升",
		"affix_type":         "base_property",
		"effect_key":         "move_speed",
		"base_value":         0.12,
		"card_type_filter":   0,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [1],
		"min_tier":           0,
	},
	"armor_thunder": {
		"affix_name":         "榴弹轰击",
		"description":        "【装甲·冠军级独有】攻击造成大范围溅射伤害",
		"affix_type":         "combat_feature",
		"effect_key":         "splash_damage",
		"base_value":         0.25,    # +25% 溅射（Lv1）
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [1],
		"min_tier":           3,
	},

	# 支援——压制/工程/护航/弹链
	"support_heavy_charge": {
		"affix_name":         "增压装药",
		"description":        "【支援专属】武器攻击伤害提升",
		"affix_type":         "base_property",
		"effect_key":         "attack_damage",
		"base_value":         0.12,
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [2],
		"min_tier":           0,
	},
	"support_pioneers": {
		"affix_name":         "工兵班组",
		"description":        "【支援专属】平台防御值提升（直接增加护甲）",
		"affix_type":         "base_property",
		"effect_key":         "defense",
		"base_value":         3.0,     # +3 DEF（Lv1）
		"card_type_filter":   0,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [2],
		"min_tier":           0,
	},
	"support_escort": {
		"affix_name":         "护航车队",
		"description":        "【支援专属】平台最大生命值提升",
		"affix_type":         "base_property",
		"effect_key":         "max_hp",
		"base_value":         0.10,    # +10% HP（Lv1）
		"card_type_filter":   0,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [2],
		"min_tier":           0,
	},
	"support_seismic": {
		"affix_name":         "地震战术",
		"description":        "【支援·冠军级独有】攻击有几率对附近敌人触发连锁伤害",
		"affix_type":         "special_mechanic",
		"effect_key":         "chain_chance",
		"base_value":         0.20,    # +20% 连锁（Lv1），交叉火力网 0.15
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [2],
		"min_tier":           3,
	},

	# 空中——对地挂载/火箭巢/高空/王牌
	"air_hardpoint": {
		"affix_name":         "重型挂载",
		"description":        "【空中专属】攻击造成范围溅射伤害",
		"affix_type":         "combat_feature",
		"effect_key":         "splash_damage",
		"base_value":         0.18,    # +18% 溅射（Lv1）
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [3],
		"min_tier":           0,
	},
	"air_rockets": {
		"affix_name":         "火箭巢",
		"description":        "【空中专属】攻击忽视目标伤害减免",
		"affix_type":         "combat_feature",
		"effect_key":         "armor_penetration",
		"base_value":         0.12,
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [3],
		"min_tier":           0,
	},
	"air_strato": {
		"affix_name":         "高空巡航",
		"description":        "【空中专属】武器攻击射程提升",
		"affix_type":         "base_property",
		"effect_key":         "attack_range",
		"base_value":         0.10,    # +10% 射程（Lv1）
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [3],
		"min_tier":           0,
	},
	"air_ace_pride": {
		"affix_name":         "王牌气场",
		"description":        "【空中·冠军级独有】每次击杀获得一层护盾（每层抵挡部分伤害）",
		"affix_type":         "special_mechanic",
		"effect_key":         "shield_on_kill",
		"base_value":         0.08,    # 8% 最大HP护盾/击杀（Lv1）
		"card_type_filter":   0,
		"weapon_type_filter": -1,
		"rarity_pool":        ["epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [3],
		"min_tier":           3,
	},

	# 堡垒——加固/伺服/闸门/湮灭
	"fort_thick_walls": {
		"affix_name":         "加固城墙",
		"description":        "【堡垒专属】平台最大生命值提升",
		"affix_type":         "base_property",
		"effect_key":         "max_hp",
		"base_value":         0.15,    # +15% HP（Lv1）
		"card_type_filter":   0,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [4],
		"min_tier":           0,
	},
	"fort_servo_mount": {
		"affix_name":         "伺服炮座",
		"description":        "【堡垒专属】武器攻击间隔缩短（加快攻速）",
		"affix_type":         "base_property",
		"effect_key":         "attack_interval",
		"base_value":         0.08,
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [4],
		"min_tier":           0,
	},
	"fort_blast_door": {
		"affix_name":         "装甲闸门",
		"description":        "【堡垒专属】平台受到伤害减少",
		"affix_type":         "base_property",
		"effect_key":         "damage_reduction",
		"base_value":         0.06,    # -6% 受伤（Lv1）
		"card_type_filter":   0,
		"weapon_type_filter": -1,
		"rarity_pool":        ["rare", "epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [4],
		"min_tier":           0,
	},
	"fort_annihilator": {
		"affix_name":         "湮灭炮击",
		"description":        "【堡垒·冠军级独有】暴击伤害倍率提升（基础暴击1.5倍）",
		"affix_type":         "combat_feature",
		"effect_key":         "crit_damage_bonus",
		"base_value":         0.32,    # +0.32x 暴伤（Lv1）
		"card_type_filter":   1,
		"weapon_type_filter": -1,
		"rarity_pool":        ["epic", "legendary"],
		"unlock_condition":   "none",
		"combat_kinds":       [4],
		"min_tier":           3,
	},
}

## 变异配置（词条 Lv5 时有概率触发，为词条额外添加特殊效果描述）
const MUTATION_TABLE: Dictionary = {
	"platform_hp_up":    "血量超过80%时，受到伤害额外减少10%",
	"weapon_dmg_up":     "攻击时有15%概率造成双倍伤害",
	"weapon_atkspd_up":  "连续攻击3次后，下次攻击伤害+50%",
	"crit_chance":       "暴击时额外恢复5%最大生命值",
	"lifesteal":         "生命值低于30%时，回收修复效果翻倍",
	"splash_dmg":        "溅射击杀时触发额外一次溅射",
	"chain_lightning":   "连锁最多延伸至5个目标",
	"shield_on_kill":    "护盾层数上限+2",
	"nano_regen":        "生命值低于50%时，回复速度翻倍",
	"platform_def_up":   "受到暴击时，额外减免30%暴击伤害",
	"dodge_chance":      "成功闪避后，下次攻击必定暴击",
	"crit_dmg_up":       "暴击击杀时，恢复10%最大生命值",
	# ─── v19 兵种专属/独特词条变异（纯描述层，暂无战斗实现，与上表口径一致） ──
	"light_skirmish":    "生命值低于40%时，移动速度额外提升15%",
	"light_evasion":     "连续闪避2次后，恢复3%最大生命值",
	"armor_column":      "生命值高于80%时，额外获得5%伤害减免",
	"armor_plating":     "受到暴击时，额外减免30%暴击伤害",
	"air_dive":          "目标生命值低于30%时，伤害额外提升25%",
	"air_supremacy":     "暴击时无视目标闪避",
	"support_outrange":  "攻击满射程边缘目标时，伤害提升15%",
	"support_repair":    "3秒未受攻击后，回复速度翻倍",
	"fort_bulwark":      "静止不动时，防御每秒+1（最多+10）",
	"fort_crossfire":    "连锁伤害的衰减减半",
	"light_executioner": "暴击伤害的20%转化为生命恢复",
	"armor_titan":       "生命值低于50%时，伤害减免额外+10%",
	"air_reaper":        "击杀后5秒内伤害提升20%",
	"support_orbital":   "溅射范围扩大50%",
	"fort_protocol":     "护盾被击破时，对周围敌人造成一次范围伤害",
	# ─── v21 P3-B（计划 C3）build-around 词条变异（纯描述层，与 v19 词条口径一致） ──
	"sm_kill_triage":      "击杀回复量低于 5% 最大生命时，回复量提升至 5%",
	"sm_intercept_guard":  "成功格挡后，下一次攻击伤害提升 25%",
	"sm_crit_ensure_hit":  "必定命中的那一击暴击率提升 20%",
	"sm_fullhp_onslaught": "满血状态额外获得 5% 伤害减免",
	"sm_double_tap":       "双倍伤害触发后，回复 2% 最大生命值",
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

## v19: 词条是否对该兵种/档位可用
## combat_kinds 空/缺省 = 通用词条（任何兵种可用）；非空 = 仅列表内兵种可用
## min_tier > tier 时不可用（特殊兵种独特词条门槛）
## v27.2: xeno_only 词条仅异族卡（p_is_xeno=true）可用——普通卡 roll 池恒排除
static func is_affix_available_for(affix_id: String, combat_kind: int, tier: int = 0, p_is_xeno: bool = false) -> bool:
	var def: Dictionary = get_definition(affix_id)
	if def.is_empty():
		return false
	if bool(def.get("xeno_only", false)) and not p_is_xeno:
		return false
	var kinds: Array = def.get("combat_kinds", []) as Array
	if not kinds.is_empty() and not kinds.has(combat_kind):
		return false
	if int(def.get("min_tier", 0)) > tier:
		return false
	return true

## v21 P3-B（计划 C3）：词条执行挂点是否已接。
## wired 缺省视为 true（全部历史词条默认已接入）；wired=false = 数据就绪、挂点待接，
## 不进任何 roll 池（防止玩家抽到无效词条），可复现性/展示查询不受影响。
static func is_affix_wired(affix_id: String) -> bool:
	var def: Dictionary = get_definition(affix_id)
	if def.is_empty():
		return false
	return bool(def.get("wired", true))

## v19: 该兵种可用的全部词条 ID（通用 + 本兵种专属，tier 达标的独特词条也计入）
static func get_ids_for_combat_kind(combat_kind: int, tier: int = 0) -> Array:
	var result: Array = []
	for id in AFFIX_TABLE.keys():
		if is_affix_available_for(String(id), combat_kind, tier):
			result.append(id)
	return result

## 获取变异描述
static func get_mutation_description(affix_id: String) -> String:
	if MUTATION_TABLE.has(affix_id):
		return String(MUTATION_TABLE[affix_id])
	return ""

## 按稀有度权重随机抽取一个词条ID（card_type: 0=平台, 1=武器）
## v19: 新增 combat_kind/tier 可选参数——传入时按兵种/档位过滤（空结果回退全池）
## v27.2: 新增 p_is_xeno——星冥专属词条（xeno_only）仅异族卡可出；
## 基础池先剔除（kind 过滤只在 combat_kind>=0 时生效，<0 的回退路径也必须排除）
static func roll_random_affix_id(card_type: int, rarity_override: String = "", combat_kind: int = -1, tier: int = 0, p_is_xeno: bool = false) -> String:
	var pool: Array = get_ids_for_card_type(card_type)
	if not p_is_xeno:
		var no_xeno: Array = []
		for id in pool:
			if not bool((AFFIX_TABLE[id] as Dictionary).get("xeno_only", false)):
				no_xeno.append(id)
		pool = no_xeno
	if pool.is_empty():
		return ""
	# v19: 兵种维度过滤；v27.2: 穿 p_is_xeno（否则 xeno_only 词条在此被默认拒绝）
	if combat_kind >= 0:
		var filtered: Array = []
		for id in pool:
			if is_affix_available_for(String(id), combat_kind, tier, p_is_xeno):
				filtered.append(id)
		if not filtered.is_empty():
			pool = filtered
	# 根据稀有度权重过滤
	var weighted: Array = []
	for id in pool:
		var def: Dictionary = AFFIX_TABLE[id] as Dictionary
		# v21 P3-B: wired=false（执行挂点待接）的词条不进 roll 池
		if not bool(def.get("wired", true)):
			continue
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
## v19: 新增 combat_kind/tier 参数——两段式 roll：先以 KIND_POOL_CHANCE 概率走本兵种
## 专属池（combat_kinds 匹配 + tier 达标），未命中/空池走通用池（combat_kinds 为空的词条）
static func roll_unlocked_affix_id(card_type: int, rarity: String, unlocked_bosses: Array, combat_kind: int = -1, tier: int = 0, p_is_xeno: bool = false) -> String:
	var pool: Array = get_unlocked_affix_ids(card_type, unlocked_bosses)
	# v27.2: 星冥专属词条仅异族卡可出（同 roll_random_affix_id 的基础池剔除）
	if not p_is_xeno:
		var no_xeno: Array = []
		for id in pool:
			if not bool((AFFIX_TABLE[id] as Dictionary).get("xeno_only", false)):
				no_xeno.append(id)
		pool = no_xeno
	if pool.is_empty():
		return ""
	# v19: 兵种两段式分流
	if combat_kind >= 0:
		var kind_pool: Array = []
		var generic_pool: Array = []
		for id in pool:
			var def: Dictionary = AFFIX_TABLE[id] as Dictionary
			var kinds: Array = def.get("combat_kinds", []) as Array
			if kinds.is_empty():
				generic_pool.append(id)
			elif kinds.has(combat_kind) and int(def.get("min_tier", 0)) <= tier:
				kind_pool.append(id)
		if not kind_pool.is_empty() and randf() < KIND_POOL_CHANCE:
			pool = kind_pool
		elif not generic_pool.is_empty():
			pool = generic_pool
		# 两池皆空（异常配置）时保留原 pool 兜底
	# 按稀有度过滤
	var weighted: Array = []
	for id in pool:
		var def: Dictionary = AFFIX_TABLE[id] as Dictionary
		# v21 P3-B: wired=false（执行挂点待接）的词条不进 roll 池
		if not bool(def.get("wired", true)):
			continue
		var rarity_pool: Array = def.get("rarity_pool", ["common"]) as Array
		if rarity_pool.has(rarity):
			weighted.append(id)
	# 如果指定稀有度没有合适的，降低要求
	if weighted.is_empty():
		for id in pool:
			# v21 P3-B: 降级兜底同样跳过 wired=false 词条
			var def_fb: Dictionary = AFFIX_TABLE[id] as Dictionary
			if not bool(def_fb.get("wired", true)):
				continue
			weighted.append(id)
	if weighted.is_empty():
		return ""
	return String(weighted[randi() % weighted.size()])
