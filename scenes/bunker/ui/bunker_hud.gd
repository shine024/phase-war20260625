extends Control
## 余烬要塞 · 顶部 HUD v21 P2
## 天数 / 精神值条 / 四资源实时读数 / 返回标题
## 数据源：BunkerManager（天数/精神值） + BasicResourceManager（资源，autoload）

signal back_to_title_requested

const BunkerRoomDefs = preload("res://data/bunker_room_defs.gd")
const DT = preload("res://resources/design_tokens.gd")

var _day_label: Label
var _sanity_label: Label
var _sanity_fill: ColorRect
var _res_labels: Dictionary = {}   # short_id -> Label
var _back_btn: Button
var _collect_btn: Button           # v23.6(归仓)：一键收取全部战利品

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size = Vector2(0, 44)
	_build()
	_refresh_all()
	# 资源变化即时刷新
	if BasicResourceManager and not BasicResourceManager.resources_changed.is_connected(_refresh_resources):
		BasicResourceManager.resources_changed.connect(_refresh_resources)
	# v23.6(归仓)：暂存池有存货才显示"收取全部"
	var dm := _drop_manager()
	if dm != null and dm.has_signal("escrow_changed"):
		if not dm.escrow_changed.is_connected(_on_escrow_changed):
			dm.escrow_changed.connect(_on_escrow_changed)
	_refresh_collect_btn()

func _drop_manager() -> Node:
	ManagerLazyLoader.ensure_loaded("drop")
	return get_node_or_null("/root/DropManager")

func _build() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size = Vector2(0, 44)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.024, 0.033, 0.055, 0.92)
	sb.border_width_bottom = 1
	sb.border_color = Color(DT.COLOR_ACCENT_CYAN, 0.25)   # v23.6.1 青色收口 token
	sb.content_margin_top = 4      # 顶部 4px 内边距，避免文字贴顶
	bar.add_theme_stylebox_override("panel", sb)
	add_child(bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	bar.add_child(row)

	# ── 左：天数/时段 ──
	_day_label = Label.new()
	_day_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM)
	_day_label.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	_day_label.custom_minimum_size = Vector2(150, 0)
	row.add_child(_day_label)

	# ── 中左：精神值 ──
	_sanity_label = Label.new()
	_sanity_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	_sanity_label.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	row.add_child(_sanity_label)
	# 精神条（120×10，青→紫渐变分段简化为纯色随档位）
	var sanity_bar := ColorRect.new()
	sanity_bar.color = Color(0, 0, 0, 0.5)
	sanity_bar.custom_minimum_size = Vector2(120, 10)
	row.add_child(sanity_bar)
	_sanity_fill = ColorRect.new()
	_sanity_fill.color = Color(0, 0.941, 1, 0.9)
	_sanity_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	sanity_bar.add_child(_sanity_fill)

	# ── 弹性间隔 ──
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	# ── 中右：四资源 ──
	for short_id in ["nano", "alloy", "crystal", "energy"]:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
		row.add_child(lbl)
		_res_labels[short_id] = lbl

	# ── 右：收取全部（归仓暂存非空时显示）+ 返回 ──
	_collect_btn = Button.new()
	_collect_btn.text = "收取全部"
	_collect_btn.visible = false
	_collect_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_collect_btn.pressed.connect(_on_collect_all_pressed)
	row.add_child(_collect_btn)
	_back_btn = Button.new()
	_back_btn.text = "返回标题"
	_back_btn.pressed.connect(func(): back_to_title_requested.emit())
	row.add_child(_back_btn)


# ───────────────────── v23.6(归仓)：一键收取 ─────────────────────

func _refresh_collect_btn() -> void:
	if _collect_btn == null:
		return
	var dm := _drop_manager()
	_collect_btn.visible = dm != null and dm.has_method("get_escrow_total_count") \
		and dm.get_escrow_total_count() > 0

func _on_escrow_changed() -> void:
	_refresh_collect_btn()

func _on_collect_all_pressed() -> void:
	var dm := _drop_manager()
	if dm == null or not dm.has_method("collect_escrow"):
		return
	var collected: Array = dm.collect_escrow()
	if collected.is_empty():
		_refresh_collect_btn()
		return
	var parts: Array[String] = []
	var rest: int = 0
	for i in range(collected.size()):
		var entry: Dictionary = collected[i]
		if i < 4:
			parts.append("%s×%d" % [String(entry.get("name", "??")), int(entry.get("count", 0))])
		else:
			rest += 1
	var text := "已收取全部：" + " · ".join(parts)
	if rest > 0:
		text += " 等 %d 项" % rest
	if SignalBus != null:
		if SignalBus.has_signal("show_toast"):
			SignalBus.show_toast.emit(text)
		if SignalBus.has_signal("play_sound"):
			SignalBus.play_sound.emit("quest_complete")

## ───────────────────── 刷新 ─────────────────────
## 天数/精神值由 bunker_main 在状态变化时主动调用（manager 引用在那边）

func refresh_day(day: int) -> void:
	_day_label.text = "第 %d 天" % day

func refresh_sanity(sanity: float) -> void:
	_sanity_label.text = "精神 %d" % int(round(sanity))
	var frac := clampf(sanity / 100.0, 0.0, 1.0)
	# fill 用 anchor 比例铺开
	_sanity_fill.anchor_right = frac
	_sanity_fill.anchor_left = 0.0
	if sanity < 30.0:
		_sanity_fill.color = Color(0.55, 0.35, 0.96, 0.95)   # 低精神偏紫
	elif sanity < 50.0:
		_sanity_fill.color = Color(0.55, 0.65, 0.9, 0.95)
	else:
		_sanity_fill.color = Color(DT.COLOR_ACCENT_CYAN, 0.9)   # v23.6.1 青色收口 token

func _refresh_resources() -> void:
	if BasicResourceManager == null:
		return
	for short_id in _res_labels:
		var total: int = BasicResourceManager.get_total(BunkerRoomDefs.res_full_id(short_id))
		var names := {"nano": "纳米", "alloy": "合金", "crystal": "水晶", "energy": "能量块"}
		(_res_labels[short_id] as Label).text = "%s %d" % [names[short_id], total]

func refresh_all_day_state() -> void:
	_refresh_all()

func _refresh_all() -> void:
	_refresh_resources()
