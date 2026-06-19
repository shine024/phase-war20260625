extends Control
class_name ModificationPanel
## 改造面板（新系统）
## 显示军事技术改造模块
## 改造消耗：纳米材料 + 改造指南（根据稀有度）

signal closed

const IntelManualItems = preload("res://data/intel_manual_items.gd")
const BlueprintDefinitions = preload("res://data/blueprint_definitions.gd")
const StarConfig = preload("res://data/blueprint_star_config.gd")
const GC = preload("res://resources/game_constants.gd")

# UI 组件引用
@onready var card_list_container = get_node_or_null("VBoxContainer/HBoxContainer/ScrollContainer/CardListContainer")
@onready var mod_list_container = get_node_or_null("VBoxContainer/HBoxContainer/ModScrollContainer/ModListContainer")
@onready var card_info_panel = get_node_or_null("VBoxContainer/HBoxContainer/DetailPanel")
@onready var research_label = get_node_or_null("VBoxContainer/ResourceBar/ResourceHBox/ResearchLabel")
@onready var result_label = get_node_or_null("VBoxContainer/ResultLabel")

var selected_card: CardResource = null
var selected_mod_id: String = ""
var _embedded_mode: bool = false

func _ready() -> void:
	# 连接关闭按钮
	var close_btn = get_node_or_null("VBoxContainer/TitleRow/TitleHBox/CloseButton")
	if close_btn:
		close_btn.pressed.connect(_on_close)

	if _embedded_mode:
		_apply_embedded_layout()
	else:
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
	# v6.4: 内嵌模式下隐藏资源栏（背包场景冗余）
	var resource_bar = get_node_or_null("VBoxContainer/ResourceBar")
	if resource_bar:
		resource_bar.visible = false
	# v6.6: 嵌入模式尺寸适配——清零根节点最小尺寸，让其服从宿主 Tab 容器
	custom_minimum_size = Vector2.ZERO

## ─────────────────────────────────────────────
##  UI更新
## ─────────────────────────────────────────────

## v7.1: 同时获取通用改造
func _refresh_card_list() -> void:
	if card_list_container == null:
		return
	for child in card_list_container.get_children():
		child.queue_free()

	var DefaultCards = preload("res://data/default_cards.gd")
	## v7.1: 同时显示蓝图中有副本的卡和当前背包中的卡
	var card_id_set: Dictionary = {}
	## 来源1：蓝图有副本的
	for id_raw in BlueprintManager.get_all_blueprint_ids():
		var card_id: String = str(id_raw)
		card_id_set[card_id] = true
	## 来源2：背包中的
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("get_pending_backpack_ids"):
		for idv in sm.get_pending_backpack_ids():
			var sid: String = String(idv)
			if not sid.is_empty():
				card_id_set[sid] = true
	if sm and sm.has_method("get_last_known_backpack_ids"):
		for idv in sm.get_last_known_backpack_ids():
			var sid: String = String(idv)
			if not sid.is_empty():
				card_id_set[sid] = true
	for card_id in card_id_set:
		var card: CardResource = DefaultCards.get_card_by_id(card_id)
		if card == null:
			continue
		if card.card_type != GC.CardType.COMBAT_UNIT:
			continue
		var item = _create_card_item(card)
		card_list_container.add_child(item)

func _create_card_item(card: CardResource) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 52)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.text = ""
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_color_override("font_color", Color(0.91, 0.93, 0.96, 1))

	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(0.06, 0.10, 0.18, 0.6)
	sb_n.set_border_width_all(1)
	sb_n.set_corner_radius_all(5)
	sb_n.content_margin_left = 8
	sb_n.content_margin_top = 5
	sb_n.content_margin_right = 8
	sb_n.content_margin_bottom = 5
	if selected_card and selected_card.card_id == card.card_id:
		sb_n.border_color = Color(0, 0.94, 1, 0.8)
		sb_n.border_width_left = 2
		sb_n.bg_color = Color(0, 0.94, 1, 0.1)
	else:
		sb_n.border_color = Color(0.55, 0.35, 0.96, 0.2)
	btn.add_theme_stylebox_override("normal", sb_n)

	var sb_h := sb_n.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(0.12, 0.08, 0.22, 0.7)
	sb_h.border_color = Color(0.55, 0.35, 0.96, 0.5)
	btn.add_theme_stylebox_override("hover", sb_h)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(_make_label(_get_unit_icon(card), 15, _get_kind_color(card.combat_kind), false))
	name_row.add_child(_make_label(card.display_name, 13, Color(0.91, 0.93, 0.96, 1), true))
	vbox.add_child(name_row)

	var meta_row := HBoxContainer.new()
	meta_row.add_theme_constant_override("separation", 8)
	meta_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var star_count: int = StarConfig.calculate_star(card.enhance_level * 2, card.rarity)
	var star_str := ""
	for s in range(5):
		star_str += "★" if s < star_count else "☆"
	meta_row.add_child(_make_label(star_str, 10, Color(1.0, 0.84, 0.0, 0.85), false))
	meta_row.add_child(_make_label("改造 %d/9" % card.mods.size(), 10, Color(0, 0.94, 1, 0.9), false))
	meta_row.add_child(_make_label("Lv.%d" % card.enhance_level, 10, Color(0.5, 0.5, 0.6, 0.7), false))
	vbox.add_child(meta_row)

	btn.add_child(vbox)
	btn.tooltip_text = "改造：%d/9" % card.mods.size()
	btn.pressed.connect(func(): _on_card_selected(card))
	return btn

