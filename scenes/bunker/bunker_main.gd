extends Control
## 余烬要塞 · 主场景 v21 P2
## 侧视横剖面基地枢纽：静态背景图 + 6 层 14 房间覆盖层 + 光点主角 + HUD + 房间面板。
## 背景图由 tools/generate_bunker_bg.py 生成（assets/bunker/bunker_background.png），
## 包含星空、地表、所有房间墙壁/家具/电梯井，运行时仅叠加状态遮罩。
##
## 流程：
##   标题屏"进入基地" → 本场景
##   兵棋室(修复后) → "前往战场" → Engine meta launch_from_bunker → main.tscn
##   main.tscn 顶栏"返回"（检测 meta）→ 回本场景

const BunkerRoomDefs = preload("res://data/bunker_room_defs.gd")
const DT = preload("res://resources/design_tokens.gd")
const HeroArchiveTexts = preload("res://data/hero_archive_texts.gd")
const RoomOverlayScript = preload("res://scenes/bunker/bunker_room_overlay.gd")
const DotScript = preload("res://scenes/bunker/bunker_player_dot.gd")
const HudScript = preload("res://scenes/bunker/ui/bunker_hud.gd")
const RoomPanelScript = preload("res://scenes/bunker/ui/bunker_room_panel.gd")
const DaySummaryScript = preload("res://scenes/bunker/ui/bunker_day_summary.gd")

## P2/P3 面板迁移：房间功能 → UI 面板
const EMBEDDED_PANELS := {
	"backpack": "res://scenes/ui/backpack_panel.tscn",
	"modification": "res://scenes/ui/modification_panel.tscn",
	"evolution": "res://scenes/ui/evolution_panel.tscn",
	"growth": "res://scenes/ui/growth_panel.tscn",
	"store": "res://scenes/ui/store_panel.tscn",
	"faction": "res://scenes/ui/faction_panel.tscn",
	"afk": "res://scenes/ui/afk_panel.tscn",
	"hero_archive": "res://scenes/bunker/ui/hero_archive_panel.gd",
	"memorial": "res://scenes/bunker/ui/memorial_wall.gd",
	"intelligence": "res://scenes/ui/intelligence_hub_panel.tscn",
	"achievement": "res://scenes/ui/achievement_panel.tscn",
	"collection": "res://scenes/ui/collection_panel.tscn",
}

const BG_PATH := "res://assets/bunker/bunker_background.png"

var _manager: Node
var _room_overlays: Dictionary = {}   # room_id -> Control(bunker_room_overlay)
var _room_rects: Dictionary = {}      # room_id -> Rect2
var _dot: Node2D
var _hud: Control
var _panel: Control
var _day_summary: Control
var _embed_layer: Control
var _embed_wrappers: Dictionary = {}  # panel_id -> {"wrapper": Control, "panel": Control}
var _night_tint: ColorRect
var _stage_overlay: ColorRect
var _stage_label: Label
var _monologue_label: Label
var _monologue_timer: Timer
var _is_night := false
var _pending_room_id := ""

func _ready() -> void:
	DesignTokens.ensure_cjk_fallback()
	ManagerLazyLoader.ensure_loaded("bunker")
	_manager = ManagerLazyLoader.get_manager("bunker")
	if _manager == null:
		_manager = get_node_or_null("/root/BunkerManager")
	if _manager == null:
		push_error("[BunkerMain] BunkerManager 创建失败")
	_build_background()
	_build_rooms()
	_build_dot()
	_build_ui_layers()
	_refresh_all_rooms()
	_connect_signals()
	call_deferred("_check_sanity_zero")
	call_deferred("_check_stage_transition")

func _exit_tree() -> void:
	if _manager and _manager.has_method("stash_runtime_state"):
		_manager.stash_runtime_state()

# ───────────────────────── 背景 ─────────────────────────

func _build_background() -> void:
	var tex := load(BG_PATH) as Texture2D
	if tex == null:
		push_warning("[BunkerMain] 背景图未找到: %s，将使用空白底" % BG_PATH)
		return
	var tr := TextureRect.new()
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVER
	# 不裁剪，直接拉伸铺满（背景图本就是 1280×720，不会有变形）
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)

# ───────────────────────── 房间构建 ─────────────────────────

func _build_rooms() -> void:
	for def in BunkerRoomDefs.get_all_rooms():
		var overlay := RoomOverlayScript.new()
		var rect := _room_rect(def)
		overlay.setup(def["id"], rect.position.x, rect.position.y, rect.size.x, rect.size.y)
		overlay.room_clicked.connect(_on_room_clicked)
		add_child(overlay)
		_room_overlays[def["id"]] = overlay
		_room_rects[def["id"]] = rect

func _room_rect(def: Dictionary) -> Rect2:
	var grid: Dictionary = BunkerRoomDefs.GRID
	var row: int = int(def["row"])
	var col: int = int(def["col"])
	var room_size: Vector2 = grid["room_size"]
	if col < 0:
		return Rect2(Vector2((1280.0 - grid["wide_size"].x) * 0.5, grid["row_y"][row]), grid["wide_size"])
	return Rect2(Vector2(grid["col_x"][col], grid["row_y"][row]), room_size)

