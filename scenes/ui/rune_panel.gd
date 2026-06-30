extends Control
## v6.2 符文管理面板
##
## 功能：
##   1. 显示当前相位仪的符文槽位（1-6个）
##   2. 显示玩家持有的所有符文（按分类/稀有度筛选）
##   3. 点击符文 → 装备到选中的槽位
##   4. 显示当前激活的符文之语及其效果
##   5. 显示组合预览（提示凑齐哪些符文可激活新符文之语）
##
## 使用方式：通过 UILazyLoader.get_panel("rune_panel") 加载

const DesignTokens = preload("res://resources/design_tokens.gd")
const RuneDefs = preload("res://data/runes.gd")
const RunewordDefs = preload("res://data/runewords.gd")
const RunewordMatcher = preload("res://managers/runeword_matcher.gd")

var _pim: Node = null  # PhaseInstrumentManager 引用
var _selected_slot_index: int = 0  # 当前选中的符文槽位

# UI元素引用
var _slot_container: HBoxContainer = null
var _rune_grid: GridContainer = null
var _runeword_list: VBoxContainer = null
var _filter_buttons: HBoxContainer = null
var _current_filter: String = "all"
var _detail_label: RichTextLabel = null

func _ready() -> void:
	_pim = get_node_or_null("/root/PhaseInstrumentManager")
	if _pim == null:
		push_error("[RunePanel] PhaseInstrumentManager 未找到")
		return
	_build_ui()
	_refresh_all()
	# 监听槽位变化
	if SignalBus.has_signal("phase_slots_changed"):
		SignalBus.phase_slots_changed.connect(_on_slots_changed)
	# v6.2 修复 M2：监听符文获得信号，新符文即时出现在网格中
	if SignalBus.has_signal("rune_acquired"):
		SignalBus.rune_acquired.connect(_on_rune_acquired)

## v6.2: 符文获得回调（购买/掉落）—— 刷新网格让新符文即时出现
func _on_rune_acquired(_rune_id: String, _source: String) -> void:
	_refresh_all()

## v6.2: 清理信号连接，防止面板销毁后回调访问已释放节点
func _exit_tree() -> void:
	if SignalBus != null:
		if SignalBus.has_signal("phase_slots_changed") and SignalBus.phase_slots_changed.is_connected(_on_slots_changed):
			SignalBus.phase_slots_changed.disconnect(_on_slots_changed)
		# v6.2 修复 M2：断开 rune_acquired 信号
		if SignalBus.has_signal("rune_acquired") and SignalBus.rune_acquired.is_connected(_on_rune_acquired):
			SignalBus.rune_acquired.disconnect(_on_rune_acquired)

# ═══════════════════════════════════════════════════════════════════
# UI 构建
# ═══════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	# 根容器
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_custom_minimum_size(Vector2(840, 580))
	
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", DesignTokens.PADDING_SMALL)
	add_child(root)
	
	# 标题栏
	root.add_child(_build_title_bar())
	
	# 符文槽位行
	_slot_container = _build_slot_row()
	root.add_child(_slot_container)
	
	# 分隔线
	root.add_child(_build_separator())
	
	# 中部：左侧符文列表 + 右侧符文之语
	var middle := HSplitContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.split_offset = 480
	root.add_child(middle)
	
	# 左侧：筛选 + 符文网格
	var left_panel := _build_left_panel()
	middle.add_child(left_panel)
	
	# 右侧：激活的符文之语列表
	_runeword_list = _build_runeword_panel()
	middle.add_child(_runeword_list)
	
	# 底部详情
	_detail_label = RichTextLabel.new()
	_detail_label.custom_minimum_size = Vector2(0, 80)
	_detail_label.bbcode_enabled = true
	_detail_label.add_theme_font_size_override("normal_font_size", DesignTokens.FONT_SIZE_SMALL)
	root.add_child(_detail_label)

