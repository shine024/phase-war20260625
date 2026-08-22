extends PanelContainer
## v7.x 单位悬浮信息窗（UnitHoverInfo）
##
## 鼠标悬停战场单位 0.3s 后显示的轻量信息面板（HP/攻/防/等级/状态标签）。
## 单击单位时立即隐藏（让位给全屏 CardInfoPanel）。
##
## 挂载：InfoPanelLayer（layer=90，与 CardInfoPanel 同层）
## 数据来源：复用 card_info_panel._resolve_source_instance_card 反查链思路，
##           提取轻量字段（不做完整渲染，只取 HP/三维/等级 meta/光环状态标签）

const DT = preload("res://resources/design_tokens.gd")
const GC = preload("res://resources/game_constants.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const USC = preload("res://scripts/battle/unit_status_collector.gd")

const _HOVER_DELAY_SEC: float = 0.3
const _HIDE_DELAY_SEC: float = 0.2
const _MAX_STATUS_LINES: int = 5

var _content: VBoxContainer = null
var _name_label: Label = null
var _rarity_strip: ColorRect = null
var _stats_label: Label = null
var _tags_label: Label = null
var _status_labels: Array[Label] = []
var _active_tween: Tween = null


func _ready() -> void:
	# 极简样式：半透明深色 + 稀有度色边框（动态）+ 圆角
	var style := StyleBoxFlat.new()
	style.bg_color = Color(DT.COLOR_PANEL.r, DT.COLOR_PANEL.g, DT.COLOR_PANEL.b, 0.95)
	style.corner_radius_top_left = DT.CORNER_RADIUS
	style.corner_radius_top_right = DT.CORNER_RADIUS
	style.corner_radius_bottom_right = DT.CORNER_RADIUS
	style.corner_radius_bottom_left = DT.CORNER_RADIUS
	style.border_width_left = 3
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = DT.COLOR_TEXT_DIM
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	add_theme_stylebox_override("panel", style)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(200, 0)
	# 内容容器
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 2)
	add_child(_content)
	# 名称
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM)
	_name_label.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	_content.add_child(_name_label)
	# 稀有度色条
	_rarity_strip = ColorRect.new()
	_rarity_strip.custom_minimum_size = Vector2(0, 3)
	_content.add_child(_rarity_strip)
	# 数值行
	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	_stats_label.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	_content.add_child(_stats_label)
	# 词条
	_tags_label = Label.new()
	_tags_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	_tags_label.add_theme_color_override("font_color", DT.COLOR_ACCENT_CYAN)
	_content.add_child(_tags_label)
	# P0-3: 当前状态效果行（buff/debuff 各一条，"名称：效果说明"点读机式就地解释）
	for i in range(_MAX_STATUS_LINES):
		var sl := Label.new()
		sl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.visible = false
		_content.add_child(sl)
		_status_labels.append(sl)
	visible = false
	modulate.a = 0.0


## 显示悬浮窗（由 battle_click_overlay 在悬停时调用）
func show_for_unit(unit: Node, screen_pos: Vector2) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	_populate(unit)
	# 定位：单位上方（若超出屏幕顶部则放下方）
	var vp_h: float = get_viewport().get_visible_rect().size.y
	var pos_y: float = screen_pos.y - 120.0
	if pos_y < 10.0:
		pos_y = screen_pos.y + 40.0
	position = Vector2(screen_pos.x - 100.0, pos_y)
	# 智能裁剪到屏幕内
	var vp_w: float = get_viewport().get_visible_rect().size.x
	if position.x + 200.0 > vp_w:
		position.x = vp_w - 210.0
	if position.x < 10.0:
		position.x = 10.0
	visible = true
	# 淡入
	_kill_active_tween()
	var tw := create_tween()
	_active_tween = tw
	tw.tween_property(self, "modulate:a", 1.0, 0.1)


## 隐藏（移开单位时延迟 0.2s，避免鼠标抖动反复闪烁）
func hide_delayed() -> void:
	_kill_active_tween()
	var tw := create_tween()
	_active_tween = tw
	tw.tween_interval(_HIDE_DELAY_SEC)
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(func(): visible = false)


## 立即隐藏（单击单位时让位给 CardInfoPanel）
func hide_immediate() -> void:
	_kill_active_tween()
	modulate.a = 0.0
	visible = false


## 终止正在运行的悬浮动画（Tween 不挂在本节点 children 下，需通过引用 kill）
func _kill_active_tween() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null


# =========================================================================
#  数据填充
# =========================================================================

