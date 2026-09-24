extends RefCounted
class_name AFKModeManager
## 挂机模式管理器 — 自动重复战斗（本关循环 / 向前推进）
## 核心思路：通过 MainBattleSetup 启动战斗，拦截 SignalBus.battle_ended 信号实现自动推进
## 卡牌从 PhaseInstrumentManager 读取已装备卡牌
## v36 实机验收改版：选关槽位退役——CYCLE=本关（停靠关）循环；PUSH=从停靠关向前
## 逐关推进，关间插行进节拍（StageBanner + TRAVEL_SECONDS）。

const DT = preload("res://resources/design_tokens.gd")
const StageBanner = preload("res://scripts/ui/stage_banner.gd")


# ── 枚举 ──

## 挂机模式
enum Mode {
	CYCLE,    ## 循环模式：本关循环（v36：恒刷卡车停靠关，选关槽位已退役）
	PUSH      ## 推图模式：从停靠关向前逐关推进直到失败
}

## 挂机状态
enum State {
	IDLE,     ## 待机
	RUNNING,  ## 运行中
	FAILED,   ## 失败停止
	TRAVELING,  ## v36：两关之间行进中（战斗间隙的赶路节拍）
}


# ── 配置 ──

## v36 实机验收：关间行进时间——胜利后向下一关"驾驶赶路"的体感节拍（用户拍板：
## 不必十分严格，有感觉就好）。轻横幅播报 + 固定秒数；动效减弱档缩短。
const TRAVEL_SECONDS: float = 4.0
const TRAVEL_SECONDS_REDUCED: float = 1.2
const LEVEL_CAP: int = 100

var mode: Mode = Mode.CYCLE
var slots: Array[int] = [0, 0, 0, 0]  # 4个slot关联的关卡号，0=未关联
var current_slot_index: int = 0       # 循环模式下当前打到第几个slot
var push_level: int = 1               # 推图模式下的当前关卡
## 显式推图起点（一次性意图，不存档）。world_map"自动部署"入口设置：玩家可能故意
## 选低级关刷，起点须精确尊重；>0 时 start_afk 优先采用并清零，不与战役前沿取 max。
var push_start_override: int = 0

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
## 挂机结束（停止/失败）时 emit 累计奖励总账。
## v6.23d 记录6#7: 加 reason 透传停止原因——"sanity"=精神耗尽收工 / "failed"=战斗失败 /
## "cap"=推到关卡上限 / "manual"=手动停止。结算弹窗据此显示人话原因，
## 修"挂一关就结算，胜利也如此"（实为精神抽干，玩家不知情）。
## 注意：GDScript signal 声明不支持默认参数值，emit 处必须显式传 reason
signal afk_settled(rewards: Dictionary, reason: String)


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
## v6.23b: 每卡独立失败计数（card_id → 次数）——配合队列轮转，超限丢卡不丢队列
var _deploy_fail_counts: Dictionary = {}
## 玩家可用部署槽位范围：3行×3列 = 9 格全部可用（无边缘禁放，slot 0~8）
## 运行时读 BattleSlotGrid.SLOT_COUNT（避免 const 求值时全局类加载顺序问题）
const _PLAYER_SLOT_RANGE_START: int = 0
var _player_slot_range_end: int = -1  # 延迟到首次使用时初始化为 SLOT_COUNT - 1

# ── 推图失败重试（v6.6）──
## 推图模式同一关失败重试次数上限；耗尽才停止（消化偶发失败）
const PUSH_MAX_RETRIES: int = 3
## 当前推图关已重试次数（start_afk 时清零，_afk_failed 时清零）
var push_retry_count: int = 0

# ── v36 行进节拍 ──
## 行进代际号：stop/start 时 +1，使在途 timer 回调作废（防停止后仍进战斗）
var _travel_gen: int = 0


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
	# 注意：不在此处手动断开 SignalBus 连接。
	# PREDELETE 时 self 正在销毁，任何 Callable(self, ...) 的解析（含 is_connected/is_valid）
	# 都可能报 "Invalid access on null instance"。而 SignalBus 作为 autoload，其销毁时
	# 引擎会自动断开所有连接；RefCounted 引用归零销毁时，Callable 也会自然失效。
	# 故手动 disconnect 在 PREDELETE 阶段既不安全也不必要。
	pass


# ── 公开方法 ──