## v7.1: 显示未安装的改造（仅显示对应兵种可用的）
func _refresh_mod_list() -> void:
	if not selected_card:
		return

	for child in mod_list_container.get_children():
		child.queue_free()

	## 获取可用改造（先精确匹配card_id，再按unit_type匹配）
	var available_mods: Array = []
	if ModificationRegistry and ModificationRegistry.has_method("get_mods_for_card"):
		available_mods = ModificationRegistry.get_mods_for_card(selected_card.card_id)
	if available_mods.is_empty() and ModificationRegistry and ModificationRegistry.has_method("get_for_unit_type"):
		available_mods = ModificationRegistry.get_for_unit_type(selected_card.combat_kind)
	if available_mods.is_empty():
		var empty_label = Label.new()
		empty_label.text = "该兵种暂无可用改造"
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 0.8))
		mod_list_container.add_child(empty_label)
		return

	for mod_id in available_mods:
		var mod_data = ModificationRegistry.get_data(mod_id)
		var item = _create_mod_item(mod_id, mod_data)
		mod_list_container.add_child(item)

func _create_mod_item(mod_id: String, mod_data: Dictionary) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 48)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.text = ""
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_color_override("font_color", Color(0.91, 0.93, 0.96, 1))

	var rarity: String = String(mod_data.get("rarity", "common"))
	var rarity_col := _rarity_color(rarity)
	var is_installed := _is_mod_installed(mod_id)
	var can_install := _can_install_mod(mod_id)

	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(0.06, 0.10, 0.18, 0.6)
	sb_n.border_width_left = 3
	sb_n.border_color = rarity_col
	sb_n.set_corner_radius_all(5)
	sb_n.content_margin_left = 8
	sb_n.content_margin_top = 5
	sb_n.content_margin_right = 8
	sb_n.content_margin_bottom = 5
	if selected_mod_id == mod_id:
		sb_n.bg_color = Color(0.55, 0.35, 0.96, 0.16)
	btn.add_theme_stylebox_override("normal", sb_n)

	var sb_h := sb_n.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(0.12, 0.08, 0.22, 0.7)
	btn.add_theme_stylebox_override("hover", sb_h)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	row1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row1.add_child(_make_label(mod_data.get("name", mod_id), 13, Color(0.91, 0.93, 0.96, 1), true))
	var status_col := Color(0, 0.94, 1, 0.9)
	var status_text := "可安装"
	if is_installed:
		status_col = Color(0.2, 0.9, 0.4, 1)
		status_text = "✓已安装"
	elif not can_install:
		status_col = Color(0.9, 0.3, 0.3, 1)
		status_text = "✗冲突"
	row1.add_child(_make_label(status_text, 10, status_col, false))
	vbox.add_child(row1)

	var proto := String(mod_data.get("prototype", ""))
	if not proto.is_empty():
		vbox.add_child(_make_label("原型：%s" % proto, 10, Color(0.5, 0.55, 0.65, 0.85), true))

	btn.add_child(vbox)
	btn.disabled = is_installed or not can_install
	btn.tooltip_text = "%s\n%s\n稀有度：%s" % [proto, String(mod_data.get("description", "")), rarity]
	btn.pressed.connect(func(): _on_mod_selected(mod_id, mod_data))
	return btn

