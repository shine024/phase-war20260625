extends Node2D
class_name SwarmEnemySlot
## 轻量蜂群敌人：无 CharacterBody2D、无血条、不可点选；逻辑由 SwarmEnemyController 驱动。
const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const EnemyStatResolver = preload("res://data/enemy_stat_resolver.gd")
const GC = preload("res://resources/game_constants.gd")
const CardGridDamage = preload("res://scripts/card_grid_damage.gd")
const ConstructUnitDeploy = preload("res://scripts/battle/construct_unit_deploy.gd")

var is_player: bool = false
var archetype_id: String = "ww1_inf_mp18"
var hp: float = 40.0
var max_hp: float = 40.0
var attack_damage: float = 8.0
var attack_range: float = 80.0
var attack_interval: float = 0.25
var move_speed: float = 80.0
var defense: float = 3.0
var weapon_type: int = 0
var weapon_types: Array = []
var wave_index: int = 0
var stats: UnitStats = null
## v6.3: 蜂群槽位的单位类型（stats 为 null 时用于条件穿甲判定）
var combat_kind: int = 0
var damage_reduction: float = 0.0
var last_damage_source: Node = null
var target: Node2D = null
var attack_timer: float = 0.0
var _target_find_timer: float = 0.0
var _attack_weapon_index: int = 0
var _incoming_damage_mul: float = 1.0
var _base_stats_ready: bool = false
var _base_max_hp: float = 40.0
var _base_attack_damage: float = 8.0
var _base_move_speed: float = 80.0
var _base_attack_interval: float = 0.25
## 蜂群槽位仍用 MultiMesh 色块绘制以保持批量性能；卡图立绘见 EnemyUnit / ConstructUnit 路径。
var visual_color: Color = Color(0.9, 0.35, 0.25)
## 空间网格更新节拍（由 SwarmEnemyController 递减，避免每帧 set_meta/get_meta）
var grid_update_timer: float = 0.0
# v7.x: 敌方布置时间（部署虚影）——蜂群版本。
# 蜂群 slot 是轻量 Node2D（process_mode=DISABLED），移动/攻击逻辑由 SwarmEnemyController 驱动，
# 故部署虚影只存状态字段；controller 在 _tick_slot 开头 early-return（部署期不索敌/不开火）。
# 视觉用 visual_color.a=0.42 表示布置态（与 EnemyUnit/ConstructUnit 的半透明一致）。
# is_deploy_ghost 被 battle_manager._is_active_combat_unit 鸭子识别，部署期不计存活数。
var is_deploy_ghost: bool = false
var _ghost_materialize_time_left: float = 0.0
var _base_visual_color: Color = Color(0.9, 0.35, 0.25)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_unregister_from_spatial_grid()

func setup(p_wave: int, p_archetype_id: String, local_pos: Vector2) -> void:
	wave_index = p_wave
	archetype_id = p_archetype_id
	position = local_pos
	target = null
	attack_timer = 0.0
	_target_find_timer = 0.0
	_attack_weapon_index = 0
	last_damage_source = null
	# v9 perf：stats 置空时同步清缓存（module_effect_handler._get_unit_stats 的 meta 快路径）
	stats = null
	if has_meta("_meh_stats_cache"):
		remove_meta("_meh_stats_cache")
	damage_reduction = 0.0
	grid_update_timer = randf_range(0.0, 0.08)
	_apply_archetype_stats()
	max_hp = hp
	add_to_group("enemy_units")
	_register_to_spatial_grid()
	_update_visual_color()
	# v7.x: 入场即进入布置态（与我方对称，复用 calculate_deploy_delay 公式）
	_start_swarm_deploy_ghost()

## v7.x: 启动蜂群部署虚影——缓存原色，按 stats.deploy_speed 算布置时间，压低 alpha 表示布置态。
## 实际计时推进与状态清除由 SwarmEnemyController._tick_swarm_deploy_ghost 完成（slot 自身无 _process）。
func _start_swarm_deploy_ghost() -> void:
	_base_visual_color = visual_color
	is_deploy_ghost = true
	var actual_delay: float = ConstructUnitDeploy.calculate_deploy_delay(stats)
	_ghost_materialize_time_left = maxf(0.05, actual_delay)
	var ghost_col: Color = visual_color
	ghost_col.a = 0.42
	visual_color = ghost_col

## v7.x: 实体化——恢复完全不透明色，投入战斗（由 controller 在计时归零时调用）
func materialize_swarm_deploy_ghost() -> void:
	is_deploy_ghost = false
	_ghost_materialize_time_left = 0.0
	visual_color = _base_visual_color

