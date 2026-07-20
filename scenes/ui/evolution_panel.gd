extends Control
class_name EvolutionPanel
## 进化面板（v7.x UI 重设计 战术进化站 · 三栏布局）
## 签名色：紫色（COLOR_VIOLET）· 蜕变主题，金/青用于分支区分

signal closed

# === 主题色（紫色进化主题） ===
const THEME_VIOLET := Color(0.653, 0.546, 0.98, 1)
const THEME_VIOLET_SOFT := Color(0.769, 0.71, 0.992, 1)
const THEME_GOLD := Color(1.0, 0.85, 0.35, 1)  # 主线分支用（保留）
const THEME_CYAN := Color(0.0, 0.9, 1.0, 1)
const THEME_GREEN := Color(0.3, 0.92, 0.5, 1)
const THEME_PURPLE := Color(0.75, 0.55, 1.0, 1)
const THEME_RED := Color(0.95, 0.4, 0.4, 1)
const THEME_TEXT := Color(0.88, 0.92, 0.98, 1)
const THEME_TEXT_DIM := Color(0.6, 0.66, 0.78, 1)
const THEME_BG_CARD := Color(0.08, 0.06, 0.12, 0.92)
const THEME_BORDER_DIM := Color(0.32, 0.28, 0.38, 0.7)

const DefaultCards = preload("res://data/default_cards.gd")
const IntelManualItems = preload("res://data/intel_manual_items.gd")
const BlueprintDefinitions = preload("res://data/blueprint_definitions.gd")

# v7.x UI 重设计基建
const DT = preload("res://resources/design_tokens.gd")
const EvolutionHelpers = preload("res://managers/evolution/evolution_helpers.gd")

const FILTER_ALL := "all"
const FILTER_EVO := "evo"
const FILTER_FINAL := "final"

# UI 组件引用（v7.x 重构：改用 % unique_name，删除 OptionButton）
var current_card_info: Label = null  # 保留兼容（已废弃，资源栏用 PowerLabel/EnhanceLabel/ModsLabel 替代）
var evolution_tree: VBoxContainer = null
var detail_content: VBoxContainer = null
var result_label: Label = null
var no_selection_label: Label = null
var target_name_label: Label = null
var info_details: Label = null
var req_details: Label = null
var resource_details: Label = null
var evolve_button: Button = null

# 资源栏
var power_label: Label = null
var enhance_label: Label = null
var mods_label: Label = null
var status_line_label: Label = null
var meta_label: Label = null

# 左栏（名册）
var card_list_container: VBoxContainer = null
var col_head_count: Label = null
var path_head_count: Label = null
var chip_all: Button = null
var chip_evo: Button = null
var chip_final: Button = null
var left_panel: PanelContainer = null

# 统计标签
var stat_hp: Label = null
var stat_attack_light: Label = null
var stat_attack_armor: Label = null
var stat_attack_air: Label = null
var stat_defense_light: Label = null
var stat_defense_armor: Label = null
var stat_defense_air: Label = null
var stat_range: Label = null
var stat_speed: Label = null

var selected_card: CardResource = null
var selected_target_id: String = ""
var _embedded_mode: bool = false
var _card_list: Array[CardResource] = []
var _evolve_callable: Callable
var _filter_mode: String = FILTER_ALL

func _ready() -> void:
	# v7.x 重构：节点绑定改用 % unique_name（路径无关）
	# 进化树 + 详情面板（业务方法直接访问这两个）
	evolution_tree = get_node_or_null("%EvolutionTree")
	detail_content = get_node_or_null("%DetailContent")
	result_label = get_node_or_null("%ResultLabel")

	# 详情面板子组件
	no_selection_label = get_node_or_null("%NoSelectionLabel")
	target_name_label = get_node_or_null("%TargetNameLabel")
	info_details = get_node_or_null("%InfoDetails")
	req_details = get_node_or_null("%ReqDetails")
	resource_details = get_node_or_null("%ResourceDetails")
	evolve_button = get_node_or_null("%EvolveButton")

	# 统计标签（9 个）
	stat_hp = get_node_or_null("%StatHP")
	stat_attack_light = get_node_or_null("%StatAttackLight")
	stat_attack_armor = get_node_or_null("%StatAttackArmor")
	stat_attack_air = get_node_or_null("%StatAttackAir")
	stat_defense_light = get_node_or_null("%StatDefenseLight")
	stat_defense_armor = get_node_or_null("%StatDefenseArmor")
	stat_defense_air = get_node_or_null("%StatDefenseAir")
	stat_range = get_node_or_null("%StatRange")
	stat_speed = get_node_or_null("%StatSpeed")

	# 资源栏（替代旧的 current_card_info）
	power_label = get_node_or_null("%PowerLabel")
	enhance_label = get_node_or_null("%EnhanceLabel")
	mods_label = get_node_or_null("%ModsLabel")
	status_line_label = get_node_or_null("%StatusLineLabel")
	meta_label = get_node_or_null("%MetaLabel")

	# 左栏（名册）
	card_list_container = get_node_or_null("%CardListContainer")
	col_head_count = get_node_or_null("%ColHeadCount")
	path_head_count = get_node_or_null("%PathHeadCount")
	chip_all = get_node_or_null("%ChipAll")
	chip_evo = get_node_or_null("%ChipEvo")
	chip_final = get_node_or_null("%ChipFinal")
	left_panel = get_node_or_null("%LeftPanel")

	# 连接关闭按钮
	var close_btn = get_node_or_null("%CloseButton")
	if close_btn:
		close_btn.pressed.connect(_on_close)
	# v9.x: 连接"返回成长首页"按钮
	var back_btn = get_node_or_null("%BackToGrowthButton")
	if back_btn:
		back_btn.pressed.connect(_on_back_to_growth)

	# chip 筛选
	if chip_all:
		chip_all.pressed.connect(_on_filter_pressed.bind(FILTER_ALL))
	if chip_evo:
		chip_evo.pressed.connect(_on_filter_pressed.bind(FILTER_EVO))
	if chip_final:
		chip_final.pressed.connect(_on_filter_pressed.bind(FILTER_FINAL))

	_evolve_callable = _on_evolve_pressed

	# v7.x UI 重设计：加载 Rajdhani 字体到主要 Label
	_apply_title_fonts()
	_update_chip_styles()

	if _embedded_mode:
		_apply_embedded_layout()
	else:
		_refresh_card_list()


