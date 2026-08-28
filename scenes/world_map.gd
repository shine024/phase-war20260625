extends Control
## 大地图：选择 1~100 关（一战 / 二战 / 冷战 / 现代 / 近未来）
## 按时代分组显示，当前关卡高亮

var _map_built: bool = false  # 地图是否已构建（缓存）
# v9 perf：隐藏期间的占领变化置脏，重新打开时补刷（见 _on_occupation_changed_refresh）
var _occupation_dirty: bool = false
static var _cached_level_map_template: Control = null  # 跨场景复用模板，避免每次重建100按钮

func _input(event: InputEvent) -> void:
	# ESC键返回主场景
	if event.is_action("ui_cancel"):
		_on_back_to_title()
		_safe_set_input_handled()
	# 检查是否是键盘事件
	elif event is InputEventKey:
		var key_event = event as InputEventKey
		if key_event.keycode == KEY_ESCAPE:
			_on_back_to_title()
			_safe_set_input_handled()

func _safe_set_input_handled() -> void:
	if not is_inside_tree():
		return
	var vp: Viewport = get_viewport()
	if vp != null and is_instance_valid(vp) and vp.is_inside_tree():
		vp.set_input_as_handled()

const LevelEras = preload("res://data/level_eras.gd")
const LevelInformation = preload("res://data/level_information.gd")
const BasicResourcesData = preload("res://data/basic_resources.gd")
const EnemyArchetypesData = preload("res://data/enemy_archetypes.gd")
const DefaultCardsData = preload("res://data/default_cards.gd")
const PhaseLawsData = preload("res://data/phase_laws.gd")
const DropTablesPreview = preload("res://resources/drop_tables.gd")
const FactionConquestBuffs = preload("res://data/faction_conquest_buffs.gd")  # v6.9: 占领势力加成描述
const CompanyDefs = preload("res://data/company_definitions.gd")  # v6.14: 统一阵营色来源
const PhaseMasterGarrison = preload("res://data/phase_master_garrison.gd")  # v7.x: Boss相位师驻守关判定
const TacticalThemes = preload("res://data/level_tactical_themes.gd")  # v10: 关卡战术主题（敌情简报）
const EnemyPhaseMasters = preload("res://data/enemy_phase_masters.gd")  # v7.x: 相位师详情查询
const BattleEnvironments = preload("res://data/battle_environments.gd")  # 2026-08-16: 环境单一真源（与 phase_law_manager/battle_damage_system 同源）
const EnemyLoadoutTiers = preload("res://data/enemy_loadout_tiers.gd")  # 2026-08-16: 难度显示单一真源（战斗链真实档位乘区）

# v6.10: 关卡按钮占领色标——势力色统一从 CompanyDefinitions.get_faction_color() 读取（Palette B）
# 无主之地兜底（右边框半透明灰）
const LEVEL_COUNT: int = LevelEras.LEVEL_COUNT
const ERA_SIZE: int = 20  # 每时代 20 关
const DEFAULT_BG_PATH: String = "res://assets/backgrounds/bg_default.png"
# 时代配色方案
const ERA_COLORS: Array = [
	{
		"name": "一战", "icon": "⚔",
		"bg":     Color(0.12, 0.08, 0.05, 0.95),
		"border": Color(0.85, 0.65, 0.3, 0.5),
		"title":  Color(0.95, 0.78, 0.45, 1.0),
		"btn_bg": Color(0.14, 0.09, 0.05, 0.85),
		"btn_active": Color(0.9, 0.65, 0.2, 1.0),
	},
	{
		"name": "二战", "icon": "✈",
		"bg":     Color(0.05, 0.09, 0.05, 0.95),
		"border": Color(0.45, 0.8, 0.35, 0.5),
		"title":  Color(0.55, 0.95, 0.45, 1.0),
		"btn_bg": Color(0.06, 0.11, 0.06, 0.85),
		"btn_active": Color(0.4, 0.95, 0.35, 1.0),
	},
	{
		"name": "冷战", "icon": "☢",
		"bg":     Color(0.05, 0.05, 0.13, 0.95),
		"border": Color(0.35, 0.55, 0.95, 0.5),
		"title":  Color(0.45, 0.7, 1.0, 1.0),
		"btn_bg": Color(0.05, 0.06, 0.15, 0.85),
		"btn_active": Color(0.4, 0.65, 1.0, 1.0),
	},
	{
		"name": "现代", "icon": "🚀",
		"bg":     Color(0.04, 0.10, 0.12, 0.95),
		"border": Color(0.0, 0.85, 0.95, 0.5),
		"title":  Color(0.2, 0.95, 1.0, 1.0),
		"btn_bg": Color(0.04, 0.12, 0.14, 0.85),
		"btn_active": Color(0.0, 0.94, 1.0, 1.0),
	},
	{
		"name": "近未来", "icon": "⚡",
		"bg":     Color(0.10, 0.04, 0.14, 0.95),
		"border": Color(0.75, 0.35, 1.0, 0.5),
		"title":  Color(0.85, 0.5, 1.0, 1.0),
		"btn_bg": Color(0.12, 0.05, 0.17, 0.85),
		"btn_active": Color(0.8, 0.45, 1.0, 1.0),
	},
]

# === v22 百灯群岛大地图（docs/地图重设计/）布局与资产常量 ===
const MAP_DIR: String = "res://assets/map/"
const MAP_VOID_PATH: String = MAP_DIR + "map_void_base.png"
const LIGHTHOUSE_TEX_PATH: String = MAP_DIR + "lighthouse_fortress.png"
const GATE_TEX_FAR: String = MAP_DIR + "gate_far.png"
const GATE_TEX_MID: String = MAP_DIR + "gate_mid.png"
const BUBCLEARED_TEX_PATH: String = MAP_DIR + "bubble_cleared.png"
const BOSS_TEX_PATH: String = MAP_DIR + "bubble_boss.png"
const BUBBLE_TEX_PATHS: Array = [
	MAP_DIR + "bubble_era_ww1.png",
	MAP_DIR + "bubble_era_ww2.png",
	MAP_DIR + "bubble_era_cold.png",
	MAP_DIR + "bubble_era_modern.png",
	MAP_DIR + "bubble_era_future.png",
]
const MAP_CANVAS_SIZE: Vector2 = Vector2(2560, 1440)
const MAP_LIGHTHOUSE_POS: Vector2 = Vector2(1280, 780)
const MAP_GATE_POS: Vector2 = Vector2(2260, 250)
## v22.3 相位两仪（方案 8）：MAP_SCHEME 切换布局。6=百灯群岛星座 / 8=沙漏双界
const MAP_SCHEME: int = 8
const SEAM_Y_S8: float = 720.0  # 相位缝：上界(现实界)1-50 / 下界(相位界)51-100 的腰部
const GATE_POS_S8: Vector2 = Vector2(1280, 1335)  # 下界底极：横卧宽门
const HOME_POS_S8: Vector2 = Vector2(330, 140)  # 上界左上漂浮岛掩体（暂用灯塔图占位）

static func _gate_pos() -> Vector2:
	return GATE_POS_S8 if MAP_SCHEME == 8 else MAP_GATE_POS

static func _home_pos() -> Vector2:
	return HOME_POS_S8 if MAP_SCHEME == 8 else MAP_LIGHTHOUSE_POS
## 五星座锚点：一战（左上）逆时针绕灯塔一圈，近未来（era4）落在巨环前庭
const ERA_CLUSTER_ANCHORS: Array = [
	Vector2(640, 420), Vector2(430, 960), Vector2(1100, 1250),
	Vector2(1800, 1100), Vector2(2110, 520),
]
const ERA_CLUSTER_RADII: Vector2 = Vector2(400, 240)
const BUBBLE_DISPLAY: float = 74.0
const BOSS_BUBBLE_DISPLAY: float = 100.0
const LIGHTHOUSE_DISPLAY_H: float = 420.0

# 静态布局/状态（模板跨实例复用时布局一致；动态状态在每次重建时刷新）
static var _s_level_points: Dictionary = {}  # level(int) -> Vector2 画布坐标
static var _s_bridges: Array = []  # [{a: Vector2, b: Vector2, era: int}]
static var _s_occ_colors: Dictionary = {}  # level(int) -> 占领势力 Color
static var _s_gate_state: String = "far"
static var _s_tex_cache: Dictionary = {}

