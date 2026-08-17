extends Control
class_name FactionPanel
## 势力系统UI面板
## 
## 功能：
## - 显示7个势力的信息（名称、描述、声望等级）
## - 显示势力升级进度
## - 显示势力控制的关卡数量
## - 显示势力商店库存预览
## - 实时更新势力声望变化

const GC = preload("res://resources/game_constants.gd")
const FactionSkillTree = preload("res://data/faction_skill_tree.gd")
const FactionSkillManager = preload("res://managers/faction/faction_skill_manager.gd")
const DT = preload("res://resources/design_tokens.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")
const PanelChrome = preload("res://scenes/ui/components/panel_chrome.gd")

signal closed

# UI 组件引用
@onready var faction_scroll = $VBoxContainer/HBoxContainer/ScrollContainer/FactionListContainer
@onready var faction_detail = $VBoxContainer/HBoxContainer/DetailScroll/DetailPanel

# 数据
var selected_faction_id: String = ""
var faction_items: Array = []
# v9 perf：隐藏期间的势力信号置脏，重新显示时补刷
var _detail_dirty: bool = false

func _ready() -> void:
	# v7.x 面板统一：MEDIUM 档 + 紫色签名框架 + PanelChrome 标题栏（右上 ✕ 关闭）
	custom_minimum_size = DT.PANEL_SIZE_MEDIUM
	var accent := DT.get_panel_accent("faction")
	add_theme_stylebox_override("panel", PanelStyles.make_panel_frame(accent))
	var chrome = PanelChrome.attach_to($VBoxContainer, "势力系统", accent, "FACTION")
	chrome.closed.connect(_on_close)
	# v9 perf：重新显示时补刷隐藏期间积累的势力变化
	visibility_changed.connect(_on_visibility_refresh)
	# 连接信号
	ManagerLazyLoader.ensure_loaded("faction")
	var faction_mgr = get_node_or_null("/root/FactionSystemManager")
	if faction_mgr:
		faction_mgr.faction_reputation_changed.connect(_on_faction_reputation_changed)
		faction_mgr.faction_level_up.connect(_on_faction_level_up)
		faction_mgr.faction_store_updated.connect(_on_faction_store_updated)
		# v8.5: 势力技能树解锁 + 激活势力变化 → 刷新详情（技能节点状态/激活按钮）
		if faction_mgr.has_signal("faction_skill_unlocked"):
			faction_mgr.faction_skill_unlocked.connect(_on_faction_skill_changed)
		if faction_mgr.has_signal("active_faction_changed"):
			faction_mgr.active_faction_changed.connect(_on_active_faction_changed)

	# 初始化势力列表
	_init_faction_list()
	# 选择第一个势力
	if faction_items.size() > 0:
		_on_faction_item_selected(faction_items[0]["id"])

## v7.x 修复 W6：面板释放时断开 autoload 信号，避免残留死 Callable（内存泄漏/脏连接）
func _exit_tree() -> void:
	var faction_mgr = get_node_or_null("/root/FactionSystemManager")
	if faction_mgr == null:
		return
	if faction_mgr.has_signal("faction_reputation_changed") and faction_mgr.faction_reputation_changed.is_connected(_on_faction_reputation_changed):
		faction_mgr.faction_reputation_changed.disconnect(_on_faction_reputation_changed)
	if faction_mgr.has_signal("faction_level_up") and faction_mgr.faction_level_up.is_connected(_on_faction_level_up):
		faction_mgr.faction_level_up.disconnect(_on_faction_level_up)
	if faction_mgr.has_signal("faction_store_updated") and faction_mgr.faction_store_updated.is_connected(_on_faction_store_updated):
		faction_mgr.faction_store_updated.disconnect(_on_faction_store_updated)
	# v8.5: 断开技能树/激活势力信号
	if faction_mgr.has_signal("faction_skill_unlocked") and faction_mgr.faction_skill_unlocked.is_connected(_on_faction_skill_changed):
		faction_mgr.faction_skill_unlocked.disconnect(_on_faction_skill_changed)
	if faction_mgr.has_signal("active_faction_changed") and faction_mgr.active_faction_changed.is_connected(_on_active_faction_changed):
		faction_mgr.active_faction_changed.disconnect(_on_active_faction_changed)


