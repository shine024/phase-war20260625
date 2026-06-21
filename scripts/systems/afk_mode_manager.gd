extends RefCounted
class_name AFKModeManager
## 挂机模式管理器 — 自动重复战斗（循环 / 推图）
## 核心思路：通过 MainBattleSetup 启动战斗，拦截 SignalBus.battle_ended 信号实现自动推进
## 卡牌从 PhaseInstrumentManager 读取已装备卡牌


# ── 枚举 ──

## 挂机模式
enum Mode {
	CYCLE,    ## 循环模式：按slot顺序循环
	PUSH      ## 推图模式：逐关推进直到失败
}

## 挂机状态
enum State {
	IDLE,     ## 待机
	RUNNING,  ## 运行中
	FAILED,   ## 失败停止
}


# ── 配置 ──

var mode: Mode = Mode.CYCLE
var slots: Array[int] = [0, 0, 0, 0]  # 4个slot关联的关卡号，0=未关联
var current_slot_index: int = 0       # 循环模式下当前打到第几个slot
var push_level: int = 1               # 推图模式下的当前关卡

## 状态
var state: State = State.IDLE
var is_running: bool = false

## 统计
var total_wins: int = 0
var total_losses: int = 0
## 累计奖励（按掉落 item_id 聚合，停止时一次性结算显示）
var accumulated_rewards: Dictionary = {}


# ── 信号 ──

signal afk_started
signal afk_stopped
signal afk_failed
signal level_completed(level: int, won: bool)
signal state_changed(new_state: State)
## 挂机结束（停止/失败）时 emit 累计奖励总账
signal afk_settled(rewards: Dictionary)


# ── 内部引用 ──

var _signal_bus: SignalBus = null
var _main: Node = null
var _battle_setup: MainBattleSetup = null
var _pending_level: int = 0
var _waiting_for_battle_end: bool = false

# ── 自动部署（C2 修复）──
# 每次 battle_started 后从 PhaseInstrumentManager.get_loadouts() 读取已装备卡牌，
# 按 _auto_deploy_interval 分时部署（每次部署消耗能量，不能一次性铺满）
var _auto_deploy_pending: Array = []   # 待部署的 platform CardResource 列表
var _auto_deploy_timer: float = 0.0
var _auto_deploy_interval: float = 0.5  # 每0.5秒部署一张（设计文档5.2节）
const _AUTO_DEPLOY_INITIAL_DELAY: float = 0.3  # 战斗开始后延迟0.3秒再开始部署
const _AUTO_DEPLOY_FAIL_GIVEUP: int = 20       # 单张连续失败次数上限，超过则放弃该张避免死循环
var _deploy_fail_streak: int = 0
## 玩家可用部署槽位范围：slot 1..6（slot 0 为屏幕边缘禁放位）
const _PLAYER_SLOT_RANGE_START: int = 1
const _PLAYER_SLOT_RANGE_END: int = 6

# ── 推图失败重试（v6.6）──
## 推图模式同一关失败重试次数上限；耗尽才停止（消化偶发失败）
const PUSH_MAX_RETRIES: int = 3
## 当前推图关已重试次数（start_afk 时清零，_afk_failed 时清零）
var push_retry_count: int = 0


# ── 初始化 ──

func init(main_node: Node, battle_setup: MainBattleSetup) -> void:
	_main = main_node
	_battle_setup = battle_setup
	_signal_bus = SignalBus

	# 连接 battle_ended 信号（挂机核心循环：拦截战斗结果推进下一关）
	if not _signal_bus.battle_ended.is_connected(_on_battle_ended_from_bus):
		_signal_bus.battle_ended.connect(_on_battle_ended_from_bus)
	# 连接 battle_started 信号（C2：战斗开始后排入自动部署队列）
	if not _signal_bus.battle_started.is_connected(_on_battle_started_from_bus):
		_signal_bus.battle_started.connect(_on_battle_started_from_bus)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _signal_bus:
			if _signal_bus.battle_ended.is_connected(_on_battle_ended_from_bus):
				_signal_bus.battle_ended.disconnect(_on_battle_ended_from_bus)
			if _signal_bus.battle_started.is_connected(_on_battle_started_from_bus):
				_signal_bus.battle_started.disconnect(_on_battle_started_from_bus)


