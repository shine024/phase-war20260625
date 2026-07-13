extends RefCounted
class_name EnemyAffixes
## v8 精英敌人词缀系统（批次2）
## 让普通波次敌人也有机制差异（暗黑破坏神式词缀怪），精英/boss 波随机获得 1-2 词缀。
##
## 设计：
## - 复用玩家词缀的 effect_key 命名空间与 UnitStats 字段映射口径
## - 独立于 AffixManager（精英无卡，绕开 CardResource 依赖）
## - 词缀是"一次性附加"（不存档，不升级），roll 后返回纯数据 Dictionary 列表
## - enemy_unit.apply_elite_affixes() 消费：数值型直接改 stats；机制型改 stats + _do_attack 触发
##
## effect_key 分两类：
##   A 数值型（apply 时改 stats 字段，战斗路径自动读取）：
##     attack_damage / max_hp / attack_speed / dodge_chance / crit_chance / hp_regen
##   B 机制型（apply 改 stats 字段 + _do_attack 调 AffixCombatHandler 触发）：
##     lifesteal / chain_chance / splash_damage / shield_on_kill

## 词缀稀有度档位（决定词缀强度 + 出现概率）
enum AffixRarity { COMMON, RARE, ELITE_ONLY }

## 词缀定义表：affix_id → {name, description, effect_key, base_value, rarity, combat_kinds(空=全兵种)}
const ENEMY_AFFIXES: Dictionary = {
	# ══════════ COMMON（数值强化，精英/boss 波均有几率） ══════════
	"enemy_frenzy": {
		"name": "狂暴",
		"description": "攻击力 +30%",
		"effect_key": "attack_damage",
		"base_value": 0.30,
		"rarity": AffixRarity.COMMON,
		"combat_kinds": [],
	},
	"enemy_tough": {
		"name": "坚韧",
		"description": "生命值 +60%",
		"effect_key": "max_hp",
		"base_value": 0.60,
		"rarity": AffixRarity.COMMON,
		"combat_kinds": [],
	},
	"enemy_swift": {
		"name": "加速",
		"description": "攻击速度 +25%",
		"effect_key": "attack_speed",
		"base_value": 0.25,
		"rarity": AffixRarity.COMMON,
		"combat_kinds": [],
	},
	"enemy_evade": {
		"name": "闪避",
		"description": "闪避率 +20%",
		"effect_key": "dodge_chance",
		"base_value": 0.20,
		"rarity": AffixRarity.COMMON,
		"combat_kinds": [],
	},
	# ══════════ RARE（机制型，仅 boss 波 + 高难度精英波） ══════════
	"enemy_crit": {
		"name": "致命",
		"description": "暴击率 +30%",
		"effect_key": "crit_chance",
		"base_value": 0.30,
		"rarity": AffixRarity.RARE,
		"combat_kinds": [],
	},
	"enemy_regen": {
		"name": "再生",
		"description": "每秒回复 1.5% 最大生命",
		"effect_key": "hp_regen",
		"base_value": 0.015,
		"rarity": AffixRarity.RARE,
		"combat_kinds": [],
	},
	"enemy_vampire": {
		"name": "吸血",
		"description": "吸血 +18%",
		"effect_key": "lifesteal",
		"base_value": 0.18,
		"rarity": AffixRarity.RARE,
		"combat_kinds": [],
	},
	"enemy_chain": {
		"name": "连锁",
		"description": "攻击弹射附近敌人",
		"effect_key": "chain_chance",
		"base_value": 0.40,
		"rarity": AffixRarity.RARE,
		"combat_kinds": [],  # 近战单位链不到远处，但 chain_chance 低也不亏
	},
	"enemy_splash": {
		"name": "溅射",
		"description": "范围溅射伤害",
		"effect_key": "splash_damage",
		"base_value": 0.35,
		"rarity": AffixRarity.RARE,
		"combat_kinds": [],
	},
	# ══════════ ELITE_ONLY（强力机制，仅 boss 波 + 相位师 elite 产兵） ══════════
	"enemy_reflect": {
		"name": "反伤",
		"description": "受到伤害时反弹 25%",
		"effect_key": "armor_reflect",
		"base_value": 0.25,
		"rarity": AffixRarity.ELITE_ONLY,
		"combat_kinds": [],  # 装甲/堡垒更配但全兵种可用
	},
}


## 按 spawn_type（normal/elite/boss）roll 一组词缀。
## 返回词缀定义 Dictionary 列表（{id, name, description, effect_key, base_value}）。
## normal → 不 roll（返回空）；elite → 1 个 common/rare；boss → 2 个（含 elite_only 池）。
static func roll_affixes(spawn_type: String, rng: RandomNumberGenerator = null) -> Array:
	var own_rng: RandomNumberGenerator = rng if rng != null else RandomNumberGenerator.new()
	if own_rng == rng and rng == null:
		own_rng = RandomNumberGenerator.new()
	if own_rng.seed == 0 and rng == null:
		own_rng.randomize()
	var result: Array = []
	match spawn_type:
		"elite":
			# 精英：1 个词缀，common 权重 2 / rare 权重 1
			var pool_elite: Array = _filter_by_rarities([AffixRarity.COMMON, AffixRarity.RARE])
			if not pool_elite.is_empty():
				result.append(_pick_weighted(pool_elite, [2.0, 1.0], own_rng))
		"boss":
			# boss：2 个词缀，从 common/rare/elite_only 池抽（不重复）
			var pool_boss: Array = _filter_by_rarities([AffixRarity.COMMON, AffixRarity.RARE, AffixRarity.ELITE_ONLY])
			var picks: int = mini(2, pool_boss.size())
			var available: Array = pool_boss.duplicate()
			for _i in range(picks):
				if available.is_empty():
					break
				var idx: int = own_rng.randi() % available.size()
				result.append(available[idx])
				available.remove_at(idx)
		_:
			pass  # normal 不 roll
	return result


