extends RefCounted
class_name EnemyPhaseMasters
## 统一敌方相位师数据 -- 聚合文件
## 30位敌方相位师数据按时代拆分到 5 个子文件:
##   enemy_phase_masters_ww1.gd    一战 (master 001-006, Lv5-8)
##   enemy_phase_masters_ww2.gd    二战 (master 007-012, Lv10-14)
##   enemy_phase_masters_cold.gd   冷战 (master 013-018, Lv16-20)
##   enemy_phase_masters_modern.gd 现代 (master 019-024, Lv22-25)
##   enemy_phase_masters_future.gd 近未来 (master 025-030, Lv26-30)
##
## 外部 API 完全兼容：
##   EnemyPhaseMasters.ENEMY_MASTERS        -- 所有敌方相位师数组
##   EnemyPhaseMasters.get_master_by_id(...)  -- 按 ID 查找
##   EnemyPhaseMasters.get_masters_by_level(...) -- 按等级范围查找
##   等

const _MASTERS_JSON_PATH := "res://data/json/enemy_phase_masters.json"

## ---- 时代子文件 preload ----
const _WW1    = preload("res://data/enemy_phase_masters_ww1.gd")
const _WW2    = preload("res://data/enemy_phase_masters_ww2.gd")
const _COLD   = preload("res://data/enemy_phase_masters_cold.gd")
const _MODERN = preload("res://data/enemy_phase_masters_modern.gd")
const _FUTURE = preload("res://data/enemy_phase_masters_future.gd")
# v6.14: 相位师符文派生用
const _RuneDefs = preload("res://data/runes.gd")

## 从子文件合并所有时代数据（兼容原 LEGACY_ENEMY_MASTERS）
static var LEGACY_ENEMY_MASTERS: Array = (
	_WW1.ERA_MASTERS + _WW2.ERA_MASTERS + _COLD.ERA_MASTERS
	+ _MODERN.ERA_MASTERS + _FUTURE.ERA_MASTERS
)

## 优先加载 JSON，不存在则回退到内联数据
static var ENEMY_MASTERS: Array = _load_json_data(_MASTERS_JSON_PATH, LEGACY_ENEMY_MASTERS)

static func _load_json_data(path: String, fallback):
	if not FileAccess.file_exists(path):
		push_warning("[EnemyPhaseMasters] JSON missing: %s" % path)
		return fallback
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[EnemyPhaseMasters] JSON parse failed, using fallback")
		return fallback
	if int(parsed.get("schema_version", 0)) != 1:
		push_warning("[EnemyPhaseMasters] Unsupported schema version")
		return fallback
	var data = parsed.get("data", fallback)
	return data if typeof(data) == TYPE_ARRAY else fallback

## 按时代获取敌方相位师
static func get_era_masters(era: int) -> Array:
	match era:
		0: return _WW1.ERA_MASTERS    ## WW1
		1: return _WW2.ERA_MASTERS    ## WW2
		2: return _COLD.ERA_MASTERS   ## COLD_WAR
		3: return _MODERN.ERA_MASTERS ## MODERN
		4: return _FUTURE.ERA_MASTERS ## NEAR_FUTURE
	return []

