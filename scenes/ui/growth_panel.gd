extends PanelContainer
## 成长面板 — 综合展示单位星级/MOD/强化/进化路线
## 6 模块：头部(头像+信息) → 星级强化 → 卡牌强化 → MOD装配(9格) → 进化路线 → 底部资源

const GC = preload("res://resources/game_constants.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const StarConfig = preload("res://data/blueprint_star_config.gd")

signal closed

# 面板大小
const PANEL_WIDTH: int = 860
const PANEL_HEIGHT: int = 920

# 动画参数
var _anim_duration: float = 0.25
var _is_open: bool = false

# 当前查看的单位
var _selected_card: CardResource = null
var _base_card: CardResource = null       # 基础卡(不含强化加成)

# UI 引用
var portrait_box: Panel
var unit_name_label: Label
var unit_subtitle_label: Label
var era_badle: Label
var stat_tags: Control

var stars_big_container: Control
var star_count_label: Label

var section_star_label: Label
var star_row_container: Control
var star_progress_bar: ProgressBar
var star_xp_text: Label
var star_cost_text: Label

var section_enhance_label: Label
var enhance_progress_bar: ProgressBar

var stat_atk_label: Label
var stat_def_label: Label
var stat_hp_label: Label
var stat_misc_label: Label

var section_mod_label: Label
var mod_count_label: Label
var mod_grid: GridContainer
var mod_subtitle_label: Label
var mod_open_btn: Button

var section_evo_label: Label
var evo_arrow: Label
var evo_requirements_label: Label
var evo_current_icon: Label
var evo_current_name: Label
var evo_target_icon: Label
var evo_target_name: Label

var currency_bar: Control
var btn_apply: Button

func _ready() -> void:
	visible = false
	modulate.a = 0.0
	_bind_nodes()
	if btn_apply:
		btn_apply.pressed.connect(_on_apply_pressed)
	if mod_open_btn:
		mod_open_btn.pressed.connect(_on_open_modification)

func _bind_nodes() -> void:
	# Header
	portrait_box = %Portrait
	unit_name_label = %UnitName
	unit_subtitle_label = %Subtitle
	era_badle = %EraBadge
	stat_tags = %TagsContainer
	stars_big_container = %StarsBig
	star_count_label = %StarCountLabel
	# Star section
	section_star_label = %StarTitle
	star_row_container = %StarRow
	star_progress_bar = %StarProgress
	star_xp_text = %StarXpText
	star_cost_text = %StarCostText
	# Enhance section
	section_enhance_label = %EnhanceLevel
	enhance_progress_bar = %EnhanceProgress
	stat_atk_label = %AtkValues
	stat_def_label = %DefValues
	stat_hp_label = %HpValues
	stat_misc_label = %MiscValues
	# Mod section
	section_mod_label = %ModTitle
	mod_count_label = %ModCountLabel
	mod_grid = %ModGrid
	mod_subtitle_label = %ModSubtitle
	mod_open_btn = %ModOpenBtn
	# Evo section
	section_evo_label = %EvoTitle
	evo_arrow = %EvoArrowLabel
	evo_requirements_label = %EvoRequirements
	evo_current_icon = %EvoCurrentIcon
	evo_current_name = %EvoCurrentName
	evo_target_icon = %EvoTargetIcon
	evo_target_name = %EvoTargetName
	# Footer
	currency_bar = %CurrencyInfo
	btn_apply = %ApplyBtn

# ─── 公开接口 ───────────────────────────────────────

## 打开面板并查看指定单位
func show_panel(card: CardResource) -> void:
	if _is_open:
		return
	_is_open = true
	_selected_card = card
	visible = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, _anim_duration).set_trans(Tween.TRANS_SINE)
	scale = Vector2(0.92, 0.92)
	tween.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), _anim_duration).set_trans(Tween.TRANS_BACK)
	_refresh_data()

## 关闭面板
func hide_panel() -> void:
	if not _is_open:
		return
	_is_open = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, _anim_duration).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(self, "scale", Vector2(0.92, 0.92), _anim_duration).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func(): visible = false)
	closed.emit()

func _on_apply_pressed() -> void:
	# TODO: 保存成长数据到存档
	print("[GrowthPanel] 应用保存(待实现)")
	# 触发全局信号
	var sb = get_node_or_null("/root/SignalBus")
	if sb and sb.has_signal("growth_panel_saved"):
		sb.growth_panel_saved.emit(_selected_card)
	hide_panel()

# ─── 数据刷新 ───────────────────────────────────────

func _refresh_data() -> void:
	if not _selected_card:
		return
	_refresh_header()
	_refresh_star_section()
	_refresh_enhance_section()
	_refresh_mod_section()
	_refresh_evolution_section()

## 按 ID 选中单位（用于从情报面板跳转）
func select_card_by_id(card_id: String) -> void:
	if card_id.is_empty():
		return
	var card = DefaultCards.get_card_by_id(card_id)
	if card:
		_selected_card = card
		if not visible:
			return  # 面板已关闭，无需刷新
		_refresh_data()

