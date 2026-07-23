extends PanelContainer
## ═══════════════════════════════════════════════════════════
##  相位师技能树面板（v8.x 新增）
##  4 分支：指挥 / 智能化 / 火力 / 概念武器
##  每分支按 tier 纵向排列节点，点击解锁（消耗技能点）
##  技能点来源：相位场 XP 升级
## ═══════════════════════════════════════════════════════════

const SkillTree = preload("res://data/phase_master_skill_tree.gd")

signal closed()

var _tab_container: TabContainer = null
var _points_label: Label = null
var _close_btn: Button = null
var _branch_containers: Dictionary = {}  # branch -> ScrollContainer
var _dirty: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(960, 640)
	# 居中定位（挂在 CanvasLayer 下时需显式设置，PRESET_CENTER 对 PanelContainer 不可靠）
	anchors_preset = Control.PRESET_CENTER
	size = Vector2(960, 640)
	_build_ui()
	# 监听解锁/点数变化信号
	if PhaseMasterSkillManager:
		if not PhaseMasterSkillManager.node_unlocked.is_connected(_on_node_unlocked):
			PhaseMasterSkillManager.node_unlocked.connect(_on_node_unlocked)
		if not PhaseMasterSkillManager.points_changed.is_connected(_on_points_changed):
			PhaseMasterSkillManager.points_changed.connect(_on_points_changed)
	_refresh()

## 构建完整 UI（代码驱动，避免 tscn 节点路径问题）
func _build_ui() -> void:
	var main_vb := VBoxContainer.new()
	main_vb.name = "MainVBox"
	add_child(main_vb)

	# 顶部栏：标题 + 技能点 + 关闭
	var top_bar := HBoxContainer.new()
	top_bar.name = "TopBar"
	main_vb.add_child(top_bar)

	var title := Label.new()
	title.text = "◆ 相位师技能树"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.75, 0.30))
	top_bar.add_child(title)

	_points_label = Label.new()
	_points_label.name = "PointsLabel"
	_points_label.add_theme_font_size_override("font_size", 18)
	_points_label.add_theme_color_override("font_color", Color(0.40, 1.0, 0.50))
	top_bar.add_child(_points_label)
	top_bar.add_child(_make_spacer(true))

	_close_btn = Button.new()
	_close_btn.name = "CloseBtn"
	_close_btn.text = "✕ 关闭"
	_close_btn.pressed.connect(_on_close_pressed)
	top_bar.add_child(_close_btn)

	# Tab 容器：4 分支
	_tab_container = TabContainer.new()
	_tab_container.name = "BranchTabs"
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vb.add_child(_tab_container)

	for branch in SkillTree.get_all_branches():
		var scroll := ScrollContainer.new()
		scroll.name = "Scroll_%s" % branch
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var tab_label: String = SkillTree.get_branch_display_name(branch)
		_tab_container.add_child(scroll)
		scroll.name = tab_label  # Tab 标题
		_branch_containers[branch] = scroll
		_populate_branch(branch, scroll)

## 填充单个分支的节点
func _populate_branch(branch: String, scroll: ScrollContainer) -> void:
	# 清空旧内容
	for child in scroll.get_children():
		child.queue_free()

	var branch_color: Color = SkillTree.get_branch_color(branch)
	var vb := VBoxContainer.new()
	vb.name = "BranchVBox"
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	scroll.add_child(vb)

	# 分支标题
	var header := Label.new()
	header.text = "▎ %s 分支" % SkillTree.get_branch_display_name(branch)
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", branch_color)
	vb.add_child(header)

	# 按 tier 分组节点
	var skills: Array = SkillTree.get_skills_for_branch(branch)
	skills.sort_custom(func(a, b): return int(a.get("tier", 0)) < int(b.get("tier", 0)))

	var current_tier: int = -1
	for skill in skills:
		var tier: int = int(skill.get("tier", 0))
		if tier != current_tier:
			current_tier = tier
			var tier_label := Label.new()
			tier_label.text = "  — 第 %d 层 —" % tier
			tier_label.add_theme_color_override("font_color", Color(0.55, 0.57, 0.62))
			vb.add_child(tier_label)

		vb.add_child(_make_node_row(skill, branch_color))

