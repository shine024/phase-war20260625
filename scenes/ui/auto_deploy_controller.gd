extends RefCounted
class_name AutoDeployController
## 战斗内自动部署控制器 — 从左到右自动铺满战斗卡，单位死亡后立即补部署
##
## 设计要点（复用 AFK 模式验证过的部署模式）：
##   - 找空槽：遍历玩家槽位 1..6，取第一个空位（从左到右铺满）
##   - 部署：BattleManager.request_player_deploy_at(card_id, pos)
##   - instance_id 优先（遵守铁律3：同名多实例卡精确匹配各自实例）
##   - 能量等待：能量不足时卡留在队列，间隔后重试，等回能后自动铺
##   - 仅当前战斗：battle_ended 自动 disable，下场战斗需重新开启
##   - 死亡补阵：监听 unit_died(is_player=true)，死亡后立即重新填充部署队列

const GC = preload("res://resources/game_constants.gd")


# ── 信号 ──

signal state_changed(enabled: bool)


# ── 常量 ──

## 部署间隔（秒）：能量充足时每 0.4 秒部署一张，避免一次性铺满导致时序问题
const DEPLOY_INTERVAL: float = 0.4
## 战斗开始后初始延迟（秒）：等能量/战场稳定
const INITIAL_DELAY: float = 0.3
## 单张连续失败次数上限：超过则放弃该张（防死循环，如该卡能量永远不够）
const FAIL_GIVEUP: int = 20
## 玩家可用部署槽位范围：slot 1..6（slot 0 为屏幕边缘禁放位）
const SLOT_RANGE_START: int = 1
const SLOT_RANGE_END: int = 6


# ── 状态 ──

var _enabled: bool = false
var _battle_active: bool = false

## 待部署的 platform CardResource 列表（从左到右顺序）
var _deploy_queue: Array = []
## 部署计时器
var _deploy_timer: float = 0.0
## 单卡连续失败计数
var _fail_streak: int = 0
## 主场景引用（定位 Battlefield）
var _main: Node = null


# ── 初始化 ──

func setup(main_node: Node) -> void:
	_main = main_node
	_connect_signals()


func _connect_signals() -> void:
	var sb: Node = _get_node("/root/SignalBus")
	if sb == null:
		return
	# 战斗结束 → 自动关闭（仅当前战斗生效）
	if sb.has_signal("battle_ended") and not sb.battle_ended.is_connected(_on_battle_ended):
		sb.battle_ended.connect(_on_battle_ended)
	# 战斗开始 → 若已开启则启动铺满
	if sb.has_signal("battle_started") and not sb.battle_started.is_connected(_on_battle_started):
		sb.battle_started.connect(_on_battle_started)
	# 单位死亡 → 立即补部署（核心：死亡补阵）
	if sb.has_signal("unit_died") and not sb.unit_died.is_connected(_on_unit_died):
		sb.unit_died.connect(_on_unit_died)


# ── 公开方法 ──

## 启用自动部署。仅在战斗中生效；非战斗态调用会被记录但等战斗开始才铺。
func enable() -> void:
	if _enabled:
		return
	_enabled = true
	_fail_streak = 0
	_deploy_queue.clear()
	state_changed.emit(true)
	# 若已在战斗中，立即启动一轮铺满
	if _battle_active:
		_start_deploy_round()


## 关闭自动部署
func disable() -> void:
	if not _enabled:
		return
	_enabled = false
	_deploy_queue.clear()
	_fail_streak = 0
	state_changed.emit(false)


func is_enabled() -> bool:
	return _enabled


# ── 信号回调 ──

func _on_battle_started() -> void:
	_battle_active = true
	if _enabled:
		# 战斗开始：重置队列 + 初始延迟后开始铺
		_deploy_queue.clear()
		_fail_streak = 0
		_deploy_timer = INITIAL_DELAY
		_start_deploy_round()


func _on_battle_ended(_won: bool) -> void:
	_battle_active = false
	# 仅当前战斗生效：战斗结束自动关闭
	if _enabled:
		disable()


