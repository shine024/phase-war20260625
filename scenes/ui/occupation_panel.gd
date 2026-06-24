extends PanelContainer
## v6.10: 势力领地图面板
##
## 世界视角展示 100 关的当前占领状态：
##   - 顶部：7 势力图例（色块 + 名称 + 派生状态标签 + 占领关数）
##   - 中部：100 关网格（5时代×20关分组，每关按钮=占领势力配色，无主=灰）
##   - 底部：点击关卡显示占领详情（当前势力/敌方加成/历史）
##
## 实时刷新：监听 SignalBus.occupation_changed / faction_reputation_changed
## 数据源：FactionSystemManager.get_level_occupation / get_faction_status

const LevelEras = preload("res://data/level_eras.gd")
const LevelInformation = preload("res://data/level_information.gd")
const CompanyDefs = preload("res://data/company_definitions.gd")
const FactionConquestBuffs = preload("res://data/faction_conquest_buffs.gd")
const FactionStatus = preload("res://data/faction_status.gd")

## 势力代表色（与势力设定呼应，用于按钮着色）
const FACTION_COLORS: Dictionary = {
	"iron_wall_corp": Color(0.62, 0.58, 0.55, 1.0),    # 钢灰：钢壁防务
	"nova_arms": Color(0.92, 0.45, 0.25, 1.0),         # 火橙：新星兵工
	"aether_dynamics": Color(0.35, 0.75, 0.95, 1.0),   # 天蓝：以太动力
	"quantum_logistics": Color(0.4, 0.85, 0.55, 1.0),  # 翠绿：量子后勤
	"helix_recon": Color(0.7, 0.4, 0.92, 1.0),         # 紫罗兰：螺旋侦察
	"void_research": Color(0.55, 0.4, 0.85, 1.0),      # 暗紫：虚空相位
	"frontier_union": Color(0.85, 0.78, 0.35, 1.0),    # 沙金：边境联合
}

const NEUTRAL_COLOR: Color = Color(0.38, 0.4, 0.44, 0.7)  # 无主之地：暗灰
const ERA_NAMES: Array = ["一战 WWI", "二战 WWII", "冷战 COLD WAR", "现代 MODERN", "近未来 NEAR FUTURE"]

var _legend_container: VBoxContainer = null
var _territory_container: VBoxContainer = null
var _detail_label: Label = null
var _active_faction_label: Label = null


func _ready() -> void:
	_legend_container = get_node_or_null("Margin/VBox/LegendScroll/LegendContainer")
	_territory_container = get_node_or_null("Margin/VBox/TerritoryScroll/TerritoryContainer")
	_detail_label = get_node_or_null("Margin/VBox/DetailLabel")
	_active_faction_label = get_node_or_null("Margin/VBox/TitleRow/ActiveFactionLabel")

	var close_btn: Button = get_node_or_null("Margin/VBox/TitleRow/CloseButton")
	if close_btn:
		close_btn.pressed.connect(_on_close)

	# 监听占领/声望变化实时刷新
	if SignalBus:
		if SignalBus.has_signal("occupation_changed"):
			SignalBus.occupation_changed.connect(_on_occupation_changed)
		if not SignalBus.faction_reputation_changed.is_connected(_on_reputation_changed):
			SignalBus.faction_reputation_changed.connect(_on_reputation_changed)

	_refresh_all()


func _on_close() -> void:
	visible = false


func _on_occupation_changed(_level: int, _old_f: String, _new_f: String) -> void:
	_refresh_all()


func _on_reputation_changed(_fid: String, _delta: int, _new_val: int) -> void:
	# 声望变化影响派生状态标签，刷新图例
	_refresh_legend()


## 全量刷新（首次显示/占领变化时）
func _refresh_all() -> void:
	_refresh_active_faction_label()
	_refresh_legend()
	_refresh_territory_grid()


