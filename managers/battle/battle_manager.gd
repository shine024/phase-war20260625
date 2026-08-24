extends Node
## 战斗管理主入口：战役流程控制、胜负判定、信号连接
## 委托 BattleSpawnSystem（刷新）和 BattleDamageSystem（掉落/伤害后处理）
##
## 设计文档: docs/architecture/project-architecture.md (Section 4)
## 重构: 原单文件 969 行拆分为三个文件，职责清晰分离。

const GC = preload("res://resources/game_constants.gd")
const SpatialGridClass = preload("res://scripts/spatial_grid.gd")
const SimpleEnemyProjectileBatchScript = preload("res://managers/battle/simple_enemy_projectile_batch.gd")
const SimplePlayerProjectileBatchScript = preload("res://managers/battle/simple_player_projectile_batch.gd")
const SimpleIndirectProjectileBatchScript = preload("res://managers/battle/simple_indirect_projectile_batch.gd")
const CombatFeedback = preload("res://scripts/combat_feedback.gd")
const ModuleEffectHandler = preload("res://scripts/battle/module_effect_handler.gd")
# v6.7: 相位师排名差异化加成 —— 玩家装配器 + 战力评估器
const MasterPlayerAssembler = preload("res://scripts/master_player_assembler.gd")
const MasterPowerEvaluator = preload("res://scripts/master_power_evaluator.gd")
const LevelInformation = preload("res://data/level_information.gd")
# v7.x: 敌方相位仪能力合并入 PhaseInstrumentAbilities 单引擎（owner-aware），旧 EnemyPhaseInstrumentAbilities 已删
const DEBUG_BATTLE_LOG := false

# v6.0 依赖注入重构: 移除 @onready 单例引用，改用 setup() 方法注入
var energy_manager: Node = null
var phase_instrument: Node = null

# ---- 子系统 ----
var _spawn_system: RefCounted = null  ## BattleSpawnSystem
var _damage_system: RefCounted = null  ## BattleDamageSystem
# v8.x: 战法检测器 + 卡片定时技能引擎
var _tactic_detector: RefCounted = null  ## TacticDetector
var _card_skill_engine: RefCounted = null  ## CardPeriodicSkillEngine
# v8.5: 敌方相位师主动技能引擎（boss active_spells 定时触发）
var _enemy_master_skill_engine: RefCounted = null  ## EnemyMasterSkillEngine
# v9.1: 我方组合技套路引擎 + 战场状态管理器
var _combo_engine: RefCounted = null  ## ComboEngine
var _combo_field_state: RefCounted = null  ## ComboFieldState

# ---- 性能优化：空间分区系统 ----
var spatial_grid: Node = null  ## SpatialGrid 实例
## 玩家轻武器弹道批处理（SimplePlayerProjectileBatch）
var player_projectile_batch: Node = null
## 敌方轻武器弹道批处理（SimpleEnemyProjectileBatch）
var enemy_projectile_batch: Node = null
## v9.x（3c 性能批次）：PerformanceMetricsManager 采样能力首帧判定缓存（免每帧 has_method）
var _pmm_checked: bool = false
var _pmm_can_sample: bool = false
## 玩家曲射/空射弹道批处理（SimpleIndirectProjectileBatch）
var player_indirect_batch: Node = null
## 敌方曲射/空射弹道批处理（SimpleIndirectProjectileBatch）
var enemy_indirect_batch: Node = null

# ---- 战斗状态 ----
var battle_active: bool = false
var battlefield: Node = null
## 批次9（2026-08-23）：战斗世代号——每场 start_battle 递增；end_battle 的 3 帧延迟
## 结算链与战斗内 call_deferred 携带世代号，快速重试时旧链撞上新战即整体作废
## （修复：秒败后立即重试 → 旧链 clobber 新战/迟发驱动销毁信号吞掉新战波次启动，
## 战斗无波次永不结算，L43 起稳定复现；玩家经世界地图"自动部署"快速重开亦可触发）。
var _battle_gen: int = 0
var player_units_node: Node = null
var enemy_units_node: Node = null
var _battle_elapsed_time: float = 0.0

## 索敌 fallback：节流缓存 get_nodes_in_group，避免每单位每帧全树遍历
const _GROUP_TARGET_CACHE_INTERVAL_SEC := 0.28
var _group_target_cache_accum: float = 0.0
var _cached_nodes_by_group: Dictionary = {}

# ---- 相位师战斗配置 ----
var _phase_master_config: Dictionary = {}
var _is_phase_master_battle: bool = false
var _enemy_phase_driver: Node2D = null
# v7.x 性能：侦查加成标志——在 end_battle 清场前计算（单位还活着），传给 Frame B' 情报收获。
# 原先 B' 才算，但那时单位已被 clear_all_units 清空 → 恒返回 false（侦查加成从未生效）。
var _pending_has_recon: bool = false

# ---- 战斗结果数据 ----
var _battle_result: Dictionary = {
	"victory_stars": 0,
	"era": 0,
	"player_won": false
}

# ---- v6.0: 击败敌人记录（供情报系统使用） ----
var _defeated_enemies: Array = []  ## [{"archetype_id": str, "rank": str, "enemy_type": str}]

# ---- 卡牌格子战术 ----
var _card_grid_placement_active: bool = false
var _card_grid_combat_started: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	process_mode = Node.PROCESS_MODE_PAUSABLE

	# v6.0 依赖注入: 初始化核心管理器引用
	# EnergyManager 和 PhaseInstrumentManager 是核心管理器，直接 autoload
	energy_manager = get_node_or_null("/root/EnergyManager")
	phase_instrument = get_node_or_null("/root/PhaseInstrumentManager")

	# 初始化子系统
	const SpawnSystemScript = preload("res://managers/battle/battle_spawn_system.gd")
	const DamageSystemScript = preload("res://managers/battle/battle_damage_system.gd")
	_spawn_system = SpawnSystemScript.new()
	_damage_system = DamageSystemScript.new()

	# v8.x: 初始化战法检测器 + 卡片定时技能引擎
	const TacticDetectorScript = preload("res://scripts/battle/tactic_detector.gd")
	const CardSkillEngineScript = preload("res://managers/battle/card_periodic_skill_engine.gd")
	const EnemyMasterSkillEngineScript = preload("res://managers/battle/enemy_master_skill_engine.gd")
	_tactic_detector = TacticDetectorScript.new()
	_card_skill_engine = CardSkillEngineScript.new()
	_enemy_master_skill_engine = EnemyMasterSkillEngineScript.new()
	# v9.1: 组合技套路引擎 + 战场状态管理器
	const ComboEngineScript = preload("res://scripts/battle/combo_engine.gd")
	const ComboFieldStateScript = preload("res://scripts/battle/combo_field_state.gd")
	_combo_field_state = ComboFieldStateScript.new()
	_combo_engine = ComboEngineScript.new()
	var skill_mgr: Node = get_node_or_null("/root/PhaseMasterSkillManager")
	_tactic_detector.setup({
		"player_units_node": null,  # 战斗开始后更新
		"skill_manager": skill_mgr,
		"card_skill_engine": _card_skill_engine,
	})
	_card_skill_engine.setup({
		"player_units_node": null,  # 战斗开始后更新
		"enemy_units_node": null,
		"skill_manager": skill_mgr,
		"battlefield": null,
	})

	_spawn_system.setup({
		"energy_manager": energy_manager,
		"phase_instrument": phase_instrument,
		"signal_bus": SignalBus,
	})
	_damage_system.setup({
		"signal_bus": SignalBus,
		"player_units_node": null,  # 战斗开始后更新
	})

	# 连接信号（is_connected 守卫防止重复注册）
	if SignalBus:
		if not SignalBus.unit_died.is_connected(_on_unit_died):
			SignalBus.unit_died.connect(_on_unit_died)
		# v6.15: 击杀修复（战场回收）——per-hit 吸血退役，改由击杀信号触发
		if not SignalBus.unit_killed.is_connected(_on_unit_killed_kill_repair):
			SignalBus.unit_killed.connect(_on_unit_killed_kill_repair)
		# v9.x: 订阅 unit_spawned 用于单位数变化广播（spawn 后计数器已递增）
		if not SignalBus.unit_spawned.is_connected(_on_unit_spawned):
			SignalBus.unit_spawned.connect(_on_unit_spawned)
		# 批次9（2026-08-23）：phase_driver_destroyed 两信号改"按场连接"（start_battle 连 /
		# end_battle 断）——常驻连接下，上一场驱动 queue_free 的迟发信号会打进新战斗
		# 触发幽灵 end_battle（秒败快速重试时曾致新战无波次永不结算，L43 稳定复现）。
		if not SignalBus.unit_damaged.is_connected(_on_unit_damaged_combat_feedback):
			SignalBus.unit_damaged.connect(_on_unit_damaged_combat_feedback)
		# v10 解题式玩法：克制质变计数（战后统计"本关克制链生效 N 次"）
		if SignalBus.has_signal("counter_break_triggered"):
			if not SignalBus.counter_break_triggered.is_connected(_on_counter_break_count):
				SignalBus.counter_break_triggered.connect(_on_counter_break_count)

