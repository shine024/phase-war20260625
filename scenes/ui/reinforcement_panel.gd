extends Control
class_name ReinforcementPanel
## 强化面板（新系统）
## 显示军事称号而非数字等级

signal closed

# === 主题色（绿色强化主题） ===
const THEME_GREEN := Color(0.3, 0.92, 0.5, 1)
const THEME_GREEN_SOFT := Color(0.2, 0.7, 0.38, 1)
const THEME_CYAN := Color(0.0, 0.9, 1.0, 1)
const THEME_GOLD := Color(1.0, 0.85, 0.35, 1)
const THEME_PURPLE := Color(0.75, 0.55, 1.0, 1)
const THEME_RED := Color(0.95, 0.4, 0.4, 1)
const THEME_TEXT := Color(0.88, 0.92, 0.98, 1)
const THEME_TEXT_DIM := Color(0.6, 0.66, 0.78, 1)
const THEME_BG_CARD := Color(0.07, 0.12, 0.16, 0.92)
const THEME_BG_SLOT := Color(0.05, 0.08, 0.11, 0.95)
const THEME_BORDER_DIM := Color(0.25, 0.35, 0.42, 0.7)

# UI 组件引用
@onready var card_list_container = $VBoxContainer/MainHBox/ScrollContainer/CardListContainer
@onready var card_detail_panel = $VBoxContainer/MainHBox/DetailPanel
@onready var reinforce_button = $VBoxContainer/MainHBox/DetailPanel/CardDetailVBox/ReinforceButton
@onready var nano_label = $VBoxContainer/ResourceBar/ResourceHBox/NanoLabel
@onready var result_label = $VBoxContainer/ResultLabel

var selected_card: CardResource = null
var _embedded_mode: bool = false

func _ready() -> void:
	# 连接关闭按钮
	var close_btn = get_node_or_null("VBoxContainer/TitleRow/CloseButton")
	if close_btn:
		close_btn.pressed.connect(_on_close)
	# 连接晋升按钮
	if reinforce_button:
		reinforce_button.pressed.connect(_on_reinforce_pressed)

	if _embedded_mode:
		_apply_embedded_layout()
	else:
		# 刷新卡牌列表
		_refresh_card_list()

## 内嵌模式：隐藏 TitleRow + 左侧卡牌列表
func set_embedded_mode(p_embedded: bool) -> void:
	_embedded_mode = p_embedded
	if is_inside_tree():
		_apply_embedded_layout()

func _apply_embedded_layout() -> void:
	var title_row = get_node_or_null("VBoxContainer/TitleRow")
	if title_row:
		title_row.visible = false
	var scroll = get_node_or_null("VBoxContainer/HBoxContainer/ScrollContainer")
	if scroll:
		scroll.visible = false

## ─────────────────────────────────────────────
##  UI更新
## ─────────────────────────────────────────────

func _refresh_card_list() -> void:
	if card_list_container == null:
		return
	# 清空列表
	for child in card_list_container.get_children():
		child.queue_free()

	# 获取所有蓝图卡牌
	var DefaultCards = preload("res://data/default_cards.gd")
	for id_raw in BlueprintManager.get_all_blueprint_ids():
		var card_id: String = str(id_raw)
		var card: CardResource = DefaultCards.get_card_by_id(card_id)
		if card == null:
			continue
		var item = _create_card_item(card)
		card_list_container.add_child(item)

func _create_card_item(card: CardResource) -> Control:
	var item = Button.new()
	item.text = card.display_name
	item.custom_minimum_size = Vector2(200, 42)
	item.add_theme_font_size_override("font_size", 14)
	item.clip_text = true
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_theme_stylebox_override("normal", _make_sb(THEME_BG_CARD * Color(1, 1, 1, 0.6), THEME_BORDER_DIM, 1, 5, Color(0, 0, 0, 0), 0, 10, 6, 10, 6))
	item.add_theme_stylebox_override("hover", _make_sb(THEME_GREEN * Color(1, 1, 1, 0.1), THEME_GREEN_SOFT * Color(1, 1, 1, 0.6), 1, 5, Color(0, 0, 0, 0), 0, 10, 6, 10, 6))

	# 获取当前军衔
	var rank_info = card.get_military_rank()
	var level = card.enhance_level
	item.tooltip_text = "Lv%d · %s\n战力：%d" % [level, rank_info.name, card.get_current_power()]

	item.pressed.connect(func(): _on_card_selected(card))
	return item

