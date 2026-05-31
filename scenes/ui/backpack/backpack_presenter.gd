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

const DefaultCardsData = preload("res://data/default_cards.gd")
const BasicResources = preload("res://data/basic_resources.gd")
const StarConfig = preload("res://data/blueprint_star_config.gd")
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
	if _defer_visible_grid_refresh:
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
		if SignalBus.backpack_changed.is_connected(_on_backpack_changed):
			SignalBus.backpack_changed.disconnect(_on_backpack_changed)
		SignalBus.backpack_changed.connect(_on_backpack_changed)

	var brm: Node = _get_autoload_node("BasicResourceManager")
	if brm != null and brm.has_signal("resources_changed"):
		if not brm.resources_changed.is_connected(_on_resources_changed):
			brm.resources_changed.connect(_on_resources_changed)

	if BlueprintManager and BlueprintManager.has_signal("fragments_changed"):
		if not BlueprintManager.fragments_changed.is_connected(_on_blueprint_fragments_changed):
			BlueprintManager.fragments_changed.connect(_on_blueprint_fragments_changed)

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
		if SignalBus.backpack_changed.is_connected(_on_backpack_changed):
			SignalBus.backpack_changed.disconnect(_on_backpack_changed)

# 注意：不主动断开 Manager 信号，因为 Presenter 生命周期通常与场景一致。
# 如果需要完全清理，可以在 cleanup 中实现。

## ============================================================
## 全局信号处理
## ============================================================

func _on_card_added(card: CardResource) -> void:
	if card == null:
		push_warning("[BackpackPresenter] _on_card_received null card")
		return
	# 从pending中移除该卡牌ID（标记为已处理）
	if SaveManager and SaveManager.has_method("consume_pending_backpack_card_id"):
		SaveManager.consume_pending_backpack_card_id(card.card_id)
	# 先保证正确性：制造入包统一走全量刷新路径，避免增量插入在复杂时序下漏显示。
	_data.add_extra_card(card.card_id, false)
	if not _is_view_visible():
		_grid_dirty_while_hidden = true
	else:
		_refresh_card_grid()
	if _view and _view.has_method("highlight_last_card_by_id"):
		_view.highlight_last_card_by_id(card.card_id)

func _on_card_equipped(_slot_index: int, card_id: String, _card_type: String) -> void:
	var t0: int = Time.get_ticks_msec()
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

func _on_backpack_changed() -> void:
	pass

func _on_resources_changed() -> void:
	pass  # 资源已在顶部资源栏显示

func _on_blueprint_fragments_changed() -> void:
	pass  # 已解锁蓝图在蓝图库中显示

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
	# 即时能量卡：点击即加能量并消耗
	if card.card_type == GC.CardType.ENERGY and card.card_id == "energy_s":
		_consume_instant_energy_card(card, source_item)
		return
	# 非即时能量卡：尝试直接装备到相位仪
	if card.card_type == GC.CardType.ENERGY and card.card_id != "energy_s":
		if _try_equip_energy_card(card):
			return
	# 其他卡：显示详情弹窗
	if _view and _view.has_method("show_card_detail"):
		_view.show_card_detail(card, source_item)

## 装备按钮回调：从详情弹窗中装备卡到相位仪
func on_equip_button_pressed(card: CardResource) -> void:
	if card == null:
		return
	if _try_equip_card(card):
		if _view and _view.has_method("hide_card_detail"):
			_view.hide_card_detail()