## v10：克制质变触发计数（战斗开始时清零，战斗结束写入 _battle_result）
var counter_break_count: int = 0

func _on_counter_break_count(_break_type: String, _target_name: String) -> void:
	counter_break_count += 1

func get_counter_break_count() -> int:
	return counter_break_count

## v6.15: 击杀修复（战场回收）——击杀者按 stats.kill_repair 回复自身最大 HP
func _on_unit_killed_kill_repair(victim: Node, killer: Node, is_player_victim: bool) -> void:
	ModuleEffectHandler.on_unit_killed(victim, killer, is_player_victim)

## P0 性能优化：退出时断开 SignalBus 连接，防止场景切换后连接累积
func _exit_tree() -> void:
	if SignalBus:
		if SignalBus.unit_died.is_connected(_on_unit_died):
			SignalBus.unit_died.disconnect(_on_unit_died)
		if SignalBus.unit_killed.is_connected(_on_unit_killed_kill_repair):
			SignalBus.unit_killed.disconnect(_on_unit_killed_kill_repair)
		if SignalBus.unit_spawned.is_connected(_on_unit_spawned):
			SignalBus.unit_spawned.disconnect(_on_unit_spawned)
		if SignalBus.phase_driver_destroyed.is_connected(_on_phase_driver_destroyed):
			SignalBus.phase_driver_destroyed.disconnect(_on_phase_driver_destroyed)
		if SignalBus.has_signal("enemy_phase_driver_destroyed") and SignalBus.enemy_phase_driver_destroyed.is_connected(_on_enemy_phase_driver_destroyed):
			SignalBus.enemy_phase_driver_destroyed.disconnect(_on_enemy_phase_driver_destroyed)
		if SignalBus.unit_damaged.is_connected(_on_unit_damaged_combat_feedback):
			SignalBus.unit_damaged.disconnect(_on_unit_damaged_combat_feedback)
		if SignalBus.has_signal("counter_break_triggered") and SignalBus.counter_break_triggered.is_connected(_on_counter_break_count):
			SignalBus.counter_break_triggered.disconnect(_on_counter_break_count)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not battle_active or battlefield == null:
		return
	var tree = get_tree()
	var paused = tree.paused if tree else true
	if paused:
		return

	_maybe_refresh_group_target_cache(delta)
	# v7.x: 驱动相位仪主动能力（owner-aware 单引擎，内部同时驱动玩家+敌方）
	# 必须在 _is_phase_master_battle 短路之前调用，否则相位师战不会驱动敌方能力
	PhaseInstrumentAbilities.update(delta)
	# v8.x: 驱动卡片定时技能引擎 + 战法检测器（同样在短路前调用，确保两套战斗都生效）
	if _card_skill_engine != null:
		_card_skill_engine.update(delta)
	# v8.5: 敌方相位师主动技能（boss active_spells 定时触发）
	if _enemy_master_skill_engine != null:
		_enemy_master_skill_engine.update(delta)
	if _tactic_detector != null:
		_tactic_detector.update(delta)
	# v9.1: 组合技套路引擎（战场浓度衰减 + 全队机制刷新）
	if _combo_engine != null:
		_combo_engine.update(delta)

	# 相位师战斗：不执行波次逻辑
	if _is_phase_master_battle:
		return

	_battle_elapsed_time += delta
	_spawn_system.update_wave_timer(delta)

	# 等 begin_card_grid_combat 后再按波次间隔整波刷敌
	if not _card_grid_combat_started:
		return

	if _spawn_system.should_spawn_wave():
		var do_consume: bool = true
		if _spawn_system.can_spawn_more_waves():
			var level: int = 1
			if "current_level" in GameManager:
				level = int(GameManager.current_level)
			do_consume = _spawn_system.spawn_card_grid_enemy_wave(level)
		if do_consume:
			_spawn_system.consume_wave_timer()

	_check_win_lose()
	# v9.x（3c 性能批次）：每帧 has_method 反射 → 首帧判定一次缓存
	if not _pmm_checked:
		_pmm_checked = true
		_pmm_can_sample = PerformanceMetricsManager != null and PerformanceMetricsManager.has_method("sample_battle_frame")
	if _pmm_can_sample:
		PerformanceMetricsManager.sample_battle_frame(delta)


# =========================================================================
#  战斗流程
# =========================================================================

## v6.7: 计算并缓存玩家与敌方 boss 的相位师星级（1-7★）
## 玩家星级：用 MasterPlayerAssembler 从 PhaseInstrumentManager 装配 master dict
## 敌方星级：仅 boss 对战时算，直接用 _phase_master_config 喂评估器
## 任一计算失败均回落到 3★（基准=现状数值，向后兼容）
## v7.x: 算完后 emit player_phase_master_power_changed 信号（携带 total/Lv），供 UI 更新
func _compute_and_cache_rank_stars() -> void:
	var player_stars: int = 3
	var enemy_stars: int = 3
	var player_eval: Dictionary = {}
	# 玩家星级
	if PhaseInstrumentManager != null:
		player_eval = MasterPlayerAssembler.evaluate_player_stars(PhaseInstrumentManager)
		player_stars = int(player_eval.get("stars", 3))
	# 敌方 boss 星级（仅 boss 对战）
	if _is_phase_master_battle and not _phase_master_config.is_empty():
		var er: Dictionary = MasterPowerEvaluator.evaluate(_phase_master_config)
		enemy_stars = int(er.get("stars", 3))
	if PhaseInstrumentManager and PhaseInstrumentManager.has_method("set_player_rank_stars"):
		PhaseInstrumentManager.set_player_rank_stars(player_stars)
		PhaseInstrumentManager.set_enemy_rank_stars(enemy_stars)
	# v7.x: 缓存完整玩家评估结果（供 UI 读取，避免重复计算）
	if PhaseInstrumentManager and PhaseInstrumentManager.has_method("set_cached_player_master_eval"):
		PhaseInstrumentManager.set_cached_player_master_eval(player_eval)
	# v7.x: 广播玩家相位师战力变化（供 bottom_instrument_bar 刷新显示）
	if not player_eval.is_empty() and SignalBus and SignalBus.has_signal("player_phase_master_power_changed"):
		var _pm_total: float = float(player_eval.get("total_score", 0.0))
		SignalBus.player_phase_master_power_changed.emit(
			_pm_total,
			_pm_total,  # 第二参数兼容（v7.x 已移除压缩，两值相同）
			int(player_eval.get("stars", 3)),
			str(player_eval.get("star_name", "")),
			int(player_eval.get("display_level", 15))
		)
	if DEBUG_BATTLE_LOG:
		push_warning("[v6.7] 相位师排名星级 — 玩家:%d★ / 敌方:%d★" % [player_stars, enemy_stars])


