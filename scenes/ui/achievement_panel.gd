extends PanelContainer
## 成就界面：显示和追踪玩家的成就进度
## 增强版本：支持扩展成就定义、奖励领取、统计信息等功能

signal closed
signal achievement_clicked(achievement_id: String)
signal reward_claimed(achievement_id: String)

const AchievementDefs = preload("res://data/achievement_definitions.gd")
const AchievementDefsExtended = preload("res://data/achievement_definitions_extended.gd")
const DT = preload("res://resources/design_tokens.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")
const PanelChrome = preload("res://scenes/ui/components/panel_chrome.gd")

# UI组件引用
@onready var category_tabs: TabContainer = $Margin/VBox/Body/CategoryTabs
# 注：路径解析到的是 ScrollContainer 下的同名 VBoxContainer 子节点（用于 add_child 排列成就条目）
@onready var achievement_list: VBoxContainer = $Margin/VBox/Body/AchievementList/AchievementList
@onready var summary_panel: Control = $Margin/VBox/SummaryPanel
@onready var total_label: Label = $Margin/VBox/SummaryPanel/TotalLabel
@onready var unlocked_label: Label = $Margin/VBox/SummaryPanel/UnlockedLabel
@onready var progress_bar: ProgressBar = $Margin/VBox/SummaryPanel/ProgressBar
@onready var claimable_label: Label = $Margin/VBox/SummaryPanel/ClaimableLabel
@onready var claim_all_button: Button = $Margin/VBox/SummaryPanel/ClaimAllButton

var _current_category: String = "all"
var achievement_manager: Node
var use_extended_definitions: bool = false
# v27.12 性能：面板不可见期间的刷新请求只置脏不重建（面板常驻，战斗中成就进度信号高频），
# 恢复可见时由 _on_visibility_refresh 统一补刷
var _refresh_dirty: bool = false
# v27.15（TODO#5 用户裁决 E1）：成就服务区块——最近解锁 + 即将完成推荐
#（数据 API 原已齐：get_recent_achievements/get_recommended_achievements，此前无展示位）
var _service_block: VBoxContainer = null
var _recent_content: HBoxContainer = null
var _reco_content: HBoxContainer = null

func _ready() -> void:
	# v7.x 性能：AchievementManager 延迟加载，面板打开时确保实例化（否则信号连不上）
	var _mll: Node = get_node_or_null("/root/ManagerLazyLoader")
	if _mll and _mll.has_method("ensure_loaded"):
		_mll.ensure_loaded("achievement")
	achievement_manager = get_node_or_null("/root/AchievementManager")
	# v27.15 修复：ManagerLazyLoader 启动期 root 未就绪时走 call_deferred 挂载——
	# 紧跟的 get_node_or_null 拿到 null 且此前永不重试，面板首次打开成空壳。
	# 等一帧让延迟挂载落地后重取；refresh() 内另有自愈兜底。
	if achievement_manager == null:
		await get_tree().process_frame
		achievement_manager = get_node_or_null("/root/AchievementManager")

	# 检查是否使用扩展成就定义（AchievementDefsExtended 是 preload 脚本对象）
	use_extended_definitions = AchievementDefsExtended != null

	# v7.x 面板统一：SMALL 档 + 金色签名框架 + PanelChrome 标题栏（右上 ✕ 关闭）
	custom_minimum_size = DT.PANEL_SIZE_SMALL
	var accent := DT.get_panel_accent("achievement")
	add_theme_stylebox_override("panel", PanelStyles.make_panel_frame_textured(accent))
	var chrome = PanelChrome.attach_to($Margin/VBox, "战功簿", accent, "功勋档案")
	chrome.closed.connect(_on_close)

	if claim_all_button != null:
		var claim_all_styles := PanelStyles.make_button_styles(accent)
		claim_all_button.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
		claim_all_button.add_theme_color_override("font_hover_color", DT.COLOR_HOVER_WHITE)
		claim_all_button.add_theme_color_override("font_pressed_color", DT.COLOR_HOVER_WHITE)
		claim_all_button.add_theme_color_override("font_focus_color", DT.COLOR_HOVER_WHITE)
		claim_all_button.add_theme_stylebox_override("normal", claim_all_styles["normal"])
		claim_all_button.add_theme_stylebox_override("hover", claim_all_styles["hover"])
		claim_all_button.add_theme_stylebox_override("pressed", claim_all_styles["pressed"])
		claim_all_button.add_theme_stylebox_override("disabled", claim_all_styles["disabled"])
		claim_all_button.pressed.connect(_on_claim_all_rewards)

	_setup_categories()
	_refresh_summary()
	_refresh_achievement_list()

	# 连接成就管理器信号
	if achievement_manager != null:
		if achievement_manager.has_signal("achievement_unlocked"):
			achievement_manager.achievement_unlocked.connect(_on_achievement_unlocked)
		if achievement_manager.has_signal("achievement_progress_updated"):
			achievement_manager.achievement_progress_updated.connect(_on_progress_updated)

	# v27.12 性能：隐藏期间置脏的刷新在恢复可见时统一补刷
	if not visibility_changed.is_connected(_on_visibility_refresh):
		visibility_changed.connect(_on_visibility_refresh)
	# v27.15（E1）：服务区块一次性构建 + 首刷（_ready 不走 refresh()——直调 summary/list，
	# 服务区块若只挂 refresh() 首次打开恒空白，须与 :68-69 两行同批首刷）
	_build_service_block()
	_refresh_service_block()

