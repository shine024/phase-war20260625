extends RefCounted
class_name BattleEnvEffects
## v26.2 战斗环境效果——BattleEnvironments 四维数据（天气/地形/能量场/时段）的数值真身。
## 此前四维数据零玩法消费（仅世界地图标签显示）；本表把每个环境值映射为一条效果，
## 四维乘法叠加后乘在 stats 构建层（玩家 battle_spawn_system._build_stats_cached /
## 经典敌兵 enemy_unit._apply_archetype_stats / 相位师产兵 driver 三处同口径），
## 直射/曲射两条伤害路径与面板显示自动一致（v25.0"乘在构建层"教训）。
##
## 设计原则：敌我对称生效；每维量级 ≤12%；效果单一可读（战前 world_map + 战内
## TopHudBar 环境 chip 双端可查）；总开关 GameConfig.env_effects_enabled
## （回滚先例 aura_range_enabled）。
##
## 聚合键（get_level_env_mults 返回）：
##   indirect_dmg  曲射类伤害乘区（GC.is_indirect_weapon_type 判定，含空射）
##   direct_dmg    直射类伤害乘区
##   all_dmg       全伤害乘区（不分直曲；城区/纳米雾）
##   direct_range  直射类射程乘区（仅"全直射单位"应用——UnitStats 单一射程，
##                 混装直曲的单位不乘，避免曲射武器射程被误降）
##   atk_speed     攻速乘区（乘 attack_*_speed = 1/interval）
##   regen         能量回复乘区（battle_manager 走 level_regen_mult 既有通道）
##   descs         UI 描述行（战前/战内共用）

const BattleEnvironmentsRef = preload("res://data/battle_environments.gd")
const GC = preload("res://resources/game_constants.gd")
const GameCfg = preload("res://resources/game_config.gd")

## 天气 → 效果（缺省值=无效果）
const WEATHER_EFFECTS: Dictionary = {
	"clear": {},
	"rain": {"indirect_dmg": 0.90, "desc": "雨：曲射武器伤害 -10%"},
	"snow": {"atk_speed": 0.92, "desc": "雪：全体攻速 -8%"},
	"storm": {"direct_dmg": 0.92, "desc": "暴风雨：直射武器伤害 -8%"},
	"sandstorm": {"direct_range": 0.85, "desc": "沙暴：直射武器射程 -15%"},
}

## 地形 → 效果
const TERRAIN_EFFECTS: Dictionary = {
	"plain": {},
	"city": {"all_dmg": 0.925, "desc": "城区：全体伤害 -7.5%（巷战掩蔽）"},
}

## 能量场 → 效果
const ENERGY_FIELD_EFFECTS: Dictionary = {
	"normal": {},
	"low_field": {"regen": 0.80, "desc": "低能量场：能量回复 -20%"},
	"high_field": {"regen": 1.15, "desc": "高能量场：能量回复 +15%"},
	"nano_fog": {"all_dmg": 0.95, "desc": "纳米雾：全体伤害 -5%"},
}

## 时段 → 效果
const TIME_OF_DAY_EFFECTS: Dictionary = {
	"day": {},
	"dusk": {"direct_range": 0.92, "desc": "黄昏：直射武器射程 -8%"},
	"night": {"direct_range": 0.88, "desc": "夜战：直射武器射程 -12%"},
}

## v27 黑门裂隙环境（每场无尽 run 随机 1 条，敌我对称；设计 §5.5）。
## 与四维环境不同源（黑门无天气/地形/时段——彼岸无昼夜），单独表 + 静态 override：
## EndlessBlackgateManager.begin_run roll 键 → BattleManager.start_battle 置
## set_rift_override / end_battle 清除，get_level_env_mults 自动叠加，
## 玩家/敌兵/相位师产兵三处乘区零新增接线。
const RIFT_ENV_EFFECTS: Dictionary = {
	"psi_storm": {"indirect_dmg": 1.15, "desc": "灵能风暴：曲射武器伤害 +15%（双向）"},
	"low_gravity": {"direct_dmg": 1.10, "desc": "低重力晶脉：直射武器伤害 +10%（双向）"},
	"rift_tide": {"regen": 1.25, "desc": "裂隙潮汐：能量回复 +25%"},
	# kill_energy_bonus 非乘区（击杀能量 +2/杀），由 BattleManager 击杀链读取结算
	"crystal_vein": {"kill_energy_bonus": 2, "desc": "晶脉浮陆：每次击杀额外 +2 能量"},
}