func _refresh_all_rooms() -> void:
	if _manager == null:
		return
	for room_id in _room_overlays:
		_refresh_room(room_id)

func _refresh_room(room_id: String) -> void:
	if _manager == null or not _room_overlays.has(room_id):
		return
	var overlay := _room_overlays[room_id]
	if overlay.has_method("refresh"):
		overlay.refresh(
			_manager.get_room_state(room_id),
			_manager.get_room_level(room_id),
			_manager.get_room_progress(room_id),
			_manager.is_repair_frozen(room_id))

# ───────────────────────── 光点主角 ─────────────────────────

func _build_dot() -> void:
	_dot = DotScript.new()
	var entry_center: Vector2 = _room_rects["entry_hall"].get_center()
	_dot.position = entry_center
	_dot.arrived.connect(_on_dot_arrived)
	add_child(_dot)

func _on_room_clicked(room_id: String) -> void:
	if not _room_rects.has(room_id):
		return
	_pending_room_id = room_id
	_monologue_timer.stop()
	var target: Vector2 = (_room_rects[room_id] as Rect2).get_center()
	_dot.move_to(_path_to(target))

func _path_to(target: Vector2) -> Array:
	var grid: Dictionary = BunkerRoomDefs.GRID
	var from: Vector2 = _dot.position
	if absf(from.y - target.y) < 2.0:
		return [target] if absf(from.x - target.x) > 1.0 else []
	var waypoints: Array = []
	if absf(from.x - float(grid["elevator_x"])) > 1.0:
		waypoints.append(Vector2(grid["elevator_x"], from.y))
	waypoints.append(Vector2(grid["elevator_x"], target.y))
	if absf(target.x - float(grid["elevator_x"])) > 1.0:
		waypoints.append(target)
	return waypoints

func _on_dot_arrived() -> void:
	_refresh_all_rooms()
	if not _pending_room_id.is_empty() and _panel != null:
		var def := BunkerRoomDefs.get_room(_pending_room_id)
		_panel.open_room(def, _manager)
	_pending_room_id = ""
	_monologue_timer.start()

# ───────────────────────── UI 层 ─────────────────────────

func _build_ui_layers() -> void:
	_night_tint = ColorRect.new()
	_night_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_night_tint.color = Color(0.01, 0.02, 0.06, 0.0)
	_night_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_night_tint)

	_monologue_label = Label.new()
	_monologue_label.anchor_left = 0.1
	_monologue_label.anchor_right = 0.9
	_monologue_label.anchor_top = 0.90
	_monologue_label.anchor_bottom = 0.97
	_monologue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_monologue_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_LARGE)
	_monologue_label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.95, 0.85))
	_monologue_label.modulate.a = 0.0
	_monologue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_monologue_label)

	_monologue_timer = Timer.new()
	_monologue_timer.wait_time = 5.0
	_monologue_timer.one_shot = true
	_monologue_timer.timeout.connect(_show_monologue)
	add_child(_monologue_timer)

	_panel = RoomPanelScript.new()
	_panel.close_requested.connect(func():
		_panel.call("close")
		_monologue_timer.start())
	_panel.sleep_requested.connect(_on_sleep)
	_panel.go_to_battle_requested.connect(_on_go_to_battle)
	_panel.repair_started.connect(func(room_id: String):
		_refresh_room(room_id))
	_panel.panel_action_done.connect(func():
		_hud.call("refresh_sanity", _manager.get_sanity())
		_hud.call("refresh_all_day_state")
		_sync_dot_sanity())
	_panel.open_embedded_panel_requested.connect(_open_embedded_panel)
	add_child(_panel)

	_embed_layer = Control.new()
	_embed_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_embed_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_embed_layer)

	_day_summary = DaySummaryScript.new()
	_day_summary.closed.connect(func():
		_day_summary.call("close")
		_check_stage_transition())
	add_child(_day_summary)

	_stage_overlay = ColorRect.new()
	_stage_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_stage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage_overlay)
	_stage_label = Label.new()
	_stage_label.anchor_left = 0.15
	_stage_label.anchor_right = 0.85
	_stage_label.anchor_top = 0.42
	_stage_label.anchor_bottom = 0.58
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stage_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_TITLE)
	_stage_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.72))
	_stage_label.modulate.a = 0.0
	_stage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage_label)

	_hud = HudScript.new()
	_hud.back_to_title_requested.connect(_on_back_to_title)
	_hud.debug_resources_requested.connect(_on_debug_resources)
	add_child(_hud)
	if _manager:
		_hud.call("refresh_day", _manager.get_day())
		_hud.call("refresh_sanity", _manager.get_sanity())

func _connect_signals() -> void:
	if SignalBus:
		if not SignalBus.bunker_room_state_changed.is_connected(_on_room_state_changed):
			SignalBus.bunker_room_state_changed.connect(_on_room_state_changed)

func _on_room_state_changed(room_id: String, _new_state: int) -> void:
	_refresh_room(room_id)

# ───────────────────────── 日循环 ─────────────────────────

