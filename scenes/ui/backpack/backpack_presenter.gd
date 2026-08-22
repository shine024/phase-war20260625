class_name BackpackPresenter
extends RefCounted
## 背包逻辑层 (Presenter)
## 连接 BackpackData (Model) 和 BackpackPanel (View)。
## 处理所有业务逻辑：卡牌点击、装备、即时能量卡消耗、存档恢复等。
##
## 设计文档：背包 MVP 架构重构（MVP 模式拆分）
## 职责：
##   - 订阅 Model 信号，驱动 View 刷新
##   - 订阅全局信号 (SignalBus / Manager)，更新 Model 并驱动 View
##   - 处理用户交互（点击卡牌、装备按钮等）
##   - 不直接操作 UI 节点，通过 View 接口方法间接操作

const BasicResources = preload("res://data/basic_resources.gd")
const GC = preload("res://resources/game_constants.gd")

## Model
var _data: BackpackData

## View（弱引用，backpack_panel.gd 实例）
var _view: PanelContainer = null
## 背包隐藏期间发生了数据变化，待下次可见时再全量刷新
var _grid_dirty_while_hidden: bool = false
var _aux_sections_initialized: bool = false
var _open_refresh_inflight: bool = false
var _suppress_next_cards_changed_refresh: bool = false
## 背包可见期间将重刷新延后到下次打开，装卡只做增量占位，降低实时卡顿。
var _defer_visible_grid_refresh: bool = true

## ============================================================
## 生命周期
## ============================================================

## 初始化 Presenter，绑定 Model 和 View
func setup(data: BackpackData, view: PanelContainer) -> void:
	_data = data
	_view = view
	_connect_model_signals()
	_connect_global_signals()
	# 初始加载
	_load_initial_cards()

## 清理所有信号连接
func cleanup() -> void:
	_disconnect_model_signals()
	_disconnect_global_signals()
	_view = null

## ============================================================
## Model 信号 -> View 刷新
## ============================================================

func _connect_model_signals() -> void:
	if _data == null:
		return
	_data.cards_changed.connect(_on_model_cards_changed)
	_data.filter_changed.connect(_on_model_filter_changed)

func _disconnect_model_signals() -> void:
	if _data == null:
		return
	if _data.cards_changed.is_connected(_on_model_cards_changed):
		_data.cards_changed.disconnect(_on_model_cards_changed)
	if _data.filter_changed.is_connected(_on_model_filter_changed):
		_data.filter_changed.disconnect(_on_model_filter_changed)

func _on_model_cards_changed() -> void:
	if _suppress_next_cards_changed_refresh:
		_suppress_next_cards_changed_refresh = false
		return
	if not _is_view_visible():
		_grid_dirty_while_hidden = true
		return
	_refresh_card_grid()

func _on_model_filter_changed() -> void:
	_refresh_card_grid()

## ============================================================
## 全局信号连接
## ============================================================