## v7.x 修复 W6：面板释放时断开 autoload 信号，避免残留死 Callable
func _exit_tree() -> void:
	if achievement_manager == null:
		return
	if achievement_manager.has_signal("achievement_unlocked") and achievement_manager.achievement_unlocked.is_connected(_on_achievement_unlocked):
		achievement_manager.achievement_unlocked.disconnect(_on_achievement_unlocked)
	if achievement_manager.has_signal("achievement_progress_updated") and achievement_manager.achievement_progress_updated.is_connected(_on_progress_updated):
		achievement_manager.achievement_progress_updated.disconnect(_on_progress_updated)

func refresh() -> void:
	# v27.15 自愈：启动期延迟挂载竞态下 _ready 可能没拿到 manager，每次刷新先补取
	if achievement_manager == null:
		achievement_manager = get_node_or_null("/root/AchievementManager")
	# v27.12 性能：面板不可见时只置脏不重建（成就解锁/进度信号战斗中高频触发），恢复可见时补刷
	if not is_visible_in_tree():
		_refresh_dirty = true
		return
	_refresh_dirty = false
	_refresh_summary()
	_refresh_service_block()
	_refresh_achievement_list()


## v27.12 性能：恢复可见时补刷隐藏期间置脏的摘要 + 成就列表
func _on_visibility_refresh() -> void:
	if is_visible_in_tree() and _refresh_dirty:
		refresh()

## v27.15（E1）：构建服务区块（一次性）——插在 SummaryPanel 与 Body 之间，
## 内容行随 refresh() 重建（remove_child + free，非 queue_free——避免同帧新旧共存撑高布局）
func _build_service_block() -> void:
	var vbox: VBoxContainer = get_node_or_null("Margin/VBox")
	var body: Control = get_node_or_null("Margin/VBox/Body")
	if vbox == null or body == null:
		return
	_service_block = VBoxContainer.new()
	_service_block.add_theme_constant_override("separation", 2)
	vbox.add_child(_service_block)
	vbox.move_child(_service_block, body.get_index())
	var accent := DT.get_panel_accent("achievement")
	_service_block.add_child(_make_service_title("◆ 最近解锁", accent))
	_recent_content = HBoxContainer.new()
	_recent_content.add_theme_constant_override("separation", 10)
	_service_block.add_child(_recent_content)
	_service_block.add_child(_make_service_title("◆ 即将完成", accent))
	_reco_content = HBoxContainer.new()
	_reco_content.add_theme_constant_override("separation", 10)
	_service_block.add_child(_reco_content)