func start_battle(battle_scene: Node) -> void:
	if DEBUG_BATTLE_LOG:
		pass
		# [LOG-v5.1] print("[BattleManager] start_battle 被调用")
	battlefield = battle_scene
	# 批次9（2026-08-23）：世代号护栏——end_battle 的结算链跨 3+ 帧延迟，快速重试时
	# 旧链会 clobber 新战状态（_is_phase_master_battle 重置/重复 battle_ended/吞掉
	# 新战 begin_card_grid_combat）。每场递增世代号，延迟调用携带并校验。
	_battle_gen += 1
	_connect_battle_scoped_signals()

	# 性能优化：初始化空间分区系统
	_setup_spatial_grid()
	_setup_enemy_projectile_batch()
	_setup_player_projectile_batch()
	_setup_player_indirect_batch()
	_setup_enemy_indirect_batch()

	# 读取波次参数
	var enemy_wave_interval: float = 12.0
	var enemy_wave_total: int = 0

	# 检查是否是相位师对战
	if GameManager.has_method("is_phase_master_battle"):
		_is_phase_master_battle = GameManager.is_phase_master_battle()
		if _is_phase_master_battle and GameManager.has_method("get_current_phase_master"):
			_phase_master_config = GameManager.get_current_phase_master()
			# v7.x 战场视觉反馈：相位师登场广播（Announcer/Spectacle 播报 + 登场特效）
			if SignalBus and not _phase_master_config.is_empty():
				SignalBus.phase_master_appeared.emit(_phase_master_config.duplicate(true))
			if DEBUG_BATTLE_LOG:
				pass
				# [LOG-v5.1] print("[BattleManager] 相位师对战配置: %s" % _phase_master_config)

	# v6.7: 计算并缓存相位师星级（玩家 + 敌方 boss），供排名差异化加成使用
	# 玩家星级：从 PhaseInstrumentManager 装配 master dict，喂给评估器
	# 敌方星级：仅 boss 对战时算（直接用 _phase_master_config 喂评估器）
	_compute_and_cache_rank_stars()

	if GameManager.has_method("get_enemy_wave_total_for_level"):
		enemy_wave_total = GameManager.get_enemy_wave_total_for_level(GameManager.current_level)
		if GameManager.has_method("get_enemy_wave_interval_for_level"):
			enemy_wave_interval = GameManager.get_enemy_wave_interval_for_level(GameManager.current_level)
	elif _is_phase_master_battle:
		if DEBUG_BATTLE_LOG:
			pass
			# [LOG-v5.1] print("[BattleManager] 相位师战斗：禁用波次系统")

	_card_grid_placement_active = false
	_card_grid_combat_started = false

	# 重置所有状态
	_battle_elapsed_time = 0.0
	_battle_result = {"victory_stars": 0, "era": 0, "player_won": false}
	battle_active = true
	counter_break_count = 0  # v10: 克制质变计数清零
	_defeated_enemies.clear()  ## v6.0: reset defeated enemy tracking
	_group_target_cache_accum = _GROUP_TARGET_CACHE_INTERVAL_SEC

	# 初始化刷新子系统
	_spawn_system.reset(battlefield, enemy_wave_interval, enemy_wave_total)
	if battlefield != null and battlefield.has_method("ensure_battle_slot_grid_ready"):
		battlefield.ensure_battle_slot_grid_ready()
	_spawn_system.configure_card_grid_battle(BattleSlotGrid.SLOT_COUNT)
	call_deferred("begin_card_grid_combat", _battle_gen)
	player_units_node = _spawn_system.get_player_units_node()
	enemy_units_node = _spawn_system.get_enemy_units_node()
	_damage_system.set_player_units_node(player_units_node)
	# v8.x: 同步 player/enemy_units_node 到战法检测器 + 卡片技能引擎
	if _tactic_detector != null:
		_tactic_detector.setup({
			"player_units_node": player_units_node,
			"skill_manager": get_node_or_null("/root/PhaseMasterSkillManager"),
			"card_skill_engine": _card_skill_engine,
		})
	if _card_skill_engine != null:
		_card_skill_engine.setup({
			"player_units_node": player_units_node,
			"enemy_units_node": enemy_units_node,
			"skill_manager": get_node_or_null("/root/PhaseMasterSkillManager"),
			"battlefield": battlefield,
		})

	# 如果是相位师对战，生成敌方相位场基地
	if _is_phase_master_battle and not _phase_master_config.is_empty():
		_spawn_enemy_phase_master_base()

	# v8.x: 我方基地（相位场）HP 加成——技能树/势力技能树的 stat_bonus.hp 路由到基地
	# 此前我方基地 phase_field_driver 恒定 200，无成长通道；现复用技能树 hp 加成让基地可成长
	_apply_player_base_hp_bonus()

	# v9.x（P2-7范围B）：法则卡同步调用已随法则系统退役移除

	# 初始化战斗能量
	if energy_manager:
		# v8 批次3: 把当前关卡的能量惩罚规则传给 energy_manager（set_meta 方式，不改 start_battle 签名）
		var _rules: Dictionary = _get_current_special_rules()
		var _energy_mult: float = float(_rules.get("energy_mult", 1.0))
		var _regen_mult: float = float(_rules.get("energy_regen_mult", 1.0))
		if absf(_energy_mult - 1.0) > 0.001 or absf(_regen_mult - 1.0) > 0.001:
			energy_manager.set_meta("level_energy_mult", _energy_mult)
			energy_manager.set_meta("level_regen_mult", _regen_mult)
		else:
			energy_manager.set_meta("level_energy_mult", 1.0)
			energy_manager.set_meta("level_regen_mult", 1.0)
		energy_manager.start_battle()

	# v7.x 性能：预热结算路径需要的 lazy manager，消除结算时首次 ensure_loaded 同步开销
	# （load()+new()+add_child() 在首帧可达数毫秒级；战斗持续数分钟，预热后 ensure_loaded 仅做
	# is_instance_valid 检查，约 0 开销）
	var _mll_pre = get_node_or_null("/root/ManagerLazyLoader")
	if _mll_pre and _mll_pre.has_method("ensure_loaded"):
		# 注：原 "story" 已移除（StoryManager 删除时的孤儿残留）
		for _pre_id in ["intel_discovery", "quest", "achievement", "level_progress",
				"leaderboard", "faction", "stat_boost"]:
			_mll_pre.ensure_loaded(_pre_id)

	if SignalBus:
		SignalBus.battle_started.emit()
	if PerformanceMetricsManager and PerformanceMetricsManager.has_method("begin_battle_sampling"):
		PerformanceMetricsManager.begin_battle_sampling()
	# v6.6: 触发相位仪主动特殊能力（酸雨/能量罩等开局能力）
	# v8.x 修复：on_battle_start(PLAYER) 只覆盖玩家侧能力字典，不清敌方 static var。
	# 若上一场相位师战未正常走完 end_battle()（如战斗中回标题页 change_scene 直接跳走），
	# _enemy_active 会残留到本场普通关，导致"无敌方相位师却持续被红橙色炮击"。
	# 在注入玩家能力前先 reset_state() 兜底清理上一场残留，确保新战斗从干净状态开始。
	PhaseInstrumentAbilities.reset_state()
	PhaseInstrumentAbilities.on_battle_start(PhaseInstrumentManager, battle_scene, PhaseInstrumentAbilities.Owner.PLAYER)
	# v8.x: 启动卡片定时技能引擎（从 PhaseMasterSkillManager 读取已解锁 card_skill）
	if _card_skill_engine != null:
		_card_skill_engine.on_battle_start()
	# v9.1: 启动组合技套路引擎（战场状态 + 全队机制检测）
	if _combo_engine != null:
		if _combo_field_state == null:
			const ComboFieldStateScript2 = preload("res://scripts/battle/combo_field_state.gd")
			_combo_field_state = ComboFieldStateScript2.new()
		_combo_field_state.reset()
		_combo_engine.setup(battle_scene, _combo_field_state)

	call_deferred("_deferred_refresh_card_grid_hud")