func _connect_global_signals() -> void:
	if SignalBus:
		if SignalBus.card_added_to_backpack.is_connected(_on_card_added):
			SignalBus.card_added_to_backpack.disconnect(_on_card_added)
		SignalBus.card_added_to_backpack.connect(_on_card_added)
		if SignalBus.card_equipped.is_connected(_on_card_equipped):
			SignalBus.card_equipped.disconnect(_on_card_equipped)
		SignalBus.card_equipped.connect(_on_card_equipped)
		# v7.x：换装原子信号（避免 card_added_to_backpack(old) + card_equipped(new) 双信号中间态导致背包重复）
		if SignalBus.has_signal("card_swapped"):
			if SignalBus.card_swapped.is_connected(_on_card_swapped):
				SignalBus.card_swapped.disconnect(_on_card_swapped)
			SignalBus.card_swapped.connect(_on_card_swapped)
		if SignalBus.backpack_changed.is_connected(_on_backpack_changed):
			SignalBus.backpack_changed.disconnect(_on_backpack_changed)
		SignalBus.backpack_changed.connect(_on_backpack_changed)
		# v7.x：监听实例销毁，清理背包列表里的幽灵 instance_id（进化消耗/拆解/相位仪清理触发）
		if SignalBus.has_signal("instance_disposed"):
			if SignalBus.instance_disposed.is_connected(_on_instance_disposed):
				SignalBus.instance_disposed.disconnect(_on_instance_disposed)
			SignalBus.instance_disposed.connect(_on_instance_disposed)

	var brm: Node = _get_autoload_node("BasicResourceManager")
	if brm != null and brm.has_signal("resources_changed"):
		if not brm.resources_changed.is_connected(_on_resources_changed):
			brm.resources_changed.connect(_on_resources_changed)

	# DEPRECATED (P0-3c): blueprint_fragments signal connection disabled — fragment-based model removed
	#if BlueprintManager and BlueprintManager.has_signal("fragments_changed"):
	#	if not BlueprintManager.fragments_changed.is_connected(_on_blueprint_fragments_changed):
	#		BlueprintManager.fragments_changed.connect(_on_blueprint_fragments_changed)

	var lm: Node = _get_autoload_node("LoreManager")
	if lm and lm.has_signal("lore_unlocked"):
		if not lm.lore_unlocked.is_connected(_on_lore_unlocked):
			lm.lore_unlocked.connect(_on_lore_unlocked)

	var sbm: Node = _get_autoload_node("StatBoostManager")
	if sbm and sbm.has_signal("stat_boost_applied"):
		if not sbm.stat_boost_applied.is_connected(_on_stat_boost_applied):
			sbm.stat_boost_applied.connect(_on_stat_boost_applied)

func _disconnect_global_signals() -> void:
	if SignalBus:
		if SignalBus.card_added_to_backpack.is_connected(_on_card_added):
			SignalBus.card_added_to_backpack.disconnect(_on_card_added)
		if SignalBus.card_equipped.is_connected(_on_card_equipped):
			SignalBus.card_equipped.disconnect(_on_card_equipped)
		if SignalBus.has_signal("card_swapped") and SignalBus.card_swapped.is_connected(_on_card_swapped):
			SignalBus.card_swapped.disconnect(_on_card_swapped)
		if SignalBus.backpack_changed.is_connected(_on_backpack_changed):
			SignalBus.backpack_changed.disconnect(_on_backpack_changed)
		if SignalBus.has_signal("instance_disposed") and SignalBus.instance_disposed.is_connected(_on_instance_disposed):
			SignalBus.instance_disposed.disconnect(_on_instance_disposed)

# 注意：不主动断开 Manager 信号，因为 Presenter 生命周期通常与场景一致。
# 如果需要完全清理，可以在 cleanup 中实现。

## ============================================================
## 全局信号处理
## ============================================================

func _on_card_added(card: CardResource) -> void:
	if card == null:
		return
	if _data == null:
		return
	# v7.0: 用 instance_id 作为背包身份（实例化养成）；无 instance_id 时回退 card_id（兼容旧卡）
	var inst_id: String = card.instance_id if not card.instance_id.is_empty() else card.card_id
	# 从pending中移除该卡牌ID（标记为已处理）
	if SaveManager and SaveManager.has_method("consume_pending_backpack_card_id"):
		SaveManager.consume_pending_backpack_card_id(inst_id)
	# silent=true：由本函数自身控制刷新，避免 cards_changed 信号触发
	# _on_model_cards_changed 时被 _suppress_next_cards_changed_refresh 吞掉导致漏刷新。
	_data.add_extra_card(inst_id, true)
	# 注意：此处不能再调用 enqueue_backpack_card_id。
	# card_added_to_backpack 信号有两个监听者——本函数(presenter) 和 SaveManager 兜底。
	# SaveManager 兜底已经 enqueue 一次（pending+last_known 各+1）；若 presenter 再 enqueue，
	# 会导致 last_known 比真实多记一份，下次 load_pending_cards 的差值补齐会把它兑现成多一张卡。
	# presenter 存活时只管真实数据 _data，pending 由上面的 consume 消费掉即可。
	if not _is_view_visible():
		_grid_dirty_while_hidden = true
	else:
		_refresh_card_grid()
	if _view and _view.has_method("highlight_last_card_by_id"):
		_view.highlight_last_card_by_id(inst_id)

