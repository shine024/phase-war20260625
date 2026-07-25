extends PanelContainer
## v7.x 战斗状态卡（纵向，每项一行，风格同 BuffFoldCard）
## 显示：时间 / 单位(我X敌X) / 击杀(我X敌X) / 伤害(我X敌X)
## 数据源：时间/击杀/伤害 从 BattleInfoDisplay.get_battle_stats() 读；单位数轮询 BattleManager

var _time_label: Label = null
var _unit_label: Label = null
var _kill_label: Label = null
var _dmg_label: Label = null
var _refresh_accum: float = 0.0
const _REFRESH_SEC: float = 0.5


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	custom_minimum_size = Vector2(150, 0)
	# PanelContainer 内套 Margin > VBox
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)
	# 标题
	var title := Label.new()
	title.text = "📊 战况"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.91, 0.94, 0.96, 1))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	title.add_theme_constant_override("outline_size", 2)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)
	# 4 行数据
	_time_label = _make_row_label()
	_unit_label = _make_row_label()
	_kill_label = _make_row_label()
	_dmg_label = _make_row_label()
	vbox.add_child(_time_label)
	vbox.add_child(_unit_label)
	vbox.add_child(_kill_label)
	vbox.add_child(_dmg_label)
	_refresh()


func _make_row_label() -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(0.78, 0.83, 0.9, 0.95))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _process(delta: float) -> void:
	_refresh_accum += delta
	if _refresh_accum >= _REFRESH_SEC:
		_refresh_accum = 0.0
		_refresh()


func _refresh() -> void:
	var stats := _get_battle_stats()
	var player_n := 0
	var enemy_n := 0
	var bm := get_node_or_null("/root/BattleManager")
	if bm:
		if bm.has_method("get_player_unit_count"):
			player_n = int(bm.get_player_unit_count())
		if bm.has_method("get_enemy_unit_count"):
			enemy_n = int(bm.get_enemy_unit_count())
	if _time_label:
		var t: float = float(stats.get("battle_time", 0.0))
		var mm := int(t / 60)
		var ss := int(fmod(t, 60.0))
		_time_label.text = "时间  %02d:%02d" % [mm, ss]
	if _unit_label:
		_unit_label.text = "单位  我%d / 敌%d" % [player_n, enemy_n]
	if _kill_label:
		_kill_label.text = "击杀  我%d / 敌%d" % [int(stats.get("player_kills", 0)), int(stats.get("enemy_kills", 0))]
	if _dmg_label:
		_dmg_label.text = "伤害  我%s / 敌%s" % [_fmt(int(stats.get("damage_dealt", 0))), _fmt(int(stats.get("damage_taken", 0)))]


func _get_battle_stats() -> Dictionary:
	# BattleInfoDisplay 在 HudLayer/BattleTopStatusBar/BattleInfoDisplay（已隐藏但保留 _process 跑）
	# 状态条在 HudLayer/BattleStatusStrip，需向上到 HudLayer 再下到 BattleTopStatusBar
	# 用绝对路径最稳妥
	var bid := get_node_or_null("/root/Main/HudLayer/BattleTopStatusBar/BattleInfoDisplay")
	if bid == null:
		bid = get_node_or_null("../BattleTopStatusBar/BattleInfoDisplay")
	if bid and bid.has_method("get_battle_stats"):
		return bid.get_battle_stats()
	return {}


func _fmt(n: int) -> String:
	if n >= 10000:
		return "%.1f万" % (n / 10000.0)
	if n >= 1000:
		return "%d" % n
	return "%d" % n