func end_battle(player_won: bool) -> void:
	if DEBUG_BATTLE_LOG:
		pass
		# [LOG-v5.1] print("[BattleManager] end_battle called, player_won: ", player_won)
	var gen := _battle_gen
	_disconnect_battle_scoped_signals()
	battle_active = false
	_card_grid_placement_active = false
	_card_grid_combat_started = false
	_clear_group_target_cache()
	# v6.6: 清空伤害数字节流表，flush 残留合并伤害并避免跨战斗残留
	CombatFeedback.reset_throttle()
	# v7.x: 重置相位仪主动能力状态（owner-aware 单引擎，内部清双 owner）
	PhaseInstrumentAbilities.reset_state()
	# v8.x: 重置卡片定时技能引擎 + 战法检测器
	if _card_skill_engine != null:
		_card_skill_engine.reset()
	if _tactic_detector != null:
		_tactic_detector.reset()
	# v9.1: 重置组合技套路引擎 + 战场状态
	if _combo_engine != null:
		_combo_engine.reset()
	# v9.x: 重置组合技指示器对象池——长生命周期指示器（弱点/雷达/谐振 3-6s）在战斗拆卸时
	# fade callback 可能不触发，_active_indicators 计数会泄漏累积，多场后池被永久锁死。
	# reset 归零计数 + free 池中归还节点，下场战斗可重新分配。
	VfxImpactFactory.reset_indicator_pool()
	# v6.7: 清空相位师排名星级缓存（恢复 3★ 基准，避免影响下一场战斗）
	if PhaseInstrumentManager and PhaseInstrumentManager.has_method("clear_rank_cache"):
		PhaseInstrumentManager.clear_rank_cache()

	# 性能优化：清理空间分区系统
	_cleanup_spatial_grid()
	_cleanup_enemy_projectile_batch()
	_cleanup_player_projectile_batch()
	_cleanup_player_indirect_batch()
	_cleanup_enemy_indirect_batch()
	# v9.x: 清理光环缓存（AuraManager 是 autoload 单例，单位 queue_free 滞后会导致
	# _unit_auras 字典残留过期 unit_id 到下场战斗。end_battle 兜底清空。）
	var _am: Node = get_node_or_null("/root/AuraManager")
	if _am != null and _am.has_method("clear_all"):
		_am.clear_all()

	# 停止敌方相位驱动器
	if _enemy_phase_driver != null and is_instance_valid(_enemy_phase_driver):
		if _enemy_phase_driver.has_method("stop_production"):
			_enemy_phase_driver.stop_production()
		_enemy_phase_driver.queue_free()
	_enemy_phase_driver = null
	# 清理预览单位
	_spawn_system.clear_preview_units()
	# 结束能量系统
	if energy_manager:
		energy_manager.end_battle()
	# 清空节点引用，防止悬空指针
	player_units_node = null
	enemy_units_node = null
	# v7.x 性能：在清场前计算侦查加成标志（单位还存活），供 Frame B' 情报收获使用。
	# 必须在 clear_all_units 之前——之后单位已 queue_free，_player_units_node.get_children() 为空。
	if _damage_system != null and _damage_system.has_method("_get_recon_fragment_bonus_multiplier"):
		_pending_has_recon = _damage_system._get_recon_fragment_bonus_multiplier() > 0.0
	else:
		_pending_has_recon = false
	# 清理战场单位（queue_free 仅入队，帧末才真正释放，不阻塞本帧）
	if DEBUG_BATTLE_LOG:
		pass
		# [LOG-v5.1] print("[BattleManager] Calling clear_all_units")
	_spawn_system.clear_all_units()
	if DEBUG_BATTLE_LOG:
		pass
		# [LOG-v5.1] print("[BattleManager] clear_all_units completed")
	if PerformanceMetricsManager and PerformanceMetricsManager.has_method("end_battle_sampling"):
		PerformanceMetricsManager.end_battle_sampling()
	if BlueprintManager and BlueprintManager.has_method("flush_deferred_unlock_notifications"):
		BlueprintManager.flush_deferred_unlock_notifications()
	# v7.x 性能：把掉落生成 / 任务通知 / battle_ended 信号广播（18+ 监听者）等重活
	# 延迟到下一帧。根因：胜利判定走 _process → _check_win_lose → end_battle，全部
	# 在"最后一个敌人倒下"那一帧同步执行；generate_battle_completion_drops 遍历所有
	# 击败敌人做情报掷骰（最重），叠加 18 个 battle_ended 监听者同步广播，渲染线程
	# 要等整条链结束才能画下一帧——这就是"胜利前卡一下"的主因。
	# 延迟后：本帧只剩轻量收尾（清缓存 + queue_free 入队），立即渲染胜利瞬间；
	# 下一帧再算掉落 + 广播信号。依赖安全性已核实：_defeated_enemies / spawn_system
	# 的 5 个累计 getter（wave_total/interval/max_deployed/units_lost/wave_index）
	# 都不被 clear_all_units 触碰；battle_active=false 后 _process 首行 return，
	# _battle_elapsed_time 不再增长；各入口有 battle_active 守卫，延迟期间不重入。
	call_deferred("_deferred_end_battle_finalize", player_won, gen)


## v9.1: 暴露组合技引擎（供 module_effect_handler / bullet 查询激活机制）
func get_combo_engine() -> RefCounted:
	return _combo_engine

## v9.1: 暴露战场状态管理器（供 phase_instrument_abilities 注入浓度）
func get_combo_field_state() -> RefCounted:
	return _combo_field_state


# v7.x 性能：原 end_battle 末尾的重负载部分，延迟到下一帧执行以消除胜利瞬间卡顿。
# 顺序约束：①掉落表生成（中等负载）→ ①b情报收获（重负载，遍历击败敌人掷骰）
# → ②任务通知（读 _battle_result.victory_stars，必须在掉落生成之后）
# → ③清理相位师战斗状态（必须在掉落生成之后，否则双爆回归）
# → ④广播 battle_ended（18+ 监听者本帧跑，但已是胜利后第三帧，玩家无感知）。
#
# 帧链：A(end_battle清理) → B(①掉落表) → B'(①b情报收获) → C(②③④广播)
# 数据时序安全：_battle_result 在①写入，①b追加字段，②③④在下一帧读；
# _is_phase_master_battle 在 C 才清零，B/B' 都可安全读取。
func _deferred_end_battle_finalize(player_won: bool, gen: int = -1) -> void:
	# 批次9：世代号护栏——新战斗已开打则本链（旧场结算）整体作废
	if gen >= 0 and gen != _battle_gen:
		return
	# ①掉落表生成（中等负载：DropManager 掉落表 + 相位仪掉落）
	if player_won:
		_battle_result = _damage_system.generate_battle_drops_only(
			true,
			_battle_elapsed_time,
			_spawn_system.get_enemy_wave_total(),
			_spawn_system.get_enemy_wave_interval(),
			_spawn_system.get_max_player_units_deployed(),
			_spawn_system.get_player_units_lost()
		)
	# 掉落表完成后，把①b情报收获延到下一帧
	call_deferred("_deferred_end_battle_intel_harvest", player_won, gen)