## v7.x：实例被销毁时（进化消耗/拆解/相位仪清理），从背包列表移除对应的幽灵 instance_id。
## 根因：dispose_instance 只清 InstanceRegistry，不通知背包列表，导致 _extra_card_ids 残留
## 已销毁的 instance_id（如进化前的源卡），下次 get_all_cards 触发"实例缺失，复用同名实例"告警。
func _on_instance_disposed(instance_id: String) -> void:
	if instance_id.is_empty() or _data == null:
		return
	# remove_extra_card_strict：仅当列表里真有该 id 时才移除并返回 true，避免误删
	var removed: bool = bool(_data.remove_extra_card_strict(instance_id, true))
	# SaveManager 的 pending/last_known 队列也要同步清理（presenter 存活时 pending 通常已 consume，
	# 但 last_known 可能残留；读档时若该 id 还在存档，会重新进 pending）
	if SaveManager and SaveManager.has_method("purge_backpack_card_id"):
		SaveManager.purge_backpack_card_id(instance_id)
	if removed and _is_view_visible():
		_refresh_card_grid()

func _on_card_equipped(_slot_index: int, card_id: String, _card_type: String) -> void:
	var can_incremental: bool = _view and _view.has_method("remove_last_card_by_id")
	var use_silent_remove: bool = can_incremental and _is_view_visible() and _defer_visible_grid_refresh
	var removed: bool = _data.remove_card(card_id, use_silent_remove)
	# 背包可见期间优先增量移除，并延后全量刷新到下次打开背包。
	if can_incremental and removed:
		var removed_from_view: bool = _view.remove_last_card_by_id(card_id)
		if removed_from_view and use_silent_remove:
			_grid_dirty_while_hidden = true
			return
		if removed_from_view:
			return
	if use_silent_remove:
		_grid_dirty_while_hidden = true
		return
	if can_incremental:
		# 仅在“装备增量路径失败并回退全量刷新”时短路下一次 model cards_changed，避免重复 rebuild。
		_suppress_next_cards_changed_refresh = true
	_refresh_card_grid()

## v7.x：换装原子回调——槽位 old_card 被替换为 new_card_id（拖卡到已占用槽位触发）。
## 关键顺序：先移新卡出包（此时 _data 里一定有它，remove 必成功），再添旧卡入包。
## 原 emit 顺序是 card_added_to_backpack(old) → card_equipped(new)，中间态背包同时含两卡，
## 叠加 remove_card 静默成功会因时序竞态导致新卡未移除 → 背包多一张。此处消除该窗口。
func _on_card_swapped(_slot_index: int, old_card: CardResource, new_card_id: String) -> void:
	if _data == null:
		return
	# 1. 先移新卡出包（换装瞬间新卡必在 _data 中，remove 必成功）
	var removed: bool = _data.remove_card(new_card_id, true)
	if not removed:
		push_warning("[BackpackPresenter] card_swapped: 新卡 %s 未在背包中找到（可能时序异常）" % new_card_id)
	# 2. 再添旧卡入包（consume pending 里可能的幽灵记录，避免下次 load_pending 兑现成重复）
	if old_card != null:
		var old_id: String = old_card.instance_id if not old_card.instance_id.is_empty() else old_card.card_id
		if SaveManager and SaveManager.has_method("consume_pending_backpack_card_id"):
			SaveManager.consume_pending_backpack_card_id(old_id)
		_data.add_extra_card(old_id, true)
	# 增量移除新卡的视觉（若可见且支持），旧卡加入由全量刷新覆盖
	var can_incremental: bool = _view and _view.has_method("remove_last_card_by_id")
	if can_incremental and removed and _is_view_visible():
		_view.remove_last_card_by_id(new_card_id)
	if not _is_view_visible():
		_grid_dirty_while_hidden = true
	else:
		_refresh_card_grid()

