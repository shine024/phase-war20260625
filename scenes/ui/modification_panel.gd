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
const ModEffectLabels = preload("res://scripts/ui/mod_effect_labels.gd")

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
	var ir: Node = get_node_or_null("/root/InstanceRegistry")

	## v7.1: 同时显示蓝图中有副本的卡和当前背包中的卡
	## 用 Dictionary 存 { card_id: { card: CardResource, instance_ids: Array } }
	var card_entries: Dictionary = {}

	## 来源1：蓝图有副本的
	for id_raw in BlueprintManager.get_all_blueprint_ids():
		var card_id: String = str(id_raw)
		if not card_entries.has(card_id):
			card_entries[card_id] = { "card": null, "instance_ids": [] }

	## 来源2：背包中的（可能是 instance_id 如 "cold_t72#1"）
	## v7.x 修复（铁律2）：优先读 InstanceRegistry 实例全集（真·实例数据源，永不被 consume）。
	## 原 ONLY 读 SaveManager 队列（pending+last_known），但该队列在 backpack_presenter 存活时
	## 会被 consume_pending_backpack_card_id 掏空，导致新买的卡看不到。SaveManager 队列降级为兜底。
	var sm: Node = get_node_or_null("/root/SaveManager")
	var all_backpack_ids: Array = []
	if ir != null and ir.has_method("get_all_instance_ids"):
		for iid in ir.get_all_instance_ids():
			all_backpack_ids.append(String(iid))
	if sm and sm.has_method("get_pending_backpack_ids"):
		all_backpack_ids.append_array(sm.get_pending_backpack_ids())
	if sm and sm.has_method("get_last_known_backpack_ids"):
		all_backpack_ids.append_array(sm.get_last_known_backpack_ids())

	for idv in all_backpack_ids:
		var sid: String = String(idv)
		if sid.is_empty():
			continue
		# 解析 instance_id → card_id
		var base_id: String = sid
		if ir != null and ir.has_method("get_card_id_of"):
			base_id = ir.get_card_id_of(sid)
		else:
			var hash_idx: int = sid.rfind("#")
			if hash_idx >= 0:
				base_id = sid.substr(0, hash_idx)
		# 记录 instance_id
		if not card_entries.has(base_id):
			card_entries[base_id] = { "card": null, "instance_ids": [] }
		# v7.x 修复（改造面板卡片重复）：pending 与 last_known 通常含同一 instance_id，
		# 原直接 append 会导致同一实例渲染两次。按 instance_id 去重后再入列。
		var _inst_arr: Array = card_entries[base_id]["instance_ids"]
		if not _inst_arr.has(sid):
			_inst_arr.append(sid)

	## 按 card_id 加载模板 CardResource
	## v7.x 修复：原版 DefaultCards.get_card_by_id 查不到模板就 continue，导致动态卡/迁移卡
	## （InstanceRegistry 里有实例，但模板未注册进 DefaultCards 缓存）被静默丢弃——
	## 背包能看到这些卡（走实例），但改造面板看不到。现在模板查不到时回退取首个实例，
	## 用实例的模板字段（display_name/combat_kind/rarity）渲染。
	for card_id in card_entries:
		var card: CardResource = DefaultCards.get_card_by_id(card_id)
		if card == null:
			# 模板查不到 → 回退取 Registry 首个同名实例（实例 clone 自模板，模板字段都在）
			if ir != null and ir.has_method("get_instances_by_card_id"):
				var _fb_ids: Array = ir.get_instances_by_card_id(card_id)
				if not _fb_ids.is_empty() and ir.has_method("get_instance"):
					card = ir.get_instance(String(_fb_ids[0]))
			if card == null:
				continue
		if card.card_type != GC.CardType.COMBAT_UNIT:
			continue
		card_entries[card_id]["card"] = card

	## 为每个 card_id 生成一个或多个列表项
	for card_id in card_entries:
		var entry = card_entries[card_id]
		var card: CardResource = entry["card"]
		if card == null:
			continue
		var instance_ids: Array = entry["instance_ids"]
		if not instance_ids.is_empty():
			# 有实例：为每个实例生成一个条目（带独立养成数据）
			for inst_id in instance_ids:
				var inst_card: CardResource = null
				if ir != null and ir.has_method("get_instance"):
					inst_card = ir.get_instance(inst_id)
				var item = _create_card_item(card, inst_card)
				card_list_container.add_child(item)
		else:
			# 无实例：仅显示模板（蓝图解锁但未入包的卡）
			var item = _create_card_item(card, null)
			card_list_container.add_child(item)