## 按 CardResource 选中（通用）
func select_card(card: CardResource) -> void:
	_selected_card = card
	if not visible:
		return
	_refresh_data()

## 从成长面板打开独立改造面板
func _on_open_modification() -> void:
	if not _selected_card:
		return
	# 懒加载获取改造面板
	var lazy = get_node_or_null("/root/UILazyLoader")
	if lazy == null:
		return
	var mod_panel = lazy.call("get_panel", "modification")
	if mod_panel == null:
		return
	# 设置选中卡牌
	if mod_panel.has_method("set_selected_card"):
		mod_panel.set_selected_card(_selected_card)
	# 显示改造覆盖层
	var overlay = get_node_or_null("PopupLayer/ModificationOverlay")
	if overlay:
		overlay.visible = true
		overlay.modulate.a = 1.0

func _refresh_header() -> void:
	var c := _selected_card
	if not c:
		return
	# 名称
	if unit_name_label:
		unit_name_label.text = c.card_id.to_upper()
	if unit_subtitle_label:
		unit_subtitle_label.text = c.display_name
	# 时代
	if c.card_type == GC.CardType.COMBAT_UNIT and era_badle:
		var era_name: String = GC.get_era_name(c.era)
		var era_short: String = GC.get_era_short(c.era)
		era_badle.text = "%s %s" % [era_short, era_name]
	# 标签
	if stat_tags:
		for child in stat_tags.get_children():
			child.queue_free()
		var kind_tag := Label.new()
		kind_tag.text = CardResource.get_combat_kind_name(c.combat_kind) if c.card_type == GC.CardType.COMBAT_UNIT else ""
		kind_tag.add_theme_font_size_override("font_size", 11)
		kind_tag.add_theme_stylebox_override("normal", _get_tag_stylebox())
		stat_tags.add_child(kind_tag)
		if c.card_type == GC.CardType.COMBAT_UNIT:
			var wtype := GC.get_weapon_type_short(c.weapon_type)
			var wt_tag := Label.new()
			wt_tag.text = "直射" if c.weapon_type == GC.WeaponType.DIRECT else (
				"曲射" if c.weapon_type == GC.WeaponType.INDIRECT else "空射" if c.weapon_type == GC.WeaponType.AERIAL else "辅助")
			wt_tag.add_theme_font_size_override("font_size", 11)
			wt_tag.add_theme_stylebox_override("normal", _get_tag_stylebox())
			stat_tags.add_child(wt_tag)
			if c.range_value > 0:
				var rng_tag := Label.new()
				rng_tag.text = "射程 %d" % c.range_value
				rng_tag.add_theme_font_size_override("font_size", 11)
				rng_tag.add_theme_stylebox_override("normal", _get_tag_stylebox())
				stat_tags.add_child(rng_tag)
			var e_cost := Label.new()
			e_cost.text = "能量 %.0f" % c.energy_cost
			e_cost.add_theme_font_size_override("font_size", 11)
			e_cost.add_theme_stylebox_override("normal", _get_tag_stylebox())
			stat_tags.add_child(e_cost)

func _refresh_star_section() -> void:
	if not _selected_card:
		return
	# 星级(用 power 和 enhance_level 估算)
	var star: int = _calculate_star()
	_clear_children(star_row_container)
	for i in range(5):
		var s := Label.new()
		s.add_theme_font_size_override("font_size", 18)
		s.custom_minimum_size = Vector2(32, 32)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if i < star:
			s.text = "\u2605"
			s.modulate = Color(1.0, 0.84, 0.0)
			s.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
		else:
			s.text = "\u2606"
			s.modulate = Color(0.333, 0.4, 0.467)
		star_row_container.add_child(s)
	if star_count_label:
		star_count_label.text = "%d/5 星级" % star
	# 星级进度(估算)
	var star_frac := float(min(star, 4)) / 4.0
	if star_progress_bar:
		star_progress_bar.value = star_frac * 100.0
	# 消耗文本(简化显示)
	if star_cost_text:
		var next_cost := StarConfig.get_research_cost_for_next_star(star, _selected_card.rarity)
		star_cost_text.text = "下一星所需: 合金×%d · 晶体×%d" % [next_cost / 5, next_cost / 7]

func _refresh_enhance_section() -> void:
	var c := _selected_card
	if not c:
		return
	if section_enhance_label:
		section_enhance_label.text = "LV.%d / 10" % c.enhance_level
	if enhance_progress_bar:
		enhance_progress_bar.value = (float(c.enhance_level) / 10.0) * 100.0
	# 获取增强后的属性
	var stats := _get_enhanced_stats()
	if stat_atk_label:
		stat_atk_label.text = "轻%.0f / 甲%.0f / 空%.0f" % [
			stats.get("atk_light", 0), stats.get("atk_armor", 0), stats.get("atk_air", 0)]
	if stat_def_label:
		stat_def_label.text = "轻%.0f / 甲%.0f / 空%.0f" % [
			stats.get("def_light", 0), stats.get("def_armor", 0), stats.get("def_air", 0)]
	if stat_hp_label:
		stat_hp_label.text = "%.0f" % stats.get("hp", 0)
	if stat_misc_label:
		stat_misc_label.text = "射程 %d | 攻速 %.1f | 移速 %.1f" % [
			stats.get("range", _selected_card.range_value),
			stats.get("atk_speed", _selected_card.attack_speed),
			stats.get("speed", _selected_card.base_speed)]