var _overlay_layer: Control = null  # v22 overlay 绘制层（微光桥/占领环/当前关光圈）
var _pan_dragging: bool = false  # v22 拖拽平移状态

var _level_info_popup: Window = null
var _runtime_active: bool = false

## 信号：当用户点击返回主界面时发出
signal back_to_main()


func _enter_tree() -> void:
	pass

func _ready() -> void:
	# v22 百灯群岛：旧网格地图的星空/扫描线绘制退役，由 map_void_base 底图承担
	var scroll_ready := get_node_or_null("Margin/VBox/ScrollContainer") as ScrollContainer
	if scroll_ready != null and not scroll_ready.gui_input.is_connected(_on_map_gui_input):
		scroll_ready.gui_input.connect(_on_map_gui_input)
	# v22: 势力领地图入口改挂标题栏（旧实现位于滚动内容里，随网格布局退役）
	var vbox_r := get_node_or_null("Margin/VBox")
	if vbox_r != null and vbox_r.get_node_or_null("TerritoryMapButton") == null:
		var territory_btn := Button.new()
		territory_btn.name = "TerritoryMapButton"
		territory_btn.text = "◆ 势力领地图"
		territory_btn.tooltip_text = "查看100关当前占领状态（势力领地分布）"
		territory_btn.custom_minimum_size = Vector2(0, 30)
		var tbs := StyleBoxFlat.new()
		tbs.bg_color = Color(0.06, 0.1, 0.17, 0.9)
		tbs.border_width_left = 1; tbs.border_width_top = 1
		tbs.border_width_right = 1; tbs.border_width_bottom = 1
		tbs.border_color = Color(0.0, 0.75, 0.85, 0.6)
		tbs.corner_radius_top_left = 5; tbs.corner_radius_top_right = 5
		tbs.corner_radius_bottom_right = 5; tbs.corner_radius_bottom_left = 5
		territory_btn.add_theme_stylebox_override("normal", tbs)
		territory_btn.add_theme_color_override("font_color", Color(0, 0.94, 1, 1))
		territory_btn.add_theme_font_size_override("font_size", 13)
		territory_btn.pressed.connect(_on_territory_map_button)
		vbox_r.add_child(territory_btn)
		vbox_r.move_child(territory_btn, 1)  # 标题之后、地图画布之前
	# 延迟一帧再生成地图，避免启动时卡顿
	call_deferred("_build_level_map")
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()
	# v6.10: 监听占领变化，刷新关卡按钮色标（攻克易主后实时更新）
	if SignalBus and SignalBus.has_signal("occupation_changed"):
		SignalBus.occupation_changed.connect(_on_occupation_changed_refresh)

	# 多种方式尝试找到返回按钮
	var back_btn: Button = get_node_or_null("Margin/VBox/BackToTitleButton")
	if back_btn == null:
		# 尝试相对路径
		back_btn = $Margin/VBox/BackToTitleButton
	if back_btn == null:
		# 尝试直接查找
		back_btn = find_child("BackToTitleButton", true, false)

	if back_btn:
		back_btn.pressed.connect(_on_back_to_title)
		# 美化返回按钮
		_style_back_button(back_btn)
	else:
		push_warning("[WorldMap] ⚠️ 返回按钮未找到！")

	# 美化标题
	_style_title()

func _on_visibility_changed() -> void:
	_runtime_active = is_visible_in_tree()
	set_process(false)
	if _runtime_active:
		queue_redraw()

func _style_title() -> void:
	var title_l: Label = get_node_or_null("Margin/VBox/TitleLabel")
	if title_l:
		title_l.add_theme_font_size_override("font_size", 26)
		title_l.add_theme_color_override("font_color", Color(0, 0.941, 1, 1))
		title_l.text = "— 百灯群岛 · 100 道防线 —"

func _style_back_button(btn: Button) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.1, 0.17, 0.9)
	s.border_width_left = 1; s.border_width_top = 1
	s.border_width_right = 1; s.border_width_bottom = 1
	s.border_color = Color(0, 0.75, 0.85, 0.6)
	s.corner_radius_top_left = 5; s.corner_radius_top_right = 5
	s.corner_radius_bottom_right = 5; s.corner_radius_bottom_left = 5
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_color_override("font_color", Color(0, 0.94, 1, 1))
	btn.add_theme_font_size_override("font_size", 14)

