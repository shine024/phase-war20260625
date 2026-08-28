extends Control
## 余烬要塞 · 主场景 v21 P2
## 侧视横剖面基地枢纽：星空地表带 + 6 层 14 房间 + 电梯井 + 光点主角 + HUD + 房间面板。
##
## 流程：
##   标题屏"进入基地" → 本场景
##   兵棋室(修复后) → "前往战场" → Engine meta launch_from_bunker → main.tscn
##   main.tscn 顶栏"返回"（检测 meta）→ 回本场景

const BunkerRoomDefs = preload("res://data/bunker_room_defs.gd")
const DT = preload("res://resources/design_tokens.gd")
const HeroArchiveTexts = preload("res://data/hero_archive_texts.gd")
const RoomOverlayScript = preload("res://scenes/bunker/bunker_room_overlay.gd")
const AmbientScript = preload("res://scenes/bunker/bunker_ambient.gd")
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
	"phase_master_skill": "res://scenes/ui/phase_master_skill_panel.tscn",
	"store": "res://scenes/ui/store_panel.tscn",
	"faction": "res://scenes/ui/faction_panel.tscn",
	"afk": "res://scenes/ui/afk_panel.tscn",
	"hero_archive": "res://scenes/bunker/ui/hero_archive_panel.gd",
	"memorial": "res://scenes/bunker/ui/memorial_wall.gd",
	"intelligence": "res://scenes/ui/intelligence_hub_panel.tscn",
	"achievement": "res://scenes/ui/achievement_panel.tscn",
	"collection": "res://scenes/ui/collection_panel.tscn",
	"quest": "res://scenes/ui/quest_panel.tscn",
	"leaderboard": "res://scenes/ui/leaderboard_panel.tscn",
	"settings": "res://scenes/ui/settings_panel.tscn",
	"help": "res://scenes/ui/help_panel.tscn",
}

## 整体大背景图（tools/generate_bunker_bg_v3.py 生成，胶囊+外壳版）：
## 一体外壳（夜空+地表+岩层）+ 14 间潜艇式房间胶囊按 GRID 嵌入；
## 初始暗版含"涂黑"锁定态，运行时叠状态遮罩与全亮切片。
## 背景/房间覆盖层都按 1280×720 设计坐标绝对定位（项目 stretch=expand 画布会
## 向下扩展，全屏锚点会竖向拉抻背景造成幻影——固定尺寸即可免疫）。
const BG_PATH := "res://assets/bunker/v3/bunker_bg_v3.png"

var _manager: Node
var _room_nodes: Dictionary = {}      # room_id -> Control(bunker_room_overlay)
var _room_rects: Dictionary = {}      # room_id -> Rect2
var _dot: Node2D
var _ambient: Node2D
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
var _ui_stage: Control = null      # v22：固定 1280×720 UI 舞台（expand 画布下面板居中不漂移）
var _is_night := false
var _pending_room_id := ""
var _current_room_id := "entry_hall"   # 光点所在房（寻路 via 链起点）

func _ready() -> void:
	DesignTokens.ensure_cjk_fallback()
	ManagerLazyLoader.ensure_loaded("bunker")
	_manager = ManagerLazyLoader.get_manager("bunker")
	if _manager == null:
		_manager = get_node_or_null("/root/BunkerManager")
	if _manager == null:
		push_error("[BunkerMain] BunkerManager 创建失败")
	else:
		# 首次进入基地发放一次性应急储备（P2：替代调试按钮的经济引导）
		if _manager.has_method("maybe_grant_bootstrap"):
			_manager.maybe_grant_bootstrap()
	_build_big_background()
	# 氛围动画层：先挂节点（画序在房间覆盖层之下），rooms 建好后再注入矩形
	_ambient = AmbientScript.new()
	add_child(_ambient)
	_build_rooms()
	_ambient.setup(_manager, _room_rects)
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

