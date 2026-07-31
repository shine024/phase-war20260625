extends PanelContainer
## 卡牌图鉴面板 v7.x(A1)
## 数据源：CardCollectionManager（收集状态/里程碑）+ DefaultCards（全集）+ InstanceRegistry（实际拥有兜底）
## 范式参考：modification_panel.gd（左列表+右详情，signal closed / show_panel）

signal closed

const DefaultCards = preload("res://data/default_cards.gd")
const DT = preload("res://resources/design_tokens.gd")

var _selected_card_id: String = ""
# v8.x 性能：on_overlay_opened 拆帧重入守卫
var _open_refresh_inflight: bool = false

@onready var _title_lbl: Label = $Margin/VBox/TitleRow/Title
@onready var _progress_lbl: Label = $Margin/VBox/ProgressRow/ProgressLabel
@onready var _progress_bar: ProgressBar = $Margin/VBox/ProgressRow/ProgressBar
@onready var _rarity_row: HBoxContainer = $Margin/VBox/RarityRow
@onready var _milestone_lbl: Label = $Margin/VBox/MilestoneRow/MilestoneLabel
@onready var _card_list: VBoxContainer = $Margin/VBox/ContentHBox/LeftVBox/CardScroll/CardList
@onready var _detail_name: Label = $Margin/VBox/ContentHBox/RightVBox/DetailScroll/DetailVBox/DetailName
@onready var _detail_status: Label = $Margin/VBox/ContentHBox/RightVBox/DetailScroll/DetailVBox/DetailStatus
@onready var _detail_info: Label = $Margin/VBox/ContentHBox/RightVBox/DetailScroll/DetailVBox/DetailInfo
@onready var _close_btn: Button = $Margin/VBox/CloseRow/CloseBtn


func _ready() -> void:
	if _close_btn:
		_close_btn.pressed.connect(_on_close)
	# v7.x 性能：CardCollectionManager 延迟加载，面板初始化时确保已实例化（否则本地信号连不上）
	var _mll: Node = get_node_or_null("/root/ManagerLazyLoader")
	if _mll and _mll.has_method("ensure_loaded"):
		_mll.ensure_loaded("card_collection")
	# 刷新订阅：blueprint_unlocked 是主路径；CardCollectionManager 本地信号兜底；
	# card_added_to_backpack 覆盖"已拥有但未触发解锁信号"的卡（ InstanceRegistry 兜底判断）。
	if SignalBus:
		if not SignalBus.blueprint_unlocked.is_connected(_on_collection_changed):
			SignalBus.blueprint_unlocked.connect(_on_collection_changed)
		if not SignalBus.card_added_to_backpack.is_connected(_on_collection_changed):
			SignalBus.card_added_to_backpack.connect(_on_collection_changed)
	var ccm := get_node_or_null("/root/CardCollectionManager")
	if ccm != null:
		if not ccm.card_obtained.is_connected(_on_collection_changed):
			ccm.card_obtained.connect(_on_collection_changed)
		if not ccm.collection_milestone_reached.is_connected(_on_milestone_reached):
			ccm.collection_milestone_reached.connect(_on_milestone_reached)
	# v8.x 性能：保留首刷（建立 _selected_card_id 初值，保证 SignalBus handler 触发时数据已初始化），
	# 但实际的"打开面板刷新"由 on_overlay_opened 拆帧承担，避免 LazyLoader 实例化同帧卡顿。
	_refresh()


## 公共入口：由 main.gd 的 _ensure_lazy_panel 路径调用。
func show_panel() -> void:
	visible = true
	_refresh()

## v8.x 性能：外部打开面板时调用（main.gd._open_overlay 分发）。
## 将列表重建拆到下一帧，避开打开同帧的实例化尖峰。
## 仿 store_panel.on_overlay_opened 模式。
func on_overlay_opened() -> void:
	if _open_refresh_inflight:
		return
	_open_refresh_inflight = true
	call_deferred("_run_open_refresh_pipeline")

func _run_open_refresh_pipeline() -> void:
	if not is_visible_in_tree():
		_open_refresh_inflight = false
		return
	await get_tree().process_frame
	if not is_visible_in_tree():
		_open_refresh_inflight = false
		return
	_refresh()
	_open_refresh_inflight = false


# ─────────────────────────────────────────────
#  数据
# ─────────────────────────────────────────────