func _on_backpack_changed() -> void:
	pass

func _on_resources_changed() -> void:
	pass  # 资源已在顶部资源栏显示

func _on_blueprint_fragments_changed() -> void:
	pass  # DEPRECATED (P0-3c): blueprint_fragments callback disabled — no longer needed

func _on_lore_unlocked(_lore_id: String, _lore_name: String) -> void:
	if _view and _view.has_method("refresh_lore_pages"):
		_view.refresh_lore_pages()

func _on_stat_boost_applied(_boost_id: String, _boost_name: String, _total_count: int) -> void:
	if _view and _view.has_method("refresh_stat_boosts"):
		_view.refresh_stat_boosts()

## ============================================================
## 用户交互处理
## ============================================================

## 卡牌点击：由 View 调用
func on_card_clicked(card: CardResource, source_item: Control) -> void:
	if card == null:
		return
	# v7.x: 能量卡系统移除，原能量卡点击处理（即时消耗/装备）已删除。
	# ENERGY 类型的残留卡（理论上不会出现）走详情弹窗兜底。
	# 其他卡：显示详情弹窗
	# B2: 点击音（同类列表行点击此前全部静音）
	if SignalBus.has_signal("play_sound"):
		SignalBus.play_sound.emit("button")
	if _view and _view.has_method("show_card_detail"):
		_view.show_card_detail(card, source_item)

## 装备按钮回调：从详情弹窗中装备卡到相位仪
func on_equip_button_pressed(card: CardResource) -> void:
	if card == null:
		return
	if _try_equip_card(card):
		if _view and _view.has_method("hide_card_detail"):
			_view.hide_card_detail()
		_show_toast_success("已装备：%s" % String(card.display_name))
		# B2: 装备成功音效（与拖拽装备路径对齐，此前成功全程静音）
		if SignalBus.has_signal("play_sound"):
			SignalBus.play_sound.emit("card_place")
	else:
		# P0-2: 失败此前弹窗不关、无任何提示（"点了没反应"），现给出具体原因
		_show_toast_error("装备失败：%s" % _last_equip_fail_reason)
		SignalBus.play_sound.emit("error")

## 最近一次装备失败的原因（由 _try_equip_card 各失败分支写入）
var _last_equip_fail_reason: String = "没有可用的对应槽位"



## 关闭详情弹窗
func on_detail_close() -> void:
	if _view and _view.has_method("hide_card_detail"):
		_view.hide_card_detail()

## 关闭背包面板
func on_close() -> void:
	if _view and _view.has_method("emit_closed"):
		_view.emit_closed()

## ============================================================
## 装备逻辑
## ============================================================

## 尝试将能量卡装备到相位仪黄色槽
func _try_equip_energy_card(card: CardResource) -> bool:
	var pim: Node = _get_autoload_node("PhaseInstrumentManager")
	var em: Node = _get_autoload_node("EnergyManager")
	if pim == null or em == null:
		return false
	if not pim.has_method("equip_card") or not pim.has_method("get_current_instrument"):
		return false
	var cfg: Dictionary = pim.get_current_instrument()
	var counts: Dictionary = cfg.get("slot_counts", {})
	var red_count: int = int(counts.get("red", 0))
	var blue_count: int = int(counts.get("blue", 0))
	var green_count: int = int(counts.get("green", 0))
	var yellow_count: int = int(counts.get("yellow", 0))
	var slots: Array = pim.get_slots() if pim.has_method("get_slots") else []
	var yellow_start: int = red_count + blue_count + green_count
	for yi in range(yellow_count):
		var flat_idx: int = yellow_start + yi
		if flat_idx < 0 or flat_idx >= slots.size():
			continue
		if slots[flat_idx] != null:
			continue
		return bool(pim.equip_card(flat_idx, card, em))
	return false