func _create_card_item(card: CardResource, instance_card: CardResource = null) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 52)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.text = ""
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_color_override("font_color", Color(0.91, 0.93, 0.96, 1))

	# v7.1: 使用实例数据（如有），否则用模板
	var display_card: CardResource = instance_card if instance_card != null else card
	var display_name: String = card.display_name if card.display_name else card.card_id
	var display_level: int = display_card.enhance_level if display_card else 0
	var display_mods: Array = display_card.mods if display_card else []
	var display_rarity: String = str(card.rarity) if card.has_method("get") else "common"
	# 兼容 CardResource 字段
	# 注意：Object.get() 只接受 1 个参数（属性名），需手动处理默认值
	if display_card != null and display_card is Object and "rarity" in display_card:
		display_rarity = str(display_card.rarity)
	elif card is Object and "rarity" in card:
		display_rarity = str(card.rarity)
	var display_instance_id: String = ""
	if display_card != null and display_card is Object and "instance_id" in display_card:
		display_instance_id = str(display_card.instance_id)

	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(0.06, 0.10, 0.18, 0.6)
	sb_n.set_border_width_all(1)
	sb_n.set_corner_radius_all(5)
	sb_n.content_margin_left = 8
	sb_n.content_margin_top = 5
	sb_n.content_margin_right = 8
	sb_n.content_margin_bottom = 5
	if selected_card and selected_card.instance_id == display_instance_id:
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
	name_row.add_child(_make_label(display_name, 13, Color(0.91, 0.93, 0.96, 1), true))
	# v7.1: 同名多实例显示序号后缀
	var inst_seq: String = ""
	if instance_card != null and instance_card.instance_id != null and not str(instance_card.instance_id).is_empty():
		var iid: String = str(instance_card.instance_id)
		var h: int = iid.rfind("#")
		if h >= 0:
			inst_seq = " #%s" % iid.substr(h + 1)
	name_row.add_child(_make_label(inst_seq, 11, Color(0.6, 0.6, 0.7, 0.8), false))
	vbox.add_child(name_row)

	var meta_row := HBoxContainer.new()
	meta_row.add_theme_constant_override("separation", 8)
	meta_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var star_count: int = StarConfig.calculate_star(display_level * 2, card.rarity)
	var star_str := ""
	for s in range(5):
		star_str += "★" if s < star_count else "☆"
	meta_row.add_child(_make_label(star_str, 10, Color(1.0, 0.84, 0.0, 0.85), false))
	meta_row.add_child(_make_label("改造 %d/9" % display_mods.size(), 10, Color(0, 0.94, 1, 0.9), false))
	meta_row.add_child(_make_label("Lv.%d" % display_level, 10, Color(0.5, 0.5, 0.6, 0.7), false))
	vbox.add_child(meta_row)

	btn.add_child(vbox)
	btn.tooltip_text = "改造：%d/9" % display_mods.size()
	# v7.3: 选中绑定用实例对象（含养成）。实例取不到时传 null，
	# _on_card_selected 会拒绝选中（避免改造写到无养成的模板污染单例）。
	# display_card 仅用于列表项显示（含回退模板的展示），不参与养成写入。
	btn.pressed.connect(func(): _on_card_selected(instance_card))
	return btn

