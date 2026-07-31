extends PanelContainer
## 成长中枢面板（v7.x UI 重设计 · 匹配"养成系统四面板设计"成长中枢页）
## 金色签名色 + 2列布局（左名册 / 右详情）+ 2×2 进度卡片网格 + 底部操作按钮
## 公开契约保持不变：show_panel / hide_panel / select_card / select_card_by_id / signal closed

const GC = preload("res://resources/game_constants.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const StarConfig = preload("res://data/blueprint_star_config.gd")
const ModRegistry = preload("res://scripts/systems/modification_registry.gd")
const EvoPathRegistry = preload("res://scripts/systems/evolution_path_registry.gd")
const BlueprintDefinitions = preload("res://data/blueprint_definitions.gd")
const FormatUtil = preload("res://scripts/ui/format_util.gd")
const UiAssetLoader = preload("res://scripts/ui_asset_loader.gd")
const DT = preload("res://resources/design_tokens.gd")
const EvolutionHelpers = preload("res://managers/evolution/evolution_helpers.gd")

signal closed

const FILTER_ALL := "all"
const FILTER_ENHANCEABLE := "enhanceable"
const FILTER_MAXED := "maxed"

var _anim_duration: float = 0.25
var _is_open: bool = false
var _selected_card: CardResource = null
var _last_unlocked_ids: Array[String] = []
var _filter_mode: String = FILTER_ALL

# 缓存样式
var _tag_stylebox: StyleBoxFlat
var _card_thumb_stylebox_cache: Dictionary  # instance_id -> StyleBoxFlat (kind color)

# ---- TitleBar ----
var meta_label: Label
var close_btn: Button

# ---- 左栏 ----
var col_head_count: Label
var chip_all: Button
var chip_enh: Button
var chip_max: Button
var card_list_container: VBoxContainer
var card_list_scroll: ScrollContainer
var card_list_hint: Label

# ---- HeroCard ----
var hero_card: PanelContainer
var hero_art: PanelContainer
var hero_art_icon: Label
var hero_name_label: Label
var hero_tags: HBoxContainer
var hero_power_label: Label

# ---- 2×2 进度卡片 ----
var prog_card_amber: PanelContainer   # 强化系统
var prog_card_cyan: PanelContainer    # 改造系统
var prog_card_violet: PanelContainer  # 进化系统
var prog_card_gold: PanelContainer    # 星级评估

# ---- 操作按钮 ----
var enhance_btn: Button
var mod_btn: Button
var evo_btn: Button

# ============================================================
# _ready
# ============================================================
func _ready() -> void:
	visible = false
	modulate.a = 0.0
	_init_cached_styleboxes()
	_bind_nodes()
	_connect_signals()
	_apply_visual_styles()


func _bind_nodes() -> void:
	# TitleBar
	meta_label = get_node_or_null("%MetaLabel")
	close_btn = get_node_or_null("%CloseBtn")

	# 左栏
	col_head_count = get_node_or_null("%ColHeadCount")
	chip_all = get_node_or_null("%ChipAll")
	chip_enh = get_node_or_null("%ChipEnh")
	chip_max = get_node_or_null("%ChipMax")
	card_list_container = get_node_or_null("%CardListContainer")
	card_list_scroll = get_node_or_null("%CardListScroll")
	card_list_hint = get_node_or_null("%CardListHint")

	# HeroCard
	hero_card = get_node_or_null("%HeroCard")
	hero_art = get_node_or_null("%HeroArt")
	hero_art_icon = get_node_or_null("%HeroArtIcon")
	hero_name_label = get_node_or_null("%HeroName")
	hero_tags = get_node_or_null("%HeroTags")
	hero_power_label = get_node_or_null("%HeroPower")

	# ProgCards
	prog_card_amber = get_node_or_null("%ProgCardAmber")
	prog_card_cyan = get_node_or_null("%ProgCardCyan")
	prog_card_violet = get_node_or_null("%ProgCardViolet")
	prog_card_gold = get_node_or_null("%ProgCardGold")

	# 操作按钮
	enhance_btn = get_node_or_null("%EnhanceBtn")
	mod_btn = get_node_or_null("%ModBtn")
	evo_btn = get_node_or_null("%EvoBtn")
	# v8.x: 强化②（选词条）已停用，enhance_btn 改为"技能树"入口
	if enhance_btn:
		enhance_btn.text = "◆ 技能树"
		enhance_btn.tooltip_text = "打开相位师技能树（指挥/智能化/火力/概念武器）"

## v8.x: 更新技能树按钮红点提示（有可用技能点时显示 "●"）
func _update_skill_tree_badge() -> void:
	if enhance_btn == null:
		return
	if PhaseMasterSkillManager == null:
		return
	var avail: int = PhaseMasterSkillManager.get_available_points()
	if avail > 0:
		enhance_btn.text = "◆ 技能树 ●%d" % avail
		# 红点配色（modulate 不影响文字，仅改文字颜色提示）
		enhance_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.30))
	else:
		enhance_btn.text = "◆ 技能树"
		enhance_btn.remove_theme_color_override("font_color")


func _connect_signals() -> void:
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
	if chip_all:
		chip_all.pressed.connect(_on_filter_pressed.bind(FILTER_ALL))
	if chip_enh:
		chip_enh.pressed.connect(_on_filter_pressed.bind(FILTER_ENHANCEABLE))
	if chip_max:
		chip_max.pressed.connect(_on_filter_pressed.bind(FILTER_MAXED))
	if enhance_btn:
		enhance_btn.pressed.connect(_on_enhance_pressed)
	if mod_btn:
		mod_btn.pressed.connect(_on_mod_pressed)
	if evo_btn:
		evo_btn.pressed.connect(_on_evo_pressed)