func _deferred_end_battle_intel_harvest(player_won: bool, gen: int = -1) -> void:
	if gen >= 0 and gen != _battle_gen:
		return
	# ①b 情报收获生成（重负载：遍历全部击败敌人做情报掷骰，胜利后单帧最重操作）
	# has_recon 由 end_battle（Frame A）清场前计算，此处直接传入，避免遍历已清空的单位。
	if player_won:
		_battle_result = _damage_system.generate_intel_harvest(_battle_result, _pending_has_recon)
	# v10 解题式玩法：克制链统计写入战报（"本关克制链生效 N 次"，战后结算可读）
	_battle_result["counter_break_count"] = counter_break_count
	# ②③④ 推迟到下一帧（让渲染线程先画情报收获后的胜利画面）
	call_deferred("_deferred_end_battle_broadcast", player_won, gen)

# v7.x 性能：掉落表+情报收获都完成后的收尾——任务通知/清状态/广播，帧C 执行。
# 依赖 _battle_result（帧B 写入掉落/星级，帧B' 追加情报字段，本帧安全读取）。
func _deferred_end_battle_broadcast(player_won: bool, gen: int = -1) -> void:
	if gen >= 0 and gen != _battle_gen:
		return
	# ①c 清理 battle_vfx 组所有节点（焦痕/烟柱/核爆动画/浓度场等延迟 spawn 或永久残留的 VFX）。
	# 放在 battle_ended emit 前：覆盖 prune_transient_children 漏掉的延迟回调 spawn 节点
	# （核爆余波环 0.08s 延迟、烟柱 2.5s 自毁链等在清场后才生成的漏网之鱼）。
	# get_nodes_in_group 返回快照副本，循环内 queue_free 安全（帧末才真正释放）。
	for node in get_tree().get_nodes_in_group("battle_vfx"):
		if is_instance_valid(node):
			node.queue_free()
	# ②通知任务系统（读 _battle_result.victory_stars，必须在掉落生成之后）
	ManagerLazyLoader.ensure_loaded("quest")
	var qm = get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("notify_battle_result"):
		var stars: int = _battle_result.get("victory_stars", 0)
		qm.notify_battle_result(_battle_elapsed_time, stars, _spawn_system.get_enemy_wave_index())
	# ③清理相位师战斗状态（必须在掉落生成之后，保证相位师战改造蓝图屏蔽生效）
	_phase_master_config = {}
	_is_phase_master_battle = false
	# ④广播战斗结束信号（原 _emit_battle_ended 合并于此，无需再套一层 deferred）
	if SignalBus:
		SignalBus.battle_ended.emit(player_won)


# =========================================================================
#  玩家部署（转发到 SpawnSystem）
# =========================================================================

func request_player_deploy_at(platform_card_id: String, world_pos: Vector2) -> bool:
	return _spawn_system.request_player_deploy(platform_card_id, world_pos, _current_battle_era())


func is_card_grid_placement_phase() -> bool:
	## 已取消「仅布阵阶段」：格子战进场即开战，全程可部署；保留 API 供旧代码查询，恒为 false
	return false


func is_card_grid_combat_started() -> bool:
	return battle_active and _card_grid_combat_started


func begin_card_grid_combat(gen: int = -1) -> void:
	# 批次9：世代号护栏——gen>=0 时校验（旧世代的延迟调用直接丢弃）
	if gen >= 0 and gen != _battle_gen:
		return
	if not battle_active:
		return
	if _card_grid_combat_started:
		return
	_card_grid_placement_active = false
	_card_grid_combat_started = true
	if battlefield != null and battlefield.has_method("_sync_battle_slot_grid_lane"):
		battlefield._sync_battle_slot_grid_lane()
	_spawn_system.finalize_card_grid_and_spawn_enemies(GameManager.current_level if GameManager else 1)
	if _is_phase_master_battle and _enemy_phase_driver != null and is_instance_valid(_enemy_phase_driver) and _enemy_phase_driver.has_method("start_production"):
		_enemy_phase_driver.start_production()
	if GameManager and GameManager.main_scene:
		var bfb: Node = GameManager.main_scene.get_node_or_null("HudLayer/BattleBottomBar/BottomFunctionBar")
		if bfb and bfb.has_method("set_start_battle_text"):
			bfb.set_start_battle_text("战斗中")
	call_deferred("_deferred_refresh_card_grid_hud")


func _deferred_refresh_card_grid_hud() -> void:
	var hud: Node = null
	if GameManager and GameManager.main_scene:
		hud = GameManager.main_scene.get_node_or_null("CardGridBattleHud")
	if hud == null and battlefield != null:
		hud = battlefield.get_node_or_null("CardGridBattleHud")
	if hud and hud.has_method("configure_for_battle"):
		hud.configure_for_battle()



# =========================================================================
#  信号回调
# =========================================================================

## v9.x: 单位生成后广播当前计数（spawn_system 在 emit unit_spawned 前已递增计数器）
func _on_unit_spawned(_unit: Node, _is_player: bool) -> void:
	if not battle_active:
		return
	_emit_unit_counts()

## v9.x: 统一广播单位数（供 UI 信号驱动刷新，替代各自 _process 轮询）
func _emit_unit_counts() -> void:
	if SignalBus:
		SignalBus.unit_counts_changed.emit(get_player_unit_count(), get_enemy_unit_count())


func _on_unit_died(unit: Node, is_player: bool) -> void:
	if not battle_active:
		return
	if not is_instance_valid(unit):
		return
	if is_player:
		_spawn_system.on_player_unit_died(unit)
		# v6.5 诊断：玩家单位死亡后立即 recount，验证左侧 HUD 数量是否同步减少。
		# 仅在 debug 构建打印，避免污染发布版本日志。
		if OS.is_debug_build() and DEBUG_BATTLE_LOG:
			var live_after: int = recount_player_units_on_field()
			prints("[BM诊断] 我方单位死亡: recount存活=%d, 缓存=%d, _is_dying=%s, phase_master战=%s" % [
				live_after, _spawn_system.player_unit_count,
				bool(unit.get("_is_dying")) if "_is_dying" in unit else "N/A",
				_is_phase_master_battle,
			])
	else:
		_spawn_system.on_enemy_unit_died()
		_damage_system.roll_blueprint_drops(unit)
		_damage_system.process_kill_rewards(unit)
		## v6.0: record defeated enemy for intel system
		_record_defeated_enemy(unit)
	_check_win_lose()
	# v9.x: 死亡后计数器已更新，广播单位数供 UI 信号驱动刷新
	_emit_unit_counts()


## v6.11: _record_battle_star_kill 已移除（战力星级系统②已合并到强化等级①）