## v7.x：给标题/目标名/统计 Label 加载 Rajdhani 字体（战术感）
func _apply_title_fonts() -> void:
	# 标题
	var title_label = get_node_or_null("%TitleLabel")
	if title_label:
		title_label.add_theme_font_override("font", DT.get_title_font_bold())
	# 目标名（大字）
	if target_name_label:
		target_name_label.add_theme_font_override("font", DT.get_title_font_bold())
	# 进化按钮
	if evolve_button:
		evolve_button.add_theme_font_override("font", DT.get_title_font())
	# 统计标签（9 个）
	for stat in [stat_hp, stat_attack_light, stat_attack_armor, stat_attack_air,
				stat_defense_light, stat_defense_armor, stat_defense_air, stat_range, stat_speed]:
		if stat:
			stat.add_theme_font_override("font", DT.get_body_font())


## v7.x 新增：chip 筛选样式
func _update_chip_styles() -> void:
	var chips := {FILTER_ALL: chip_all, FILTER_EVO: chip_evo, FILTER_FINAL: chip_final}
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
			sb.bg_color = Color(0.653, 0.546, 0.98, 0.12)
			sb.border_color = DT.COLOR_VIOLET
			btn.add_theme_color_override("font_color", DT.COLOR_VIOLET_SOFT)
		else:
			sb.bg_color = Color(0.05, 0.09, 0.16, 0.4)
			sb.border_color = Color(0.25, 0.35, 0.42, 0.3)
			btn.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 0.8))
		btn.add_theme_stylebox_override("normal", sb)
		var sb_h := sb.duplicate() as StyleBoxFlat
		sb_h.bg_color = Color(0.653, 0.546, 0.98, 0.06)
		btn.add_theme_stylebox_override("hover", sb_h)


## v7.x 新增：筛选回调
func _on_filter_pressed(mode: String) -> void:
	_filter_mode = mode
	_update_chip_styles()
	_refresh_card_list()


## 内嵌模式：隐藏标题/资源栏/左名册
func set_embedded_mode(p_embedded: bool) -> void:
	_embedded_mode = p_embedded
	if is_inside_tree():
		_apply_embedded_layout()

func _apply_embedded_layout() -> void:
	var title_row = get_node_or_null("VBoxContainer/TitleRow")
	if title_row:
		title_row.visible = false
	# v7.x：隐藏整个左栏（含 chip 筛选 + 名册列表），替代原 CardSelectorArea
	if left_panel:
		left_panel.visible = false
	# v6.4: 内嵌模式下隐藏资源栏（背包场景冗余）
	var resource_bar = get_node_or_null("VBoxContainer/ResourceBar")
	if resource_bar:
		resource_bar.visible = false
	# v6.6: 嵌入模式尺寸适配——清零根节点最小尺寸，让其服从宿主 Tab 容器
	custom_minimum_size = Vector2.ZERO


## ─────────────────────────────────────────────
##  UI更新
## ─────────────────────────────────────────────

## v7.x 重构：刷新左栏名册列表（替代旧 OptionButton 下拉）
## 数据源不变：InstanceRegistry 实例全集（主）+ BlueprintManager 蓝图补无实例卡（兜底）。
## 应用 chip 筛选：全部/可进化（有进化目标）/终阶（无进化目标）。
func _refresh_card_list() -> void:
	if card_list_container == null:
		return
	# 先收集全部候选（不依赖筛选）
	_card_list.clear()
	var seen_full: Dictionary = {}
	var seen_base: Dictionary = {}
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir != null and ir.has_method("get_all_instance_ids"):
		for iid_raw in ir.get_all_instance_ids():
			var iid: String = str(iid_raw)
			if iid.is_empty() or seen_full.has(iid):
				continue
			var inst: CardResource = ir.get_instance(iid) if ir.has_method("get_instance") else null
			if inst == null:
				continue
			seen_full[iid] = true
			seen_base[inst.card_id] = true
			_card_list.append(inst)
	if BlueprintManager and BlueprintManager.has_method("get_all_blueprint_ids"):
		for bid_raw in BlueprintManager.get_all_blueprint_ids():
			var bid: String = str(bid_raw)
			if bid.is_empty() or seen_base.has(bid):
				continue
			var card: CardResource = DefaultCards.get_card_by_id(bid)
			if card == null:
				continue
			_card_list.append(card)
	# 清空列表 UI
	for child in card_list_container.get_children():
		child.queue_free()
	# 应用筛选 + 渲染
	var shown := 0
	for card in _card_list:
		if not _passes_filter(card):
			continue
		var item := _create_card_item(card)
		card_list_container.add_child(item)
		shown += 1
	# 计数
	if col_head_count:
		col_head_count.text = "%d / %d" % [shown, _card_list.size()]
	# 默认选中第一张（筛选后）可见卡
	if shown > 0 and selected_card == null:
		for card in _card_list:
			if _passes_filter(card):
				_on_card_selected(card)
				break


