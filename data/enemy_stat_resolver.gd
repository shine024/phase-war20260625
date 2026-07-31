extends RefCounted
class_name EnemyStatResolver
## 经典敌兵 / 蜂群单一解析入口。
##
## v8.2 简化公式（base 已含时代递进，公式不再加时代系数/关卡线性乘数）：
##   hp  = base_hp  × 档位系数 × 波数 [× 势力] [× 难度]
##   atk = base_atk × 档位系数 × 波数 [× 势力] [× 难度]
##   def = base_def × 档位系数
## 档位系数（EnemyLoadoutTiers）：低1.30 / 中1.75 / 高2.00（hp/atk/def 同系数）。
## 砍掉的旧乘区：level_stat_multiplier（关卡线性）、master_stats、player_pressure（恒空死乘区）。

const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const GC = preload("res://resources/game_constants.gd")
const LevelInfoClass = preload("res://data/level_information.gd")
const FactionConquestBuffs = preload("res://data/faction_conquest_buffs.gd")
const EnemyLoadoutTiers = preload("res://data/enemy_loadout_tiers.gd")


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
	# v6.2 曾提升威胁(0.0005→0.002)；v6.11 回调至 0.0005（普通敌兵也开始吃 master_stats）；
	# v6.12 增强至 0.0008：配合敌方产兵改用真实 archetype 数据，让敌方有足够威胁。
	# 新系数下 master001(atk120)→1.096x、master016(atk400)→1.32x、master030(atk1000)→1.80x。
	return 1.0 + atk * 0.0008


static func master_defense_hp_multiplier(master_stats: Dictionary) -> float:
	var dfn: float = float(master_stats.get("defense", 0.0))
	if dfn <= 0.0:
		return 1.0
	# v6.2 曾削弱血量加成(0.0003→0.0001)；v6.11 恢复 0.0003；v6.12 增强至 0.0006；
	# v7.x 平衡修订：提至 0.0008 与 m_atk 系数对称（原 0.0006 使攻端加成是防端 6.7×）。
	# 新系数下 master016(def200)→1.16x、master030(def200)→1.16x，攻防对称。
	return 1.0 + dfn * 0.0008


static func _pressure_mul(pressure: Dictionary, key: String) -> float:
	if pressure.is_empty():
		return 1.0
	return maxf(0.01, float(pressure.get(key, 1.0)))


## 从 GameManager / PhaseInstrument 等聚合；未启用时返回空字典（等价全 1）
## v7.x 平衡修订标注：此为预留未接通的难度调节点（p_hp/p_atk/p_spd 在 resolve_classic_enemy 链路中
## 恒为 1.0）。若未来要启用「我方养成反向影响敌方难度」，在此写入 hp_mul/attack_mul/speed_mul 即可。
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
	# v8.2: 档位按时代内进度选（前1/3低 / 中段中 / 后1/3高）。
	# base 属性表已含时代递进，档位负责时代内的难度台阶。
	var era_local_level: int = ((ctx.level - 1) % 20) + 1
	var era_progress: float = float(era_local_level - 1) / 19.0
	ctx.tier = EnemyLoadoutTiers.get_tier_for_level_progress(era_progress, false)
	# v6.9: 占领势力对敌人的加成（无主之地/未知势力留空 → 视为全 1.0）
	ctx.faction_buff = _collect_faction_buff(ctx.level, tree)
	# v7.x(敌方加成来源明细): 记录占领势力标签信息，供 resolve_classic_enemy 构建"加成来源"可读标签。
	_collect_faction_labels(ctx, tree)
	# v8.2: 相位师战标记保留（仅标签用），但 master_stats 不再收集（经典敌兵不再吃相位师属性加成，
	# 相位师产兵的高档位已体现强度差异）。普通波次与相位师战走同一公式。
	if tree != null and tree.root != null:
		var bm: Node = tree.root.get_node_or_null("BattleManager")
		if bm != null and "_is_phase_master_battle" in bm and bool(bm.get("_is_phase_master_battle")):
			ctx.is_phase_master_battle = true
	# v7.x(A4): 从 settings.cfg 读玩家难度，填充到 ctx（resolver 保持纯函数，不直接读全局设置）。
	var _diff_pair: Array = _read_difficulty_pair()
	ctx.difficulty_multiplier = float(_diff_pair[0])
	ctx.difficulty_name = String(_diff_pair[1])
	return ctx