# ── 公开方法 ──

## 开始挂机
func start_afk() -> bool:
	if is_running:
		return false
	
	var valid = _get_valid_slots()
	if valid.is_empty():
		return false
	
	# 推图模式：检查当前关卡是否已解锁
	if mode == Mode.PUSH:
		var lp = get_node_or_null("/root/LevelProgressManager")
		if lp and lp.has_method("get_max_unlocked_level"):
			var max_unlocked = lp.get_max_unlocked_level()
			if push_level > max_unlocked:
				push_level = max_unlocked
			if push_level < 1:
				push_level = 1
	
	state = State.RUNNING
	is_running = true

	# 清空累计奖励与自动部署队列（新一轮挂机）
	accumulated_rewards.clear()
	_auto_deploy_pending.clear()
	_deploy_fail_streak = 0
	# v6.6: 重置推图重试计数（新会话从头开始计重试）
	push_retry_count = 0

	if mode == Mode.PUSH:
		_pending_level = push_level
	else:
		current_slot_index = 0
		_pending_level = slots[current_slot_index] if current_slot_index < slots.size() else 0

	afk_started.emit()
	state_changed.emit(state)
	return true


## 停止挂机
func stop_afk() -> void:
	if not is_running:
		return

	# 保存进度
	if mode == Mode.PUSH:
		push_level = _pending_level
	else:
		current_slot_index = 0

	# 清理自动部署
	_auto_deploy_pending.clear()
	_deploy_fail_streak = 0

	# 先结算上一场尚未 claim 的掉落到累计池（若战斗刚结束）
	accumulate_pending_drops()

	state = State.IDLE
	is_running = false
	_pending_level = 0
	_waiting_for_battle_end = false

	afk_stopped.emit()
	afk_settled.emit(accumulated_rewards.duplicate(true))
	state_changed.emit(state)


## 设置模式
func set_mode(m: Mode) -> void:
	if is_running:
		return
	mode = m


## 设置slot关卡
func set_slot(slot_index: int, level: int) -> void:
	if is_running or slot_index < 0 or slot_index > 3:
		return
	slots[slot_index] = level


## 获取有效slot数量
func get_valid_slot_count() -> int:
	return _get_valid_slots().size()


## 获取有效slot关卡列表
func get_active_slots() -> Array[int]:
	return _get_valid_slots()


## 获取slot关联的关卡号（用于UI显示）
func get_slot_level(slot_index: int) -> int:
	if slot_index < 0 or slot_index > 3:
		return 0
	return slots[slot_index]


## 重置统计
func reset_stats() -> void:
	total_wins = 0
	total_losses = 0


# ── 存档（v6.6）──

## 保存挂机状态（配置/进度/累计奖励池）。由 SaveManager 经 Main 桥接调用。
## 不存 is_running/state（读档后保持 IDLE，不自动恢复运行）。
func save_state() -> Dictionary:
	return {
		"_version": 1,
		"mode": int(mode),
		"slots": slots.duplicate(),
		"push_level": push_level,
		"accumulated_rewards": accumulated_rewards.duplicate(true),
	}


## 加载挂机状态。旧 save 无此键时 data 为空字典，保持默认值。
func load_state(data: Dictionary) -> void:
	if data.is_empty():
		return   # 旧档无此键，保持默认（CYCLE / slots=[0,0,0,0] / push_level=1）
	# mode：0=CYCLE, 1=PUSH；防御性 clamp，越界回退 CYCLE
	var m: int = int(data.get("mode", 0))
	if m == int(Mode.PUSH):
		mode = Mode.PUSH
	else:
		mode = Mode.CYCLE
	# slots：逐个读取，缺失补 0
	var loaded_slots: Array = data.get("slots", [0, 0, 0, 0])
	for i in range(min(4, loaded_slots.size())):
		slots[i] = int(loaded_slots[i])
	# push_level
	push_level = max(1, int(data.get("push_level", 1)))
	# accumulated_rewards：读档恢复累计池（不自动恢复运行，玩家可手动开始挂机继续累积）
	var loaded_rewards: Variant = data.get("accumulated_rewards", {})
	if loaded_rewards is Dictionary:
		accumulated_rewards = (loaded_rewards as Dictionary).duplicate(true)