## v7.x 重构：显示所有已解锁（持有图纸）的改造，选了战斗卡时用状态标识区分可用性。
## 数据源从 ModificationRegistry.get_mods_for_card（硬编码 card_id 前缀白名单，不全）
## 改为从 IntelItemBag 读所有改造图纸（与背包"改造"Tab 同口径）——
## 这样背包里有的改造在面板里一定能看到，不会再出现"背包有、面板没有"。
## 兵种适用性由 _create_mod_item 的"⊘该兵种不适用"灰态标识，不再从列表里剔除。
func _refresh_mod_list() -> void:
	if not selected_card:
		return

	for child in mod_list_container.get_children():
		child.queue_free()

	## 从 IntelItemBag 读所有已解锁改造图纸（照搬 backpack_panel.refresh_intel_tab 的口径）
	var bag = get_node_or_null("/root/IntelItemBag")
	var unlocked_mod_ids: Array = []
	if bag and bag.has_method("get_all_inventory"):
		var inv: Dictionary = bag.get_all_inventory()
		for item_type in inv.keys():
			if int(inv[item_type]) <= 0:
				continue
			# 仅处理改造图纸（blueprint_ 前缀，排除 blueprint_evol_ 进化图纸）
			if not IntelManualItems.is_mod_blueprint(item_type):
				continue
			var mod_id: String = BlueprintDefinitions.extract_mod_id(item_type)
			if not mod_id.is_empty() and not unlocked_mod_ids.has(mod_id):
				unlocked_mod_ids.append(mod_id)

	if unlocked_mod_ids.is_empty():
		var empty_label = Label.new()
		empty_label.text = "暂无已解锁改造\n（获得改造图纸后，所有已解锁改造会显示于此）"
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 0.8))
		mod_list_container.add_child(empty_label)
		return

	## 按稀有度排序（高→低），让玩家先看到珍贵改造
	unlocked_mod_ids.sort_custom(func(a: String, b: String):
		return _rarity_sort_value(String(ModificationRegistry.get_data(a).get("rarity", "common"))) \
			> _rarity_sort_value(String(ModificationRegistry.get_data(b).get("rarity", "common"))))

	for mod_id in unlocked_mod_ids:
		var mod_data = ModificationRegistry.get_data(mod_id)
		if mod_data.is_empty():
			continue  # 找不到改造数据（旧/无效 mod_id），跳过避免渲染异常
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
	var rarity_names := {"common": "普通", "uncommon": "优秀", "rare": "稀有", "epic": "史诗", "legendary": "传说", "mythic": "神话"}
	var rarity_cn: String = rarity_names.get(rarity, rarity)
	var rarity_col := _rarity_color(rarity)
	var is_installed := _is_mod_installed(mod_id)
	var is_applicable := _is_mod_applicable_to_card(mod_id)
	# 不适用时跳过 can_install_modification（它会因改造数据存在但兵种不符而返回误判），
	# 直接 block_reason = "不适用该兵种"；适用时才查具体 block 原因（冲突/槽满/情报不足）。
	var block_reason := ""
	if is_applicable and not is_installed:
		block_reason = _get_install_block_reason(mod_id)

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
	# 改造图标
	var icon_path: String = mod_data.get("icon", "")
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path, "Texture2D"):
		var tex_rect := TextureRect.new()
		tex_rect.texture = load(icon_path)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(28, 28)
		tex_rect.tooltip_text = mod_data.get("name", mod_id)
		row1.add_child(tex_rect)
	row1.add_child(_make_label(mod_data.get("name", mod_id), 13, Color(0.91, 0.93, 0.96, 1), true))
	# v7.x 四态状态标识：已安装 / 可安装 / ⊘该兵种不适用 / ✗冲突·槽满·情报不足
	var status_col := Color(0, 0.94, 1, 0.9)
	var status_text := "可安装"
	if is_installed:
		status_col = Color(0.2, 0.9, 0.4, 1)
		status_text = "✓已安装"
	elif not is_applicable:
		status_col = Color(0.5, 0.5, 0.55, 0.7)
		status_text = "⊘该兵种不适用"
	elif not block_reason.is_empty():
		status_col = Color(0.9, 0.3, 0.3, 1)
		status_text = "✗%s" % block_reason
	row1.add_child(_make_label(status_text, 10, status_col, false))
	vbox.add_child(row1)

	var proto := String(mod_data.get("prototype", ""))
	if not proto.is_empty():
		vbox.add_child(_make_label("原型：%s" % proto, 10, Color(0.5, 0.55, 0.65, 0.85), true))

	btn.add_child(vbox)
	# 禁用规则：已安装、不适用、或被 block（冲突/槽满/情报不足）时禁用点击
	btn.disabled = is_installed or not is_applicable or not block_reason.is_empty()
	btn.tooltip_text = "%s\n%s\n稀有度：%s" % [proto, String(mod_data.get("description", "")), rarity_cn]
	btn.pressed.connect(func(): _on_mod_selected(mod_id, mod_data))
	return btn