# ============================================================
# 视觉样式
# ============================================================
func _apply_visual_styles() -> void:
	# HeroArt：菱形琥珀边框（与设计稿一致）
	if hero_art:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.06, 0.11, 1)
		sb.border_color = DT.COLOR_AMBER
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(10)
		sb.shadow_color = DT.COLOR_AMBER_GLOW
		sb.shadow_size = 10
		hero_art.add_theme_stylebox_override("panel", sb)

	# 关闭按钮 hover 红
	if close_btn:
		pass  # tscn 已定义 normal/hover

	# chip 初始 active 样式（全部）
	_update_chip_styles()

	# 字体：标题/卡名用 Rajdhani
	if hero_name_label:
		hero_name_label.add_theme_font_override("font", DT.get_title_font_bold())
	if hero_power_label:
		hero_power_label.add_theme_font_override("font", DT.get_title_font_bold())
	for btn in [enhance_btn, mod_btn, evo_btn]:
		if btn:
			btn.add_theme_font_override("font", DT.get_title_font())


func _update_chip_styles() -> void:
	var chips := {FILTER_ALL: chip_all, FILTER_ENHANCEABLE: chip_enh, FILTER_MAXED: chip_max}
	for mode in chips:
		var btn: Button = chips[mode]
		if btn == null:
			continue
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(3)
		sb.set_border_width_all(1)
		sb.content_margin_left = 8
		sb.content_margin_top = 4
		sb.content_margin_right = 8
		sb.content_margin_bottom = 4
		if mode == _filter_mode:
			sb.bg_color = Color(1.0, 0.85, 0.35, 0.12)
			sb.border_color = DT.COLOR_GOLD
			btn.add_theme_color_override("font_color", DT.COLOR_GOLD)
		else:
			sb.bg_color = Color(0.05, 0.09, 0.16, 0.4)
			sb.border_color = Color(0.25, 0.35, 0.42, 0.3)
			btn.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 0.8))
		btn.add_theme_stylebox_override("normal", sb)
		# hover 态
		var sb_h := sb.duplicate() as StyleBoxFlat
		sb_h.bg_color = Color(1.0, 0.85, 0.35, 0.06)
		btn.add_theme_stylebox_override("hover", sb_h)


# ============================================================
# 打开/关闭（保持公开契约）
# ============================================================
func show_panel(card: CardResource) -> void:
	if _is_open:
		return
	_is_open = true
	_selected_card = card
	visible = true
	modulate.a = 0.0
	scale = Vector2(0.92, 0.92)
	_update_skill_tree_badge()  # v8.x: 刷新技能树按钮红点（轻量，立即刷）
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, _anim_duration).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), _anim_duration).set_trans(Tween.TRANS_BACK)
	# v8.x 性能：_load_unlocked_cards（扫 InstanceRegistry + SaveManager + Blueprint 重建名册，
	# 内部对每张卡调 _format_power 触发 estimate_power_score 重操作）原与显示同帧，
	# 现挪到打开动画首帧之后，让用户先看到 fade-in 空壳再填充列表，避免打开同帧尖峰。
	tw.tween_callback(_deferred_load_unlocked_cards)
	tw.tween_callback(func(): _refresh_data())

## v8.x 性能：show_panel 的延迟入口，让出一帧再执行重活。
func _deferred_load_unlocked_cards() -> void:
	if not is_visible_in_tree():
		return
	_load_unlocked_cards()


func hide_panel() -> void:
	if not _is_open:
		return
	_is_open = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, _anim_duration).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(self, "scale", Vector2(0.92, 0.92), _anim_duration).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func():
		visible = false
	)
	closed.emit()


# ============================================================
# 卡牌加载（数据层逻辑保持不变）
# ============================================================
func _load_unlocked_cards() -> void:
	var all_ids: Array[String] = []
	var seen_full: Dictionary = {}
	var seen_base: Dictionary = {}
	var _sm = get_node_or_null("/root/SaveManager")
	var _ir = get_node_or_null("/root/InstanceRegistry")
	var _normalize := func(raw_id: String) -> String:
		if _ir != null and _ir.has_method("get_card_id_of"):
			return _ir.get_card_id_of(raw_id)
		var hi: int = raw_id.rfind("#")
		return raw_id.substr(0, hi) if hi >= 0 else raw_id
	if _ir != null and _ir.has_method("get_all_instance_ids"):
		for iid in _ir.get_all_instance_ids():
			var sid: String = String(iid)
			if sid.is_empty():
				continue
			if not seen_full.has(sid):
				all_ids.append(sid)
				seen_full[sid] = true
				seen_base[String(_normalize.call(sid))] = true
	if _sm:
		var pending: Array = _sm.get_pending_backpack_ids() if _sm.has_method("get_pending_backpack_ids") else []
		var last_known: Array = _sm.get_last_known_backpack_ids() if _sm.has_method("get_last_known_backpack_ids") else []
		for id in pending + last_known:
			var sid: String = String(id)
			if sid.is_empty():
				continue
			if seen_full.has(sid):
				continue
			var base_id: String = String(_normalize.call(sid))
			if seen_base.has(base_id):
				continue
			all_ids.append(sid)
			seen_full[sid] = true
			seen_base[base_id] = true
	var bp = get_node_or_null("/root/BlueprintManager")
	if bp:
		var bp_ids: Array = bp.get_all_blueprint_ids() if bp.has_method("get_all_blueprint_ids") else bp.get_unlocked_blueprint_ids()
		for id in bp_ids:
			var sid: String = String(id)
			if sid.is_empty():
				continue
			if not seen_base.has(sid) and not seen_full.has(sid):
				all_ids.append(sid)
				seen_full[sid] = true
				seen_base[sid] = true
	_last_unlocked_ids = all_ids
	if not _selected_card and not all_ids.is_empty():
		var first_card = _resolve_card(all_ids[0])
		if first_card:
			_selected_card = first_card
	refresh_card_list(all_ids)