# v7.x(A4): 读 settings.cfg 的玩家难度档位 → 返回乘区系数（easy 0.85 / normal 1.0 / hard 1.15）。
# 仅在 make_default_context 调用一次，写入 ctx.difficulty_multiplier，resolver 乘区链读 ctx。
# settings 缺失或键缺省时返回 1.0（normal），行为与历史版本一致。
# v7.x(敌方加成来源明细): 改为返回 [multiplier, name] 对，name 供面板标签显示。
static func _read_difficulty_pair() -> Array:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") != OK:
		return [1.0, "普通"]
	var idx: int = cfg.get_value("settings", "difficulty_idx", 1)
	const IDS := ["easy", "normal", "hard"]
	const NAMES := ["简单", "普通", "困难"]
	idx = clampi(idx, 0, IDS.size() - 1)
	return [float(GC.DIFFICULTY_MULTIPLIERS.get(IDS[idx], 1.0)), NAMES[idx]]


# v7.x(敌方加成来源明细): 记录占领势力标签信息到 ctx，供 resolve_classic_enemy 构建"加成来源"标签。
# 与 _collect_faction_buff 同款查询路径（动态占领优先，回退静态），但只填 faction_id/faction_level。
# 不影响战斗数值（faction_buff 已在前面填好），仅为面板显示服务。
static func _collect_faction_labels(ctx: EnemyStatContext, tree: SceneTree) -> void:
	if tree == null or tree.root == null:
		return
	var fsm: Node = tree.root.get_node_or_null("FactionSystemManager")
	if fsm == null:
		return
	# faction_id：优先动态占领，回退静态表（与 _collect_faction_buff 一致）
	if fsm.has_method("get_level_occupation"):
		ctx.faction_id = fsm.get_level_occupation(ctx.level)
	else:
		var level_info := LevelInfoClass.new()
		ctx.faction_id = level_info.get_level_faction(ctx.level)
	if ctx.faction_id.is_empty():
		return
	if fsm.has_method("get_faction_level"):
		ctx.faction_level = int(fsm.get_faction_level(ctx.faction_id))


## v6.9/v6.10: 按当前关卡占领势力 + 势力等级，计算敌方加成
## v6.10: 数据源从静态 level_information 切到动态 get_level_occupation（玩家攻克易主后生效）
## 无主之地（faction_id 为空）返回空字典（无加成）
static func _collect_faction_buff(level: int, tree: SceneTree) -> Dictionary:
	if tree == null or tree.root == null:
		return {}
	var fsm: Node = tree.root.get_node_or_null("FactionSystemManager")
	# v6.10: 优先用动态占领查询（玩家攻克易主后生效）；FSM 未加载或无该方法时回退静态
	var faction_id: String = ""
	if fsm != null and fsm.has_method("get_level_occupation"):
		faction_id = fsm.get_level_occupation(level)
	else:
		var level_info := LevelInfoClass.new()
		faction_id = level_info.get_level_faction(level)
	if faction_id.is_empty():
		return {}
	if fsm == null or not fsm.has_method("get_faction_level"):
		return {}
	var flevel: int = int(fsm.get_faction_level(faction_id))
	return FactionConquestBuffs.get_buff(faction_id, flevel)