# 判断卡牌是否实际被玩家拥有（双源：CollectionManager 状态 + InstanceRegistry 实例兜底）。
# CollectionManager._collection_data 仅在 update_card_status 被调用时填充，
# 而该调用由 blueprint_unlocked 信号触发——已拥有但未触发信号的卡会显示 LOCKED，
# 故用 InstanceRegistry.get_instances_by_card_id 兜底。
func _is_owned(card_id: String) -> bool:
	var ccm := get_node_or_null("/root/CardCollectionManager")
	if ccm != null and ccm.has_method("get_card_status"):
		var status: int = ccm.get_card_status(card_id)
		if status >= 1:  # CardStatus.OWNED=1, MAX_LEVEL=2
			return true
	# 兜底：查 InstanceRegistry 是否有该卡的实例
	var ir := get_node_or_null("/root/InstanceRegistry")
	if ir != null and ir.has_method("get_instances_by_card_id"):
		return ir.get_instances_by_card_id(card_id).size() > 0
	return false


func _is_max_level(card_id: String) -> bool:
	var ccm := get_node_or_null("/root/CardCollectionManager")
	if ccm != null and ccm.has_method("get_card_status"):
		return ccm.get_card_status(card_id) == 2  # CardStatus.MAX_LEVEL
	return false


func _refresh() -> void:
	_refresh_header()
	_refresh_card_list()
	_refresh_detail()


func _refresh_header() -> void:
	var ccm := get_node_or_null("/root/CardCollectionManager")
	var progress := {"total": 0, "owned": 0, "max_level": 0, "completion_rate": 0.0, "perfection_rate": 0.0}
	if ccm != null and ccm.has_method("get_collection_progress"):
		# CollectionManager 的 owned 基于 _collection_data，可能漏；用 _is_owned 重算
		progress = ccm.get_collection_progress()
	# 用 InstanceRegistry 兜底重算 owned（覆盖已拥有但未触发解锁信号的卡）
	var all_ids: Array = []
	if DefaultCards:
		all_ids = DefaultCards.get_all_blueprint_ids()
	var owned_count := 0
	for cid in all_ids:
		if _is_owned(cid):
			owned_count += 1
	var total: int = all_ids.size()
	var completion := float(owned_count) / total if total > 0 else 0.0
	if _progress_lbl:
		_progress_lbl.text = "已收集 %d / %d（%.1f%%）" % [owned_count, total, completion * 100.0]
	if _progress_bar:
		_progress_bar.max_value = max(1, total)
		_progress_bar.value = owned_count
	# 稀有度色块
	if _rarity_row:
		for child in _rarity_row.get_children():
			child.queue_free()
		if ccm != null and ccm.has_method("get_rarity_collection_stats"):
			var stats: Dictionary = ccm.get_rarity_collection_stats()
			for rarity in ["普通", "稀有", "史诗", "传说", "神话"]:
				var s: Dictionary = stats.get(rarity, {"total": 0, "owned": 0, "rate": 0.0})
				var lbl := Label.new()
				lbl.text = "%s %d/%d" % [rarity, int(s.get("owned", 0)), int(s.get("total", 0))]
				lbl.add_theme_font_size_override("font_size", 12)
				lbl.add_theme_color_override("font_color", _rarity_color(rarity))
				_rarity_row.add_child(lbl)


func _refresh_card_list() -> void:
	if _card_list == null:
		return
	for child in _card_list.get_children():
		child.queue_free()
	var all_ids: Array = []
	if DefaultCards:
		all_ids = DefaultCards.get_all_blueprint_ids()
	# 按稀有度分组（读 CardResource.rarity；查不到归"普通"）
	var groups: Dictionary = {}
	for cid in all_ids:
		var card = DefaultCards.get_card_by_id(cid) if DefaultCards else null
		var rarity: String = "普通"
		if card != null and "rarity" in card and not str(card.rarity).is_empty():
			rarity = str(card.rarity)
		if not groups.has(rarity):
			groups[rarity] = []
		groups[rarity].append(cid)
	# 按固定稀有度顺序渲染分组
	for rarity in ["mythic", "legendary", "epic", "rare", "uncommon", "common", "普通", "稀有", "史诗", "传说", "神话"]:
		if not groups.has(rarity):
			continue
		var header := Label.new()
		header.text = "—— %s（%d）——" % [_rarity_display(rarity), groups[rarity].size()]
		header.add_theme_font_size_override("font_size", 13)
		header.add_theme_color_override("font_color", _rarity_color(rarity))
		_card_list.add_child(header)
		for cid in groups[rarity]:
			_card_list.add_child(_make_card_row(cid))
	# 选中态保持
	if _selected_card_id.is_empty() and all_ids.size() > 0:
		_selected_card_id = all_ids[0]


