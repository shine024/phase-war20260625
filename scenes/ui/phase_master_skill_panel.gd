extends PanelContainer
## ═══════════════════════════════════════════════════════════
##  相位师技能树面板（v8.x 新增，v9 重设计）
##  3 分支：指挥 / 智能化 / 火力
##  每分支按 tier 纵向排列节点，点击解锁（消耗技能点）
##  技能点来源：相位场 XP 升级
##  v9 奇点节点（原概念武器内容，capstone: true）：沉入三系深层，
##  紫色 ◈ 徽标 + 加粗边框统一识别；「奇点解算」为三系共通门关
## ═══════════════════════════════════════════════════════════

const SkillTree = preload("res://data/phase_master_skill_tree.gd")
const UnlockLabels = preload("res://data/unlock_labels.gd")
const DT = preload("res://resources/design_tokens.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")
const PanelChrome = preload("res://scenes/ui/components/panel_chrome.gd")

signal closed()

var _tab_container: TabContainer = null
var _points_label: Label = null
var _branch_containers: Dictionary = {}  # branch -> ScrollContainer
var _summary_container: ScrollContainer = null  # v8.x 已解锁总览 tab
var _dirty: bool = false
# ── v9 perf: 刷新链路四项优化（打开慢/解锁卡顿根因） ──
# 1) 去抖：解锁一个节点会触发 node_unlocked + points_changed 两信号 + 按钮回调，
#    原实现同帧 3 次全量重建（71 行 × 3 销毁重造）；合并为帧末 1 次
var _refresh_queued: bool = false
# 2) 状态签名：解锁集合 + 可用点数没变则跳过重建（打开面板零成本，首开不再双重构建）
var _rendered_sig: String = ""
# 3) 懒填充：只构建访问过的 tab，切 tab 时按需构建（首开 71+总览行 → 仅当前分支 24 行）
var _tab_branches: Array = []              # tab 索引 -> branch
var _populated_branches: Dictionary = {}   # branch -> true（已构建过的分支 tab）
var _summary_populated: bool = false

func _ready() -> void:
	# v7.x 面板统一：MEDIUM 档 + 金色签名框架
	custom_minimum_size = DT.PANEL_SIZE_MEDIUM
	# 居中定位（挂在 CanvasLayer 下时需显式设置，PRESET_CENTER 对 PanelContainer 不可靠）
	anchors_preset = Control.PRESET_CENTER
	size = DT.PANEL_SIZE_MEDIUM
	add_theme_stylebox_override("panel", PanelStyles.make_panel_frame(DT.get_panel_accent("phase_master_skill")))
	_build_ui()
	# 监听解锁/点数变化信号
	if PhaseMasterSkillManager:
		if not PhaseMasterSkillManager.node_unlocked.is_connected(_on_node_unlocked):
			PhaseMasterSkillManager.node_unlocked.connect(_on_node_unlocked)
		if not PhaseMasterSkillManager.points_changed.is_connected(_on_points_changed):
			PhaseMasterSkillManager.points_changed.connect(_on_points_changed)
	# v9: 接通 visibility_changed（原 _on_visibility_changed 定义了但从未连接，属死代码；
	# 接通后隐藏期间积累的 _dirty 在重新显示时补刷，有状态签名兜底，重复刷新零成本）
	visibility_changed.connect(_on_visibility_changed)
	_refresh()

## 构建完整 UI（代码驱动，避免 tscn 节点路径问题）
func _build_ui() -> void:
	var main_vb := VBoxContainer.new()
	main_vb.name = "MainVBox"
	add_child(main_vb)

	# v7.x 面板统一：PanelChrome 标题栏（右上 ✕ 关闭），技能点挂 chrome 状态行
	var chrome = PanelChrome.attach_to(main_vb, "相位师技能树", DT.get_panel_accent("phase_master_skill"), "SKILL TREE")
	chrome.closed.connect(_on_close_pressed)
	_points_label = chrome.add_status_line()

	# Tab 容器：3 分支（v9：概念武器分支解散，奇点节点沉入三系深层）
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
		_tab_branches.append(branch)
		# v9 perf: 此处不填充内容——懒填充，切到该 tab 时才构建（见 _on_tab_changed）

	# v8.x: 第 5 个 tab ——「已解锁总览」（同样懒填充）
	var summary_scroll := ScrollContainer.new()
	summary_scroll.name = "Scroll_Summary"
	summary_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_child(summary_scroll)
	summary_scroll.name = "📋 总览"
	_summary_container = summary_scroll

	# v9 perf: tab 切换监听（懒填充未访问过的 tab）
	_tab_container.tab_changed.connect(_on_tab_changed)
	# v9 perf: 首开只构建当前 tab（第一个分支），其余切到时再建
	if not _tab_branches.is_empty():
		var first_branch: String = String(_tab_branches[0])
		_populate_branch(first_branch, _branch_containers[first_branch])
		_populated_branches[first_branch] = true
	# v9 perf: 记录初始渲染签名——growth_panel 打开时的 _refresh() 会被签名比对拦截，
	# 避免首开 _build_ui 全量构建 + _refresh 再全量重建的双倍开销
	_rendered_sig = _current_state_signature()