## 返回 Dictionary：含三维攻防 + 单一 defense（格子战用）+ 其他属性
## v8.2 简化公式：hp/atk = base × 档位 × 波数 [× 势力] [× 难度]；def = base × 档位。
## 砍掉关卡线性(level)、master_stats、player_pressure（死乘区）。
static func resolve_classic_enemy(archetype_id: String, ctx: EnemyStatContext) -> Dictionary:
	var cfg: Dictionary = EnemyArchetypes.get_config(archetype_id)
	var w_hp: float = wave_hp_multiplier(ctx.wave_index)
	var w_dmg: float = wave_damage_multiplier(ctx.wave_index)
	# v8.2: 档位系数（低1.30/中1.75/高2.00），hp/atk/def 同系数，平衡只调一处（TIER_BONUS）。
	var tier_bonus: Dictionary = EnemyLoadoutTiers.get_bonus_for_tier(ctx.tier)
	var tier_hp: float = 1.0 + float(tier_bonus.get("hp_pct", 0.0))
	var tier_atk: float = 1.0 + float(tier_bonus.get("atk_pct", 0.0))
	var tier_def: float = 1.0 + float(tier_bonus.get("def_pct", 0.0))
	# 势力占领加成（无主之地 → _pressure_mul 返回 1.0）
	var f_hp: float = _pressure_mul(ctx.faction_buff, "hp_mul")
	var f_atk: float = _pressure_mul(ctx.faction_buff, "attack_mul")
	var f_spd: float = _pressure_mul(ctx.faction_buff, "speed_mul")
	# 难度（easy 0.85 / normal 1.0 / hard 1.15），默认 normal=1.0
	var d_mul: float = ctx.difficulty_multiplier if ctx.difficulty_multiplier > 0.0 else 1.0
	# v8.2 简化乘区链：档位 × 波数 × 势力 × 难度
	var dmg_mul_chain: float = tier_atk * w_dmg * f_atk * d_mul
	var hp_mul_chain: float = tier_hp * w_hp * f_hp * d_mul

	if cfg.is_empty():
		var hp_lin: float = (60.0 + float(ctx.wave_index) * 15.0) * hp_mul_chain
		var atk_lin: float = (10.0 + float(ctx.wave_index) * 2.0) * dmg_mul_chain
		var fallback_cfg: Dictionary = {
			"hp": hp_lin,
			"attack_damage": atk_lin,
			"speed": -60.0,
			"tags": [],
		}
		var _fb_breakdown: Dictionary = _build_classic_breakdown(ctx, tier_hp, tier_atk, tier_def, w_hp, w_dmg, f_hp, f_atk, d_mul, 60.0 + float(ctx.wave_index) * 15.0, 10.0 + float(ctx.wave_index) * 2.0, 0.0)
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
			"bonus_breakdown": _fb_breakdown,
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
	# v8.2: 防御也乘档位系数（与 hp/atk 同系数，平衡更直观）。
	var def_out: float = maxf(def_l, maxf(def_a, def_air)) * tier_def
	def_l *= tier_def
	def_a *= tier_def
	def_air *= tier_def
	# v8.1: 三维攻速——cfg 有三维 interval 则各自读取，否则用单一 attack_interval 统一
	var base_ivl: float = float(cfg.get("attack_interval", 1.0))
	var ivl_l: float = float(cfg.get("attack_light_interval", base_ivl))
	var ivl_a: float = float(cfg.get("attack_armor_interval", base_ivl))
	var ivl_air: float = float(cfg.get("attack_air_interval", base_ivl))
	# v6.3 修复：move_speed 读 cfg.speed（而非硬编码 0.0）
	# v8.2: speed 只乘势力速度（砍掉 player_pressure 死乘区 p_spd）。
	# move_speed 为负（向左），速度更快=绝对值更大，所以用 |speed|×乘子 再取负。
	var base_speed: float = float(cfg.get("speed", -60.0))
	var move_speed_out: float = -absf(base_speed) * f_spd if base_speed < 0.0 else base_speed * f_spd
	# v7.x(敌方加成来源明细): 构建加成来源明细，挂在返回字典的 bonus_breakdown 键。
	# enemy_unit / swarm_enemy_slot 取出后写入 set_meta，情报面板读取显示"为什么这么强"。
	# 纯追加记录，不参与战斗数值计算。base 取 archetype cfg 原始值（未乘任何加成）。
	var _base_hp_for_breakdown: float = base_hp
	var _base_atk_for_breakdown: float = maxf(float(cfg.get("attack_light", 0.0)), maxf(float(cfg.get("attack_armor", 0.0)), float(cfg.get("attack_air", 0.0))))
	if _base_atk_for_breakdown <= 0.0:
		_base_atk_for_breakdown = float(cfg.get("attack_damage", 10.0))
	# def_out 已乘 tier_def，除回得到 base_def（三维最大值的原始量级）
	var _base_def_for_breakdown: float = def_out / tier_def if tier_def > 0.0 else def_out
	var _breakdown: Dictionary = _build_classic_breakdown(ctx, tier_hp, tier_atk, tier_def, w_hp, w_dmg, f_hp, f_atk, d_mul, _base_hp_for_breakdown, _base_atk_for_breakdown, _base_def_for_breakdown)
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
		"attack_interval": base_ivl,
		"attack_light_interval": ivl_l,
		"attack_armor_interval": ivl_a,
		"attack_air_interval": ivl_air,
		"move_speed": move_speed_out,
		"weapon_type": int(cfg.get("weapon_type", 0)),  # default SMG
		"weapon_label": String(cfg.get("weapon_label", "")),
		"bonus_breakdown": _breakdown,
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
	# v7.x: master.stats.max_hp 对单位 HP 的加成（之前完全空转——max_hp 是相位师 stats 最具
	# 区分度的字段，HP 9× 量级，但不接入加成链导致单卡战力评估严重偏低）。
	# 系数 0.00015 与 master_defense_hp_multiplier（defense×0.0008）量级协调：
	# max_hp 3000→×1.45, 5000→×1.75。仅相位师战（master_stats 非空）生效，普通波次零影响。
	if master_stats.has("max_hp"):
		var mhp_m: float = 1.0 + float(master_stats["max_hp"]) * 0.00015
		stats.max_hp *= mhp_m