# v8.5: 势力技能树解锁/激活变化回调 → 刷新详情区（技能节点状态变化）
func _on_faction_skill_changed(_faction_id: String, _skill_id: String) -> void:
	if is_visible_in_tree():
		_update_faction_detail()

func _on_active_faction_changed(_faction_id: String) -> void:
	if is_visible_in_tree():
		_update_faction_detail()

func _init_faction_list() -> void:
	"""初始化势力列表"""
	var faction_mgr = get_node_or_null("/root/FactionSystemManager")
	if not faction_scroll or not faction_mgr:
		return
	
	# 清空现有列表
	for child in faction_scroll.get_children():
		child.queue_free()
	
	faction_items.clear()
	
	# 获取所有势力信息
	var all_factions = faction_mgr.get_all_factions_info()
	
	for faction_info in all_factions:
		var faction_id = faction_info.get("id", "")
		if faction_id.is_empty():
			continue
		
		# 创建势力项目按钮
		var item_button = Button.new()
		var faction_name = faction_info.get("name", "")
		var level = faction_info.get("level", 1)
		item_button.text = "%s (Lv.%d)" % [faction_name, level]
		item_button.custom_minimum_size = Vector2(200, 50)
		var item_styles := PanelStyles.make_button_styles(DT.get_panel_accent("faction"))
		item_button.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		item_button.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
		item_button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
		item_button.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
		item_button.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))
		item_button.add_theme_stylebox_override("normal", item_styles["normal"])
		item_button.add_theme_stylebox_override("hover", item_styles["hover"])
		item_button.add_theme_stylebox_override("pressed", item_styles["pressed"])
		item_button.add_theme_stylebox_override("disabled", item_styles["disabled"])
		var logo: Texture2D = UiAssetLoader.faction_logo_128(faction_id)
		if logo != null:
			item_button.icon = logo
			item_button.expand_icon = true
			item_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		item_button.pressed.connect(_on_faction_item_selected.bindv([faction_id]))
		
		faction_scroll.add_child(item_button)
		faction_items.append({"id": faction_id, "button": item_button})

func _on_faction_item_selected(faction_id: String) -> void:
	"""势力项目被选中"""
	selected_faction_id = faction_id
	_update_faction_detail()