## 拆解按钮回调：将背包额外卡拆解为研究点 + 纳米材料（研究公式与重复蓝图副本一致）
func on_dismantle_button_pressed(card: CardResource) -> void:
	if card == null:
		return
	if _data == null or not _data.has_method("remove_extra_card_strict"):
		return
	# 仅允许拆解背包中的“额外卡”；不存在则不执行，防止重复领取资源。
	var removed: bool = bool(_data.remove_extra_card_strict(card.card_id))
	if not removed:
		_show_toast_error("该卡不在背包中，无法拆解")
		return

	var gains: Dictionary = _calculate_dismantle_gains(card)
	var research_gain: int = int(gains.get("research", 0))
	var nano_gain: int = int(gains.get("nano", 0))
	var bpm: Node = _get_autoload_node("BlueprintManager")
	if bpm != null:
		if research_gain > 0 and bpm.has_method("add_research_points"):
			bpm.add_research_points(research_gain)
		if nano_gain > 0 and bpm.has_method("add_nano_materials"):
			bpm.add_nano_materials(nano_gain)
	else:
		var brm: Node = _get_autoload_node("BasicResourceManager")
		if brm != null and brm.has_method("add_resource"):
			if research_gain > 0:
				brm.add_resource(BasicResources.ID_RESEARCH_POINTS, research_gain)
			if nano_gain > 0:
				brm.add_resource(BasicResources.ID_NANO_MATERIALS, nano_gain)

	if _view and _view.has_method("hide_card_detail"):
		_view.hide_card_detail()
	if _view and _view.has_method("remove_last_card_by_id"):
		var removed_from_view: bool = _view.remove_last_card_by_id(card.card_id)
		if not removed_from_view:
			_refresh_card_grid()
	else:
		_refresh_card_grid()
	if SignalBus and SignalBus.has_signal("backpack_changed"):
		SignalBus.backpack_changed.emit()
	_show_toast_success("拆解成功：+%d 研究点，+%d 纳米材料" % [research_gain, nano_gain])

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
				push_warning("[BackpackPresenter] 当前相位仪没有平台/武器槽位")
				return false
			var first_occupied_green: int = -1
			for gi in range(green_count):
				var flat_gi: int = green_start + gi
				if flat_gi >= slots.size():
					break
				if slots[flat_gi] == null:
					var ok0: bool = bool(pim.equip_card(flat_gi, card, em))
					return ok0
				if first_occupied_green < 0:
					first_occupied_green = flat_gi
			# 所有绿色槽位已满 → 替换第一个
			if first_occupied_green >= 0:
				var ok0: bool = bool(pim.equip_card(first_occupied_green, card, em))
				return ok0
			push_warning("[BackpackPresenter] 绿色槽位不足")
			return false
		GC.CardType.ENERGY:
			return _try_equip_energy_card(card)
		GC.CardType.LAW:
			var lid: String = card.linked_law_id if "linked_law_id" in card else ""
			if lid.is_empty():
				lid = card.card_id
			# 制造/蓝图链路可能传入 law: 前缀，查法则定义前统一去前缀。
			if lid.begins_with("law:"):
				lid = lid.substr(4)
			var PL = preload("res://data/phase_laws.gd")
			var law: Dictionary = PL.get_by_id(lid)
			if law.is_empty():
				push_error("[BackpackPresenter] 法则卡找不到法则数据: " + lid)
				return false
			var kind: String = String(law.get("kind", ""))
			var target_color: String = "red" if kind == "active" else "blue"
			var target_start: int = 0 if target_color == "red" else red_count
			var target_count: int = int(counts.get(target_color, 0))
			if target_count <= 0:
				push_warning("[BackpackPresenter] 当前相位仪没有%s槽位" % ("主动" if target_color == "red" else "被动"))
				return false
			var first_occupied_idx: int = -1
			for ti in range(target_count):
				var flat_idx: int = target_start + ti
				if flat_idx >= slots.size():
					break
				if slots[flat_idx] == null:
					var ok1: bool = bool(pim.equip_card(flat_idx, card, em))
					return ok1
				if first_occupied_idx < 0:
					first_occupied_idx = flat_idx
			# 所有槽位已满 → 替换第一个同色槽位（旧卡自动退回背包）
			if first_occupied_idx >= 0:
				var ok2: bool = bool(pim.equip_card(first_occupied_idx, card, em))
				return ok2
			push_warning("[BackpackPresenter] %s槽位不足" % ("主动" if target_color == "red" else "被动"))
			return false
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