## 开始挂机
func start_afk() -> bool:
	if is_running:
		return false

	var lp = get_node_or_null("/root/LevelProgressManager")
	# v36：循环模式改为"本关循环"——不再要求选关槽位（UI 已退役），恒刷卡车停靠关
	if mode == Mode.CYCLE:
		var parked: int = _resolve_parked_level()
		if parked < 1:
			prints("[AFK-DIAG] start_afk FAIL: 循环模式无法解析停靠关 (current_level=%s)" %
				str(get_node_or_null("/root/GameManager") != null))
			return false

	# 推图模式：起始关 = push_level（持久化进度），覆盖三种续推场景：
	#   - 首次挂机：push_level=默认1 或读档恢复值
	#   - 失败续推：_afk_failed 已设 push_level=失败关-1（最高通关关），从该关重推
	#   - 停止续推：stop_afk 已设 push_level=当前推进关
	# world_map"自动部署"入口在调用 start_afk 前显式设 push_start_override=玩家选定关
	# （可能故意选低级关刷，精确尊重，不抬到前沿）。
	# current_level 由后续 enter_next_battle→set_current_level(_pending_level) 同步。
	if mode == Mode.PUSH:
		var start_lvl: int = push_level
		if push_start_override > 0:
			start_lvl = push_start_override
			push_start_override = 0
		elif lp != null and lp.has_method("get_max_unlocked_level"):
			# 推图起点跟随战役前沿：push_level 只被挂机自身回写，玩家手动推进的战役
			# 进度不会抬它——否则手动推到 50 关的玩家首次挂机推图会从第 1 关打起。
			# 取 max 对齐到最高解锁关（= 最高通关关 + 1，第一个未通关关）；挂机中途
			# 关游戏导致的 push_level 落后也经此自愈（AFK 胜利会推进 max_unlocked）。
			start_lvl = maxi(push_level, int(lp.get_max_unlocked_level()))
		if start_lvl < 1:
			start_lvl = 1
		# 钳制到已解锁上限：推图不应从玩家尚未解锁的关开始
		if lp != null and lp.has_method("get_max_unlocked_level"):
			var max_unlocked = lp.get_max_unlocked_level()
			if start_lvl > max_unlocked:
				start_lvl = max_unlocked
			if start_lvl < 1:
				start_lvl = 1
		# v26.19 停靠门控：挂机推图收敛到"停靠关"（卡车停哪打哪，战线推进靠手动行车+出击）。
		# 前沿跟随/续推/低关刷取等场景全部对齐停靠点；无 BunkerManager 时保持旧行为。
		var tb := get_node_or_null("/root/BunkerManager")
		if tb != null and tb.has_method("get_parked_level"):
			start_lvl = clampi(int(tb.get_parked_level()), 1, 100)
		push_level = start_lvl
	else:
		# v36：本关循环——slot 解锁校验退役（不再用 slots 起动）
		pass

	state = State.RUNNING
	is_running = true

	# 清空累计奖励与自动部署队列（新一轮挂机）
	accumulated_rewards.clear()
	_auto_deploy_pending.clear()
	_deploy_fail_streak = 0
	_deploy_fail_counts.clear()
	# 重置战斗等待标志：上一轮挂机若 battle_ended 未正常到达（战斗异常/手动中断），
	# _waiting_for_battle_end 残留 true 会让本次 enter_next_battle 被守卫 skip → 挂机不启动。
	_waiting_for_battle_end = false
	# v6.6: 重置推图重试计数（新会话从头开始计重试）
	push_retry_count = 0

	if mode == Mode.PUSH:
		_pending_level = push_level
	else:
		# v36：本关循环——恒从停靠关起步
		_pending_level = _resolve_parked_level()

	_travel_gen += 1   # 新一轮作废在途行进回调
	afk_started.emit()
	state_changed.emit(state)
	prints("[AFK-DIAG] start_afk OK: mode=%d _pending_level=%d" % [int(mode), _pending_level])
	return true


## 停止挂机（reason 透传给 afk_settled，见信号注释）
func stop_afk(reason: String = "manual") -> void:
	if not is_running:
		return

	_travel_gen += 1   # v36：作废在途行进回调（TRAVELING 态停止即断）
	# 保存进度
	if mode == Mode.PUSH:
		push_level = _pending_level
	else:
		current_slot_index = 0

	# 清理自动部署
	_auto_deploy_pending.clear()
	_deploy_fail_streak = 0
	_deploy_fail_counts.clear()

	# 先结算上一场尚未 claim 的掉落到累计池（若战斗刚结束）
	accumulate_pending_drops()

	state = State.IDLE
	is_running = false
	_pending_level = 0
	_waiting_for_battle_end = false

	afk_stopped.emit()
	afk_settled.emit(accumulated_rewards.duplicate(true), reason)
	state_changed.emit(state)