func _update_card_info() -> void:
	if card_info_panel == null:
		return
	if not selected_card:
		card_info_panel.visible = false
		return

	card_info_panel.visible = true

	# 显示 CardView（卡牌摘要+已装列表）时隐藏 ModDetailsPanel（避免重叠）
	var card_view = card_info_panel.get_node_or_null("CardView")
	if card_view:
		card_view.visible = true
	var mod_details = card_info_panel.get_node_or_null("ModDetailsPanel")
	if mod_details:
		mod_details.visible = false

	var info_label = card_info_panel.get_node_or_null("CardView/InfoLabel")
	if info_label:
		var rank_info = selected_card.get_military_rank()
		info_label.text = "%s\n军衔：%s | 改造：%d/9" % [
			selected_card.display_name,
			rank_info.name,
			selected_card.mods.size()
		]

	# 显示已安装改造列表
	var installed_list = card_info_panel.get_node_or_null("CardView/InstalledList")
	if installed_list:
		_refresh_installed_list(installed_list)

	# 更新资源标签
	if research_label:
		var nano_amount = BasicResourceManager.get_total(BasicResources.ID_NANO_MATERIALS)
		var total_blueprints = 0
		var _iib = Engine.get_main_loop().get_root().get_node_or_null("IntelItemBag")
		if _iib:
			total_blueprints = _iib.get_total_count()
		research_label.text = "纳米：%d | 图纸总数：%d" % [nano_amount, total_blueprints]

func _refresh_installed_list(installed_list: Control) -> void:
	for child in installed_list.get_children():
		child.queue_free()

	var mod_index := 0
	for mod_entry in selected_card.mods:
		var mod_id = mod_entry.get("id", "") if mod_entry is Dictionary else ""
		var mod_data = ModificationRegistry.get_data(mod_id)
		var rarity: String = String(mod_data.get("rarity", "common"))
		var slot_type: String = String(mod_data.get("slot_type", ""))
		var is_weapon_mod: bool = (slot_type == "weapon" or slot_type == "gun" or slot_type == "ammunition")
		# v6.5: 获取启用状态（武器类改造可切换）
		var enabled: bool = true
		if mod_entry is Dictionary and mod_entry.has("enabled"):
			enabled = bool(mod_entry["enabled"])

		var item := PanelContainer.new()
		item.custom_minimum_size = Vector2(0, 28)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.12, 0.2, 0.5) if enabled else Color(0.08, 0.08, 0.1, 0.5)
		sb.border_width_left = 2
		sb.border_color = _rarity_color(rarity) if enabled else (_rarity_color(rarity) * Color(1, 1, 1, 0.4))
		sb.set_corner_radius_all(3)
		sb.content_margin_left = 8
		sb.content_margin_top = 3
		sb.content_margin_right = 8
		sb.content_margin_bottom = 3
		item.add_theme_stylebox_override("panel", sb)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)

		var lbl := Label.new()
		var status_prefix: String = "✓ " if enabled else "⊘ "
		lbl.text = status_prefix + String(mod_data.get("name", mod_id))
		lbl.add_theme_font_size_override("font_size", 11)
		if enabled:
			lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95, 1))
		else:
			lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 0.7))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl)

		# v6.5: 武器类改造显示启用/禁用切换按钮
		if is_weapon_mod:
			var toggle_btn := Button.new()
			toggle_btn.text = "启用" if not enabled else "禁用"
			toggle_btn.add_theme_font_size_override("font_size", 10)
			toggle_btn.custom_minimum_size = Vector2(50, 0)
			# 绑定切换回调（用 lambda 捕获 mod_index）
			var captured_index := mod_index
			toggle_btn.pressed.connect(func():
				_on_weapon_mod_toggled(captured_index, not enabled)
			)
			hbox.add_child(toggle_btn)

		item.add_child(hbox)
		installed_list.add_child(item)
		mod_index += 1


## v6.5: 武器类改造启用/禁用切换
func _on_weapon_mod_toggled(mod_index: int, enable: bool) -> void:
	if selected_card == null:
		return
	if BlueprintManager and BlueprintManager.has_method("set_mod_enabled"):
		var ok: bool = BlueprintManager.set_mod_enabled(selected_card.card_id, mod_index, enable)
		if ok:
			# 刷新已安装列表
			var installed_list = card_info_panel.get_node_or_null("CardView/InstalledList") if card_info_panel else null
			if installed_list:
				_refresh_installed_list(installed_list)


## ─────────────────────────────────────────────
##  改造操作
## ─────────────────────────────────────────────

func _is_mod_installed(mod_id: String) -> bool:
	if not selected_card:
		return false
	# 优先从 BlueprintManager 的持久存储读取（比 card.mods 更可靠）
	if BlueprintManager and BlueprintManager.blueprint_mods.has(selected_card.card_id):
		var saved_mods = BlueprintManager.blueprint_mods[selected_card.card_id] as Array
		if saved_mods:
			for entry in saved_mods:
				var eid = entry.get("id", "") if entry is Dictionary else ""
				if eid == mod_id:
					return true
	# 回退到 card.mods（模板）
	for mod_entry in selected_card.mods:
		var entry_id = mod_entry.get("id", "") if mod_entry is Dictionary else ""
		if entry_id == mod_id:
			return true
	return false

