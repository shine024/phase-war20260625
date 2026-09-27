extends PanelContainer
## 卡牌图鉴面板 v7.x(A1)
## 数据源：CardCollectionManager（收集状态/里程碑）+ DefaultCards（全集）+ InstanceRegistry（实际拥有兜底）
## 范式参考：modification_panel.gd（左列表+右详情，signal closed / show_panel）

signal closed

const DefaultCards = preload("res://data/default_cards.gd")
const DT = preload("res://resources/design_tokens.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")
const PanelChrome = preload("res://scenes/ui/components/panel_chrome.gd")

var _selected_card_id: String = ""
# v8.x 性能：on_overlay_opened 拆帧重入守卫
var _open_refresh_inflight: bool = false

@onready var _progress_lbl: Label = $Margin/VBox/ProgressRow/ProgressLabel
@onready var _progress_bar: ProgressBar = $Margin/VBox/ProgressRow/ProgressBar
@onready var _rarity_row: HBoxContainer = $Margin/VBox/RarityRow
@onready var _milestone_lbl: Label = $Margin/VBox/MilestoneRow/MilestoneLabel
@onready var _card_list: VBoxContainer = $Margin/VBox/ContentHBox/LeftVBox/CardScroll/CardList
@onready var _detail_name: Label = $Margin/VBox/ContentHBox/RightVBox/DetailScroll/DetailVBox/DetailName
@onready var _detail_status: Label = $Margin/VBox/ContentHBox/RightVBox/DetailScroll/DetailVBox/DetailStatus
@onready var _detail_info: Label = $Margin/VBox/ContentHBox/RightVBox/DetailScroll/DetailVBox/DetailInfo


func _ready() -> void:
	# v7.x 面板统一：MEDIUM 档 + 科技青签名框架 + PanelChrome 标题栏（右上 ✕ 关闭）
	custom_minimum_size = DT.PANEL_SIZE_MEDIUM
	var accent := DT.get_panel_accent("collection")
	add_theme_stylebox_override("panel", PanelStyles.make_panel_frame_textured(accent))
	var chrome = PanelChrome.attach_to($Margin/VBox, "生灵图鉴", accent, "收藏档案")
	chrome.closed.connect(_on_close)
	# v32.3 E3：详情区顶部大卡图（插到 DetailName 之前，懒建一次）
	_detail_icon = TextureRect.new()
	_detail_icon.custom_minimum_size = Vector2(0, 170)
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var _detail_vbox := get_node_or_null("Margin/VBox/ContentHBox/RightVBox/DetailScroll/DetailVBox")
	if _detail_vbox != null:
		_detail_vbox.add_child(_detail_icon)
		_detail_vbox.move_child(_detail_icon, 0)
	# v7.x 性能：CardCollectionManager 延迟加载，面板初始化时确保已实例化（否则本地信号连不上）
	var _mll: Node = get_node_or_null("/root/ManagerLazyLoader")
	if _mll and _mll.has_method("ensure_loaded"):
		_mll.ensure_loaded("card_collection")
	# 刷新订阅：blueprint_unlocked 是主路径；CardCollectionManager 本地信号兜底；
	# card_added_to_backpack 覆盖"已拥有但未触发解锁信号"的卡（ InstanceRegistry 兜底判断）。
	if SignalBus:
		# 2026-08-22：原 blueprint_unlocked 信号已移除，入包信号即收集刷新源
		if not SignalBus.card_added_to_backpack.is_connected(_on_collection_changed):
			SignalBus.card_added_to_backpack.connect(_on_collection_changed)
	# v38.x O 条: 容器宽度变化（面板缩放/分辨率切换）防抖重排卡格列数
	if not _card_list.resized.is_connected(_on_card_list_resized):
		_card_list.resized.connect(_on_card_list_resized)
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
# 而该调用由 card_added_to_backpack 信号触发——历史存量卡可能未触发信号，
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
	# 稀有度色块——口径与头部"已收集"同源（_is_owned 重算）。此前读 CardCollectionManager
	# 的 _collection_data，新档已拥有但未触发解锁信号的卡不计 → 页签恒 0/N 与头部 3/332 打架
	# （2026-09-20 全矩阵报告 review 项核销）。分组映射与 card_collection_manager 同表。
	if _rarity_row:
		for child in _rarity_row.get_children():
			child.queue_free()
		var en_to_cn := {
			"common": "普通", "uncommon": "普通", "rare": "稀有",
			"epic": "史诗", "legendary": "传说", "mythic": "神话",
		}
		var rarity_groups := {}
		for cid in all_ids:
			var card = DefaultCards.get_card_by_id(String(cid))
			var group: String = en_to_cn.get(String(card.rarity), "普通") if card != null else "普通"
			if not rarity_groups.has(group):
				rarity_groups[group] = {"total": 0, "owned": 0}
			rarity_groups[group]["total"] += 1
			if _is_owned(String(cid)):
				rarity_groups[group]["owned"] += 1
		for rarity in ["普通", "稀有", "史诗", "传说", "神话"]:
			var s: Dictionary = rarity_groups.get(rarity, {"total": 0, "owned": 0})
			var lbl := Label.new()
			lbl.text = "%s %d/%d" % [rarity, int(s.get("owned", 0)), int(s.get("total", 0))]
			lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
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
	# v32.3 E3：卡图网格化（原单列 220×34 纯文字按钮流无收集欲）——每组标题+自适应列卡格；
	# 拥有=真彩卡图+稀有度描边，未获得=黑影+？？？（收集目标感）
	# v38.x O 条: 列数按容器实宽自适应（原固定 5 列×118px 在窄容器溢出横滚条，实机验收⑮）。
	var avail_w: float = maxf(_card_list.size.x, 320.0)
	_card_cell_width = 118.0
	var cols: int = _card_grid_cols(avail_w)
	if cols < 4:
		_card_cell_width = 106.0
		cols = _card_grid_cols(avail_w)
	# 记录4#8：低级在前、神话垫底（原 mythic-first 与收集预期相反）
	for rarity in ["common", "uncommon", "rare", "epic", "legendary", "mythic", "普通", "稀有", "史诗", "传说", "神话"]:
		if not groups.has(rarity):
			continue
		var owned_in_group := 0
		for cid in groups[rarity]:
			if _is_owned(cid):
				owned_in_group += 1
		var header := Label.new()
		header.text = "%s  %d / %d" % [_rarity_display(rarity), owned_in_group, groups[rarity].size()]
		header.add_theme_font_size_override("font_size", 13)
		header.add_theme_color_override("font_color", _rarity_color(rarity))
		_card_list.add_child(header)
		var grid := GridContainer.new()
		grid.columns = cols
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		_card_list.add_child(grid)
		for cid in groups[rarity]:
			grid.add_child(_make_card_cell(cid))
	# 选中态保持
	if _selected_card_id.is_empty() and all_ids.size() > 0:
		_selected_card_id = all_ids[0]
	_update_cell_selection()