## v8 批次3: 获取当前关卡的特殊规则（读 GameManager.current_level → LevelInformation）
## v9 perf：按关卡号缓存——规则是静态数据且整场战斗不变，_check_win_lose 每帧调用，
## 原实现每帧 Dictionary.get + 两次默认值空字典分配（小额常驻垃圾）
var _cached_special_rules: Dictionary = {}
var _cached_special_rules_level: int = -1

func _get_current_special_rules() -> Dictionary:
	if GameManager == null:
		return {}
	var level: int = 1
	if "current_level" in GameManager:
		level = int(GameManager.current_level)
	if level != _cached_special_rules_level:
		# v7.x 性能：用全局单例，避免 _check_win_lose 每帧重建 100 关字典
		var li = LevelInformation.get_shared()
		_cached_special_rules = li.get_special_rules(level)
		_cached_special_rules_level = level
	return _cached_special_rules


func _check_win_lose() -> void:
	if not battle_active or battlefield == null:
		return

	# 相位师战斗：胜负由基地销毁信号驱动
	if _is_phase_master_battle:
		return

	if not _card_grid_combat_started:
		return

	# v8 批次3: 特殊胜利条件——坚守N波（survive_waves）
	# 达到指定波数后立即判胜（无需清场），考验玩家在持续压力下的生存能力
	# ⚠️ 2026-08-16 关卡设计审查：本分支只对普通关生效——上方 _is_phase_master_battle
	# 已提前 return（驻守相位师胜负=摧毁基地）。survive_waves 不可挂在驻守关
	# （LevelInformation._set_rules 有守卫拒绝挂载）。
	var rules: Dictionary = _get_current_special_rules()
	var win_type: String = String(rules.get("win_type", ""))
	if win_type == "survive_waves":
		var survive_target: int = int(rules.get("win_param", 0))
		if survive_target > 0 and _spawn_system != null:
			var current_wave: int = _spawn_system.get_enemy_wave_index()
			if current_wave >= survive_target:
				if DEBUG_BATTLE_LOG:
					pass
				end_battle(true)
				return

	# 普通格子战：配置波次全部刷出 + 场上无敌方战斗单位
	if not _spawn_system.all_enemy_waves_spawned():
		return
	var live_enemies: int = _spawn_system.enemy_unit_count
	if live_enemies <= 0:
		live_enemies = recount_enemy_units_on_field()
		_spawn_system.enemy_unit_count = live_enemies
	if live_enemies > 0:
		return
	if DEBUG_BATTLE_LOG:
		pass
		# [LOG-v5.1] print("[BattleManager] 普通战斗胜利！波次=%d/%d，剩余敌人=%d" % [_spawn_system.get_enemy_wave_index(), _spawn_system.get_enemy_wave_total(), live_enemies])
	end_battle(true)


func _on_phase_driver_destroyed() -> void:
	if not battle_active:
		return
	end_battle(false)


func _on_enemy_phase_driver_destroyed() -> void:
	if not battle_active:
		return
	end_battle(true)

## 批次9：驱动销毁信号按场连接/断开（迟发信号只在本场有效，见 _battle_gen 注释）
func _connect_battle_scoped_signals() -> void:
	if not SignalBus:
		return
	if not SignalBus.phase_driver_destroyed.is_connected(_on_phase_driver_destroyed):
		SignalBus.phase_driver_destroyed.connect(_on_phase_driver_destroyed)
	if SignalBus.has_signal("enemy_phase_driver_destroyed"):
		if not SignalBus.enemy_phase_driver_destroyed.is_connected(_on_enemy_phase_driver_destroyed):
			SignalBus.enemy_phase_driver_destroyed.connect(_on_enemy_phase_driver_destroyed)


func _disconnect_battle_scoped_signals() -> void:
	if not SignalBus:
		return
	if SignalBus.phase_driver_destroyed.is_connected(_on_phase_driver_destroyed):
		SignalBus.phase_driver_destroyed.disconnect(_on_phase_driver_destroyed)
	if SignalBus.has_signal("enemy_phase_driver_destroyed") and SignalBus.enemy_phase_driver_destroyed.is_connected(_on_enemy_phase_driver_destroyed):
		SignalBus.enemy_phase_driver_destroyed.disconnect(_on_enemy_phase_driver_destroyed)

# =========================================================================
#  v6.0: 记录击败的敌人信息（供情报系统使用）
# =========================================================================

func _record_defeated_enemy(unit: Node) -> void:
	if not is_instance_valid(unit):
		return
	var archetype_id: String = ""
	var rank: String = "normal"
	var enemy_type: String = ""
	if unit.get("archetype_id") != null:
		archetype_id = str(unit.archetype_id)
	## 判断rank
	if unit.get("is_elite") == true or unit.get("is_boss") == true:
		rank = "boss" if unit.get("is_boss") == true else "elite"
	## 尝试从EnemyArchetypes获取tags
	if not archetype_id.is_empty():
		var config: Dictionary = EnemyArchetypes.get_config(archetype_id)
		if not config.is_empty():
			var tags: Array = config.get("tags", [])
			if tags.has("boss"):
				rank = "boss"
			elif tags.has("elite"):
				rank = "elite"
			enemy_type = _guess_enemy_type_from_archetype(archetype_id, tags)
	if enemy_type.is_empty():
		enemy_type = "infantry"
	_defeated_enemies.append({
		"archetype_id": archetype_id,
		"rank": rank,
		"enemy_type": enemy_type,
	})

func _guess_enemy_type_from_archetype(archetype_id: String, tags: Array) -> String:
	var lower: String = archetype_id.to_lower()
	if "flame" in lower or "fire" in lower:
		return "flame"
	if "armor" in lower or "tank" in lower or "pz" in lower or "tiger" in lower or "t72" in lower or "m1a" in lower or "ft17" in lower:
		return "heavy_armor"
	if "artillery" in lower or "howitzer" in lower or "m270" in lower or "mortar" in lower or "m81" in lower or "zsu" in lower:
		return "artillery"
	if "stealth" in lower or "spectre" in lower:
		return "stealth"
	if "air" in lower or "mig" in lower or "fighter" in lower or "drone" in lower or "heli" in lower or "ah64" in lower or "ah1" in lower:
		return "air"
	if "boss" in lower or "nano" in lower or tags.has("boss"):
		return "boss_nano"
	if "phase_master" in lower or tags.has("phase_master"):
		return "boss_phase"
	if "scout" in lower or "recon" in lower:
		return "scout"
	if "medic" in lower or "repair" in lower:
		return "medic"
	if "command" in lower or "hq" in lower:
		return "command"
	return "infantry"


# =========================================================================
#  相位师战斗基地
# =========================================================================

func _spawn_enemy_phase_master_base() -> void:
	if battlefield == null or _phase_master_config.is_empty():
		return
	if not battlefield.has_method("ensure_enemy_phase_driver"):
		return
	_enemy_phase_driver = battlefield.ensure_enemy_phase_driver(_phase_master_config)
	# v7.x: 敌方相位师基地建立后，触发敌方相位仪主动能力（开局一次性能力 + 周期能力初始化）
	if _enemy_phase_driver != null and is_instance_valid(_enemy_phase_driver):
		PhaseInstrumentAbilities.on_battle_start(_enemy_phase_driver, battlefield, PhaseInstrumentAbilities.Owner.ENEMY)
		# v8.5: 初始化敌方相位师主动技能引擎（boss active_spells 定时触发）
		if _enemy_master_skill_engine != null:
			_enemy_master_skill_engine.setup(_enemy_phase_driver, battlefield)
			# 注入引擎引用给 driver（用于死亡时触发被动）
			if _enemy_phase_driver.has_method("set_master_skill_engine"):
				_enemy_phase_driver.set_master_skill_engine(_enemy_master_skill_engine)