## 从背包点击装备任意卡到相位仪对应槽位
func _try_equip_card(card: CardResource) -> bool:
	if card == null:
		return false
	var pim: Node = _get_autoload_node("PhaseInstrumentManager")
	var em: Node = _get_autoload_node("EnergyManager")
	if pim == null or not pim.has_method("get_slots") or not pim.has_method("equip_card"):
		_last_equip_fail_reason = "相位仪系统未就绪"
		return false

	var slots: Array = pim.get_slots() if pim.has_method("get_slots") else []
	var cfg: Dictionary = pim.get_current_instrument() if pim.has_method("get_current_instrument") else {}
	var counts: Dictionary = cfg.get("slot_counts", {})
	var red_count: int = int(counts.get("red", 0))
	var blue_count: int = int(counts.get("blue", 0))
	var green_count: int = int(counts.get("green", 0))
	var green_start: int = red_count + blue_count

	match card.card_type:
		GC.CardType.COMBAT_UNIT, GC.CardType.COMBAT_UNIT, GC.CardType.COMBAT_UNIT:
			if green_count <= 0:
				_last_equip_fail_reason = "当前相位仪没有绿色战斗槽位"
				push_warning("[BackpackPresenter] 当前相位仪没有平台/武器槽位")
				return false
			var first_occupied_green: int = -1
			for gi in range(green_count):
				var flat_gi: int = green_start + gi
				if flat_gi >= slots.size():
					break
				if slots[flat_gi] == null:
					var ok0: bool = bool(pim.equip_card(flat_gi, card, em))
					if not ok0:
						_last_equip_fail_reason = "槽位校验未通过"
					return ok0
				if first_occupied_green < 0:
					first_occupied_green = flat_gi
			# 所有绿色槽位已满 → 替换第一个
			if first_occupied_green >= 0:
				var ok0: bool = bool(pim.equip_card(first_occupied_green, card, em))
				if not ok0:
					_last_equip_fail_reason = "槽位校验未通过"
				return ok0
			_last_equip_fail_reason = "绿色槽位不足"
			push_warning("[BackpackPresenter] 绿色槽位不足")
			return false
		GC.CardType.ENERGY:
			return _try_equip_energy_card(card)
	# match 兜底：未知卡牌类型（其余分支均自带 return，此处兜不可达的未来类型）
	# v9.x（P2-7范围A）：法则卡装备分支随法则卡链路退役移除——背包已无法则卡可装备
	_last_equip_fail_reason = "未知卡牌类型，无法装备"
	return false

## ============================================================
## 即时能量卡消耗
## ============================================================

func _consume_instant_energy_card(card: CardResource, source_item: Control) -> void:
	var em: Node = _get_autoload_node("EnergyManager")
	if em and em.has_method("add_energy"):
		em.add_energy(card.energy_grant)
	var removed: bool = _data.remove_card(card.card_id)
	if _can_incremental_update() and removed and _view and _view.has_method("remove_last_card_by_id"):
		var removed_from_view: bool = _view.remove_last_card_by_id(card.card_id)
		if removed_from_view:
			return
	# 兜底：如果无法增量移除，保留原有全量刷新路径保证正确性。
	if source_item and is_instance_valid(source_item) and source_item.has_method("set_card"):
		source_item.set_card(null)
	_refresh_card_grid()



func _show_toast_success(message: String) -> void:
	var toast_mgr: Node = _get_autoload_node("ToastManager")
	if toast_mgr != null and toast_mgr.has_method("show_success"):
		toast_mgr.show_success(message)
		return
	if SignalBus and SignalBus.has_signal("show_toast"):
		SignalBus.show_toast.emit(message)

func _show_toast_error(message: String) -> void:
	var toast_mgr: Node = _get_autoload_node("ToastManager")
	if toast_mgr != null and toast_mgr.has_method("show_error"):
		toast_mgr.show_error(message)
		return
	if SignalBus and SignalBus.has_signal("show_toast"):
		SignalBus.show_toast.emit(message)

## ============================================================
## 存档恢复
## ============================================================

## 读档后恢复额外卡牌
func restore_extra_cards(ids: Array) -> void:
	_data.restore_extra_cards(ids)