## 填充单个分支的节点
func _populate_branch(branch: String, scroll: ScrollContainer) -> void:
	# 清空旧内容（v9 perf: 先 remove_child 摘除再 queue_free——queue_free 实际释放延迟到帧末，
	# 若直接排队，同帧多次重建时容器里会堆叠新旧多代节点，VBox 布局成本超线性膨胀）
	for child in scroll.get_children():
		scroll.remove_child(child)
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
			tier_label.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
			vb.add_child(tier_label)

		vb.add_child(_make_node_row(skill, branch_color))

## v8.x: 填充「已解锁总览」tab —— 显示所有已解锁内容的玩家可读列表
func _populate_summary() -> void:
	if _summary_container == null:
		return
	# 清空旧内容
	for child in _summary_container.get_children():
		_summary_container.remove_child(child)  # v9 perf: 先摘除再释放（同 _populate_branch）
		child.queue_free()
	var vb := VBoxContainer.new()
	vb.name = "SummaryVBox"
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)
	_summary_container.add_child(vb)

	if PhaseMasterSkillManager == null:
		var empty_label := Label.new()
		empty_label.text = "（技能管理器未加载）"
		empty_label.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
		vb.add_child(empty_label)
		return

	# 标题
	var header := Label.new()
	var unlocked_nodes: Array = PhaseMasterSkillManager.get("_unlocked_nodes") if PhaseMasterSkillManager.get("_unlocked_nodes") != null else []
	header.text = "▎ 已解锁内容（%d 个节点）" % unlocked_nodes.size()
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", DT.COLOR_GOLD)
	vb.add_child(header)

	# 调用 UnlockLabels 获取已解锁内容摘要
	var summary: Array = UnlockLabels.get_unlocked_summary(unlocked_nodes)
	if summary.is_empty():
		var none_label := Label.new()
		none_label.text = "尚未解锁任何内容。在分支 tab 中点亮节点即可解锁兵种机制/卡片技能/战法。"
		none_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		none_label.add_theme_font_size_override("font_size", 13)
		vb.add_child(none_label)
		return

	# 按类型分组显示
	var by_type: Dictionary = {}  # type -> Array[summary item]
	for item in summary:
		var t: String = String(item.get("type", ""))
		if not by_type.has(t):
			by_type[t] = []
		by_type[t].append(item)

	# 类型标题映射
	var type_titles: Dictionary = {
		"unit_mechanism": "🥷 兵种机制",
		"unit_ability": "⚔ 兵种能力",
		"card_skill": "💥 卡片定时技能",
		"tactic": "🔱 战法",
		"phase_instrument": "🔮 相位仪",
		"affix": "📊 词条系统",
		"evolution": "🧬 进化形态",
		"concept_weapon": "☢ 概念武器",
		"special_card": "🌟 特殊卡",
	}

	for t in by_type.keys():
		var items: Array = by_type[t]
		var type_label := Label.new()
		type_label.text = "— %s（%d）—" % [String(type_titles.get(t, t)), items.size()]
		type_label.add_theme_color_override("font_color", Color(0.65, 0.55, 0.95))
		type_label.add_theme_font_size_override("font_size", 14)
		vb.add_child(type_label)
		for item in items:
			var row := _make_summary_row(item)
			vb.add_child(row)

