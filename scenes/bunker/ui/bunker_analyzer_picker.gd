extends Control
## 分析仪缴获卡选择弹窗（v26 批次3）
## 由 bunker_room_panel（档案室）动态挂载：列出背包全部缴获卡（captured_*），
## 点击即放入分析仪（manager.analyzer_insert）。ESC/遮罩点击关闭。

const DT = preload("res://resources/design_tokens.gd")

var _manager: Node = null
var _list_box: VBoxContainer = null
var _hint_label: Label = null

## equipped_ids：上阵中的卡（可显示"上阵中"角标，插入会被拒绝）
func setup(manager: Node) -> void:
	_manager = manager

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# 遮罩（点击关闭）
	var mask := ColorRect.new()
	mask.color = Color(0.0, 0.0, 0.0, 0.62)
	mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(mask)
	mask.gui_input.connect(_on_mask_input)

	# 中央面板
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(520, 460)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.13, 0.98)
	sb.set_border_width_all(1)
	sb.border_color = DT.COLOR_VIOLET
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "选择要分析的缴获卡"
	title.add_theme_font_size_override("font_size", DT.FONT_SIZE_TITLE)
	title.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "烧毁缴获卡换取情报——品质越高产出越多；同屏只能烧一张，每日限 3 张，2 场战斗后出炉。"
	sub.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	sub.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(sub)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 4)
	scroll.add_child(_list_box)

	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	vbox.add_child(_hint_label)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.pressed.connect(queue_free)
	vbox.add_child(close_btn)

	_refresh_list()

func _on_mask_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		queue_free()

func _refresh_list() -> void:
	for child in _list_box.get_children():
		child.queue_free()
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	var equipped: Array = pim.get_slot_card_ids() if pim != null and pim.has_method("get_slot_card_ids") else []
	var found := 0
	if ir != null and ir.has_method("get_all_instance_ids"):
		for iid_raw in ir.get_all_instance_ids():
			var inst: CardResource = ir.get_instance(String(iid_raw))
			if inst == null or not String(inst.card_id).begins_with("captured_"):
				continue
			_list_box.add_child(_make_row(inst, String(inst.instance_id) in equipped))
			found += 1
	if found == 0:
		var empty := Label.new()
		empty.text = "背包里没有缴获卡——出击击败敌兵、仓库打印机或地表探索可获取。"
		empty.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		empty.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
		_list_box.add_child(empty)

func _make_row(inst: CardResource, equipped: bool) -> Button:
	var row := Button.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size = Vector2(0, 40)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.075, 0.102, 0.165, 0.6)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 8
	row.add_theme_stylebox_override("normal", sb)
	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(0.653, 0.546, 0.98, 0.1)
	row.add_theme_stylebox_override("hover", sb_h)
	row.text = "%s · %s%s" % [inst.display_name, _rarity_zh(String(inst.rarity)),
		"（上阵中——先卸下）" if equipped else ""]
	row.add_theme_font_size_override("font_size", DT.FONT_SIZE_BODY)
	row.pressed.connect(_on_row_pressed.bind(String(inst.instance_id), equipped))
	return row

func _rarity_zh(r: String) -> String:
	match r:
		"common": return "普通"
		"uncommon": return "精良"
		"rare": return "稀有"
		"epic": return "史诗"
		"legendary": return "传说"
		"mythic": return "神话"
	return r

func _on_row_pressed(instance_id: String, equipped: bool) -> void:
	if _manager == null:
		return
	if equipped:
		_hint_label.text = "该卡已上阵，先卸下再分析。"
		_hint_label.add_theme_color_override("font_color", DT.COLOR_RED_DOWN)
		return
	var result: Dictionary = _manager.analyzer_insert(instance_id)
	if bool(result.get("ok", false)):
		if SignalBus and SignalBus.has_signal("show_toast"):
			SignalBus.show_toast.emit(String(result.get("reason", "已放入分析仪")))
		queue_free()
	else:
		_hint_label.text = String(result.get("reason", "无法放入"))
		_hint_label.add_theme_color_override("font_color", DT.COLOR_RED_DOWN)
