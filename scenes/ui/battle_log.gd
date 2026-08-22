extends PanelContainer
## v7.x 战斗日志底栏（BattleLog）
##
## 让战斗感觉"活起来"——玩家看到"我方 XX 击毁 敌方 YY"、"施放 法则"、"基地 -350 HP"，
## 沉浸感显著提升。克制风格：默认折叠（仅最新 1 行 + ▼ 展开），不遮挡战场核心区域。
##
## 性能：仿 battle_info_display 的 _stats_dirty 模式——事件先入队列，
## _process 每 0.3s 合并刷新一次 Label，避免高频事件每帧重建文本。
##
## 挂载：HudLayer/BattleLogBar（BattleBottomBar 兄弟节点，紧贴底部栏上方）
## 保留最近 30 条，FIFO。

const DT = preload("res://resources/design_tokens.gd")

const _MAX_ENTRIES: int = 30           # 保留条目上限
const _REFRESH_SEC: float = 0.3        # 合并刷新间隔
const _COLLAPSED_LINES: int = 1        # 折叠时显示行数
const _EXPANDED_LINES: int = 5         # 展开时显示行数

var _entries: Array[Dictionary] = []   # {text, color}
var _dirty: bool = false
var _refresh_acc: float = 0.0
var _expanded: bool = false
var _log_label: RichTextLabel = null
var _toggle_btn: Button = null

func _ready() -> void:
	# 半透明黑条样式 + 左侧 4px 青色色条（通过 border_width_left）
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.5)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.border_width_left = 4
	style.border_color = DT.COLOR_ACCENT_CYAN
	style.content_margin_left = 10.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	add_theme_stylebox_override("panel", style)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 主容器
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	add_child(hbox)
	# 日志文本（RichTextLabel 支持多色多行）
	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled = true
	_log_label.fit_content = true
	_log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_label.scroll_active = false
	_log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_label.add_theme_font_size_override("normal_font_size", DT.FONT_SIZE_SMALL)
	hbox.add_child(_log_label)
	# 展开/折叠按钮
	_toggle_btn = Button.new()
	_toggle_btn.text = "▼"
	_toggle_btn.custom_minimum_size = Vector2(28, 0)
	_toggle_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_toggle_btn.pressed.connect(_on_toggle_pressed)
	# 按钮样式（克制：小而暗）
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.1, 0.15, 0.25, 0.8)
	btn_style.corner_radius_top_left = 3
	btn_style.corner_radius_top_right = 3
	btn_style.corner_radius_bottom_right = 3
	btn_style.corner_radius_bottom_left = 3
	_toggle_btn.add_theme_stylebox_override("normal", btn_style)
	_toggle_btn.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	_toggle_btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	hbox.add_child(_toggle_btn)
	modulate.a = 0.0
	visible = false
	set_process(false)
	# 监听战斗事件
	if SignalBus:
		SignalBus.unit_killed.connect(_on_unit_killed)
		SignalBus.boss_wave_started.connect(_on_boss_wave_started)
		SignalBus.phase_master_appeared.connect(_on_phase_master_appeared)
		SignalBus.battle_started.connect(_on_battle_started)
		SignalBus.battle_ended.connect(_on_battle_ended)
		SignalBus.unit_damaged.connect(_on_unit_damaged)

# =========================================================================
#  信号处理
# =========================================================================

func _on_battle_started() -> void:
	_entries.clear()
	_dirty = true
	modulate.a = 1.0
	visible = true
	set_process(true)

func _on_battle_ended(_player_won: bool) -> void:
	# 战斗结束停止采集，但保留最后日志 2s 供查看，然后淡出
	set_process(false)
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func():
		visible = false
		_entries.clear()
	)

func _on_unit_killed(victim: Node, killer: Node, is_player_victim: bool) -> void:
	if is_player_victim:
		# 我方损失
		_add_entry("损失 %s" % _unit_name(victim), DT.COLOR_DANGER)
	else:
		# 我方击杀敌方
		_add_entry("我方 %s 击毁 %s" % [_unit_name(killer), _unit_name(victim)], DT.COLOR_GREEN_BRIGHT)