func _resolve_card(id_str: String) -> CardResource:
	if id_str.is_empty():
		return null
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir != null and ir.has_method("get_instance"):
		var inst: CardResource = ir.get_instance(id_str)
		if inst != null:
			return inst
	var base_card_id: String = id_str
	if ir != null and ir.has_method("get_card_id_of"):
		base_card_id = ir.get_card_id_of(id_str)
	var hash_idx: int = id_str.rfind("#")
	if hash_idx < 0 and ir != null and ir.has_method("get_instances_by_card_id"):
		var insts: Array = ir.get_instances_by_card_id(base_card_id)
		if not insts.is_empty():
			var first_inst: CardResource = ir.get_instance(String(insts[0]))
			if first_inst != null:
				return first_inst
	return DefaultCards.get_card_by_id(base_card_id)


# ============================================================
# 卡牌列表渲染（新风格：缩略卡图 + 单行元信息 + 战力）
# ============================================================
func refresh_card_list(unlocked_ids: Array[String]) -> void:
	if not card_list_container:
		return
	for child in card_list_container.get_children():
		child.queue_free()

	# 应用筛选
	var filtered: Array[String] = []
	for iid in unlocked_ids:
		var card = _resolve_card(iid)
		if card == null:
			continue
		if _filter_mode == FILTER_ENHANCEABLE and card.enhance_level >= 10:
			continue
		if _filter_mode == FILTER_MAXED and card.enhance_level < 10:
			continue
		filtered.append(iid)

	if filtered.is_empty():
		if card_list_hint:
			card_list_hint.visible = true
			card_list_hint.text = "无匹配卡牌" if _filter_mode != FILTER_ALL else "无卡牌"
		if col_head_count:
			col_head_count.text = "0"
		return

	if card_list_hint:
		card_list_hint.visible = false

	if col_head_count:
		col_head_count.text = "%d / %d" % [filtered.size(), unlocked_ids.size()]

	for iid in filtered:
		var card = _resolve_card(iid)
		if not card:
			continue
		var item = _create_card_list_item(card, iid)
		card_list_container.add_child(item)


func _on_card_selected(card: CardResource) -> void:
	_selected_card = card
	refresh_card_list(_last_unlocked_ids)
	select_card(card)


func _create_card_list_item(card: CardResource, instance_id_raw: Variant) -> Control:
	var iid: String = String(instance_id_raw)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 48)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.text = ""
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 13)

	# 选中态判断
	var is_selected := false
	if _selected_card != null:
		var sel_iid := String(_selected_card.instance_id)
		if not sel_iid.is_empty():
			is_selected = (sel_iid == iid)
		else:
			is_selected = (iid.is_empty() or iid.split("#")[0] == _selected_card.card_id)

	# 按钮样式
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(0.04, 0.07, 0.12, 0.4)
	sb_n.set_border_width_all(0)
	sb_n.set_corner_radius_all(3)
	sb_n.content_margin_left = 6
	sb_n.content_margin_top = 4
	sb_n.content_margin_right = 6
	sb_n.content_margin_bottom = 4
	var sb_h := sb_n.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(0.1, 0.14, 0.22, 0.7)
	var sb_s := sb_n.duplicate() as StyleBoxFlat
	sb_s.bg_color = Color(0.13, 0.16, 0.24, 0.9)
	sb_s.border_width_left = 3
	sb_s.border_color = DT.COLOR_GOLD
	if is_selected:
		btn.add_theme_stylebox_override("normal", sb_s)
		btn.add_theme_stylebox_override("hover", sb_s)
	else:
		btn.add_theme_stylebox_override("normal", sb_n)
		btn.add_theme_stylebox_override("hover", sb_h)

	# 内容 HBox：缩略卡图 + 信息列 + 战力
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 8)

	# 缩略卡图（32×36，顶部稀有度色条）
	var thumb := PanelContainer.new()
	thumb.custom_minimum_size = Vector2(36, 40)
	thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var thumb_sb := StyleBoxFlat.new()
	thumb_sb.bg_color = Color(0.03, 0.06, 0.11, 1)
	thumb_sb.border_color = _get_kind_color(card.combat_kind)
	thumb_sb.set_border_width_all(1)
	thumb_sb.set_corner_radius_all(3)
	thumb.add_theme_stylebox_override("panel", thumb_sb)
	# 顶部稀有度色条（用 ColorRect 放在 thumb 上）
	var rarity_strip := ColorRect.new()
	rarity_strip.color = _get_rarity_color(card.rarity)
	rarity_strip.custom_minimum_size = Vector2(32, 2)
	rarity_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 兵种字母（占位图）
	var thumb_icon := Label.new()
	thumb_icon.text = _get_unit_icon(card)
	thumb_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thumb_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	thumb_icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	thumb_icon.add_theme_font_size_override("font_size", 16)
	thumb_icon.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	thumb_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.add_child(thumb_icon)
	hbox.add_child(thumb)

	# 信息列
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 2)
	info.custom_minimum_size = Vector2(150, 0)

	# 第一行：卡名 + 实例序号
	var name_hbox := HBoxContainer.new()
	name_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_hbox.add_theme_constant_override("separation", 4)
	var name_label := Label.new()
	name_label.text = card.display_name if card.display_name else card.card_id
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98, 1) if is_selected else Color(0.85, 0.88, 0.94, 1))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = false
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_hbox.add_child(name_label)
	# 实例序号
	if iid.find("#") >= 0:
		var parts := iid.split("#")
		if parts.size() >= 2:
			var seq_label := Label.new()
			seq_label.text = "#" + parts[1]
			seq_label.add_theme_font_size_override("font_size", 10)
			seq_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75, 0.7))
			seq_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			name_hbox.add_child(seq_label)
	info.add_child(name_hbox)

	# 第二行：Lv.N · Mx/9（单行内联）
	var meta_label := Label.new()
	var mod_count: int = 0
	if "mods" in card:
		var mods_arr = card.mods
		mod_count = mods_arr.size() if mods_arr is Array else 0
	meta_label.text = "Lv.%d  ·  M%d/9" % [card.enhance_level, mod_count]
	meta_label.add_theme_font_size_override("font_size", 11)
	meta_label.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7, 0.85))
	meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(meta_label)
	hbox.add_child(info)

	# 战力（右侧）
	var power_label := Label.new()
	var power_str := _format_power(card)
	power_label.text = power_str
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	power_label.add_theme_font_size_override("font_size", 12)
	power_label.add_theme_color_override("font_color", DT.COLOR_GOLD if power_str != "—" else Color(0.5, 0.5, 0.55, 0.5))
	power_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	power_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(power_label)

	btn.add_child(hbox)
	btn.pressed.connect(_on_card_selected.bind(card))
	return btn