## 判断改造是否适用于选中卡的兵种。
## v7.x：数据源切到 IntelItemBag 后，列表会显示所有已解锁改造（不限兵种），
## 此函数用于在 _create_mod_item 里给不适用的改造标灰"⊘该兵种不适用"。
## 复用 ModificationRegistry 的 get_mods_for_card（card_id 精筛）+ get_for_unit_type（combat_kind 兜底）。
func _is_mod_applicable_to_card(mod_id: String) -> bool:
	if not selected_card:
		return true  # 无选中卡时不拦截，统一显示为"可安装"
	if ModificationRegistry and ModificationRegistry.has_method("get_mods_for_card"):
		if mod_id in ModificationRegistry.get_mods_for_card(selected_card.card_id):
			return true
	if ModificationRegistry and ModificationRegistry.has_method("get_for_unit_type"):
		if mod_id in ModificationRegistry.get_for_unit_type(selected_card.combat_kind):
			return true
	return false

## 获取改造安装的阻断原因（空串表示可安装）。
## v7.x：透传 can_install_modification 的 reason，让"✗冲突"细分为冲突/槽满/情报不足。
func _get_install_block_reason(mod_id: String) -> String:
	if not selected_card:
		return ""
	var check_result: Dictionary = selected_card.can_install_modification(mod_id)
	if check_result.get("can_install", true):
		return ""
	return String(check_result.get("reason", "冲突"))

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
		info_label.text = "%s\n强化 Lv.%d | 改造：%d/9" % [
			selected_card.display_name,
			selected_card.enhance_level,
			selected_card.mods.size()
		]

	# 显示已安装改造列表
	var installed_list = card_info_panel.get_node_or_null("CardView/InstalledList")
	if installed_list:
		_refresh_installed_list(installed_list)

	# 更新资源标签：仅显示纳米（图纸是否持有在改造详情页逐项判断，顶部总数无决策价值）
	if research_label:
		var nano_amount = BasicResourceManager.get_total(BasicResources.ID_NANO_MATERIALS)
		research_label.text = "纳米：%d" % nano_amount

func _refresh_installed_list(installed_list: Control) -> void:
	# 同步移除（remove_child + free），不要用 queue_free：InstalledList 不在 ScrollContainer 内
	# （它是 DetailPanel→CardView 下的 VBox），而整个面板挂在 CenterContainer 下。
	# queue_free 延迟删除会让旧行与新行同帧共存，DetailPanel 的 combined_minimum_size 暂时膨胀，
	# CenterContainer 据此把面板撑高且永不回缩（切换到已装改造数量不同的卡时面板变长）。
	for child in installed_list.get_children():
		installed_list.remove_child(child)
		child.free()

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

		# v6.10: 改造列表每项用 VBox——第一行名字+图标+切换，第二行完整效果
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)

		# 已安装改造图标
		var icon_path: String = mod_data.get("icon", "")
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path, "Texture2D"):
			var tex_rect := TextureRect.new()
			tex_rect.texture = load(icon_path)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.custom_minimum_size = Vector2(20, 20)
			hbox.add_child(tex_rect)

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

		vbox.add_child(hbox)

		# v6.10: 第二行——显示完整改造效果（复用已修好的 _format_effects_for_display）
		# 让玩家一眼看到"装了什么、加什么"，而不只是改造名字
		var effect_lines := _format_effects_for_display(mod_data)
		if not effect_lines.is_empty():
			var effect_lbl := Label.new()
			effect_lbl.text = " · ".join(effect_lines)
			effect_lbl.add_theme_font_size_override("font_size", 10)
			if enabled:
				effect_lbl.add_theme_color_override("font_color", Color(0.65, 0.78, 0.62, 0.95))
			else:
				effect_lbl.add_theme_color_override("font_color", Color(0.45, 0.5, 0.45, 0.6))
			effect_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			vbox.add_child(effect_lbl)

		item.add_child(vbox)
		installed_list.add_child(item)
		mod_index += 1