## v7.x 新增：chip 筛选判定
## FILTER_ALL=全部 / FILTER_EVO=可进化（有进化目标）/ FILTER_FINAL=终阶（无进化目标）
func _passes_filter(card: CardResource) -> bool:
	if card == null:
		return true
	match _filter_mode:
		FILTER_EVO:
			var targets: Array = []
			if card.has_method("get_evolution_targets"):
				targets = card.get_evolution_targets()
			return not targets.is_empty()
		FILTER_FINAL:
			var targets: Array = []
			if card.has_method("get_evolution_targets"):
				targets = card.get_evolution_targets()
			return targets.is_empty()
		_:
			return true


## v7.x 新增：构建单个名册列表项（缩略卡图 + 卡名#N + Lv·Mx/9 + 战力）
func _create_card_item(card: CardResource) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 44)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.text = ""
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_color_override("font_color", Color(0.91, 0.93, 0.96, 1))

	# 选中态判断
	var is_selected := false
	if selected_card != null:
		var sel_iid := String(selected_card.instance_id)
		if not sel_iid.is_empty():
			is_selected = (sel_iid == String(card.instance_id))
		else:
			is_selected = (String(card.instance_id).is_empty() or card.card_id == selected_card.card_id)

	# 样式（选中态紫色左边框）
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
	sb_s.bg_color = Color(0.653, 0.546, 0.98, 0.1)
	sb_s.border_width_left = 3
	sb_s.border_color = DT.COLOR_VIOLET
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

	# 缩略卡图（32×36，兵种色边框）
	var thumb := PanelContainer.new()
	thumb.custom_minimum_size = Vector2(32, 36)
	thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var thumb_sb := StyleBoxFlat.new()
	thumb_sb.bg_color = Color(0.03, 0.06, 0.11, 1)
	thumb_sb.border_color = _get_kind_color(card.combat_kind)
	thumb_sb.set_border_width_all(1)
	thumb_sb.set_corner_radius_all(3)
	thumb.add_theme_stylebox_override("panel", thumb_sb)
	var thumb_icon := Label.new()
	thumb_icon.text = _get_unit_icon(card)
	thumb_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thumb_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	thumb_icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	thumb_icon.add_theme_font_size_override("font_size", 14)
	thumb_icon.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	thumb_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.add_child(thumb_icon)
	hbox.add_child(thumb)

	# 信息列
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 2)

	# 第一行：卡名 + #N
	var name_row := HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_theme_constant_override("separation", 4)
	var name_label := Label.new()
	name_label.text = card.display_name if card.display_name else card.card_id
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98, 1) if is_selected else Color(0.85, 0.88, 0.94, 1))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(name_label)
	# 实例序号
	if not String(card.instance_id).is_empty():
		var iid: String = String(card.instance_id)
		var h_idx: int = iid.rfind("#")
		if h_idx >= 0:
			var seq_label := Label.new()
			seq_label.text = "#" + iid.substr(h_idx + 1)
			seq_label.add_theme_font_size_override("font_size", 9)
			seq_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75, 0.7))
			seq_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			name_row.add_child(seq_label)
	info.add_child(name_row)

	# 第二行：Lv.N · Mx/9
	var mod_count: int = 0
	if "mods" in card and card.mods is Array:
		mod_count = card.mods.size()
	var meta_label := Label.new()
	meta_label.text = "Lv.%d  ·  M%d/9" % [card.enhance_level, mod_count]
	meta_label.add_theme_font_size_override("font_size", 9)
	meta_label.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7, 0.85))
	meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(meta_label)
	hbox.add_child(info)

	# 战力（右侧）
	var power_label := Label.new()
	var power_str := _format_power_value(card)
	power_label.text = power_str
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	power_label.add_theme_font_size_override("font_size", 11)
	power_label.add_theme_color_override("font_color", DT.COLOR_VIOLET_SOFT if power_str != "—" else Color(0.5, 0.5, 0.55, 0.5))
	power_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	power_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(power_label)

	btn.add_child(hbox)
	btn.pressed.connect(_on_card_selected.bind(card))
	return btn


## v7.x 辅助：估算卡牌战力数值
func _format_power_value(card: CardResource) -> String:
	if BlueprintManager == null or card == null:
		return "—"
	var id_to_eval: String = card.instance_id if not card.instance_id.is_empty() else card.card_id
	if id_to_eval.is_empty():
		return "—"
	var power := EvolutionHelpers.estimate_power_score(id_to_eval, BlueprintManager)
	if power <= 0:
		return "—"
	return _format_int(int(round(power)))


## v7.x 辅助：整数千分位格式化
func _format_int(n: int) -> String:
	var s := str(n)
	var out := ""
	var cnt := 0
	for i in range(s.length() - 1, -1, -1):
		if cnt > 0 and cnt % 3 == 0:
			out = "," + out
		out = s[i] + out
		cnt += 1
	return out