# ============================================================
# 筛选
# ============================================================
func _on_filter_pressed(mode: String) -> void:
	_filter_mode = mode
	_update_chip_styles()
	refresh_card_list(_last_unlocked_ids)


# ============================================================
# 公开方法
# ============================================================
func select_card_by_id(card_id: String) -> void:
	if card_id.is_empty():
		return
	var card = _resolve_card(card_id)
	if card:
		_selected_card = card
		if visible:
			_refresh_data()


func select_card(card: CardResource) -> void:
	_selected_card = card
	if visible:
		_refresh_data()


# ============================================================
# 数据刷新
# ============================================================
func _refresh_data() -> void:
	if not _selected_card:
		return
	_selected_card = _ensure_selected_is_instance(_selected_card)
	_refresh_header()
	_refresh_star_section()
	_refresh_enhance_section()
	_refresh_mod_section()
	_refresh_evolution_section()


func _ensure_selected_is_instance(card: CardResource) -> CardResource:
	if card == null:
		return card
	if not card.instance_id.is_empty():
		return card
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir != null and ir.has_method("get_instances_by_card_id") and not card.card_id.is_empty():
		var insts: Array = ir.get_instances_by_card_id(card.card_id)
		if not insts.is_empty() and ir.has_method("get_instance"):
			var inst: CardResource = ir.get_instance(String(insts[0]))
			if inst != null:
				return inst
	return card


# ============================================================
# Header
# ============================================================
func _refresh_header() -> void:
	var c := _selected_card
	if not c:
		return

	# HeroArt 图标 + 边框（边框色随兵种，但保留下方 hero_art 的琥珀边框——此处仅更新 icon）
	if hero_art_icon:
		hero_art_icon.text = _get_unit_icon(c)
		hero_art_icon.add_theme_color_override("font_color", _get_kind_color(c.combat_kind))

	# 卡名 + card_id#instance
	if hero_name_label:
		var name_text := c.display_name if c.display_name else c.card_id
		var id_text := c.card_id
		if not c.instance_id.is_empty():
			id_text = c.instance_id
		hero_name_label.text = "%s   [color=#454f63][font_size=10]%s[/font_size][/color]" % [name_text, id_text]
		hero_name_label.text = name_text  # 简化：纯文本，id 显示在 meta
	# MetaLabel 显示 card_id#instance
	if meta_label:
		var id_text := c.card_id.to_upper()
		if not c.instance_id.is_empty():
			id_text = c.instance_id
		var era_name = GameConstants.get_era_name(c.era)
		meta_label.text = "%s  ·  %s" % [id_text, era_name] if era_name else id_text

	# 标签：时代 / 兵种 / 军衔星级 / 可进化
	if hero_tags:
		for child in hero_tags.get_children():
			child.queue_free()
		# 时代
		var era_name = GameConstants.get_era_name(c.era)
		if era_name:
			_add_hero_tag(era_name, _get_era_color(c.era))
		# 兵种
		if c.card_type == GC.CardType.COMBAT_UNIT:
			_add_hero_tag(CardResource.get_combat_kind_name(c.combat_kind), _get_kind_color(c.combat_kind))
		# 星级（军衔）
		var star: int = _calculate_star()
		var star_str := ""
		for i in range(5):
			star_str += "★" if i < star else "☆"
		_add_hero_tag(star_str, DT.COLOR_GOLD)
		# 可进化标记
		var evo_paths: Array = c.evolution_paths if "evolution_paths" in c else []
		if not evo_paths.is_empty():
			_add_hero_tag("可进化", DT.COLOR_VIOLET_SOFT)

	# 综合战力
	if hero_power_label:
		hero_power_label.text = _format_power(c)


