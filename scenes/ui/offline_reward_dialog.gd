extends Control
class_name OfflineRewardDialog
## 离线挂机"欢迎回来"奖励弹窗
## 仿 battle_result_dialog 的静态 create 模式，运行时动态构建 UI
## result 结构见 OfflineIdleManager.compute_offline_rewards

signal claimed(rewards: Dictionary)

const _BG_PANEL := Color(0.03, 0.05, 0.10, 0.98)
const _BORDER := Color(0, 0.65, 1, 0.4)
const _ACCENT := Color(0, 0.94, 0.7, 1.0)
const _TEXT := Color(0.8, 0.88, 1.0, 0.95)
const _TEXT_DIM := Color(0.6, 0.7, 0.85, 0.8)
const _BTN_BG := Color(0, 0.5, 0.38, 1.0)

const _BasicResources = preload("res://data/basic_resources.gd")

var _result: Dictionary = {}


## 静态构造：parent 通常是 Main；result 为 OfflineIdleManager.compute_offline_rewards 的返回值
static func create(parent: Node, result: Dictionary) -> OfflineRewardDialog:
	var dialog := OfflineRewardDialog.new()
	dialog._result = result
	dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(dialog)
	dialog._build_ui()
	return dialog


func _build_ui() -> void:
	# 半透明遮罩（铺满整个屏幕）
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	# CenterContainer 保证面板无论内容多高都精确居中（与项目所有 overlay 一致）
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 让点击穿透到 dim 拦截
	add_child(center)

	# 居中面板
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(440, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = _BG_PANEL
	style.border_color = _BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	# 不用 FULL_RECT：让 VBox 自然撑开 Panel 高度（Panel 在 CenterContainer 里按内容尺寸居中）
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# 标题
	var title := Label.new()
	title.text = "欢迎回来"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", _ACCENT)
	vbox.add_child(title)

	# 离线时长 + 战斗次数
	var elapsed: int = int(_result.get("capped_sec", 0))
	var battles: int = int(_result.get("battles", 0))
	var level: int = int(_result.get("level", 1))
	var info := Label.new()
	info.text = "离线 %s  ·  折合 %d 场战斗  ·  基于第 %d 关" % [_format_duration(elapsed), battles, level]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_color_override("font_color", _TEXT_DIM)
	info.add_theme_font_size_override("font_size", 13)
	vbox.add_child(info)

	# 分隔线
	vbox.add_child(_make_separator())

	# 奖励标题
	var rew_title := Label.new()
	rew_title.text = "获得奖励"
	rew_title.add_theme_color_override("font_color", _TEXT)
	rew_title.add_theme_font_size_override("font_size", 15)
	vbox.add_child(rew_title)

	# 货币明细
	var currencies: Dictionary = _result.get("currencies", {})
	for id in currencies.keys():
		var amount: int = int(currencies[id])
		if amount > 0:
			vbox.add_child(_make_reward_line(_currency_display_name(String(id)), amount))

	# 掉落预估
	var drop_count: int = int(_result.get("drop_preview_count", 0))
	if drop_count > 0:
		vbox.add_child(_make_reward_line("战利品（约）", drop_count))

	# 领取按钮
	vbox.add_child(_make_separator())
	var claim_btn := Button.new()
	claim_btn.text = "领取"
	claim_btn.custom_minimum_size = Vector2(0, 42)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = _BTN_BG
	btn_style.border_color = _ACCENT
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(8)
	claim_btn.add_theme_stylebox_override("normal", btn_style)
	claim_btn.add_theme_stylebox_override("hover", btn_style)
	claim_btn.add_theme_stylebox_override("pressed", btn_style)
	claim_btn.add_theme_color_override("font_color", Color.WHITE)
	claim_btn.add_theme_font_size_override("font_size", 16)
	claim_btn.pressed.connect(_on_claim)
	vbox.add_child(claim_btn)


func _on_claim() -> void:
	claimed.emit(_result)
	queue_free()


# ── UI 辅助 ──

func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 2)
	return sep


func _make_reward_line(label_text: String, amount: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_lbl := Label.new()
	name_lbl.text = "· " + label_text
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_color_override("font_color", _TEXT_DIM)
	row.add_child(name_lbl)
	var amt_lbl := Label.new()
	amt_lbl.text = "×%d" % amount
	amt_lbl.add_theme_color_override("font_color", _TEXT)
	amt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(amt_lbl)
	return row


func _currency_display_name(id: String) -> String:
	match id:
		_BasicResources.ID_NANO_MATERIALS:
			return "纳米材料"
		_BasicResources.ID_ALLOY:
			return "合金"
		_BasicResources.ID_CRYSTAL:
			return "晶体"
		_BasicResources.ID_ENERGY_BLOCK:
			return "能量块"
		_BasicResources.ID_RESEARCH_POINTS:
			return "研究点"
		_:
			return id


func _format_duration(sec: int) -> String:
	var h: int = sec / 3600
	var m: int = (sec % 3600) / 60
	if h > 0:
		return "%d 小时 %d 分" % [h, m]
	return "%d 分" % m