## v7.x 辅助：兵种图标
func _get_unit_icon(card: CardResource) -> String:
	match CardResource.get_combat_kind_name(card.combat_kind):
		"步兵": return "⚔"
		"装甲": return "◈"
		"炮兵": return "◎"
		"防空": return "↑"
		"空军": return "✈"
		"侦察": return "◉"
		"工程": return "⚙"
		"堡垒": return "■"
		_: return "⚔"


## v7.x 辅助：兵种颜色
func _get_kind_color(combat_kind: int) -> Color:
	match CardResource.get_combat_kind_name(combat_kind):
		"步兵": return Color(0.9, 0.3, 0.3)
		"装甲": return Color(0.3, 0.5, 0.9)
		"炮兵": return Color(0.95, 0.6, 0.2)
		"防空": return Color(0.85, 0.8, 0.3)
		"空军": return Color(0.3, 0.85, 0.95)
		"侦察": return Color(0.4, 0.9, 0.4)
		"工程": return Color(0.65, 0.45, 0.95)
		"堡垒": return Color(0.6, 0.6, 0.65)
		_: return Color(0.6, 0.6, 0.65)


## 创建进化节点（对齐网页设计稿 evo-node 卡片样式）
## 紧凑单卡布局：左侧路径色条 + 顶部（名+badge）/ 中部（战力 cur ▶ tgt +N%）/ 底部（阶段+分支tag）
## 可点击整卡（用 Button 包裹）
func _create_evolution_node(target: Dictionary) -> Control:
	var src_id: String = selected_card.instance_id if (selected_card and not selected_card.instance_id.is_empty()) else (selected_card.card_id if selected_card else "")
	var check_result = BlueprintManager.can_evolve_blueprint(src_id, target.target_id)
	var can_evo: bool = bool(check_result.get("ok", false))
	var target_card = DefaultCards.get_card_by_id(target.target_id)
	# v7.x 防御：目标卡数据缺失时返回占位
	if target_card == null:
		var ph := Label.new()
		ph.text = "⚠ 无效进化目标：%s（数据缺失）" % String(target.get("target_id", "???"))
		ph.add_theme_font_size_override("font_size", 11)
		ph.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
		ph.modulate.a = 0.6
		return ph

	var current_power = _get_current_power_score()
	var target_power = _get_target_power_score(target.target_id)
	var pcolor := _path_type_color(String(target.get("path_type", "")))
	var path_type := String(target.get("path_type", ""))
	var is_selected_target := (selected_target_id == String(target.target_id))

	# 整卡 Button（设计稿用 div，Godot 用 Button）
	var btn := Button.new()
	btn.text = ""
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 70)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_color_override("font_color", Color(0.91, 0.93, 0.96, 1))
	# 卡片样式：左侧 3px 路径色条 + 浅紫背景（可进化）/ 灰背景（锁定）
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(0.075, 0.102, 0.165, 0.7) if can_evo else Color(0.05, 0.07, 0.12, 0.5)
	sb_n.border_width_left = 3
	sb_n.border_width_right = 1
	sb_n.border_width_top = 1
	sb_n.border_width_bottom = 1
	# 边框色：可进化用路径色（主线金/分支紫/情报青），锁定用暗灰
	sb_n.border_color = pcolor if can_evo else Color(0.25, 0.28, 0.35, 0.4)
	sb_n.set_corner_radius_all(4)
	sb_n.content_margin_left = 10
	sb_n.content_margin_top = 6
	sb_n.content_margin_right = 10
	sb_n.content_margin_bottom = 6
	if is_selected_target:
		sb_n.bg_color = Color(0.653, 0.546, 0.98, 0.14)
		sb_n.border_color = DT.COLOR_VIOLET_SOFT
		sb_n.border_width_left = 3
	btn.add_theme_stylebox_override("normal", sb_n)
	var sb_h := sb_n.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(0.653, 0.546, 0.98, 0.08)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.disabled = not can_evo
	btn.modulate.a = 1.0 if can_evo else 0.6

	# 内容 VBox
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 3)

	# 第 1 行：目标名 + 状态 badge
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_lbl := Label.new()
	name_lbl.text = target.name
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", THEME_VIOLET_SOFT if can_evo else THEME_TEXT_DIM)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(name_lbl)
	# 状态 badge（紧凑）
	var badge_lbl := Label.new()
	if can_evo:
		badge_lbl.text = "✓可进化"
		badge_lbl.add_theme_color_override("font_color", THEME_GREEN)
	else:
		# 锁定原因分级（按 reason 字段细分）
		var reason := String(check_result.get("reason", ""))
		var badge_text := "🔒条件不足"
		if reason.find("enhance") >= 0:
			var enh_req: int = int(check_result.get("enhance_requirement", 0))
			badge_text = "🔒需Lv.%d" % enh_req
		elif reason.find("mod") >= 0:
			badge_text = "🔒改造不足"
		elif reason.find("blueprint") >= 0 or reason.find("evo_blueprint") >= 0:
			badge_text = "🔒缺图纸"
		badge_lbl.text = badge_text
		badge_lbl.add_theme_color_override("font_color", THEME_RED)
	badge_lbl.add_theme_font_size_override("font_size", 9)
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(badge_lbl)
	content.add_child(top_row)

	# 第 2 行：战力对比 + 百分比
	var power_row := HBoxContainer.new()
	power_row.add_theme_constant_override("separation", 8)
	power_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var power_lbl := Label.new()
	var pct := 0
	if current_power > 0:
		pct = int((float(target_power) / float(current_power) - 1.0) * 100.0)
	var pct_str := ("+%d%%" % pct) if pct >= 0 else ("%d%%" % pct)
	power_lbl.text = "战力 %d ▶ %d" % [current_power, target_power]
	power_lbl.add_theme_font_size_override("font_size", 10)
	power_lbl.add_theme_color_override("font_color", THEME_GREEN if pct >= 0 else THEME_RED)
	power_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_row.add_child(power_lbl)
	var pct_lbl := Label.new()
	pct_lbl.text = pct_str
	pct_lbl.add_theme_font_size_override("font_size", 10)
	pct_lbl.add_theme_color_override("font_color", THEME_GREEN if pct >= 0 else THEME_RED)
	pct_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_row.add_child(pct_lbl)
	content.add_child(power_row)

	# 第 3 行：阶段 + 路径类型 tag
	var meta_row := HBoxContainer.new()
	meta_row.add_theme_constant_override("separation", 6)
	meta_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 路径类型标签
	var type_text := "主线" if path_type == "main" else ("势力分支" if path_type == "faction" else ("情报隐藏" if path_type.find("intel") >= 0 else path_type))
	var type_col := THEME_GOLD if path_type == "main" else (THEME_PURPLE if path_type == "faction" else THEME_CYAN)
	var type_chip := _make_small_chip(type_text, type_col)
	meta_row.add_child(type_chip)
	# 时代
	var era_lbl := Label.new()
	var era_name := GameConstants.get_era_name(target_card.era) if target_card and GameConstants else str(target_card.era)
	era_lbl.text = "· " + era_name if not era_name.is_empty() else ""
	era_lbl.add_theme_font_size_override("font_size", 9)
	era_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 0.8))
	era_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_row.add_child(era_lbl)
	content.add_child(meta_row)

	btn.add_child(content)
	if can_evo:
		btn.pressed.connect(func(): _on_target_selected(target.target_id, target.name))
	return btn