# ============================================================
# 2×2 进度卡片填充
# ============================================================
# --- 星级评估（ProgCardGold） ---
func _refresh_star_section() -> void:
	if prog_card_gold == null or _selected_card == null:
		return
	var body: VBoxContainer = _get_prog_body(prog_card_gold)
	if body == null:
		return
	for child in body.get_children():
		child.queue_free()

	var c := _selected_card
	var star: int = _calculate_star()
	var rarity_name: String = c.rarity

	# 星星行
	var stars_row := HBoxContainer.new()
	stars_row.add_theme_constant_override("separation", 2)
	for i in range(5):
		var s := Label.new()
		s.text = "★" if i < star else "☆"
		s.add_theme_font_size_override("font_size", 16)
		s.add_theme_color_override("font_color", DT.COLOR_GOLD if i < star else Color(0.27, 0.31, 0.39, 1))
		stars_row.add_child(s)
	body.add_child(stars_row)

	# 统计行
	_add_prog_stat(body, "综合星级", "%d/5" % star)
	_add_prog_stat(body, "稀有度", rarity_name, _get_rarity_color(c.rarity))
	_add_prog_stat(body, "强化等级", "Lv.%d/10" % c.enhance_level)

	# 进度条
	var next_cost := StarConfig.get_research_cost_for_next_star(star, c.rarity)
	var bp = get_node_or_null("/root/BlueprintManager")
	var cur_rp: int = 0
	if bp and bp.has_method("get_star_progress"):
		var progress: Dictionary = bp.get_star_progress(c.card_id)
		cur_rp = int(progress.get("current_research", 0))
	var bar := _create_progress_bar(DT.COLOR_GOLD, cur_rp, next_cost)
	body.add_child(bar)

	# 提示
	if next_cost <= 0:
		_add_prog_hint(body, "已达最高星级")
	else:
		_add_prog_hint(body, "下一星 · 研究点 %s / %s" % [_format_number(cur_rp), _format_number(next_cost)])

	# 状态标签
	_set_prog_status(prog_card_gold, "Lv.%d" % star)


# --- 强化系统（ProgCardAmber） ---
func _refresh_enhance_section() -> void:
	if prog_card_amber == null or _selected_card == null:
		return
	var body: VBoxContainer = _get_prog_body(prog_card_amber)
	if body == null:
		return
	for child in body.get_children():
		child.queue_free()

	var c := _selected_card
	var cur_lv: int = c.enhance_level
	var max_lv: int = 10
	var is_maxed := cur_lv >= max_lv

	# 进度条
	var pct := float(cur_lv) / float(max_lv)
	var bar := _create_progress_bar_pct(DT.COLOR_AMBER, pct)
	body.add_child(bar)

	# 统计
	_add_prog_stat(body, "当前等级", "Lv.%d/%d" % [cur_lv, max_lv])
	if is_maxed:
		_add_prog_stat(body, "状态", "已满级", DT.COLOR_GOLD)
	else:
		# 下一级消耗（纳米材料）
		var next_cost := _estimate_next_enhance_cost(c)
		_add_prog_stat(body, "下一级消耗", "%s 纳米" % _format_number(next_cost))
		_add_prog_hint(body, "Lv.%d → 全属性+5%%" % (cur_lv + 1))

	# 状态标签
	_set_prog_status(prog_card_amber, "可强化" if not is_maxed else "已满级")


# --- 改造系统（ProgCardCyan） ---
func _refresh_mod_section() -> void:
	if prog_card_cyan == null or _selected_card == null:
		return
	var body: VBoxContainer = _get_prog_body(prog_card_cyan)
	if body == null:
		return
	for child in body.get_children():
		child.queue_free()

	var c := _selected_card
	var mod_count: int = 0
	if "mods" in c:
		var mods_arr = c.mods
		mod_count = mods_arr.size() if mods_arr is Array else 0
	var max_mods: int = 9

	# 9 格 tag 行
	var slots_row := HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", 3)
	for i in range(max_mods):
		var tag := _make_slot_tag(i < mod_count)
		slots_row.add_child(tag)
	body.add_child(slots_row)

	# 统计
	_add_prog_stat(body, "已装模块", "%d/%d" % [mod_count, max_mods])
	_add_prog_stat(body, "战力档位", _get_power_tier_name(c))
	_add_prog_stat(body, "候选改造", "%d 个可用" % _count_available_mods(c))

	# 状态标签
	_set_prog_status(prog_card_cyan, "可改造" if mod_count < max_mods else "已满槽")