## v26.6：宿主场景销毁时调用——停机并断开 SignalBus 连接。
## RefCounted 无 _exit_tree；此前 Main 场景每次重建（战斗↔标题往返）都会 new 一个新实例，
## 旧实例被 SignalBus 连接引用永不释放（泄漏），且 is_running 残留时会继续响应
## battle_ended 驱动已释放的 _main。必须在 Main._exit_tree（实例仍存活时）显式调用。
func shutdown() -> void:
	stop_afk()
	if _signal_bus != null:
		if _signal_bus.battle_ended.is_connected(_on_battle_ended_from_bus):
			_signal_bus.battle_ended.disconnect(_on_battle_ended_from_bus)
		if _signal_bus.battle_started.is_connected(_on_battle_started_from_bus):
			_signal_bus.battle_started.disconnect(_on_battle_started_from_bus)


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
		"total_wins": total_wins,
		"total_losses": total_losses,
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
	# v7.x(统计存档): 恢复胜负计数，避免读档后面板显示 0/0 与累计奖励不一致
	total_wins = maxi(0, int(data.get("total_wins", 0)))
	total_losses = maxi(0, int(data.get("total_losses", 0)))


## 新游戏重置（由 SaveManager.start_new_game 经 Main 桥接调用）
func reset_progress() -> void:
	mode = Mode.CYCLE
	slots = [0, 0, 0, 0]
	push_level = 1
	push_start_override = 0
	push_retry_count = 0
	accumulated_rewards.clear()
	total_wins = 0
	total_losses = 0


# ── 进入下一场战斗 ──

## 进入下一场战斗（由外部调用或信号回调触发）
func enter_next_battle() -> void:
	if not is_running or _pending_level < 1:
		prints("[AFK-DIAG] enter_next_battle SKIP: is_running=%s _pending_level=%d" % [str(is_running), _pending_level])
		return

	# 防止重复启动
	if _waiting_for_battle_end:
		prints("[AFK-DIAG] enter_next_battle SKIP: _waiting_for_battle_end=true (上一场 battle_ended 未到)")
		return

	_waiting_for_battle_end = true
	
	# 设置关卡号到 GameManager
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("set_current_level"):
		gm.set_current_level(_pending_level)
	
	# 通过 MainBattleSetup 启动战斗（复用现有管线）
	if _battle_setup and _battle_setup.has_method("run_start_battle_sequence"):
		prints("[AFK-DIAG] enter_next_battle RUN: level=%d → run_start_battle_sequence()" % _pending_level)
		_battle_setup.run_start_battle_sequence()
	else:
		prints("[AFK-DIAG] enter_next_battle FAIL: _battle_setup=%s has_method=%s" % [str(_battle_setup != null), str(_battle_setup != null and _battle_setup.has_method("run_start_battle_sequence"))])


# ── 内部逻辑 ──

func _get_valid_slots() -> Array[int]:
	var result: Array[int] = []
	for i in range(4):
		if slots[i] > 0:
			result.append(slots[i])
	return result


## 返回已关联且已解锁的 slot 关卡列表（循环模式战斗推进专用）。
## lp 为 LevelProgressManager 节点；为 null 或缺 is_level_unlocked 方法时回退为不过滤（保持旧行为）。
## 注意：与 _get_valid_slots() 区分——后者仅过滤"已关联"（slots[i]>0），用于 UI 计数显示。
func _get_unlocked_valid_slots(lp: Node) -> Array[int]:
	var result: Array[int] = []
	if lp == null or not lp.has_method("is_level_unlocked"):
		# LevelProgressManager 不可用（测试/异常环境），退化为原始 _get_valid_slots，
		# 避免阻断挂机功能。正常运行时 lp 必然存在。
		return _get_valid_slots()
	for lvl in _get_valid_slots():
		if lp.is_level_unlocked(int(lvl)):
			result.append(lvl)
	return result


## 战斗结束信号回调 — 挂机核心循环
func _on_battle_ended_from_bus(player_won: bool) -> void:
	if not is_running:
		return

	_waiting_for_battle_end = false

	# v22.4（P1-4）：精神归零收工——BunkerManager 每场扣精神（胜-10/败-20），
	# 挂机连打会无声抽干精神且 main 侧无任何感知。此处归零即停机并提示回基地
	# 睡觉（睡觉 +20 且推进天数）；从未进过基地的玩家不受影响（manager 不存在）。
	if _bunker_sanity_exhausted():
		stop_afk("sanity")  # v6.23d 记录6#7: 原因透传，结算弹窗显示"精神耗尽收工"
		if SignalBus != null and SignalBus.has_signal("show_toast"):
			SignalBus.show_toast.emit("陈末的精神已经耗尽——挂机收工，回基地睡一觉（睡觉自动存档），顺手收一下房间里的战利品气泡")
		return

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