## 新游戏重置（由 SaveManager.start_new_game 经 Main 桥接调用）
func reset_progress() -> void:
	mode = Mode.CYCLE
	slots = [0, 0, 0, 0]
	push_level = 1
	push_retry_count = 0
	accumulated_rewards.clear()
	total_wins = 0
	total_losses = 0


# ── 进入下一场战斗 ──

## 进入下一场战斗（由外部调用或信号回调触发）
func enter_next_battle() -> void:
	if not is_running or _pending_level < 1:
		return
	
	# 防止重复启动
	if _waiting_for_battle_end:
		return
	
	_waiting_for_battle_end = true
	
	# 设置关卡号到 GameManager
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("set_current_level"):
		gm.set_current_level(_pending_level)
	
	# 通过 MainBattleSetup 启动战斗（复用现有管线）
	if _battle_setup and _battle_setup.has_method("run_start_battle_sequence"):
		_battle_setup.run_start_battle_sequence()


# ── 内部逻辑 ──

func _get_valid_slots() -> Array[int]:
	var result: Array[int] = []
	for i in range(4):
		if slots[i] > 0:
			result.append(slots[i])
	return result


## 战斗结束信号回调 — 挂机核心循环
func _on_battle_ended_from_bus(player_won: bool) -> void:
	if not is_running:
		return

	_waiting_for_battle_end = false

	if player_won:
		total_wins += 1
		# 胜利清零推图重试计数（过了这关，下关重新计重试）
		push_retry_count = 0
		level_completed.emit(_pending_level, true)
		_advance_to_next_level()
	else:
		total_losses += 1
		level_completed.emit(_pending_level, false)
		# v6.6: 推图模式失败重试——同一关重试 PUSH_MAX_RETRIES 次，耗尽才停止。
		# 循环模式失败即停（符合设计：刷已能稳定通关的关卡）。
		if mode == Mode.PUSH and push_retry_count < PUSH_MAX_RETRIES:
			push_retry_count += 1
			# 重试同一关：_pending_level 不变，直接延迟进入下一场战斗
			call_deferred("_delayed_enter_battle")
		else:
			_afk_failed()


## 推进到下一关（仅在胜利时调用）。失败处理见 _on_battle_ended_from_bus。
func _advance_to_next_level() -> void:
	if mode == Mode.PUSH:
		_pending_level += 1
		if _pending_level > 100:
			stop_afk()
			return
	else:
		# 循环模式
		var valid = _get_valid_slots()
		current_slot_index += 1
		if current_slot_index >= valid.size():
			current_slot_index = 0
		if valid.is_empty():
			stop_afk()
			return
		_pending_level = valid[current_slot_index]

	# 延迟一帧进入下一关，确保当前战斗完全清理
	# 使用 call_deferred 确保 battle_ended 信号完全处理后再启动下一场
	call_deferred("_delayed_enter_battle")


func _delayed_enter_battle() -> void:
	enter_next_battle()


func _afk_failed() -> void:
	# 清理自动部署
	_auto_deploy_pending.clear()
	_deploy_fail_streak = 0
	# v6.6: 推图模式失败时保存已通关最高关（= 失败关 - 1），修复"失败丢弃全部进度"bug。
	# 下次 start_afk 从该进度续推，而非从会话开始时的 push_level 重来。
	if mode == Mode.PUSH and _pending_level > 1:
		push_level = _pending_level - 1
	push_retry_count = 0
	# 失败前结算上一场尚未 claim 的掉落（game_manager 的 AFK 分支已处理 claim，
	# 但若失败场未走该分支，这里兜底快照累计）
	accumulate_pending_drops()
	state = State.FAILED
	is_running = false
	afk_failed.emit()
	afk_settled.emit(accumulated_rewards.duplicate(true))
	state_changed.emit(state)


# ── 累计奖励（M4 修复）──

## 将 DropManager 当前 pending_drops 快照累加到累计池。
## 由 game_manager.gd 的 AFK 分支在 claim_drops() 之前调用，确保奖励计入总账。
func accumulate_pending_drops() -> void:
	var dm: Node = get_node_or_null("/root/DropManager")
	if dm == null or not dm.has_method("get_pending_drops"):
		return
	for drop in dm.get_pending_drops():
		# drop 是 DropTables.DropResult（自定义 RefCounted 子类，非 Dictionary）：
		#   .drop -> DropEntry（含 .item_id/.type），.count -> int
		# 这些字段在 _init 中必设，直接属性访问即可。
		var item_id: String = ""
		if drop.drop != null:
			item_id = String(drop.drop.item_id)
		var key: String = item_id if not item_id.is_empty() else "other"
		accumulated_rewards[key] = int(accumulated_rewards.get(key, 0)) + int(drop.count)