func _build_level_map() -> void:
	# 缓存检查：如果地图已构建，跳过
	if _map_built:
		return
	var scroll: ScrollContainer = get_node_or_null("Margin/VBox/ScrollContainer") as ScrollContainer
	if scroll == null:
		return
	# 清空旧内容
	for c in scroll.get_children():
		c.queue_free()

	var current_level: int = GameManager.current_level if GameManager else 1
	_refresh_static_state(current_level)
	_ensure_layout()

	# 跨实例缓存命中：复用模板副本，重连信号 + 重绑 overlay + 更新巨环状态
	if _cached_level_map_template != null and is_instance_valid(_cached_level_map_template):
		var reused := _cached_level_map_template.duplicate(Node.DUPLICATE_USE_INSTANTIATION) as Control
		if reused != null:
			scroll.add_child(reused)
			_reconnect_level_buttons(reused)
			_rebind_overlay(reused)
			_apply_gate_state(reused)
			_map_built = true
			_center_on_current_level()
			return

	# v22 百灯群岛：2560×1440 平移画布——黑海底图 + 残骸 + 灯塔 + 巨环 + 5 星座泡群
	var canvas := Control.new()
	canvas.name = "MapCanvas"
	canvas.custom_minimum_size = MAP_CANVAS_SIZE
	canvas.size = MAP_CANVAS_SIZE
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(canvas)

	# 1) 黑海底图
	var bg := TextureRect.new()
	bg.name = "VoidBase"
	bg.texture = _tex(MAP_VOID_PATH)
	bg.size = MAP_CANVAS_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(bg)

	# 2) 漂浮残骸装饰（静态散布，位于节点之下）
	_scatter_debris(canvas)

	# v22.3 方案 8：下界（相位界）整体加青紫滤镜 + 相位缝光带标签（占位，待专用底图）
	if MAP_SCHEME == 8:
		var lower_tint := ColorRect.new()
		lower_tint.name = "LowerRealmTint"
		lower_tint.position = Vector2(0, SEAM_Y_S8)
		lower_tint.size = Vector2(MAP_CANVAS_SIZE.x, MAP_CANVAS_SIZE.y - SEAM_Y_S8)
		lower_tint.color = Color(0.45, 0.30, 0.95, 0.07)
		lower_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(lower_tint)
		var seam_lbl := Label.new()
		seam_lbl.text = "── 相位缝 ──"
		seam_lbl.add_theme_font_size_override("font_size", 15)
		seam_lbl.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0, 0.85))
		seam_lbl.position = Vector2(60, SEAM_Y_S8 - 24)
		seam_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(seam_lbl)

	# 3) 终局巨环（三态渐进，_apply_gate_state 设纹理/尺寸/透明度）
	var gate := TextureRect.new()
	gate.name = "GateMarker"
	gate.position = MAP_GATE_POS
	gate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(gate)
	_apply_gate_state(canvas)

	# 4) 灯塔要塞（家）
	var lh := TextureRect.new()
	lh.name = "Lighthouse"
	var lh_tex: Texture2D = _tex(LIGHTHOUSE_TEX_PATH)
	lh.texture = lh_tex
	var lh_scale: float = LIGHTHOUSE_DISPLAY_H / lh_tex.get_height()
	lh.size = Vector2(lh_tex.get_width() * lh_scale, LIGHTHOUSE_DISPLAY_H)
	lh.position = _home_pos() - lh.size * 0.5
	lh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(lh)
	var home_lbl := Label.new()
	home_lbl.text = "余烬要塞"
	home_lbl.add_theme_font_size_override("font_size", 14)
	home_lbl.add_theme_color_override("font_color", Color(1.0, 0.71, 0.37, 0.9))
	var home_lbl_off: Vector2 = Vector2(-28, lh.size.y * 0.42) if MAP_SCHEME == 6 		else Vector2(lh.size.x * 0.3, lh.size.y * 0.55)
	home_lbl.position = _home_pos() + home_lbl_off
	home_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(home_lbl)

	# 5) overlay 层：微光桥 / 占领环 / 当前关光圈（draw 信号驱动）
	_overlay_layer = Control.new()
	_overlay_layer.name = "OverlayLayer"
	_overlay_layer.size = MAP_CANVAS_SIZE
	_overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.draw.connect(_draw_map_overlay)
	canvas.add_child(_overlay_layer)

	# 6) 100 个相位泡节点 + 区标签（方案6=星座标签 / 方案8=两界大标 + 时代行标）
	if MAP_SCHEME == 8:
		for realm in range(2):
			var realm_lbl := Label.new()
			realm_lbl.text = "现实界 · 第 1–50 关" if realm == 0 else "相位界 · 第 51–100 关"
			realm_lbl.add_theme_font_size_override("font_size", 20)
			realm_lbl.add_theme_color_override("font_color",
				Color(0.9, 0.8, 0.6, 0.9) if realm == 0 else Color(0.55, 0.75, 1.0, 0.9))
			realm_lbl.position = Vector2(80, 150) if realm == 0 else Vector2(80, 1210)
			realm_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			canvas.add_child(realm_lbl)
	for era_idx in range(5):
		var era_info: Dictionary = ERA_COLORS[era_idx]
		var era_start: int = era_idx * ERA_SIZE + 1
		var zone_lbl := Label.new()
		zone_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		zone_lbl.add_theme_font_size_override("font_size", 17 if MAP_SCHEME == 6 else 15)
		zone_lbl.add_theme_color_override("font_color", era_info["title"])
		zone_lbl.modulate.a = 0.85
		if MAP_SCHEME == 6:
			zone_lbl.text = "%s %s · 第 %d–%d 关" % [era_info["icon"], era_info["name"],
				era_start, era_start + ERA_SIZE - 1]
			zone_lbl.position = ERA_CLUSTER_ANCHORS[era_idx] + Vector2(-100.0, -ERA_CLUSTER_RADII.y - 74.0)
			canvas.add_child(zone_lbl)
		else:
			var first_pt: Vector2 = _s_level_points.get(era_start, Vector2.ZERO)
			zone_lbl.text = "%s %s %d–%d%s" % [era_info["icon"], era_info["name"],
				era_start, era_start + ERA_SIZE - 1, "（跨缝）" if era_idx == 2 else ""]
			zone_lbl.position = first_pt + Vector2(-150.0, -34.0)
			canvas.add_child(zone_lbl)
			var lower_first: int = 51
			if era_idx == 2:  # 冷战下半（51-60）补一枚下界行标
				var seam_era_lbl := zone_lbl.duplicate() as Label
				seam_era_lbl.text = "%s %s 51–60" % [era_info["icon"], era_info["name"]]
				seam_era_lbl.position = _s_level_points.get(lower_first, Vector2.ZERO) + Vector2(-150.0, -34.0)
				canvas.add_child(seam_era_lbl)
		if MAP_SCHEME == 6:
			var pts: Array = _cluster_level_positions(era_idx)
			for j in range(ERA_SIZE):
				var level_index_s6: int = era_start + j
				canvas.add_child(_make_level_node(level_index_s6, era_idx, pts[j], current_level))
	for lv_s8 in range(1, LEVEL_COUNT + 1):
		if MAP_SCHEME == 8:
			var era_idx_s8: int = floori((lv_s8 - 1) / 20.0)
			canvas.add_child(_make_level_node(lv_s8, era_idx_s8,
				_s_level_points.get(lv_s8, Vector2.ZERO), current_level))
	_overlay_layer.queue_redraw()

	# 标记地图已构建（静态模板供跨场景复用）
	_cached_level_map_template = canvas.duplicate(Node.DUPLICATE_USE_INSTANTIATION) as Control
	_map_built = true
	_center_on_current_level()

# === v22 百灯群岛：布局/资产/状态辅助 ===

static func _tex(path: String) -> Texture2D:
	if not _s_tex_cache.has(path):
		_s_tex_cache[path] = load(path)
	return _s_tex_cache.get(path)