func _update_faction_detail() -> void:
	"""更新势力详细信息"""
	var faction_mgr = get_node_or_null("/root/FactionSystemManager")
	if not faction_detail or selected_faction_id.is_empty() or not faction_mgr:
		return
	
	# 清空现有内容
	for child in faction_detail.get_children():
		child.queue_free()
	
	var faction_info = faction_mgr.get_faction_info(selected_faction_id)
	
	# 势力名称
	var name_label = Label.new()
	name_label.text = faction_info.get("name", "")
	name_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_LARGE)
	faction_detail.add_child(name_label)

	# v8.5: 激活势力按钮（战斗注入只对激活势力生效，必须让玩家能激活）
	var active_faction: String = faction_mgr.get("active_faction") if "active_faction" in faction_mgr else ""
	var is_this_active: bool = (active_faction == selected_faction_id)
	var active_btn = Button.new()
	if is_this_active:
		active_btn.text = "★ 已激活（战斗加成生效中）"
		active_btn.disabled = true
	else:
		active_btn.text = "☆ 激活此势力（战斗加成切换到此）"
		active_btn.disabled = false
	active_btn.custom_minimum_size = Vector2(0, 32)
	var active_styles := PanelStyles.make_button_styles(DT.COLOR_GREEN_UP if not is_this_active else DT.COLOR_TEXT_DIM)
	active_btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	active_btn.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	active_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	active_btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	active_btn.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))
	active_btn.add_theme_stylebox_override("normal", active_styles["normal"])
	active_btn.add_theme_stylebox_override("hover", active_styles["hover"])
	active_btn.add_theme_stylebox_override("pressed", active_styles["pressed"])
	active_btn.add_theme_stylebox_override("disabled", active_styles["disabled"])
	if not is_this_active:
		active_btn.pressed.connect(_on_activate_faction_pressed.bind(selected_faction_id))
	faction_detail.add_child(active_btn)
	
	# 势力描述
	var desc_label = Label.new()
	desc_label.text = faction_info.get("description", "")
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.custom_minimum_size = Vector2(0, 60)
	faction_detail.add_child(desc_label)
	
	# 势力等级和声望
	var reputation = faction_info.get("reputation", 0)
	var level = faction_info.get("level", 1)
	var level_progress = faction_info.get("level_progress", {})
	
	var level_label = Label.new()
	level_label.text = "等级：%d" % level
	faction_detail.add_child(level_label)
	
	var rep_label = Label.new()
	rep_label.text = "声望：%d" % reputation
	faction_detail.add_child(rep_label)
	
	# 升级进度条
	if level < 10:
		var progress_label = Label.new()
		var progress = level_progress.get("progress", 0.0)
		var current = level_progress.get("current", 0)
		var needed = level_progress.get("needed", 1)
		progress_label.text = "升级进度：%.0f%% (%d/%d)" % [progress * 100, current, needed]
		faction_detail.add_child(progress_label)
		
		var progress_bar = ProgressBar.new()
		progress_bar.value = progress * 100
		progress_bar.custom_minimum_size = Vector2(0, 30)
		faction_detail.add_child(progress_bar)
	else:
		var max_label = Label.new()
		max_label.text = "[color=yellow]已达最高等级[/color]"
		faction_detail.add_child(max_label)
	
	# 控制的关卡数量
	var controlled_levels = faction_info.get("controlled_levels", [])
	var levels_label = Label.new()
	levels_label.text = "控制关卡数：%d" % int(controlled_levels.size())
	faction_detail.add_child(levels_label)
	
	# 显示商店库存预览
	var store_label = Label.new()
	store_label.text = "势力商店库存"
	store_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_BODY)
	store_label.add_theme_color_override("font_color", DT.COLOR_VIOLET)
	faction_detail.add_child(store_label)
	
	var store_inventory = faction_info.get("store_inventory", [])
	if store_inventory.size() > 0:
		var store_preview = Label.new()
		var store_text = ""
		for card_id in store_inventory:
			if not store_text.is_empty():
				store_text += ", "
			var dc = preload("res://data/default_cards.gd")
			var card_data = dc.get_card_by_id(card_id) if dc else null
			var card_name = card_data.display_name if card_data else String(card_id)
			store_text += card_name
		store_preview.text = store_text
		store_preview.autowrap_mode = TextServer.AUTOWRAP_WORD
		store_preview.custom_minimum_size = Vector2(0, 40)
		faction_detail.add_child(store_preview)
	else:
		var empty_label = Label.new()
		empty_label.text = "暂无库存"
		faction_detail.add_child(empty_label)

	# ── v8.5: 势力技能树区块（12 节点，按 tier 分组，A/B 互斥并排）──
	_append_faction_skill_tree(faction_mgr, selected_faction_id, level)

## v8.5: 追加势力技能树区块到详情区
func _append_faction_skill_tree(faction_mgr: Node, faction_id: String, faction_level: int) -> void:
	# 分隔标题
	var skill_title = Label.new()
	skill_title.text = "◆ 势力技能树"
	skill_title.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM)
	skill_title.add_theme_color_override("font_color", DT.COLOR_VIOLET)
	faction_detail.add_child(skill_title)

	# 可用技能点
	var state: Dictionary = faction_mgr.faction_skill_states.get(faction_id, {}) if "faction_skill_states" in faction_mgr else {}
	var unlocked: Array = state.get("unlocked_skills", [])
	var avail: int = FactionSkillManager.get_available_points(state, faction_level)
	var spent: int = FactionSkillManager.get_total_spent(state)
	var points_label = Label.new()
	points_label.text = "可用技能点：%d（已用 %d，势力等级 %d）" % [avail, spent, faction_level]
	points_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	faction_detail.add_child(points_label)

	# 按节点数判断是否放入 ScrollContainer（12 节点 + 分组标题可能超出高度）
	var skills: Array = FactionSkillTree.get_skills_for_faction(faction_id)
	if skills.is_empty():
		var empty_sk = Label.new()
		empty_sk.text = "（该势力无技能定义）"
		empty_sk.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		faction_detail.add_child(empty_sk)
		return

	# 按 tier 分组（tier 顺序：2/3/4/5/7/10）
	var tiers: Array = []
	for s in skills:
		var t: int = int(s.get("tier", 0))
		if not tiers.has(t):
			tiers.append(t)
	tiers.sort()

	for tier in tiers:
		# tier 分组标题
		var tier_label = Label.new()
		tier_label.text = "— 等级 %d 解锁 —" % tier
		tier_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		tier_label.modulate = DT.COLOR_TEXT_DIM
		faction_detail.add_child(tier_label)

		# 该 tier 的节点（A/B 并排）
		var tier_skills: Array = FactionSkillTree.get_skills_at_tier(faction_id, tier)
		var branch_a: Dictionary = {}
		var branch_b: Dictionary = {}
		for s in tier_skills:
			var br: String = String(s.get("branch", "A"))
			if br == "B":
				branch_b = s
			else:
				branch_a = s
		# 并排容器
		var branch_row = HBoxContainer.new()
		branch_row.custom_minimum_size = Vector2(0, 0)
		if not branch_a.is_empty():
			branch_row.add_child(_make_faction_skill_node(branch_a, faction_id, faction_level, unlocked, avail, branch_b.get("id", "")))
		if not branch_b.is_empty():
			branch_row.add_child(_make_faction_skill_node(branch_b, faction_id, faction_level, unlocked, avail, branch_a.get("id", "")))
		faction_detail.add_child(branch_row)