func _on_unit_died(_unit: Node, is_player: bool) -> void:
	# 只关心玩家单位死亡 → 触发补部署
	if not is_player:
		return
	if not _enabled or not _battle_active:
		return
	# 死亡后立即重新填充部署队列（若队列已空才填，避免重复堆叠）
	if _deploy_queue.is_empty():
		_start_deploy_round()
		_deploy_timer = DEPLOY_INTERVAL  # 短暂延迟后开始补


# ── 每帧驱动（由 bottom_instrument_bar._process 转发）──

func process(delta: float) -> void:
	if not _enabled or not _battle_active:
		return
	if _deploy_queue.is_empty():
		return
	_deploy_timer -= delta
	if _deploy_timer > 0.0:
		return
	_deploy_timer = DEPLOY_INTERVAL
	_deploy_next()


# ── 核心逻辑 ──

## 收集装备的战斗卡，填充部署队列（从左到右 = get_loadouts 返回顺序）
func _start_deploy_round() -> void:
	var pim: Node = _get_node("/root/PhaseInstrumentManager")
	if pim == null or not pim.has_method("get_loadouts"):
		return
	var loadouts: Array = pim.get_loadouts()
	var cards: Array = []
	for loadout in loadouts:
		var platform = loadout.get("platform")
		# platform 是 CardResource（Resource），card_id 是 String 属性。
		if platform == null:
			continue
		if not ("card_id" in platform) or String(platform.card_id).is_empty():
			continue
		# 仅战斗单位卡可部署（过滤能量卡/法则卡）
		if "card_type" in platform and int(platform.card_type) != GC.CardType.COMBAT_UNIT:
			continue
		cards.append(platform)
	if cards.is_empty():
		return
	_deploy_queue = cards


## 部署队列里的下一张卡到第一个空槽（从左到右）
func _deploy_next() -> void:
	if _deploy_queue.is_empty():
		return
	var bm: Node = _get_node("/root/BattleManager")
	if bm == null or not bool(bm.get("battle_active")):
		return  # 战斗已结束，下一帧重试
	var bf: Node2D = _get_battlefield()
	if bf == null:
		return
	# 找第一个空槽（从左到右）
	var pos: Vector2 = _find_free_slot_world_pos(bf)
	if pos == Vector2.INF:
		# 没有空槽了 → 铺满了，清空队列等死亡补阵
		_deploy_queue.clear()
		_fail_streak = 0
		return
	var platform = _deploy_queue[0]
	# instance_id 优先（铁律3：同名卡按 instance_id 精确匹配各自实例）
	var card_id: String = ""
	if "instance_id" in platform and not String(platform.instance_id).is_empty():
		card_id = String(platform.instance_id)
	elif "card_id" in platform:
		card_id = String(platform.card_id)
	if card_id.is_empty():
		_deploy_queue.pop_front()
		return
	var ok: bool = false
	if bm.has_method("request_player_deploy_at"):
		ok = bm.request_player_deploy_at(card_id, pos)
	if ok:
		_deploy_queue.pop_front()
		_fail_streak = 0
	else:
		# 部署失败（多为能量不足）—— 队列不清空，下次重试
		_fail_streak += 1
		if _fail_streak > FAIL_GIVEUP:
			_deploy_queue.pop_front()
			_fail_streak = 0


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
	for si in range(SLOT_RANGE_START, SLOT_RANGE_END + 1):
		var occupied: bool = false
		if grid.has_method("is_player_slot_occupied") and player_units != null:
			occupied = grid.is_player_slot_occupied(si, player_units)
		if not occupied:
			return bf.get_card_grid_player_slot_global(si)
	return Vector2.INF


func _get_battlefield() -> Node2D:
	if _main != null and _main.has_method("_get_battlefield"):
		return _main._get_battlefield()
	# 回退：直接查节点路径
	if _main != null:
		return _main.get_node_or_null("BattleContainer/SubViewportContainer/SubViewport/Battlefield") as Node2D
	return null


func _get_node(path: String) -> Node:
	if _main != null:
		return _main.get_node_or_null(path)
	return null