## 星座内 20 关点位：椭圆盘均匀采样 + 最小间距拒绝采样（固定种子，跨实例一致）
static func _cluster_level_positions(era_idx: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260827 + era_idx * 131
	var center: Vector2 = ERA_CLUSTER_ANCHORS[era_idx]
	var pts: Array = []
	var tries: int = 0
	while pts.size() < ERA_SIZE and tries < 4000:
		tries += 1
		var ang := rng.randf() * TAU
		var rad := sqrt(rng.randf())
		var p := center + Vector2(cos(ang) * rad * ERA_CLUSTER_RADII.x,
			sin(ang) * rad * ERA_CLUSTER_RADII.y)
		var ok := true
		for q in pts:
			if p.distance_to(q) < 132.0:
				ok = false
				break
		if ok:
			pts.append(p)
	while pts.size() < ERA_SIZE:
		pts.append(center + Vector2(rng.randf_range(-1, 1) * ERA_CLUSTER_RADII.x,
			rng.randf_range(-1, 1) * ERA_CLUSTER_RADII.y))
	return pts

## 布局只算一次（静态缓存）：节点坐标 + 微光桥连线（灯塔→L1→…→L100→巨环）
static func _ensure_layout() -> void:
	if not _s_level_points.is_empty():
		return
	if MAP_SCHEME == 8:
		_layout_scheme8()
	else:
		_layout_scheme6()

## 方案 8 沙漏双界：上界 5 行自宽收窄向相位缝（1-50），下界自缝张开向底极（51-100）。
## 时代映射：一战/二战全在上界；冷战跨缝（41-50 上 / 51-60 下）；现代/近未来全在下界。
static func _layout_scheme8() -> void:
	var cx := 1280.0
	for k in range(5):
		var y := 240.0 + k * 100.0
		var half := 950.0 - k * 130.0
		for j in range(10):
			_s_level_points[k * 10 + j + 1] = Vector2(cx - half + (2.0 * half / 9.0) * j, y)
	for k2 in range(5):
		var y2 := 800.0 + k2 * 88.0
		var half2 := 300.0 + k2 * 130.0
		for j2 in range(10):
			_s_level_points[50 + k2 * 10 + j2 + 1] = Vector2(cx - half2 + (2.0 * half2 / 9.0) * j2, y2)
	_s_bridges.append({"a": _home_pos(), "b": _s_level_points[1], "era": 0})
	for lv in range(1, LEVEL_COUNT):
		_s_bridges.append({"a": _s_level_points[lv], "b": _s_level_points[lv + 1],
			"era": floori((lv - 1) / 20.0)})
	_s_bridges.append({"a": _s_level_points[LEVEL_COUNT], "b": _gate_pos(), "era": 4})

static func _layout_scheme6() -> void:
	for era_idx in range(5):
		var pts := _cluster_level_positions(era_idx)
		for j in range(ERA_SIZE):
			_s_level_points[era_idx * ERA_SIZE + 1 + j] = pts[j]
		if era_idx == 0:
			_s_bridges.append({"a": _home_pos(), "b": pts[0], "era": 0})
		else:
			_s_bridges.append({"a": _s_level_points[era_idx * ERA_SIZE], "b": pts[0], "era": era_idx})
		for j in range(ERA_SIZE - 1):
			_s_bridges.append({"a": pts[j], "b": pts[j + 1], "era": era_idx})
	_s_bridges.append({"a": _s_level_points[LEVEL_COUNT], "b": _gate_pos(), "era": 4})

## 每次构建/刷新时重读动态状态：占领色环集合 + 巨环三态
func _refresh_static_state(current_level: int) -> void:
	_s_occ_colors.clear()
	for lv in range(1, LEVEL_COUNT + 1):
		var fid := _get_level_occupation_safe(lv)
		if not fid.is_empty():
			var c := CompanyDefs.get_faction_color(fid)
			c.a = 0.85
			_s_occ_colors[lv] = c
	_s_gate_state = _gate_state_for_level(current_level)

func _gate_state_for_level(cur: int) -> String:
	if cur >= 90:
		return "near"
	if cur >= 50:
		return "mid"
	return "far"

## 巨环三态：far 小而淡 / mid 可辨 / near 用 mid 放大 + 暖染近似
## （gate_near.png 整幅图保留给终局近接演出，不直接摆画布）
func _apply_gate_state(canvas: Control) -> void:
	var gate := canvas.get_node_or_null("GateMarker") as TextureRect
	if gate == null:
		return
	gate.texture = _tex(GATE_TEX_FAR if _s_gate_state == "far" else GATE_TEX_MID)
	if MAP_SCHEME == 8:
		# 下界底极：门横卧（竖向压扁），三档尺寸
		var disp8: Vector2 = {"far": Vector2(260, 100), "mid": Vector2(380, 140),
			"near": Vector2(520, 190)}.get(_s_gate_state, Vector2(260, 100))
		gate.size = disp8
		gate.position = GATE_POS_S8 - disp8 * 0.5
	else:
		var disp: float = 240.0 if _s_gate_state == "far" else (400.0 if _s_gate_state == "mid" else 560.0)
		gate.size = Vector2(disp, disp)
		gate.position = MAP_GATE_POS - gate.size * 0.5
	match _s_gate_state:
		"far":
			gate.modulate = Color(1, 1, 1, 0.45)
		"mid":
			gate.modulate = Color(1, 1, 1, 0.85)
		_:
			gate.modulate = Color(1.0, 0.88, 0.78, 1.0)

func _scatter_debris(canvas: Control) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260827
	for i in range(12):
		var tex := _tex(MAP_DIR + "debris_%d.png" % ((i % 8) + 1))
		if tex == null:
			continue
		var d := TextureRect.new()
		d.texture = tex
		var sc: float = rng.randf_range(0.45, 1.0)
		d.size = Vector2(tex.get_width(), tex.get_height()) * sc
		d.position = Vector2(rng.randf_range(60.0, MAP_CANVAS_SIZE.x - 160.0),
			rng.randf_range(60.0, MAP_CANVAS_SIZE.y - 160.0))
		d.rotation = rng.randf_range(-0.45, 0.45)
		d.modulate = Color(1, 1, 1, rng.randf_range(0.35, 0.6))
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(d)

func _is_level_cleared(level_index: int) -> bool:
	var lpm := get_node_or_null("/root/LevelProgressManager")
	if lpm != null and lpm.has_method("get_level_stars"):
		return lpm.get_level_stars(level_index) > 0
	return level_index < (GameManager.current_level if GameManager else 1)

## overlay 绘制：微光桥（时代色虚线）+ 占领色环 + 当前关青色光圈
func _draw_map_overlay() -> void:
	var layer := _overlay_layer
	if layer == null or not is_instance_valid(layer):
		return
	for br in _s_bridges:
		var col: Color = ERA_COLORS[br["era"]]["border"]
		col.a = 0.32
		_draw_dashed(layer, br["a"], br["b"], col, 1.5, 10.0, 6.0)
	if MAP_SCHEME == 8:
		# 相位缝光带：三层辉光 + 中心亮线
		var seam_a := Vector2(0, SEAM_Y_S8)
		var seam_b := Vector2(MAP_CANVAS_SIZE.x, SEAM_Y_S8)
		layer.draw_line(seam_a, seam_b, Color(0.0, 0.9, 1.0, 0.06), 14.0)
		layer.draw_line(seam_a, seam_b, Color(0.0, 0.9, 1.0, 0.14), 6.0)
		layer.draw_line(seam_a, seam_b, Color(0.55, 0.95, 1.0, 0.55), 2.0)
	for lv in _s_occ_colors:
		var p: Vector2 = _s_level_points.get(lv, Vector2.ZERO)
		if p != Vector2.ZERO:
			layer.draw_arc(p, 46.0, 0.0, TAU, 40, _s_occ_colors[lv], 2.5)
	var cur: int = GameManager.current_level if GameManager else 1
	var cp: Vector2 = _s_level_points.get(cur, Vector2.ZERO)
	if cp != Vector2.ZERO:
		layer.draw_arc(cp, 52.0, 0.0, TAU, 48, Color(0.0, 0.9, 1.0, 0.9), 2.5)
		layer.draw_arc(cp, 58.0, 0.0, TAU, 48, Color(0.0, 0.9, 1.0, 0.35), 1.5)

func _draw_dashed(layer: Control, a: Vector2, b: Vector2, color: Color,
		width: float, dash: float, gap: float) -> void:
	var total := a.distance_to(b)
	if total <= 1.0:
		return
	var dir := (b - a) / total
	var t := 0.0
	while t < total:
		var t2 := minf(t + dash, total)
		layer.draw_line(a + dir * t, a + dir * t2, color, width)
		t = t2 + gap

## 模板复用时重绑 overlay 的 draw 信号到当前实例（旧连接指向已释放实例）
func _rebind_overlay(root: Node) -> void:
	var layer := root.get_node_or_null("OverlayLayer") as Control
	if layer == null:
		return
	_overlay_layer = layer
	for conn in layer.draw.get_connections():
		layer.draw.disconnect(conn.callable)
	layer.draw.connect(_draw_map_overlay)
	layer.queue_redraw()

## 构建完成后把视口居中到当前关（等一帧让 ScrollContainer 尺寸就绪）
func _center_on_current_level() -> void:
	await get_tree().process_frame
	var scroll := get_node_or_null("Margin/VBox/ScrollContainer") as ScrollContainer
	if scroll == null or not is_inside_tree():
		return
	var cur: int = clampi(GameManager.current_level if GameManager else 1, 1, LEVEL_COUNT)
	# 截图/测试辅助：WM_VIEW_LEVEL=N 时视口居中到第 N 关（跳过定场镜头）
	if OS.has_environment("WM_VIEW_LEVEL"):
		cur = clampi(int(OS.get_environment("WM_VIEW_LEVEL")), 1, LEVEL_COUNT)
	var p: Vector2 = _s_level_points.get(cur, MAP_LIGHTHOUSE_POS)
	if cur <= 3 and not OS.has_environment("WM_VIEW_LEVEL"):
		# 新档定场镜头：方案6 看灯塔与巨环；方案8 看上界战线+相位缝（含家）
		p = Vector2(800, 420) if MAP_SCHEME == 8 else MAP_LIGHTHOUSE_POS.lerp(MAP_GATE_POS, 0.45)
	scroll.set_h_scroll(int(p.x - scroll.size.x * 0.5))
	scroll.set_v_scroll(int(p.y - scroll.size.y * 0.5))

## v7.5: 静态模板复用时重新连接关卡按钮的 pressed 信号到当前实例。
## v22: 节点改用 TextureButton（相位泡），按 BaseButton 检索；势力领地图按钮已改挂标题栏（非模板内）。
func _reconnect_level_buttons(root: Node) -> void:
	var buttons := root.find_children("*", "BaseButton", true, false)
	for btn in buttons:
		if not (btn is BaseButton):
			continue
		var nm: String = btn.name
		# 清掉旧实例遗留的所有 pressed 连接（匿名 lambda 无法按 Callable 精确断开，全清）
		for conn in btn.pressed.get_connections():
			btn.pressed.disconnect(conn.callable)
		# 关卡按钮：按 LevelButton%d 解析关卡号重连
		if nm.begins_with("LevelButton"):
			var level_str := nm.substr("LevelButton".length())
			if level_str.is_valid_int():
				var level_index: int = level_str.to_int()
				btn.pressed.connect(func() -> void: _on_level_selected(level_index))

## 刷新地图（清除缓存，强制重新生成）
func refresh_levels() -> void:
	_map_built = false
	# 当前关卡高亮依赖构建时的 current_level；刷新时禁用静态模板复用，避免高亮停留在旧关卡
	_cached_level_map_template = null
	_build_level_map()

## v6.10: 占领变化时刷新地图（让关卡按钮的占领色标实时更新）
## v9 perf：地图隐藏时置脏跳过——world_map 随 WorldMapPanel 常驻主场景但默认不可见，
## 每次过关都触发 100 按钮全量重建是纯浪费；重新打开时 refresh_for_open 补刷
func _on_occupation_changed_refresh(_level: int, _old_f: String, _new_f: String) -> void:
	if not is_visible_in_tree():
		_occupation_dirty = true
		return
	refresh_levels()

## v22: 相位泡关卡节点（TextureButton）——贴图=时代泡/通关残壳/相位师泡，
## 占领色标=占领环（overlay 绘制）+ boss 泡染势力色 + tooltip（沿用旧按钮逻辑）
func _make_level_node(level_index: int, era_idx: int, point: Vector2, _current_level: int) -> TextureButton:
	var btn := TextureButton.new()
	btn.name = "LevelButton%d" % level_index
	var is_boss: bool = PhaseMasterGarrison.is_garrison_level(level_index)
	var tex: Texture2D
	if _is_level_cleared(level_index):
		tex = _tex(BUBCLEARED_TEX_PATH)
	elif is_boss:
		tex = _tex(BOSS_TEX_PATH)
	else:
		tex = _tex(String(BUBBLE_TEX_PATHS[era_idx]))
	btn.texture_normal = tex
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_SCALE
	var disp: float = BOSS_BUBBLE_DISPLAY if is_boss else BUBBLE_DISPLAY
	btn.custom_minimum_size = Vector2(disp, disp)
	btn.size = Vector2(disp, disp)
	btn.position = point - Vector2(disp, disp) * 0.5

	var num := Label.new()
	num.name = "LevelNum"
	num.text = "%d" % level_index
	num.set_anchors_preset(Control.PRESET_FULL_RECT)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.add_theme_font_size_override("font_size", 14)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(num)

	# v7.x: 驻守相位师 Boss 关——数字金色 + 描边 + tooltip
	var boss_master_name: String = ""
	if is_boss:
		var bmid: String = PhaseMasterGarrison.get_garrison_master_id(level_index)
		if not bmid.is_empty():
			var bm: Dictionary = EnemyPhaseMasters.get_master_by_id(bmid)
			if not bm.is_empty():
				boss_master_name = "%s Lv.%d" % [String(bm.get("name", "")), int(bm.get("level", 0))]
		if not boss_master_name.is_empty():
			num.add_theme_color_override("font_color", Color(1.0, 0.84, 0.3, 1.0))
			num.add_theme_color_override("font_outline_color", Color(1.0, 0.65, 0.2, 0.9))
			num.add_theme_constant_override("outline_size", 2)
			btn.tooltip_text = "⚔ 相位师首领：%s" % boss_master_name

	# v6.10: 占领色标——Boss 泡膜染势力色（混白避免过暗）+ tooltip 追加占领信息
	var occupation_fid: String = _get_level_occupation_safe(level_index)
	if not occupation_fid.is_empty():
		var occ_color: Color = CompanyDefs.get_faction_color(occupation_fid)
		if is_boss:
			btn.modulate = Color(occ_color.r * 0.5 + 0.5, occ_color.g * 0.5 + 0.5,
				occ_color.b * 0.5 + 0.5, 1.0)
		var occ_name: String = occupation_fid
		var fsm = get_node_or_null("/root/FactionSystemManager")
		if fsm and fsm.has_method("get_faction_info"):
			occ_name = String(fsm.get_faction_info(occupation_fid).get("name", occupation_fid))
		if btn.tooltip_text.is_empty():
			btn.tooltip_text = "占领：%s" % occ_name
		else:
			btn.tooltip_text += "
占领：%s" % occ_name

	btn.pressed.connect(func() -> void: _on_level_selected(level_index))
	return btn

## v6.10: 安全查询关卡占领势力（FSM 优先动态，未加载/无方法时回退静态 level_information）
func _get_level_occupation_safe(level: int) -> String:
	var fsm = get_node_or_null("/root/FactionSystemManager")
	if fsm and fsm.has_method("get_level_occupation"):
		return String(fsm.get_level_occupation(level))
	# 回退静态（v7.x 性能：用全局单例）
	var li = LevelInformation.get_shared()
	return li.get_level_faction(level)

func _process(_delta: float) -> void:
	pass

func _draw() -> void:
	# v22：地图内容全部由 MapCanvas 子树绘制，根节点不再画星空/扫描线
	pass

## 拖拽平移：左键拖空白处滚动视口（气泡按钮会先消费自身点击，互不冲突）
func _on_map_gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_pan_dragging = (ev as InputEventMouseButton).pressed
	elif ev is InputEventMouseMotion and _pan_dragging:
		var scroll := get_node_or_null("Margin/VBox/ScrollContainer") as ScrollContainer
		if scroll != null:
			var rel: Vector2 = (ev as InputEventMouseMotion).relative
			scroll.set_h_scroll(int(scroll.get_h_scroll() - rel.x))
			scroll.set_v_scroll(int(scroll.get_v_scroll() - rel.y))

func _on_back_to_title() -> void:
	# 嵌入到 Main 的 MapOverlay 时，不切场景，改为通知父层关闭。
	if has_meta("embedded_mode") and bool(get_meta("embedded_mode")):
		back_to_main.emit()
		return
	# 独立场景模式：直接切换回主场景
	get_tree().change_scene_to_file("res://scenes/main.tscn")

## v6.10: 打开势力领地图面板
func _on_territory_map_button() -> void:
	# OccupationPanel 已静态实例化于 main.tscn（PopupLayer/OccupationOverlay/CenterContainer），
	# 旧的 UILazyLoader.ensure_loaded("occupation") 守卫恒真（UILazyLoader 无此方法），导致按钮永远早退——已删。
	var overlay = get_node_or_null("/root/Main/PopupLayer/OccupationOverlay")
	if overlay == null:
		return
	overlay.visible = true
	var panel = overlay.get_node_or_null("CenterContainer/OccupationPanel")
	if panel and panel.has_method("_refresh_all"):
		panel._refresh_all()

func _on_level_selected(level_index: int) -> void:
	_show_level_info_popup(level_index)

func _show_level_info_popup(level_index: int) -> void:
	if _level_info_popup and is_instance_valid(_level_info_popup):
		_level_info_popup.queue_free()
	var popup := AcceptDialog.new()
	popup.title = "关卡情报"
	# 隐藏 AcceptDialog 自带的 OK 按钮，使用自定义按钮。
	# 注意：AcceptDialog 仅有 OK 按钮（无 Cancel），set_cancel_button_text 是 ConfirmationDialog 的方法。
	popup.set_ok_button_text("")
	if popup.get_ok_button() != null:
		popup.get_ok_button().visible = false
	# 同步 queue_free 可能在输入分发中途拆掉 Window 视口，触发 Viewport::_push_unhandled_input_internal 断言
	popup.canceled.connect(_close_popup_safe.bind(popup))
	add_child(popup)
	_level_info_popup = popup

	var info: Dictionary = _collect_level_info(level_index)
	var era_id: int = LevelEras.get_era(level_index)
	var era_color: Color = ERA_COLORS[clampi(era_id - 1, 0, ERA_COLORS.size() - 1)].get("title", Color(0, 0.94, 1, 1))
	var era_name: String = String(ERA_COLORS[clampi(era_id - 1, 0, ERA_COLORS.size() - 1)].get("name", ""))
	var display_name: String = String(info.get("display_name", "第%d关" % level_index))

	# === 外层 Margin ===
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup.add_child(margin)

	# === 根 VBox（Header / Body / ActionRow）===
	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root_vbox)

	# ── Header：标题(左) + 关闭按钮(右) ──
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = "%s · %s" % [era_name, display_name]
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", era_color)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "×"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.pressed.connect(_close_popup_safe.bind(popup))
	header.add_child(close_btn)
	root_vbox.add_child(header)

	# ── Body：可滚动分区内容 ──
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(440, 320)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root_vbox.add_child(scroll)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	# ▸ 基本信息
	body.add_child(_make_detail_section_title("基本信息"))
	var in_era_pos: int = ((level_index - 1) % ERA_SIZE) + 1
	# 2026-08-16: 难度显示改用战斗链真实乘区（敌方配置档位），不再显示已死链的
	# difficulty_modifier 线性公式值（v8.2 起该公式不在任何战斗乘区中）
	var era_progress: float = float(in_era_pos - 1) / 19.0
	var diff_tier_id: int = EnemyLoadoutTiers.get_tier_for_level_progress(era_progress)
	var diff_tier: String = _difficulty_label(diff_tier_id)
	var diff_mult: float = 1.0 + float(EnemyLoadoutTiers.get_bonus_for_tier(diff_tier_id).get("hp_pct", 0.0))
	# v7.x 性能：用全局单例（与 _collect_level_info 一致）
	var _li_instance := LevelInformation.get_shared()
	var lpm: Node = get_node_or_null("/root/LevelProgressManager")
	var stars: int = 0
	if lpm and lpm.has_method("get_level_stars"):
		stars = lpm.get_level_stars(level_index)
	var stars_text: String = _stars_to_text(stars)
	var rec_level: int = max(1, level_index - 5)
	body.add_child(_make_detail_row("关卡编号", "第 %d 关（时代内 %d）" % [level_index, in_era_pos]))
	body.add_child(_make_detail_row("难度", "%s  (敌方配置 ×%.2f)" % [diff_tier, diff_mult]))
	body.add_child(_make_detail_row("评价", stars_text))
	body.add_child(_make_detail_row("推荐等级", "Lv.%d" % rec_level))
	# 驻防势力（沿用现有 garrison 逻辑）
	var garrison_faction_id: String = String(info.get("garrison_faction_id", ""))
	var garrison_text: String = String(info.get("garrison_text", "无主之地"))
	var garrison_buff_text: String = String(info.get("garrison_buff_text", ""))
	var garrison_color: Color = info.get("garrison_color", Color(0.7, 0.75, 0.8, 0.9))
	var garrison_full: String = garrison_text
	if not garrison_faction_id.is_empty() and not garrison_buff_text.is_empty() and garrison_buff_text != "无加成":
		garrison_full = "%s  [敌方加成: %s]" % [garrison_text, garrison_buff_text]
	body.add_child(_make_detail_row("驻防势力", garrison_full, garrison_color))
	# v7.x: 驻守相位师（固定驻守关显示）
	var garrison_master_name: String = String(info.get("garrison_master_name", ""))
	if not garrison_master_name.is_empty():
		body.add_child(_make_detail_row("驻守相位师", garrison_master_name, Color(1.0, 0.55, 0.3, 1.0)))

	# v10: 敌情简报——关卡战术主题（题面）。威胁=敌方在做什么，建议=可用解法提示
	var theme_info: Dictionary = TacticalThemes.get_theme_display(level_index)
	var theme_color: Color = Color.from_string(String(theme_info.get("color", "#ffffff")), Color(1, 1, 1, 1))
	body.add_child(_make_detail_row("敌情简报", "⚠ %s" % String(theme_info.get("name", "")), theme_color))
	body.add_child(_make_detail_desc("· %s" % String(theme_info.get("threat", "")), theme_color))
	body.add_child(_make_detail_desc("· %s" % String(theme_info.get("advice", "")), Color(0.7, 0.85, 0.7, 0.95)))

	# v8 批次3: 关卡特殊规则提示（限定兵种/能量惩罚/特殊胜利/部署上限）
	var _rules: Dictionary = _li_instance.get_special_rules(level_index)
	var _rules_text: String = _format_special_rules(_rules)
	if not _rules_text.is_empty():
		body.add_child(_make_detail_row("特殊规则", _rules_text, Color(1.0, 0.82, 0.4, 1.0)))

	# ▸ 环境参数（2列网格）
	body.add_child(_make_detail_section_title("环境参数"))
	var env_grid := GridContainer.new()
	env_grid.columns = 2
	env_grid.add_theme_constant_override("h_separation", 6)
	env_grid.add_theme_constant_override("v_separation", 6)
	env_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	env_grid.add_child(_make_env_tag("天气", _translate_env("weather", info.get("weather", "?"))))
	env_grid.add_child(_make_env_tag("地形", _translate_env("terrain", info.get("terrain", "?"))))
	env_grid.add_child(_make_env_tag("能量场", _translate_env("energy_field", info.get("energy_field", "?"))))
	env_grid.add_child(_make_env_tag("时段", _translate_env("time_of_day", info.get("time_of_day", "?"))))
	body.add_child(env_grid)

	# ▸ 敌情预览（敌方单位 + 可能掉落 + 资源掉落）
	body.add_child(_make_detail_section_title("敌情预览"))
	var enemy_preview: String = String(info.get("enemy_preview", "未知"))
	body.add_child(_make_detail_desc("敌方单位：%s" % (enemy_preview if not enemy_preview.is_empty() else "未知")))
	var enemy_drop_preview: String = String(info.get("enemy_drop_preview", "无"))
	body.add_child(_make_detail_desc("可能掉落：%s" % enemy_drop_preview, Color(0.9, 0.82, 1, 0.95)))
	# 资源掉落 + 蓝图概率（紧凑格式）
	var recon_bonus: float = 0.0
	if GameManager and GameManager.has_method("_get_recon_fragment_bonus_multiplier"):
		recon_bonus = float(GameManager._get_recon_fragment_bonus_multiplier())
	var base_frag_pct: float = float(info.get("fragment_chance_percent", 0.0))
	var preview_frag_pct: float = base_frag_pct * (1.0 + recon_bonus)
	var resource_line := "资源：能量块 +%d · 纳米 +%d · 合金 +%d · 晶体 +%d" % [
		int(info.get("energy_block_drop", 0)),
		int(info.get("nano_materials_drop", 0)),
		0, 0
	]
	body.add_child(_make_detail_desc(resource_line, Color(0.9, 0.95, 0.8, 0.95)))
	body.add_child(_make_detail_desc("蓝图碎片：%.1f%% → %.1f%%（侦查 %+d%%）" % [base_frag_pct, preview_frag_pct, int(round(recon_bonus * 100.0))], Color(0.9, 0.95, 0.8, 0.95)))

	# ▸ 关卡描述
	body.add_child(_make_detail_section_title("关卡描述"))
	body.add_child(_make_detail_desc(String(info.get("description", "（无描述）"))))

	# ── ActionRow：进入该关 + 自动部署 ──
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(action_row)
	var enter_btn := Button.new()
	enter_btn.text = "▶  进入该关"
	enter_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enter_btn.custom_minimum_size = Vector2(0, 36)
	enter_btn.add_theme_font_size_override("font_size", 13)
	enter_btn.pressed.connect(_enter_level_from_popup.bind(level_index, popup))
	action_row.add_child(enter_btn)
	var auto_btn := Button.new()
	auto_btn.text = "⚙  自动部署"
	auto_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto_btn.custom_minimum_size = Vector2(0, 36)
	auto_btn.add_theme_font_size_override("font_size", 13)
	auto_btn.pressed.connect(_auto_deploy_from_popup.bind(level_index, popup))
	action_row.add_child(auto_btn)

	popup.popup_centered(Vector2i(540, 520))