## v8.x: 我方基地（相位场）HP 加成注入。
## 取相位师技能树 + 激活势力技能树的 stat_bonus.hp，乘到我方基地 phase_field_driver。
## 此前基地恒定 200 无成长；现复用技能树 hp 加成通道让基地可成长（与单位 hp 加成同源）。
## 复用 active_law_effects.gd:126 的取节点范式（battlefield.get_node_or_null("PhaseFieldDriver")）。
func _apply_player_base_hp_bonus() -> void:
	if battlefield == null or not is_instance_valid(battlefield):
		return
	var pd: Node = battlefield.get_node_or_null("PhaseFieldDriver")
	if pd == null or not is_instance_valid(pd):
		return
	if not ("max_hp" in pd):
		return
	# 汇总 hp 加成比例（技能树 + 势力技能树）
	var hp_bonus: float = 0.0
	# 相位师技能树
	var pmsm: Node = get_node_or_null("/root/PhaseMasterSkillManager")
	if pmsm != null and pmsm.has_method("get_active_effects"):
		var fx: Dictionary = pmsm.get_active_effects().get("stat_bonus", {})
		hp_bonus += float(fx.get("hp", 0.0))
	# 激活势力技能树
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	if fsm != null and fsm.has_method("get_active_faction_skill_effects"):
		var ffx: Dictionary = fsm.get_active_faction_skill_effects().get("stat_bonus", {})
		hp_bonus += float(ffx.get("hp", 0.0))
	if hp_bonus <= 0.0:
		return
	# 应用到基地（乘法，与单位 hp 加成口径一致）
	var old_max: float = float(pd.max_hp)
	pd.max_hp = maxf(1.0, old_max * (1.0 + hp_bonus))
	if "hp" in pd:
		pd.hp = float(pd.max_hp)  # 满血出场（与敌方 driver setup 后 hp=max_hp 一致）
	# 刷新血条 UI（与 phase_field_driver._ready 的 emit 范式一致）
	if SignalBus and SignalBus.has_signal("phase_driver_hp_changed"):
		SignalBus.phase_driver_hp_changed.emit(float(pd.hp), float(pd.max_hp))


# =========================================================================
#  公开只读接口（转发到 SpawnSystem，保持外部 API 兼容）
# =========================================================================

func get_player_spawn_time_remaining() -> float:
	return _spawn_system.get_player_spawn_time_remaining()

func get_player_spawn_interval() -> float:
	return _spawn_system.get_player_spawn_interval()

func get_player_unit_count() -> int:
	if not battle_active:
		return 0
	# v6.5: HUD 高频读取走缓存计数器（O(1)），避免每帧 O(N) 递归遍历。
	# 缓存由部署(+1)/死亡(-1)维护，且 _is_active_combat_unit 已排除 deploy ghost，
	# 计数器与 recount 结果一致。部署检查仍直接调 recount_player_units_on_field() 保证准确。
	return _spawn_system.player_unit_count

func get_enemy_wave_time_remaining() -> float:
	return _spawn_system.get_enemy_wave_time_remaining() if battle_active else -1.0

func get_enemy_wave_interval() -> float:
	return _spawn_system.get_enemy_wave_interval() if battle_active else 0.0

func get_enemy_wave_index() -> int:
	return _spawn_system.get_enemy_wave_index() if battle_active else 0

func get_enemy_unit_count() -> int:
	if not battle_active:
		return 0
	# v6.5: 同上，读缓存计数器避免每帧 O(N) 遍历
	return _spawn_system.enemy_unit_count


func recount_player_units_on_field() -> int:
	if player_units_node == null or not is_instance_valid(player_units_node):
		return 0
	return _recount_units_under(player_units_node, true)


func recount_enemy_units_on_field() -> int:
	if enemy_units_node == null or not is_instance_valid(enemy_units_node):
		return 0
	return _recount_units_under(enemy_units_node, false)


func _recount_units_under(root: Node, ally: bool) -> int:
	if root == null or not is_instance_valid(root):
		return 0
	var total: int = 0
	for child in root.get_children():
		total += _recount_unit_node(child, ally)
	return total


func _recount_unit_node(node: Node, ally: bool) -> int:
	if node == null or not is_instance_valid(node):
		return 0
	if _is_active_combat_unit(node, ally):
		return 1
	var sub: int = 0
	for child in node.get_children():
		sub += _recount_unit_node(child, ally)
	return sub


func _is_active_combat_unit(node: Node, ally: bool) -> bool:
	if not node.has_method("take_damage"):
		return false
	if ally:
		if not node.is_in_group("player_units"):
			return false
	else:
		if not node.is_in_group("enemy_units"):
			return false
	if "is_preview_mode" in node and bool(node.get("is_preview_mode")):
		return false
	# v6.5: 部署幽灵（尚未实体化）不计入存活数，否则会虚高导致
	# "场上4个但显示5个且不让再部署"的计数错位
	if "is_deploy_ghost" in node and bool(node.get("is_deploy_ghost")):
		return false
	# 死亡淡出期间（_is_dying=true，queue_free 尚未执行）不计入存活数，
	# 否则计数会在淡出动画的 ~0.5s 内虚高，且 maxi(cached,live) 会把它锁在峰值
	if "_is_dying" in node and bool(node.get("_is_dying")):
		return false
	return true

func get_enemy_wave_total() -> int:
	return _spawn_system.get_enemy_wave_total() if battle_active else 0


## v10 解题式玩法：下一波敌方构成预览（波次预警 HUD 数据源）。
## 返回结构见 BattleSpawnSystem.get_next_wave_preview()；无下一波返回 {valid: false}。
func get_next_wave_preview() -> Dictionary:
	if not battle_active:
		return {"valid": false}
	return _spawn_system.get_next_wave_preview()


func try_place_enemy_unit_on_card_grid(unit: Node2D) -> bool:
	if not battle_active:
		return false
	return _spawn_system.place_existing_enemy_on_card_grid(unit)


func spawn_enemy_unit_on_card_grid(unit: Node2D) -> bool:
	if not battle_active:
		return false
	return _spawn_system.spawn_enemy_unit_on_card_grid(unit)

func set_player_unit_count(c: int) -> void:
	_spawn_system.player_unit_count = c

func set_enemy_unit_count(c: int) -> void:
	_spawn_system.enemy_unit_count = c

func get_battle_result() -> Dictionary:
	return _battle_result.duplicate(true)


func _maybe_refresh_group_target_cache(delta: float) -> void:
	_group_target_cache_accum += delta
	if _group_target_cache_accum < _GROUP_TARGET_CACHE_INTERVAL_SEC:
		return
	_group_target_cache_accum = 0.0
	var tree := get_tree()
	if tree == null:
		return
	for g in ["player_units", "enemy_units", "phase_driver", "enemy_phase_driver"]:
		_cached_nodes_by_group[g] = tree.get_nodes_in_group(g)
	# v6.6: 顺带 flush 伤害数字节流表（同节奏 ~0.28s），确保合并伤害最终显示
	CombatFeedback.flush_expired_throttle()


func _clear_group_target_cache() -> void:
	_cached_nodes_by_group.clear()
	_group_target_cache_accum = 0.0