## v7.x 辅助：小型 chip 标签（用于进化节点路径类型）
func _make_small_chip(text: String, color: Color) -> Control:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.r, color.g, color.b, 0.12)
	sb.border_color = Color(color.r, color.g, color.b, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 5
	sb.content_margin_top = 1
	sb.content_margin_right = 5
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p

func _update_evolution_tree() -> void:
	if evolution_tree == null:
		return
	if not selected_card:
		_clear_evolution_tree()
		return

	_clear_evolution_tree()

	# 获取进化路径
	var targets = selected_card.get_evolution_targets()

	# 顶部摘要 + 路径类型图例（对齐网页设计稿）
	var summary_box := VBoxContainer.new()
	summary_box.add_theme_constant_override("separation", 4)
	summary_box.custom_minimum_size = Vector2(0, 0)
	# 摘要行
	var main_count := 0
	var branch_count := 0
	for t in targets:
		var pt := String(t.get("path_type", ""))
		if pt == "main":
			main_count += 1
		else:
			branch_count += 1
	var summary_lbl := Label.new()
	if targets.is_empty():
		summary_lbl.text = "%s · 终阶形态（无进化路线）" % selected_card.display_name
	else:
		summary_lbl.text = "%s → %d 个可选目标 · %d 主线 / %d 分支" % [
			selected_card.display_name, targets.size(), main_count, branch_count]
	summary_lbl.add_theme_font_size_override("font_size", 9)
	summary_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 0.85))
	summary_box.add_child(summary_lbl)
	# 图例行（仅当有目标时显示）
	if not targets.is_empty():
		var legend_row := HBoxContainer.new()
		legend_row.add_theme_constant_override("separation", 6)
		legend_row.add_theme_constant_override("margin_bottom", 4)
		legend_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if main_count > 0:
			legend_row.add_child(_make_small_chip("●主线", THEME_GOLD))
		# 势力分支（紫）
		var has_faction := false
		var has_intel := false
		for t in targets:
			var pt := String(t.get("path_type", ""))
			if pt == "faction": has_faction = true
			if pt.find("intel") >= 0: has_intel = true
		if has_faction:
			legend_row.add_child(_make_small_chip("●势力分支", THEME_PURPLE))
		if has_intel:
			legend_row.add_child(_make_small_chip("●情报隐藏", THEME_CYAN))
		summary_box.add_child(legend_row)
	# 摘要底部分隔线（用 PanelContainer + StyleBox border_bottom）
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.25, 0.28, 0.35, 0.4))
	summary_box.add_child(sep)
	evolution_tree.add_child(summary_box)

	if targets.is_empty():
		# 终阶提示
		var final_lbl := Label.new()
		final_lbl.text = "✓ 该卡牌已达终阶形态"
		final_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		final_lbl.add_theme_font_size_override("font_size", 13)
		final_lbl.add_theme_color_override("font_color", THEME_GOLD)
		final_lbl.custom_minimum_size = Vector2(0, 40)
		evolution_tree.add_child(final_lbl)
		if path_head_count:
			path_head_count.text = "0"
		return

	# "当前形态" 节点（对齐网页设计稿 current 节点）
	var current_node := _create_current_form_node()
	evolution_tree.add_child(current_node)

	# 进化目标节点（紧凑列表，无连线）
	for i in range(targets.size()):
		var target_node = _create_evolution_node(targets[i])
		evolution_tree.add_child(target_node)

	if path_head_count:
		path_head_count.text = "%d" % targets.size()