## v7.x(敌方加成来源明细): 势力ID → 中文名映射，供加成来源标签显示。
const _FACTION_DISPLAY_NAMES: Dictionary = {
	"iron_wall_corp": "钢壁防务",
	"nova_arms": "新星兵工",
	"aether_dynamics": "以太动力",
	"quantum_logistics": "量子后勤",
	"helix_recon": "螺旋侦察",
	"void_research": "虚空相位",
	"frontier_union": "边境联合",
}


## v7.x(敌方加成来源明细): 构建经典敌人/蜂群的加成来源明细字典。
## v8.2: 简化乘区——档位 × 波数 × 势力 × 难度（砍掉关卡线性/master/pressure）。
## 收集 resolve_classic_enemy 乘区链中各来源的倍率与可读标签，供情报面板显示"为什么这么强"。
## 纯记录，不影响战斗数值。ng_plus 初始 1.0（enemy_unit._apply_ng_plus_scaling 会更新）。
## total_*_mul = 所有 source 之积（不含 ng_plus，因二周目在 resolver 外应用）。
static func _build_classic_breakdown(ctx: EnemyStatContext, tier_hp: float, tier_atk: float, tier_def: float, w_hp: float, w_dmg: float, f_hp: float, f_atk: float, d_mul: float, base_hp: float, base_atk: float, base_def: float) -> Dictionary:
	var sources: Array = []
	# 档位：hp/atk/def 同系数（低1.30/中1.75/高2.00）
	var _tier_name: String = String(EnemyLoadoutTiers.TIER_BONUS.get(ctx.tier, {}).get("name", "档位%d" % ctx.tier))
	sources.append({"label": "档位(%s)×%.2f" % [_tier_name, tier_hp], "hp_mul": tier_hp, "atk_mul": tier_atk, "def_mul": tier_def})
	# 波次：HP 与攻击倍率不同（0.12 vs 0.08），分开记录
	sources.append({"label": "波次×%.2f/×%.2f" % [w_hp, w_dmg], "hp_mul": w_hp, "atk_mul": w_dmg})
	# 势力占领：有占领势力才记录（无主之地 f_hp/f_atk=1.0，跳过避免显示无意义×1.0）
	if not ctx.faction_id.is_empty():
		var fname: String = String(_FACTION_DISPLAY_NAMES.get(ctx.faction_id, ctx.faction_id))
		var flabel: String = "势力(%s Lv%d)" % [fname, ctx.faction_level]
		if f_hp != f_atk:
			flabel += "×%.2f/×%.2f" % [f_hp, f_atk]
		else:
			flabel += "×%.2f" % f_hp
		sources.append({"label": flabel, "hp_mul": f_hp, "atk_mul": f_atk})
	# 难度：HP/攻击同倍率
	sources.append({"label": "难度(%s)×%.2f" % [ctx.difficulty_name, d_mul], "hp_mul": d_mul, "atk_mul": d_mul})
	# 总倍率：各 source 之积（不含二周目，二周目由 enemy_unit._apply_ng_plus_scaling 单独叠加并更新）
	var total_hp: float = 1.0
	var total_atk: float = 1.0
	for s in sources:
		total_hp *= float(s.get("hp_mul", 1.0))
		total_atk *= float(s.get("atk_mul", 1.0))
	return {
		"base_hp": base_hp,
		"base_atk": base_atk,
		"base_def": base_def,
		"sources": sources,
		"ng_plus": 1.0,           # 经典敌人/蜂群由 _apply_ng_plus_scaling 更新
		"total_hp_mul": total_hp,
		"total_atk_mul": total_atk,
		"kind": "classic",
	}