func _make_service_title(text: String, accent: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	lbl.add_theme_color_override("font_color", accent)
	return lbl

## v27.15（E1）：刷新服务区块——最近解锁 5 条（金名）+ 即将完成 3 条（≥50% 进度）
func _refresh_service_block() -> void:
	if _service_block == null or achievement_manager == null:
		return
	if not achievement_manager.has_method("get_recent_achievements"):
		return
	_clear_service_row(_recent_content)
	var recent: Array = achievement_manager.get_recent_achievements(5)
	if recent.is_empty():
		_add_service_chip(_recent_content, "暂无解锁记录——先去打一场战斗", false)
	else:
		for ach in recent:
			_add_service_chip(_recent_content, String(ach.get("name", ach.get("id", "?"))), true, String(ach.get("description", "")))
	_clear_service_row(_reco_content)
	var recos: Array = achievement_manager.get_recommended_achievements(3)
	if recos.is_empty():
		_add_service_chip(_reco_content, "暂无接近完成的成就", false)
	else:
		for ach in recos:
			var pct := 0
			if achievement_manager.has_method("get_achievement_progress"):
				pct = int(achievement_manager.get_achievement_progress(String(ach.get("id", ""))).get("percentage", 0))
			_add_service_chip(_reco_content, "%s %d%%" % [String(ach.get("name", "?")), pct], true, String(ach.get("description", "")))

func _clear_service_row(row: HBoxContainer) -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.free()

func _add_service_chip(row: HBoxContainer, text: String, lit: bool, tip: String = "") -> void:
	var chip := Label.new()
	chip.text = text
	chip.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	chip.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45) if lit else Color(0.5, 0.55, 0.65, 0.8))
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	if not tip.is_empty():
		chip.tooltip_text = tip
	row.add_child(chip)

## 设置分类标签页
func _setup_categories() -> void:
	if not category_tabs:
		return

	# 清空现有标签
	for i in range(category_tabs.get_tab_count()):
		category_tabs.set_tab_title(i, "")

	# 添加基础分类
	category_tabs.set_tab_title(0, "全部")
	category_tabs.set_tab_title(1, "战斗")
	category_tabs.set_tab_title(2, "收集")
	category_tabs.set_tab_title(3, "进度")

	# 如果使用扩展定义，添加更多分类
	if use_extended_definitions:
		var tab_count = category_tabs.get_tab_count()
		if tab_count > 4:
			category_tabs.set_tab_title(4, "挑战")
		if tab_count > 5:
			category_tabs.set_tab_title(5, "系统")
		if tab_count > 6:
			category_tabs.set_tab_title(6, "特殊")

	if category_tabs.has_signal("tab_changed"):
		if not category_tabs.tab_changed.is_connected(_on_category_changed):
			category_tabs.tab_changed.connect(_on_category_changed)

## 刷新摘要信息
func _refresh_summary() -> void:
	if achievement_manager == null or summary_panel == null:
		return

	var statistics = achievement_manager.get_achievement_statistics() if achievement_manager.has_method("get_achievement_statistics") else {}
	var progress = achievement_manager.get_unlock_progress() if achievement_manager.has_method("get_unlock_progress") else {}

	if total_label != null:
		total_label.text = "总成就数: %d" % progress.get("total", 0)

	if unlocked_label != null:
		unlocked_label.text = "已解锁: %d" % progress.get("unlocked", 0)

	if progress_bar != null:
		var percentage = progress.get("percentage", 0.0)
		progress_bar.value = percentage
		progress_bar.tooltip_text = "完成度: %.1f%%" % percentage

	var claimable_count = 0
	if achievement_manager.has_method("get_claimable_rewards"):
		var claimable = achievement_manager.get_claimable_rewards()
		claimable_count = claimable.size()

	if claimable_label != null:
		claimable_label.text = "可领取奖励: %d" % claimable_count

	if claim_all_button != null:
		claim_all_button.disabled = claimable_count == 0

## 刷新成就列表
func _refresh_achievement_list() -> void:
	if not achievement_list:
		return

	# 清空现有内容
	for child in achievement_list.get_children():
		child.queue_free()

	var achievements = _get_filtered_achievements()

	for achievement_data in achievements:
		var achievement_item = _create_achievement_item(achievement_data)
		achievement_list.add_child(achievement_item)