# ── 自动部署（C2 修复）──

## 战斗开始信号回调：读取已装备卡牌排入自动部署队列
func _on_battle_started_from_bus() -> void:
	if not is_running:
		return
	_auto_deploy_pending.clear()
	_deploy_fail_streak = 0
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim and pim.has_method("get_loadouts"):
		for loadout in pim.get_loadouts():
			var platform = loadout.get("platform")
			if platform != null and platform.get("card_id") != null:
				_auto_deploy_pending.append(platform)
	# 战斗开始后延迟一小段时间再开始部署，等能量/战场稳定
	_auto_deploy_timer = _AUTO_DEPLOY_INITIAL_DELAY


## 每帧推进自动部署（由 main.gd 的 _process 转发调用）
## RefCounted 无 _process 自动回调，故由外部驱动
func process_auto_deploy(delta: float) -> void:
	if not is_running or _auto_deploy_pending.is_empty():
		return
	_auto_deploy_timer -= delta
	if _auto_deploy_timer > 0.0:
		return
	_auto_deploy_timer = _auto_deploy_interval
	_deploy_next_from_queue()


## 部署队列里的下一张卡到第一个空槽
func _deploy_next_from_queue() -> void:
	if _auto_deploy_pending.is_empty():
		return
	var platform = _auto_deploy_pending[0]
	var card_id: String = String(platform.get("card_id", ""))
	if card_id.is_empty():
		_auto_deploy_pending.pop_front()
		return
	var bm: Node = get_node_or_null("/root/BattleManager")
	if bm == null or not bool(bm.get("battle_active")):
		return  # 战斗已结束或未就绪，下一帧重试
	var bf: Node2D = null
	if _main != null and _main.has_method("_get_battlefield"):
		bf = _main._get_battlefield()
	if bf == null:
		return
	var pos: Vector2 = _find_free_slot_world_pos(bf)
	if pos == Vector2.INF:
		# 没有空槽了，清空队列
		_auto_deploy_pending.clear()
		_deploy_fail_streak = 0
		return
	var ok: bool = false
	if bm.has_method("request_player_deploy_at"):
		ok = bm.request_player_deploy_at(card_id, pos)
	if ok:
		_auto_deploy_pending.pop_front()
		_deploy_fail_streak = 0
	else:
		# 部署失败（多为能量不足）—— 队列不清空，下一帧再试
		_deploy_fail_streak += 1
		if _deploy_fail_streak > _AUTO_DEPLOY_FAIL_GIVEUP:
			_auto_deploy_pending.pop_front()
			_deploy_fail_streak = 0


## 遍历玩家可用槽位 1..6，返回第一个空槽的世界坐标；全占用返回 Vector2.INF
func _find_free_slot_world_pos(bf: Node2D) -> Vector2:
	if bf == null or not bf.has_method("get_card_grid_player_slot_global"):
		return Vector2.INF
	var grid: Node = null
	if bf.has_method("ensure_battle_slot_grid_ready"):
		grid = bf.ensure_battle_slot_grid_ready()
	if grid == null:
		grid = bf.get_node_or_null("BattleSlotGrid")
	if grid == null:
		return Vector2.INF
	var player_units: Node2D = null
	if bf.has_method("get_player_units_node"):
		player_units = bf.get_player_units_node()
	if player_units == null:
		player_units = bf.get_node_or_null("PlayerUnits")
	for si in range(_PLAYER_SLOT_RANGE_START, _PLAYER_SLOT_RANGE_END + 1):
		var occupied: bool = false
		if grid.has_method("is_player_slot_occupied") and player_units != null:
			occupied = grid.is_player_slot_occupied(si, player_units)
		if not occupied:
			return bf.get_card_grid_player_slot_global(si)
	return Vector2.INF


## 获取节点辅助
func get_node_or_null(path: String) -> Node:
	if _main:
		return _main.get_node_or_null(path)
	return null