func _update_detail_panel() -> void:
	if not selected_card:
		card_detail_panel.visible = false
		return

	card_detail_panel.visible = true
	# 切换占位提示 ↔ 详情区（修复详情区一直不显示的问题）
	var info_label = card_detail_panel.get_node_or_null("InfoLabel")
	var detail_vbox = card_detail_panel.get_node_or_null("CardDetailVBox")
	if info_label:
		info_label.visible = false
	if detail_vbox:
		detail_vbox.visible = true
		_clear_dyn(detail_vbox)

	# 获取军衔信息
	var rank_info = selected_card.get_military_rank()
	var next_rank_info = selected_card.get_next_rank_info()

	# 更新UI文本
	_update_card_info()
	_update_rank_info(rank_info, next_rank_info)
	_update_reinforce_button(rank_info)

	# 更新资源标签
	if nano_label:
		var nano_amount = BasicResourceManager.get_total(BasicResources.ID_NANO_MATERIALS)
		nano_label.text = "🧪 纳米材料：%d" % nano_amount

func _update_card_info() -> void:
	var detail_vbox = card_detail_panel.get_node_or_null("CardDetailVBox")
	if detail_vbox == null or selected_card == null:
		return
	# 卡牌信息卡片（插入详情区顶部）
	var info_card := PanelContainer.new()
	info_card.name = "_dyn_info_card"
	info_card.add_theme_stylebox_override("panel", _make_sb(THEME_BG_CARD, THEME_GREEN_SOFT * Color(1, 1, 1, 0.5), 1, 6, THEME_GREEN * Color(1, 1, 1, 0.12), 4, 14, 12, 14, 12))
	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 6)
	var name_l := Label.new()
	name_l.text = selected_card.display_name
	name_l.add_theme_font_size_override("font_size", 22)
	name_l.add_theme_color_override("font_color", THEME_CYAN)
	name_l.add_theme_color_override("font_outline_color", Color(0, 0.12, 0.18, 0.75))
	name_l.add_theme_constant_override("outline_size", 2)
	info_vbox.add_child(name_l)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	chips.add_child(_make_chip("⚡ 战力 %d" % selected_card.get_current_power(), THEME_CYAN * Color(1, 1, 1, 0.15), THEME_CYAN * Color(1, 1, 1, 0.6), THEME_CYAN, 13))
	chips.add_child(_make_chip("⬆ 强化 Lv.%d" % selected_card.enhance_level, THEME_GREEN * Color(1, 1, 1, 0.16), THEME_GREEN * Color(1, 1, 1, 0.65), THEME_GREEN, 13))
	info_vbox.add_child(chips)
	info_card.add_child(info_vbox)
	detail_vbox.add_child(info_card)
	detail_vbox.move_child(info_card, 0)

func _update_rank_info(rank_info: Dictionary, next_rank_info: Dictionary) -> void:
	var detail_vbox = card_detail_panel.get_node_or_null("CardDetailVBox")
	# 隐藏被对比卡片取代的静态军衔标签
	var rank_label = card_detail_panel.get_node_or_null("RankLabel")
	var desc_label = card_detail_panel.get_node_or_null("RankDescLabel")
	if rank_label:
		rank_label.visible = false
	if desc_label:
		desc_label.visible = false
	# 当前 → 下一军衔 对比卡片
	if detail_vbox:
		var compare := HBoxContainer.new()
		compare.name = "_dyn_compare"
		compare.add_theme_constant_override("separation", 8)
		compare.add_child(_make_rank_card(rank_info.name, rank_info.desc, THEME_GOLD, false))
		if not next_rank_info.is_empty():
			var arrow := Label.new()
			arrow.text = "➜"
			arrow.add_theme_font_size_override("font_size", 24)
			arrow.add_theme_color_override("font_color", THEME_GREEN)
			arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			compare.add_child(arrow)
			compare.add_child(_make_rank_card(String(next_rank_info.get("next_name", "??")), "", THEME_GREEN, true))
		detail_vbox.add_child(compare)
		detail_vbox.move_child(compare, 1)
	# 进度条
	var progress_bar = card_detail_panel.get_node_or_null("RankProgressBar")
	if progress_bar and progress_bar is ProgressBar:
		progress_bar.value = selected_card.get_rank_progress() * 100
	# 下一级提示
	if not next_rank_info.is_empty():
		var next_label = card_detail_panel.get_node_or_null("NextRankLabel")
		if next_label:
			var progress_pct = int(next_rank_info.progress * 100)
			next_label.text = "晋升进度：%d%% → %s" % [progress_pct, next_rank_info.next_name]