# --- 进化系统（ProgCardViolet） ---
func _refresh_evolution_section() -> void:
	if prog_card_violet == null or _selected_card == null:
		return
	var body: VBoxContainer = _get_prog_body(prog_card_violet)
	if body == null:
		return
	for child in body.get_children():
		child.queue_free()

	var c := _selected_card
	# v7.x：用 get_evolution_targets() 获取完整目标列表（主线+势力+情报分支），
	# 而非旧字段 evolution_paths（可能为空或单一目标）。
	var evo_targets: Array = []
	if c.has_method("get_evolution_targets"):
		evo_targets = c.get_evolution_targets()

	if evo_targets.is_empty():
		_add_prog_hint(body, "无可用进化路线（终阶形态）")
		_set_prog_status(prog_card_violet, "终阶")
		return

	# 显示前 N 个目标（卡片空间有限，最多 3 个）
	var shown := mini(evo_targets.size(), 3)
	for i in range(shown):
		var t: Dictionary = evo_targets[i] if evo_targets[i] is Dictionary else {}
		var target_id: String = String(t.get("target_id", ""))
		var target_name: String = String(t.get("name", target_id))
		var path_type: String = String(t.get("path_type", "main"))
		if target_id.is_empty():
			continue
		# 路径类型 tag（主线/势力分支/情报隐藏）
		var type_label := "主线" if path_type == "main" else ("势力" if path_type == "faction" else "情报")
		var type_col := DT.COLOR_GOLD if path_type == "main" else (DT.COLOR_VIOLET_SOFT if path_type == "faction" else DT.COLOR_CYAN_TECH_SOFT)
		# 战力变化
		var target_card = DefaultCards.get_card_by_id(target_id)
		var power_delta := ""
		if target_card:
			var cur_power := _estimate_power_value(c)
			var tgt_power := _estimate_power_value(target_card)
			if cur_power > 0 and tgt_power > 0:
				var pct := int((float(tgt_power) / float(maxi(1, cur_power)) - 1.0) * 100.0)
				var sign := "+" if pct >= 0 else ""
				power_delta = "%s%d%%" % [sign, pct]
		# 进化条件（取首个目标的校验结果）
		var met_count := 0
		var total_count := 0
		var bp = get_node_or_null("/root/BlueprintManager")
		if bp and bp.has_method("can_evolve_blueprint"):
			var can_info: Dictionary = bp.can_evolve_blueprint(c.card_id, target_id)
			if bool(can_info.get("ok", false)):
				met_count = 3
				total_count = 3
			else:
				# 统计已满足/总数
				var enh_req: int = int(can_info.get("enhance_requirement", 0))
				var mod_req: int = int(can_info.get("mod_requirement", 0))
				if enh_req > 0:
					total_count += 1
					if int(can_info.get("current_enhance", 0)) >= enh_req:
						met_count += 1
				if mod_req > 0:
					total_count += 1
					if int(can_info.get("current_mod_count", 0)) >= mod_req:
						met_count += 1
				# 图纸
				total_count += 1
				var evo_bp_id := BlueprintDefinitions.get_evolution_blueprint_id(c.card_id, target_id)
				var has_bp := false
				var _iib = Engine.get_main_loop().get_root().get_node_or_null("IntelItemBag")
				if _iib and not evo_bp_id.is_empty():
					has_bp = _iib.has_item(evo_bp_id)
				if has_bp:
					met_count += 1
		_add_evo_target_row(body, target_name, type_label, type_col, power_delta, met_count, total_count)

	# 属性对比（取首个目标的 before→after）
	var first_target_id: String = ""
	if not evo_targets.is_empty():
		var ft: Dictionary = evo_targets[0] if evo_targets[0] is Dictionary else {}
		first_target_id = String(ft.get("target_id", ""))
	if not first_target_id.is_empty() and c.has_method("calculate_evolved_stats"):
		var evolved_stats: Dictionary = c.calculate_evolved_stats(first_target_id)
		if not evolved_stats.is_empty():
			_add_prog_hint(body, "HP %d→%d · 攻击 +%d" % [
				int(c.base_hp),
				int(float(evolved_stats.get("hp", c.base_hp))),
				maxi(0, int(float(evolved_stats.get("attack_light", c.attack_light))) - c.attack_light),
			])

	_set_prog_status(prog_card_violet, "%d 路线" % evo_targets.size())


## v7.x 辅助：估算卡牌战力数值（用于进化前后对比）
func _estimate_power_value(card: CardResource) -> int:
	var bp = get_node_or_null("/root/BlueprintManager")
	if bp == null or card == null:
		return 0
	var id_to_eval: String = card.instance_id if not card.instance_id.is_empty() else card.card_id
	if id_to_eval.is_empty():
		return 0
	var power := EvolutionHelpers.estimate_power_score(id_to_eval, bp)
	return int(round(power))


## v7.x 辅助：添加进化目标行（网页 evo-node 卡片样式浓缩版）
func _add_evo_target_row(parent: VBoxContainer, name: String, type_label: String, type_col: Color, power_delta: String, met: int, total: int) -> void:
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.075, 0.102, 0.165, 0.5)
	sb.border_width_left = 2
	sb.border_color = type_col
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 8
	sb.content_margin_top = 4
	sb.content_margin_right = 8
	sb.content_margin_bottom = 4
	row.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 6)

	# 类型 tag
	var type_lbl := Label.new()
	type_lbl.text = type_label
	type_lbl.add_theme_font_size_override("font_size", 10)
	type_lbl.add_theme_color_override("font_color", type_col)
	type_lbl.custom_minimum_size = Vector2(28, 0)
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(type_lbl)

	# 目标名
	var name_lbl := Label.new()
	name_lbl.text = name
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96, 1))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = false
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(name_lbl)

	# 战力变化
	if not power_delta.is_empty():
		var delta_lbl := Label.new()
		delta_lbl.text = power_delta
		delta_lbl.add_theme_font_size_override("font_size", 10)
		var is_up := power_delta.begins_with("+")
		delta_lbl.add_theme_color_override("font_color", DT.COLOR_GREEN_UP if is_up else DT.COLOR_RED_DOWN)
		delta_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(delta_lbl)

	# 条件满足数
	var cond_lbl := Label.new()
	cond_lbl.text = "%d/%d" % [met, total]
	cond_lbl.add_theme_font_size_override("font_size", 10)
	cond_lbl.add_theme_color_override("font_color", DT.COLOR_GREEN_UP if met >= total else DT.COLOR_AMBER_SOFT)
	cond_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(cond_lbl)

	row.add_child(hbox)
	parent.add_child(row)


# ============================================================
# 导航（保持原有逻辑）
# ============================================================
func _on_close_pressed() -> void:
	hide_panel()


func _on_enhance_pressed() -> void:
	# v8.x: 强化②已停用，此按钮改为打开相位师技能树面板
	_open_phase_master_skill_panel()