## 基地精神是否已归零（BunkerManager 不存在/未进过基地 → false，行为不变）
func _bunker_sanity_exhausted() -> bool:
	var root: Node = Engine.get_main_loop().root if Engine.get_main_loop() != null else null
	var bunker: Node = root.get_node_or_null("BunkerManager") if root != null else null
	if bunker == null or not bunker.has_method("get_sanity"):
		return false
	return bunker.get_sanity() <= 0.5


## 推进到下一关（仅在胜利时调用）。失败处理见 _on_battle_ended_from_bus。
## v36 实机验收改版：PUSH=向前推进（去掉 v26.19 钳制，胜利 +1，关间有行进节拍）；
## CYCLE=本关循环（_pending_level 不动）。
func _advance_to_next_level() -> void:
	# v7.x(防崩溃丢奖励): 此刻位于两场战斗之间（上一场 battle_ended 已发出，
	# 下一场尚未 start），battle_active=false，天然通过 SaveManager 的战斗守卫。
	# 触发存档把累计奖励/统计/进度落盘，避免崩溃丢失本轮挂机全部收益。
	_trigger_afk_save()
	if mode == Mode.PUSH:
		_pending_level += 1
		if _pending_level > LEVEL_CAP:
			stop_afk("cap")  # v6.23d 记录6#7: 到达关卡上限
			return
		# v6.23c: 推进即回写 push_level——原只在 start/stop/fail 时同步，挂机推到第 9 关
		# 战况卡仍显示"推图中 第6关"（主诉⑨）；顺带修复中途崩溃存档 push_level 落后。
		push_level = _pending_level
		# v36：关间行进节拍（横幅 + 赶路秒数），到点再进下一场
		_travel_then_enter()
		return
	# 循环模式：本关循环——直接进下一场（原 slot 轮换退役）
	call_deferred("_delayed_enter_battle")


## v36：关间行进——StageBanner 轻横幅（不挡操作，AFK 豁免体系不受影响）+ 固定秒数。
## TRAVELING 态可被 stop_afk/new game 打断（_travel_gen 代际守卫，过期回调静默作废）。
func _travel_then_enter() -> void:
	_travel_gen += 1
	var gen := _travel_gen
	state = State.TRAVELING
	state_changed.emit(state)
	StageBanner.post("车队向第 %d 关行进…" % _pending_level)
	var secs: float = TRAVEL_SECONDS_REDUCED if DT.is_motion_reduce() else TRAVEL_SECONDS
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_delayed_enter_battle()
		return
	tree.create_timer(secs).timeout.connect(func() -> void:
		if gen != _travel_gen or not is_running:
			return
		_delayed_enter_battle())


## v36：解析卡车停靠关（BunkerManager 缺失时回退 GameManager.current_level）
func _resolve_parked_level() -> int:
	var tb := get_node_or_null("/root/BunkerManager")
	if tb != null and tb.has_method("get_parked_level"):
		return clampi(int(tb.get_parked_level()), 1, LEVEL_CAP)
	var gm := get_node_or_null("/root/GameManager")
	if gm != null and "current_level" in gm:
		return clampi(int(gm.get("current_level")), 1, LEVEL_CAP)
	return 0


func _delayed_enter_battle() -> void:
	enter_next_battle()


func _afk_failed() -> void:
	# 清理自动部署
	_auto_deploy_pending.clear()
	_deploy_fail_streak = 0
	_deploy_fail_counts.clear()
	# v6.6: 推图模式失败时保存已通关最高关（= 失败关 - 1），修复"失败丢弃全部进度"bug。
	# 下次 start_afk 从该进度续推，而非从会话开始时的 push_level 重来。
	if mode == Mode.PUSH and _pending_level > 1:
		push_level = _pending_level - 1
	push_retry_count = 0
	# 失败前结算上一场尚未 claim 的掉落（game_manager 的 AFK 分支已处理 claim，
	# 但若失败场未走该分支，这里兜底快照累计）
	accumulate_pending_drops()
	# v7.x(防崩溃丢奖励): 失败停止前落盘，确保累计奖励/统计/推图进度不丢。
	# 此时 battle_active=false（失败场已结束），存档可通过守卫。
	_trigger_afk_save()
	state = State.FAILED
	is_running = false
	afk_failed.emit()
	afk_settled.emit(accumulated_rewards.duplicate(true), "failed")
	state_changed.emit(state)


# ── 累计奖励（M4 修复）──