## v38.x O 条: 卡格列数/格宽自适应成员与公式（cols=clampi(floor((avail+6)/(cell+6)),3,6)；
## cols<4 时格宽降 106 再算一次；resized 防抖重排）
var _card_cell_width: float = 118.0
var _card_list_resize_pending: bool = false

func _card_grid_cols(avail: float) -> int:
	return clampi(int(floor((avail + 6.0) / (_card_cell_width + 6.0))), 3, 6)


func _on_card_list_resized() -> void:
	if _card_list_resize_pending:
		return
	_card_list_resize_pending = true
	var timer := get_tree().create_timer(0.3)
	timer.timeout.connect(func():
		_card_list_resize_pending = false
		if _card_list != null and is_instance_valid(_card_list):
			_refresh_card_list())


## v32.3 E3：单卡格（118×132：72px 卡图 + 名字行，v38.x O 条格宽自适应）——拥有亮卡图，未获得黑影+问号
func _make_card_cell(card_id: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(_card_cell_width, 132)
	btn.set_meta("cell_card_id", card_id)
	var card = DefaultCards.get_card_by_id(card_id) if DefaultCards else null
	var owned := _is_owned(card_id)
	# 描边：稀有度色（拥有）/ 暗灰（未获得）
	var border: Color = DT.COLOR_SLOT_LOCKED
	if card != null:
		border = card.get_rarity_color() if owned else Color(card.get_rarity_color().r, card.get_rarity_color().g, card.get_rarity_color().b, 0.28)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.13, 0.85) if owned else Color(0.04, 0.05, 0.08, 0.72)
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	var sb_h := sb.duplicate()
	sb_h.border_color = DT.COLOR_ACCENT_CYAN if not owned else border.lightened(0.25)
	sb_h.bg_color = Color(0.09, 0.13, 0.19, 0.92)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_h)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# 内容：卡图 + 名字
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_top = 6.0
	vbox.offset_bottom = -4.0
	vbox.offset_left = 5.0
	vbox.offset_right = -5.0
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 3)
	btn.add_child(vbox)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(0, 84)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex: Texture2D = UiAssetLoader.card_icon_for_list(card) if card != null else null
	if tex != null:
		icon.texture = tex
		# 未获得 → 黑影剪影（保留轮廓神秘感）
		icon.modulate = Color.WHITE if owned else Color(0.05, 0.07, 0.10, 0.92)
	vbox.add_child(icon)
	var name_lbl := Label.new()
	name_lbl.text = _card_display_name(card_id) if owned else "？？？"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color",
		DT.COLOR_GOLD if _is_max_level(card_id) else (DT.COLOR_TEXT_BRIGHT if owned else Color(DT.COLOR_TEXT_DIM.r, DT.COLOR_TEXT_DIM.g, DT.COLOR_TEXT_DIM.b, 0.75)))
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)
	# tooltip：拥有=档案一句话；未获得=获取指向
	if owned:
		var st := "★ 已满级" if _is_max_level(card_id) else "已拥有"
		btn.tooltip_text = "%s · %s · %s" % [_card_display_name(card_id),
			_rarity_display(str(card.rarity)) if card != null else "",
			GameConstants.get_era_name(card.era) if card != null else ""] + "\n" + st
	else:
		btn.tooltip_text = "未获得——击败该敌形积累情报（25% 解锁配方），或在制造舱直接生产"
	btn.pressed.connect(func() -> void:
		_selected_card_id = card_id
		_update_cell_selection()
		_refresh_detail())
	return btn