func _build_title_bar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := Label.new()
	title.text = "⚡ 符文之语"
	title.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_TITLE)
	title.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_PURPLE)
	bar.add_child(title)
	var hint := Label.new()
	hint.text = "  (点击符文装备到选中槽位)"
	hint.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_SMALL)
	hint.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT)
	bar.add_child(hint)
	return bar

func _build_slot_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", DesignTokens.PADDING_SMALL)
	return row

func _build_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 2)
	return sep

func _build_left_panel() -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", DesignTokens.PADDING_SMALL)
	
	# 筛选按钮行
	_filter_buttons = HBoxContainer.new()
	_filter_buttons.add_theme_constant_override("separation", 4)
	_add_filter_button("all", "全部")
	_add_filter_button("attack", "攻击")
	_add_filter_button("defense", "防御")
	_add_filter_button("energy", "能量")
	_add_filter_button("mobility", "机动")
	_add_filter_button("special", "特殊")
	panel.add_child(_filter_buttons)
	
	# 符文网格（可滚动）
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	
	_rune_grid = GridContainer.new()
	_rune_grid.columns = 4
	_rune_grid.add_theme_constant_override("h_separation", 4)
	_rune_grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(_rune_grid)
	
	return panel

func _add_filter_button(filter_id: String, label_text: String) -> void:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(60, 28)
	btn.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_SMALL)
	btn.toggle_mode = true
	btn.set_meta("filter_id", filter_id)
	btn.pressed.connect(_on_filter_pressed.bind(filter_id, btn))
	_filter_buttons.add_child(btn)
	if filter_id == "all":
		btn.button_pressed = true
		btn.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_CYAN)

func _build_runeword_panel() -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 4)
	
	var title := Label.new()
	title.text = "已激活符文之语"
	title.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_LARGE)
	title.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_PURPLE)
	panel.add_child(title)
	
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 4)
	scroll.add_child(inner)
	# 用 set_meta 存储内部容器引用，便于后续刷新
	panel.set_meta("inner_container", inner)
	return panel

# ═══════════════════════════════════════════════════════════════════
# 刷新逻辑
# ═══════════════════════════════════════════════════════════════════

func _refresh_all() -> void:
	_refresh_slots()
	_refresh_rune_grid()
	_refresh_runeword_list()
	_refresh_detail()

func _refresh_slots() -> void:
	for child in _slot_container.get_children():
		child.queue_free()
	var slot_count: int = _pim.get_rune_slot_count() if _pim.has_method("get_rune_slot_count") else 0
	for i in range(slot_count):
		var slot_btn := _make_slot_button(i)
		_slot_container.add_child(slot_btn)

func _make_slot_button(slot_index: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(70, 80)
	btn.toggle_mode = true
	if slot_index == _selected_slot_index:
		btn.button_pressed = true
		btn.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_CYAN)
	var rune_id: String = _pim.get_rune_at(slot_index) if _pim.has_method("get_rune_at") else ""
	if rune_id.is_empty():
		btn.text = "槽%d\n(空)" % (slot_index + 1)
		btn.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT)
	else:
		btn.text = "%s\n%s" % [RuneDefs.get_rune_name(rune_id), RuneDefs.RARITY_NAMES.get(RuneDefs.get_rune(rune_id).get("rarity", ""), "")]
		var color: Color = RuneDefs.get_color(rune_id)
		btn.add_theme_color_override("font_color", color)
	btn.pressed.connect(_on_slot_selected.bind(slot_index))
	return btn

func _refresh_rune_grid() -> void:
	for child in _rune_grid.get_children():
		child.queue_free()
	var owned_runes: Array = _pim.get_owned_runes() if _pim.has_method("get_owned_runes") else []
	for rune_id in owned_runes:
		var rune_def: Dictionary = RuneDefs.get_rune(rune_id)
		if rune_def.is_empty():
			continue
		# 应用筛选
		if _current_filter != "all" and rune_def.get("category", "") != _current_filter:
			continue
		var btn := _make_rune_button(rune_id, rune_def)
		_rune_grid.add_child(btn)