## 整体大背景图铺底：场景内已有 BG 节点（编辑器可视化用）则只补 expand 底色
func _build_big_background() -> void:
	# expand 画布比 720 高时底部会露出默认灰底——先铺一层近黑（读作地下暗部）
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.035, 0.028, 0.02)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	if has_node("BG"):
		# 场景自带 BG TextureRect（1280×720 固定，编辑器可见）。
		# ⚠️ draw 顺序=子节点索引：add_child 把底色块追加到末尾，会盖住 BG 图，
		# 运行时整张烘焙背景（星空/岩层）变黑——必须把底色块挪到最底层（index 0）。
		move_child(backdrop, 0)
		return
	var tex := load(BG_PATH) as Texture2D
	if tex == null:
		push_error("[BunkerMain] 背景图缺失: %s（先跑 tools/generate_bunker_bg_v3.py）" % BG_PATH)
		return
	var tr := TextureRect.new()
	tr.position = Vector2.ZERO
	tr.size = Vector2(1280, 720)
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)

# ───────────────────────── 房间构建 ─────────────────────────

func _build_rooms() -> void:
	for def in BunkerRoomDefs.get_all_rooms():
		# 布局唯一真身 = 场景同名占位块（编辑器可视化拖拽调整）；
		# 节点缺失时回退 defs 的 rect 兜底。
		var ph := get_node_or_null(NodePath(str(def["id"]))) as ColorRect
		var rect: Rect2 = Rect2(ph.position, ph.size) if ph != null else def["rect"]
		if ph != null:
			ph.visible = false   # 占位块仅供编辑器摆位，运行时隐藏
		var node = RoomOverlayScript.new()
		node.setup(def["id"], rect.position.x, rect.position.y, rect.size.x, rect.size.y)
		node.room_clicked.connect(_on_room_clicked)
		node.relit.connect(_on_room_relit)
		add_child(node)
		_room_nodes[def["id"]] = node
		_room_rects[def["id"]] = rect

func _refresh_all_rooms() -> void:
	if _manager == null:
		return
	for room_id in _room_nodes:
		_refresh_room(room_id)

func _refresh_room(room_id: String) -> void:
	if _manager == null or not _room_nodes.has(room_id):
		return
	_room_nodes[room_id].call("refresh",
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
	_dot.move_to(_path_to_room(room_id))

## 房间 → 竖井的离房路点序列（via 门连锁递归 → 隧道房 → 竖井直通房）。
## v22：门位/隧道线全部由矩形实时推导（占位块拖到哪，线跟到哪）——
## C 房接口 = 房中心；via 门 = 共边垂直重叠中点；隧道 = 房中心高。
func _exit_points(room_id: String) -> Array:
	var def := BunkerRoomDefs.get_room(room_id)
	if def.is_empty():
		return []
	var side := str(def.get("side", "L"))
	var rect: Rect2 = _room_rects[room_id]
	if side == "C":
		return [Vector2(_shaft_cx(), rect.get_center().y)]
	if def.has("via"):
		var via_id := str(def["via"])
		var via := BunkerRoomDefs.get_room(via_id)
		if via.is_empty():
			return []
		var via_rect: Rect2 = _room_rects[via_id]
		var door_x := rect.end.x if via_rect.position.x > rect.position.x else rect.position.x
		var door_y := (maxf(rect.position.y, via_rect.position.y)
			+ minf(rect.end.y, via_rect.end.y)) * 0.5
		var pts: Array = [Vector2(door_x, door_y), via_rect.get_center()]
		pts.append_array(_exit_points(via_id))
		return pts
	var ty := rect.get_center().y
	var door_x := rect.position.x if side == "R" else rect.end.x
	return [Vector2(door_x, ty), Vector2(_shaft_cx(), ty)]

func _shaft_cx() -> float:
	var shaft: Dictionary = BunkerRoomDefs.GRID["shaft"]
	return (float(shaft["x1"]) + float(shaft["x2"])) * 0.5

## 当前房 → 目标房 的完整路点（离房链 + 入房链反转 + 目标中心）
func _path_to_room(target_id: String) -> Array:
	var pts: Array = []
	if _current_room_id == target_id:
		var center: Vector2 = (_room_rects[target_id] as Rect2).get_center()
		return [center] if _dot.position.distance_to(center) > 1.0 else []
	pts.append_array(_exit_points(_current_room_id))
	var enter: Array = _exit_points(target_id)
	enter.reverse()
	pts.append_array(enter)
	pts.append((_room_rects[target_id] as Rect2).get_center())
	return pts

func _on_dot_arrived() -> void:
	if not _pending_room_id.is_empty():
		_current_room_id = _pending_room_id
	_refresh_all_rooms()
	if not _pending_room_id.is_empty() and _panel != null:
		var def := BunkerRoomDefs.get_room(_pending_room_id)
		_panel.open_room(def, _manager)
	_pending_room_id = ""
	_monologue_timer.start()

# ───────────────────────── UI 层 ─────────────────────────

func _build_ui_layers() -> void:
	# v22：UI 舞台——固定 1280×720 顶层容器。项目 stretch=expand 时画布会高于 720
	# （如 1028×720 窗口 → 1280×896），全屏锚点的居中容器会按 896 居中导致面板
	# 漂移/出屏；所有弹层挂进本舞台后一律按 720 设计高度居中，永不越界。
	_ui_stage = Control.new()
	_ui_stage.name = "UiStage"
	_ui_stage.position = Vector2.ZERO
	_ui_stage.size = Vector2(1280, 720)
	_ui_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui_stage)
	var stage := _ui_stage

	_night_tint = ColorRect.new()
	_night_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_night_tint.color = Color(0.01, 0.02, 0.06, 0.0)
	_night_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_night_tint)

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
	stage.add_child(_monologue_label)

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
	stage.add_child(_panel)

	_embed_layer = Control.new()
	_embed_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_embed_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_embed_layer)

	_day_summary = DaySummaryScript.new()
	_day_summary.closed.connect(func():
		_day_summary.call("close")
		_check_stage_transition())
	stage.add_child(_day_summary)

	_stage_overlay = ColorRect.new()
	_stage_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_stage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_stage_overlay)
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
	stage.add_child(_stage_label)

	_hud = HudScript.new()
	_hud.back_to_title_requested.connect(_on_back_to_title)
	stage.add_child(_hud)
	if _manager:
		_hud.call("refresh_day", _manager.get_day())
		_hud.call("refresh_sanity", _manager.get_sanity())