## 刷新顶部激活势力标签
func _refresh_active_faction_label() -> void:
	if _active_faction_label == null:
		return
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	if fsm == null:
		_active_faction_label.text = ""
		return
	var active: String = fsm.get("active_faction") if "active_faction" in fsm else ""
	if active.is_empty():
		_active_faction_label.text = "（未激活势力，攻克=解放为无主之地）"
		_active_faction_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 0.8))
	else:
		var fname: String = active
		if fsm.has_method("get_faction_info"):
			fname = String(fsm.get_faction_info(active).get("name", active))
		_active_faction_label.text = "当前激活：%s（攻克关卡将归属此势力）" % fname
		_active_faction_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35, 1.0))


## 刷新势力图例（7势力状态 + 占领数）
func _refresh_legend() -> void:
	if _legend_container == null:
		return
	for c in _legend_container.get_children():
		c.queue_free()
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	var factions: Array = CompanyDefs.get_all() if CompanyDefs else []
	for fdata in factions:
		var fid: String = String(fdata.get("id", ""))
		if fid.is_empty():
			continue
		var fname: String = String(fdata.get("name", fid))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		# 色块
		var swatch := _make_color_swatch(FACTION_COLORS.get(fid, Color(0.7, 0.7, 0.7)))
		row.add_child(swatch)
		# 名称
		var name_l := Label.new()
		name_l.text = fname
		name_l.add_theme_font_size_override("font_size", 12)
		name_l.add_theme_color_override("font_color", Color(0.88, 0.9, 0.95, 0.95))
		name_l.custom_minimum_size = Vector2(110, 0)
		row.add_child(name_l)
		# 状态标签（派生）
		var status_text: String = "未知"
		var status_color: Color = Color(0.7, 0.7, 0.7)
		if fsm and fsm.has_method("get_faction_status_name"):
			status_text = String(fsm.get_faction_status_name(fid))
			status_color = fsm.get_faction_status_color(fid) if fsm.has_method("get_faction_status_color") else status_color
		var status_l := Label.new()
		status_l.text = "[%s]" % status_text
		status_l.add_theme_font_size_override("font_size", 11)
		status_l.add_theme_color_override("font_color", status_color)
		status_l.custom_minimum_size = Vector2(70, 0)
		row.add_child(status_l)
		# 占领关数
		var territory_text: String = "0关"
		if fsm and fsm.has_method("get_territory_count"):
			territory_text = "%d关" % int(fsm.get_territory_count(fid))
		var terr_l := Label.new()
		terr_l.text = territory_text
		terr_l.add_theme_font_size_override("font_size", 11)
		terr_l.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 0.85))
		row.add_child(terr_l)
		# 声望
		var rep_text: String = ""
		if fsm and fsm.has_method("get_faction_reputation"):
			rep_text = "声望%d" % int(fsm.get_faction_reputation(fid))
		var rep_l := Label.new()
		rep_l.text = rep_text
		rep_l.add_theme_font_size_override("font_size", 11)
		rep_l.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8, 0.7))
		row.add_child(rep_l)
		_legend_container.add_child(row)


## 刷新100关领地网格（5时代分组）
func _refresh_territory_grid() -> void:
	if _territory_container == null:
		return
	for c in _territory_container.get_children():
		c.queue_free()
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	# 5时代 × 每时代20关
	for era_idx in range(5):
		var era_start: int = era_idx * 20 + 1
		var era_end: int = era_idx * 20 + 20
		# 时代标题行
		var era_title := Label.new()
		era_title.text = ERA_NAMES[era_idx] if era_idx < ERA_NAMES.size() else "时代%d" % era_idx
		era_title.add_theme_font_size_override("font_size", 13)
		era_title.add_theme_color_override("font_color", Color(0.85, 0.78, 0.45, 0.95))
		_territory_container.add_child(era_title)
		# 关卡网格（10列×2行）
		var grid := GridContainer.new()
		grid.columns = 10
		grid.add_theme_constant_override("h_separation", 3)
		grid.add_theme_constant_override("v_separation", 3)
		for level in range(era_start, era_end + 1):
			var btn := _make_territory_button(level, fsm)
			grid.add_child(btn)
		_territory_container.add_child(grid)