## 背包卡拆解收益（见设定总览 §7.2）：
## - 研究点 = 1★→2★ 研究消耗 × 0.35
## - 纳米材料 = 同上 × 2（对齐 Lv1 强化 100 纳米 vs Common 1★→2★ 50 研究）
func _calculate_dismantle_gains(card: CardResource) -> Dictionary:
	var rarity: String = String(card.rarity).to_lower()
	if rarity.is_empty():
		rarity = "common"
	var base_cost: int = StarConfig.get_research_cost_for_next_star(1, rarity)
	var scaled: float = float(base_cost) * 0.35
	return {
		"research": maxi(1, int(scaled)),
		"nano": maxi(1, int(scaled * 2.0)),
	}

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
func load_pending_cards(prefer_incremental_view_update: bool = false) -> bool:
	var pending: Array = []
	if SaveManager and SaveManager.has_method("get_pending_backpack_ids"):
		pending = SaveManager.get_pending_backpack_ids()
	# 背包面板可能被销毁重建：若 pending 已被清空，但会话内仍有最近已知卡列表，则用其恢复一次。
	if pending.is_empty() and _data != null and _data.has_method("get_extra_card_ids") and _data.get_extra_card_ids().is_empty():
		if SaveManager and SaveManager.has_method("get_last_known_backpack_ids"):
			pending = SaveManager.get_last_known_backpack_ids()
	if pending.size() <= 0:
		return false
	var can_incremental: bool = prefer_incremental_view_update and _can_incremental_update()
	if _data != null and _data.has_method("append_extra_cards"):
		_data.append_extra_cards(pending, can_incremental)
	else:
		_data.restore_extra_cards(pending)
	if can_incremental and _view and _view.has_method("add_card"):
		for id_val in pending:
			var card_id: String = str(id_val) if id_val != null else ""
			if card_id.is_empty():
				continue
			var card_res: CardResource = DefaultCardsData.get_card_by_id(card_id)
			if card_res != null:
				_view.add_card(card_res, false)
	if SaveManager and SaveManager.has_method("clear_pending_backpack_ids"):
		SaveManager.clear_pending_backpack_ids()
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

## 初始加载：读档 pending + 仅额外卡网格（无默认全卡池）
func _load_initial_cards() -> void:
	if _view == null:
		return
	# 1. 读取存档的 pending 额外卡
	var loaded: bool = load_pending_cards(false)
	# 2. 填充卡片网格
	_refresh_card_grid()
	var cards := _data.get_filtered_sorted_cards()
	# 3. 固定顶部能量卡
	if _view and _view.has_method("pin_top_energy_to_front"):
		_view.pin_top_energy_to_front()
	# 4. 情报/属性提升区域改为首次打开背包后再异步初始化，避免首开卡顿。
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
	if _view and _view.has_method("rebuild_card_grid"):
		_view.rebuild_card_grid(cards)

func _can_incremental_update() -> bool:
	return _is_view_visible() and _data != null and _data.has_method("is_default_view_mode") and _data.is_default_view_mode()

func _run_open_refresh_pipeline() -> void:
	# 保护：若背包在这一帧内已关闭，直接结束。
	if not _is_view_visible():
		_open_refresh_inflight = false
		return
	# Step 1: 先吸收 pending，默认模式优先增量插入。
	var loaded_pending: bool = load_pending_cards(true)
	# Step 2: 若存在隐藏期脏数据，或 pending 未走增量，则下一帧再做一次网格刷新。
	var need_grid_rebuild: bool = _grid_dirty_while_hidden or (loaded_pending and not _can_incremental_update()) or (not loaded_pending and _grid_dirty_while_hidden)
	var tree: SceneTree = _get_scene_tree()
	if need_grid_rebuild and tree != null:
		await tree.process_frame
		if _is_view_visible():
			_grid_dirty_while_hidden = false
			_refresh_card_grid()
	# Step 3: 附属区（情报/属性提升）再延后一帧，避开与网格同帧竞争。
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