## v8.5: 渲染单个势力技能节点（参考 phase_master_skill_panel 的三态着色范式）
func _make_faction_skill_node(skill: Dictionary, faction_id: String, faction_level: int, unlocked: Array, avail: int, conflict_id: String) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(195, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var skill_id: String = String(skill.get("id", ""))
	var is_unlocked: bool = unlocked.has(skill_id)
	# branch 冲突：另一个分支已解锁 → 本节点不可选
	var is_conflict: bool = not conflict_id.is_empty() and unlocked.has(conflict_id)
	# 解锁校验（用 manager 拿权威结果）
	var faction_mgr = get_node_or_null("/root/FactionSystemManager")
	var can_unlock: bool = false
	if faction_mgr != null and faction_mgr.has_method("can_unlock_faction_skill"):
		can_unlock = bool(faction_mgr.can_unlock_faction_skill(faction_id, skill_id).get("ok", false))

	# 三态着色（StyleBoxFlat）
	var sb = StyleBoxFlat.new()
	if is_unlocked:
		sb.bg_color = Color(DT.COLOR_GREEN_UP.r, DT.COLOR_GREEN_UP.g, DT.COLOR_GREEN_UP.b, 0.12)
		sb.border_color = Color(DT.COLOR_GREEN_UP.r, DT.COLOR_GREEN_UP.g, DT.COLOR_GREEN_UP.b, 0.8)
	elif can_unlock and avail > 0:
		sb.bg_color = Color(DT.COLOR_GOLD.r, DT.COLOR_GOLD.g, DT.COLOR_GOLD.b, 0.10)
		sb.border_color = Color(DT.COLOR_GOLD.r, DT.COLOR_GOLD.g, DT.COLOR_GOLD.b, 0.9)
	else:
		sb.bg_color = DT.COLOR_SLOT_LOCKED
		sb.border_color = Color(DT.COLOR_BORDER_DIM.r, DT.COLOR_BORDER_DIM.g, DT.COLOR_BORDER_DIM.b, 0.9)
	sb.set_border_width_all(1)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	panel.add_theme_stylebox_override("panel", sb)

	var vb = VBoxContainer.new()
	panel.add_child(vb)

	# 节点名称
	var name_lbl = Label.new()
	name_lbl.text = String(skill.get("name", skill_id))
	name_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	vb.add_child(name_lbl)

	# 描述
	var desc_lbl = Label.new()
	desc_lbl.text = String(skill.get("desc", ""))
	desc_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_XSMALL)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(180, 0)
	vb.add_child(desc_lbl)

	# 消耗/状态
	var cost: int = int(skill.get("cost", 1))
	if is_unlocked:
		var ok_lbl = Label.new()
		ok_lbl.text = "✓ 已解锁"
		ok_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		ok_lbl.modulate = DT.COLOR_GREEN_UP
		vb.add_child(ok_lbl)
	elif is_conflict:
		var conflict_lbl = Label.new()
		conflict_lbl.text = "⚠ 已选另一分支"
		conflict_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_XSMALL)
		conflict_lbl.modulate = DT.COLOR_RED_DOWN
		vb.add_child(conflict_lbl)
	else:
		var unlock_btn = Button.new()
		unlock_btn.text = "解锁 (%d点)" % cost
		unlock_btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		unlock_btn.custom_minimum_size = Vector2(0, 26)
		var unlock_styles := PanelStyles.make_button_styles(DT.COLOR_GOLD)
		unlock_btn.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
		unlock_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
		unlock_btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
		unlock_btn.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))
		unlock_btn.add_theme_stylebox_override("normal", unlock_styles["normal"])
		unlock_btn.add_theme_stylebox_override("hover", unlock_styles["hover"])
		unlock_btn.add_theme_stylebox_override("pressed", unlock_styles["pressed"])
		unlock_btn.add_theme_stylebox_override("disabled", unlock_styles["disabled"])
		unlock_btn.disabled = not can_unlock or avail < cost
		if can_unlock and avail >= cost:
			unlock_btn.pressed.connect(_on_unlock_faction_skill.bind(faction_id, skill_id))
		vb.add_child(unlock_btn)
	return panel

