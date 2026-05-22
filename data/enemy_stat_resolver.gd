extends RefCounted
class_name EnemyStatResolver
## 敌人基底 + 波次/关卡/相位师/可选 player_pressure 单一解析入口（经典 EnemyUnit / 蜂群与相位师产兵共用公式常数）。

const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const GC = preload("res://resources/game_constants.gd")


static func wave_hp_multiplier(wave_index: int) -> float:
	return 1.0 + 0.12 * float(max(0, wave_index - 1))


static func wave_damage_multiplier(wave_index: int) -> float:
	return 1.0 + 0.08 * float(max(0, wave_index - 1))


## 与旧版一致：未接关卡曲线前保持 1.0，后续只改此处即可全链路生效
static func level_stat_multiplier(_level: int) -> float:
	return 1.0


static func master_attack_multiplier(master_stats: Dictionary) -> float:
	var atk: float = float(master_stats.get("attack_power", 0.0))
	if atk <= 0.0:
		return 1.0
	return 1.0 + atk * 0.0005


static func master_defense_hp_multiplier(master_stats: Dictionary) -> float:
	var dfn: float = float(master_stats.get("defense", 0.0))
	if dfn <= 0.0:
		return 1.0
	return 1.0 + dfn * 0.0003


static func _pressure_mul(pressure: Dictionary, key: String) -> float:
	if pressure.is_empty():
		return 1.0
	return maxf(0.01, float(pressure.get(key, 1.0)))


## 从 GameManager / PhaseInstrument 等聚合；未启用时返回空字典（等价全 1）
static func collect_player_pressure() -> Dictionary:
	## PhaseInstrumentManager / StatBoostManager：若 GDD 规定「我方养成影响敌难度」，在此写入 hp_mul / attack_mul 等
	return {}


static func make_default_context(wave_index: int) -> EnemyStatContext:
	var ctx := EnemyStatContext.new(1, wave_index)
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var gm: Node = tree.root.get_node_or_null("GameManager")
		if gm != null and "current_level" in gm:
			ctx.level = maxi(1, int(gm.current_level))
	ctx.player_pressure = collect_player_pressure()
	return ctx


## 返回 Dictionary：hp, attack_damage, defense, attack_range, attack_interval, move_speed, weapon_type
static func resolve_classic_enemy(archetype_id: String, ctx: EnemyStatContext) -> Dictionary:
	var cfg: Dictionary = EnemyArchetypes.get_config(archetype_id)
	var w_hp: float = wave_hp_multiplier(ctx.wave_index)
	var w_dmg: float = wave_damage_multiplier(ctx.wave_index)
	var lvl: float = level_stat_multiplier(ctx.level)
	var p_hp: float = _pressure_mul(ctx.player_pressure, "hp_mul")
	var p_atk: float = _pressure_mul(ctx.player_pressure, "attack_mul")
	var p_spd: float = _pressure_mul(ctx.player_pressure, "speed_mul")
	var m_hp: float = master_defense_hp_multiplier(ctx.master_stats)
	var m_atk: float = master_attack_multiplier(ctx.master_stats)

	if cfg.is_empty():
		var hp_lin: float = (60.0 + float(ctx.wave_index) * 15.0) * lvl * p_hp * m_hp
		var atk_lin: float = (10.0 + float(ctx.wave_index) * 2.0) * lvl * p_atk * m_atk
		var fallback_cfg: Dictionary = {
			"hp": hp_lin,
			"attack_damage": atk_lin,
			"speed": -60.0,
			"tags": [],
		}
		return {
			"hp": hp_lin,
			"attack_damage": atk_lin,
			"defense": float(EnemyArchetypes.compute_defense_from_config(fallback_cfg)),
			"attack_range": 100.0,
			"attack_interval": 1.0,
			"move_speed": 0.0,
			"weapon_type": int(GC.WeaponType.SMG),
		}

	var base_hp: float = float(cfg.get("hp", 80.0))
	var base_atk: float = float(cfg.get("attack_damage", 10.0))
	var hp_out: float = base_hp * w_hp * lvl * p_hp * m_hp
	var atk_out: float = base_atk * w_dmg * lvl * p_atk * m_atk
	var def_out: float = float(EnemyArchetypes.compute_defense_from_config(cfg))
	return {
		"hp": hp_out,
		"attack_damage": atk_out,
		"defense": def_out,
		"attack_range": float(cfg.get("attack_range", 100.0)),
		"attack_interval": float(cfg.get("attack_interval", 1.0)),
		"move_speed": 0.0,
		"weapon_type": int(cfg.get("weapon_type", GC.WeaponType.SMG)),
	}


static func apply_phase_master_to_unit_stats(stats: UnitStats, master_stats: Dictionary) -> void:
	if stats == null:
		return
	var atk_m: float = master_attack_multiplier(master_stats)
	if atk_m != 1.0:
		stats.attack_damage *= atk_m
		for i in range(stats.weapons.size()):
			var w: Variant = stats.weapons[i]
			if w is Dictionary:
				var wd: Dictionary = w
				if wd.has("damage"):
					wd["damage"] = float(wd["damage"]) * atk_m
					stats.weapons[i] = wd
	var hp_m: float = master_defense_hp_multiplier(master_stats)
	if hp_m != 1.0:
		stats.max_hp *= hp_m
		stats.defense *= hp_m