func _connect_signals() -> void:
	if SignalBus:
		if not SignalBus.bunker_room_state_changed.is_connected(_on_room_state_changed):
			SignalBus.bunker_room_state_changed.connect(_on_room_state_changed)

func _on_room_state_changed(room_id: String, _new_state: int) -> void:
	_refresh_room(room_id)

## 点亮演出反馈：轻微震屏（动效减弱选项下静默）
func _on_room_relit(_room_id: String) -> void:
	if DT.is_motion_reduce():
		return
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "position", Vector2(3, -2), 0.05)
	tw.tween_property(self, "position", Vector2(-3, 2), 0.06)
	tw.tween_property(self, "position", Vector2(2, -1), 0.06)
	tw.tween_property(self, "position", Vector2.ZERO, 0.08)

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
	# 伪面板路由：runes/instruments = 复用背包实例并直达对应页签（不双开面板）
	var target_id := panel_id
	if panel_id == "runes" or panel_id == "instruments":
		target_id = "backpack"
	if not EMBEDDED_PANELS.has(target_id):
		return
	_panel.call("close")
	var wrapper: Control = _ensure_embed_wrapper(target_id)
	if wrapper == null:
		return
	if target_id == "backpack":
		var bp: Control = _embed_wrappers["backpack"]["panel"]
		match panel_id:
			"runes":
				if bp.has_method("switch_to_runes_tab"):
					bp.call("switch_to_runes_tab")
			"instruments":
				if bp.has_method("switch_to_phase_instruments_tab"):
					bp.call("switch_to_phase_instruments_tab")
	wrapper.visible = true
	var p: Control = _embed_wrappers[target_id]["panel"]
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
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrapper.add_child(center)
	# 脚本型面板（.gd）根是裸 Control（min=0），会被 CenterContainer 折成 0×0
	# 挤到屏幕中心点、内容往右下溢出半屏——给满舞台最小尺寸，内部全屏锚点才能展开
	if not path.ends_with(".tscn"):
		panel.custom_minimum_size = Vector2(1280, 720)
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
	_current_room_id = "dormitory"   # 瞬移后同步房间归属，点击宿舍即达
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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		if _monologue_timer and not _monologue_timer.is_stopped():
			_monologue_timer.start()