## 特质效果类型说明（供战斗系统参考）
## trait.effects 可包含以下键:
## - defense_boost: float            防御百分比加成
## - attack_boost: float            攻击力百分比加成
## - attack_speed_boost: float      攻击速度百分比加成
## - hp_boost: float                生命值百分比加成
## - energy_regen_boost: float      能量恢复百分比加成
## - fire_damage_boost: float       火焰伤害百分比加成
## - lightning_damage_boost: float  雷电伤害百分比加成
## - void_damage_boost: float       虚空伤害百分比加成
## - all_damage_boost: float        所有伤害百分比加成
## - all_resistance_boost: float    所有抗性百分比加成
## - unit_limit_bonus: int          额外单位上限
## - cooldown_reduction: float      冷却减少百分比
## - energy_cost_reduction: float   能量消耗减少百分比
## - crit_chance: float             暴击率
## - burn_duration_bonus: float     燃烧持续时间额外秒数
## - chain_bounce_bonus: int        闪电链额外弹射次数
## - deploy_speed_boost: float      部署速度百分比加成
## - move_speed_boost: float        移动速度百分比加成
## - energy_drain_on_hit: float     攻击附带能量吸取百分比
## - magic_power_boost: float       法术强度百分比加成
## - boss_damage_boost: float       对首领伤害百分比加成
## - backstab_damage_boost: float   背刺伤害百分比加成
## - darkness_damage_boost: float   黑暗中伤害加成百分比
## - damage_cap: float              单次伤害上限(最大HP百分比)
## - unit_count_defense: float      每个友军提供的防御百分比
## - deploy_shield: int             部署时获得的护盾值
## - auto_spawn_interval: float     自动生产间隔(秒)
## - fire_cooldown_reduction: float 火焰技能冷却减少百分比
## - auto_revive_once: dict         单次自动复活 {hp_percent, delay}
## - full_resurrect_once: bool      单次完全复活
## - divine_transform: dict         神圣变身 {duration, all_stat_boost}
## - cheat_death_chance: float      免死概率
## - global_dot: int                全局每秒伤害
## - permanent_darkness: float      永久黑暗命中率降低
## - mass_convert_once: bool        单次转化敌方单位
## - instant_delete: dict           现实抹除 {cooldown}
## - auto_thunder_dome: dict        自动雷霆穹顶 {interval, duration}
## - scaling_per_cast: float        每次施法属性提升
## - synergy_boost: float           协同加成
## - synergy_types: Array           协同势力类型
## - time_scaling: dict             时间缩放 {interval, boost}
## - flame_trail: bool              燃烧轨迹
## - energy_full_auto_strike: bool  能量满自动打击
## - burn_energy_drain_mult: float  燃烧能量流失倍率
## - dual_damage_chance: float      双重伤害概率
## - enemy_defense_reduction: float 敌方防御降低百分比
## - armor_reflect: int             护甲反射伤害值

## 获取指定等级的敌方相位师
static func get_masters_by_level(min_level: int, max_level: int) -> Array:
	var result = []
	for master in ENEMY_MASTERS:
		var level = master.get("level", 1)
		if level >= min_level and level <= max_level:
			result.append(master)
	return result

## 获取指定势力的敌方相位师
static func get_masters_by_faction(faction: String) -> Array:
	var result = []
	for master in ENEMY_MASTERS:
		if master.get("faction", "") == faction:
			result.append(master)
	return result

## 获取指定难度的敌方相位师
static func get_masters_by_difficulty(difficulty: String) -> Array:
	var result = []
	for master in ENEMY_MASTERS:
		if master.get("difficulty", "") == difficulty:
			result.append(master)
	return result

## 根据ID获取敌方相位师
static func get_master_by_id(master_id: String) -> Dictionary:
	for master in ENEMY_MASTERS:
		if master.get("id", "") == master_id:
			return master
	return {}

## 获取敌方相位师的特性
static func get_master_traits(master_id: String) -> Array:
	var master = get_master_by_id(master_id)
	if not master.is_empty():
		return master.get("traits", [])
	return []

## 获取敌方相位师的主动技能
static func get_master_active_spells(master_id: String) -> Array:
	var master = get_master_by_id(master_id)
	if not master.is_empty():
		return master.get("active_spells", [])
	return []

## 获取敌方相位师的被动技能
static func get_master_passive_spells(master_id: String) -> Array:
	var master = get_master_by_id(master_id)
	if not master.is_empty():
		return master.get("passive_spells", [])
	return []

## 获取敌方相位师的装备配置
static func get_master_equipment(master_id: String) -> Dictionary:
	var master = get_master_by_id(master_id)
	if not master.is_empty():
		return master.get("equipment", {})
	return {}

## v6.14: 获取相位师的"增强装备"——在原 equipment 基础上程序化派生 runes 和 spawn_sequence。
## 数据文件中 equipment 可能没有 runes/spawn_sequence 字段（向后兼容），本函数按 level/faction
## 程序化补全，让每个相位师都有符文配置和出兵序列，无需手填 30 条数据。
##
## 派生规则：
## - runes：按 level 选稀有度（Lv5-9→common+rare，Lv10-19→rare+epic，Lv20+→epic+legendary），
##          从 generic 池随机选 2-4 个（level 越高越多）。若数据已含 runes 则用原值。
## - spawn_sequence：按 platforms 列表生成循环序列（带 level 相关的精英/boss 平台标记），
##                   若数据已含 spawn_sequence 则用原值。
##
## [return] 增强后的 equipment 字典（原 equipment 的深拷贝 + 派生字段）
static func get_enriched_equipment(master_id: String) -> Dictionary:
	var master: Dictionary = get_master_by_id(master_id)
	if master.is_empty():
		return {}
	var equip: Dictionary = master.get("equipment", {}).duplicate(true)
	var level: int = int(master.get("level", 5))
	# runes
	if not equip.has("runes") or equip.get("runes", []).is_empty():
		equip["runes"] = _derive_runes(level, String(master.get("faction", "")))
	# spawn_sequence
	if not equip.has("spawn_sequence") or equip.get("spawn_sequence", []).is_empty():
		equip["spawn_sequence"] = _derive_spawn_sequence(equip.get("platforms", []), level)
	return equip