## 将 DropManager 当前 pending_drops 快照累加到累计池。
## 由 game_manager.gd 的 AFK 分支在 claim_drops() 之前调用，确保奖励计入总账。
func accumulate_pending_drops() -> void:
	ManagerLazyLoader.ensure_loaded("drop")  # v7.x: DropManager 已改懒加载
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
	_deploy_fail_counts.clear()
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim and pim.has_method("get_loadouts"):
		var _ld: Array = pim.get_loadouts()
		prints("[AFK-DIAG] battle_started: get_loadouts()=%d 张可部署战斗卡 (green槽 COMBAT_UNIT)" % _ld.size())
		for loadout in _ld:
			var platform = loadout.get("platform")
			# platform 是 CardResource（Resource），其 card_id 为 String 属性，
			# 不可用 Dictionary 的 .get(key, default)；直接属性访问。
			if platform != null and "card_id" in platform and not String(platform.card_id).is_empty():
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
	# v8.1d: 统一门控——与 AutoDeployController 一致，用 BattleSpawnSystem 的
	# get_remaining_deployable_count 检查剩余配额，避免"slot 检查说有空位但
	# recount 说已满"的错位。
	var bss: Node = get_node_or_null("/root/BattleSpawnSystem")
	if bss != null and bss.has_method("get_remaining_deployable_count"):
		if bss.get_remaining_deployable_count() <= 0:
			_auto_deploy_pending.clear()
			_deploy_fail_streak = 0
			return
	if _auto_deploy_pending.is_empty():
		return
	var platform = _auto_deploy_pending[0]
	# platform 是 CardResource（Resource）。优先传 instance_id（铁律3：同名卡按
	# instance_id 精确匹配各自实例，避免 loadout 回退到"首个匹配"的错位实例），
	# 实例卡无 instance_id 时回退裸 card_id（兼容旧卡/测试卡）。
	var card_id: String = ""
	if "instance_id" in platform and not String(platform.instance_id).is_empty():
		card_id = String(platform.instance_id)
	elif "card_id" in platform:
		card_id = String(platform.card_id)
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
	# v6.23b: 走静默版——重试期间失败不弹 toast（主诉⑦"一直跳弹窗"）
	if bm.has_method("request_player_deploy_at_silent"):
		ok = bm.request_player_deploy_at_silent(card_id, pos)
	if ok:
		_auto_deploy_pending.pop_front()
		_deploy_fail_streak = 0
		_deploy_fail_counts.erase(card_id)
	else:
		# v6.23b: 部署失败改为**轮转**——队首卡挪到队尾试下一张，不再原地死磕
		#（原逻辑每 0.5s 重试同一张直到连败 20 次才放弃，期间每帧触发失败链）。
		# 每卡独立失败计数，超限（giveup 上限）直接丢弃该卡。
		var fails: int = int(_deploy_fail_counts.get(card_id, 0)) + 1
		_deploy_fail_counts[card_id] = fails
		_deploy_fail_streak += 1
		_auto_deploy_pending.pop_front()
		if fails > _AUTO_DEPLOY_FAIL_GIVEUP:
			_deploy_fail_counts.erase(card_id)  # 彻底放弃该卡
		else:
			_auto_deploy_pending.push_back(platform)  # 挪队尾，先试别的卡


## 返回玩家可用槽位末端索引（延迟初始化，避免 const 求值时全局类加载顺序问题）
func _get_player_slot_range_end() -> int:
	if _player_slot_range_end < 0:
		_player_slot_range_end = BattleSlotGrid.SLOT_COUNT - 1
	return _player_slot_range_end

## 遍历玩家可用槽位 0..SLOT_COUNT-1，返回第一个空槽的世界坐标；全占用返回 Vector2.INF
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
	for si in range(_PLAYER_SLOT_RANGE_START, _get_player_slot_range_end() + 1):
		var occupied: bool = false
		if grid.has_method("is_player_slot_occupied") and player_units != null:
			occupied = grid.is_player_slot_occupied(si, player_units)
		if not occupied:
			return bf.get_card_grid_player_slot_global(si)
	return Vector2.INF


## v7.x(防崩溃丢奖励): 在两场战斗之间触发一次存档，把累计奖励/统计/进度落盘。
## 调用时机由调用方保证为"上一场已结束、下一场未开始"（battle_active=false），
## 故天然通过 SaveManager 的战斗守卫，无需特殊绕过。null 安全：SaveManager 不可
## 用时静默跳过（不影响挂机主流程）。
func _trigger_afk_save() -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("save_game"):
		sm.save_game()


## 获取节点辅助
func get_node_or_null(path: String) -> Node:
	if _main:
		return _main.get_node_or_null(path)
	return null