## 创建单个关卡领地按钮（颜色=占领势力）
func _make_territory_button(level: int, fsm: Node) -> Button:
	var btn := Button.new()
	btn.text = str(level)
	btn.custom_minimum_size = Vector2(46, 32)
	btn.add_theme_font_size_override("font_size", 11)
	# 查占领势力
	var fid: String = ""
	if fsm and fsm.has_method("get_level_occupation"):
		fid = String(fsm.get_level_occupation(level))
	var bg_color: Color = NEUTRAL_COLOR
	var border_color: Color = Color(0.3, 0.32, 0.36, 0.5)
	var font_color: Color = Color(0.7, 0.72, 0.78, 0.85)
	if not fid.is_empty():
		bg_color = FACTION_COLORS.get(fid, Color(0.7, 0.7, 0.7))
		border_color = bg_color.lightened(0.2)
		font_color = Color(0.05, 0.05, 0.08, 1.0)  # 深色字配亮底
	# 样式
	var s := StyleBoxFlat.new()
	s.bg_color = bg_color
	s.border_width_left = 1; s.border_width_top = 1
	s.border_width_right = 1; s.border_width_bottom = 1
	s.border_color = border_color
	s.corner_radius_top_left = 3; s.corner_radius_top_right = 3
	s.corner_radius_bottom_right = 3; s.corner_radius_bottom_left = 3
	btn.add_theme_stylebox_override("normal", s)
	# hover 高亮
	var s_hover := StyleBoxFlat.new()
	s_hover.bg_color = bg_color.lightened(0.15)
	s_hover.border_width_left = 2; s_hover.border_width_top = 2
	s_hover.border_width_right = 2; s_hover.border_width_bottom = 2
	s_hover.border_color = border_color.lightened(0.3)
	s_hover.corner_radius_top_left = 3; s_hover.corner_radius_top_right = 3
	s_hover.corner_radius_bottom_right = 3; s_hover.corner_radius_bottom_left = 3
	btn.add_theme_stylebox_override("hover", s_hover)
	btn.add_theme_color_override("font_color", font_color)
	# tooltip
	var tooltip_text: String = "第%d关" % level
	if fid.is_empty():
		tooltip_text += "\n无主之地"
	else:
		var fname: String = fid
		if fsm and fsm.has_method("get_faction_info"):
			fname = String(fsm.get_faction_info(fid).get("name", fid))
		tooltip_text += "\n占领：%s" % fname
		# 加成预览
		if fsm and fsm.has_method("get_faction_level"):
			var flevel: int = int(fsm.get_faction_level(fid))
			var buff_desc: String = FactionConquestBuffs.describe_buff(fid, flevel)
			tooltip_text += "\n敌方加成：%s" % buff_desc
	btn.tooltip_text = tooltip_text
	btn.pressed.connect(_on_level_clicked.bind(level))
	return btn


## 点击关卡显示详情
func _on_level_clicked(level: int) -> void:
	if _detail_label == null:
		return
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	var fid: String = ""
	if fsm and fsm.has_method("get_level_occupation"):
		fid = String(fsm.get_level_occupation(level))
	var parts: Array = ["第%d关" % level]
	if fid.is_empty():
		parts.append("无主之地（无占领势力，无敌方加成）")
	else:
		var fname: String = fid
		var flevel: int = 1
		if fsm and fsm.has_method("get_faction_info"):
			fname = String(fsm.get_faction_info(fid).get("name", fid))
			flevel = int(fsm.get_faction_info(fid).get("level", 1))
		parts.append("占领：%s (Lv.%d)" % [fname, flevel])
		# 状态
		if fsm and fsm.has_method("get_faction_status_name"):
			parts.append("状态：%s" % String(fsm.get_faction_status_name(fid)))
		# 加成
		var buff_desc: String = FactionConquestBuffs.describe_buff(fid, flevel)
		parts.append("敌方加成：%s" % buff_desc)
	_detail_label.text = "  ·  ".join(parts)


## 辅助：色块
func _make_color_swatch(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.custom_minimum_size = Vector2(16, 16)
	return rect