## v7.x 新增：当前形态节点（网页设计稿 current evo-node）
func _create_current_form_node() -> Control:
	var btn := Button.new()
	btn.text = ""
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.disabled = true
	btn.custom_minimum_size = Vector2(0, 50)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# amber 当前态边框：左 3px 金色（突出），其余 1px 暗色
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.075, 0.102, 0.165, 0.5)
	sb.border_width_left = 3
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	# 用 content_margin_color 分别设左右色（左侧金色突出，其余暗色）不可行——StyleBoxFlat 单色 border
	# 改用 content_margin 调整 + 左边色作为主标识
	sb.border_color = THEME_GOLD
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_top = 6
	sb.content_margin_right = 10
	sb.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("disabled", sb)
	btn.modulate.a = 0.85
	# 内容
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	# 第 1 行：名 + "当前" badge
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_lbl := Label.new()
	name_lbl.text = selected_card.display_name if selected_card.display_name else selected_card.card_id
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98, 1))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(name_lbl)
	var badge := Label.new()
	badge.text = "● 当前"
	badge.add_theme_font_size_override("font_size", 9)
	badge.add_theme_color_override("font_color", THEME_GOLD)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(badge)
	vbox.add_child(top)
	# 第 2 行：战力 + 当前形态
	var meta := Label.new()
	var cur_power := _get_current_power_score()
	meta.text = "战力 %d · 当前形态" % cur_power
	meta.add_theme_font_size_override("font_size", 9)
	meta.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 0.7))
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(meta)
	btn.add_child(vbox)
	return btn


func _clear_evolution_tree() -> void:
	for child in evolution_tree.get_children():
		child.queue_free()

## 更新资源栏显示（替代旧 current_card_info）
func _update_current_card_info() -> void:
	if _embedded_mode or selected_card == null:
		return
	var power = _get_current_power_score()
	var mod_count: int = selected_card.mods.size() if "mods" in selected_card else 0
	if power_label:
		power_label.text = "当前战力 %d" % power
	if enhance_label:
		enhance_label.text = "强化 Lv.%d" % selected_card.enhance_level
	if mods_label:
		mods_label.text = "改造 %d/9" % mod_count
	# meta_label（标题栏右侧）：显示卡名简略
	if meta_label:
		var dn: String = selected_card.display_name if selected_card.display_name else selected_card.card_id
		meta_label.text = dn

## 获取当前卡牌的战力评分
## v6.2 修复 M15：统一用 CardResource.get_current_power（与 reinforcement_panel 一致），
## 原 _estimate_power_score 与 get_current_power 口径不同，导致同一张卡在不同面板显示不同战力
func _get_current_power_score() -> int:
	if not selected_card:
		return 0
	return selected_card.get_current_power()

## v6.2: 获取目标卡的战力评分（统一用 get_current_power，确保对比基准一致）
func _get_target_power_score(target_id: String) -> int:
	if target_id.is_empty():
		return 0
	var target_card = DefaultCards.get_card_by_id(target_id)
	if target_card == null:
		return 0
	return target_card.get_current_power()