func _apply_archetype_stats() -> void:
	var cfg: Dictionary = EnemyArchetypes.get_config(archetype_id)
	if cfg.is_empty():
		return
	var ctx = EnemyStatResolver.make_default_context(wave_index)
	var r: Dictionary = EnemyStatResolver.resolve_classic_enemy(archetype_id, ctx)
	hp = float(r.get("hp", 40.0))
	attack_damage = float(r.get("attack_damage", 8.0))
	attack_range = float(r.get("attack_range", 80.0))
	attack_interval = float(r.get("attack_interval", 0.25))
	move_speed = 0.0
	defense = float(r.get("defense", 3.0))
	weapon_type = int(r.get("weapon_type", int(cfg.get("weapon_type", 0))))
	# v6.3: 读取单位类型（用于条件穿甲判定）
	combat_kind = int(r.get("combat_kind", int(cfg.get("combat_kind", 0))))
	# v6.4: 构建轻量 UnitStats 让蜂群接入三维防御系统
	# take_damage 会优先用 stats.defense_light/armor/air（按攻击者类型）
	if stats == null:
		stats = UnitStats.new()
		# v9 perf：stats 引用缓存（module_effect_handler._get_unit_stats 的 meta 快路径）
		set_meta("_meh_stats_cache", stats)
	stats.combat_kind = combat_kind
	stats.max_hp = hp
	stats.attack_range = attack_range
	stats.attack_interval = attack_interval
	stats.move_speed = move_speed
	stats.attack_light = float(r.get("attack_light", attack_damage))
	stats.attack_armor = float(r.get("attack_armor", 0.0))
	stats.attack_air = float(r.get("attack_air", 0.0))
	stats.attack_damage = stats.attack_light
	stats.defense_light = float(r.get("defense_light", defense))
	stats.defense_armor = float(r.get("defense_armor", defense))
	stats.defense_air = float(r.get("defense_air", defense))
	stats.weapon_type = weapon_type
	weapon_types = []
	var wt_arr: Array = cfg.get("weapon_types", [])
	for x in wt_arr:
		weapon_types.append(int(x))
	_base_max_hp = hp
	_base_attack_damage = attack_damage
	_base_move_speed = move_speed
	_base_attack_interval = attack_interval
	_base_stats_ready = true
	# v7.x(敌方加成来源明细): 蜂群同经典敌人，挂加成明细到 meta 供情报面板显示。
	# 蜂群无二周目加成（_apply_ng_plus_scaling 不在蜂群路径），ng_plus 保持 1.0。
	var _sw_breakdown: Dictionary = r.get("bonus_breakdown", {})
	if not _sw_breakdown.is_empty():
		_sw_breakdown["final_hp"] = float(hp)
		_sw_breakdown["final_atk"] = float(attack_damage)
		_sw_breakdown["final_def"] = float(defense)
		set_meta("enemy_bonus_breakdown", _sw_breakdown)

# v9.x（P2-7范围B）：_apply_phase_law_passives 已随法则系统退役删除
# （我方蓝槽法则对敌减益不再存在）

func _update_visual_color() -> void:
	var era: int = int(EnemyArchetypes.get_config(archetype_id).get("era", 0))
	var era_colors := {
		0: Color(0.85, 0.45, 0.35),
		1: Color(0.55, 0.65, 0.4),
		2: Color(0.55, 0.62, 0.72),
		3: Color(0.58, 0.58, 0.62),
		4: Color(0.35, 0.72, 0.88),
	}
	visual_color = era_colors.get(era, Color(0.9, 0.35, 0.25))

# v10: 受击闪白计时(MultiMesh 不能 tween,由 controller _sync 时 lerp visual_color 向白)
var _hit_flash_t: float = 0.0
const _HIT_FLASH_DUR: float = 0.08