## 读档后从 SaveManager 加载 pending 卡牌
## 关键：面板可能被 LazyLoader 反复销毁重建，每次重建 _data._extra_card_ids 都是空的。
## 因此每次打开背包时，都要从 SaveManager 的权威数据（pending + last_known）中同步恢复。
func load_pending_cards(prefer_incremental_view_update: bool = false) -> bool:
	if _data == null:
		return false
	# 1. 从 pending 取完整列表（含重复卡）
	var pending: Array = []
	if SaveManager and SaveManager.has_method("get_pending_backpack_ids"):
		pending = SaveManager.get_pending_backpack_ids()
	# 2. 合并 last_known（会话内曾经入包的所有卡，防止 pending 被消费后丢失）
	var last_known: Array = []
	if SaveManager and SaveManager.has_method("get_last_known_backpack_ids"):
		last_known = SaveManager.get_last_known_backpack_ids()
	# [LOG-v5.1] print("[BP] load_pending: pending=%s last_known=%s data_extra=%d" % [pending, last_known, _data.get_extra_card_ids().size()])
	# 3. 合并：以 pending 为主，补充 last_known 中 pending 缺少的卡（按出现次数差值补齐）
	var pending_counts: Dictionary = {}
	for id_val in pending:
		var sid: String = str(id_val) if id_val != null else ""
		if not sid.is_empty():
			pending_counts[sid] = pending_counts.get(sid, 0) + 1
	var last_known_counts: Dictionary = {}
	for id_val in last_known:
		var sid: String = str(id_val) if id_val != null else ""
		if not sid.is_empty():
			last_known_counts[sid] = last_known_counts.get(sid, 0) + 1
	var final_ids: Array = []
	# 先放 pending 的全部（保留重复）
	for id_val in pending:
		var sid: String = str(id_val) if id_val != null else ""
		if not sid.is_empty():
			final_ids.append(sid)
	# 补齐 last_known 比 pending 多出的次数
	for sid in last_known_counts:
		var lk_count: int = last_known_counts.get(sid, 0)
		var p_count: int = pending_counts.get(sid, 0)
		var diff: int = lk_count - p_count
		for _i in range(maxi(0, diff)):
			final_ids.append(sid)
	if final_ids.is_empty():
		return false
	# 4. 仅追加 _data 中不存在的卡（按出现次数逐张比对）
	var data_ids: Array = _data.get_extra_card_ids()
	var data_count_map: Dictionary = {}
	for sid in data_ids:
		data_count_map[sid] = data_count_map.get(sid, 0) + 1
	var new_ids: Array = []
	for sid in final_ids:
		var current: int = data_count_map.get(sid, 0)
		if current > 0:
			data_count_map[sid] = current - 1
		else:
			new_ids.append(sid)
	if new_ids.is_empty():
		return false
	var silent: bool = prefer_incremental_view_update
	_data.append_extra_cards(new_ids, silent)
	# [LOG-v5.1] print("[BP] load_pending: new_ids=%s final_data=%d" % [new_ids, _data.get_extra_card_ids().size()])
	return true

## ============================================================
## 筛选 / 排序
## ============================================================

func set_filter_type(filter_type: int) -> void:
	_data.set_filter_type(filter_type)

func set_sort_type(sort_type: int) -> void:
	_data.set_sort_type(sort_type)

func reset_filters() -> void:
	_data.reset_filters()

## ============================================================
## 快速稀有度筛选（可见性切换）
## ============================================================

func quick_filter_by_rarity(rarity: String) -> void:
	if _view and _view.has_method("apply_rarity_filter"):
		_view.apply_rarity_filter(rarity)

func reset_visibility_filters() -> void:
	if _view and _view.has_method("reset_visibility"):
		_view.reset_visibility()

## ============================================================
## 内部方法
## ============================================================