func _make_rune_button(rune_id: String, rune_def: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(105, 80)
	btn.text = "%s\n%s" % [RuneDefs.get_rune_name(rune_id), RuneDefs.RARITY_NAMES.get(rune_def.get("rarity", ""), "")]
	btn.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_SMALL)
	var color: Color = RuneDefs.get_color(rune_id)
	btn.add_theme_color_override("font_color", color)
	# v6.2: 符文图标贴图（缺失时回退到纯文字按钮）
	var icon_tex: Texture2D = UiAssetLoader.rune_icon(rune_id)
	if icon_tex != null:
		btn.icon = icon_tex
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	# 已装备的符文标记
	var equipped_slots: Array = _pim.get_rune_slots() if _pim.has_method("get_rune_slots") else []
	if equipped_slots.has(rune_id):
		btn.text += " ✓"
		btn.disabled = false  # 允许点击以切换到其他槽位
	btn.pressed.connect(_on_rune_pressed.bind(rune_id))
	return btn

func _refresh_runeword_list() -> void:
	var inner: VBoxContainer = _runeword_list.get_meta("inner_container", null)
	if inner == null:
		return
	for child in inner.get_children():
		child.queue_free()
	var active: Array = _pim.get_active_runewords() if _pim.has_method("get_active_runewords") else []
	if active.is_empty():
		var empty_label := Label.new()
		empty_label.text = "（暂无激活的符文之语）"
		empty_label.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_SMALL)
		empty_label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT)
		inner.add_child(empty_label)
		return
	for rw in active:
		var entry := _make_runeword_entry(rw)
		inner.add_child(entry)

func _make_runeword_entry(rw: Dictionary) -> VBoxContainer:
	var entry := VBoxContainer.new()
	entry.add_theme_constant_override("separation", 2)
	# 名称行
	var name_label := Label.new()
	var tier_color: Color = RunewordDefs.TIER_COLORS.get(rw.get("tier", 2), DesignTokens.COLOR_ACCENT_PURPLE)
	name_label.text = "★ %s (T%d)" % [RunewordDefs.get_runeword_name(rw.get("id", "")), rw.get("tier", 2)]
	name_label.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_MEDIUM)
	name_label.add_theme_color_override("font_color", tier_color)
	entry.add_child(name_label)
	# 效果行
	var effect_label := Label.new()
	effect_label.text = RunewordDefs.get_effects_description(rw.get("id", ""))
	effect_label.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_SMALL)
	effect_label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT)
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry.add_child(effect_label)
	return entry

func _refresh_detail() -> void:
	var bonus: Dictionary = _pim.get_rune_bonus() if _pim.has_method("get_rune_bonus") else {}
	var rune_stats: Dictionary = bonus.get("rune_stats", {})
	var rune_specials: Array = bonus.get("rune_specials", [])
	var runeword_bonuses: Array = bonus.get("runeword_bonuses", [])
	if rune_stats.is_empty() and rune_specials.is_empty() and runeword_bonuses.is_empty():
		_detail_label.text = "[color=gray]当前无符文加成[/color]"
		return
	var lines: PackedStringArray = []
	# v6.2b: 单符文加成
	if not rune_stats.is_empty() or not rune_specials.is_empty():
		lines.append("[b]符文加成：[/b]")
		for key in rune_stats:
			var display_name: String = _stat_display(key)
			var pct := int(round(float(rune_stats[key]) * 100.0))
			if key == "energy_cost_reduction" or key == "damage_reduction":
				lines.append("  %s -%d%%" % [display_name, pct])
			else:
				lines.append("  %s +%d%%" % [display_name, pct])
		for sp in rune_specials:
			var sp_name: String = _special_display(sp.get("special", ""))
			var chance := int(round(float(sp.get("chance", 1.0)) * 100.0))
			lines.append("  %s (%d%%概率)" % [sp_name, chance])
	# v6.2b: 符文之语加成（每个带名称）
	if not runeword_bonuses.is_empty():
		lines.append("[b]符文之语加成：[/b]")
		for rw in runeword_bonuses:
			var rw_name: String = String(rw.get("name", ""))
			var rw_stats: Dictionary = rw.get("stats", {})
			var rw_parts: Array[String] = []
			for key in rw_stats:
				var pct := int(round(float(rw_stats[key]) * 100.0))
				if String(key) == "energy_cost_reduction" or String(key) == "damage_reduction":
					rw_parts.append("%s -%d%%" % [_stat_display(String(key)), pct])
				else:
					rw_parts.append("%s +%d%%" % [_stat_display(String(key)), pct])
			for sp in rw.get("specials", []):
				var sp_name: String = _special_display(sp.get("special", ""))
				var chance := int(round(float(sp.get("chance", 1.0)) * 100.0))
				rw_parts.append("%s (%d%%概率)" % [sp_name, chance])
			if not rw_parts.is_empty():
				lines.append("  [color=#c9a0ff][%s][/color] %s" % [rw_name, " | ".join(rw_parts)])
	_detail_label.text = "\n".join(lines)