## v6.5: 武器类改造启用/禁用切换
func _on_weapon_mod_toggled(mod_index: int, enable: bool) -> void:
	if selected_card == null:
		return
	if BlueprintManager and BlueprintManager.has_method("set_mod_enabled"):
		# v7.0: 用 instance_id 操作（实例化养成）；无 instance_id 回退 card_id
		var ok: bool = BlueprintManager.set_mod_enabled(_selected_id(), mod_index, enable)
		if ok:
			# 刷新已安装列表
			var installed_list = card_info_panel.get_node_or_null("CardView/InstalledList") if card_info_panel else null
			if installed_list:
				_refresh_installed_list(installed_list)


## v7.0: 取当前选中卡的身份标识（优先 instance_id，回退 card_id）
func _selected_id() -> String:
	if selected_card == null:
		return ""
	return selected_card.instance_id if not selected_card.instance_id.is_empty() else selected_card.card_id


## ─────────────────────────────────────────────
## 改造操作
## ─────────────────────────────────────────────

func _is_mod_installed(mod_id: String) -> bool:
	if not selected_card:
		return false
	# 优先从 BlueprintManager 的持久存储读取（比 card.mods 更可靠）
	# v7.0: 用 instance_id 查（blueprint_mods key 已改 instance_id）
	var sid: String = _selected_id()
	if BlueprintManager and BlueprintManager.blueprint_mods.has(sid):
		var saved_mods = BlueprintManager.blueprint_mods[sid] as Array
		if saved_mods:
			for entry in saved_mods:
				var eid = entry.get("id", "") if entry is Dictionary else ""
				if eid == mod_id:
					return true
	# 回退到 card.mods（实例对象）
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
	# v7.3: 双重保险——改造必须写到实例对象。无 instance_id 的卡是模板/残留，
	# install_modification 会把改造写到模板污染单例。在此拦截，与 _on_card_selected 的守卫呼应。
	if selected_card.instance_id.is_empty():
		push_warning("[modification_panel] _install_modification: 选中卡 '%s' 无 instance_id，拒绝安装（避免污染模板）" % selected_card.card_id)
		_show_result("该卡牌实例不可用，无法改造")
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
	# v7.x 修复：原版收到 instance_id 为空的卡（模板/残留）直接 return 并报错，
	# 导致独立改造面板点击"无实例但列表里显示的卡"时毫无反应。
	# 列表项绑定的 instance_card（_create_card_item:227）在 Registry 缺失该实例
	# （但 SaveManager 兜底队列里有）时为 null → 回退到模板 → 被原守卫拦死。
	# 现复用 _resolve_instance_or_warn 回退查同名实例；仍查不到才真的拒绝。
	var resolved_card: CardResource = _resolve_instance_or_warn(card)
	if resolved_card == null:
		_show_result("该卡牌实例不可用，无法改造（请重新获取该卡）")
		return
	selected_card = resolved_card
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
			var rarity_names := {"common": "普通", "uncommon": "优秀", "rare": "稀有", "epic": "史诗", "legendary": "传说", "mythic": "神话"}
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
			var effect_texts = _format_effects_for_display(mod_data)
			effects_label.text = "效果：\n" + "\n".join(effect_texts) if effect_texts.size() > 0 else "无具体数值效果"

		# 新增：元信息（槽位/冲突组/倍率）
		var meta_label = details_panel.get_node_or_null("DetailVBox/MetaInfoLabel")
		if meta_label:
			var slot_type: String = String(mod_data.get("slot_type", ""))
			var conflict: String = String(mod_data.get("conflict_group", ""))
			var power_mult: float = float(mod_data.get("power_mult", 1.0))
			var parts: Array = []
			if not slot_type.is_empty():
				parts.append("槽位：%s" % _translate_slot_type(slot_type))
			if not conflict.is_empty():
				parts.append("冲突组：%s" % _translate_conflict(conflict))
			if power_mult != 1.0:
				parts.append("战力倍率×%.1f" % power_mult)
			meta_label.text = " — ".join(parts) if not parts.is_empty() else "—"

		# 新增：属性变化预览（基于选中卡的当前属性计算）
		var stat_delta_label = details_panel.get_node_or_null("DetailVBox/StatDeltaLabel")
		if stat_delta_label:
			stat_delta_label.text = _build_stat_delta_preview(mod_data)

		# 新增：解锁条件
		var unlock_label = details_panel.get_node_or_null("DetailVBox/UnlockLabel")
		if unlock_label:
			var unlock = mod_data.get("unlock_conditions", {})
			if unlock is Dictionary and unlock.has("required_level"):
				var req_lv = int(unlock["required_level"])
				unlock_label.text = "解锁要求：强化等级 ≥ %d" % req_lv
			else:
				unlock_label.text = ""

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

