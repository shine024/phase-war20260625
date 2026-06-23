extends RefCounted
class_name EnemyStatResolver
## 敌人基底 + 波次/关卡/相位师/可选 player_pressure 单一解析入口（经典 EnemyUnit / 蜂群与相位师产兵共用公式常数）。

const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const GC = preload("res://resources/game_constants.gd")


static func wave_hp_multiplier(wave_index: int) -> float:
	return 1.0 + 0.12 * float(max(0, wave_index - 1))


static func wave_damage_multiplier(wave_index: int) -> float:
	return 1.0 + 0.08 * float(max(0, wave_index - 1))


## v6.4: 接入关卡难度曲线（原 difficulty_modifier 公式：0.8 + level × 0.014）
## 第1关≈0.814（略低于基础值，新手友好），第20关≈1.08，第100关=2.2
## 此值乘到敌人 HP/攻击上，使关卡随进度逐步变强
static func level_stat_multiplier(level: int) -> float:
	var lv: int = clampi(int(level), 1, 100)
	return 0.8 + lv * 0.014


static func master_attack_multiplier(master_stats: Dictionary) -> float:
	var atk: float = float(master_stats.get("attack_power", 0.0))
	if atk <= 0.0:
		return 1.0
	# v6.2: 提升敌方攻击威胁(0.0005→0.002)，配合召唤上限让战斗更激烈但更短
	return 1.0 + atk * 0.002


static func master_defense_hp_multiplier(master_stats: Dictionary) -> float:
	var dfn: float = float(master_stats.get("defense", 0.0))
	if dfn <= 0.0:
		return 1.0
	# v6.2: 削弱敌方血量加成(0.0003→0.0001)，战斗单位更脆、战斗更快
	return 1.0 + dfn * 0.0001


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