## v8.5: 解锁势力技能按钮回调
func _on_unlock_faction_skill(faction_id: String, skill_id: String) -> void:
	var faction_mgr = get_node_or_null("/root/FactionSystemManager")
	if faction_mgr == null or not faction_mgr.has_method("unlock_faction_skill"):
		return
	var ok: bool = faction_mgr.unlock_faction_skill(faction_id, skill_id)
	if not ok:
		# 解锁失败：查原因并提示
		var reason: String = ""
		if faction_mgr.has_method("can_unlock_faction_skill"):
			reason = String(faction_mgr.can_unlock_faction_skill(faction_id, skill_id).get("reason", ""))
		var tip: String = "解锁失败"
		match reason:
			"level_not_enough": tip = "势力等级不足"
			"not_enough_points": tip = "技能点不足"
			"branch_conflict": tip = "已选同层另一分支"
			"already_unlocked": tip = "已解锁"
		if SignalBus.has_signal("show_toast"):
			SignalBus.show_toast.emit(tip)
	else:
		# 解锁成功：刷新面板（_on_faction_skill_changed 会处理，这里即时刷新避免延迟）
		_update_faction_detail()

## v8.5: 激活势力按钮回调
func _on_activate_faction_pressed(faction_id: String) -> void:
	var faction_mgr = get_node_or_null("/root/FactionSystemManager")
	if faction_mgr == null or not faction_mgr.has_method("set_active_faction"):
		return
	faction_mgr.set_active_faction(faction_id)
	# 刷新面板（_on_active_faction_changed 会处理，这里即时刷新）
	_update_faction_detail()

func _on_faction_reputation_changed(faction_id: String, delta: int, new_value: int) -> void:
	"""势力声望变化回调"""
	# v9 perf：面板隐藏时置脏跳过（每过关最多 7 势力反应触发详情区重建）；
	# 重新显示时 _on_visibility_refresh 补刷
	if not is_visible_in_tree():
		_detail_dirty = true
		return
	if faction_id == selected_faction_id:
		_update_faction_detail()

	# 更新列表中的等级显示
	_update_faction_list_display(faction_id)

func _on_faction_level_up(faction_id: String, new_level: int) -> void:
	"""势力升级回调"""
	if not is_visible_in_tree():
		_detail_dirty = true
		return
	if faction_id == selected_faction_id:
		_update_faction_detail()

	_update_faction_list_display(faction_id)

func _on_faction_store_updated(faction_id: String) -> void:
	"""势力商店更新回调"""
	if not is_visible_in_tree():
		_detail_dirty = true
		return
	if faction_id == selected_faction_id:
		_update_faction_detail()

func _update_faction_list_display(faction_id: String) -> void:
	"""更新列表中的势力显示"""
	var faction_mgr = get_node_or_null("/root/FactionSystemManager")
	if not faction_mgr:
		return

	for item in faction_items:
		if item["id"] == faction_id:
			var faction_info = faction_mgr.get_faction_info(faction_id)
			var faction_name = faction_info.get("name", "")
			var level = faction_info.get("level", 1)
			item["button"].text = "%s (Lv.%d)" % [faction_name, level]

## v9 perf：重新显示时补刷隐藏期间积累的势力变化（详情区 + 全部列表行）
func _on_visibility_refresh() -> void:
	if not is_visible_in_tree() or not _detail_dirty:
		return
	_detail_dirty = false
	if not selected_faction_id.is_empty():
		_update_faction_detail()
	for item in faction_items:
		_update_faction_list_display(String(item.get("id", "")))

func _on_close() -> void:
	closed.emit()