## 单个技能节点行
func _make_node_row(skill: Dictionary, branch_color: Color) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(880, 0)

	# v9 奇点节点（原概念武器内容）：紫色 ◈ 徽标，覆盖分支配色统一识别
	var is_capstone: bool = bool(skill.get("capstone", false))
	var capstone_color: Color = SkillTree.CAPSTONE_COLOR

	var sb := StyleBoxFlat.new()
	var node_id: String = skill.get("id", "")
	var is_unlocked: bool = PhaseMasterSkillManager and PhaseMasterSkillManager.is_unlocked(node_id)
	var can_unlock: bool = PhaseMasterSkillManager and PhaseMasterSkillManager.can_unlock_node(node_id).get("ok", false)

	if is_unlocked:
		sb.bg_color = Color(DT.COLOR_GREEN_UP.r, DT.COLOR_GREEN_UP.g, DT.COLOR_GREEN_UP.b, 0.12)
		sb.border_color = capstone_color if is_capstone else branch_color
	elif can_unlock:
		sb.bg_color = Color(DT.COLOR_GOLD.r, DT.COLOR_GOLD.g, DT.COLOR_GOLD.b, 0.10)
		sb.border_color = DT.COLOR_GOLD
	else:
		sb.bg_color = DT.COLOR_SLOT_LOCKED
		sb.border_color = Color(DT.COLOR_BORDER_DIM.r, DT.COLOR_BORDER_DIM.g, DT.COLOR_BORDER_DIM.b, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	if is_capstone:
		sb.set_border_width_all(3)
	panel.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(hb)

	# 左：名称 + 描述
	var info_vb := VBoxContainer.new()
	info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(info_vb)

	var name_label := Label.new()
	name_label.text = ("◈ " if is_capstone else "") + skill.get("name", "")
	name_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM + 1 if is_capstone else DT.FONT_SIZE_MEDIUM)
	if is_capstone:
		name_label.add_theme_color_override("font_color", capstone_color)
	else:
		name_label.add_theme_color_override("font_color", branch_color if is_unlocked else DT.COLOR_TEXT_BRIGHT)
	info_vb.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = skill.get("desc", "")
	desc_label.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	desc_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	info_vb.add_child(desc_label)

	# 解锁内容提示
	var unlocks: Array = skill.get("unlocks", [])
	if not unlocks.is_empty():
		var unlock_text := _format_unlocks(unlocks)
		if not unlock_text.is_empty():
			var unlock_label := Label.new()
			unlock_label.text = "解锁：" + unlock_text
			unlock_label.add_theme_color_override("font_color", DT.COLOR_VIOLET)
			unlock_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_XSMALL)
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
			# v9.x 修复：指明缺失的前置节点与所属分支。跨分支前置不可见是"技能加不了却不知
			# 缺什么"的根源——典型：战术核武在火力页全亮，缺的是智能化分支的「奇点解算」门关。
			req_label.text = "⚠ 前置未满足：%s" % _format_missing_requires(requires)
			req_label.add_theme_color_override("font_color", Color(DT.COLOR_RED_DOWN.r, DT.COLOR_RED_DOWN.g, DT.COLOR_RED_DOWN.b, 0.9))
			req_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_XSMALL)
			info_vb.add_child(req_label)

	# 右：状态/按钮
	if is_unlocked:
		var done_label := Label.new()
		done_label.text = "✓ 已解锁"
		done_label.add_theme_color_override("font_color", DT.COLOR_GREEN_BRIGHT)
		done_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_BODY)
		hb.add_child(done_label)
	else:
		var btn := Button.new()
		btn.text = "解锁 (%d点)" % int(skill.get("cost", 1))
		var unlock_styles := PanelStyles.make_button_styles(DT.COLOR_GOLD, "solid")
		btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		btn.add_theme_color_override("font_color", DT.COLOR_VOID)
		btn.add_theme_color_override("font_hover_color", DT.COLOR_VOID)
		btn.add_theme_color_override("font_pressed_color", DT.COLOR_VOID)
		btn.add_theme_color_override("font_focus_color", DT.COLOR_VOID)
		btn.add_theme_stylebox_override("normal", unlock_styles["normal"])
		btn.add_theme_stylebox_override("hover", unlock_styles["hover"])
		btn.add_theme_stylebox_override("pressed", unlock_styles["pressed"])
		btn.add_theme_stylebox_override("disabled", unlock_styles["disabled"])
		btn.disabled = not can_unlock
		btn.set_meta("node_id", node_id)
		btn.pressed.connect(_on_unlock_pressed.bind(node_id))
		hb.add_child(btn)

	return panel