func _populate(unit: Node) -> void:
	var stats = unit.get("stats") if "stats" in unit else null
	# 名称
	var display_name: String = _resolve_display_name(unit)
	_name_label.text = display_name
	# 稀有度
	var card := _resolve_card(unit)
	var rarity_color: Color = DT.COLOR_TEXT_DIM
	if card != null:
		rarity_color = GC.get_rarity_color(card.rarity)
	_rarity_strip.color = rarity_color
	# 数值行（HP/攻/防）
	if stats != null:
		var hp_text: String = "生命 %d/%d" % [int(unit.get("hp") if "hp" in unit else 0), int(stats.max_hp)]
		var atk_val: float = maxf(stats.attack_light, maxf(stats.attack_armor, stats.attack_air))
		var def_val: float = maxf(stats.defense_light, maxf(stats.defense_armor, stats.defense_air))
		_stats_label.text = "%s · 攻 %d · 防 %d" % [hp_text, int(atk_val), int(def_val)]
	else:
		_stats_label.text = ""
	# 等级行：只显示战斗等级（光环/buff 移到下方状态效果行，避免重复）
	var tags: Array = []
	if unit.has_meta("unit_level") and int(unit.get_meta("unit_level")) > 0:
		tags.append("Lv.%d" % int(unit.get_meta("unit_level")))
	_tags_label.text = "  ".join(tags)
	# P0-3: 状态效果行（复用 UnitStatusCollector，与点击详情面板同一数据源）
	var entries: Array = USC.collect(unit)
	for i in range(_MAX_STATUS_LINES):
		var sl: Label = _status_labels[i]
		if i < entries.size():
			var e: Dictionary = entries[i]
			var kind: int = int(e.get("kind", -1))
			var stacks: int = int(e.get("stacks", 0))
			var is_buff: bool = bool(e.get("is_buff", false))
			var n: String = String(USC.STATUS_NAMES.get(kind, "未知状态"))
			if stacks > 1:
				n = "%s ×%d" % [n, stacks]
			var desc: String = USC.describe(kind, stacks, unit)
			sl.text = ("%s %s：%s" % ["▲", n, desc]) if is_buff else ("%s %s：%s" % ["▼", n, desc])
			sl.add_theme_color_override("font_color",
				DT.COLOR_HEALTH if is_buff else DT.COLOR_DANGER)
			sl.visible = true
		else:
			sl.visible = false


func _resolve_display_name(unit: Node) -> String:
	var card := _resolve_card(unit)
	if card != null:
		var dn := DefaultCards.safe_name(card)
		if not dn.is_empty():
			return dn + DefaultCards.seq_suffix(card)
	if "stats" in unit and unit.stats != null:
		var cid: String = String(unit.stats.platform_card_id)
		if not cid.is_empty():
			return DefaultCards.get_safe_display_name(cid)
	if "archetype_id" in unit:
		var aid: String = str(unit.archetype_id)
		# 敌方单位不在 InstanceRegistry（仅存我方实例），按 archetype_id 查中文名。
		# 复用 get_safe_display_name，它内部会查 EnemyArchetypes.display_name。
		var adn: String = DefaultCards.get_safe_display_name(aid)
		if not adn.is_empty() and adn != aid:
			return adn
		# 相位师召唤单位（phase_master_*）不在 archetype 表，兜底"相位师"
		if aid.begins_with("phase_master_"):
			return "相位师"
		return aid
	return "单位"


func _resolve_card(unit: Node) -> CardResource:
	if unit == null or not is_instance_valid(unit):
		return null
	var platform_card_id: String = ""
	if "stats" in unit and unit.stats != null:
		platform_card_id = String(unit.stats.platform_card_id)
	var inst_id: String = String(unit.get_meta("source_instance_id", ""))
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	# ① instance_id 精确取
	if ir != null and ir.has_method("get_instance") and not inst_id.is_empty():
		var inst: CardResource = ir.get_instance(inst_id)
		if inst != null:
			return inst
	# ② 裸 card_id → 首个实例
	if ir != null and ir.has_method("get_instances_by_card_id") and not platform_card_id.is_empty():
		var insts: Array = ir.get_instances_by_card_id(platform_card_id)
		if not insts.is_empty() and ir.has_method("get_instance"):
			var fb: CardResource = ir.get_instance(String(insts[0]))
			if fb != null:
				return fb
	# ③ 兜底：模板卡
	if not platform_card_id.is_empty():
		return DefaultCards.get_card_by_id(platform_card_id)
	return null