## 返回 Dictionary：含三维攻防 + 单一 defense（格子战用）+ 其他属性
## v6.3: 输出三维攻防（attack_light/armor/air + defense_light/armor/air），不再只有 attack_damage/defense
## 同时修复 move_speed:0 bug（改读 cfg.speed）
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
	# 通用乘算链系数（攻击/HP 各自）
	var dmg_mul_chain: float = w_dmg * lvl * p_atk * m_atk
	var hp_mul_chain: float = w_hp * lvl * p_hp * m_hp

	if cfg.is_empty():
		var hp_lin: float = (60.0 + float(ctx.wave_index) * 15.0) * hp_mul_chain
		var atk_lin: float = (10.0 + float(ctx.wave_index) * 2.0) * dmg_mul_chain
		var fallback_cfg: Dictionary = {
			"hp": hp_lin,
			"attack_damage": atk_lin,
			"speed": -60.0,
			"tags": [],
		}
		return {
			"hp": hp_lin,
			"attack_damage": atk_lin,
			"attack_light": atk_lin, "attack_armor": 0.0, "attack_air": 0.0,
			"defense": float(EnemyArchetypes.compute_defense_from_config(fallback_cfg)),
			"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
			"combat_kind": 0,
			"attack_range": 100.0,
			"attack_interval": 1.0,
			"move_speed": 0.0,
			"weapon_type": 0,  # SMG
		}

	var base_hp: float = float(cfg.get("hp", 80.0))
	var hp_out: float = base_hp * hp_mul_chain
	# v6.3: 三维攻击——cfg 有三维则各自缩放，否则从 attack_damage 拆分
	var atk_l: float
	var atk_a: float
	var atk_air: float
	if cfg.has("attack_light") or cfg.has("attack_armor") or cfg.has("attack_air"):
		atk_l = float(cfg.get("attack_light", 0.0)) * dmg_mul_chain
		atk_a = float(cfg.get("attack_armor", 0.0)) * dmg_mul_chain
		atk_air = float(cfg.get("attack_air", 0.0)) * dmg_mul_chain
	else:
		# v6.4: 旧一维数据按 combat_kind 智能派生三维攻击（不再对装甲/对空=0）
		var base_atk: float = float(cfg.get("attack_damage", 10.0)) * dmg_mul_chain
		var ck_atk: int = int(cfg.get("combat_kind", 0))
		match ck_atk:
			GC.CombatKind.LIGHT:
				# 步兵：对轻装强，对装甲中，对空中低
				atk_l = base_atk
				atk_a = base_atk * 0.6
				atk_air = base_atk * 0.2
			GC.CombatKind.ARMOR:
				# 装甲：对装甲强，对轻装中，对空中低
				atk_l = base_atk * 0.7
				atk_a = base_atk
				atk_air = base_atk * 0.3
			GC.CombatKind.SUPPORT:
				# 支援/炮兵：对装甲强（反坦克），对轻装中，对空中低
				atk_l = base_atk * 0.5
				atk_a = base_atk * 1.2
				atk_air = base_atk * 0.2
			GC.CombatKind.AIR:
				# 空军：对空中强（空战），对装甲中，对轻装中
				atk_l = base_atk * 0.6
				atk_a = base_atk * 0.6
				atk_air = base_atk
			GC.CombatKind.FORT:
				# 堡垒：对装甲强（反坦克炮台），对轻装中，对空中低
				atk_l = base_atk * 0.5
				atk_a = base_atk * 1.3
				atk_air = base_atk * 0.2
			_:
				atk_l = base_atk
				atk_a = base_atk * 0.6
				atk_air = base_atk * 0.2
	# 兼容：保留 attack_damage 字段（取三维中的最大值或对轻装值）
	var atk_out: float = maxf(atk_l, maxf(atk_a, atk_air))
	# v6.3: 三维防御——cfg 有三维则直接取，否则从单一 defense 派生或用 derive_defense_by_unit_type
	var def_l: float
	var def_a: float
	var def_air: float
	var combat_kind: int = int(cfg.get("combat_kind", 0))
	# v6.8: tags 含 "aircraft" 的敌人（飞机/直升机/无人机）一律判为 AIR。
	# 历史 JSON/era 配置只标了 tags 没标 combat_kind，回退到 LIGHT 会导致飞机被当步兵缩放且不悬浮。
	# 注意：必须在防御派生（L161 match）和输出（L205）之前修正，保证攻防分类与显示分类一致。
	if combat_kind != GC.CombatKind.AIR:
		var tags_var: Variant = cfg.get("tags", [])
		if tags_var is Array and (tags_var as Array).has("aircraft"):
			combat_kind = GC.CombatKind.AIR
	if cfg.has("defense_light") or cfg.has("defense_armor") or cfg.has("defense_air"):
		def_l = float(cfg.get("defense_light", 0.0))
		def_a = float(cfg.get("defense_armor", 0.0))
		def_air = float(cfg.get("defense_air", 0.0))
	else:
		# v6.4: 旧一维数据按 combat_kind 派生差异化三维防御（不再三者相同）
		var single_def: float = float(cfg.get("defense", EnemyArchetypes.compute_defense_from_config(cfg)))
		match combat_kind:
			GC.CombatKind.LIGHT:
				# 步兵：防轻装高，防装甲低，防空中低
				def_l = single_def
				def_a = single_def * 0.5
				def_air = single_def * 0.3
			GC.CombatKind.ARMOR:
				# 装甲：防装甲高，防轻装中，防空中中
				def_l = single_def * 0.7
				def_a = single_def
				def_air = single_def * 0.6
			GC.CombatKind.SUPPORT:
				# 炮兵/支援：防装甲中，防轻装低，防空中低（脆皮）
				def_l = single_def * 0.5
				def_a = single_def * 0.7
				def_air = single_def * 0.3
			GC.CombatKind.AIR:
				# 空军：防空中高（机动规避），防轻装中，防装甲低
				def_l = single_def * 0.6
				def_a = single_def * 0.4
				def_air = single_def
			GC.CombatKind.FORT:
				# 堡垒：全维度高防御（结构强度）
				def_l = single_def * 1.3
				def_a = single_def * 1.3
				def_air = single_def * 1.2
			_:
				def_l = single_def
				def_a = single_def
				def_air = single_def
	# 格子战单一 defense：取三维中最大值（与 build_stats_from_card 一致）
	var def_out: float = maxf(def_l, maxf(def_a, def_air))
	# v6.3 修复：move_speed 读 cfg.speed（而非硬编码 0.0）
	var move_speed_out: float = float(cfg.get("speed", -60.0))
	return {
		"hp": hp_out,
		"attack_damage": atk_out,  # 兼容旧字段
		"attack_light": atk_l,
		"attack_armor": atk_a,
		"attack_air": atk_air,
		"defense": def_out,
		"defense_light": def_l,
		"defense_armor": def_a,
		"defense_air": def_air,
		"combat_kind": combat_kind,
		"attack_range": float(cfg.get("attack_range", 100.0)),
		"attack_interval": float(cfg.get("attack_interval", 1.0)),
		"move_speed": move_speed_out,
		"weapon_type": int(cfg.get("weapon_type", 0)),  # default SMG
		"weapon_label": String(cfg.get("weapon_label", "")),
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