func _can_install_mod(mod_id: String) -> bool:
	if not selected_card:
		return false

	var check_result = selected_card.can_install_modification(mod_id)
	return check_result.can_install

func _install_modification(mod_id: String) -> void:
	if not selected_card:
		return

	var result = BlueprintManager.install_modification(selected_card, mod_id)

	if result.success:
		_show_result("改造安装成功：%s" % result.message)
		_refresh_mod_list()
		_update_card_info()
	else:
		_show_result("安装失败：%s" % result.message)

## ─────────────────────────────────────────────
##  事件处理
## ─────────────────────────────────────────────

func _on_card_selected(card: CardResource) -> void:
	selected_card = card
	selected_mod_id = ""
	_refresh_mod_list()
	_update_card_info()

func _on_mod_selected(mod_id: String, mod_data: Dictionary) -> void:
	selected_mod_id = mod_id
	# 显示改造详情
	_show_mod_details(mod_data)

## v7.1: 改造效果展示更友好
func _show_mod_details(mod_data: Dictionary) -> void:
	var details_panel = card_info_panel.get_node_or_null("ModDetailsPanel")
	if details_panel:
		details_panel.visible = true
		# 隐藏 CardView，避免与详情重叠
		var card_view = card_info_panel.get_node_or_null("CardView")
		if card_view:
			card_view.visible = false

		var name_label = details_panel.get_node_or_null("DetailVBox/NameLabel")
		if name_label:
			var rarity_names := {"common": "普通", "uncommon": "精良", "rare": "稀有", "epic": "史诗", "legendary": "传说"}
			var mod_rarity: String = String(mod_data.get("rarity", "common"))
			name_label.text = "%s [%s]" % [mod_data.get("name", ""), rarity_names.get(mod_rarity, mod_rarity)]

		var proto_label = details_panel.get_node_or_null("DetailVBox/PrototypeLabel")
		if proto_label:
			proto_label.text = "原型：%s" % mod_data.get("prototype", "")

		var desc_label = details_panel.get_node_or_null("DetailVBox/DescLabel")
		if desc_label:
			desc_label.text = mod_data.get("description", "")

		var effects_label = details_panel.get_node_or_null("DetailVBox/EffectsLabel")
		if effects_label:
			var effects = mod_data.get("effects", {})
			var effect_texts = []
			for key in effects.keys():
				var val = effects[key]
				## 将效果键翻译为中文
				var key_display = _translate_effect_key(key)
				if val is float and val >= 0.01 and val < 100.0:
					effect_texts.append("%s +%d%%" % [key_display, int(val * 100)])
				elif val is float and val <= -0.01:
					effect_texts.append("%s %d%%" % [key_display, int(val * 100)])
				elif val is int:
					effect_texts.append("%s +%d" % [key_display, val])
				elif val is bool and val:
					effect_texts.append("✓ %s" % key_display)
				else:
						effect_texts.append("%s: %d" % [key_display, int(val)])
			effects_label.text = "效果：\n" + "\n".join(effect_texts) if effect_texts.size() > 0 else "无具体数值效果"

		# 消耗可视化
		# v6.2 修复：用基础战力（与实际扣费 BlueprintManager.install_modification 的 get_base_power_for_mod_cost 一致），
		# 原用 get_current_power（含强化+改造）导致显示成本虚高
		var base_power: float = BlueprintManager.get_base_power_for_mod_cost(selected_card.card_id) if selected_card else 100.0
		var nano_cost = int(base_power * 0.5)
		var blueprint_id = BlueprintDefinitions.get_mod_blueprint_id(selected_mod_id)
		var blueprint_name = BlueprintDefinitions.get_mod_blueprint_name(selected_mod_id)
		var has_blueprint = false
		var _iib = Engine.get_main_loop().get_root().get_node_or_null("IntelItemBag")
		if _iib:
			has_blueprint = _iib.has_item(blueprint_id)
		var nano_amount = BasicResourceManager.get_total(BasicResources.ID_NANO_MATERIALS) if BasicResourceManager else 0
		var has_nano = nano_amount >= nano_cost

		var nano_lbl = details_panel.get_node_or_null("DetailVBox/CostHBox/NanoCostLabel")
		if nano_lbl:
			nano_lbl.text = "纳米 %d %s" % [nano_cost, "✓" if has_nano else "✗（有%d）" % nano_amount]
			nano_lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4, 1) if has_nano else Color(0.95, 0.35, 0.35, 1))

		var bp_lbl = details_panel.get_node_or_null("DetailVBox/CostHBox/BlueprintCostLabel")
		if bp_lbl:
			bp_lbl.text = "图纸：%s %s" % [blueprint_name, "✓" if has_blueprint else "✗"]
			bp_lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4, 1) if has_blueprint else Color(0.95, 0.35, 0.35, 1))

		var install_btn = details_panel.get_node_or_null("DetailVBox/InstallButton")
		if install_btn:
			var is_installed = _is_mod_installed(selected_mod_id)
			if is_installed:
				install_btn.text = "已安装"
				install_btn.disabled = true
			elif not has_blueprint:
				install_btn.text = "缺少图纸"
				install_btn.disabled = true
			elif not has_nano:
				install_btn.text = "纳米不足"
				install_btn.disabled = true
			else:
				install_btn.text = "安装"
				install_btn.disabled = false

			# v5.0: Godot 4 正确的信号断开方式：存储并移除所有现有连接
			var connections: Array = install_btn.pressed.get_connections()
			for conn in connections:
				if conn.callable.is_valid():
					install_btn.pressed.disconnect(conn.callable)
			var install_callable = func(): _install_modification(selected_mod_id)
			install_btn.pressed.connect(install_callable)