## v6.13→v8.2: 给单位叠加战场乘区（波数 × 势力）。
##
## v8.2 简化：砍掉关卡线性(level)/player_pressure（死乘区）。公式 = 波数 × 势力。
## 产兵侧（enemy_phase_field_driver）v8.2 起不再调用本函数（产兵不吃经典敌兵难度链），
## 此函数保留供蜂群/其他调用方兼容。
##
## 乘算范围：三维攻击 + HP + 防御 + 武器伤害；移速单独走 f_spd。
static func apply_field_multipliers_to_unit_stats(stats: UnitStats, ctx: EnemyStatContext) -> void:
	if stats == null or ctx == null:
		return
	var w_hp: float = wave_hp_multiplier(ctx.wave_index)
	var w_dmg: float = wave_damage_multiplier(ctx.wave_index)
	var f_hp: float = _pressure_mul(ctx.faction_buff, "hp_mul")
	var f_atk: float = _pressure_mul(ctx.faction_buff, "attack_mul")
	var f_spd: float = _pressure_mul(ctx.faction_buff, "speed_mul")
	var dmg_mul: float = w_dmg * f_atk
	var hp_mul: float = w_hp * f_hp
	stats.attack_light *= dmg_mul
	stats.attack_armor *= dmg_mul
	stats.attack_air *= dmg_mul
	stats.max_hp *= hp_mul
	stats.defense *= hp_mul
	stats.defense_light *= hp_mul
	stats.defense_armor *= hp_mul
	stats.defense_air *= hp_mul
	# 多武器伤害同步缩放
	for i in range(stats.weapons.size()):
		var w: Variant = stats.weapons[i]
		if w is Dictionary:
			var wd: Dictionary = w
			if wd.has("damage"):
				wd["damage"] = float(wd["damage"]) * dmg_mul
				stats.weapons[i] = wd
	# 移速：archetype 用绝对值（朝左），乘区不改变方向
	if f_spd != 1.0 and stats.move_speed > 0.001:
		stats.move_speed *= f_spd