# === 关卡详情面板辅助函数（原型 level_select_v3.html 分区样式）===

## 分区段标题（小号大写灰、下划线）
func _make_detail_section_title(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)  # 批次三 B10：分区标题为中文，10→12
	lbl.add_theme_color_override("font_color", Color(0.4, 0.5, 0.7, 0.8))
	lbl.add_theme_constant_override("line_spacing", 1)
	# 模拟下划线：用一个小分隔条
	return lbl

## 键值对行（label 左 / value 右）
func _make_detail_row(label_text: String, value_text: String, value_color: Color = Color(0.92, 0.94, 0.98, 1.0)) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = label_text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.55, 0.65, 0.8, 0.9))
	l.custom_minimum_size.x = 80
	row.add_child(l)
	var v := Label.new()
	v.text = value_text
	v.add_theme_font_size_override("font_size", 12)
	v.add_theme_color_override("font_color", value_color)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(v)
	return row

## 环境参数标签（带半透明背景的小格子）
func _make_env_tag(label_text: String, value_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 26)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.03)
	sb.border_width_left = 1; sb.border_width_top = 1
	sb.border_width_right = 1; sb.border_width_bottom = 1
	sb.border_color = Color(1, 1, 1, 0.06)
	sb.corner_radius_top_left = 3; sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3; sb.corner_radius_bottom_right = 3
	sb.content_margin_left = 8; sb.content_margin_right = 8
	sb.content_margin_top = 4; sb.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", sb)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_bottom", 3)
	panel.add_child(margin)
	var lbl := Label.new()
	lbl.text = "%s: %s" % [label_text, value_text]
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 1, 0.95))
	margin.add_child(lbl)
	return panel