func _update_detail_panel() -> void:
	if detail_content == null:
		return
	if not selected_card or selected_target_id.is_empty():
		_clear_detail_panel()
		return

	# 隐藏默认提示，显示详情面板
	if no_selection_label:
		no_selection_label.visible = false
	_set_detail_panel_visible(true)

	# 显示目标信息
	var target_card = DefaultCards.get_card_by_id(selected_target_id)
	if not target_card:
		return

	# 更新目标名称
	if target_name_label:
		target_name_label.text = "→ " + target_card.display_name

	# 条件检查（提升到函数作用域，后续多处使用）
	# v7.0: 传 instance_id（实例化养成身份）
	var src_id_ck: String = selected_card.instance_id if (selected_card and not selected_card.instance_id.is_empty()) else (selected_card.card_id if selected_card else "")
	var check_result = BlueprintManager.can_evolve_blueprint(src_id_ck, selected_target_id)
	var can_ok_res: bool = bool(check_result.get("ok", false))
	# 进化图纸持有状态（提到函数顶层，供 ReqDetails + EvolveButton 共用）
	var evo_bp_id: String = BlueprintDefinitions.get_evolution_blueprint_id(selected_card.card_id, selected_target_id)
	var has_bp: bool = false
	var _iib_bp: Node = Engine.get_main_loop().get_root().get_node_or_null("IntelItemBag")
	if _iib_bp != null and not evo_bp_id.is_empty():
		has_bp = _iib_bp.has_item(evo_bp_id)

	# 更新基础信息（对齐网页设计稿：阶段+目标名+card_id 居中显示）
	if info_details:
		var target_pw = _get_target_power_score(selected_target_id)
		var era_name := GameConstants.get_era_name(target_card.era) if GameConstants else ""
		info_details.text = "进化目标 · 战力 %d\n%s · %s · %s" % [
			target_pw, era_name if not era_name.is_empty() else str(target_card.era),
			CardResource.get_combat_kind_name(target_card.combat_kind),
			target_card.card_id]
	# 进化条件（行式列表，对齐网页 evo-cond-row）
	if req_details:
		var req_lines: Array = []
		# 进化图纸（has_bp 在函数顶层已计算）
		req_lines.append("%s 进化图纸" % ("✓" if has_bp else "✗"))
		# 强化等级
		var enh_req: int = int(check_result.get("enhance_requirement", 0))
		if enh_req > 0:
			var cur_enh: int = int(check_result.get("current_enhance", selected_card.enhance_level))
			req_lines.append("%s 强化 Lv.%d / %d" % [("✓" if cur_enh >= enh_req else "✗"), cur_enh, enh_req])
		# 改造数量
		var mod_req: int = int(check_result.get("mod_requirement", 0))
		if mod_req > 0:
			var cur_mod: int = int(check_result.get("current_mod_count", selected_card.mods.size()))
			req_lines.append("%s 改造 %d / %d" % [("✓" if cur_mod >= mod_req else "✗"), cur_mod, mod_req])
		req_details.text = " · ".join(req_lines)
		if can_ok_res:
			req_details.add_theme_color_override("font_color", THEME_GREEN)
		else:
			# 失败时标橙，但仍显示各项进度
			req_details.add_theme_color_override("font_color", Color(0.95, 0.6, 0.4))

	# 更新属性对比（当前 → 进化后 + 增量），并修复射程/移速恒为 0 的问题
	var new_stats = selected_card.calculate_evolved_stats(selected_target_id)
	var cur_stats: Dictionary = selected_card.get_modified_stats() if selected_card.has_method("get_modified_stats") else {}
	if target_card != null:
		if not new_stats.has("attack_range"):
			new_stats["attack_range"] = int(target_card.range_value)
		if not new_stats.has("move_speed"):
			new_stats["move_speed"] = int(target_card.base_speed)
	_set_stat_compare(stat_hp, "生命值", cur_stats.get("max_hp", 0), new_stats.get("max_hp", 0))
	_set_stat_compare(stat_attack_light, "对直射攻击", cur_stats.get("attack_light", 0), new_stats.get("attack_light", 0))
	_set_stat_compare(stat_attack_armor, "对曲射攻击", cur_stats.get("attack_armor", 0), new_stats.get("attack_armor", 0))
	_set_stat_compare(stat_attack_air, "对空攻击", cur_stats.get("attack_air", 0), new_stats.get("attack_air", 0))
	_set_stat_compare(stat_defense_light, "对直射防御", cur_stats.get("defense_light", 0), new_stats.get("defense_light", 0))
	_set_stat_compare(stat_defense_armor, "对曲射防御", cur_stats.get("defense_armor", 0), new_stats.get("defense_armor", 0))
	_set_stat_compare(stat_defense_air, "对空防御", cur_stats.get("defense_air", 0), new_stats.get("defense_air", 0))
	_set_stat_compare(stat_range, "射程", cur_stats.get("attack_range", 0), new_stats.get("attack_range", 0))
	_set_stat_compare(stat_speed, "移速", cur_stats.get("move_speed", 0), new_stats.get("move_speed", 0))

	# 资源/继承信息（对齐网页设计稿：进化零消耗 + 继承提示）
	# v7.x：can_ok_res 在函数顶层已定义
	if resource_details:
		# 失败时显示具体原因（成功时不重复）
		var res_text := ""
		if not can_ok_res:
			var reason_zh := String(check_result.get("reason_zh", ""))
			if not reason_zh.is_empty():
				res_text += "⚠ %s\n" % reason_zh
		# 进化零消耗 + 继承提示（对齐网页设计稿）
		res_text += "✓ 进化零消耗（图纸永久持有）\n"
		res_text += "✓ 强化/改造/词条槽完全继承 · HP 下限 ×1.10"
		resource_details.text = res_text
		resource_details.add_theme_color_override("font_color", THEME_GREEN if can_ok_res else Color(0.95, 0.6, 0.4))

	# 进化按钮：只看图纸持有 + can_evolve_blueprint 结果（不再校验纳米）
	# v7.x：has_bp 在 ReqDetails 段已定义；can_ok_res 已定义
	if evolve_button:
		if not has_bp:
			evolve_button.text = "缺少图纸 ✗"
			evolve_button.disabled = true
		elif not can_ok_res:
			# 显示具体未满足项（从 reason 推断）
			var reason := String(check_result.get("reason", ""))
			var btn_text := "进化条件未满足"
			if reason.find("enhance") >= 0:
				btn_text = "需更高强化 ✗"
			elif reason.find("mod") >= 0:
				btn_text = "需更多改造 ✗"
			evolve_button.text = btn_text
			evolve_button.disabled = true
		else:
			evolve_button.text = "执行进化 ▶"
			evolve_button.disabled = false

		if not evolve_button.pressed.is_connected(_evolve_callable):
			evolve_button.pressed.connect(_evolve_callable)

func _clear_detail_panel() -> void:
	if no_selection_label:
		no_selection_label.visible = true

	# 显示详情面板（让 NoSelectionLabel 可见），但隐藏子面板
	_set_detail_panel_visible(true)
	if target_name_label:
		target_name_label.visible = false
	if info_details:
		info_details.visible = false
	if req_details:
		req_details.visible = false
	if stat_hp:
		stat_hp.visible = false
	if resource_details:
		resource_details.visible = false
	if evolve_button:
		evolve_button.visible = false

func _restore_detail_sub_panels() -> void:
	if target_name_label:
		target_name_label.visible = true
	if info_details:
		info_details.visible = true
	if req_details:
		req_details.visible = true
	if stat_hp:
		stat_hp.visible = true
	if resource_details:
		resource_details.visible = true
	if evolve_button:
		evolve_button.visible = true

func _set_detail_panel_visible(visible: bool) -> void:
	if detail_content:
		detail_content.visible = visible