## v8.x: 打开相位师技能树面板
## 直接实例化场景挂到 PopupLayer（不依赖 UILazyLoader 的 parent_path，避免 main.tscn 无 overlay 节点）
func _open_phase_master_skill_panel() -> void:
	# 先查 PopupLayer 下是否已存在面板（复用，避免重复实例化）
	var canvas: CanvasLayer = get_tree().root.get_node_or_null("PopupLayer")
	if canvas == null:
		canvas = CanvasLayer.new()
		canvas.name = "PopupLayer"
		canvas.layer = 100
		get_tree().root.add_child(canvas)
	var existing: Node = canvas.get_node_or_null("PhaseMasterSkillPanel")
	var panel: Node = existing
	if panel == null:
		# 实例化场景
		var scene = load("res://scenes/ui/phase_master_skill_panel.tscn")
		if scene == null:
			push_error("[growth_panel] 无法加载相位师技能树面板场景")
			return
		panel = scene.instantiate()
		if panel == null:
			push_error("[growth_panel] 相位师技能树面板实例化失败")
			return
		canvas.add_child(panel)
		if panel.has_signal("closed") and not panel.closed.is_connected(_on_phase_master_skill_closed):
			panel.closed.connect(_on_phase_master_skill_closed)
	# 居中显示
	if panel is Control:
		(panel as Control).anchors_preset = Control.PRESET_CENTER
	panel.visible = true
	if panel.has_method("_refresh"):
		panel._refresh()

## v8.x: 技能树面板关闭回调
func _on_phase_master_skill_closed() -> void:
	# 面板自身已 hide；关闭后刷新红点（点数可能已变化）
	_update_skill_tree_badge()


func _on_mod_pressed() -> void:
	if not _selected_card:
		return
	_open_target_panel("modification")


func _on_evo_pressed() -> void:
	if not _selected_card:
		return
	_open_target_panel("evolution")


func _open_target_panel(panel_key: String) -> void:
	var card_to_select: CardResource = _selected_card
	if _is_open:
		_is_open = false
		modulate.a = 0.0
		visible = false
		closed.emit()
	var main = get_node_or_null("/root/Main")
	if main and main.has_method("_toggle_overlay"):
		var overlay = main._overlay_for_panel_key(panel_key) if main.has_method("_overlay_for_panel_key") else null
		if overlay:
			main._toggle_overlay(overlay, panel_key)
			_preselect_target_card(overlay, panel_key, card_to_select)


func _preselect_target_card(overlay: Control, panel_key: String, card: CardResource) -> void:
	if card == null or overlay == null:
		return
	var panel: Node = overlay.get_node_or_null("CenterContainer/%s" % _target_panel_node_name(panel_key))
	if panel == null:
		panel = overlay.find_child(_target_panel_node_name(panel_key), true, false)
	if panel == null:
		return
	match panel_key:
		"enhancement":
			if panel.has_method("select_card_by_id"):
				var sel_id: String = card.instance_id if not card.instance_id.is_empty() else card.card_id
				if card.instance_id.is_empty():
					var ir: Node = get_node_or_null("/root/InstanceRegistry")
					if ir != null and ir.has_method("get_instances_by_card_id"):
						var insts: Array = ir.get_instances_by_card_id(card.card_id)
						if not insts.is_empty():
							sel_id = String(insts[0])
				panel.select_card_by_id(sel_id)
		"modification", "evolution":
			var card_to_pass: CardResource = card
			if card.instance_id.is_empty():
				var ir: Node = get_node_or_null("/root/InstanceRegistry")
				if ir != null and ir.has_method("get_instances_by_card_id"):
					var insts: Array = ir.get_instances_by_card_id(card.card_id)
					if not insts.is_empty() and ir.has_method("get_instance"):
						var resolved: CardResource = ir.get_instance(String(insts[0]))
						if resolved != null:
							card_to_pass = resolved
			if panel.has_method("set_selected_card"):
				panel.set_selected_card(card_to_pass)


func _target_panel_node_name(panel_key: String) -> String:
	match panel_key:
		"enhancement": return "CardEnhancementPanel"
		"modification": return "ModificationPanel"
		"evolution": return "EvolutionPanel"
	return ""


# ============================================================
# ProgCard 辅助
# ============================================================
func _get_prog_body(card_node: PanelContainer) -> VBoxContainer:
	if card_node == null:
		return null
	return card_node.get_node_or_null("ProgVBox/ProgBody")


func _set_prog_status(card_node: PanelContainer, text: String) -> void:
	if card_node == null:
		return
	var status: Label = card_node.get_node_or_null("ProgVBox/ProgHead/ProgStatus")
	if status:
		status.text = text


func _add_prog_stat(parent: VBoxContainer, label: String, value: String, value_color: Color = Color(0.9, 0.92, 0.96, 1)) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 0.85))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var val := Label.new()
	val.text = value
	val.add_theme_font_size_override("font_size", 11)
	val.add_theme_color_override("font_color", value_color)
	row.add_child(val)
	parent.add_child(row)


func _add_prog_cond(parent: VBoxContainer, label: String, value: String, is_met: bool) -> void:
	_add_prog_stat(parent, label, "%s %s" % ["✓" if is_met else "✗", value],
		DT.COLOR_GREEN_UP if is_met else DT.COLOR_RED_DOWN)


func _add_prog_hint(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.4, 0.45, 0.55, 0.8))
	parent.add_child(lbl)


func _create_progress_bar(fill_color: Color, current: int, target: int) -> ProgressBar:
	var pct := 0.0
	if target > 0:
		pct = clampf(float(current) / float(target), 0.0, 1.0)
	return _create_progress_bar_pct(fill_color, pct)


