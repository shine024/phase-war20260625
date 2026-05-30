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