## 环境值翻译：将英文 key 转为中文显示
static func _translate_env(key: String, raw: String) -> String:
	var maps: Dictionary = {
		"weather": {
			"clear": "晴朗",
			"rain": "降雨",
			"storm": "风暴",
			"fog": "迷雾",
			"snow": "降雪",
			"sandstorm": "沙暴",
		},
		"terrain": {
			"plain": "平原",
			"city": "城市",
			"mountain": "山地",
			"forest": "森林",
			"desert": "荒漠",
		},
		"energy_field": {
			"normal": "常规",
			"high_field": "高能",
			"low_field": "低能",
			"nano_fog": "纳米雾",
			"void_rift": "虚空裂隙",
		},
		"time_of_day": {
			"dawn": "黎明",
			"day": "白天",
			"dusk": "黄昏",
			"night": "夜晚",
		},
	}
	var group: Dictionary = maps.get(key, {})
	if group.has(raw):
		return String(group[raw])
	return raw

## 描述行（autowrap 文字段）
func _make_detail_desc(text: String, color: Color = Color(0.7, 0.75, 0.85, 0.9)) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lbl

## 难度档位标签（2026-08-16: 与敌方配置档位 EnemyLoadoutTiers 同源——
## 时代内 in_era 1-3 低配 / 4-11 中配 / 12-20 高配，与战斗乘区一致）
func _difficulty_label(tier: int) -> String:
	match tier:
		EnemyLoadoutTiers.TIER_LOW:
			return "简单"
		EnemyLoadoutTiers.TIER_MID:
			return "普通"
		EnemyLoadoutTiers.TIER_HIGH:
			return "困难"
	return "普通"