## 获取过滤后的成就列表
func _get_filtered_achievements() -> Array:
	var all_achievements = []

	# 优先使用扩展成就定义
	if use_extended_definitions:
		all_achievements = AchievementDefsExtended.get_all_achievements()
	else:
		all_achievements = AchievementDefs.get_all_achievements()

	# 如果使用成就管理器，从管理器获取
	if achievement_manager != null and achievement_manager.has_method("get_all_achievements"):
		all_achievements = achievement_manager.get_all_achievements()

	if _current_category == "all":
		return all_achievements

	var filtered: Array = []
	for achievement in all_achievements:
		if achievement.get("category", "") == _current_category:
			filtered.append(achievement)

	return filtered

## 创建成就项目
func _create_achievement_item(data: Dictionary) -> Control:
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(0, 80)
	container.add_theme_constant_override("separation", 4)

	var achievement_id = data.get("id", "")
	var is_unlocked = _is_achievement_unlocked(achievement_id)

	# 成就标题行
	var header_row = HBoxContainer.new()

	# 图标
	var icon_label = Label.new()
	icon_label.text = data.get("icon", "🏆")
	icon_label.custom_minimum_size = Vector2(40, 0)
	icon_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_LARGE)
	header_row.add_child(icon_label)

	# 名称和状态
	var name_box = VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label = Label.new()
	name_label.text = data.get("name", "未知成就")
	name_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_BODY)
	name_label.add_theme_color_override("font_color", DT.COLOR_GOLD)
	name_box.add_child(name_label)

	var status_label = Label.new()
	if is_unlocked:
		status_label.text = "✓ 已解锁"
		status_label.add_theme_color_override("font_color", DT.COLOR_GREEN_BRIGHT)
	else:
		# 显示进度信息
		var progress_info = _get_achievement_progress_info(achievement_id)
		if not progress_info.is_empty():
			var current = progress_info.get("current", 0)
			var max_val = progress_info.get("max", 0)
			status_label.text = "进度: %d/%d" % [current, max_val]
		else:
			status_label.text = "○ 未解锁"
		status_label.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	name_box.add_child(status_label)

	header_row.add_child(name_box)

	# 添加奖励领取按钮（如果成就已解锁且有奖励）
	if is_unlocked and _has_claimable_reward(achievement_id):
		var claim_button = Button.new()
		claim_button.text = "领取奖励"
		claim_button.custom_minimum_size = Vector2(80, 30)
		var claim_styles := PanelStyles.make_button_styles(DT.COLOR_GOLD, "solid")
		claim_button.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		claim_button.add_theme_color_override("font_color", DT.COLOR_VOID)
		claim_button.add_theme_color_override("font_hover_color", DT.COLOR_VOID)
		claim_button.add_theme_color_override("font_pressed_color", DT.COLOR_VOID)
		claim_button.add_theme_color_override("font_focus_color", DT.COLOR_VOID)
		claim_button.add_theme_stylebox_override("normal", claim_styles["normal"])
		claim_button.add_theme_stylebox_override("hover", claim_styles["hover"])
		claim_button.add_theme_stylebox_override("pressed", claim_styles["pressed"])
		claim_button.pressed.connect(_on_achievement_claim.bind(achievement_id))
		header_row.add_child(claim_button)

	container.add_child(header_row)

	# 描述（v23.6.1：中文描述 10px→12px，10px 档仅限纯数字/英文）
	var desc_label = Label.new()
	desc_label.text = data.get("description", "")
	desc_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	desc_label.add_theme_color_override("font_color", DT.COLOR_TEXT_MID)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	container.add_child(desc_label)

	# 风味文本
	var flavor_text = data.get("flavor_text", "")
	if not flavor_text.is_empty():
		var flavor_label = Label.new()
		flavor_label.text = "\"%s\"" % flavor_text
		flavor_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		flavor_label.add_theme_color_override("font_color", DT.COLOR_TEXT_FAINT)
		flavor_label.add_theme_stylebox_override("normal", StyleBoxFlat.new())
		flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		container.add_child(flavor_label)

	# 奖励信息
	var rewards = data.get("reward", {})
	if not rewards.is_empty():
		var reward_label = Label.new()
		var reward_text = _format_rewards(rewards)
		reward_label.text = "奖励：%s" % reward_text
		reward_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		reward_label.add_theme_color_override("font_color", DT.COLOR_RARITY_RARE)
		container.add_child(reward_label)

	# 分隔线
	var separator = HSeparator.new()
	separator.add_theme_constant_override("separation", 8)
	container.add_child(separator)

	return container