## v6.14: 按 level 派生相位师符文。从 generic 池按稀有度梯度选 2-4 个。
static func _derive_runes(level: int, faction_family: String) -> Array:
	# 稀有度池：level 越高，高稀有度比例越大
	var pool: Array[Dictionary] = []
	pool.append_array(_RuneDefs.get_generic_runes())
	if pool.is_empty():
		return []
	# 按 level 确定候选稀有度
	var rarities: Array[String] = []
	if level <= 9:
		rarities = [_RuneDefs.RARITY_COMMON, _RuneDefs.RARITY_RARE]
	elif level <= 19:
		rarities = [_RuneDefs.RARITY_RARE, _RuneDefs.RARITY_EPIC]
	else:
		rarities = [_RuneDefs.RARITY_EPIC, _RuneDefs.RARITY_LEGENDARY]
	# 筛出候选稀有度的符文
	var candidates: Array[Dictionary] = []
	for r in pool:
		if r.get("rarity", "") in rarities:
			candidates.append(r)
	if candidates.is_empty():
		candidates = pool  # 兜底
	# 用 master_id 相关种子选（保证同相位师每次相同，跨战斗一致）
	# 注意：此处不带种子（randi），因 callers 通常在战斗开始时调一次；如需严格一致可由调用方缓存
	var count: int = clampi(2 + int(level / 10), 2, 4)  # Lv5→2, Lv15→3, Lv25→4
	var picked: Array[String] = []
	var remaining: Array = candidates.duplicate()
	for _i in range(mini(count, remaining.size())):
		var idx: int = randi() % remaining.size()
		picked.append(String(remaining[idx].get("id", "")))
		remaining.remove_at(idx)
	return picked


## v6.14: 按 platforms 派生出兵序列。
## 序列结构：[{platform, type}, ...]，type 为 "normal"/"elite"/"boss"，
## 决定该次产兵的平台和是否附带精英/boss 标记（产兵时叠加额外加成）。
## 规则：循环遍历 platforms，每 4 个插入一个 "elite"，序列末尾插一个 "boss"（若有 boss 平台）。
static func _derive_spawn_sequence(platforms: Array, level: int) -> Array:
	if platforms.is_empty():
		return []
	var seq: Array = []
	var pos: int = 0
	var seq_len: int = clampi(6 + level / 4, 6, 14)  # Lv5→7, Lv30→13
	for i in range(seq_len):
		var pid: String = String(platforms[pos % platforms.size()])
		var entry_type: String = "normal"
		# 每 4 步出一个 elite（level 越高越频繁）
		var elite_every: int = 5 if level < 15 else 4
		if i > 0 and i % elite_every == 0:
			entry_type = "elite"
		seq.append({"platform": pid, "type": entry_type})
		pos += 1
	# 序列末尾加 boss（用最后一个平台）
	if not platforms.is_empty():
		seq.append({"platform": String(platforms[platforms.size() - 1]), "type": "boss"})
	return seq


## 获取敌方相位师的属性
static func get_master_stats(master_id: String) -> Dictionary:
	var master = get_master_by_id(master_id)
	if not master.is_empty():
		return master.get("stats", {})
	return {}

## 获取推荐战斗等级
static func get_recommended_level(master_id: String) -> int:
	var master = get_master_by_id(master_id)
	if not master.is_empty():
		return master.get("level", 1)
	return 1

## 创建敌方相位师实例
static func create_master_instance(master_id: String) -> Dictionary:
	var master = get_master_by_id(master_id)
	if master.is_empty():
		return {}

	return {
		"instance_id": master_id + "_" + str(Time.get_unix_time_from_system()),
		"template_id": master_id,
		"current_hp": master.get("stats", {}).get("max_hp", 0),
		"current_energy": 0,
		"skill_cooldowns": {},
		"passive_effects": [],
		"active_traits": [],
		"spawned_units": []
	}
