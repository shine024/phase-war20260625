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
# v6.7: 相位师排名差异化加成 —— 玩家装配器 + 战力评估器
const MasterPlayerAssembler = preload("res://scripts/master_player_assembler.gd")
const MasterPowerEvaluator = preload("res://scripts/master_power_evaluator.gd")
const DEBUG_BATTLE_LOG := false

# v6.0 依赖注入重构: 移除 @onready 单例引用，改用 setup() 方法注入
var energy_manager: Node = null
var phase_instrument: Node = null

# ---- 子系统 ----
var _spawn_system: RefCounted = null  ## BattleSpawnSystem
var _damage_system: RefCounted = null  ## BattleDamageSystem

# ---- 性能优化：空间分区系统 ----
var spatial_grid: Node = null  ## SpatialGrid 实例
## 玩家轻武器弹道批处理（SimplePlayerProjectileBatch）
var player_projectile_batch: Node = null
## 敌方轻武器弹道批处理（SimpleEnemyProjectileBatch）
var enemy_projectile_batch: Node = null
## 玩家曲射/空射弹道批处理（SimpleIndirectProjectileBatch）
var player_indirect_batch: Node = null
## 敌方曲射/空射弹道批处理（SimpleIndirectProjectileBatch）
var enemy_indirect_batch: Node = null

# ---- 战斗状态 ----
var battle_active: bool = false
var battlefield: Node = null
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

# ---- v6.6(剧情): 必败战机制（序章噩梦/守护者失败重试）----
# 开启后启动倒计时，到时强制判负；玩家无法通过清场获胜（_check_win_lose 提前返回）
var _force_defeat: bool = false
var _force_defeat_timer: float = 0.0  ## 剩余秒数，倒计时到 0 强制 end_battle(false)

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
		if not SignalBus.phase_driver_destroyed.is_connected(_on_phase_driver_destroyed):
			SignalBus.phase_driver_destroyed.connect(_on_phase_driver_destroyed)
		if SignalBus.has_signal("enemy_phase_driver_destroyed"):
			if not SignalBus.enemy_phase_driver_destroyed.is_connected(_on_enemy_phase_driver_destroyed):
				SignalBus.enemy_phase_driver_destroyed.connect(_on_enemy_phase_driver_destroyed)
		if not SignalBus.unit_damaged.is_connected(_on_unit_damaged_combat_feedback):
			SignalBus.unit_damaged.connect(_on_unit_damaged_combat_feedback)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not battle_active or battlefield == null:
		return
	var tree = get_tree()
	var paused = tree.paused if tree else true
	if paused:
		return

	_maybe_refresh_group_target_cache(delta)
	# v6.6: 驱动相位仪主动能力（火炮连发/核子轰炸/酸雨持续）
	PhaseInstrumentAbilities.update(delta)

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

	# v6.6(剧情): 必败战倒计时 — 到时强制判负，玩家"撑过"指定时长后结束
	if _force_defeat:
		_force_defeat_timer -= delta
		if _force_defeat_timer <= 0.0:
			_force_defeat_timer = 0.0
			_force_defeat = false  # 防止 end_battle 内重复触发
			end_battle(false)  # 玩家基地被"梦魇/守护者"击穿
			return
	_check_win_lose()
	if PerformanceMetricsManager and PerformanceMetricsManager.has_method("sample_battle_frame"):
		PerformanceMetricsManager.sample_battle_frame(delta)


# =========================================================================
#  战斗流程
# =========================================================================

## v6.7: 计算并缓存玩家与敌方 boss 的相位师星级（1-7★）
## 玩家星级：用 MasterPlayerAssembler 从 PhaseInstrumentManager 装配 master dict
## 敌方星级：仅 boss 对战时算，直接用 _phase_master_config 喂评估器
## 任一计算失败均回落到 3★（基准=现状数值，向后兼容）
func _compute_and_cache_rank_stars() -> void:
	var player_stars: int = 3
	var enemy_stars: int = 3
	# 玩家星级
	if PhaseInstrumentManager != null:
		var pr: Dictionary = MasterPlayerAssembler.evaluate_player_stars(PhaseInstrumentManager)
		player_stars = int(pr.get("stars", 3))
	# 敌方 boss 星级（仅 boss 对战）
	if _is_phase_master_battle and not _phase_master_config.is_empty():
		var er: Dictionary = MasterPowerEvaluator.evaluate(_phase_master_config)
		enemy_stars = int(er.get("stars", 3))
	if PhaseInstrumentManager and PhaseInstrumentManager.has_method("set_player_rank_stars"):
		PhaseInstrumentManager.set_player_rank_stars(player_stars)
		PhaseInstrumentManager.set_enemy_rank_stars(enemy_stars)
	if DEBUG_BATTLE_LOG:
		push_warning("[v6.7] 相位师排名星级 — 玩家:%d★ / 敌方:%d★" % [player_stars, enemy_stars])