## 按稀有度过滤词缀池，返回 [{id, ...rarity_info}] 列表（带 rarity 标记，用于权重抽取）。
static func _filter_by_rarities(rarities: Array) -> Array:
	var result: Array = []
	for affix_id in ENEMY_AFFIXES:
		var def: Dictionary = ENEMY_AFFIXES[affix_id]
		var r: int = int(def.get("rarity", AffixRarity.COMMON))
		if r in rarities:
			var entry: Dictionary = {"id": affix_id}
			entry.merge(def, true)
			result.append(entry)
	return result


## 按权重抽取一个词缀（weights 对应 rarities 顺序的权重）。
static func _pick_weighted(pool: Array, weights: Array, rng: RandomNumberGenerator) -> Dictionary:
	# pool 元素含 rarity 字段，按 weights 给不同 rarity 不同权重
	var weighted: Array = []
	for entry in pool:
		var r: int = int(entry.get("rarity", AffixRarity.COMMON))
		var w: float = 1.0
		if r < weights.size():
			w = weights[r]
		for _j in range(maxi(1, int(round(w)))):
			weighted.append(entry)
	if weighted.is_empty():
		return {}
	return weighted[rng.randi() % weighted.size()]


## 把词缀效果应用到 UnitStats（数值型直接改字段；机制型也改字段，触发由 _do_attack 负责）。
## 返回实际应用的词缀列表（供调用方记录到单位节点，用于 _do_attack 触发 + UI 显示）。
## 注意：max_hp 应用后需同步裸 hp/max_hp（由调用方处理，因 enemy_unit 持有裸字段）。
static func apply_to_stats(stats: UnitStats, affixes: Array) -> void:
	if stats == null or affixes.is_empty():
		return
	for affix in affixes:
		var key: String = String(affix.get("effect_key", ""))
		var val: float = float(affix.get("base_value", 0.0))
		match key:
			"attack_damage":
				# 注意：UnitStats.attack_damage 是 attack_light 的别名（setter 联动），
				# 故只需乘 attack_armor/attack_air；attack_light 通过 attack_damage 设置联动。
				stats.attack_armor = maxf(0.1, stats.attack_armor * (1.0 + val))
				stats.attack_air = maxf(0.1, stats.attack_air * (1.0 + val))
				stats.attack_damage = maxf(0.1, stats.attack_damage * (1.0 + val))  # 联动 attack_light
				if stats.has_method("_sync_weapon_slots_damage"):
					stats._sync_weapon_slots_damage(1.0 + val)
			"max_hp":
				stats.max_hp = maxf(1.0, stats.max_hp * (1.0 + val))
			"attack_speed":
				# 攻速 +val% → interval ×(1/(1+val))；同步武器槽 attack_speed
				var spd_mult: float = 1.0 + val
				stats.attack_interval = maxf(0.05, stats.attack_interval / spd_mult)
				for w in stats.weapon_slots:
					if w != null and w.enabled:
						w.attack_speed = maxf(0.1, float(w.attack_speed) * spd_mult)
			"dodge_chance":
				stats.dodge_chance = minf(0.50, stats.dodge_chance + val)
			"crit_chance":
				stats.crit_chance = minf(0.60, stats.crit_chance + val)
			"hp_regen":
				stats.hp_regen += val
			"lifesteal":
				stats.lifesteal = minf(0.50, stats.lifesteal + val)
			"chain_chance":
				stats.chain_chance = minf(0.60, stats.chain_chance + val)
			"splash_damage":
				stats.splash_damage = minf(0.60, stats.splash_damage + val)
			"armor_reflect":
				# 反伤用 damage_reduction 通道不合适（那是减伤），单独存到 armor_reflect 字段
				# UnitStats 若无此字段则用 set_meta 兜底（enemy_unit._get_armor_reflect_ratio 读取）
				if "armor_reflect" in stats:
					stats.armor_reflect = clampf(stats.armor_reflect + val, 0.0, 0.60)
				else:
					stats.set_meta("armor_reflect", clampf(val, 0.0, 0.60))


## 获取词缀显示名列表（供 UI / 信息面板显示）。
static func get_display_names(affixes: Array) -> Array:
	var names: Array = []
	for affix in affixes:
		names.append(String(affix.get("name", "")))
	return names


## 按稀有度获取边框颜色（供词缀怪视觉标记用）。
static func get_border_color_for_rarity(spawn_type: String) -> Color:
	match spawn_type:
		"boss":
			return Color(1.0, 0.55, 0.0)  # 橙色
		"elite":
			return Color(0.6, 0.3, 0.85)  # 紫色
		_:
			return Color(0.3, 0.5, 0.9)  # 蓝色（common 词缀怪）
