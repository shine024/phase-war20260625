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
##   B 机制型（apply 改 stats 字段 + 战斗路径消费）：
##     kill_repair / chain_chance / splash_damage / armor_reflect
##   C v19 兵种专属/独特扩展（战斗路径同样自动读取）：
##     move_speed / damage_reduction / attack_range / defense / crit_damage_bonus

## 词缀稀有度档位（决定词缀强度 + 出现概率）
enum AffixRarity { COMMON, RARE, ELITE_ONLY }

## v19: 兵种专属词缀池优先概率（两段式：先以此概率走本兵种专属池，空池/未命中走通用池）
const KIND_POOL_CHANCE: float = 0.55

## v19: 特殊档位独特词缀门槛（卡牌 Tier >= 此值才可 roll；3=CHAMPION/4=BOSS/5=ULTIMATE/6=FORT）
const UNIQUE_AFFIX_MIN_TIER: int = 3

## 词缀定义表：affix_id → {name, description, effect_key, base_value, rarity, combat_kinds(空=全兵种), min_tier(0=无门槛)}
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
		"name": "战场回收",
		"description": "击杀时回复自身 12% 最大生命",
		"effect_key": "kill_repair",
		"base_value": 0.12,
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
		"min_tier": 0,
	},

	# ══════════ v19 兵种专属词缀（combat_kinds 限定，每兵种 2 个） ══════════
	"enemy_gale_raid": {
		"name": "疾风突袭",
		"description": "移动速度 +35%",
		"effect_key": "move_speed",
		"base_value": 0.35,
		"rarity": AffixRarity.COMMON,
		"combat_kinds": [0],  # 轻装
		"min_tier": 0,
	},
	"enemy_ghost_step": {
		"name": "幽灵步伐",
		"description": "闪避率 +25%",
		"effect_key": "dodge_chance",
		"base_value": 0.25,
		"rarity": AffixRarity.COMMON,
		"combat_kinds": [0],  # 轻装
		"min_tier": 0,
	},
	"enemy_steel_tide": {
		"name": "钢铁洪流",
		"description": "生命值 +75%",
		"effect_key": "max_hp",
		"base_value": 0.75,
		"rarity": AffixRarity.COMMON,
		"combat_kinds": [1],  # 装甲
		"min_tier": 0,
	},
	"enemy_compound_armor": {
		"name": "复合装甲",
		"description": "受到伤害减少 15%",
		"effect_key": "damage_reduction",
		"base_value": 0.15,
		"rarity": AffixRarity.RARE,
		"combat_kinds": [1],  # 装甲
		"min_tier": 0,
	},
	"enemy_dive_strike": {
		"name": "掠袭俯冲",
		"description": "攻击力 +40%",
		"effect_key": "attack_damage",
		"base_value": 0.40,
		"rarity": AffixRarity.COMMON,
		"combat_kinds": [3],  # 空中
		"min_tier": 0,
	},
	"enemy_airspace_hunt": {
		"name": "空域猎杀",
		"description": "暴击率 +20%",
		"effect_key": "crit_chance",
		"base_value": 0.20,
		"rarity": AffixRarity.RARE,
		"combat_kinds": [3],  # 空中
		"min_tier": 0,
	},
	"enemy_long_bombard": {
		"name": "超远程炮击",
		"description": "攻击射程 +30%",
		"effect_key": "attack_range",
		"base_value": 0.30,
		"rarity": AffixRarity.COMMON,
		"combat_kinds": [2],  # 支援
		"min_tier": 0,
	},
	"enemy_field_rebuild": {
		"name": "战地重构",
		"description": "每秒回复 2.0% 最大生命",
		"effect_key": "hp_regen",
		"base_value": 0.020,
		"rarity": AffixRarity.RARE,
		"combat_kinds": [2],  # 支援
		"min_tier": 0,
	},
	"enemy_permament_works": {
		"name": "永固工事",
		"description": "防御值 +8",
		"effect_key": "defense",
		"base_value": 8.0,
		"rarity": AffixRarity.COMMON,
		"combat_kinds": [4],  # 堡垒
		"min_tier": 0,
	},
	"enemy_fireweb": {
		"name": "火网封锁",
		"description": "攻击弹射附近敌人 +25%",
		"effect_key": "chain_chance",
		"base_value": 0.25,
		"rarity": AffixRarity.RARE,
		"combat_kinds": [4],  # 堡垒
		"min_tier": 0,
	},

	# ══════════ v19 特殊档位独特词缀（min_tier >= CHAMPION，仅 boss 波可出） ══════════
	"enemy_execution_protocol": {
		"name": "处刑协议",
		"description": "暴击伤害 +0.5x",
		"effect_key": "crit_damage_bonus",
		"base_value": 0.50,
		"rarity": AffixRarity.ELITE_ONLY,
		"combat_kinds": [0],  # 轻装
		"min_tier": 3,
	},
	"enemy_titan_armor": {
		"name": "泰坦装甲",
		"description": "生命值 +100%",
		"effect_key": "max_hp",
		"base_value": 1.00,
		"rarity": AffixRarity.ELITE_ONLY,
		"combat_kinds": [1],  # 装甲
		"min_tier": 3,
	},
	"enemy_death_scythe": {
		"name": "死神镰刀",
		"description": "攻击力 +55%",
		"effect_key": "attack_damage",
		"base_value": 0.55,
		"rarity": AffixRarity.ELITE_ONLY,
		"combat_kinds": [3],  # 空中
		"min_tier": 3,
	},
	"enemy_orbital_bombard": {
		"name": "轨道轰炸",
		"description": "范围溅射伤害 +50%",
		"effect_key": "splash_damage",
		"base_value": 0.50,
		"rarity": AffixRarity.ELITE_ONLY,
		"combat_kinds": [2],  # 支援
		"min_tier": 3,
	},
	"enemy_fortress_will": {
		"name": "堡垒意志",
		"description": "受到伤害时反弹 35%",
		"effect_key": "armor_reflect",
		"base_value": 0.35,
		"rarity": AffixRarity.ELITE_ONLY,
		"combat_kinds": [4],  # 堡垒
		"min_tier": 3,
	},
}