## 当前裂隙 override 键（""=无；仅无尽 run 战斗期间非空）
static var _rift_override: String = ""


static func set_rift_override(key: String) -> void:
	_rift_override = key if RIFT_ENV_EFFECTS.has(key) else ""


static func clear_rift_override() -> void:
	_rift_override = ""


## v6.35: 本场裂隙环境描述(desc 表内单一真身——开战播报/战报同源,C3)
static func get_rift_desc(key: String) -> String:
	return String(RIFT_ENV_EFFECTS.get(key, {}).get("desc", ""))


static func get_rift_override() -> String:
	return _rift_override


## 裂隙附加非乘区效果读取（如晶脉击杀能量）；无 override/无键返回 0
static func rift_flat_bonus(key: String) -> float:
	if _rift_override.is_empty():
		return 0.0
	return float(RIFT_ENV_EFFECTS.get(_rift_override, {}).get(key, 0.0))

const _MULT_KEYS: Array = ["indirect_dmg", "direct_dmg", "all_dmg", "direct_range", "atk_speed", "regen"]


static func enabled() -> bool:
	return bool(GameCfg.get_default().env_effects_enabled)


## 聚合某关四维环境的效果乘区（总开关关闭时恒返回中性值）
static func get_level_env_mults(level: int) -> Dictionary:
	var out: Dictionary = {
		"indirect_dmg": 1.0, "direct_dmg": 1.0, "all_dmg": 1.0,
		"direct_range": 1.0, "atk_speed": 1.0, "regen": 1.0,
		"descs": [],
	}
	if not enabled():
		return out
	var env: Dictionary = BattleEnvironmentsRef.get_for_level(level)
	_accumulate(out, WEATHER_EFFECTS.get(String(env.get("weather", "clear")), {}))
	_accumulate(out, TERRAIN_EFFECTS.get(String(env.get("terrain", "plain")), {}))
	_accumulate(out, ENERGY_FIELD_EFFECTS.get(String(env.get("energy_field", "normal")), {}))
	_accumulate(out, TIME_OF_DAY_EFFECTS.get(String(env.get("time_of_day", "day")), {}))
	# v27 黑门裂隙 override（无尽 run 期间非空；乘区键走同一 _accumulate，desc 追加）
	if not _rift_override.is_empty():
		_accumulate(out, RIFT_ENV_EFFECTS.get(_rift_override, {}))
	return out


static func _accumulate(out: Dictionary, eff: Dictionary) -> void:
	if eff.is_empty():
		return
	for k in _MULT_KEYS:
		if eff.has(k):
			out[k] = float(out.get(k, 1.0)) * float(eff[k])
	var d: String = String(eff.get("desc", ""))
	if not d.is_empty():
		(out["descs"] as Array).append(d)


## 是否存在任何非中性效果（UI 显隐用）
static func has_any_effect(mults: Dictionary) -> bool:
	for k in _MULT_KEYS:
		if absf(float(mults.get(k, 1.0)) - 1.0) > 0.001:
			return true
	return false


## 战前/战内共用的效果描述行
static func describe_level_env(level: int) -> Array:
	return get_level_env_mults(level).get("descs", []) as Array


## 按武器类型取伤害乘区（all_dmg × 直/曲分乘区）
static func damage_mult_for_weapon(mults: Dictionary, wt: int) -> float:
	var m: float = float(mults.get("all_dmg", 1.0))
	if GC.is_indirect_weapon_type(wt):
		m *= float(mults.get("indirect_dmg", 1.0))
	else:
		m *= float(mults.get("direct_dmg", 1.0))
	return m


## 按武器类型取射程乘区（曲射不受时段/沙暴影响）
static func range_mult_for_weapon(mults: Dictionary, wt: int) -> float:
	if GC.is_indirect_weapon_type(wt):
		return 1.0
	return float(mults.get("direct_range", 1.0))