func _make_card_row(card_id: String) -> Control:
	var btn := Button.new()
	btn.text = _card_display_name(card_id)
	btn.custom_minimum_size = Vector2(220, 32)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", _status_color(card_id))
	btn.pressed.connect(func() -> void:
		_selected_card_id = card_id
		_refresh_detail()
		# 更新选中高亮
		for child in _card_list.get_children():
			if child is Button:
				child.disabled = (child.text == btn.text)
	)
	if card_id == _selected_card_id:
		btn.disabled = true  # 用 disabled 态作选中高亮
	return btn


func _refresh_detail() -> void:
	if _selected_card_id.is_empty():
		if _detail_name:
			_detail_name.text = "请选择一张卡牌"
		if _detail_status:
			_detail_status.text = ""
		if _detail_info:
			_detail_info.text = ""
		return
	var card = DefaultCards.get_card_by_id(_selected_card_id) if DefaultCards else null
	if _detail_name:
		_detail_name.text = _card_display_name(_selected_card_id)
	# 状态
	var status_text: String = ""
	if _is_max_level(_selected_card_id):
		status_text = "★ 已满级"
	elif _is_owned(_selected_card_id):
		status_text = "✓ 已拥有"
	else:
		status_text = "✗ 未获得"
	if _detail_status:
		_detail_status.text = "收集状态：" + status_text
		_detail_status.add_theme_color_override("font_color", _status_color(_selected_card_id))
	# 信息
	var info := ""
	if card != null:
		var lines: Array = []
		lines.append("稀有度：%s" % _rarity_display(str(card.rarity)))
		lines.append("卡牌类型：%s" % str(card.card_type))
		lines.append("兵种：%s" % str(card.combat_kind))
		lines.append("时代：%s" % str(card.era))
		# 三维攻防（若存在）
		if card.attack_light > 0.0:
			lines.append("轻装攻击：%s" % str(card.attack_light))
		if card.attack_armor > 0.0:
			lines.append("装甲攻击：%s" % str(card.attack_armor))
		if card.attack_air > 0.0:
			lines.append("空中攻击：%s" % str(card.attack_air))
		if card.base_hp > 0.0:
			lines.append("生命值：%s" % str(card.base_hp))
		info = "\n".join(lines)
	if _detail_info:
		_detail_info.text = info


func _on_milestone_reached(milestone: Dictionary) -> void:
	if _milestone_lbl:
		var name: String = milestone.get("name", "")
		_milestone_lbl.text = "里程碑达成：%s" % name
		_milestone_lbl.modulate.a = 1.0
		# 简单淡出动画
		var tween := create_tween()
		tween.tween_interval(2.5)
		tween.tween_property(_milestone_lbl, "modulate:a", 0.0, 1.5)


func _on_collection_changed(_arg = null) -> void:
	_refresh()


# ─────────────────────────────────────────────
#  辅助
# ─────────────────────────────────────────────

func _card_display_name(card_id: String) -> String:
	var card = DefaultCards.get_card_by_id(card_id) if DefaultCards else null
	if card != null and card.display_name != "":
		return str(card.display_name)
	return card_id


func _rarity_display(rarity: String) -> String:
	match rarity:
		"common", "普通": return "普通"
		"uncommon": return "优良"
		"rare", "稀有": return "稀有"
		"epic", "史诗": return "史诗"
		"legendary", "传说": return "传说"
		"mythic", "神话": return "神话"
		_: return rarity


func _rarity_color(rarity: String) -> Color:
	match rarity:
		"common", "普通": return Color(0.7, 0.7, 0.7)
		"uncommon": return Color(0.4, 0.8, 0.4)
		"rare", "稀有": return Color(0.35, 0.55, 1.0)
		"epic", "史诗": return Color(0.7, 0.4, 1.0)
		"legendary", "传说": return Color(1.0, 0.7, 0.2)
		"mythic", "神话": return Color(1.0, 0.3, 0.5)
		_: return Color(0.8, 0.8, 0.8)


func _status_color(card_id: String) -> Color:
	if _is_max_level(card_id):
		return Color(1.0, 0.85, 0.3)  # 金
	if _is_owned(card_id):
		return Color(0.85, 0.9, 0.95)  # 正常文本
	return Color(0.45, 0.45, 0.5)  # 灰（未获得）


func _on_close() -> void:
	visible = false
	closed.emit()