func take_damage(amount: float, attacker: Variant = null) -> void:
	var hp_loss: float = amount
	if GameManager and GameManager.has_method("is_card_grid_battle") and GameManager.is_card_grid_battle():
		var pen: float = 0.0
		var attacker_kind: int = -1
		if attacker != null and is_instance_valid(attacker) and "stats" in attacker:
			var atk_stats: Variant = attacker.get("stats")
			if atk_stats is UnitStats:
				# v6.2: 条件型穿甲（相克 MOD）按目标(自身)类型激活
				var self_kind: int = combat_kind
				if (atk_stats as UnitStats).has_method("get_effective_armor_penetration"):
					pen = (atk_stats as UnitStats).get_effective_armor_penetration(self_kind)
				else:
					pen = float((atk_stats as UnitStats).armor_penetration)
				attacker_kind = int((atk_stats as UnitStats).combat_kind)
		# v6.4: 优先用三维防御（按攻击者类型选），回退到旧 defense 单字段
		var eff_defense: float = defense
		if stats != null and attacker_kind >= 0:
			match attacker_kind:
				GC.CombatKind.LIGHT, GC.CombatKind.SUPPORT:
					eff_defense = stats.defense_light
				GC.CombatKind.ARMOR, GC.CombatKind.FORT:
					eff_defense = stats.defense_armor
				GC.CombatKind.AIR:
					eff_defense = stats.defense_air
		var eff_def: float = CardGridDamage.effective_defense(eff_defense, pen)
		# v7.5: 接入 dodge 和 damage_reduction（此前 swarm 全程无闪避/无减伤结算）
		# v10(H3): ECM 闪避削弱（带激活中的 _ecm_dodge_penalty 时扣减，此前四处写零读）
		var swarm_dodge: float = maxf(0.0, (float(stats.dodge_chance) if stats != null else 0.0) - ModuleEffectHandler.get_ecm_dodge_penalty(self))
		var swarm_red: float = float(stats.damage_reduction) if stats != null else 0.0
		swarm_red = minf(0.60, swarm_red + float(damage_reduction))
		var _swarm_hit: Dictionary = CardGridDamage.resolve_hit(amount, eff_def, swarm_dodge, swarm_red)
		# v8.x: 闪避反馈——dodged 字段从不被读取（原链式 .get 丢弃了），现飘 MISS 并提前 return。
		if bool(_swarm_hit.get("dodged", false)):
			CombatFeedback.show_miss(global_position, self)
			return
		hp_loss = float(_swarm_hit.get("hp_loss", amount))
		# v7.x: 新机制 meta 读取（破甲叠加/标记易伤/巷战免伤）——与 construct_unit 口径一致
		# v10(C9): 破甲带 8s 到期，过期惰性清理（原永久生效）
		if has_meta("_armor_break_stacks"):
			var _ab_expired: bool = false
			if has_meta("_armor_break_until") \
					and Time.get_ticks_msec() / 1000.0 >= float(get_meta("_armor_break_until", 0.0)):
				remove_meta("_armor_break_stacks")
				remove_meta("_armor_break_ratio")
				remove_meta("_armor_break_until")
				_ab_expired = true
			if not _ab_expired:
				var _ab_stacks: int = int(get_meta("_armor_break_stacks", 0))
				var _ab_ratio: float = float(get_meta("_armor_break_ratio", 0.0))
				if _ab_stacks > 0 and _ab_ratio > 0.0:
					eff_defense = eff_defense * maxf(0.1, 1.0 - _ab_stacks * _ab_ratio)
		if has_meta("_marked_until"):
			var _mark_expire: float = float(get_meta("_marked_until", 0.0))
			var _now: float = Time.get_ticks_msec() / 1000.0
			if _now < _mark_expire:
				var _vuln: float = float(get_meta("_mark_vuln_bonus", 0.0))
				if _vuln > 0.0:
					hp_loss = hp_loss * (1.0 + _vuln)
			else:
				remove_meta("_marked_until")
				remove_meta("_mark_vuln_bonus")
		# v8.x: 暴击标注惰性清理（加成按时间戳在 bullet.gd 判定，过期 meta 顺带清掉）
		if has_meta("_crit_marked_until"):
			var _cm_expire: float = float(get_meta("_crit_marked_until", 0.0))
			if Time.get_ticks_msec() / 1000.0 >= _cm_expire:
				remove_meta("_crit_marked_until")
				remove_meta("_crit_mark_bonus")
		# v7.x: 巷战免伤（敌方也可装备 infantry_mods 改造，若 stats 有 urban_defense_bonus 则生效）
		if stats != null and stats.urban_defense_bonus > 0.0 and attacker_kind >= 0:
			if attacker_kind == GC.CombatKind.ARMOR or attacker_kind == GC.CombatKind.AIR:
				hp_loss = hp_loss * (1.0 - stats.urban_defense_bonus)
	# v7.x 第二批：拦截判定（概率伤害归零）
	if stats != null and ModuleEffectHandler.try_intercept(self):
		return  # 拦截成功
	if attacker != null and is_instance_valid(attacker) and attacker is Node and attacker.is_in_group("player_units"):
		last_damage_source = attacker
	# v6.6 修复：_incoming_damage_mul 同样需作用于伤害数字显示，保持飘字与血条扣血一致
	var final_loss: float = hp_loss * _incoming_damage_mul
	hp -= final_loss
	if hp > 0.0 and final_loss > 0.0:
		_hit_flash_t = _HIT_FLASH_DUR  # v10: 受击闪白(controller 同步时 lerp 向白)
	if SignalBus:
		SignalBus.unit_damaged.emit(self, false, final_loss, global_position)
	if hp <= 0.0:
		_die()

func _die() -> void:
	_unregister_from_spatial_grid()
	if SignalBus:
		SignalBus.unit_died.emit(self, false)
	var parent_ctl: Node = get_parent()
	if parent_ctl and parent_ctl.has_method("on_slot_died"):
		parent_ctl.on_slot_died(self)
	queue_free()

func _register_to_spatial_grid() -> void:
	if not BattleManager or not BattleManager.spatial_grid:
		return
	BattleManager.spatial_grid.insert(self)

func _unregister_from_spatial_grid() -> void:
	if not BattleManager or not BattleManager.spatial_grid:
		return
	BattleManager.spatial_grid.remove(self)

func update_spatial_grid() -> void:
	if not BattleManager or not BattleManager.spatial_grid:
		return
	BattleManager.spatial_grid.update(self)