func _create_progress_bar_pct(fill_color: Color, pct: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = pct * 100.0
	bar.custom_minimum_size = Vector2(0, 5)
	bar.show_percentage = false
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.03, 0.06, 0.11, 0.9)
	bg_sb.set_border_width_all(1)
	bg_sb.border_color = Color(0.25, 0.35, 0.42, 0.2)
	bg_sb.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg_sb)
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = fill_color
	fill_sb.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill_sb)
	return bar


func _make_slot_tag(filled: bool) -> PanelContainer:
	var tag := PanelContainer.new()
	tag.custom_minimum_size = Vector2(20, 20)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(2)
	sb.set_border_width_all(1)
	if filled:
		sb.bg_color = Color(DT.COLOR_CYAN_TECH_SOFT.r, DT.COLOR_CYAN_TECH_SOFT.g, DT.COLOR_CYAN_TECH_SOFT.b, 0.15)
		sb.border_color = DT.COLOR_CYAN_TECH_SOFT
	else:
		sb.bg_color = Color(0.05, 0.09, 0.16, 0.3)
		sb.border_color = Color(0.25, 0.35, 0.42, 0.3)
	tag.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = "+" if not filled else "●"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", DT.COLOR_CYAN_TECH_SOFT if filled else Color(0.4, 0.45, 0.55, 0.5))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(lbl)
	return tag


# ============================================================
# HeroCard 标签
# ============================================================
func _add_hero_tag(text: String, color: Color) -> void:
	if hero_tags == null:
		return
	var tag := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.r, color.g, color.b, 0.08)
	sb.border_color = Color(color.r, color.g, color.b, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 7
	sb.content_margin_top = 2
	sb.content_margin_right = 7
	sb.content_margin_bottom = 2
	tag.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(lbl)
	hero_tags.add_child(tag)


# ============================================================
# 战力 / 资源辅助
# ============================================================
func _format_power(card: CardResource) -> String:
	var bp = get_node_or_null("/root/BlueprintManager")
	if bp == null:
		return "—"
	var id_to_eval: String = card.instance_id if not card.instance_id.is_empty() else card.card_id
	if id_to_eval.is_empty():
		return "—"
	var power := EvolutionHelpers.estimate_power_score(id_to_eval, bp)
	if power <= 0:
		return "—"
	return _format_number(int(round(power)))


func _estimate_next_enhance_cost(card: CardResource) -> int:
	# 简化估算：每级 50 × (level+1)
	return 50 * (card.enhance_level + 1)


func _count_available_mods(card: CardResource) -> int:
	# 简化：返回注册表中该兵种类型可用的改造总数（运行时由 modification_panel 详查）
	return 14


func _get_power_tier_name(card: CardResource) -> String:
	# 简化：基于战力的 5 档
	var bp = get_node_or_null("/root/BlueprintManager")
	if bp == null:
		return "GRUNT"
	var id_to_eval: String = card.instance_id if not card.instance_id.is_empty() else card.card_id
	var power := EvolutionHelpers.estimate_power_score(id_to_eval, bp)
	if power < 150: return "GRUNT 灰"
	if power < 260: return "VETERAN 绿"
	if power < 420: return "ELITE 蓝"
	if power < 720: return "CHAMPION 紫"
	return "OVERLORD 金"


# ============================================================
# 颜色/图标辅助
# ============================================================
func _calculate_star() -> int:
	if _selected_card == null:
		return 0
	return StarConfig.calculate_star(_selected_card.enhance_level * 2, _selected_card.rarity)


func _get_unit_icon(card: CardResource) -> String:
	var kind_names = CardResource.get_combat_kind_name(card.combat_kind)
	match kind_names:
		"步兵": return "⚔"
		"装甲": return "◈"
		"炮兵": return "◎"
		"防空": return "↑"
		"空军": return "✈"
		"侦察": return "◉"
		"工程": return "⚙"
		"堡垒": return "■"
		_: return "⚔"


func _get_kind_color(combat_kind: int) -> Color:
	# v1.5：收敛到 DesignTokens 单一源（旧本地 match 键名错位，除装甲外全灰）
	return DT.get_kind_color(combat_kind)


func _get_rarity_color(rarity: String) -> Color:
	match rarity.to_lower():
		"common": return Color(0.42, 0.46, 0.57)
		"uncommon": return Color(0.13, 0.77, 0.37)
		"rare": return Color(0.22, 0.74, 0.97)
		"epic": return Color(0.75, 0.52, 0.99)
		"legendary": return DT.COLOR_AMBER
		"mythic": return DT.COLOR_RED_DOWN
		_: return Color(0.5, 0.5, 0.5)


func _get_era_color(era: int) -> Color:
	match era:
		0: return Color(0.7, 0.72, 0.78)  # WW1
		1: return Color(0.9, 0.4, 0.35)   # WW2
		2: return Color(0.3, 0.5, 0.9)    # Cold
		3: return DT.COLOR_CYAN_TECH_SOFT # Modern
		4: return DT.COLOR_VIOLET_SOFT    # Future
		_: return Color(0.6, 0.62, 0.68)


func _format_number(n: int) -> String:
	return FormatUtil.format_thousands(n)


func _init_cached_styleboxes() -> void:
	_tag_stylebox = StyleBoxFlat.new()
	_tag_stylebox.bg_color = Color(1.0, 0.85, 0.35, 0.12)
	_tag_stylebox.border_color = Color(1.0, 0.85, 0.35, 0.5)
	_tag_stylebox.set_border_width_all(1)
	_tag_stylebox.set_corner_radius_all(3)
	_tag_stylebox.content_margin_left = 8
	_tag_stylebox.content_margin_top = 3
	_tag_stylebox.content_margin_right = 8
	_tag_stylebox.content_margin_bottom = 3