func _update_reinforce_button(rank_info: Dictionary) -> void:
	if not reinforce_button:
		return

	var current_level = selected_card.enhance_level
	if current_level >= 10:
		reinforce_button.disabled = true
		reinforce_button.text = "★ 已达最高军衔"
		return

	reinforce_button.disabled = false

	# 计算消耗
	var next_level = current_level + 1
	var cost_multiplier = UnifiedRankSystem.get_cost_multiplier(next_level)
	var nano_cost = int(selected_card.power * cost_multiplier)

	reinforce_button.text = "🎖 晋升（消耗 %d 纳米）" % nano_cost

## ─────────────────────────────────────────────
##  事件处理
## ─────────────────────────────────────────────

func _on_card_selected(card: CardResource) -> void:
	selected_card = card
	_update_detail_panel()

func _on_reinforce_pressed() -> void:
	if not selected_card:
		return

	var current_level = selected_card.enhance_level
	if current_level >= 10:
		_show_result("已达最高等级")
		return

	var next_level = current_level + 1
	var result = BlueprintManager.apply_reinforcement(selected_card, next_level)

	if result.success:
		_show_result("强化成功！%s → %s" % [result.message, selected_card.get_military_rank().name])
		_update_detail_panel()
	else:
		_show_result("强化失败：%s" % result.message)


## 供外部调用的接口
func set_selected_card(card: CardResource) -> void:
	selected_card = card
	if has_node("VBoxContainer/HBoxContainer/DetailPanel"):
		_update_detail_panel()

func show_panel() -> void:
	visible = true
	if not _embedded_mode:
		_refresh_card_list()

func _on_close() -> void:
	closed.emit()

func _show_result(message: String) -> void:
	if result_label:
		result_label.text = message
		result_label.visible = true
		# 3秒后自动隐藏
		await get_tree().create_timer(3.0).timeout
		if not is_inside_tree():
			return
		result_label.visible = false


# ─────────────────────────────────────────────
#  UI 美化 helper
# ─────────────────────────────────────────────

## 生成可复用 StyleBoxFlat
func _make_sb(bg: Color, border: Color, border_w: float, corner: float, \
		shadow_color := Color(0, 0, 0, 0), shadow_size := 0, \
		ml := 0.0, mt := 0.0, mr := 0.0, mb := 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = border_w
	sb.border_width_top = border_w
	sb.border_width_right = border_w
	sb.border_width_bottom = border_w
	sb.corner_radius_top_left = corner
	sb.corner_radius_top_right = corner
	sb.corner_radius_bottom_left = corner
	sb.corner_radius_bottom_right = corner
	if shadow_size > 0:
		sb.shadow_color = shadow_color
		sb.shadow_size = shadow_size
	if ml > 0 or mt > 0 or mr > 0 or mb > 0:
		sb.content_margin_left = ml
		sb.content_margin_top = mt
		sb.content_margin_right = mr
		sb.content_margin_bottom = mb
	return sb

## 清除父节点下所有 "_dyn_" 前缀的动态子节点
func _clear_dyn(parent: Node) -> void:
	if parent == null:
		return
	for c in parent.get_children():
		if c is Node and String(c.name).begins_with("_dyn_"):
			c.queue_free()

## 创建带背景的胶囊标签
func _make_chip(text: String, bg: Color, border: Color, fg: Color = THEME_TEXT, size := 13) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "_dyn_chip"
	p.add_theme_stylebox_override("panel", _make_sb(bg, border, 1, 4, Color(0, 0, 0, 0), 0, 8, 3, 8, 3))
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", fg)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p

## 创建军衔卡片（大字名称 + 描述）
func _make_rank_card(rank_name: String, desc: String, accent: Color, is_next := false) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "_dyn_rankcard"
	if is_next:
		card.add_theme_stylebox_override("panel", _make_sb(Color(0, 0, 0, 0), accent * Color(1, 1, 1, 0.55), 1, 6, Color(0, 0, 0, 0), 0, 14, 10, 14, 10))
	else:
		card.add_theme_stylebox_override("panel", _make_sb(accent * Color(1, 1, 1, 0.14), accent * Color(1, 1, 1, 0.7), 1, 6, accent * Color(1, 1, 1, 0.2), 4, 14, 10, 14, 10))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	var name_l := Label.new()
	name_l.text = rank_name
	name_l.add_theme_font_size_override("font_size", 20 if not is_next else 17)
	name_l.add_theme_color_override("font_color", accent)
	name_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	name_l.add_theme_constant_override("outline_size", 2)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_l)
	if not desc.is_empty():
		var desc_l := Label.new()
		desc_l.text = desc
		desc_l.add_theme_font_size_override("font_size", 12)
		desc_l.add_theme_color_override("font_color", THEME_TEXT_DIM)
		desc_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc_l)
	card.add_child(vbox)
	return card