## 星级文本
func _stars_to_text(stars: int) -> String:
	if stars <= 0:
		return "未通关"
	var s := ""
	for i in range(3):
		s += "★" if i < stars else "☆"
	return s

## v8 批次3: 格式化关卡特殊规则为中文提示文本（供关卡弹窗显示）
## 返回空串=普通关（无特殊规则）。
func _format_special_rules(rules: Dictionary) -> String:
	if rules.is_empty():
		return ""
	var parts: Array = []
	# 限定兵种
	var restrict: Array = rules.get("restrict_platforms", [])
	if not restrict.is_empty():
		var names: Array = []
		for pt in restrict:
			names.append(_platform_type_name(int(pt)))
		parts.append("限定兵种: " + ", ".join(names))
	# 能量惩罚
	var em: float = float(rules.get("energy_mult", 1.0))
	if absf(em - 1.0) > 0.001:
		parts.append("能量上限 %d%%" % int(em * 100))
	var rm: float = float(rules.get("energy_regen_mult", 1.0))
	if absf(rm - 1.0) > 0.001:
		parts.append("能量回复 %d%%" % int(rm * 100))
	# 特殊胜利
	var wt: String = String(rules.get("win_type", ""))
	if wt == "survive_waves":
		parts.append("胜利条件: 坚守 %d 波" % int(rules.get("win_param", 0)))
	# 注：deploy_limit 已移除——可上场单位数现由相位仪实际装备的战斗卡数决定，不再作为关卡修饰显示。
	return "  ·  ".join(parts) if not parts.is_empty() else ""


## v8 批次3: platform_type 枚举值转中文名（供限定兵种提示）
func _platform_type_name(pt: int) -> String:
	# 对齐 GameConstants.PlatformType 枚举
	match pt:
		0: return "步兵"
		1: return "装甲"
		2: return "空军"
		3: return "支援"
		4: return "侦察"
		5: return "炮兵"
		6: return "防空"
		7: return "工兵"
		8: return "航母"
		9: return "医疗"
		10: return "隐身"
		11: return "堡垒"
		12: return "指挥"
		_: return "类型%d" % pt

## 自动部署：进入该关 + 自动开始战斗 + AFK 自动布阵
## world_map 是独立场景，无法直接调 main.gd 的 AFK；
## 用 Engine 全局标记传递意图，main.gd 在 _ready 末尾检测标记后自动启动 AFK 推图。
func _auto_deploy_from_popup(level_index: int, popup: Window) -> void:
	if GameManager and GameManager.has_method("set_current_level"):
		GameManager.set_current_level(level_index)
	_close_popup_safe(popup)
	# 设置全局标记：main.gd _ready 末尾检测到则自动 start_afk（推图模式从本关开始）
	Engine.set_meta("world_map_auto_deploy_level", level_index)
	if has_meta("embedded_mode") and bool(get_meta("embedded_mode")):
		back_to_main.emit()
		return
	get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")

func _close_popup_safe(popup: Window) -> void:
	if is_instance_valid(popup):
		popup.call_deferred("queue_free")

func _enter_level_from_popup(level_index: int, popup: Window) -> void:
	if GameManager and GameManager.has_method("set_current_level"):
		GameManager.set_current_level(level_index)
	_close_popup_safe(popup)
	if has_meta("embedded_mode") and bool(get_meta("embedded_mode")):
		back_to_main.emit()
		return
	# 独立场景模式：切回主场景
	# 同步切场景会在按键输入分发中途释放本 Window 视口，易触发 Viewport::_push_unhandled_input_internal
	get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")