# ═══════════════════════════════════════════════════════════════════
# 事件处理
# ═══════════════════════════════════════════════════════════════════

func _on_slot_selected(slot_index: int) -> void:
	_selected_slot_index = slot_index
	_refresh_slots()

func _on_rune_pressed(rune_id: String) -> void:
	if _pim == null or not _pim.has_method("equip_rune"):
		return
	# 槽位越界保护：选中的槽位索引可能因相位仪切换/读档后变非法，自动夹紧到首个有效槽
	var slot_count: int = _pim.get_rune_slot_count() if _pim.has_method("get_rune_slot_count") else 0
	if slot_count <= 0:
		_show_detail_hint("当前相位仪没有符文槽位")
		return
	if _selected_slot_index < 0 or _selected_slot_index >= slot_count:
		_selected_slot_index = 0
	# v7.x 修复 W2：若点击的符文正是当前选中槽位已装备的，则卸下它（提供卸下入口，原只能换装覆盖）
	if _pim.has_method("get_rune_at") and _pim.get_rune_at(_selected_slot_index) == rune_id:
		if _pim.has_method("unequip_rune"):
			_pim.unequip_rune(_selected_slot_index)
			_refresh_all()
			_show_detail_hint("已卸下符文：%s" % rune_id)
			return
	var success: bool = _pim.equip_rune(_selected_slot_index, rune_id)
	if success:
		_refresh_all()
	else:
		# 装备失败时给出原因提示，避免静默失败让玩家无所适从
		if not _pim.has_rune(rune_id):
			_show_detail_hint("未持有该符文，无法装备")
		else:
			_show_detail_hint("符文装备失败（槽位不可用）")

## 在底部详情标签里显示一条临时提示（不覆盖加成总览的持久内容则用单独方法）
func _show_detail_hint(msg: String) -> void:
	if _detail_label == null:
		return
	_detail_label.text = "[color=yellow]%s[/color]" % msg

func _on_filter_pressed(filter_id: String, btn: Button) -> void:
	_current_filter = filter_id
	# 更新筛选按钮高亮
	for child in _filter_buttons.get_children():
		if child is Button:
			child.button_pressed = false
			child.remove_theme_color_override("font_color")
	btn.button_pressed = true
	btn.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_CYAN)
	_refresh_rune_grid()

func _on_slots_changed(_slots: Variant = null) -> void:
	_refresh_all()

# ═══════════════════════════════════════════════════════════════════
# 辅助
# ═══════════════════════════════════════════════════════════════════

## v6.2: 转发到公共工具 RuneDefinitions，消除重复映射（保留旧签名向后兼容）
static func _stat_display(stat: String) -> String:
	return RuneDefinitions.stat_display_name(stat)

static func _special_display(special: String) -> String:
	return RuneDefinitions.special_display_name(special)