## 单个技能节点行
func _make_node_row(skill: Dictionary, branch_color: Color) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(880, 0)

	var sb := StyleBoxFlat.new()
	var node_id: String = skill.get("id", "")
	var is_unlocked: bool = PhaseMasterSkillManager and PhaseMasterSkillManager.is_unlocked(node_id)
	var can_unlock: bool = PhaseMasterSkillManager and PhaseMasterSkillManager.can_unlock_node(node_id).get("ok", false)

	if is_unlocked:
		sb.bg_color = Color(0.08, 0.18, 0.10, 0.95)
		sb.border_color = branch_color
	elif can_unlock:
		sb.bg_color = Color(0.12, 0.14, 0.20, 0.95)
		sb.border_color = Color(0.95, 0.75, 0.30)
	else:
		sb.bg_color = Color(0.06, 0.07, 0.10, 0.95)
		sb.border_color = Color(0.30, 0.32, 0.36)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(hb)

	# 左：名称 + 描述
	var info_vb := VBoxContainer.new()
	info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(info_vb)

	var name_label := Label.new()
	name_label.text = skill.get("name", "")
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", branch_color if is_unlocked else Color(0.85, 0.87, 0.90))
	info_vb.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = skill.get("desc", "")
	desc_label.add_theme_color_override("font_color", Color(0.62, 0.64, 0.68))
	desc_label.add_theme_font_size_override("font_size", 13)
	info_vb.add_child(desc_label)

	# 解锁内容提示
	var unlocks: Array = skill.get("unlocks", [])
	if not unlocks.is_empty():
		var unlock_text := _format_unlocks(unlocks)
		if not unlock_text.is_empty():
			var unlock_label := Label.new()
			unlock_label.text = "解锁：" + unlock_text
			unlock_label.add_theme_color_override("font_color", Color(0.65, 0.55, 0.95))
			unlock_label.add_theme_font_size_override("font_size", 12)
			info_vb.add_child(unlock_label)

	# 前置提示
	var requires: Array = skill.get("requires", [])
	if not requires.is_empty() and not is_unlocked:
		var req_met: bool = true
		for req in requires:
			if not (PhaseMasterSkillManager and PhaseMasterSkillManager.is_unlocked(req)):
				req_met = false
				break
		if not req_met:
			var req_label := Label.new()
			req_label.text = "⚠ 需先解锁前置节点"
			req_label.add_theme_color_override("font_color", Color(0.90, 0.45, 0.35))
			req_label.add_theme_font_size_override("font_size", 12)
			info_vb.add_child(req_label)

	# 右：状态/按钮
	if is_unlocked:
		var done_label := Label.new()
		done_label.text = "✓ 已解锁"
		done_label.add_theme_color_override("font_color", Color(0.40, 1.0, 0.50))
		done_label.add_theme_font_size_override("font_size", 15)
		hb.add_child(done_label)
	else:
		var btn := Button.new()
		btn.text = "解锁 (%d点)" % int(skill.get("cost", 1))
		btn.disabled = not can_unlock
		btn.set_meta("node_id", node_id)
		btn.pressed.connect(_on_unlock_pressed.bind(node_id))
		hb.add_child(btn)

	return panel

## 格式化解锁内容为简短文字
func _format_unlocks(unlocks: Array) -> String:
	var parts: Array = []
	for u in unlocks:
		if not (u is Dictionary):
			continue
		var u_type: String = u.get("type", "")
		var u_id: String = str(u.get("id", u.get("era", "")))
		match u_type:
			"phase_instrument": parts.append("相位仪[%s]" % u_id)
			"unit_ability": parts.append("兵种能力[%s]" % u_id)
			"unit_mechanism": parts.append("兵种机制[%s]" % u_id)
			"concept_weapon": parts.append("概念武器[%s]" % u_id)
			"special_card": parts.append("特殊卡[%s]" % u_id)
			"evolution":
				var era: int = int(u.get("era", 0))
				parts.append("进化解锁[时代%d]" % era if era >= 0 else "进化解锁[全时代]")
			"affix": parts.append("词条赋予")
	return "、".join(parts)

func _make_spacer(expand: bool) -> Control:
	var c := Control.new()
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

# ─────────────────────────────────────────────
#  交互
# ─────────────────────────────────────────────

func _on_unlock_pressed(node_id: String) -> void:
	if PhaseMasterSkillManager == null:
		return
	var ok: bool = PhaseMasterSkillManager.unlock_node(node_id)
	if not ok:
		# 解锁失败提示（可接 toast）
		var can: Dictionary = PhaseMasterSkillManager.can_unlock_node(node_id)
		var reason: String = can.get("reason", "")
		if reason == "not_enough_points":
			_show_temp_msg("技能点不足")
		elif reason == "requires_not_met":
			_show_temp_msg("需先解锁前置节点")
	_refresh()

func _on_close_pressed() -> void:
	hide_panel()

func hide_panel() -> void:
	visible = false
	closed.emit()

func _on_node_unlocked(_node_id: String) -> void:
	_refresh()

func _on_points_changed(_available: int) -> void:
	_refresh()

func _refresh() -> void:
	if not visible:
		_dirty = true
		return
	_dirty = false
	# 更新技能点显示
	if _points_label and PhaseMasterSkillManager:
		var avail: int = PhaseMasterSkillManager.get_available_points()
		var spent: int = PhaseMasterSkillManager.get_spent_points()
		_points_label.text = "  可用技能点：%d（已用 %d）" % [avail, spent]
	# 重建各分支（节点状态变化需重绘）
	for branch in _branch_containers.keys():
		_populate_branch(branch, _branch_containers[branch])

func _show_temp_msg(msg: String) -> void:
	# 简易提示：复用标题区临时显示（完整 toast 接 ToastManager）
	if _points_label:
		var orig: String = _points_label.text
		_points_label.text = "  ⚠ %s" % msg
		await get_tree().create_timer(1.2).timeout
		if is_instance_valid(_points_label):
			_points_label.text = orig

func _on_visibility_changed() -> void:
	if visible and _dirty:
		_refresh()