func _collect_level_info(level_index: int) -> Dictionary:
	var info_db = LevelInformation.get_shared()
	var li: Dictionary = info_db.get_level_info(level_index)
	# 2026-08-16: 环境单一真源 = BattleEnvironments（战斗侧 phase_law_manager/battle_damage_system
	# 同源读取）。原读 li["environment"]（level_information 程序循环生成）与战斗环境不同步。
	var env: Dictionary = BattleEnvironments.get_for_level(level_index)
	var drops: Dictionary = BasicResourcesData.get_drops_for_level(level_index)
	var era: int = LevelEras.get_era(level_index)
	var enemy_ids: Array = EnemyArchetypesData.get_ids_for_era(era)
	enemy_ids.sort()
	var level_enemy_ids: Array = _pick_level_enemy_ids(level_index, enemy_ids)
	var enemy_names: Array = []
	var drop_names: Array = []
	var drop_ids_all: Array = []
	for i in range(mini(level_enemy_ids.size(), 5)):
		var eid: String = String(level_enemy_ids[i])
		var cfg: Dictionary = EnemyArchetypesData.get_config(eid)
		var ename: String = String(cfg.get("display_name", eid))
		enemy_names.append(ename)
		var ds: Array = EnemyArchetypesData.get_drop_definitions(eid)
		for d in ds:
			if d is Dictionary:
				var cid: String = String(d.get("card_id", ""))
				if cid.is_empty():
					continue
				var c = DefaultCardsData.get_card_by_id(cid)
				var n: String = c.display_name if c else DefaultCardsData.get_safe_display_name(cid)
				if not drop_names.has(n):
					drop_names.append(n)
	# 统计该关敌人池的可能掉落（关卡专属口径）
	for eid_val in level_enemy_ids:
		var eid_all: String = String(eid_val)
		var all_drops: Array = EnemyArchetypesData.get_drop_definitions(eid_all)
		for d_all in all_drops:
			if d_all is Dictionary:
				var cid_all: String = String(d_all.get("card_id", ""))
				if cid_all.is_empty():
					continue
				if not drop_ids_all.has(cid_all):
					drop_ids_all.append(cid_all)
	# 实际磁盘文件命名为 bg_level_NN.png (bg_level_01~bg_level_100), 原 bg_%02d.png 不存在导致全部回退空背景
	var bg_idx: int = ((level_index - 1) % 10) + 1
	var bg_path: String = "res://assets/backgrounds/bg_level_%02d.png" % bg_idx
	var bg_exists: bool = ResourceLoader.exists(bg_path)
	var fallback_exists: bool = ResourceLoader.exists(DEFAULT_BG_PATH)
	var selected_bg_path: String = bg_path if bg_exists else (DEFAULT_BG_PATH if fallback_exists else "")
	
	# 根据关卡号生成掉落预览，使用不同的掉落组合
	var rng = RandomNumberGenerator.new()
	rng.seed = level_index * 7919  # 使用大质数作为种子，让不同关卡差异更大
	
	# 优先显示与该关卡敌人相关的掉落
	var drop_preview_text: String = "无"
	var display_drops: Array = []
	
	# 从该时代所有可掉落中，根据关卡号选择不同的掉落
	if not drop_ids_all.is_empty():
		# 按稀有度分组
		var common_drops: Array = []
		var rare_drops: Array = []
		var epic_drops: Array = []
		var mythic_drops: Array = []
		
		for cid in drop_ids_all:
			var c = DefaultCardsData.get_card_by_id(cid)
			if c:
				match c.rarity:
					"common":
						common_drops.append(c.display_name)
					"uncommon":
						rare_drops.append(c.display_name)
					"rare":
						epic_drops.append(c.display_name)
					"epic", "mythic":
						mythic_drops.append(c.display_name)
		
		# 根据关卡难度决定掉落组合
		var era_level = (level_index - 1) % 20 + 1  # 时代内关卡号 1-20
		var difficulty_tier = era_level / 5  # 1-4 (整数除法，故意为之)
		
		# 高难度关卡有更高概率显示稀有掉落
		var show_mythic = era_level >= 18 and difficulty_tier >= 3
		var show_epic = era_level >= 12 or difficulty_tier >= 2
		var show_rare = era_level >= 6
		
		# 构建掉落列表
		if mythic_drops.size() > 0 and show_mythic:
			var mythic_idx = rng.randi() % mythic_drops.size()
			display_drops.append(mythic_drops[mythic_idx])
		
		if show_epic and epic_drops.size() > 0:
			var count = mini(2 if difficulty_tier >= 3 else 1, epic_drops.size())
			for k in range(count):
				if epic_drops.size() > 0:
					var idx = rng.randi() % epic_drops.size()
					display_drops.append(epic_drops[idx])
					epic_drops.remove_at(idx)
		
		if show_rare and rare_drops.size() > 0:
			var count = mini(2 if difficulty_tier >= 2 else 1, rare_drops.size())
			for k in range(count):
				if rare_drops.size() > 0:
					var idx = rng.randi() % rare_drops.size()
					display_drops.append(rare_drops[idx])
					rare_drops.remove_at(idx)
		
		# 填充普通掉落直到有3-5个
		while display_drops.size() < 4 and not common_drops.is_empty():
			if common_drops.size() > 0:
				var idx = rng.randi() % common_drops.size()
				display_drops.append(common_drops[idx])
				common_drops.remove_at(idx)
			else:
				break
		
		# 打乱最终顺序
		for i in range(display_drops.size()):
			var j = rng.randi() % display_drops.size()
			var temp = display_drops[i]
			display_drops[i] = display_drops[j]
			display_drops[j] = temp
		
		# 限制显示数量
		display_drops.resize(mini(display_drops.size(), 5))
		drop_preview_text = ", ".join(display_drops)
		
		if drop_ids_all.size() > display_drops.size():
			drop_preview_text += " 等%d种" % drop_ids_all.size()
	elif not drop_names.is_empty():
		drop_preview_text = ", ".join(drop_names.slice(0, 3))
	# 与战后 DropTables CARD_DATA 池对齐的示例（敌方原型表常为空或与结算不一致）
	var dt_preview = DropTablesPreview.new()
	if dt_preview != null and dt_preview.has_method("sample_era_blueprint_display_names_for_preview"):
		var bp_line: PackedStringArray = dt_preview.sample_era_blueprint_display_names_for_preview(era, level_index, 4)
		if not bp_line.is_empty():
			var sample_txt: String = ", ".join(bp_line)
			if drop_preview_text == "无":
				drop_preview_text = "%s（每场战功卡随机）" % sample_txt
			else:
				drop_preview_text = "%s · 战功卡池示例: %s" % [drop_preview_text, sample_txt]
	# v6.9/v6.10: 查询关卡驻防势力（动态占领优先，回退静态）
	# v6.10: 玩家攻克易主后，驻防显示跟随动态占领状态
	var garrison_faction_id: String = _get_level_occupation_safe(level_index)
	var garrison_text: String = "无主之地（无占领势力，无敌方加成）"
	var garrison_buff_text: String = ""
	var garrison_color: Color = Color(0.7, 0.75, 0.8, 0.9)
	if not garrison_faction_id.is_empty():
		var fsm = get_node_or_null("/root/FactionSystemManager")
		if fsm and fsm.has_method("get_faction_info"):
			var finfo: Dictionary = fsm.get_faction_info(garrison_faction_id)
			var fname: String = String(finfo.get("name", garrison_faction_id))
			var flevel: int = int(finfo.get("level", 1))
			garrison_text = "%s（Lv.%d）" % [fname, flevel]
			# 显示该势力对该关敌人的加成（来自 faction_conquest_buffs.gd）
			if FactionConquestBuffs != null:
				garrison_buff_text = FactionConquestBuffs.describe_buff(garrison_faction_id, flevel)
				garrison_color = Color(1.0, 0.7, 0.4, 1.0)  # 橙红：占领势力，威胁提示
	# v7.x: 查询驻守相位师（固定驻守关，复用顶部 const）
	var garrison_master_name: String = ""
	var _garrison_mid: String = PhaseMasterGarrison.get_garrison_master_id(level_index)
	if not _garrison_mid.is_empty():
		var _gm: Dictionary = EnemyPhaseMasters.get_master_by_id(_garrison_mid)
		if not _gm.is_empty():
			garrison_master_name = "%s Lv.%d" % [String(_gm.get("name", "")), int(_gm.get("level", 0))]
	var out: Dictionary = {
		"display_name": String(li.get("display_name", "第%d关" % level_index)),
		"description": String(li.get("description", "")),
		"weather": String(env.get("weather", "")),
		"terrain": String(env.get("terrain", "")),
		"energy_field": String(env.get("energy_field", "")),
		"time_of_day": String(env.get("time_of_day", "")),
		"background_path": selected_bg_path,
		"background_exists": bg_exists,
		"background_fallback_used": (not bg_exists and fallback_exists),
		"nano_materials_drop": int(drops.get("basic_nano", 0)),
		"energy_block_drop": int(drops.get("energy_block", 0)),
		"nano_material_drop": 5 + level_index * 2,
		"fragment_chance_percent": (0.25 + level_index * 0.002) * 100.0,
		"enemy_preview": ", ".join(enemy_names),
		"enemy_drop_preview": drop_preview_text,
		# v6.9: 驻防势力信息
		"garrison_faction_id": garrison_faction_id,
		"garrison_text": garrison_text,
		"garrison_buff_text": garrison_buff_text,
		"garrison_color": garrison_color,
		# v7.x: 驻守相位师（固定驻守关）
		"garrison_master_id": _garrison_mid,
		"garrison_master_name": garrison_master_name,
	}
	return out

func _pick_level_enemy_ids(level_index: int, era_enemy_ids: Array) -> Array:
	if era_enemy_ids.is_empty():
		return []
	var in_era: int = ((level_index - 1) % ERA_SIZE) + 1
	# 关卡越后，敌人池越大：早期更聚焦，后期更丰富
	var target_count: int = clampi(4 + int((in_era - 1) / 4), 4, 10)
	target_count = mini(target_count, era_enemy_ids.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = int(level_index) * 2654435761
	var shuffled: Array = era_enemy_ids.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = t
	var picked: Array = []
	for i in range(target_count):
		picked.append(shuffled[i])
	return picked

## 仅在地图打开时执行的轻量刷新（避免每次重建100个按钮）
func refresh_for_open() -> void:
	# v9 perf：隐藏期间占领变化过 → 补一次全量重建（占领色标已变）
	if _occupation_dirty:
		_occupation_dirty = false
		refresh_levels()
	_on_visibility_changed()
	if not _map_built:
		_build_level_map()