## 初始加载：从 SaveManager 同步 pending + last_known 额外卡
func _load_initial_cards() -> void:
	if _view == null:
		return
	# 1. 合并 pending + last_known 恢复所有已知额外卡
	var loaded := load_pending_cards(false)
	# [LOG-v5.1] print("[BP] _load_initial_cards: loaded=%s extra=%d" % [loaded, _data.get_extra_card_ids().size()])
	# 2. 同步当前 _data 到 SaveManager._last_known_extra_ids（如果尚未同步）
	if SaveManager and SaveManager.has_method("_set_last_known_extra_ids_direct"):
		var all_known: Array = _data.get_extra_card_ids().duplicate()
		SaveManager._set_last_known_extra_ids_direct(all_known)
	# 3. 填充卡片网格
	_refresh_card_grid()
	# 4. 固定顶部能量卡
	if _view and _view.has_method("pin_top_energy_to_front"):
		_view.pin_top_energy_to_front()
	# 5. 情报/属性提升区域改为首次打开背包后再异步初始化，避免首开卡顿。
	_aux_sections_initialized = false

func flush_if_dirty() -> void:
	if not _grid_dirty_while_hidden:
		return
	if not _is_view_visible():
		return
	_grid_dirty_while_hidden = false
	_refresh_card_grid()

func on_overlay_opened() -> void:
	# 打开背包时将重刷新拆帧，先保证可交互，再补齐网格与附属区域，降低首开尖峰。
	if _open_refresh_inflight:
		return
	_open_refresh_inflight = true
	call_deferred("_run_open_refresh_pipeline")

## 刷新卡片网格（重新填充筛选排序后的卡牌）
func _refresh_card_grid() -> void:
	if _data == null:
		return
	var cards := _data.get_filtered_sorted_cards()
	var extra := _data.get_extra_card_ids()
	# [LOG-v5.1] print("[BP] _refresh_grid: cards=%d extra_ids=%s" % [cards.size(), extra])
	if _view and _view.has_method("rebuild_card_grid"):
		_view.rebuild_card_grid(cards)

func _can_incremental_update() -> bool:
	return _is_view_visible() and _data != null and _data.has_method("is_default_view_mode") and _data.is_default_view_mode()

func _run_open_refresh_pipeline() -> void:
	# [LOG-v5.1] print("[BP] _run_open_refresh_pipeline: visible=%s dirty=%s inflight=%s" % [_is_view_visible(), _grid_dirty_while_hidden, _open_refresh_inflight])
	# 保护：若背包在这一帧内已关闭，直接结束。
	if not _is_view_visible():
		_open_refresh_inflight = false
		return
	# Step 1: 先吸收 pending，默认模式优先增量插入。
	var loaded_pending: bool = load_pending_cards(true)
	# Step 2: 总是刷新网格。dirty flag 或 pending 变化是充分条件，
	# 但即使两者都为 false，也做一次全量刷新确保 SaveManager 与 _data 一致。
	var tree: SceneTree = _get_scene_tree()
	if tree != null:
		await tree.process_frame
		if _is_view_visible():
			_grid_dirty_while_hidden = false
			_refresh_card_grid()
	# Step 3: 附属区（情报/属性提升/符文）再延后一帧，避开与网格同帧竞争。
	# 首次打开需要 await 一帧做异步初始化（避免首开卡顿）；后续每次打开也刷新一次，
	# 否则 _aux_sections_initialized 置位后再次打开背包不会刷新附属区，
	# 导致购买/掉落的新符文、新情报等不在对应标签页显示。
	if not _aux_sections_initialized:
		_aux_sections_initialized = true
		tree = _get_scene_tree()
		if tree != null:
			await tree.process_frame
	if _view != null and is_instance_valid(_view) and _view.is_visible_in_tree():
		_view.call_deferred("_refresh_aux_sections_after_open")
	_open_refresh_inflight = false

func _is_view_visible() -> bool:
	return _view != null and is_instance_valid(_view) and _view.is_visible_in_tree()

func _get_autoload_node(name: String) -> Node:
	var tree: SceneTree = _get_scene_tree()
	if tree != null and tree.root != null:
		return tree.root.get_node_or_null(name)
	return null

func _get_scene_tree() -> SceneTree:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return loop as SceneTree
	return null