## 应用到 UnitStats（玩家 _build_stats_cached 尾部 / 相位师产兵 driver 同用）。
## 三维攻击按各自武器槽的直/曲取伤害乘区（无槽回退 wt_hint）；
## 射程仅"存在直射武器且无曲射武器"的单位应用（混合直曲不乘，见类注释）；
## 攻速乘三维 attack_*_speed。
static func apply_to_unit_stats(stats, level: int, wt_hint: int = -1) -> void:
	if stats == null:
		return
	var mults: Dictionary = get_level_env_mults(level)
	if not has_any_effect(mults):
		return
	var speed_mult: float = float(mults.get("atk_speed", 1.0))

	# 武器槽直/曲表（三维对齐 weapon_slots 下标；无槽统一用 hint）
	var wts: Array = []
	var has_direct: bool = false
	var has_indirect: bool = false
	for i in range(3):
		var wt: int = wt_hint
		if i < stats.weapon_slots.size():
			var w = stats.weapon_slots[i]
			if w != null and "weapon_type" in w:
				wt = int(w.weapon_type)
		wts.append(wt)
		if GC.is_indirect_weapon_type(wt):
			has_indirect = true
		else:
			has_direct = true

	var dims: Array = ["attack_light", "attack_armor", "attack_air"]
	for i in range(3):
		var key: String = dims[i]
		var dm: float = damage_mult_for_weapon(mults, int(wts[i]))
		if absf(dm - 1.0) > 0.001:
			stats.set(key, maxf(0.1, float(stats.get(key)) * dm))
	stats.attack_damage = stats.attack_light  # 兼容别名（经典路径读单维）

	# weapon_slots[].damage 逐槽同口径（主战斗路径读这里——v25.0 教训）
	for i in range(stats.weapon_slots.size()):
		var w = stats.weapon_slots[i]
		if w == null or not ("damage" in w):
			continue
		var wt: int = int(wts[i]) if i < wts.size() else wt_hint
		var dm: float = damage_mult_for_weapon(mults, wt)
		if absf(dm - 1.0) > 0.001 and float(w.damage) > 0.0:
			w.damage = maxf(0.1, float(w.damage) * dm)

	# 射程：仅全直射单位应用 direct_range
	if has_direct and not has_indirect:
		var rm: float = float(mults.get("direct_range", 1.0))
		if absf(rm - 1.0) > 0.001:
			stats.attack_range = maxf(30.0, float(stats.attack_range) * rm)

	# 攻速（speed = 1/interval）
	if absf(speed_mult - 1.0) > 0.001:
		for key in ["attack_light_speed", "attack_armor_speed", "attack_air_speed"]:
			var cur: float = float(stats.get(key))
			if cur > 0.0:
				stats.set(key, cur * speed_mult)


## 应用到经典敌兵的 resolver 结果字典（enemy_unit._apply_archetype_stats 内、
## 赋值给成员/构建 UnitStats 之前调用；单武器类型，直/曲由 wt_hint 决定）。
static func apply_to_resolved_enemy(r: Dictionary, wt_hint: int, level: int) -> void:
	if r.is_empty():
		return
	var mults: Dictionary = get_level_env_mults(level)
	if not has_any_effect(mults):
		return
	var dm: float = damage_mult_for_weapon(mults, wt_hint)
	if absf(dm - 1.0) > 0.001:
		for key in ["attack_light", "attack_armor", "attack_air", "attack_damage"]:
			if r.has(key):
				r[key] = maxf(0.1, float(r[key]) * dm)
	var rm: float = range_mult_for_weapon(mults, wt_hint)
	if absf(rm - 1.0) > 0.001 and r.has("attack_range"):
		r["attack_range"] = maxf(30.0, float(r["attack_range"]) * rm)
	var sm: float = float(mults.get("atk_speed", 1.0))
	if absf(sm - 1.0) > 0.001:
		# interval 除以攻速乘区（攻速降 → interval 变长）
		for key in ["attack_interval", "attack_light_interval", "attack_armor_interval", "attack_air_interval"]:
			if r.has(key) and float(r[key]) > 0.0:
				r[key] = maxf(0.05, float(r[key]) / sm)