func start_battle(battle_scene: Node) -> void:
	if DEBUG_BATTLE_LOG:
		pass
		# [LOG-v5.1] print("[BattleManager] start_battle 被调用")
	battlefield = battle_scene

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
	_defeated_enemies.clear()  ## v6.0: reset defeated enemy tracking
	_group_target_cache_accum = _GROUP_TARGET_CACHE_INTERVAL_SEC

	# v6.6(剧情): 读取必败战配置（序章噩梦/守护者失败重试）
	_force_defeat = false
	_force_defeat_timer = 0.0
	if GameManager.has_method("is_force_defeat_battle") and GameManager.is_force_defeat_battle():
		_force_defeat = true
		var dur: float = 420.0
		if GameManager.has_method("get_force_defeat_duration"):
			dur = GameManager.get_force_defeat_duration()
		_force_defeat_timer = dur

	# 初始化刷新子系统
	_spawn_system.reset(battlefield, enemy_wave_interval, enemy_wave_total)
	if battlefield != null and battlefield.has_method("ensure_battle_slot_grid_ready"):
		battlefield.ensure_battle_slot_grid_ready()
	_spawn_system.configure_card_grid_battle(BattleSlotGrid.SLOT_COUNT)
	call_deferred("begin_card_grid_combat")
	player_units_node = _spawn_system.get_player_units_node()
	enemy_units_node = _spawn_system.get_enemy_units_node()
	_damage_system.set_player_units_node(player_units_node)

	# 如果是相位师对战，生成敌方相位场基地
	if _is_phase_master_battle and not _phase_master_config.is_empty():
		_spawn_enemy_phase_master_base()

	# 同步法则卡到 PhaseInstrumentManager
	if PhaseInstrumentManager.has_method("sync_law_cards_to_phase_law_manager"):
		PhaseInstrumentManager.sync_law_cards_to_phase_law_manager()

	# 初始化战斗能量
	energy_manager.start_battle()

	if SignalBus:
		SignalBus.battle_started.emit()
	if PerformanceMetricsManager and PerformanceMetricsManager.has_method("begin_battle_sampling"):
		PerformanceMetricsManager.begin_battle_sampling()
	# v6.6: 触发相位仪主动特殊能力（酸雨/能量罩等开局能力）
	PhaseInstrumentAbilities.on_battle_start(PhaseInstrumentManager, battle_scene)

	call_deferred("_deferred_refresh_card_grid_hud")


func end_battle(player_won: bool) -> void:
	if DEBUG_BATTLE_LOG:
		pass
		# [LOG-v5.1] print("[BattleManager] end_battle called, player_won: ", player_won)
	battle_active = false
	_card_grid_placement_active = false
	_card_grid_combat_started = false
	_clear_group_target_cache()
	# v6.6: 清空伤害数字节流表，flush 残留合并伤害并避免跨战斗残留
	CombatFeedback.reset_throttle()
	# v6.6: 重置相位仪主动能力状态
	PhaseInstrumentAbilities.reset_state()
	# v6.7: 清空相位师排名星级缓存（恢复 3★ 基准，避免影响下一场战斗）
	if PhaseInstrumentManager and PhaseInstrumentManager.has_method("clear_rank_cache"):
		PhaseInstrumentManager.clear_rank_cache()

	# 性能优化：清理空间分区系统
	_cleanup_spatial_grid()
	_cleanup_enemy_projectile_batch()
	_cleanup_player_projectile_batch()
	_cleanup_player_indirect_batch()
	_cleanup_enemy_indirect_batch()

	# 停止敌方相位驱动器
	if _enemy_phase_driver != null and is_instance_valid(_enemy_phase_driver):
		if _enemy_phase_driver.has_method("stop_production"):
			_enemy_phase_driver.stop_production()
		_enemy_phase_driver.queue_free()
	_enemy_phase_driver = null
	# 清理预览单位
	_spawn_system.clear_preview_units()
	# 结束能量系统
	energy_manager.end_battle()
	# 战斗胜利时奖励
	if player_won:
		_damage_system.try_grant_battle_affixes(phase_instrument)
		_battle_result = _damage_system.generate_battle_completion_drops(
			true,
			_battle_elapsed_time,
			_spawn_system.get_enemy_wave_total(),
			_spawn_system.get_enemy_wave_interval(),
			_spawn_system.get_max_player_units_deployed(),
			_spawn_system.get_player_units_lost()
		)
	# 清空节点引用，防止悬空指针
	player_units_node = null
	enemy_units_node = null
	# 清理战场单位
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
	if SignalBus:
		call_deferred("_emit_battle_ended", player_won)
	# 通知任务系统
	ManagerLazyLoader.ensure_loaded("quest")
	var qm = get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("notify_battle_result"):
		var stars: int = _battle_result.get("victory_stars", 0)
		qm.notify_battle_result(_battle_elapsed_time, stars, _spawn_system.get_enemy_wave_index())
	# 清理相位师战斗状态
	_phase_master_config = {}
	_is_phase_master_battle = false
	# v6.6(剧情): 清理必败战状态（防止跨战斗残留）
	_force_defeat = false
	_force_defeat_timer = 0.0