## ─────────────────────────────────────────────
##  进化操作
## ─────────────────────────────────────────────

func _on_evolve_pressed() -> void:
	if not selected_card or selected_target_id.is_empty():
		return

	if BlueprintManager and BlueprintManager.has_method("can_evolve_blueprint") and BlueprintManager.has_method("evolve_blueprint"):
		# v7.0: 进化传 instance_id（实例化养成身份）；无 instance_id 回退 card_id
		var source_id: String = selected_card.instance_id if not selected_card.instance_id.is_empty() else selected_card.card_id
		var ok: bool = BlueprintManager.evolve_blueprint(source_id, selected_target_id)
		if ok:
			_show_result("进化成功：%s → %s" % [selected_card.display_name, DefaultCards.get_safe_display_name(selected_target_id)])
			# 刷新UI - 选中进化后的新卡
			# v7.0: 进化创建目标新实例，优先从 InstanceRegistry 取
			var new_card: CardResource = null
			var ir: Node = get_node_or_null("/root/InstanceRegistry")
			if ir != null and ir.has_method("get_instances_by_card_id"):
				var new_ids: Array = ir.get_instances_by_card_id(selected_target_id)
				if not new_ids.is_empty():
					new_card = ir.get_instance(String(new_ids[new_ids.size() - 1]))
			if new_card == null:
				new_card = DefaultCards.get_card_by_id(selected_target_id)
			if new_card:
				selected_card = new_card
				# v7.x：刷新左栏名册列表（替代 OptionButton），新卡选中由 _refresh_card_list 的 selected_card 判定
				_refresh_card_list()
			_update_evolution_tree()
			_clear_detail_panel()
		else:
			var fail_info: Dictionary = BlueprintManager.can_evolve_blueprint(source_id, selected_target_id)
			var fail_reason: String = String(fail_info.get("reason_zh", "条件未满足"))
			_show_result("进化失败：%s" % fail_reason)
	else:
		_show_result("进化系统未加载")

## ─────────────────────────────────────────────
##  事件处理
## ─────────────────────────────────────────────

func _on_card_selected(card: CardResource) -> void:
	selected_card = card
	selected_target_id = ""
	_update_current_card_info()
	_update_evolution_tree()
	_clear_detail_panel()

func _on_target_selected(target_id: String, target_name: String) -> void:
	selected_target_id = target_id
	_restore_detail_sub_panels()
	_update_detail_panel()

## 供外部调用的接口
func set_selected_card(card: CardResource) -> void:
	selected_card = card
	selected_target_id = ""
	# v7.x：改用节点引用判空（替代 has_node 硬编码路径）
	if evolution_tree != null:
		_update_evolution_tree()
	if detail_content != null:
		_update_detail_panel()
	_update_current_card_info()

func show_panel() -> void:
	visible = true
	if not _embedded_mode:
		_refresh_card_list()

func _on_close() -> void:
	closed.emit()


## v9.x: 返回成长面板首页（关闭当前面板 + 打开成长面板）
func _on_back_to_growth() -> void:
	closed.emit()
	var main = get_node_or_null("/root/Main")
	if main and main.has_method("_toggle_overlay"):
		var overlay = main._overlay_for_panel_key("growth") if main.has_method("_overlay_for_panel_key") else null
		if overlay:
			main._toggle_overlay(overlay, "growth")

func _show_result(message: String) -> void:
	if result_label:
		# v7.x：ResultLabel 始终占位（visible 不切换），只切 text，避免布局抖动
		result_label.text = message
		var is_fail := message.findn("失败") >= 0 or message.findn("不足") >= 0 or message.findn("缺少") >= 0
		result_label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35, 1) if is_fail else Color(0.2, 0.9, 0.4, 1))
		await get_tree().create_timer(3.0).timeout
		if not is_inside_tree():
			return
		result_label.text = ""


# ─────────────────────────────────────────────
#  UI 辅助
# ─────────────────────────────────────────────
# （_make_sb / _make_chip 已删除：v7.x 重写 _create_evolution_node 改用内联 StyleBoxFlat + _make_small_chip）

## 路径类型 → 色条颜色（主线金/分支紫/情报青）
func _path_type_color(path_type: String) -> Color:
	if path_type == "main":
		return THEME_GOLD
	if path_type.find("intel") >= 0 or path_type.find("情报") >= 0:
		return THEME_CYAN
	return THEME_PURPLE

## 设置属性对比 Label：名称 当前 → 目标 (+增量)
## 属性对比 Label：紧凑网页设计稿风格（"生命值  690 → 980  +290"）
## diff 用独立颜色，整体行 10px 字号
func _set_stat_compare(label: Label, stat_name: String, cur_val, new_val) -> void:
	if label == null:
		return
	var c := int(cur_val)
	var n := int(new_val)
	var diff := n - c
	# 紧凑格式：名 + cur → tgt + diff
	var diff_str := "+%d" % diff if diff > 0 else ("%d" % diff if diff < 0 else "=")
	label.text = "%s  %d → %d  %s" % [stat_name, c, n, diff_str]
	label.add_theme_font_size_override("font_size", 10)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 颜色：上升绿 / 下降红 / 持平灰
	if diff > 0:
		label.add_theme_color_override("font_color", THEME_GREEN)
	elif diff < 0:
		label.add_theme_color_override("font_color", THEME_RED)
	else:
		label.add_theme_color_override("font_color", THEME_TEXT_DIM)