func _refresh_mod_section() -> void:
	if not mod_grid:
		return
	if not _selected_card:
		return
	# 清空（保留PlaceholderSlot模板）
	for child in mod_grid.get_children():
		if child.name != "PlaceholderSlot":
			child.queue_free()
	var template: PackedScene = load("res://scenes/ui/mod_slot_item.tscn")
	var mod_list: Array = _selected_card.mods
	var filled: int = mini(mod_list.size(), 9)
	if mod_count_label:
		mod_count_label.text = "%d/9 已装配" % filled
	# 创建9个槽位（从模板复制）
	for i in range(9):
		var slot: Control
		if template:
			slot = template.instantiate()
		else:
			slot = PanelContainer.new()
		slot.custom_minimum_size = Vector2(80, 100)
		slot.layout_mode = 2
		slot.modulate.a = 1.0  # 确保可见
		mod_grid.add_child(slot)
		if slot.has_method("set_slot_index"):
			slot.set_slot_index(i + 1)
		var mod_data: Dictionary = {}
		if i < filled:
			var entry = mod_list[i]
			if entry is Dictionary:
				mod_data = entry
			elif entry is String:
				var md = ModificationRegistry.get_data(entry)
				mod_data = {"id": entry, "name": md.get("display_name", entry), "level": 1, "tier": "A"}
		if slot.has_method("set_mod"):
			slot.set_mod(mod_data)

func _refresh_evolution_section() -> void:
	var c := _selected_card
	if not c:
		return
	var evo_paths: Array = c.evolution_paths
	if evo_target_icon:
		if evo_paths.is_empty():
			evo_target_icon.text = "🔒"
			evo_target_name.text = "未解锁进化路线"
		else:
			var target_id: String = evo_paths[0]
			# 查找目标卡
			var target = DefaultCards.get_card_by_id(target_id)
			if target:
				evo_target_icon.text = "\u2694"
				evo_target_name.text = target.display_name
			else:
				evo_target_icon.text = "🔒"
				evo_target_name.text = target_id
	# 进化条件
	if evo_requirements_label:
		var lines: Array = []
		# 条件1: 素材情报
		lines.append("[color=#00E676]✓ 素材情报 ≥ 2/2[/color]")
		# 条件2: 战力
		var current_power := c.get_current_power()
		var target_power: int = max(int(c.power * 2.0), 800)
		if current_power >= target_power:
			lines.append("[color=#00E676]✓ 战力 ≥ %d (当前 %d)[/color]" % [target_power, current_power])
		else:
			lines.append("[color=#FF9800]✗ 战力 ≥ %d (当前 %d)[/color]" % [target_power, current_power])
		# 条件3: 星级
		var star := _calculate_star()
		if star >= 4:
			lines.append("[color=#00E676]✓ 星级 ≥ 4[/color]")
		else:
			lines.append("[color=#FF9800]✗ 星级 ≥ 4[/color]")
		# 条件4: 合金
		lines.append("[color=#FF9800]✗ 合金 500[/color]")
		evo_requirements_label.text = "\n".join(lines)

# ─── 工具方法 ───────────────────────────────────────

func _calculate_star() -> int:
	# 基于 enhance_level 和 rarity 估算
	return StarConfig.calculate_star(_selected_card.enhance_level * 2, _selected_card.rarity)

func _get_enhanced_stats() -> Dictionary:
	var c := _selected_card
	var mult := 1.0
	if c.enhance_level > 0:
		mult = 1.0 + (float(c.enhance_level) * 0.08)  # 每级+8%
	return {
		"atk_light": c.attack_light * mult,
		"atk_armor": c.attack_armor * mult,
		"atk_air": c.attack_air * mult,
		"def_light": c.defense_light * mult,
		"def_armor": c.defense_armor * mult,
		"def_air": c.defense_air * mult,
		"hp": c.base_hp * mult,
		"range": c.range_value,
		"atk_speed": c.attack_speed,
		"speed": c.base_speed,
	}

func _clear_children(parent: Control) -> void:
	if not parent:
		return
	for child in parent.get_children():
		child.queue_free()

func _get_tag_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.29, 0.561, 0.851, 0.1)
	sb.border_color = Color(0.29, 0.561, 0.851, 0.25)
	sb.set_corner_radius_all(2)
	sb.content_left = 6
	sb.content_top = 1
	sb.content_right = 6
	sb.content_bottom = 1
	return sb