## v7.1: 效果键翻译
func _translate_effect_key(key: String) -> String:
	match key:
		"attack_light": return "对直射攻击"
		"attack_armor": return "对曲射攻击"
		"attack_air": return "对空攻击"
		"defense_light": return "对直射防御"
		"defense_armor": return "对曲射防御"
		"defense_air": return "对空防御"
		"max_hp": return "生命值"
		"move_speed": return "移动速度"
		"attack_range": return "射程"
		"attack_interval": return "攻击间隔"
		"deploy_speed": return "部署速度"
		"crit_chance": return "暴击率"
		"dodge_chance": return "闪避率"
		"crit_resist": return "暴抗"
		"smoke_ignore": return "烟雾无视"
		"mine_immunity": return "地雷免疫"
		"river_no_penalty": return "涉渡无损"
		"missile_intercept": return "导弹拦截"
		"heat_immunity_once": return "HEAT首击免疫"
		"heat_resist": return "HEAT抗性"
		"ally_hit_bonus": return "友军命中加成"
		"vision": return "视野"
		_: return key


## 供外部调用的接口
func set_selected_card(card: CardResource) -> void:
	selected_card = card
	selected_mod_id = ""
	if has_node("VBoxContainer/HBoxContainer/DetailPanel"):
		_update_card_info()
	if has_node("VBoxContainer/HBoxContainer/ModScrollContainer"):
		_refresh_mod_list()

func show_panel() -> void:
	visible = true
	_refresh_card_list()

func _on_close() -> void:
	closed.emit()

func _show_result(message: String) -> void:
	if result_label:
		result_label.text = message
		result_label.visible = true
		# 失败用红，成功用绿
		var is_fail := message.findn("失败") >= 0 or message.findn("不足") >= 0 or message.findn("缺少") >= 0
		result_label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35, 1) if is_fail else Color(0.2, 0.9, 0.4, 1))
		await get_tree().create_timer(3.0).timeout
		if not is_inside_tree():
			return
		result_label.visible = false


# ========== 辅助函数 ==========

func _make_label(text: String, font_size: int, color: Color, expand: bool) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lbl

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

func _get_kind_color(combat_kind: int) -> Color:
	match CardResource.get_combat_kind_name(combat_kind):
		"步兵": return Color(0.9, 0.3, 0.3)
		"装甲": return Color(0.3, 0.55, 0.95)
		"炮兵": return Color(0.95, 0.6, 0.2)
		"防空": return Color(0.85, 0.8, 0.3)
		"空军": return Color(0.3, 0.85, 0.95)
		"侦察": return Color(0.4, 0.9, 0.4)
		"工程": return Color(0.65, 0.45, 0.95)
		"堡垒": return Color(0.6, 0.6, 0.65)
		_: return Color(0.6, 0.6, 0.65)

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"common": return Color(0.5, 0.5, 0.55)
		"uncommon": return Color(0.3, 0.85, 0.4)
		"rare": return Color(0.3, 0.6, 0.95)
		"epic": return Color(0.7, 0.4, 0.95)
		"legendary": return Color(1.0, 0.78, 0.2)
		_: return Color(0.5, 0.5, 0.55)