func _on_sleep() -> void:
	if _manager == null:
		return
	_panel.call("close")
	_is_night = true
	var tween := create_tween()
	tween.tween_property(_night_tint, "color:a", 0.42, 0.7)
	tween.tween_callback(func():
		var summary: Dictionary = _manager.sleep()
		_hud.call("refresh_day", int(summary.get("day", 1)))
		_hud.call("refresh_sanity", float(summary.get("sanity_after", 100.0)))
		_sync_dot_sanity()
		if SaveManager and SaveManager.has_method("save_game"):
			SaveManager.save_game()
		_day_summary.call("open", summary))
	tween.tween_interval(0.6)
	tween.tween_property(_night_tint, "color:a", 0.0, 0.9)
	_is_night = false

# ───────────────────── P2: 嵌入面板 ─────────────────────

func _open_embedded_panel(panel_id: String) -> void:
	if not EMBEDDED_PANELS.has(panel_id):
		return
	_panel.call("close")
	var wrapper: Control = _ensure_embed_wrapper(panel_id)
	if wrapper == null:
		return
	wrapper.visible = true
	var p: Control = _embed_wrappers[panel_id]["panel"]
	if p.has_method("refresh"):
		p.call("refresh")

func _ensure_embed_wrapper(panel_id: String) -> Control:
	if _embed_wrappers.has(panel_id):
		return _embed_wrappers[panel_id]["wrapper"]
	var path: String = EMBEDDED_PANELS[panel_id]
	var panel: Control
	if path.ends_with(".tscn"):
		var packed: PackedScene = load(path)
		if packed == null:
			push_error("[BunkerMain] 嵌入面板加载失败: " + path)
			return null
		panel = packed.instantiate()
	else:
		var s: GDScript = load(path)
		if s == null:
			push_error("[BunkerMain] 嵌入面板脚本加载失败: " + path)
			return null
		panel = Control.new()
		panel.set_script(s)
	if panel == null:
		return null

	var wrapper := Control.new()
	wrapper.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
	wrapper.visible = false

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrapper.add_child(center)
	center.add_child(panel)

	if panel.has_signal("closed"):
		panel.closed.connect(func(): wrapper.visible = false)
	_embed_layer.add_child(wrapper)
	_embed_wrappers[panel_id] = {"wrapper": wrapper, "panel": panel}
	return wrapper

# ───────────────────── P2: 精神归零 ─────────────────────

func _check_sanity_zero() -> void:
	if _manager == null or _dot == null:
		return
	if _manager.get_sanity() > 0.5:
		return
	_dot.position = (_room_rects["dormitory"] as Rect2).get_center()
	_monologue_label.text = "精神耗尽。陈末几乎是爬着回到床边的。"
	var tween := create_tween()
	tween.tween_property(_monologue_label, "modulate:a", 1.0, 0.6)
	tween.tween_interval(2.6)
	tween.tween_property(_monologue_label, "modulate:a", 0.0, 0.8)
	_on_room_clicked("dormitory")

func _sync_dot_sanity() -> void:
	if _manager and _dot:
		_dot.call("set_sanity_tier", _manager.sanity_tier())

# ───────────────────── P3: 情感阶段切换 ─────────────────────

func _check_stage_transition() -> void:
	if _manager == null or _stage_overlay == null:
		return
	var stage: int = _manager.consume_stage_transition()
	if stage <= 0:
		return
	var titles: Dictionary = HeroArchiveTexts.STAGE_TITLES
	if not titles.has(stage):
		return
	_stage_label.text = str(titles[stage])
	_stage_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_stage_overlay, "color:a", 0.88, 1.0)
	tween.parallel().tween_property(_stage_label, "modulate:a", 1.0, 0.8).set_delay(0.7)
	tween.tween_interval(2.4)
	tween.parallel().tween_property(_stage_label, "modulate:a", 0.0, 0.8)
	tween.tween_property(_stage_overlay, "color:a", 0.0, 1.0)
	tween.tween_callback(func():
		_stage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE)

# ───────────────────── 发呆独白 ─────────────────────

func _show_monologue() -> void:
	if _manager == null:
		return
	var stage: int = _manager.get_narrative_stage()
	var pool: Array = BunkerRoomDefs.STAGE_MONOLOGUES.get(stage, [])
	if pool.is_empty():
		return
	var text := str(pool[randi() % pool.size()])
	_monologue_label.text = text
	var tween := create_tween()
	tween.tween_property(_monologue_label, "modulate:a", 1.0, 0.8)
	tween.tween_interval(3.6)
	tween.tween_property(_monologue_label, "modulate:a", 0.0, 1.0)

# ───────────────────── 导航 ─────────────────────

func _on_go_to_battle() -> void:
	_panel.call("close")
	Engine.set_meta("launch_from_bunker", true)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_back_to_title() -> void:
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")

func _on_debug_resources() -> void:
	if _manager and _manager.has_method("debug_grant_resources"):
		_manager.debug_grant_resources()
		_hud.call("refresh_all_day_state")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		if _monologue_timer and not _monologue_timer.is_stopped():
			_monologue_timer.start()