## 获取成就进度信息
func _get_achievement_progress_info(achievement_id: String) -> Dictionary:
	if achievement_manager != null and achievement_manager.has_method("get_achievement_progress"):
		return achievement_manager.get_achievement_progress(achievement_id)
	return {}

## 检查是否有可领取奖励
func _has_claimable_reward(achievement_id: String) -> bool:
	if achievement_manager == null:
		return false

	if not achievement_manager.has_method("get_achievement_progress"):
		return false

	var progress = achievement_manager.get_achievement_progress(achievement_id)
	if not progress.get("unlocked", false):
		return false

	return not progress.get("reward_claimed", false)

## 领取成就奖励
func _on_achievement_claim(achievement_id: String) -> void:
	if achievement_manager != null and achievement_manager.has_method("claim_achievement_reward"):
		if achievement_manager.claim_achievement_reward(achievement_id):
			reward_claimed.emit(achievement_id)
			refresh()  # 刷新显示

## 领取所有奖励
func _on_claim_all_rewards() -> void:
	if achievement_manager == null:
		return

	var claimable = []
	if achievement_manager.has_method("get_claimable_rewards"):
		claimable = achievement_manager.get_claimable_rewards()

	var claimed_count = 0
	for ach_id in claimable:
		if achievement_manager.has_method("claim_achievement_reward"):
			if achievement_manager.claim_achievement_reward(ach_id):
				claimed_count += 1
				reward_claimed.emit(ach_id)

	if claimed_count > 0:
		refresh()

## 成就解锁处理
func _on_achievement_unlocked(achievement_id: String, achievement_name: String) -> void:
	refresh()

## 进度更新处理
func _on_progress_updated(achievement_id: String, current: int, max_val: int) -> void:
	# 如果当前显示的成就进度更新，刷新显示
	refresh()

## 检查成就是否已解锁
func _is_achievement_unlocked(achievement_id: String) -> bool:
	var achievement_mgr = get_node_or_null("/root/AchievementManager")
	if achievement_mgr != null and achievement_mgr.has_method("is_achievement_unlocked"):
		return achievement_mgr.is_achievement_unlocked(achievement_id)
	return false

## 格式化奖励信息
func _format_rewards(rewards: Dictionary) -> String:
	var parts: Array = []

	if rewards.has("nano_materials"):
		parts.append("%d纳米材料" % rewards["nano_materials"])
	# DEPRECATED (P0-3c): blueprint_fragments reward display disabled — reward schema migrated away from fragment-based model
	#if rewards.has("blueprint_fragments"):
	#	var fragments = rewards["blueprint_fragments"]
	#	for fragment_id in fragments:
	#		parts.append("%s蓝图x%d" % [fragment_id, fragments[fragment_id]])

	if rewards.has("company_rep"):
		var rep = rewards["company_rep"]
		for company_id in rep:
			parts.append("%s声望+%d" % [company_id, rep[company_id]])

	# 将Array转换为PackedStringArray后使用join
	var parts_array = PackedStringArray(parts)
	return "、".join(parts_array)

## 分类标签改变
func _on_category_changed(tab_index: int) -> void:
	match tab_index:
		0: _current_category = "all"
		1: _current_category = "battle"
		2: _current_category = "collection"
		3: _current_category = "progress"
		4: _current_category = "challenge"  # 仅在扩展定义中
		5: _current_category = "system"     # 仅在扩展定义中
		6: _current_category = "special"    # 仅在扩展定义中
		_: _current_category = "all"

	_refresh_achievement_list()

## 关闭按钮
func _on_close() -> void:
	closed.emit()
	queue_free()