## 构建属性变化预览：对比安装改造前后各属性的变化
func _build_stat_delta_preview(mod_data: Dictionary) -> String:
	if selected_card == null:
		return ""
	# 读取当前卡的属性（含已有改造加成）
	var current_stats: Dictionary = selected_card.get_modified_stats()
	if current_stats.is_empty():
		return ""
	var eff: Dictionary = mod_data.get("effects", {})
	if eff.is_empty():
		return ""
	var le: Dictionary = mod_data.get("level_effects", {})
	# 如果有等级效果，取最高档
	if not le.is_empty():
		var levels = le.keys()
		levels.sort()
		eff = le[levels[levels.size() - 1]]
	# 计算变化
	var lines: Array = []
	for key in eff.keys():
		var val = eff[key]
		var cn = ModEffectLabels.translate(key)
		var cur_val = current_stats.get(key, 0)
		var delta_str = _format_delta(cn, cur_val, val)
		lines.append(delta_str)
	if lines.is_empty():
		return ""
	return "属性预览：\n" + "\n".join(lines)

## 格式化单条属性变化
func _format_delta(stat_name: String, current_val, change_val) -> String:
	if change_val is float:
		if change_val > 0:
			return "▶ %s: %s +%.0f%%" % [stat_name, _val_display(current_val, change_val), change_val * 100]
		elif change_val < 0:
			return "▶ %s: %s %d%%" % [stat_name, _val_display(current_val, change_val), int(change_val * 100)]
	elif change_val is int:
		return "▶ %s: %s +%d" % [stat_name, _val_display(current_val, change_val), change_val]
	elif change_val is bool and change_val:
		return "▶ %s: ✓ 解锁" % stat_name
	return "▶ %s: %s" % [stat_name, str(change_val)]

## 数值显示：根据当前值格式化变化后结果
func _val_display(current, change) -> String:
	if current is int or current is float:
		var new_val = current + (change if change is int else int(float(current) * (1.0 + change)))
		return "%d→%d" % [int(current), int(new_val)]
	return ""