## 格式化解锁内容为玩家可读文字（使用 UnlockLabels 翻译表）
func _format_unlocks(unlocks: Array) -> String:
	var parts: Array = []
	for u in unlocks:
		if not (u is Dictionary):
			continue
		var u_type: String = u.get("type", "")
		var u_id: String = str(u.get("id", u.get("era", "")))
		# 优先查翻译表（unit_mechanism/unit_ability/card_skill/tactic）
		var label: Dictionary = UnlockLabels.get_unlock_label(u_type, u_id)
		if not label.is_empty():
			var icon: String = String(label.get("icon", ""))
			var name: String = String(label.get("name", u_id))
			parts.append("%s %s" % [icon, name] if not icon.is_empty() else name)
		else:
			# 翻译表未覆盖的类型走原逻辑
			match u_type:
				"phase_instrument":
					# 查 PhaseInstruments 取中文名，查不到回退原始 ID
					var PhaseInstrumentsCls = preload("res://data/phase_instruments.gd")
					var inst_cfg: Dictionary = PhaseInstrumentsCls.get_by_id(u_id)
					var inst_name: String = String(inst_cfg.get("name", u_id))
					parts.append("相位仪：%s" % inst_name)
				"concept_weapon": parts.append("概念武器[%s]" % u_id)
				"special_card": parts.append("特殊卡[%s]" % u_id)
				"evolution":
					var era: int = int(u.get("era", 0))
					var era_names: Array = ["一战", "二战", "冷战", "现代", "近未来"]
					var era_label: String = era_names[clampi(era, 0, 4)] if era >= 0 and era < 5 else "全时代"
					parts.append("进化解锁[%s]" % era_label)
				"affix": parts.append("词条赋予")
				_: parts.append("%s[%s]" % [u_type, u_id])
	return "、".join(parts)

## 格式化缺失前置：节点名（所属分支）列表，如「奇点解算（智能化分支）」。
## 跨分支前置（奇点门关等）在当前分支页看不到，必须点名否则玩家无从下手。
func _format_missing_requires(requires: Array) -> String:
	var missing_names: Array = []
	for req in requires:
		if PhaseMasterSkillManager and PhaseMasterSkillManager.is_unlocked(req):
			continue
		var req_node: Dictionary = SkillTree.get_skill(String(req))
		var req_name: String = String(req_node.get("name", String(req)))
		var req_branch: String = SkillTree.get_branch_display_name(SkillTree.get_branch_of(String(req)))
		missing_names.append("%s（%s分支）" % [req_name, req_branch])
	return "、".join(missing_names)

func _make_spacer(expand: bool) -> Control:
	var c := Control.new()
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

## v8.x: 总览 tab 单行（图标 + 名称 + 描述）
func _make_summary_row(item: Dictionary) -> Control:
	var hb := HBoxContainer.new()
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override("separation", 8)
	# 图标
	var icon_label := Label.new()
	icon_label.text = String(item.get("icon", "•"))
	icon_label.add_theme_font_size_override("font_size", 16)
	hb.add_child(icon_label)
	# 名称 + 描述
	var info_vb := VBoxContainer.new()
	info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(info_vb)
	var name_label := Label.new()
	name_label.text = String(item.get("name", ""))
	name_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_BODY)
	name_label.add_theme_color_override("font_color", DT.COLOR_GREEN_BRIGHT)
	info_vb.add_child(name_label)
	var desc: String = String(item.get("desc", ""))
	if not desc.is_empty():
		var desc_label := Label.new()
		desc_label.text = desc
		desc_label.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
		desc_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_XSMALL)
		info_vb.add_child(desc_label)
	return hb

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
			# v9.x 修复：点名缺失前置（can 的 missing 只报第一个，这里列全）
			var missing_str := _format_missing_requires(
				SkillTree.get_skill(node_id).get("requires", []))
			if missing_str.is_empty():
				_show_temp_msg("需先解锁前置节点")
			else:
				_show_temp_msg("需先解锁：%s" % missing_str)
	else:
		# 解锁成功：弹 Toast 通知（含节点名称 + 解锁内容摘要）
		_emit_unlock_toast(node_id)
	# v9 perf: 刷新走去抖入口（node_unlocked/points_changed 信号也会请求，同帧合并为 1 次）
	_request_refresh()

