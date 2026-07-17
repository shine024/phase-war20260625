extends RefCounted
class_name AutoDeployController
## 战斗内自动部署控制器 — 绿槽索引固定映射到战场位，单位死亡后补对应位
##
## v7.x 固定映射设计：
##   - 绿槽 0 → 战场位 1，绿槽 1 → 战场位 2，... 绿槽 N-1 → 战场位 N
##   - 某战场位单位死亡 → 自动补该位对应的绿槽卡
##   - 绿槽未装卡 → 对应战场位永远空着
##   - instance_id 优先（遵守铁律3：同名多实例卡精确匹配各自实例）
##   - 能量不足时卡留在队列，间隔后重试，等回能后自动铺
##   - 仅当前战斗：battle_ended 自动 disable，下场战斗需重新开启

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
## 绿槽索引 → 战场位的偏移量（绿槽0→位1, 绿槽1→位2, ...）
const SLOT_INDEX_OFFSET: int = 1


# ── 状态 ──

var _enabled: bool = false
var _battle_active: bool = false

## 待部署条目列表，每项 = {platform: CardResource, slot_index: int}
var _deploy_queue: Array = []
## 部署计时器
var _deploy_timer: float = 0.0
## 单卡连续失败计数
var _fail_streak: int = 0
## v8.1c: 槽位补阵冷却——记录每个槽位上次成功部署的时间戳，防止单位秒死后
## 陷入"死亡→立即补→又秒死→又补"的死循环（烧能量无意义）。
## key=slot_index, value=部署时的 Time.get_ticks_msec()
var _slot_deploy_time: Dictionary = {}
## v8.1c: 补阵冷却秒数：某槽位刚部署的单位若很快死亡，冷却期内不重复补该位
const REPLOY_COOLDOWN_SEC: float = 3.0
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
	_slot_deploy_time.clear()  # v8.1c: 清理跨战斗冷却残留
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
	# v7.x: 死亡后始终重新收集队列，确保补阵能感知当前战场状态
	# （哪些实例已在场上、哪些卡槽已空出）
	_deploy_queue.clear()
	_fail_streak = 0
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

## 收集装备的战斗卡，填充部署队列（保留绿槽索引用于固定映射）
## v7.x: 过滤掉已在战场上存活的卡（不管它在哪个位置），避免手动+自动混用时报错
## v8.1d: 先用 get_remaining_deployable_count 做快速门控——与 request_player_deploy
##         的 live_count 检查口径一致，杜绝"slot 检查说有空位但 recount 说已满"的错位。
func _start_deploy_round() -> void:
	# v8.1d: 快速门控——如果BattleSpawnSystem认为已无部署余量，直接清队
	var bss: Node = _get_node("/root/BattleSpawnSystem")
	if bss != null and bss.has_method("get_remaining_deployable_count"):
		var remaining: int = bss.get_remaining_deployable_count()
		if remaining <= 0:
			_deploy_queue.clear()
			return
	var pim: Node = _get_node("/root/PhaseInstrumentManager")
	if pim == null or not pim.has_method("get_loadouts"):
		return
	var loadouts: Array = pim.get_loadouts()
	# v8.1b: 存活过滤改为按"槽位对应的战场位是否已占用"判断，而非按卡 id。
	# 原按 instance_id/card_id 过滤会误杀"同一实例装多槽"的第二张（用户把同一张卡放两个槽
	# 想部署两个单位，或游戏开局送的同名卡被装多槽）。固定映射下每个绿槽有独立战场位，
	# _deploy_next 的 is_player_slot_occupied 已能精确判断该位是否需要补。
	var bf: Node2D = _get_battlefield()
	var grid: Node = null
	if bf != null:
		if bf.has_method("ensure_battle_slot_grid_ready"):
			grid = bf.ensure_battle_slot_grid_ready()
		if grid == null:
			grid = bf.get_node_or_null("BattleSlotGrid")
	var player_units: Node2D = null
	if bf != null:
		if bf.has_method("get_player_units_node"):
			player_units = bf.get_player_units_node()
		if player_units == null:
			player_units = bf.get_node_or_null("PlayerUnits")
	var entries: Array = []
	for loadout in loadouts:
		var platform = loadout.get("platform")
		if platform == null:
			continue
		if not ("card_id" in platform) or String(platform.card_id).is_empty():
			continue
		# 仅战斗单位卡可部署（过滤能量卡/法则卡）
		if "card_type" in platform and int(platform.card_type) != GC.CardType.COMBAT_UNIT:
			continue
		var slot_index: int = int(loadout.get("slot_index", 0))
		# v8.1b: 该槽位对应的战场位已被占用 → 跳过（该位已有单位，无需补）
		var battlefield_slot: int = slot_index + SLOT_INDEX_OFFSET
		if grid != null and player_units != null and grid.has_method("is_player_slot_occupied"):
			if grid.is_player_slot_occupied(battlefield_slot, player_units):
				continue
		# v8.1c: 补阵冷却——该槽位刚部署的单位若很快死亡（秒死），冷却期内不重复补，
		# 避免"死亡→立即补→又秒死→又补"的死循环（烧能量无意义）。
		if _slot_deploy_time.has(slot_index):
			var elapsed_sec: float = (Time.get_ticks_msec() - float(_slot_deploy_time[slot_index])) / 1000.0
			if elapsed_sec < REPLOY_COOLDOWN_SEC:
				continue
		entries.append({"platform": platform, "slot_index": slot_index})
	if entries.is_empty():
		return
	_deploy_queue = entries