## 槽位类型翻译
func _translate_slot_type(raw: String) -> String:
	var maps: Dictionary = {
		"weapon": "武器",
		"weapons": "武器",
		"armor": "装甲",
		"gun": "火炮",
		"ammunition": "弹药",
		"active": "主动",
		"aerodynamics": "气动",
		"autoloader": "自动装填",
		"automation": "自动化",
		"barrel": "枪管",
		"bridge": "舰桥",
		"command": "指挥",
		"comms": "通信",
		"countermeasure": "对抗",
		"deception": "欺骗",
		"demolition": "爆破",
		"designator": "指示",
		"digging": "挖掘",
		"drone": "无人机",
		"ecm": "电子对抗",
		"electronics": "电子",
		"engine": "引擎",
		"engineering": "工程",
		"enhancement": "强化",
		"environment": "环境",
		"ergonomics": "人体工学",
		"exoskeleton": "外骨骼",
		"fire_control": "火控",
		"fortification": "筑城",
		"fuze": "引信",
		"guidance": "制导",
		"helmet": "头盔",
		"laser": "激光",
		"logistics": "后勤",
		"medical": "医疗",
		"minefield": "布雷",
		"missile": "导弹",
		"mobility": "机动",
		"mount": "炮塔",
		"navigation": "导航",
		"network": "网络",
		"obstacle": "障碍",
		"optics": "光学",
		"power": "动力",
		"protection": "防护",
		"radar": "雷达",
		"recon": "侦察",
		"recovery": "抢修",
		"repair": "维修",
		"shield": "盾牌",
		"stealth": "隐身",
		"survival": "生存",
		"system": "系统",
		"thrust": "推力",
	}
	return maps.get(raw, raw)

## 冲突组翻译
func _translate_conflict(raw: String) -> String:
	var maps: Dictionary = {
		"fire_rate": "射速",
		"armor": "装甲",
		"damage": "伤害",
		"environment": "环境",
		"enh_atkspd": "攻速强化",
		"enh_chain": "连锁强化",
		"enh_crit": "暴击强化",
		"enh_crit_dmg": "暴伤强化",
		"enh_def": "防御强化",
		"enh_def_flat": "平防强化",
		"enh_dmg": "伤害强化",
		"enh_dodge": "闪避强化",
		"enh_hp": "生命强化",
		"enh_lifesteal": "吸血强化",
		"enh_penetration": "穿透强化",
		"enh_range": "射程强化",
		"enh_regen": "回复强化",
		"enh_shield_kill": "护盾强化",
		"enh_speed": "速度强化",
		"enh_splash": "溅射强化",
	}
	return maps.get(raw, raw)

## 效果键翻译（薄封装，委托 ModEffectLabels 共享表）。
## v7.x 统一：情报/改造/强化三面板共用 ModEffectLabels.translate（简短词口径），
## 消除原先与 card_info_panel 的"完整词 vs 简短词"分叉。
func _translate_effect_key(key: String) -> String:
	return ModEffectLabels.translate(key)