func _on_boss_wave_started(_ids: Array) -> void:
	_add_entry("精英波次来袭！", DT.COLOR_ENERGY)

func _on_phase_master_appeared(master_config: Dictionary) -> void:
	var name: String = master_config.get("display_name", master_config.get("name", "相位师"))
	_add_entry("相位师 · %s" % name, DT.COLOR_DANGER)

func _on_unit_damaged(unit: Node, is_player: bool, amount: float, _pos: Vector2) -> void:
	# 仅记录"我方基地驱动器"受击（普通单位受伤太频繁，不记）
	# 基地驱动器走 phase_field_driver.gd emit unit_damaged，普通单位不走 SignalBus
	if not is_player:
		return
	if unit == null or not is_instance_valid(unit):
		return
	# 基地驱动器的类名判断：检查是否为 phase_field_driver
	var cls = unit.get_class()
	if unit.has_method("get") and unit.get("max_hp") != null:
		# 粗略识别：基地驱动器是 Node2D 且不在 player_units/enemy_units 组
		if not unit.is_in_group("player_units") and not unit.is_in_group("enemy_units"):
			var amt := int(amount)
			if amt > 0:
				_add_entry("基地 -%d HP" % amt, DT.COLOR_DANGER)

# =========================================================================
#  日志条目管理
# =========================================================================

func _add_entry(text: String, color: Color) -> void:
	_entries.append({"text": text, "color": color})
	# FIFO 裁剪
	while _entries.size() > _MAX_ENTRIES:
		_entries.pop_front()
	_dirty = true

func _process(delta: float) -> void:
	_refresh_acc += delta
	if _refresh_acc < _REFRESH_SEC:
		return
	_refresh_acc = 0.0
	if _dirty:
		_refresh_display()
		_dirty = false

func _refresh_display() -> void:
	if _entries.is_empty():
		_log_label.text = ""
		return
	var lines: int = _EXPANDED_LINES if _expanded else _COLLAPSED_LINES
	var start: int = maxi(0, _entries.size() - lines)
	var bb := ""
	for i in range(start, _entries.size()):
		var e: Dictionary = _entries[i]
		var c: Color = e["color"]
		var color_hex := "#%02x%02x%02x" % [int(c.r * 255), int(c.g * 255), int(c.b * 255)]
		var prefix := "" if i == _entries.size() - 1 else "  "  # 最新一条前缀空格少（视觉强调）
		bb += "%s[color=%s]%s[/color]\n" % [prefix, color_hex, str(e["text"])]
	_log_label.text = bb

func _on_toggle_pressed() -> void:
	_expanded = not _expanded
	_toggle_btn.text = "▲" if _expanded else "▼"
	_dirty = true

# =========================================================================
#  辅助
# =========================================================================

## 单位显示名（优先用卡牌名，回退 archetype_id，再回退节点名）
func _unit_name(unit: Node) -> String:
	if unit == null or not is_instance_valid(unit):
		return "未知单位"
	# 优先 stats.platform_card_id（我方/卡格战）
	if "stats" in unit:
		var s = unit.get("stats")
		if s != null and "platform_card_id" in s:
			var cid: String = str(s.platform_card_id)
			if not cid.is_empty():
				return _card_id_to_name(cid)
	# 敌方 archetype_id
	if "archetype_id" in unit:
		var aid: String = str(unit.archetype_id)
		if not aid.is_empty():
			return _archetype_to_name(aid)
	return unit.name

func _card_id_to_name(card_id: String) -> String:
	# 简单美化：去掉前缀，按 _ 拆分
	if card_id.is_empty():
		return "单位"
	var cleaned := card_id.replace("ww1_", "").replace("ww2_", "").replace("cold_", "").replace("modern_", "").replace("future_", "")
	cleaned = cleaned.replace("_", " ")
	return cleaned.capitalize()

func _archetype_to_name(archetype_id: String) -> String:
	if archetype_id.is_empty():
		return "敌方单位"
	var cleaned := archetype_id.replace("elite_", "").replace("basic_", "").replace("boss_", "")
	cleaned = cleaned.replace("_", " ")
	return cleaned.capitalize()