## 供单位索敌 fallback：读节流缓存（战斗外或未命中缓存时回退到实时 get_nodes_in_group）
func get_cached_nodes_in_group(group_name: String) -> Array:
	if battle_active and _cached_nodes_by_group.has(group_name):
		# v6.6: 直接返回缓存数组引用，调用方自行跳过失效节点（用 is_instance_valid）。
		# 原实现每次调用都分配新数组并做 is_instance_valid 遍历，索敌高频调用下开销可观。
		# 索敌路径已在 is_attackable_combat_unit / 距离判定中做了 is_instance_valid 检查，
		# 因此返回原数组不会造成悬空引用错误。
		return _cached_nodes_by_group[group_name]
	var tree := get_tree()
	if tree == null:
		return []
	return tree.get_nodes_in_group(group_name)


# =========================================================================
#  性能优化：空间分区系统
# =========================================================================

## 初始化空间分区网格
func _setup_spatial_grid() -> void:
	if not SpatialGridClass:
		push_error("[BattleManager] SpatialGrid 类未加载")
		return

	# 创建空间网格实例
	spatial_grid = SpatialGridClass.new()
	spatial_grid.name = "SpatialGrid"

	# 配置网格参数（根据战场尺寸）
	# 战场范围: X(40-1240)；Y 覆盖三行布局全程（车道中心≈576，三行偏移 -30/0/+60 → 约 466~636）。
	# 空间网格 Y 范围 200~720 覆盖整个战场垂直区，确保所有行单位可被索敌/点击/AOE 命中。
	spatial_grid.setup(100.0, 40.0, 1240.0, 200.0, 720.0)

	# 添加到场景树
	if battlefield:
		battlefield.add_child(spatial_grid)
		if DEBUG_BATTLE_LOG:
			pass
			# [LOG-v5.1] print("[BattleManager] 空间分区系统已初始化")
	else:
		push_warning("[BattleManager] 战场未设置，空间网格无法添加到场景树")

## 清理空间分区网格
func _cleanup_spatial_grid() -> void:
	if spatial_grid and is_instance_valid(spatial_grid):
		spatial_grid.clear()
		spatial_grid.queue_free()
		spatial_grid = null
		if DEBUG_BATTLE_LOG:
			pass
			# [LOG-v5.1] print("[BattleManager] 空间分区系统已清理")


func _setup_enemy_projectile_batch() -> void:
	_cleanup_enemy_projectile_batch()
	if battlefield == null:
		prints("[BM] enemy_batch FAILED: battlefield is null")
		return
	var n := Node2D.new()
	n.set_script(SimpleEnemyProjectileBatchScript)
	n.name = "SimpleEnemyProjectileBatch"
	battlefield.add_child(n)
	# P0 修复：删除战斗启动时的冗余调试 prints（含笔误条件 n.has_method("has_method")）
	enemy_projectile_batch = n


func _cleanup_enemy_projectile_batch() -> void:
	if enemy_projectile_batch != null and is_instance_valid(enemy_projectile_batch):
		if enemy_projectile_batch.has_method("clear_all"):
			enemy_projectile_batch.clear_all()
		enemy_projectile_batch.queue_free()
	enemy_projectile_batch = null


func _setup_player_projectile_batch() -> void:
	_cleanup_player_projectile_batch()
	if battlefield == null:
		return
	var n := Node2D.new()
	n.set_script(SimplePlayerProjectileBatchScript)
	n.name = "SimplePlayerProjectileBatch"
	battlefield.add_child(n)
	player_projectile_batch = n


func _cleanup_player_projectile_batch() -> void:
	if player_projectile_batch != null and is_instance_valid(player_projectile_batch):
		if player_projectile_batch.has_method("clear_all"):
			player_projectile_batch.clear_all()
		player_projectile_batch.queue_free()
	player_projectile_batch = null


func _setup_player_indirect_batch() -> void:
	_cleanup_player_indirect_batch()
	if battlefield == null:
		return
	var n := Node2D.new()
	n.set_script(SimpleIndirectProjectileBatchScript)
	n.name = "SimpleIndirectProjectileBatch"
	battlefield.add_child(n)
	player_indirect_batch = n


func _cleanup_player_indirect_batch() -> void:
	if player_indirect_batch != null and is_instance_valid(player_indirect_batch):
		if player_indirect_batch.has_method("clear_all"):
			player_indirect_batch.clear_all()
		player_indirect_batch.queue_free()
	player_indirect_batch = null


func _setup_enemy_indirect_batch() -> void:
	_cleanup_enemy_indirect_batch()
	if battlefield == null:
		return
	var n := Node2D.new()
	n.set_script(SimpleIndirectProjectileBatchScript)
	n.name = "SimpleEnemyIndirectBatch"
	n.is_player_side = false
	battlefield.add_child(n)
	enemy_indirect_batch = n


func _cleanup_enemy_indirect_batch() -> void:
	if enemy_indirect_batch != null and is_instance_valid(enemy_indirect_batch):
		if enemy_indirect_batch.has_method("clear_all"):
			enemy_indirect_batch.clear_all()
		enemy_indirect_batch.queue_free()
	enemy_indirect_batch = null


func _on_unit_damaged_combat_feedback(unit: Node, _is_player: bool, amount: float, at_position: Vector2) -> void:
	# v6.6: 暴击时弹道会打 _vfx_crit_pending 标记。这里据此用金色 critical 样式显示
	# （数字仍取信号携带的 amount = 实际扣血），避免暴击数字绕过 take_damage 导致与血条矛盾。
	# v8.1: 穿透时弹道打 _vfx_pierce_pending 标记，据此用紫色 pierce 样式显示。
	# v8.1: 暴击屏幕震动也在此统一触发（原 new_systems_integration._on_unit_damaged 的暴击震动
	#        因 meta 竞态失效——battle_manager 先清 meta 导致 new_systems 读不到，是死逻辑，已迁移至此）。
	var is_crit: bool = false
	var is_pierce: bool = false
	var is_counter: bool = false
	if unit != null and is_instance_valid(unit):
		if unit.has_meta("_vfx_crit_pending"):
			unit.remove_meta("_vfx_crit_pending")
			is_crit = true
		if unit.has_meta("_vfx_pierce_pending"):
			unit.remove_meta("_vfx_pierce_pending")
			is_pierce = true
		# v10 解题式玩法：标签克制质变命中（break_effect 生效）时用金色 counter_break 样式
		if unit.has_meta("_vfx_counter_pending"):
			unit.remove_meta("_vfx_counter_pending")
			is_counter = true
	# 暴击优先于穿透/克制样式（暴击视觉冲击更强）；克制优先于穿透（质变更稀有）
	# v9.x 清理：暴击震屏块删除——BattleFeedbackManager 从未注册（get_node_or_null 恒 null），
	# 该路径自 v8.1 迁移以来静默失效；恢复震屏应直调 screen_shake.gd（8 个活文件的既有先例）
	if is_crit:
		CombatFeedback.show_damage(at_position, amount, unit, true, "critical")
	elif is_counter:
		CombatFeedback.show_damage(at_position, amount, unit, false, "counter_break")
	elif is_pierce:
		CombatFeedback.show_damage(at_position, amount, unit, false, "pierce")
	else:
		CombatFeedback.show_damage(at_position, amount, unit, false)


# =========================================================================
#  内部工具
# =========================================================================

func _current_battle_era() -> int:
	var lv: int = 1
	if "current_level" in GameManager:
		lv = int(GameManager.current_level)
	return GC.get_era_for_level(lv)


## v6.4: 触发屏幕震动（命中/爆炸反馈的统一入口）
## 调用方示例：BattleManager.request_screen_shake(3.0, 0.15)
func request_screen_shake(intensity: float, duration: float) -> void:
	if battlefield == null or not is_instance_valid(battlefield):
		return
	if battlefield.has_method("request_screen_shake"):
		battlefield.request_screen_shake(intensity, duration)