## 收集当前战场上所有存活玩家单位的卡 ID（instance_id 优先，回退 card_id）
func _collect_alive_card_ids() -> Array:
	var ids: Array = []
	var bf: Node2D = _get_battlefield()
	if bf == null:
		return ids
	var player_units: Node2D = null
	if bf.has_method("get_player_units_node"):
		player_units = bf.get_player_units_node()
	if player_units == null:
		player_units = bf.get_node_or_null("PlayerUnits")
	if player_units == null:
		return ids
	for u in player_units.get_children():
		if u == null or not is_instance_valid(u):
			continue
		# 死亡淡出期间（_is_dying=true，queue_free 尚未执行）不计入存活，
		# 否则刚死亡的单位仍被当作存活→对应卡被跳过→补阵失败
		if "_is_dying" in u and u._is_dying:
			continue
		var inst: String = String(u.get_meta("source_instance_id", ""))
		if not inst.is_empty():
			ids.append(inst)
		else:
			var cid: String = String(u.get_meta("source_card_id", ""))
			if not cid.is_empty():
				ids.append(cid)
	return ids


## v7.x 固定映射部署：遍历队列，每个条目部署到其绿槽对应的战场位
## 绿槽 N → 战场位 N+1；该位已有单位则跳过，空闲则部署
func _deploy_next() -> void:
	if _deploy_queue.is_empty():
		return
	var bm: Node = _get_node("/root/BattleManager")
	if bm == null or not bool(bm.get("battle_active")):
		return  # 战斗已结束，下一帧重试
	var bf: Node2D = _get_battlefield()
	if bf == null:
		return
	var grid: Node = null
	if bf.has_method("ensure_battle_slot_grid_ready"):
		grid = bf.ensure_battle_slot_grid_ready()
	if grid == null:
		grid = bf.get_node_or_null("BattleSlotGrid")
	if grid == null:
		return
	var player_units: Node2D = null
	if bf.has_method("get_player_units_node"):
		player_units = bf.get_player_units_node()
	if player_units == null:
		player_units = bf.get_node_or_null("PlayerUnits")
	# v8.1d: 每次部署前用统一口径检查剩余配额，避免"slot 检查说有空位但 recount 说已满"
	var bss: Node = _get_node("/root/BattleSpawnSystem")
	if bss != null and bss.has_method("get_remaining_deployable_count"):
		if bss.get_remaining_deployable_count() <= 0:
			_deploy_queue.clear()
			return
	var deployed_index: int = -1
	for i in range(_deploy_queue.size()):
		var entry: Dictionary = _deploy_queue[i]
		var platform = entry.get("platform")
		var slot_index: int = int(entry.get("slot_index", 0))
		var battlefield_slot: int = slot_index + SLOT_INDEX_OFFSET
		# 该战场位已有单位 → 跳过（不部署，不报错）
		if grid.has_method("is_player_slot_occupied") and player_units != null:
			if grid.is_player_slot_occupied(battlefield_slot, player_units):
				continue
		# 战场位空闲 → 部署到该位置
		var pos: Vector2 = _get_slot_world_pos(bf, battlefield_slot)
		if pos == Vector2.INF:
			continue
		var card_id: String = ""
		if platform != null and "instance_id" in platform and not String(platform.instance_id).is_empty():
			card_id = String(platform.instance_id)
		elif platform != null and "card_id" in platform:
			card_id = String(platform.card_id)
		if card_id.is_empty():
			deployed_index = i
			break
		var ok: bool = false
		if bm.has_method("request_player_deploy_at"):
			ok = bm.request_player_deploy_at(card_id, pos)
		if ok:
			deployed_index = i
			break
		# 部署失败（能量不足等）→ 继续尝试下一个条目
	if deployed_index >= 0:
		var dep_entry: Dictionary = _deploy_queue[deployed_index]
		var dep_slot: int = int(dep_entry.get("slot_index", -1))
		if dep_slot >= 0:
			_slot_deploy_time[dep_slot] = Time.get_ticks_msec()  # v8.1c: 记录补阵时间用于冷却
		_deploy_queue.remove_at(deployed_index)
		_fail_streak = 0
	else:
		# 全部失败（多为能量不足或对应位已有单位）→ 整轮重试
		_fail_streak += 1
		if _fail_streak > FAIL_GIVEUP:
			# 连续多轮无进展 → 检查是否所有位都已占满
			if _all_slots_occupied(grid, player_units):
				_deploy_queue.clear()
			else:
				# 仍有空位但部署一直失败（如能量永远不够）→ 放弃队首
				_deploy_queue.pop_front()
			_fail_streak = 0


## 返回指定战场位的世界坐标；无效返回 Vector2.INF
func _get_slot_world_pos(bf: Node2D, battlefield_slot: int) -> Vector2:
	if bf == null or not bf.has_method("get_card_grid_player_slot_global"):
		return Vector2.INF
	return bf.get_card_grid_player_slot_global(battlefield_slot)


## 检查所有队列条目对应的战场位是否都已占满
func _all_slots_occupied(grid: Node, player_units: Node2D) -> bool:
	if grid == null or not grid.has_method("is_player_slot_occupied") or player_units == null:
		return false
	for entry in _deploy_queue:
		var slot_index: int = int(entry.get("slot_index", 0))
		var battlefield_slot: int = slot_index + SLOT_INDEX_OFFSET
		if not grid.is_player_slot_occupied(battlefield_slot, player_units):
			return false
	return true


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