## v32.3 E3：选中态（描边加亮），只改样式不重建（避免 ~250 格全量重刷）
func _update_cell_selection() -> void:
	for child in _card_list.get_children():
		if child is GridContainer:
			for cell in child.get_children():
				if cell is Button and cell.has_meta("cell_card_id"):
					var is_sel: bool = String(cell.get_meta("cell_card_id")) == _selected_card_id
					cell.set_meta("cell_selected", is_sel)
					var sb: StyleBoxFlat = cell.get_theme_stylebox("normal")
					if sb != null:
						sb.set_border_width_all(2 if is_sel else 1)


func _refresh_detail() -> void:
	if _selected_card_id.is_empty():
		if _detail_name:
			_detail_name.text = "请选择一张卡牌"
		if _detail_status:
			_detail_status.text = ""
		if _detail_info:
			_detail_info.text = ""
		_update_detail_icon(null, false)
		return
	var card = DefaultCards.get_card_by_id(_selected_card_id) if DefaultCards else null
	# 记录5#5/#14：未获得的卡按情报度遮蔽——此前详情面板无条件给真名+全属性，
	# 与列表格（？？？+剪影）不一致。现未获得 = 名字？？？+数值属性遮蔽，
	# 仅保留类型/兵种/时代等图鉴分类学信息；获得后逐项解锁。
	var owned := _is_owned(_selected_card_id)
	if _detail_name:
		_detail_name.text = _card_display_name(_selected_card_id) if owned else "？？？"
	# 状态
	var status_text: String = ""
	if owned and _is_max_level(_selected_card_id):
		status_text = "★ 已满级"
	elif owned:
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
		lines.append("卡牌类型：%s" % GameConstants.get_card_type_name(card.card_type))
		lines.append("兵种：%s" % CardResource.get_combat_kind_name(card.combat_kind))
		lines.append("时代：%s" % GameConstants.get_era_name(card.era))
		if owned:
			lines.append("战力：%d" % int(card.power))
			# 三维攻防（若存在）
			if card.attack_light > 0.0:
				lines.append("轻装攻击：%s" % str(card.attack_light))
			if card.attack_armor > 0.0:
				lines.append("装甲攻击：%s" % str(card.attack_armor))
			if card.attack_air > 0.0:
				lines.append("空中攻击：%s" % str(card.attack_air))
			if card.base_hp > 0.0:
				lines.append("生命值：%s" % str(card.base_hp))
		else:
			lines.append("战力：？？？（获得后解锁）")
			lines.append("详细属性：？？？（获得后解锁）")
		info = "\n".join(lines)
	if _detail_info:
		_detail_info.text = info
	# v32.3 E3：详情大卡图（未获得显示剪影）
	var tex: Texture2D = UiAssetLoader.card_icon_for_list(card) if card != null else null
	_update_detail_icon(tex, owned)


## v32.3 E3：详情区顶部大卡图（懒建一次，之后只换纹理/明暗）
var _detail_icon: TextureRect = null

func _update_detail_icon(tex: Texture2D, owned: bool) -> void:
	if _detail_icon == null:
		return
	if tex != null:
		_detail_icon.texture = tex
		_detail_icon.modulate = Color.WHITE if owned else Color(0.05, 0.07, 0.10, 0.92)
		_detail_icon.visible = true
	else:
		_detail_icon.visible = false


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
	# v9 perf：隐藏时跳过——战后掉落逐张 emit，同帧 N 次全量重建所有卡牌行；
	# 打开路径 on_overlay_opened 全量刷新，不漏内容
	if not is_visible_in_tree():
		return
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
		"common", "普通": return DT.COLOR_RARITY_COMMON
		"uncommon": return DT.COLOR_RARITY_UNCOMMON
		"rare", "稀有": return DT.COLOR_RARITY_RARE
		"epic", "史诗": return DT.COLOR_RARITY_EPIC
		"legendary", "传说": return DT.COLOR_RARITY_LEGENDARY
		"mythic", "神话": return DT.COLOR_RARITY_MYTHIC
		_: return DT.COLOR_TEXT_MID


func _status_color(card_id: String) -> Color:
	if _is_max_level(card_id):
		return DT.COLOR_GOLD
	if _is_owned(card_id):
		return DT.COLOR_TEXT_BRIGHT
	return Color(DT.COLOR_TEXT_DIM.r, DT.COLOR_TEXT_DIM.g, DT.COLOR_TEXT_DIM.b, 0.8)  # 灰（未获得）


func _on_close() -> void:
	visible = false
	closed.emit()