## v7.2: 格式化改造效果为展示文本（兼容 effects 单档 + level_effects 多档）
## 返回行数组（供 effects_label 展示）
func _format_effects_for_display(mod_data: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	# 优先 effects（单档），其次 level_effects（Lv1/2/3 多档，enhancement 词条用）
	if mod_data.has("effects") and (mod_data["effects"] as Dictionary).size() > 0:
		var eff: Dictionary = mod_data["effects"]
		for key in eff.keys():
			lines.append(_format_one_effect(String(key), eff[key]))
	elif mod_data.has("level_effects") and (mod_data["level_effects"] as Dictionary).size() > 0:
		var le: Dictionary = mod_data["level_effects"]
		# level_effects = {1: {...}, 2: {...}, 3: {...}}，取最高档展示（max_level 对应满级数值）
		var sorted_levels = le.keys()
		sorted_levels.sort()
		var top_level = sorted_levels[sorted_levels.size() - 1]
		var top_eff: Dictionary = le[top_level]
		lines.append("—— Lv.%d（满级）——" % int(top_level))
		for key in top_eff.keys():
			lines.append(_format_one_effect(String(key), top_eff[key]))
	# v6.13: grant_slot 赋予新攻击维度（如炮射导弹激活对空槽）
	if mod_data.has("grant_slot") and (mod_data["grant_slot"] as Dictionary).size() > 0:
		lines.append(_format_grant_slot(mod_data["grant_slot"]))
	return lines


## v7.2: 格式化单条效果（key + value）为一行文本
## 数值格式化沿用 v7.1 逻辑：小数百分比 / 整数加成 / 布尔勾选 / 其他
func _format_one_effect(key: String, val) -> String:
	var key_display = _translate_effect_key(key)
	if val is float and val >= 0.01 and val < 100.0:
		return "%s +%d%%" % [key_display, int(val * 100)]
	elif val is float and val <= -0.01:
		return "%s %d%%" % [key_display, int(val * 100)]
	elif val is int:
		if val >= 0:
			return "%s +%d" % [key_display, val]
		return "%s %d" % [key_display, val]
	elif val is bool and val:
		return "✓ %s" % key_display
	else:
		return "%s: %d" % [key_display, int(val)]


## v6.13: 格式化 grant_slot（赋予新攻击维度）为一行展示文本
## v7.x: 复用 ModEffectLabels.format_grant_slot，与情报面板 grant 文案完全一致。
## grant = {slot, base_damage, damage_ratio, speed, weapon_type, display_name, ...}
func _format_grant_slot(grant: Dictionary) -> String:
	return ModEffectLabels.format_grant_slot(grant)


## 解析卡牌为实例：instance_id 非空直接用；为空（模板/残留）则回退查 Registry 同名实例。
## 返回 null 表示确实无可用实例（此时调用方 return）。
## v7.x 修复：原 set_selected_card/_on_card_selected 收到 instance_id 为空的卡直接 return，
## 导致改造 Tab 永远空。但背包 backpack_data 在 Registry 缺失某实例时会回退到 DefaultCards 模板
## （instance_id 空），而该 card_id 的实例可能其实存在于 Registry（只是引用对不上）——
## 改造数据挂在实例上，不回退就永远读不到。此处复用战场 _resolve_source_instance_card 的回退链模式。
func _resolve_instance_or_warn(card: CardResource) -> CardResource:
	if card == null:
		return null
	if not card.instance_id.is_empty():
		return card
	# instance_id 为空（模板/残留）→ 按 card_id 查首个同名实例
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir != null and ir.has_method("get_instances_by_card_id") and not card.card_id.is_empty():
		var insts: Array = ir.get_instances_by_card_id(card.card_id)
		if not insts.is_empty() and ir.has_method("get_instance"):
			var fb: CardResource = ir.get_instance(String(insts[0]))
			if fb != null:
				push_warning("[modification_panel] 卡 '%s' 无 instance_id，已回退到同名实例 '%s'" % [card.card_id, fb.instance_id])
				return fb
	push_warning("[modification_panel] 卡 '%s' 无 instance_id 且 Registry 无同名实例，拒绝选中" % card.card_id)
	return null

## 供外部调用的接口
func set_selected_card(card: CardResource) -> void:
	# v7.x 修复：原版收到 instance_id 为空的卡直接 return，导致嵌入模式（背包→情报面板改造 Tab）
	# 改造 Tab 永远空。现回退查同名实例（Registry 缺失某实例但 backpack_data 回退到模板的场景）。
	var resolved_card: CardResource = _resolve_instance_or_warn(card)
	if resolved_card == null:
		_show_result("该卡牌实例不可用，无法改造（请重新获取该卡）")
		return
	selected_card = resolved_card
	selected_mod_id = ""
	# v7.x 修复（Bug2）：非嵌入模式下进入面板时补刷卡片列表。
	# 根因：面板被 ui_lazy_loader 缓存（整个会话只实例化一次），_refresh_card_list 只在首帧 _ready 跑一次。
	# 从 growth_panel 跳转进来走 set_selected_card（而非 show_panel），原版不刷列表，导致卡片列表永远停留在首帧快照。
	# 嵌入模式（card_info_panel 内嵌）下卡片列表本就被 _apply_embedded_layout 隐藏，无需刷新。
	if not _embedded_mode and card_list_container != null:
		_refresh_card_list()
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

## v7.x 稀有度配色统一到 GC.get_rarity_color（单一数据源），避免与背包卡牌/卡框配色不一致。
func _rarity_color(rarity: String) -> Color:
	return GC.get_rarity_color(rarity)

## 稀有度排序权重（mythic 最大，用于已解锁改造列表按稀有度降序排列）
func _rarity_sort_value(rarity: String) -> int:
	match rarity:
		"common": return 1
		"uncommon": return 2
		"rare": return 3
		"epic": return 4
		"legendary": return 5
		"mythic": return 6
		_: return 0