## 解锁成功后发射 Toast 通知
func _emit_unlock_toast(node_id: String) -> void:
	var node: Dictionary = SkillTree.get_skill(node_id)
	if node.is_empty():
		return
	var node_name: String = String(node.get("name", node_id))
	var unlocks: Array = node.get("unlocks", [])
	# 构造 Toast 文案
	var toast_lines: Array = ["✨ 已解锁：%s" % node_name]
	if not unlocks.is_empty():
		var unlock_descs: Array = []
		for u in unlocks:
			if not (u is Dictionary):
				continue
			var u_type: String = u.get("type", "")
			var u_id: String = str(u.get("id", ""))
			var label: Dictionary = UnlockLabels.get_unlock_label(u_type, u_id)
			if not label.is_empty():
				unlock_descs.append(String(label.get("desc", "")))
		if not unlock_descs.is_empty():
			# Toast 只显示第一条描述（避免过长）
			toast_lines.append(String(unlock_descs[0]))
	var toast_msg: String = "\n".join(toast_lines)
	# 发射 SignalBus.show_toast（ToastManager 已连接）
	if SignalBus and SignalBus.has_signal("show_toast"):
		SignalBus.show_toast.emit(toast_msg)

func _on_close_pressed() -> void:
	hide_panel()

func hide_panel() -> void:
	visible = false
	closed.emit()

func _on_node_unlocked(_node_id: String) -> void:
	_request_refresh()

func _on_points_changed(_available: int) -> void:
	_request_refresh()

## v9 perf: 去抖刷新入口。
## 解锁一个节点会依次触发 node_unlocked 信号 → points_changed 信号 → 按钮回调收尾，
## 原实现三个入口各调一次 _refresh() = 同帧 3 次全量重建；统一走本方法后合并为帧末 1 次。
func _request_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_refresh.call_deferred()

## v9 perf: 渲染状态签名 = 已解锁节点集合 + 可用点数。
## 两者唯一决定所有节点行的三态渲染（已解锁/可解锁/锁定）与按钮可用性，
## 签名不变即无需重建（打开面板时状态通常没变 → 零重建成本）。
func _current_state_signature() -> String:
	if PhaseMasterSkillManager == null:
		return "no-mgr"
	return "%s:%d" % [PhaseMasterSkillManager.get_unlocked_signature(),
			PhaseMasterSkillManager.get_available_points()]

func _update_points_label() -> void:
	if _points_label and PhaseMasterSkillManager:
		var avail: int = PhaseMasterSkillManager.get_available_points()
		var spent: int = PhaseMasterSkillManager.get_spent_points()
		_points_label.text = "  可用技能点：%d（已用 %d）" % [avail, spent]

## v9 perf: tab 切换 → 懒填充。未访问过的 tab 不预建，切到时才构建（构建即最新状态）。
func _on_tab_changed(tab_idx: int) -> void:
	if tab_idx >= 0 and tab_idx < _tab_branches.size():
		var branch: String = String(_tab_branches[tab_idx])
		if not _populated_branches.has(branch):
			_populate_branch(branch, _branch_containers[branch])
			_populated_branches[branch] = true
	elif tab_idx == _tab_branches.size() and _summary_container != null and not _summary_populated:
		_populate_summary()
		_summary_populated = true

func _refresh() -> void:
	_refresh_queued = false
	if not visible:
		_dirty = true
		return
	_dirty = false
	_update_points_label()
	# v9 perf: 状态签名比对——签名未变则到此为止（打开面板的常规路径）
	var sig: String = _current_state_signature()
	if sig == _rendered_sig:
		return
	_rendered_sig = sig
	# v9 perf: 当前 tab 若从未构建，本次直接构建（即最新状态，无需先建再重建）；
	# 已构建过的 tab（含当前）重建以刷新三态着色
	var current_branch := ""
	var cur_idx: int = _tab_container.current_tab if _tab_container != null else -1
	if cur_idx >= 0 and cur_idx < _tab_branches.size():
		current_branch = String(_tab_branches[cur_idx])
	var newly_populated := ""
	if current_branch != "" and not _populated_branches.has(current_branch):
		_populated_branches[current_branch] = true
		newly_populated = current_branch
	for branch_key in _populated_branches.keys():
		var branch: String = String(branch_key)
		if branch != newly_populated and _branch_containers.has(branch):
			_populate_branch(branch, _branch_containers[branch])
	if newly_populated != "":
		_populate_branch(newly_populated, _branch_containers[newly_populated])
	# v8.x: 刷新已解锁总览 tab（仅当玩家访问过）
	if _summary_populated and _summary_container != null:
		_populate_summary()

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