func _emit_battle_ended(player_won: bool) -> void:
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


func begin_card_grid_combat() -> void:
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

func _on_unit_died(unit: Node, is_player: bool) -> void:
	if not battle_active:
		return
	if not is_instance_valid(unit):
		return
	if is_player:
		_spawn_system.on_player_unit_died()
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
		## v6.5: 战力星级 — 击杀者累计被杀敌人的战力
		_record_battle_star_kill(unit)
	_check_win_lose()


## v6.5: 从被杀敌人获取击杀者，累计击溃战力到击杀者的卡牌
func _record_battle_star_kill(killed_unit: Node) -> void:
	if killed_unit == null or not is_instance_valid(killed_unit):
		return
	# 从 last_damage_source 获取击杀者（玩家单位）
	var killer: Node = null
	if "last_damage_source" in killed_unit:
		killer = killed_unit.get("last_damage_source")
	if killer == null or not is_instance_valid(killer):
		return
	# 取击杀者的卡牌ID
	var card_id: String = ""
	if "stats" in killer and killer.get("stats") != null:
		var killer_stats = killer.get("stats")
		if "platform_card_id" in killer_stats:
			card_id = String(killer_stats.platform_card_id)
	if card_id.is_empty():
		return
	# 计算被杀敌人的战力（与 enemy_unit.gd power_score 公式一致）
	var enemy_power: float = 50.0
	if "stats" in killed_unit and killed_unit.get("stats") != null:
		var estats = killed_unit.get("stats")
		# estats 是 UnitStats（Resource），直接用属性访问
		var e_hp: float = float(estats.max_hp)
		var e_range: float = float(estats.attack_range)
		var e_atk_l: float = float(estats.attack_light)
		var e_atk_a: float = float(estats.attack_armor)
		var e_atk_air: float = float(estats.attack_air)
		var e_interval: float = maxf(float(estats.attack_interval), 0.05)
		var dps_l: float = e_atk_l / e_interval if e_atk_l > 0.0 else 0.0
		var dps_a: float = e_atk_a / e_interval if e_atk_a > 0.0 else 0.0
		var dps_air: float = e_atk_air / e_interval if e_atk_air > 0.0 else 0.0
		var best_dps: float = maxf(dps_l, maxf(dps_a, dps_air))
		enemy_power = maxf(50.0, e_hp * 0.28 + best_dps * 2.2 + e_range * 0.22)
	else:
		# v6.6 修复：原 float(killed_unit.get("max_hp")) 在属性存在但值为 null 时
		# 触发 "Nonexistent 'float' constructor" 运行时错误（偶发，特定敌人被击杀时）。
		# get() 默认值仅在 key/属性不存在时生效，值为 null 时返回 null，float(null) 报错。
		var e_hp_raw: Variant = killed_unit.get("max_hp") if "max_hp" in killed_unit else null
		var e_hp_alt: float = float(e_hp_raw) if (e_hp_raw is float or e_hp_raw is int) else 100.0
		enemy_power = maxf(50.0, e_hp_alt * 0.28)
	BlueprintManager.add_battle_star_power(card_id, enemy_power)


func _check_win_lose() -> void:
	if not battle_active or battlefield == null:
		return

	# 相位师战斗：胜负由基地销毁信号驱动
	if _is_phase_master_battle:
		return

	# v6.6(剧情): 必败战 — 禁用玩家正常胜利路径，胜负完全由倒计时控制
	# 即使玩家清场，也不判胜；让波次持续刷敌，直到 _force_defeat_timer 归零
	if _force_defeat:
		return

	if not _card_grid_combat_started:
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
	# 战场范围: X(40-1240), Y(280-440)
	spatial_grid.setup(100.0, 40.0, 1240.0, 280.0, 440.0)

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
	var is_crit: bool = false
	if unit != null and is_instance_valid(unit) and unit.has_meta("_vfx_crit_pending"):
		unit.remove_meta("_vfx_crit_pending")
		is_crit = true
	CombatFeedback.show_damage(at_position, amount, unit, is_crit)


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