## 按 spawn_type（normal/elite/boss）roll 一组词缀。
## 返回词缀定义 Dictionary 列表（{id, name, description, effect_key, base_value}）。
## normal → 不 roll（返回空）；elite → 1 个 common/rare；boss → 2 个（含 elite_only 池）。
## v19: 新增 combat_kind/tier 参数——池按兵种互斥过滤（他兵种专属词缀不进池），
## tier 达标的独特词缀（min_tier >= CHAMPION）进池；再两段式分流（55% 优先本兵种专属池）。
static func roll_affixes(spawn_type: String, rng: RandomNumberGenerator = null, combat_kind: int = -1, tier: int = 0) -> Array:
	var own_rng: RandomNumberGenerator = rng if rng != null else RandomNumberGenerator.new()
	if own_rng == rng and rng == null:
		own_rng = RandomNumberGenerator.new()
	if own_rng.seed == 0 and rng == null:
		own_rng.randomize()
	var result: Array = []
	match spawn_type:
		"elite":
			# 精英：1 个词缀，common 权重 2 / rare 权重 1
			var pool_elite: Array = _pick_kind_or_generic(
				_filter_by_rarities([AffixRarity.COMMON, AffixRarity.RARE], combat_kind, tier),
				combat_kind, own_rng)
			if not pool_elite.is_empty():
				result.append(_pick_weighted(pool_elite, [2.0, 1.0], own_rng))
		"boss":
			# boss：2 个词缀，从 common/rare/elite_only 池抽（不重复）
			var pool_boss: Array = _pick_kind_or_generic(
				_filter_by_rarities([AffixRarity.COMMON, AffixRarity.RARE, AffixRarity.ELITE_ONLY], combat_kind, tier),
				combat_kind, own_rng)
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


## v19: 两段式池分流——以 KIND_POOL_CHANCE 概率走本兵种专属池（combat_kinds 匹配者），
## 未命中/空池走通用池（combat_kinds 为空者）。入参 pool 需已做过兵种互斥过滤。
static func _pick_kind_or_generic(pool: Array, combat_kind: int, rng: RandomNumberGenerator) -> Array:
	if combat_kind < 0 or pool.is_empty():
		return pool
	var kind_pool: Array = []
	var generic_pool: Array = []
	for entry in pool:
		var kinds: Array = entry.get("combat_kinds", []) as Array
		if kinds.is_empty():
			generic_pool.append(entry)
		else:
			kind_pool.append(entry)
	if not kind_pool.is_empty() and rng.randf() < KIND_POOL_CHANCE:
		return kind_pool
	if not generic_pool.is_empty():
		return generic_pool
	return pool  # 两池皆空（异常配置）时保留原池兜底


## 按稀有度过滤词缀池，返回 [{id, ...rarity_info}] 列表（带 rarity 标记，用于权重抽取）。
## v19: 新增 combat_kind/tier 过滤——他兵种专属词缀剔除；min_tier 超过 tier 的独特词缀剔除。
static func _filter_by_rarities(rarities: Array, combat_kind: int = -1, tier: int = 0) -> Array:
	var result: Array = []
	for affix_id in ENEMY_AFFIXES:
		var def: Dictionary = ENEMY_AFFIXES[affix_id]
		var r: int = int(def.get("rarity", AffixRarity.COMMON))
		if r in rarities:
			if combat_kind >= 0:
				var kinds: Array = def.get("combat_kinds", []) as Array
				if not kinds.is_empty() and not kinds.has(combat_kind):
					continue
				if int(def.get("min_tier", 0)) > tier:
					continue
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
			"kill_repair":
				stats.kill_repair = minf(0.50, stats.kill_repair + val)
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
			"move_speed":
				# v19 兵种专属（轻装·疾风突袭）：乘区，下限防归零
				stats.move_speed = maxf(5.0, stats.move_speed * (1.0 + val))
			"damage_reduction":
				# v19 兵种专属（装甲·复合装甲）：加法，封顶对齐玩家侧 0.75
				stats.damage_reduction = minf(0.75, stats.damage_reduction + val)
			"attack_range":
				# v19 兵种专属（支援·超远程炮击）：乘区，下限 50px 防异常
				stats.attack_range = maxf(50.0, stats.attack_range * (1.0 + val))
			"defense":
				# v19 兵种专属（堡垒·永固工事）：主防御 + 三维防御同加（对齐 CardGrowthConfig 口径）
				stats.defense += val
				stats.defense_light += val
				stats.defense_armor += val
				stats.defense_air += val
			"crit_damage_bonus":
				# v19 独特（轻装·处刑协议）：暴伤加成，bullet 单发暴击结算读此字段（1.5x 基础）
				stats.crit_damage_bonus += val


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
