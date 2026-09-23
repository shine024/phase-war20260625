extends PanelContainer
## 底部常驻栏：统一从相位仪槽数据渲染（绿/红/蓝/黄）

const GC = preload("res://resources/game_constants.gd")
const DT = preload("res://resources/design_tokens.gd")
const PhaseLaws = preload("res://data/phase_laws.gd")
const PhaseInstruments = preload("res://data/phase_instruments.gd")
const DefaultCardsData = preload("res://data/default_cards.gd")
const LevelInformation = preload("res://data/level_information.gd")
const NodeFinder = preload("res://scripts/node_finder.gd")
const CardInfoPanel = preload("res://scenes/ui/card_info_panel.gd")
# R-B2 键位角标：新类消费必须 preload 而非依赖 class_name 全局缓存
# （headless/gdunit 运行期无编辑器扫描，v6.16 ModBreakpoints 同款教训）
const KeycapBadge = preload("res://scripts/ui/keycap_badge.gd")
const BackpackCombatPreview = preload("res://scenes/ui/backpack_combat_preview.gd")
const RankDisplayUi = preload("res://scripts/rank_display_ui.gd")
const CardFrameUi = preload("res://scripts/card_frame_ui.gd")
const CardBackgroundUi = preload("res://scripts/card_background_ui.gd")
const AutoDeployController = preload("res://scenes/ui/auto_deploy_controller.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")
# v32.0 B2-3: 套装体系检测（备战面预示——战斗内实时态见 combo_status_strip）
const ComboTactics = preload("res://data/combo_tactics.gd")
const DEBUG_BOTTOM_BAR_LOG := false
## ── 子系统：槽位拖放 ──
const DragSub = preload("res://scenes/ui/instrument_bar_drag.gd")
var _drag_system: InstrumentBarDrag = null

## ── 子系统：战斗内自动部署（从左到右铺满 + 死亡补阵）──
var _auto_deploy: AutoDeployController = null
var _auto_deploy_btn: Button = null
# v32.0 B2-3: 阵容体系预示行（NameSection 第三行）
var _synergy_label: Label = null
## ── v32.0 B2-1: 阵容预设 UI（「阵」按钮 + PopupPanel 五槽）──
var _preset_btn: Button = null
var _preset_popup: PopupPanel = null
var _preset_rows: Array = []

func _build_preset_ui() -> void:
	var slot_section: Node = get_node_or_null("Margin/HBox/InstrumentSection/SlotSection")
	if slot_section == null:
		return
	_preset_btn = Button.new()
	_preset_btn.text = "阵"
	_preset_btn.custom_minimum_size = Vector2(34, 0)
	_preset_btn.tooltip_text = "阵容预设：保存当前战斗卡装载，一键整套切换"
	_preset_btn.pressed.connect(_toggle_preset_popup)
	slot_section.add_child(_preset_btn)

func _toggle_preset_popup() -> void:
	if _preset_popup != null and _preset_popup.visible:
		_preset_popup.hide()
		return
	if _preset_popup == null:
		_build_preset_popup()
	_refresh_preset_popup()
	_preset_popup.reset_size()
	var btn_rect: Rect2 = _preset_btn.get_global_rect()
	_preset_popup.position = Vector2(
		clampf(btn_rect.position.x - 40.0, 4.0, 1276.0 - _preset_popup.size.x),
		maxf(btn_rect.position.y - _preset_popup.size.y - 6.0, 4.0))
	_preset_popup.popup()

func _build_preset_popup() -> void:
	_preset_popup = PopupPanel.new()
	_preset_popup.exclusive = false
	add_child(_preset_popup)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(330, 0)
	v.add_theme_constant_override("separation", 6)
	_preset_popup.add_child(v)
	var title := Label.new()
	title.text = "阵容预设"
	title.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM)
	title.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	v.add_child(title)
	var hint := Label.new()
	hint.text = "应用=整套切换战斗卡；保存=快照当前绿槽"
	hint.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	hint.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	v.add_child(hint)
	_preset_rows.clear()
	for i in range(PhaseInstrumentManager.LOADOUT_PRESET_SLOTS):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		v.add_child(row)
		var name_lbl := Label.new()
		name_lbl.text = "阵%d" % (i + 1)
		name_lbl.custom_minimum_size = Vector2(34, 0)
		name_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		row.add_child(name_lbl)
		var apply_btn := Button.new()
		apply_btn.text = "应用"
		apply_btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		apply_btn.pressed.connect(_on_preset_apply.bind(i))
		row.add_child(apply_btn)
		var save_btn := Button.new()
		save_btn.text = "保存"
		save_btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		save_btn.pressed.connect(_on_preset_save.bind(i))
		row.add_child(save_btn)
		var summary := Label.new()
		summary.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		summary.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
		summary.clip_text = true
		summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(summary)
		_preset_rows.append({"apply": apply_btn, "summary": summary})

func _refresh_preset_popup() -> void:
	if _preset_popup == null:
		return
	for i in range(_preset_rows.size()):
		var row: Dictionary = _preset_rows[i]
		var summary: Label = row["summary"]
		summary.text = PhaseInstrumentManager.get_loadout_preset_summary(i)
		row["apply"].disabled = PhaseInstrumentManager.get_loadout_presets()[i].is_empty()

func _on_preset_apply(idx: int) -> void:
	var n: int = PhaseInstrumentManager.apply_loadout_preset(idx)
	if n < 0:
		SignalBus.show_toast.emit("该预设为空：先「保存」当前阵容")
	else:
		SignalBus.show_toast.emit("已应用预设「阵%d」：%d 张战斗卡" % [idx + 1, n])
		_preset_popup.hide()

func _on_preset_save(idx: int) -> void:
	var n: int = PhaseInstrumentManager.save_loadout_preset(idx)
	if n < 0:
		SignalBus.show_toast.emit("预设槽位无效")
	else:
		SignalBus.show_toast.emit("已保存「阵%d」：%d 张战斗卡" % [idx + 1, n])
		_refresh_preset_popup()



signal instrument_area_clicked
signal phase_level_label_clicked
## 自动部署开关切换（战斗内：从左到右自动铺满 + 死亡补阵）
signal auto_deploy_toggled(enabled: bool)

var _slot_panels: Array = []
var _deployed_card_ids: Array = []
const SLOT_FIXED_SIZE := Vector2(90, 64)
const BAR_FIXED_HEIGHT := SLOT_FIXED_SIZE.y
## v21.x: 固定槽宽基准槽数——满配 13 格（green9+rune4，全布局最大总槽数）。
## 用作槽宽计算分母：无论当前实际几格（3/5/8/10/13），格子宽度恒等于 13 格布局的宽度。
const _FIXED_WIDTH_SLOT_REF := 13
## v21.x: 固定槽位宽度——所有相位仪统一用 13 格布局的宽度，不再随实际槽数变化
## （此前 3 格=90px、13 格≈71px 同屏不一致）。_fit_slots_to_bar 按视口可用宽 / 13 计算，上限90px。
var _slot_width: float = SLOT_FIXED_SIZE.x
## 槽底双行文字区高度（名称 + 费用），卡图只占上方区域避免遮挡
const _SLOT_BOTTOM_TEXT_H := 30
## 槽位 tooltip 过长会拖慢每次装备/刷新；限制长度
const _TOOLTIP_DESC_MAX := 140
const _TOOLTIP_ENHANCE_MAX := 24
## 合并同帧内多次 phase_slots_changed，只刷新一次 UI
var _slots_refresh_coalesce: bool = false
# v7.3 性能优化：tooltip 签名缓存。_update_instrument_tooltip 遍历符文之语+多行拼接，
# phase_slots_changed 每次都重建。相同 (instrument_id, lv) 跳过重建。
var _tooltip_last_sig: String = ""

## ── BU-1（战斗界面美化，2026-08-24）：悬浮卡 + 常驻能量条 + 菜单抽屉 + 槽位可负担状态机 ──
var _energy_fill: ProgressBar = null
var _energy_num_label: Label = null
var _menu_btn: Button = null
var _last_pending_deploy_id: String = ""
var _selected_deploy_panel: Control = null
var _breath_phase: float = 0.0
# v27.12 性能：呼吸微光 0.1s 节流累加器（原每帧对每个槽位 modulate + EnergyManager.can_afford）
var _anim_acc: float = 0.0
# v20.13b：每卡部署次数缓存（base_card_id → [remaining, total]），由 deploy_uses_changed 信号驱动
var _deploy_uses_map: Dictionary = {}

@onready var instrument_section: HBoxContainer = $Margin/HBox/InstrumentSection
@onready var instrument_icon: TextureRect = $Margin/HBox/InstrumentSection/InstrumentIcon
@onready var name_section: VBoxContainer = $Margin/HBox/InstrumentSection/NameSection
@onready var phase_level_label: Label = $Margin/HBox/InstrumentSection/NameSection/PhaseLevelLabel
@onready var instrument_stats_label: Label = $Margin/HBox/InstrumentSection/NameSection/InstrumentStatsLabel
@onready var slot_section: HBoxContainer = $Margin/HBox/InstrumentSection/SlotSection
var _phase_level_label_container: Control = null

func _ready() -> void:
	# 拖拽槽位发现锚点：背包卡拖拽缓存槽位时，主场景走 /root/Main 固定路径，
	# 基地（bunker）内嵌实例无该宿主——统一挂分组供 BackpackCardItemDrag 兜底查找
	add_to_group("instrument_bar_host")
	_drag_system = DragSub.new()
	_drag_system.setup(self)
	custom_minimum_size.y = BAR_FIXED_HEIGHT
	size.y = BAR_FIXED_HEIGHT
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_update_name_section_width()
	_connect_signals()
	_make_phase_level_label_clickable()
	_setup_auto_deploy()
	_apply_float_frame_style()
	_build_energy_row()
	_setup_menu_button()
	_update_energy_display()
	_build_synergy_label()
	_build_preset_ui()
	_build_deploy_count_label()
	_refresh_all()
	# 布局完成后，让格子高度精确填满条的可用空间
	call_deferred("_fit_slots_to_bar")


## 每帧驱动自动部署控制器（RefCounted 无 _process，由本 Control 节点转发）
## BU-1：另驱动槽位呼吸微光 + 部署待选（pending）金框轮询
func _process(delta: float) -> void:
	if _auto_deploy != null:
		_auto_deploy.process(delta)
	# v27.12 性能：pending 轮询保持每帧（部署选中金框的即时反馈），挪到节流 return 之前
	_poll_pending_deploy_selection()
	# v27.12 性能：呼吸微光 0.1s 节流——原每帧对每个槽位 modulate + EnergyManager.can_afford
	#（战斗中稳态空耗），10Hz 步进对 1.2s 周期的呼吸视觉无感；用累计时长推进相位，周期不变；
	# 战斗态 / motion_reduce 既有守卫仍在 _process_slot_breathing 内部生效
	_anim_acc += delta
	if _anim_acc < 0.1:
		return
	_process_slot_breathing(_anim_acc)
	_anim_acc = 0.0


## v7.x(自动部署)：在 InstrumentSection 最前面创建"自动"toggle 按钮 + 初始化控制器。
## v32.3 A3：默认开（偏好持久化）；战前可预武装（开战后自动铺）；战斗结束不再自动关。
func _setup_auto_deploy() -> void:
	# 控制器需要主场景引用（定位 Battlefield）
	var main_node: Node = _find_main_scene()
	_auto_deploy = AutoDeployController.new()
	# 先连 state_changed 再 setup——setup 会按持久化偏好发初始开启态
	_auto_deploy.state_changed.connect(_on_auto_deploy_state_changed)
	_auto_deploy.setup(main_node)
	# 按钮插到 InstrumentSection 最前面（InstrumentIcon 之前）
	_auto_deploy_btn = Button.new()
	_auto_deploy_btn.name = "AutoDeployBtn"
	_auto_deploy_btn.text = "自动"
	_auto_deploy_btn.custom_minimum_size = Vector2(48, BAR_FIXED_HEIGHT - 4)
	_auto_deploy_btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	_auto_deploy_btn.tooltip_text = "自动部署：开战后卡组自动上阵（绿槽顺序）\n单位死亡后自动补阵\n默认开启，偏好自动记忆"
	_auto_deploy_btn.toggle_mode = true
	# v32.3 A3：初始按压态对齐持久化偏好（set_pressed_no_signal 防回环触发 enable/disable）
	_auto_deploy_btn.set_pressed_no_signal(_auto_deploy != null and _auto_deploy.is_enabled())
	_apply_auto_deploy_btn_style(_auto_deploy != null and _auto_deploy.is_enabled())
	_auto_deploy_btn.pressed.connect(_on_auto_deploy_btn_pressed)
	instrument_section.add_child(_auto_deploy_btn)
	instrument_section.move_child(_auto_deploy_btn, 0)  # 移到最前面


func _find_main_scene() -> Node:
	var p: Node = get_parent()
	while p != null:
		if p.has_method("_get_battlefield"):
			return p
		p = p.get_parent()
	# 回退：通过 autoload 查找
	var tree: SceneTree = get_tree()
	if tree != null and tree.root != null:
		for c in tree.root.get_children():
			if c.has_method("_get_battlefield"):
				return c
	return null


func _on_auto_deploy_btn_pressed() -> void:
	# v25.2 按压音（此前仅菜单按钮有，同屏按钮反馈不一致）
	if SignalBus and SignalBus.has_signal("play_sound"):
		SignalBus.play_sound.emit("button")
	if _auto_deploy == null:
		return
	# v32.3 A3：解除"战斗中才能开"门控——战前可预武装（battle_started 后自动铺，
	# 控制器 _on_battle_started 原生支持）；开关即偏好，持久化在控制器侧
	if _auto_deploy_btn.is_pressed():
		_auto_deploy.enable()
	else:
		_auto_deploy.disable()


## v32.3 A3：外部查询自动部署偏好（教程首战 nudge 区分自动/手动语义用）
func is_auto_deploy_enabled() -> bool:
	return _auto_deploy != null and _auto_deploy.is_enabled()


func _on_auto_deploy_state_changed(enabled: bool) -> void:
	# 同步按钮视觉（防止代码触发与按钮状态不同步）
	if _auto_deploy_btn != null and is_instance_valid(_auto_deploy_btn):
		_auto_deploy_btn.set_pressed_no_signal(enabled)
		_apply_auto_deploy_btn_style(enabled)
	auto_deploy_toggled.emit(enabled)


## 按钮样式：关闭态灰色、开启态绿色高亮（P1-5: 补全 hover/pressed 四态 + 颜色走 DesignTokens）
## 注：mk_style 不用 lambda 局部变量——4.5.1 解析器不支持 `f(...)` 直接调用 lambda 变量（报
## "Function not found in base self"），故提为私有方法。
func _apply_auto_deploy_btn_style(active: bool) -> void:
	if _auto_deploy_btn == null or not is_instance_valid(_auto_deploy_btn):
		return
	if active:
		var g := DT.COLOR_HEALTH
		_auto_deploy_btn.add_theme_stylebox_override("normal",
			_mk_style(Color(g.r * 0.35, g.g * 0.55, g.b * 0.45, 0.95), g, 1))
		_auto_deploy_btn.add_theme_stylebox_override("hover",
			_mk_style(Color(g.r * 0.35, g.g * 0.62, g.b * 0.52, 1.0), Color(g.r, 1.0, g.b, 1.0), 2))
		_auto_deploy_btn.add_theme_stylebox_override("pressed",
			_mk_style(Color(g.r * 0.2, g.g * 0.4, g.b * 0.33, 1.0), g, 2))
		_auto_deploy_btn.add_theme_stylebox_override("disabled",
			_mk_style(Color(0.08, 0.12, 0.18, 0.6), Color(0.25, 0.45, 0.65, 0.25), 1))
		_auto_deploy_btn.add_theme_color_override("font_color", DT.COLOR_HOVER_WHITE)
		_auto_deploy_btn.add_theme_color_override("font_hover_color", Color.WHITE)
		_auto_deploy_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	else:
		_auto_deploy_btn.add_theme_stylebox_override("normal",
			_mk_style(Color(0.08, 0.12, 0.18, 0.85), Color(0.25, 0.45, 0.65, 0.4), 1))
		_auto_deploy_btn.add_theme_stylebox_override("hover",
			_mk_style(Color(0.13, 0.2, 0.3, 0.95), Color(DT.COLOR_ACCENT_CYAN.r, DT.COLOR_ACCENT_CYAN.g, DT.COLOR_ACCENT_CYAN.b, 0.7), 2))
		_auto_deploy_btn.add_theme_stylebox_override("pressed",
			_mk_style(DT.COLOR_PANEL_DEEP, Color(DT.COLOR_ACCENT_CYAN.r, DT.COLOR_ACCENT_CYAN.g, DT.COLOR_ACCENT_CYAN.b, 0.9), 2))
		_auto_deploy_btn.add_theme_stylebox_override("disabled",
			_mk_style(Color(0.08, 0.12, 0.18, 0.6), Color(0.25, 0.45, 0.65, 0.25), 1))
		_auto_deploy_btn.add_theme_color_override("font_color", Color(0.6, 0.7, 0.85, 0.9))
		_auto_deploy_btn.add_theme_color_override("font_hover_color", DT.COLOR_TEXT_BRIGHT)
		_auto_deploy_btn.add_theme_color_override("font_pressed_color", DT.COLOR_TEXT_BRIGHT)

func _mk_style(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(bw)
	sb.bg_color = bg
	sb.border_color = border
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	return sb

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_name_section_width()
		_fit_slots_to_bar()

func _connect_signals() -> void:
	if SignalBus:
		if SignalBus.has_signal("phase_slots_changed"):
			SignalBus.phase_slots_changed.connect(_on_slots_changed)
		if SignalBus.has_signal("battle_ended"):
			SignalBus.battle_ended.connect(_on_battle_ended)
		if SignalBus.has_signal("unit_spawned"):
			SignalBus.unit_spawned.connect(_on_unit_spawned)
		if SignalBus.has_signal("unit_died"):
			SignalBus.unit_died.connect(_on_unit_died)
		# v7.x: 接入能量不足/相位场升级提示（原信号 emit 无监听，玩家无反馈）
		if SignalBus.has_signal("energy_insufficient"):
			SignalBus.energy_insufficient.connect(_on_energy_insufficient)
		if SignalBus.has_signal("phase_field_level_up"):
			SignalBus.phase_field_level_up.connect(_on_phase_field_level_up)
		# v7.x: 玩家相位师战力变化 → 刷新底部栏等级显示
		if SignalBus.has_signal("player_phase_master_power_changed"):
			SignalBus.player_phase_master_power_changed.connect(_on_player_phase_master_power_changed)
		# BU-1: 能量变化 → 常驻能量条 + 槽位可负担状态刷新
		if SignalBus.has_signal("energy_changed"):
			SignalBus.energy_changed.connect(_on_energy_changed)
		# v20.13b: 每卡部署次数变化 → 槽位 ×N 角标刷新
		if SignalBus.has_signal("deploy_uses_changed"):
			SignalBus.deploy_uses_changed.connect(_on_deploy_uses_changed)

func _on_energy_insufficient(_cost: float) -> void:
	# 能量不足时给红色警告 toast（部署失败无其他视觉反馈）
	var tm: Node = get_node_or_null("/root/ToastManager")
	if tm and tm.has_method("show_error"):
		tm.show_error("能量不足，无法部署")

## BU-1：能量变化 → 更新常驻能量条 + 槽位可负担状态（部署选中金框最后重涂，不被覆盖）。
func _on_energy_changed(_cur: float, _mx: float) -> void:
	_update_energy_display()
	_refresh_slot_affordability()
	if _selected_deploy_panel != null and is_instance_valid(_selected_deploy_panel):
		_apply_slot_selection_glow(_selected_deploy_panel)

## v20.13b：每卡部署次数变化 → 更新缓存并刷新对应槽（×N 角标 + 耗尽压暗走 affordance 统一状态机）
## v20.16：键 = 部署身份（实例卡 instance_id / 旧卡裸 card_id），与 BSS 次数池同口径
func _on_deploy_uses_changed(deploy_key: String, remaining: int, total: int) -> void:
	_deploy_uses_map[deploy_key] = [remaining, total]
	for panel in _slot_panels:
		if panel == null or not is_instance_valid(panel):
			continue
		if _panel_deploy_key(panel) == deploy_key:
			_apply_slot_affordance(panel)
			_refresh_deploy_uses_badge(panel)


## v20.16：槽位的部署身份键（实例卡 instance_id 优先，回退裸 card_id，与 BSS/信号口径一致）
func _panel_deploy_key(panel: Control) -> String:
	var inst: String = String(panel.get_meta("instance_id", ""))
	if not inst.is_empty():
		return inst
	return String(panel.get_meta("card_id", ""))


## v20.16：卡对象的部署身份键
func _card_deploy_key(card: CardResource) -> String:
	if card.instance_id != null and not String(card.instance_id).is_empty():
		return String(card.instance_id)
	return String(card.card_id)

## v20.13b：槽位左上部署次数角标 ×N（右上已被费用角标占用）。
## 仅绿槽战斗卡且有信号数据时显示；耗尽转红（压暗由 _apply_slot_affordability 统一处理）。
func _refresh_deploy_uses_badge(panel: Control) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var color: String = String(panel.get_meta("slot_color", ""))
	var du_key: String = _panel_deploy_key(panel)
	var badge: Label = panel.get_node_or_null("DeployUsesBadge") as Label
	var has_data: bool = color == "green" and not du_key.is_empty() and _deploy_uses_map.has(du_key)
	if not has_data:
		if badge != null:
			badge.queue_free()
		return
	var remaining: int = int(_deploy_uses_map[du_key][0])
	if remaining > 99:
		return  # 次数充裕（≥100）不占角标注意力
	if badge == null:
		badge = Label.new()
		badge.name = "DeployUsesBadge"
		badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		badge.offset_left = 4.0
		badge.offset_top = 2.0
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_theme_font_size_override("font_size", DT.FONT_SIZE_XSMALL)
		badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		badge.add_theme_constant_override("outline_size", 3)
		badge.z_index = 3
		panel.add_child(badge)
	badge.text = "×%d" % remaining
	badge.add_theme_color_override("font_color",
		Color(1.0, 0.35, 0.3, 0.95) if remaining <= 0 else Color(1, 1, 1, 0.92))

## BU-1：底栏悬浮卡片化——弃用 tscn 直角通栏样式，走 PanelStyles 面板语言
## （12 圆角 + accent 边框 + 外发光）；底色 alpha 0.92 让战场从卡片下微透。
func _apply_float_frame_style() -> void:
	var sb: StyleBoxFlat = PanelStyles.make_panel_frame(DT.COLOR_ACCENT_CYAN)
	sb.bg_color.a = 0.92
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	add_theme_stylebox_override("panel", sb)

## BU-1：NameSection 中部常驻能量条（条 + 数值）。战斗中随 SignalBus.energy_changed
## 实时刷新；详细回复速率仍在相位仪等级 tooltip（_update_instrument_tooltip）。
func _build_energy_row() -> void:
	if name_section == null or not is_instance_valid(name_section):
		return
	var row := HBoxContainer.new()
	row.name = "EnergyRow"
	row.add_theme_constant_override("separation", 4)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pb := ProgressBar.new()
	pb.name = "EnergyFill"
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(24, 10)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = DT.COLOR_PANEL_DEEP
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = DT.COLOR_ENERGY
	fill.set_corner_radius_all(3)
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fill)
	_energy_fill = pb
	row.add_child(pb)
	var num := Label.new()
	num.name = "EnergyNumLabel"
	num.text = "--"
	num.custom_minimum_size = Vector2(52, 14)
	num.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	num.add_theme_color_override("font_color",
		Color(DT.COLOR_ENERGY.r, DT.COLOR_ENERGY.g, DT.COLOR_ENERGY.b, 0.95))
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_energy_num_label = num
	row.add_child(num)
	name_section.add_child(row)
	name_section.move_child(row, 1)

func _update_energy_display() -> void:
	if EnergyManager == null or not EnergyManager.has_method("get_current"):
		return
	var cur: float = float(EnergyManager.get_current())
	var mx: float = float(EnergyManager.get_max())
	if _energy_fill != null and is_instance_valid(_energy_fill):
		_energy_fill.max_value = maxf(mx, 1.0)
		_energy_fill.value = clampf(cur, 0.0, mx)
	if _energy_num_label != null and is_instance_valid(_energy_num_label):
		_energy_num_label.text = "%d/%d" % [int(cur), int(mx)]

## BU-1：底栏右端「菜单」按钮——展开/收起功能按钮抽屉（BottomFunctionBar），
## 把 15 个功能入口从战场视觉里收起来；红点聚合角标由 set_menu_badge 驱动。
## v38.x B 条: NameSection 常显"在场 n/上限 m"——第6关"只能上场6个哪里有说"主诉。
## 上限口径与 BattleSpawnSystem 一致（PhaseInstrumentManager 绿槽战斗卡数）；
## 在场数走战场实时 recount；刷新挂 unit_spawned/unit_died 信号。
var _deploy_count_label: Label = null

func _build_deploy_count_label() -> void:
	if name_section == null or not is_instance_valid(name_section):
		return
	_deploy_count_label = Label.new()
	_deploy_count_label.name = "DeployCountLabel"
	_deploy_count_label.add_theme_font_size_override("font_size", 11)
	_deploy_count_label.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0, 0.95))
	_deploy_count_label.tooltip_text = "在场单位数 / 可上场上限\n上限 = 绿槽装备的战斗卡数，场上另受 3×3 格子截断"
	name_section.add_child(_deploy_count_label)
	if SignalBus.has_signal("unit_spawned"):
		SignalBus.unit_spawned.connect(_on_deploy_count_dirty)
	if SignalBus.has_signal("unit_died"):
		SignalBus.unit_died.connect(_on_deploy_count_dirty)
	_refresh_deploy_count()


func _on_deploy_count_dirty(_unit: Node, _is_player: bool) -> void:
	_refresh_deploy_count()


func _refresh_deploy_count() -> void:
	if _deploy_count_label == null or not is_instance_valid(_deploy_count_label):
		return
	var max_units: int = 0
	if PhaseInstrumentManager != null:
		max_units = PhaseInstrumentManager.get_max_deployable_units()
	var live: int = 0
	if BattleManager != null and is_instance_valid(BattleManager) \
			and BattleManager.has_method("recount_player_units_on_field"):
		live = BattleManager.recount_player_units_on_field()
	_deploy_count_label.text = "在场 %d / 上限 %d" % [live, max_units]


func _setup_menu_button() -> void:
	var hbox: HBoxContainer = get_node_or_null("Margin/HBox") as HBoxContainer
	if hbox == null:
		return
	_menu_btn = Button.new()
	_menu_btn.name = "MenuBtn"
	_menu_btn.text = "菜单"
	_menu_btn.custom_minimum_size = Vector2(48, BAR_FIXED_HEIGHT - 4)
	_menu_btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	_menu_btn.tooltip_text = "功能菜单：背包/商店/任务等全部入口\n再点一次或按 ESC 收起"
	var styles := PanelStyles.make_button_styles(DT.COLOR_ACCENT_CYAN)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		_menu_btn.add_theme_stylebox_override(state, styles[state])
	_menu_btn.pressed.connect(_on_menu_btn_pressed)
	hbox.add_child(_menu_btn)

func _on_menu_btn_pressed() -> void:
	if SignalBus and SignalBus.has_signal("play_sound"):
		SignalBus.play_sound.emit("button")
	# v38.2 后抽屉被 _become_right_side_column reparent 到 HudLayer 直下
	#（HudLayer/BottomFunctionBar），旧兄弟路径只在测试/裸实例化结构里成立——
	# 两路都试（_notify_menu_badge 同款兜底纪律）。
	var fb: Node = get_node_or_null("../../BottomFunctionBar")
	if fb == null:
		fb = get_node_or_null("../BottomFunctionBar")
	if fb == null or not fb.has_method("toggle_drawer"):
		return
	fb.toggle_drawer()
	FeatureUnlockPopup.show_once("drawer_menu", "功能菜单",
		"背包/商店/任务等入口已收进底部「菜单」按钮。\n点击展开抽屉，再点一次或按 ESC 收起。")

## 功能栏红点聚合（BottomFunctionBar.set_btn_badge 透传）：任一功能有角标即显示总数。
func set_menu_badge(total: int) -> void:
	if _menu_btn == null or not is_instance_valid(_menu_btn):
		return
	var bg := _menu_btn.get_node_or_null("BadgeBg") as ColorRect
	var bd := _menu_btn.get_node_or_null("Badge") as Label
	if total <= 0 and bg == null:
		return
	if bg == null:
		bg = ColorRect.new()
		bg.name = "BadgeBg"
		bg.color = Color(0.95, 0.25, 0.25, 0.95)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		bg.offset_left = -18.0
		bg.offset_right = -2.0
		bg.offset_top = -2.0
		bg.offset_bottom = 14.0
		bg.size = Vector2(16, 16)
		_menu_btn.add_child(bg)
		bd = Label.new()
		bd.name = "Badge"
		bd.add_theme_font_size_override("font_size", DT.FONT_SIZE_XSMALL)
		bd.add_theme_color_override("font_color", Color.WHITE)
		bd.add_theme_color_override("font_outline_color", Color(0.8, 0.1, 0.1, 1.0))
		bd.add_theme_constant_override("outline_size", 2)
		bd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bd.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		bd.offset_left = -18.0
		bd.offset_right = -2.0
		bd.offset_top = -2.0
		bd.offset_bottom = 14.0
		bd.size = Vector2(16, 16)
		_menu_btn.add_child(bd)
	if total > 0:
		bd.text = str(total)
		bg.visible = true
		bd.visible = true
	else:
		bd.text = ""
		bg.visible = false
		bd.visible = false

## BU-1：槽位可负担状态机。能量不足的战斗卡槽：压暗罩（EnergyDim）+ 费用角标转红；
## 能量充足：边框 alpha 提到 1.0。部署选中槽的金框优先，不被本函数覆盖。
func _refresh_slot_affordability() -> void:
	for panel in _slot_panels:
		if panel == null or not is_instance_valid(panel):
			continue
		_apply_slot_affordance(panel)

func _apply_slot_affordance(panel: Control) -> void:
	var color: String = String(panel.get_meta("slot_color", ""))
	var card_type: int = int(panel.get_meta("card_type", -1))
	var cost: float = float(panel.get_meta("energy_cost", 0.0))
	var restricted: bool = bool(panel.get_meta("restricted", false))
	var deployable: bool = color == "green" and card_type == GC.CardType.COMBAT_UNIT and cost > 0.0
	var affordable: bool = deployable and EnergyManager != null \
		and EnergyManager.has_method("can_afford") and EnergyManager.can_afford(cost)
	var dim := panel.get_node_or_null("EnergyDim") as ColorRect
	if dim != null:
		# v20.13b：能量不足 or 部署次数耗尽，任一触发压暗（v20.16 按部署身份键查池）
		var du_key: String = _panel_deploy_key(panel)
		var du_exhausted: bool = deployable and _deploy_uses_map.has(du_key) \
			and int(_deploy_uses_map[du_key][0]) <= 0
		dim.visible = deployable and (not affordable or du_exhausted) and not restricted
	# Godot 4.5：get_meta 缺键时即使带 default 也打 error（空槽无 cost_badge_node meta，
	# 能量变化时刷屏）——必须 has_meta 守卫
	var cb: Variant = null
	if panel.has_meta("cost_badge_node"):
		cb = panel.get_meta("cost_badge_node")
	if cb != null and is_instance_valid(cb) and "warn" in cb:
		cb.set("warn", deployable and not affordable and not restricted)
	if panel == _selected_deploy_panel:
		return  # 部署选中金框优先
	if panel.has_meta("own_stylebox"):
		var sb: StyleBoxFlat = panel.get_meta("own_stylebox") as StyleBoxFlat
		if sb != null:
			var border: Color = _slot_border(color)
			if affordable and not restricted:
				border.a = 1.0
			sb.border_color = border

## v25.2 pickup 拦截判定：与压暗罩（_apply_slot_affordance）完全同口径——
## 能量不足 or 部署次数耗尽即拦；restricted/非战斗卡/零费卡不在此列（另有视觉口径）。
func _slot_deploy_blocked(panel: Control) -> bool:
	var color: String = String(panel.get_meta("slot_color", ""))
	var card_type: int = int(panel.get_meta("card_type", -1))
	var cost: float = float(panel.get_meta("energy_cost", 0.0))
	if color != "green" or card_type != GC.CardType.COMBAT_UNIT or cost <= 0.0:
		return false
	if bool(panel.get_meta("restricted", false)):
		return false
	if EnergyManager != null and EnergyManager.has_method("can_afford") \
			and not EnergyManager.can_afford(cost):
		return true
	var du_key: String = _panel_deploy_key(panel)
	return _deploy_uses_map.has(du_key) and int(_deploy_uses_map[du_key][0]) <= 0

## v25.2 pickup 拒绝反馈：error 音 + 槽位水平抖动（拒绝语义的水平摇头，区别于部署
## 震屏的垂直震动）。抖动尊重 motion_reduce（音效保留——听觉反馈不受减动效约束）。
func _reject_deploy_pickup(panel: Control) -> void:
	if SignalBus and SignalBus.has_signal("play_sound"):
		SignalBus.play_sound.emit("error")
	if panel == null or not is_instance_valid(panel) or DT.is_motion_reduce():
		return
	if not panel.has_meta("_slot_rest_x"):
		panel.set_meta("_slot_rest_x", panel.position.x)
	var rest_x: float = float(panel.get_meta("_slot_rest_x"))
	if panel.has_meta("reject_tween"):
		var old: Variant = panel.get_meta("reject_tween")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
			panel.position.x = rest_x
	var tw: Tween = panel.create_tween()
	panel.set_meta("reject_tween", tw)
	tw.tween_property(panel, "position:x", rest_x - 5.0, 0.04)
	tw.tween_property(panel, "position:x", rest_x + 5.0, 0.08)
	tw.tween_property(panel, "position:x", rest_x - 3.0, 0.08)
	tw.tween_property(panel, "position:x", rest_x, 0.05)

## BU-1：能量不足压暗罩——盖在卡图上、位于角标之下（树序控制绘制层级）。
func _ensure_energy_dim(panel: Control) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	if panel.get_node_or_null("EnergyDim") != null:
		return
	var dim := ColorRect.new()
	dim.name = "EnergyDim"
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.visible = false
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(dim)
	panel.move_child(dim, 1)

## 部署待选（pending）槽位金框：BattleInputState.pending 变化轮询驱动（点击/1-9 键同链路）。
func _poll_pending_deploy_selection() -> void:
	var pend: String = String(BattleInputState.pending_deploy_platform_card_id)
	if pend == _last_pending_deploy_id:
		return
	_last_pending_deploy_id = pend
	_apply_pending_selection(pend)

func _apply_pending_selection(pend: String) -> void:
	_refresh_slot_affordability()  # 先复位上一轮选中槽的边框
	if _selected_deploy_panel != null and is_instance_valid(_selected_deploy_panel):
		_clear_slot_selection_glow(_selected_deploy_panel)
	_selected_deploy_panel = null
	if pend.is_empty():
		return
	for panel in _slot_panels:
		if panel == null or not is_instance_valid(panel):
			continue
		var inst: String = String(panel.get_meta("instance_id", ""))
		var cid: String = String(panel.get_meta("card_id", ""))
		if (not inst.is_empty() and inst == pend) or (inst.is_empty() and cid == pend):
			_selected_deploy_panel = panel
			break
	if _selected_deploy_panel != null:
		_apply_slot_selection_glow(_selected_deploy_panel)

func _apply_slot_selection_glow(panel: Control) -> void:
	if panel == null or not is_instance_valid(panel) or not panel.has_meta("own_stylebox"):
		return
	var sb: StyleBoxFlat = panel.get_meta("own_stylebox") as StyleBoxFlat
	if sb == null:
		return
	sb.border_color = Color(DT.COLOR_GOLD.r, DT.COLOR_GOLD.g, DT.COLOR_GOLD.b, 1.0)
	sb.shadow_color = Color(DT.COLOR_GOLD.r, DT.COLOR_GOLD.g, DT.COLOR_GOLD.b, 0.55)
	sb.shadow_size = 8

func _clear_slot_selection_glow(panel: Control) -> void:
	if panel == null or not is_instance_valid(panel) or not panel.has_meta("own_stylebox"):
		return
	var sb: StyleBoxFlat = panel.get_meta("own_stylebox") as StyleBoxFlat
	if sb == null:
		return
	sb.shadow_size = 0
	sb.shadow_color = DT.COLOR_TRANSPARENT

## BU-1：可部署槽位呼吸微光——战斗中能量充足的战斗卡槽 modulate.a 0.85↔1.0（周期 1.2s）。
## 尊重 DT.is_motion_reduce()（静止 1.0）；受限灰显/能量不足槽不参与。
func _process_slot_breathing(delta: float) -> void:
	var in_battle: bool = BattleManager != null and "battle_active" in BattleManager and BattleManager.battle_active
	if not in_battle or DT.is_motion_reduce():
		if _breath_phase != 0.0:
			_breath_phase = 0.0
			_reset_slot_breathing()
		return
	_breath_phase = fmod(_breath_phase + delta / 1.2, 1.0)
	var a: float = 0.85 + 0.15 * (0.5 - 0.5 * cos(_breath_phase * TAU))
	for panel in _slot_panels:
		if panel == null or not is_instance_valid(panel):
			continue
		if not _slot_breath_eligible(panel):
			if panel.modulate.a != 1.0 and not bool(panel.get_meta("restricted", false)):
				panel.modulate.a = 1.0
			continue
		panel.modulate.a = a

func _slot_breath_eligible(panel: Control) -> bool:
	if String(panel.get_meta("slot_color", "")) != "green":
		return false
	if int(panel.get_meta("card_type", -1)) != GC.CardType.COMBAT_UNIT:
		return false
	if bool(panel.get_meta("restricted", false)):
		return false
	var cost: float = float(panel.get_meta("energy_cost", 0.0))
	if cost <= 0.0:
		return false
	return EnergyManager != null and EnergyManager.has_method("can_afford") and EnergyManager.can_afford(cost)

func _reset_slot_breathing() -> void:
	for panel in _slot_panels:
		if panel == null or not is_instance_valid(panel):
			continue
		if bool(panel.get_meta("restricted", false)):
			continue
		panel.modulate.a = 1.0

func _on_phase_field_level_up(old_level: int, new_level: int, unspent_points: int) -> void:
	# 相位场升级给正面提示（玩家可能未察觉等级提升）
	var tm: Node = get_node_or_null("/root/ToastManager")
	if tm and tm.has_method("show_success"):
		tm.show_success("相位场提升至 Lv%d！获得 %d 点（累计待用 %d）" % [new_level, new_level - old_level, unspent_points])
	# P2-13: 首次升级弹一次属性点说明（相位场属性点系统已接通但入口隐蔽）
	FeatureUnlockPopup.show_once("phase_field", "相位场升级",
		"相位场随战斗经验升级，每次升级获得属性点。\n点击底部栏左侧的相位场等级（Lv 标签）可打开分配面板，把点数分配到攻击/防御/生命等属性。")

## v7.x: 玩家相位师战力变化（战斗开始算出后触发）→ 刷新底部栏显示
func _on_player_phase_master_power_changed(_raw: float, _compressed: float, _stars: int, _star_name: String, _level: int) -> void:
	_refresh_instrument_stats()

func _on_battle_ended(_won: bool) -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return  # 主场景已离树（切场景竞态）：槽位面板随场景消亡，无需刷新
	_deployed_card_ids.clear()
	# v20.13b：部署次数缓存与角标随战斗结束清除（下场由 reset 信号重建）
	_deploy_uses_map.clear()
	for panel in _slot_panels:
		if panel == null or not is_instance_valid(panel):
			continue
		var badge: Label = panel.get_node_or_null("DeployUsesBadge") as Label
		if badge != null:
			badge.queue_free()
	_refresh_slot_layout()
	_refresh_phase_level()
	# 自动部署按钮复位（仅当前战斗生效，下场需重新开启）
	if _auto_deploy_btn != null and is_instance_valid(_auto_deploy_btn):
		_auto_deploy_btn.set_pressed_no_signal(false)
		_apply_auto_deploy_btn_style(false)

func _on_unit_spawned(unit: Node, is_player: bool) -> void:
	if not is_player:
		return
	if unit == null or not is_instance_valid(unit):
		return
	var card_id = unit.get_meta("source_card_id", "")
	if not card_id.is_empty() and not card_id in _deployed_card_ids:
		_deployed_card_ids.append(card_id)
		_refresh_slot_indicators()

func _on_unit_died(unit: Node, is_player: bool) -> void:
	if not is_player:
		return
	if unit == null or not is_instance_valid(unit):
		return
	var card_id = unit.get_meta("source_card_id", "")
	if not card_id.is_empty() and card_id in _deployed_card_ids:
		_deployed_card_ids.erase(card_id)
		_refresh_slot_indicators()

func _refresh_slot_indicators() -> void:
	if not is_instance_valid(self):
		return
	for panel in _slot_panels:
		if panel == null or not is_instance_valid(panel):
			continue
		_apply_deploy_indicator_state(panel)

## 在场标记按"同型卡前 N 个槽"点亮（N = 该卡种当前在场数）。
## 旧口径按 card_id 成员判断——部署 1 个步枪班，3 个步枪班槽全亮，与「在场 n / 上限 m」
## 计数当场矛盾（同名卡越多越离谱）。_deployed_card_ids 是进出场维护的多元集合，
## 某 card_id 的出现次数即该卡种在场数；同型槽按槽位序只点亮前 N 个。
func _apply_deploy_indicator_state(panel: Control) -> void:
	var indicator: Polygon2D = panel.get_node_or_null("DeployIndicator") as Polygon2D
	if indicator == null or not is_instance_valid(indicator):
		return
	var card_id := String(panel.get_meta("card_id", ""))
	if card_id.is_empty():
		indicator.visible = false
		return
	var quota := 0
	for cid in _deployed_card_ids:
		if String(cid) == card_id:
			quota += 1
	if quota <= 0:
		indicator.visible = false
		return
	var ordinal := 0
	var found := false
	for p in _slot_panels:
		if p == null or not is_instance_valid(p):
			continue
		if String(p.get_meta("card_id", "")) == card_id:
			ordinal += 1
			if p == panel:
				found = true
				break
	indicator.visible = found and ordinal <= quota

## 刷新全部显示
func _refresh_all() -> void:
	_refresh_slot_layout()
	_refresh_phase_level()
	_refresh_synergy_label()

## v32.0 B2-3: 备战面体系预示——NameSection 第三行。
## 战斗内实时激活态由 combo_status_strip 轮询场上单位（v9.1/v21）；
## 本行消费同一 detect API 但读**装载槽卡的已装改造**，在基地调整卡时即时预览
## "这套阵容将激活什么体系"，闭合构筑决策回路。
func _build_synergy_label() -> void:
	var name_section: Node = get_node_or_null("Margin/HBox/InstrumentSection/NameSection")
	if name_section == null:
		return
	_synergy_label = Label.new()
	_synergy_label.custom_minimum_size = Vector2(0, 16)
	_synergy_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_synergy_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_synergy_label.add_theme_font_size_override("font_size", 12)
	_synergy_label.add_theme_color_override("font_color", DT.COLOR_GOLD)
	_synergy_label.clip_text = true
	_synergy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_synergy_label.visible = false
	name_section.add_child(_synergy_label)


func _refresh_synergy_label() -> void:
	if _synergy_label == null or not is_instance_valid(_synergy_label):
		return
	# combo_id -> 档位rank（0=基础 1=满档），多卡同类取最高
	var agg: Dictionary = {}
	if PhaseInstrumentManager != null:
		for loadout in PhaseInstrumentManager.get_loadouts():
			var card: CardResource = loadout.get("platform")
			if card == null or card.mods.is_empty():
				continue
			var tiers: Dictionary = ComboTactics.detect_card_combo_tiers(card.mods)
			for cid in tiers:
				var rank: int = 1 if String(tiers[cid]) == ComboTactics.TIER_FULL else 0
				if rank > int(agg.get(cid, -1)):
					agg[cid] = rank
		# v6.19 P2-T2.2 流派成型埋点：备战态首次激活套装 / 首次满档（构筑即成型时刻）
		if not agg.is_empty():
			var pm: Node = get_node_or_null("/root/PerformanceMetricsManager")
			if pm != null and pm.has_method("record_milestone"):
				pm.record_milestone("combo_active_first")
				var has_full := false
				for cid in agg:
					if int(agg[cid]) == 1:
						has_full = true
						break
				if has_full:
					pm.record_milestone("combo_full_first")
	if agg.is_empty():
		_synergy_label.visible = false
		return
	var parts: Array[String] = []
	var tips: Array[String] = []
	for cid in agg:
		var def: Dictionary = ComboTactics.COMBOS.get(cid, {})
		var cname: String = String(def.get("name", String(cid)))
		var is_full: bool = int(agg[cid]) == 1
		parts.append("%s·%s" % [cname, "满" if is_full else "基"])
		tips.append("%s（%s）" % [cname, "满档" if is_full else "基础档"])
	_synergy_label.visible = true
	_synergy_label.text = "体系：" + "、".join(parts)
	var nl_sep := String.chr(10)
	_synergy_label.tooltip_text = "当前阵容体系预览（按已装改造，满档需集齐满档件）：" + nl_sep + nl_sep.join(tips)



func _format_card_slot_tooltip(color: String, card: CardResource) -> String:
	if card == null:
		return ""
	var display_name: String = "充能槽" if card.card_type == GC.CardType.ENERGY else DefaultCardsData.get_safe_display_name(card.card_id)
	# v7.x：同名卡追加序号后缀（#1/#2…）
	display_name += DefaultCardsData.seq_suffix(card)
	var cost_text: String = "%d⚡" % int(card.energy_cost)
	var detail_lines: Array[String] = []
	detail_lines.append("%s 槽：%s" % [_slot_name(color), display_name])
	detail_lines.append("能量消耗：%s" % cost_text)
	# v19: 战斗等级（card_level 1-30）——装配决策核心维度，tooltip 常驻显示
	if card.card_type == GC.CardType.COMBAT_UNIT:
		var _ir_lv: Node = get_node_or_null("/root/InstanceRegistry")
		var _lv_val: int = 1
		if _ir_lv != null and _ir_lv.has_method("get_card_level"):
			var _ident: String = String(card.instance_id) if not String(card.instance_id).is_empty() else String(card.card_id)
			_lv_val = clampi(maxi(int(_ir_lv.get_card_level(_ident)), 1), 1, 30)
		detail_lines.append("等级：Lv.%d" % _lv_val)
	# v20.13b：每卡部署次数（本场剩余/总量；战斗中由 deploy_uses_changed 信号维护；v20.16 实例键）
	if card.card_type == GC.CardType.COMBAT_UNIT and _deploy_uses_map.has(_card_deploy_key(card)):
		var du: Array = _deploy_uses_map[_card_deploy_key(card)]
		detail_lines.append("部署次数：%d / %d" % [int(du[0]), int(du[1])])
	# v20.15: 固定机制文案（雷达/指挥/医疗等 tag 机制）
	for mech_line in CardMechanismDesc.get_mechanism_lines(card.tags):
		detail_lines.append(mech_line)
	if not String(card.type_line).is_empty():
		detail_lines.append("类型：%s" % String(card.type_line))
	if not String(card.summary_line).is_empty():
		detail_lines.append("摘要：%s" % String(card.summary_line))
	var desc := String(card.description)
	if desc.length() > _TOOLTIP_DESC_MAX:
		desc = desc.substr(0, _TOOLTIP_DESC_MAX) + "…"
	if not desc.is_empty():
		detail_lines.append("说明：%s" % desc)
	var rank_line: String = RankDisplayUi.format_line(RankDisplayUi.resolve_from_card_resource(card))
	if not rank_line.is_empty():
		detail_lines.append(rank_line)
	var combat_line: String = BackpackCombatPreview.build_line(card)
	if not combat_line.is_empty():
		detail_lines.append(combat_line)
	# v5.1: star_level system removed - skip star enhancement display
	return "\n".join(detail_lines)


func _on_slots_changed(_slots_data: Array) -> void:
	_slots_refresh_coalesce = true
	call_deferred("_flush_pending_slots_refresh")


func _flush_pending_slots_refresh() -> void:
	if not _slots_refresh_coalesce:
		return
	_slots_refresh_coalesce = false
	if not is_inside_tree():
		return
	_refresh_slot_layout()
	_refresh_phase_level()
	_refresh_slot_indicators()
	_refresh_synergy_label()


func _refresh_slot_layout() -> void:
	if PhaseInstrumentManager == null:
		return
	var layout: Array = PhaseInstrumentManager.get_slot_layout() if PhaseInstrumentManager.has_method("get_slot_layout") else []
	# 槽位数量变化时全量重建
	if layout.size() != _slot_panels.size():
		_rebuild_all_slot_panels(layout)
		return
	# 数量相同：始终增量更新（gui_input 闭包通过 panel meta 读取当前状态，不依赖构建时捕获）
	for i in range(layout.size()):
		var entry: Dictionary = layout[i]
		_update_slot_panel(_slot_panels[i], entry)
	_refresh_slot_affordability()
	_refresh_deploy_keycaps()

func _rebuild_all_slot_panels(layout: Array) -> void:
	for old in _slot_panels:
		if old and is_instance_valid(old):
			old.queue_free()
	_slot_panels.clear()
	for i in range(layout.size()):
		var entry: Dictionary = layout[i]
		var panel := _build_slot_panel(entry)
		slot_section.add_child(panel)
		_slot_panels.append(panel)
		# BU-1：重建路径也走增量更新，补 energy_cost/restricted meta + 压暗罩
		_update_slot_panel(panel, entry)
	_refresh_slot_affordability()
	_refresh_deploy_keycaps()
	call_deferred("_fit_slots_to_bar")

## UI 四级标准修复 R-B2：部署槽 1-9 数字角标——键盘部署真身
## begin_deploy_from_slot_index(n) 的 n=第 n 个可部署绿槽（有战斗卡的非空绿槽），
## 角标序号必须与它同口径；布局/换卡变化后重算（增量与全量两条路径都挂）。
## >9 无键位不显示；空绿槽隐藏角标（与键盘行为一致：跳过空槽继续数）。
func _refresh_deploy_keycaps() -> void:
	var n := 0
	for panel in _slot_panels:
		if panel == null or not is_instance_valid(panel):
			continue
		var deployable: bool = String(panel.get_meta("slot_color", "")) == "green" \
			and not String(panel.get_meta("card_id", "")).is_empty() \
			and int(panel.get_meta("card_type", -1)) == GC.CardType.COMBAT_UNIT
		if deployable:
			n += 1
		# v38.x I 条: tooltip 补键位语义——数字角标被误读成"关1 2 3"，点明"按 N 键部署"
		if deployable:
			var base_tip: String = String(panel.get_meta("deploy_tooltip_base", panel.tooltip_text))
			panel.set_meta("deploy_tooltip_base", base_tip)
			panel.tooltip_text = base_tip + "\n\n按 %d 键直接部署该单位" % n
		KeycapBadge.bind_to_digit(panel, n if deployable else 0)

## 增量更新单个格子的内容和样式（避免每次重建所有格子）
func _update_slot_panel(panel: Control, entry: Dictionary) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var color: String = String(entry.get("color", ""))
	# v8 修复：关卡限定兵种预过滤——默认不灰显，仅 has_card 受限分支覆盖为 0.4。
	# 在函数入口设默认值，避免上一轮被灰显的槽位换成法则/符文/空卡后残留灰显。
	panel.modulate.a = 1.0
	# v6.2: rune 槽的 card 字段实际是 rune_id (String)，不能用 CardResource 类型注解，
	# 否则赋值时崩溃 "Trying to assign a non-object value to a variable of type 'card_resource.gd'"。
	# 用 Variant 承载，并在使用 card 属性前用 is CardResource 守卫。
	var card: Variant = entry.get("card", null)
	# 仅当确为 CardResource 时才视为有效卡（rune 槽的 String 不应走卡牌渲染分支）
	var has_card: bool = card != null and card is CardResource
	# v7.x：非战斗卡（法则/符文/空槽）清除费用角标，避免旧角标残留
	if not has_card:
		CardFrameUi.clear_cost_corner_badge(panel)
	var law_id: String = String(entry.get("law_id", ""))
	var law_kind: String = String(entry.get("law_kind", ""))
	panel.set_meta("slot_color", color)
	panel.set_meta("card_id", card.card_id if has_card else "")
	# v7.x 修复（情报面板看不到强化/改造）：额外存 instance_id，显示路径用它精确实例取回（带养成数据）。
	# card_id meta 不变（部署指示器 L109/L247 比对 _deployed_card_ids 仍用裸 card_id）。
	panel.set_meta("instance_id", card.instance_id if (has_card and card.instance_id != null and not card.instance_id.is_empty()) else "")
	panel.set_meta("card_type", int(card.card_type) if has_card else -1)
	panel.set_meta("law_id", law_id)
	panel.set_meta("law_kind", law_kind)
	# BU-1：可负担状态机数据——energy_cost/restricted meta + 压暗罩
	panel.set_meta("energy_cost",
		float(card.energy_cost) if (has_card and card.card_type == GC.CardType.COMBAT_UNIT) else 0.0)
	panel.set_meta("restricted",
		has_card and card.card_type == GC.CardType.COMBAT_UNIT and _is_card_platform_restricted(card))
	_ensure_energy_dim(panel)
	# 更新样式
	# v7.3 修复+性能：每个槽位 panel 用独立的 StyleBoxFlat override，而非改共享 theme stylebox。
	# 原实现 get_theme_stylebox("panel") 返回 theme 共享实例，直接改 bg_color/border_color 会污染所有
	# 同主题节点（视觉 bug）+ 无谓触发全局重绘。改为每 panel 缓存独立 stylebox（首次创建，之后复用改色）。
	var sb: StyleBoxFlat = null
	if panel.has_meta("own_stylebox"):
		sb = panel.get_meta("own_stylebox") as StyleBoxFlat
	if sb == null or not is_instance_valid(sb):
		sb = StyleBoxFlat.new()
		# 复制基础样式（边框宽度等）
		var base_sb: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		if base_sb and base_sb is StyleBoxFlat:
			sb.border_width_left = base_sb.border_width_left
			sb.border_width_right = base_sb.border_width_right
			sb.border_width_top = base_sb.border_width_top
			sb.border_width_bottom = base_sb.border_width_bottom
			sb.corner_radius_top_left = base_sb.corner_radius_top_left
			sb.corner_radius_top_right = base_sb.corner_radius_top_right
			sb.corner_radius_bottom_left = base_sb.corner_radius_bottom_left
			sb.corner_radius_bottom_right = base_sb.corner_radius_bottom_right
			sb.content_margin_left = base_sb.content_margin_left
			sb.content_margin_right = base_sb.content_margin_right
			sb.content_margin_top = base_sb.content_margin_top
			sb.content_margin_bottom = base_sb.content_margin_bottom
		panel.add_theme_stylebox_override("panel", sb)
		panel.set_meta("own_stylebox", sb)
	sb.bg_color = _slot_bg(color)
	sb.border_color = _slot_border(color)
	# v7.x：精简模式不再有 SlotTextVBox，直接用 SlotIconClip 判定槽位结构完整性
	if _slot_icon_rect(panel) == null:
		return
	# 处理 DeployIndicator：仅在战斗卡时存在
	var needs_indicator: bool = has_card and card.card_type == GC.CardType.COMBAT_UNIT
	var indicator: Polygon2D = panel.get_node_or_null("DeployIndicator") as Polygon2D
	if needs_indicator and indicator == null:
		indicator = Polygon2D.new()
		indicator.name = "DeployIndicator"
		indicator.polygon = PackedVector2Array([
			Vector2(-6, 0), Vector2(6, 0), Vector2(0, -10)
		])
		indicator.color = Color(DT.COLOR_GREEN_BRIGHT.r, DT.COLOR_GREEN_BRIGHT.g, DT.COLOR_GREEN_BRIGHT.b, 0.9)
		indicator.position = Vector2(_slot_width * 0.5, -2)
		panel.add_child(indicator)
		_apply_deploy_indicator_state(panel)
	elif not needs_indicator and indicator != null:
		indicator.queue_free()
	if has_card:
		_apply_slot_card_labels(panel, card)
		panel.tooltip_text = _format_card_slot_tooltip(color, card)
		# v7.x 修复：has_card 分支必须 return，否则会继续执行到 L314 的
		# _apply_slot_bottom_text(panel, "空", "") 把刚设好的卡名覆盖成"空"
		# （费用角标独立设置不受影响，导致"名字空+费用有"的诡异现象）
		_sync_slot_icon(panel, card, law_id)
		_clear_slot_rank_badge(panel)
		_sync_slot_card_background(panel, card)
		_sync_slot_card_frame(panel, card)
		# v8 修复：关卡限定兵种预过滤——战斗卡若被本关 restrict_platforms 排除，灰显提示
		# （部署时 battle_spawn_system 仍会拦截，这里只是 UI 预提示，避免玩家点了才报错）
		if card.card_type == GC.CardType.COMBAT_UNIT and _is_card_platform_restricted(card):
			panel.modulate.a = 0.4
		return
	elif not law_id.is_empty():
		var PhaseLaws_local = PhaseLaws
		var cfg: Dictionary = PhaseLaws_local.get_by_id(law_id) if PhaseLaws_local else {}
		var law_name: String = String(cfg.get("name", law_id))
		var battle_cost: Dictionary = cfg.get("battle_cost", {})
		var activate_cost: Dictionary = cfg.get("activate_cost", {})
		var battle_energy: int = int(battle_cost.get("energy", 0))
		var activate_nano: int = int(activate_cost.get("nano", 0))
		var cost_line: String = ""
		if battle_energy > 0:
			cost_line = "%d⚡" % battle_energy
		elif activate_nano > 0:
			cost_line = "纳米%d" % activate_nano
		var short_law_name: String = law_name
		if short_law_name.length() > 5:
			short_law_name = short_law_name.substr(0, 5)
		_apply_slot_bottom_text(
			panel,
			("⚔" if law_kind == "active" else "🛡") + short_law_name,
			cost_line
		)
		_sync_slot_icon(panel, card, law_id)
		_clear_slot_rank_badge(panel)
		_sync_slot_card_background(panel, card)
		_sync_slot_card_frame(panel, card)
		return
	# v6.2: 符文槽位显示
	var rune_id: String = String(entry.get("rune_id", ""))
	if color == "rune" and not rune_id.is_empty():
		var RuneDefs = preload("res://data/runes.gd")
		var rune_name: String = RuneDefs.get_rune_name(rune_id)
		var rune_def: Dictionary = RuneDefs.get_rune(rune_id)
		var rarity_name: String = RuneDefs.RARITY_NAMES.get(rune_def.get("rarity", ""), "")
		var short_name: String = rune_name
		if short_name.length() > 4:
			short_name = short_name.substr(0, 4)
		_apply_slot_bottom_text(panel, "◈" + short_name, rarity_name)
		panel.tooltip_text = "符文：%s（%s）\n%s" % [rune_name, rarity_name, RuneDefs.get_description(rune_id)]
		# v6.2: 符文专属图标贴图（参照 _sync_slot_icon 的尺寸算法）
		var rune_tr: TextureRect = _slot_icon_rect(panel)
		var rune_tex: Texture2D = UiAssetLoader.rune_icon_small(rune_id)
		var slot_h: float = panel.size.y if panel.size.y > 4.0 else float(SLOT_FIXED_SIZE.y)
		# v7.x：精简模式无底部文字区，图标占满（留 4px 边距）
		var art_h: float = maxf(18.0, slot_h - 4.0)
		var art_w: float = _slot_width - 6.0
		UiAssetLoader.setup_texrect_icon(rune_tr, rune_tex, Vector2(art_w, art_h))
		_sync_slot_card_background(panel, null)
		_sync_slot_card_frame(panel, null)
		return
	_apply_slot_bottom_text(panel, "空", "")
	panel.tooltip_text = "%s 槽（空）" % _slot_name(color)
	_sync_slot_icon(panel, card, law_id)
	_clear_slot_rank_badge(panel)
	_sync_slot_card_background(panel, card)
	_sync_slot_card_frame(panel, card)

## v8 修复：判断战斗卡是否被当前关 restrict_platforms 排除（UI 预过滤用）。
## 读 GameManager.current_level → LevelInformation.get_special_rules → restrict_platforms 白名单。
## 无规则 / 非战斗场景（GameManager 未就绪）返回 false（不灰显）。
## v20.x 修复：白名单值是 CombatKind(0-4)，改读 combat_kind（platform_type 在 UCT 构建
## 与实例 clone 两路径均漏设恒 -1，曾致第15/30/55/85关全部战斗卡被灰显）。
func _is_card_platform_restricted(card: CardResource) -> bool:
	if card == null:
		return false
	if GameManager == null or not GameManager.get("current_level"):
		return false
	var level: int = int(GameManager.current_level)
	var li = LevelInformation.get_shared()
	var restrict: Array = li.get_special_rules(level).get("restrict_platforms", [])
	if restrict.is_empty():
		return false
	return not restrict.has(int(card.combat_kind))

## 让格子高度精确填满条的可用高度（抵消 PanelContainer content_margin 等开销）
## v21.x: 槽位宽度固定为 13 格（green9+rune4，最大槽数）布局的宽度——槽少也不放大，
## 所有相位仪格子同宽。
## v38.x H 条: 弃纯视口反推，改布局后实测——HBox 实宽减可见兄弟实测宽（菜单钮隐藏
## 不计，truck 内嵌实例不再被幽灵 48px 预算吃掉半格）+「阵」按钮实测计入 slot 内开销。
## 布局未稳定（首帧 size≈0）回退旧视口估算。
func _fit_slots_to_bar() -> void:
	if not is_instance_valid(slot_section):
		return
	var available_h: float = slot_section.size.y
	if available_h < 1.0:
		available_h = BAR_FIXED_HEIGHT
	var viewport_width: float = get_viewport_rect().size.x
	if viewport_width <= 1.0:
		viewport_width = 1280.0
	var slot_available_w: float = -1.0
	var hbox: Container = null
	if instrument_section != null and is_instance_valid(instrument_section) \
			and instrument_section.get_parent() is Container:
		hbox = instrument_section.get_parent() as Container
	if hbox != null and hbox.size.x > 1.0:
		# ── 实测路径 ──
		var overhead: float = 0.0
		var visible_n: int = 0
		for child in hbox.get_children():
			var c: Control = child as Control
			if c == null or not c.visible:
				continue
			visible_n += 1
			if c == instrument_section:
				continue
			overhead += maxf(c.size.x, c.get_combined_minimum_size().x)
		overhead += float(hbox.get_theme_constant("separation")) * float(maxi(0, visible_n - 1))
		# InstrumentSection 内非槽位开销：图标 / 名称区 / 自动按钮 + 区内间距
		var section_inner: float = 0.0
		var sec_visible_n: int = 0
		for child in instrument_section.get_children():
			var c2: Control = child as Control
			if c2 == null or not c2.visible:
				continue
			sec_visible_n += 1
			if c2 == slot_section:
				continue
			section_inner += maxf(c2.size.x, c2.get_combined_minimum_size().x)
		section_inner += float(instrument_section.get_theme_constant("separation")) * float(maxi(0, sec_visible_n - 1))
		# MarginContainer 左右 content margin（16）+ 少量安全余量（分隔线/圆角裁切）
		slot_available_w = maxf(200.0, hbox.size.x - overhead - section_inner - 16.0 - 4.0)
	if slot_available_w < 0.0:
		# ── fallback：布局未稳定，按视口反推（v26.x 估算保留）──
		var reserved_w: float = 16.0 + 48.0 + 48.0 + 120.0 + 12.0 + 2.0 + 6.0 + 48.0 + 6.0 + 32.0 + 20.0  # ≈ 358px
		slot_available_w = maxf(200.0, viewport_width - reserved_w)
	var separation: float = 6.0
	# v38.x H 条: slot_section 内非槽位可见子（「阵」按钮 34px 等）实测计入开销
	var slot_overhead: float = 0.0
	var slot_panels_set: Dictionary = {}
	for p in _slot_panels:
		if p and is_instance_valid(p):
			slot_panels_set[p] = true
	for child in slot_section.get_children():
		var c3: Control = child as Control
		if c3 == null or not c3.visible or slot_panels_set.has(c3):
			continue
		slot_overhead += maxf(c3.size.x, c3.get_combined_minimum_size().x) + separation
	# v21.x: 固定宽度——原恒按最大槽数 _FIXED_WIDTH_SLOT_REF(13) 格计算。
	# v6.23（用户拍板）：改按实际可见槽数（clamp 4..13）——不满配时格子放大吃掉右侧空白
	# （基地背包装配相位仪"格子太窄+右边还有很多空间"主诉）。13 格满配时与旧公式同值
	# 零回归；切相位仪槽数变化时格子宽度随之变化（有意打破 v21.x"恒同宽"）。
	# 上限90px（宽屏不放大），下限40px（窄屏再窄看不清）。
	var slot_count: int = 0
	for p in _slot_panels:
		if p != null and is_instance_valid(p) and (p as Control).visible:
			slot_count += 1
	var width_basis: int = _FIXED_WIDTH_SLOT_REF if slot_count <= 0 else clampi(slot_count, 4, _FIXED_WIDTH_SLOT_REF)
	var full_total_sep: float = separation * float(width_basis - 1)
	var full_dynamic_w: float = maxf(40.0, (slot_available_w - full_total_sep - slot_overhead) / float(width_basis))
	_slot_width = minf(full_dynamic_w, SLOT_FIXED_SIZE.x)
	for p in _slot_panels:
		if p and is_instance_valid(p):
			p.custom_minimum_size = Vector2(_slot_width, available_h)
			p.size = Vector2(_slot_width, available_h)
	_resync_slot_icon_min_sizes(available_h)

## v9.4 修复：槽位收窄后图标右侧被裁。
## SlotIcon 锚定铺满 SlotIconClip（clip_contents=true），但 custom_minimum_size 在
## _update_slot_panel 时按当时的 _slot_width 写死（如 90 宽时 min=84）；_fit_slots_to_bar
## 随后把 13 槽收窄到 ~72，图标 min 宽仍 84 > 裁剪容器 ~70 → 锚定子节点被钳在 84px、
## 溢出部分被 clip_contents 切掉（战斗卡/符文右侧均缺一块）。宽度变化后必须重同步 min 尺寸。
func _resync_slot_icon_min_sizes(available_h: float) -> void:
	var art_h: float = maxf(18.0, available_h - 4.0)
	var art_w: float = maxf(18.0, _slot_width - 6.0)
	for p in _slot_panels:
		if p == null or not is_instance_valid(p):
			continue
		var tr: TextureRect = _slot_icon_rect(p)
		if tr:
			tr.custom_minimum_size = Vector2(art_w, art_h)

func _update_name_section_width() -> void:
	if name_section == null or not is_instance_valid(name_section):
		return
	var viewport_width: float = get_viewport_rect().size.x
	if viewport_width <= 1.0:
		return
	# v9.3: NameSection 占屏宽比例从 3/13 下调到 1.5/13（13槽满载时给 SlotSection 让出空间）。
	# 旧 3/13 在 1280 宽下 = 295px，扣除 reserved 144 = 151px 给名称区，
	# 但 NameSection 的 size_flags=0（不扩展），实际由 tscn 的 custom_minimum_size=260 主导，
	# 挤压了 SlotSection。现统一用动态计算，名称区收紧到 ~100px，槽位区获得更多空间。
	var reserved: float = 48.0 + 48.0 + 48.0  # 自动按钮 + 图标 + 分隔线余量
	var name_w: float = floor(viewport_width * 1.5 / 13.0 - reserved * 0.5)
	name_section.custom_minimum_size.x = maxf(60.0, name_w)


## v6.22.6: 战斗卡槽不再直显军衔肩章——纯荣誉信息决策价值低，且 Badge 是挂在本
## PanelContainer 上的 anchor 定位子节点，会被 Container 布局强拉成横贯卡面的灰蓝横条
## （CHANGELOG「Container 子节点拉伸」坑的第二处实例，backpack_card_item 同款已修）。
## 军衔信息保留在悬停 tooltip（_format_card_slot_tooltip 的军衔行）。
func _clear_slot_rank_badge(panel: Control) -> void:
	if panel == null:
		return
	var old: Node = panel.get_node_or_null("RankCornerBadge")
	if old != null:
		old.queue_free()


func _slot_name_label(panel: Control) -> Label:
	return panel.get_node_or_null("SlotVBox/SlotTextVBox/SlotNameLabel") as Label


func _slot_cost_label(panel: Control) -> Label:
	return panel.get_node_or_null("SlotVBox/SlotTextVBox/SlotCostLabel") as Label


func _slot_icon_rect(panel: Control) -> TextureRect:
	return panel.get_node_or_null("SlotVBox/SlotIconClip/SlotIcon") as TextureRect


func _apply_slot_bottom_text(panel: Control, name_text: String, cost_text: String) -> void:
	# v7.x：精简模式槽位已无 SlotNameLabel/SlotCostLabel（节点删除），此函数保留仅为兼容旧调用点，
	# 内部安全空转（名称/成本信息已转移到 tooltip + 费用角标）
	var name_l: Label = _slot_name_label(panel)
	var cost_l: Label = _slot_cost_label(panel)
	if name_l:
		name_l.text = name_text
	if cost_l:
		cost_l.text = cost_text


func _apply_slot_card_labels(panel: Control, card: CardResource) -> void:
	if card == null:
		return
	# v7.x：精简模式槽位不再显示底部名称，只设置费用角标（tooltip 提供完整信息）
	# 保留原名称计算逻辑仅用于 tooltip（_format_card_slot_tooltip 已覆盖），此处只设角标
	var cost_badge = CardFrameUi.ensure_cost_corner_badge(panel, true)
	if cost_badge != null:
		cost_badge.energy_value = int(card.energy_cost)
		panel.set_meta("cost_badge_node", cost_badge)
	# v20.13b：槽位重建后恢复部署次数角标（缓存由信号维护，重布局不丢）
	_refresh_deploy_uses_badge(panel)


func _sync_slot_card_frame(panel: Control, card: CardResource) -> void:
	if panel == null or not (panel is PanelContainer):
		return
	var p: PanelContainer = panel as PanelContainer
	if card != null:
		CardFrameUi.apply_slot_chrome(p, card)
	else:
		CardFrameUi.clear_panel_frame(p)
		CardBackgroundUi.clear_overlay(p)


func _sync_slot_card_background(panel: Control, card: CardResource) -> void:
	_sync_slot_card_frame(panel, card)


func _sync_slot_icon(panel: Control, card: CardResource, _law_id: String) -> void:
	var tr: TextureRect = _slot_icon_rect(panel)
	if tr == null:
		return
	var tex: Texture2D = null
	if card != null:
		tex = UiAssetLoader.load_tex(UiAssetLoader.card_icon_path_for_list(card))
	# 可玩性检查修复（2026-09-12）：精简模式槽位无文字区（v7.x 删），空槽只剩纯色底，
	# 观感如贴图丢失。补/撤"＋"占位符与卡图互斥——空槽语义从"色块"变"可放置格"。
	var clip: Control = tr.get_parent()
	var hint: Label = clip.get_node_or_null("EmptyHint") if clip != null else null
	if card != null:
		if hint != null:
			hint.queue_free()
	elif hint == null:
		_add_empty_slot_hint(panel)
	# v9.x（P2-7范围B）：法则格图标分支已随法则槽退役移除（参数保留兼容调用签名）
	var slot_h: float = panel.size.y if panel.size.y > 4.0 else float(SLOT_FIXED_SIZE.y)
	# v7.x：精简模式槽位无底部文字区，图标占满整个可用高度（留 4px 上下边距）
	var art_h: float = maxf(18.0, slot_h - 4.0)
	var art_w: float = _slot_width - 6.0
	if card != null:
		UiAssetLoader.setup_card_unit_icon(tr, tex, Vector2(art_w, art_h), true)
	else:
		UiAssetLoader.setup_texrect_icon(tr, tex, Vector2(art_w, art_h))


## 空槽占位符：icon 区中央半透明"＋"（槽边框色低透明）——空=可放置而非渲染缺陷
func _add_empty_slot_hint(panel: Control) -> void:
	var clip: Control = panel.get_node_or_null("SlotVBox/SlotIconClip")
	if clip == null:
		return
	var bc: Color = _slot_border(String(panel.get_meta("slot_color", "")))
	var hint := Label.new()
	hint.name = "EmptyHint"
	hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(bc.r, bc.g, bc.b, 0.55))
	hint.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.4))
	hint.add_theme_constant_override("outline_size", 2)
	clip.add_child(hint)


func _build_slot_panel(entry: Dictionary) -> PanelContainer:
	var color: String = String(entry.get("color", "green"))
	var color_index: int = int(entry.get("index", -1))
	var law_id: String = String(entry.get("law_id", ""))
	var law_kind: String = String(entry.get("law_kind", ""))
	# v6.2: rune 槽的 card 字段实际是 rune_id (String)，用 Variant 承载避免类型崩溃
	var card: Variant = entry.get("card", null)
	var has_card: bool = card != null and card is CardResource
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(_slot_width, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.set_meta("slot_color", color)
	panel.set_meta("slot_index", color_index)
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# P1-5: 悬停提亮反馈（PanelContainer 没有 Button 的 hover 态，用 modulate 模拟；
	# 只动 rgb 不动 alpha，兼容 v8 关卡限定兵种灰显的 modulate.a=0.4）
	panel.mouse_entered.connect(func() -> void:
		panel.modulate = Color(1.18, 1.18, 1.18, panel.modulate.a))
	panel.mouse_exited.connect(func() -> void:
		panel.modulate = Color(1.0, 1.0, 1.0, panel.modulate.a))
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(1)
	sb.bg_color = _slot_bg(color)
	sb.border_color = _slot_border(color)
	panel.add_theme_stylebox_override("panel", sb)
	var root_v := VBoxContainer.new()
	root_v.name = "SlotVBox"
	root_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_v.add_theme_constant_override("separation", 2)
	var icon_clip := Control.new()
	icon_clip.name = "SlotIconClip"
	icon_clip.clip_contents = true
	icon_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slot_icon_tr := TextureRect.new()
	slot_icon_tr.name = "SlotIcon"
	slot_icon_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_icon_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slot_icon_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot_icon_tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_clip.add_child(slot_icon_tr)
	# v7.x：精简模式删除 SlotTextVBox（名称+成本），只保留图标+费用角标
	root_v.add_child(icon_clip)
	panel.add_child(root_v)
	# v6.2c: 符文槽位（card 字段是 rune_id String，不是 CardResource，必须单独处理）
	var rune_id: String = String(entry.get("rune_id", ""))
	if color == "rune" and not rune_id.is_empty():
		var rune_name: String = RuneDefinitions.get_rune_name(rune_id)
		var rune_def: Dictionary = RuneDefinitions.get_rune(rune_id)
		var rarity_name: String = RuneDefinitions.RARITY_NAMES.get(rune_def.get("rarity", ""), "")
		var short_name: String = rune_name
		if short_name.length() > 4:
			short_name = short_name.substr(0, 4)
		panel.set_meta("card_id", "")
		panel.set_meta("card_type", -1)
		panel.set_meta("law_id", "")
		panel.set_meta("law_kind", "")
		_apply_slot_bottom_text(panel, "◈" + short_name, rarity_name)
		panel.tooltip_text = "符文：%s（%s）\n%s" % [rune_name, rarity_name, RuneDefinitions.get_description(rune_id)]
		var rune_tr: TextureRect = _slot_icon_rect(panel)
		var rune_tex: Texture2D = UiAssetLoader.rune_icon_small(rune_id)
		var slot_h: float = panel.size.y if panel.size.y > 4.0 else float(SLOT_FIXED_SIZE.y)
		# v7.x：精简模式无底部文字区，图标占满（留 4px 边距）
		var art_h: float = maxf(18.0, slot_h - 4.0)
		var art_w: float = _slot_width - 6.0
		UiAssetLoader.setup_texrect_icon(rune_tr, rune_tex, Vector2(art_w, art_h))
		_clear_slot_rank_badge(panel)
		_sync_slot_card_background(panel, null)
		_sync_slot_card_frame(panel, null)
		panel.gui_input.connect(_on_slot_gui_input.bind(panel))
		return panel
	if has_card:
		panel.set_meta("card_id", card.card_id)
		# v7.x 修复：同步存 instance_id（与 _update_slot_panel L207 一致），显示路径用它精确实例取回
		panel.set_meta("instance_id", card.instance_id if (card.instance_id != null and not card.instance_id.is_empty()) else "")
		panel.set_meta("card_type", int(card.card_type))
		panel.set_meta("law_id", "")
		panel.set_meta("law_kind", "")
		_apply_slot_card_labels(panel, card)
		panel.tooltip_text = _format_card_slot_tooltip(color, card)
		if card.card_type == GC.CardType.COMBAT_UNIT:
			var indicator := Polygon2D.new()
			indicator.name = "DeployIndicator"
			indicator.polygon = PackedVector2Array([
				Vector2(-6, 0), Vector2(6, 0), Vector2(0, -10)
			])
			indicator.color = Color(DT.COLOR_GREEN_BRIGHT.r, DT.COLOR_GREEN_BRIGHT.g, DT.COLOR_GREEN_BRIGHT.b, 0.9)
			indicator.position = Vector2(_slot_width * 0.5, -2)
			indicator.visible = false
			panel.add_child(indicator)
	elif not law_id.is_empty():
		panel.set_meta("card_id", "")
		panel.set_meta("card_type", -1)
		panel.set_meta("law_id", law_id)
		panel.set_meta("law_kind", law_kind)
		var cfg: Dictionary = PhaseLaws.get_by_id(law_id) if PhaseLaws else {}
		var law_name: String = String(cfg.get("name", law_id))
		var battle_cost: Dictionary = cfg.get("battle_cost", {})
		var activate_cost: Dictionary = cfg.get("activate_cost", {})
		var battle_energy: int = int(battle_cost.get("energy", 0))
		var activate_nano: int = int(activate_cost.get("nano", 0))
		var cost_line: String = ""
		if battle_energy > 0:
			cost_line = "%d⚡" % battle_energy
		elif activate_nano > 0:
			cost_line = "纳米%d" % activate_nano
		var short_law_name: String = law_name
		if short_law_name.length() > 5:
			short_law_name = short_law_name.substr(0, 5)
		_apply_slot_bottom_text(
			panel,
			("⚔" if law_kind == "active" else "🛡") + short_law_name,
			cost_line
		)
		var detail_lines: Array[String] = []
		detail_lines.append("%s 槽：%s" % [_slot_name(color), law_name])
		detail_lines.append("类型：%s" % ("主动条令" if law_kind == "active" else "被动条令"))
		if battle_energy > 0:
			detail_lines.append("战斗能量消耗：%d⚡" % battle_energy)
		if activate_nano > 0:
			detail_lines.append("激活消耗：纳米%d" % activate_nano)
		var rt: Dictionary = cfg.get("runtime_tags", {})
		if not rt.is_empty():
			var effect: String = String(rt.get("effect", ""))
			var value: float = float(rt.get("value", 0.0))
			var duration: float = float(rt.get("duration", 0.0))
			if not effect.is_empty():
				var effect_line: String = "效果：%s" % effect
				if value != 0.0:
					effect_line += "（值 %.2f）" % value
				if duration > 0.0:
					effect_line += "，持续 %.1f 秒" % duration
				detail_lines.append(effect_line)
		var env_req: Dictionary = cfg.get("env_req", {})
		if not env_req.is_empty():
			var env_parts: Array[String] = []
			if env_req.has("weather"):
				env_parts.append("天气:%s" % _join_env_values("weather", env_req["weather"]))
			if env_req.has("terrain"):
				env_parts.append("地形:%s" % _join_env_values("terrain", env_req["terrain"]))
			if env_req.has("energy_field"):
				env_parts.append("能场:%s" % _join_env_values("energy_field", env_req["energy_field"]))
			if env_req.has("time_of_day"):
				env_parts.append("时段:%s" % _join_env_values("time_of_day", env_req["time_of_day"]))
			if env_parts.size() > 0:
				detail_lines.append("环境要求：" + "；".join(env_parts))
		panel.tooltip_text = "\n".join(detail_lines)
	else:
		panel.set_meta("card_id", "")
		panel.set_meta("card_type", -1)
		panel.set_meta("law_id", "")
		panel.set_meta("law_kind", "")
		_apply_slot_bottom_text(panel, "空", "")
		panel.tooltip_text = "%s 槽（空）" % _slot_name(color)
	_sync_slot_icon(panel, card, law_id)
	_clear_slot_rank_badge(panel)
	_sync_slot_card_background(panel, card)
	_sync_slot_card_frame(panel, card)
	# 统一 gui_input 处理：通过 panel meta 读取当前状态
	# 无论面板初始是卡牌/法则/空，都能正确处理所有情况
	panel.gui_input.connect(_on_slot_gui_input.bind(panel))
	return panel

func _show_instrument_slot_card_detail(card_id: String, instance_id: String, source_panel: Control) -> bool:
	if card_id.is_empty():
		return false
	# v7.x 修复（情报面板看不到强化/改造）：优先用 instance_id 从 InstanceRegistry 取实例对象（带 enhance_level/mods 养成数据）。
	# 根因：原版直接 DefaultCardsData.get_card_by_id(card_id) 取共享模板，模板 enhance_level=0/mods=[]，
	# 导致战斗中点开装配卡显示"未强化/无改造"。
	var card: CardResource = null
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir != null and ir.has_method("get_instance") and not instance_id.is_empty():
		card = ir.get_instance(instance_id)
	# instance_id 取不到（旧面板 meta 无 instance_id / 实例被释放）：回退取该 card_id 的首个实例
	if card == null and ir != null and ir.has_method("get_instances_by_card_id"):
		var _insts: Array = ir.get_instances_by_card_id(card_id)
		if not _insts.is_empty():
			card = ir.get_instance(String(_insts[0]))
	# 最终回退：模板（无养成，仅用于显示卡牌基础信息，不会是常态）
	if card == null:
		card = DefaultCardsData.get_card_by_id(card_id)
	if card == null and PhaseInstrumentManager and PhaseInstrumentManager.has_method("get_card_by_id"):
		card = PhaseInstrumentManager.get_card_by_id(card_id)
	if card == null:
		return false
	# 先隐藏背包的 CardDetailPopup（防止与全局面板同时显示）
	var backpack_panel = NodeFinder.get_backpack_panel()
	if backpack_panel and backpack_panel.has_method("hide_card_detail"):
		backpack_panel.hide_card_detail()
	# 使用全局 CardInfoPanel（挂在 InfoPanelLayer layer=90，不被 HUD 遮挡）
	var info_panel: Control = NodeFinder.get_card_info_panel() as Control
	if info_panel != null:
		if info_panel.has_method("set_panel_mode"):
			info_panel.set_panel_mode(CardInfoPanel.PanelMode.MODE_BATTLEFIELD)
		if info_panel.has_method("show_card_info"):
			var show_pos := source_panel.global_position + Vector2(source_panel.size.x + 8, -200)
			info_panel.show_card_info(card, show_pos)
		return true
	return false


func _on_slot_gui_input(ev: InputEvent, panel: Control) -> void:
	if not is_instance_valid(panel) or not is_instance_valid(self):
		return
	var m_color: String = String(panel.get_meta("slot_color", ""))
	var m_index: int = int(panel.get_meta("slot_index", -1))
	var m_card_id: String = String(panel.get_meta("card_id", ""))
	# v7.x 修复：读取 instance_id（显示路径用它精确实例取回带养成的实例）
	var m_instance_id: String = String(panel.get_meta("instance_id", ""))
	var m_card_type: int = int(panel.get_meta("card_type", -1))
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if Input.is_key_pressed(KEY_SHIFT):
			if _try_unequip_card_slot(m_color, m_index):
				return
		if m_color == "green" and not m_card_id.is_empty():
			var in_battle: bool = BattleManager != null and "battle_active" in BattleManager and BattleManager.battle_active
			var can_deploy: bool = (
				in_battle
				and m_card_type == GC.CardType.COMBAT_UNIT
			)
			if can_deploy and SignalBus:
				# v25.2 pickup 即拦截：能量不足/次数耗尽的槽位不再进入选点模式
				# （与压暗罩同口径），就地抖动 + error 音——省掉一次注定失败的选点往返。
				if _slot_deploy_blocked(panel):
					_reject_deploy_pickup(panel)
					return
				# v7.x 修复（同名卡部署属性相同）：优先传 instance_id（cold_t72#1），让
				# get_loadout_by_platform_card_id 精确匹配到点击的那张实例（含其独立强化/改造）。
				# 原传裸 card_id（cold_t72），同名卡都命中"回退取首个匹配"，导致两张同名卡
				# 部署的是同一个实例 → 战场上强化/改造相同。无 instance_id 时回退 card_id（兼容旧卡）。
				BattleInputState.pending_deploy_platform_card_id = m_instance_id if not m_instance_id.is_empty() else m_card_id
				BattleInputState.pending_deploy_origin_global = panel.get_global_rect().get_center()
				# B2: 鼠标进入部署补拿起音效（键盘路径 begin_deploy_from_slot_index 已有，鼠标路径静音）
				if SignalBus and SignalBus.has_signal("play_sound"):
					SignalBus.play_sound.emit("card_pickup")
				return
			if _show_instrument_slot_card_detail(m_card_id, m_instance_id, panel):
				return
		# v9.x（P2-7范围B）：红/蓝法则格点击分支已随法则槽退役移除（v6.2 起仪器无法则槽）
		instrument_area_clicked.emit()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		if _try_unequip_card_slot(m_color, m_index):
			return

func _slot_name(color: String) -> String:
	match color:
		"green": return "单位"
		"red": return "主动条令"
		"blue": return "被动条令"
		"yellow": return "能量"
		"rune": return "符文"
	return color

## P2-14: 战斗中数字键快捷部署——第 n 个（1 起）有战斗卡的绿槽进入部署选点模式。
## 与点击槽位走同一条 BattleInputState 链路（含 instance_id 精确匹配语义）。
func begin_deploy_from_slot_index(n: int) -> bool:
	var in_battle: bool = BattleManager != null and "battle_active" in BattleManager and BattleManager.battle_active
	if not in_battle or n < 1:
		return false
	var count: int = 0
	for panel in _slot_panels:
		if panel == null or not is_instance_valid(panel):
			continue
		if String(panel.get_meta("slot_color", "")) != "green":
			continue
		if String(panel.get_meta("card_id", "")).is_empty():
			continue
		if int(panel.get_meta("card_type", -1)) != GC.CardType.COMBAT_UNIT:
			continue
		count += 1
		if count == n:
			# v25.2 pickup 即拦截（键盘路径与点击同口径）
			if _slot_deploy_blocked(panel):
				_reject_deploy_pickup(panel)
				return false
			var m_instance_id: String = String(panel.get_meta("instance_id", ""))
			var m_card_id: String = String(panel.get_meta("card_id", ""))
			BattleInputState.pending_deploy_platform_card_id = m_instance_id if not m_instance_id.is_empty() else m_card_id
			BattleInputState.pending_deploy_origin_global = panel.get_global_rect().get_center()
			if SignalBus and SignalBus.has_signal("play_sound"):
				SignalBus.play_sound.emit("card_pickup")
			return true
	return false

func _env_value_label(env_key: String, raw: String) -> String:
	var maps: Dictionary = {
		"weather": {
			"clear": "晴朗",
			"rain": "降雨",
			"storm": "风暴",
			"fog": "迷雾",
		},
		"terrain": {
			"plain": "平原",
			"city": "城市",
			"mountain": "山地",
			"forest": "森林",
		},
		"energy_field": {
			"normal": "常规场",
			"high_field": "高能场",
			"nano_fog": "纳米雾",
			"void_rift": "虚空裂隙",
		},
		"time_of_day": {
			"day": "白天",
			"dusk": "黄昏",
			"night": "夜晚",
		},
	}
	var group: Dictionary = maps.get(env_key, {})
	if group.has(raw):
		return String(group[raw])
	return raw

func _join_env_values(env_key: String, values: Array) -> String:
	var out: Array[String] = []
	for v in values:
		out.append(_env_value_label(env_key, String(v)))
	return ", ".join(out)

func _slot_bg(color: String) -> Color:
	match color:
		"green": return Color(0.04, 0.16, 0.08, 0.92)
		"red": return Color(0.20, 0.05, 0.05, 0.92)
		"blue": return Color(0.05, 0.10, 0.22, 0.92)
		"yellow": return Color(0.18, 0.15, 0.04, 0.92)
		"rune": return Color(0.14, 0.06, 0.22, 0.92)
	return Color(0.07, 0.08, 0.12, 0.92)

func _slot_border(color: String) -> Color:
	match color:
		"green": return Color(0.32, 0.85, 0.45, 0.85)
		"red": return Color(0.90, 0.35, 0.35, 0.85)
		"blue": return Color(0.45, 0.70, 1.00, 0.85)
		"yellow": return Color(0.95, 0.80, 0.35, 0.90)
		"rune": return Color(0.75, 0.45, 0.95, 0.90)
	return Color(0.35, 0.45, 0.60, 0.8)

func _try_unequip_card_slot(color: String, color_index: int) -> bool:
	if _drag_system:
		return _drag_system.try_unequip_card_slot(color, color_index)
	return false

# D3 2026-08-22：删除 _can_drop_data/_drop_data/_get_slot_entry_by_local_pos 三个死转发——
# 原生 DnD 需要拖拽源（_get_drag_data 实现），全项目无任何实现，回调永不触发。

func _slot_to_flat_index(color: String, color_index: int) -> int:
	if _drag_system:
		return _drag_system.slot_to_flat_index(color, color_index)
	return -1

## 刷新相位仪等级标签
func _refresh_phase_level() -> void:
	if phase_level_label == null or not is_instance_valid(phase_level_label):
		return
	if PhaseInstrumentManager == null or not PhaseInstrumentManager.has_method("get_phase_field_xp_progress"):
		return
	var prog: Dictionary = PhaseInstrumentManager.get_phase_field_xp_progress()
	var lv: int = int(prog.get("level", 1))
	var cur_xp: int = int(prog.get("cur_xp", 0))
	var next_xp: int = int(prog.get("next_xp", 0))
	var instrument_name: String = ""
	var instrument_star: int = -1
	var cfg: Dictionary = {}
	if PhaseInstrumentManager.has_method("get_current_instrument"):
		cfg = PhaseInstrumentManager.get_current_instrument()
		instrument_name = String(cfg.get("name", ""))
		instrument_star = int(cfg.get("star", -1))
	var head: String = "相位场"
	if not instrument_name.is_empty() and instrument_star > 0:
		head = "%s ★%d" % [instrument_name, instrument_star]
	if next_xp <= 0:
		phase_level_label.text = "%s Lv.%d MAX" % [head, lv]
	else:
		phase_level_label.text = "%s Lv.%d %d/%d" % [head, lv, cur_xp, next_xp]
	_refresh_instrument_stats()
	# v7.3 性能优化：tooltip 签名缓存。相同 (instrument_id, lv) 跳过 _update_instrument_tooltip 的符文遍历+多行拼接。
	# 原 phase_slots_changed 每次都重建 tooltip 字符串，战斗中频繁装备时累积开销。
	var tooltip_sig: String = "%s|%d" % [String(cfg.get("id", "")), lv]
	if tooltip_sig != _tooltip_last_sig:
		_tooltip_last_sig = tooltip_sig
		_update_instrument_tooltip(cfg)

func _update_instrument_tooltip(cfg: Dictionary) -> void:
	var target: Control = _phase_level_label_container if (_phase_level_label_container and is_instance_valid(_phase_level_label_container)) else name_section
	if target == null:
		return
	if cfg.is_empty():
		target.tooltip_text = ""
		return
	var lines: Array[String] = []
	# 能量属性（v7.x: 移除 energy_output_rate，仅保留能量恢复）
	var recovery_rate: float = float(cfg.get("energy_recovery_rate", 0.3))
	var recovery_ps: float = recovery_rate * 3.0
	lines.append("能量恢复: %.1f/秒" % recovery_ps)
	# v21.x: 移除部署范围显示（功能下线）
	# 槽位配置
	var sc: Dictionary = cfg.get("slot_counts", {})
	var green_n: int = int(sc.get("green", 0))
	var red_n: int = int(sc.get("red", 0))
	var blue_n: int = int(sc.get("blue", 0))
	var yellow_n: int = int(sc.get("yellow", 0))
	var rune_n: int = int(sc.get("rune", 0))
	var slot_parts: Array[String] = []
	if green_n > 0: slot_parts.append("单位%d" % green_n)
	if red_n > 0: slot_parts.append("主动%d" % red_n)
	if blue_n > 0: slot_parts.append("被动%d" % blue_n)
	if yellow_n > 0: slot_parts.append("能量%d" % yellow_n)
	if rune_n > 0: slot_parts.append("符文%d" % rune_n)
	if not slot_parts.is_empty():
		lines.append("槽位: %s" % " ".join(slot_parts))
	# 属性加成（新 properties[] + 旧字段回退）
	var bonus_lines: Array[String] = _collect_cfg_property_lines(cfg)
	if not bonus_lines.is_empty():
		lines.append("属性加成:")
		for bl in bonus_lines:
			lines.append("  %s" % bl)
	# 特殊特性
	var traits: Array = cfg.get("special_traits", [])
	if not traits.is_empty():
		lines.append("特殊特性:")
		for t in traits:
			lines.append("  ✦ %s" % String(t))
	# v6.7: 主动特殊能力（active_ability）— 7星相位仪招牌技能，原装配后 tooltip 漏显示
	var ability: Dictionary = cfg.get("active_ability", {})
	if not ability.is_empty():
		var ability_name: String = String(ability.get("name", ""))
		var ability_desc: String = String(ability.get("description", ""))
		var ability_text: String = ability_desc if not ability_desc.is_empty() else ability_name
		if not ability_name.is_empty() and not ability_desc.is_empty():
			ability_text = "%s：%s" % [ability_name, ability_desc]
		lines.append("主动能力:")
		lines.append("  ⚡ %s" % ability_text)
	# v6.2: 追加符文之语 + 相位场属性点加成
	_append_bonus_tooltip_lines(lines)
	# v7.x: 追加玩家相位师战力分解
	_append_player_master_tooltip_lines(lines)
	target.tooltip_text = "\n".join(lines)

## v6.2: 把符文之语加成和相位场加成格式化追加到 tooltip lines
## 复用 PhaseInstrumentManager.get_all_bonus_summary() 统一数据源
func _append_bonus_tooltip_lines(lines: Array) -> void:
	if PhaseInstrumentManager == null or not PhaseInstrumentManager.has_method("get_all_bonus_summary"):
		return
	var summary: Dictionary = PhaseInstrumentManager.get_all_bonus_summary()
	# v6.2b: 单符文加成
	var rune_stats: Dictionary = summary.get("rune_stats", {})
	var rune_specials: Array = summary.get("rune_specials", [])
	if not rune_stats.is_empty() or not rune_specials.is_empty():
		lines.append("符文加成:")
		if not rune_stats.is_empty():
			var stat_parts: Array[String] = []
			for key in rune_stats.keys():
				var s: String = RuneDefinitions.format_stat_bonus(String(key), float(rune_stats[key]))
				if not s.is_empty():
					stat_parts.append(s)
			if not stat_parts.is_empty():
				lines.append("  " + " | ".join(stat_parts))
		if not rune_specials.is_empty():
			var sp_parts: Array[String] = []
			for sp in rune_specials:
				if not (sp is Dictionary):
					continue
				var sp_name: String = RuneDefinitions.special_display_name(String((sp as Dictionary).get("special", "")))
				var chance := int(round(float((sp as Dictionary).get("chance", 1.0)) * 100.0))
				sp_parts.append("%s(%d%%概率)" % [sp_name, chance])
			if not sp_parts.is_empty():
				lines.append("  " + " | ".join(sp_parts))
	# v6.2b: 符文之语加成（每个带名称）
	var runeword_bonuses: Array = summary.get("runeword_bonuses", [])
	if not runeword_bonuses.is_empty():
		lines.append("符文之语加成:")
		for rw in runeword_bonuses:
			if not (rw is Dictionary):
				continue
			var rw_name: String = String((rw as Dictionary).get("name", ""))
			var rw_stats: Dictionary = (rw as Dictionary).get("stats", {})
			var rw_parts: Array[String] = []
			for key in rw_stats.keys():
				var s: String = RuneDefinitions.format_stat_bonus(String(key), float(rw_stats[key]))
				if not s.is_empty():
					rw_parts.append(s)
			for sp in (rw as Dictionary).get("specials", []):
				if not (sp is Dictionary):
					continue
				var sp_name: String = RuneDefinitions.special_display_name(String((sp as Dictionary).get("special", "")))
				var chance := int(round(float((sp as Dictionary).get("chance", 1.0)) * 100.0))
				rw_parts.append("%s(%d%%概率)" % [sp_name, chance])
			if not rw_parts.is_empty():
				lines.append("  [%s] %s" % [rw_name, " | ".join(rw_parts)])
	# 相位场属性点加成
	var pf_bonus: Dictionary = summary.get("phase_field", {})
	var pf_labels: Dictionary = summary.get("phase_field_labels", {})
	if not pf_bonus.is_empty():
		var pf_parts: Array[String] = []
		for key in pf_bonus.keys():
			var val: float = float(pf_bonus[key])
			var pct := int(round(val * 100.0))
			if pct == 0:
				continue
			var label: String = String(pf_labels.get(key, key))
			pf_parts.append("%s +%d%%" % [label, pct])
		if not pf_parts.is_empty():
			lines.append("相位场加成:")
			lines.append("  " + " | ".join(pf_parts))

## v7.x: 追加玩家相位师战力分解到 tooltip（hover 相位场标签时可见）
func _append_player_master_tooltip_lines(lines: Array) -> void:
	if PhaseInstrumentManager == null:
		return
	var MasterPlayerAssembler = preload("res://scripts/master_player_assembler.gd")
	var ev: Dictionary = {}
	# 优先读缓存（战斗中），否则现算
	if PhaseInstrumentManager.has_method("get_cached_player_master_eval"):
		ev = PhaseInstrumentManager.get_cached_player_master_eval()
	if ev.is_empty():
		ev = MasterPlayerAssembler.evaluate_player_stars(PhaseInstrumentManager)
	if ev.is_empty():
		return
	var raw: float = float(ev.get("raw_total_score", 0.0))
	var compressed: float = 0.0  # v7.x: 已移除压缩，保留变量兼容
	var stars: int = int(ev.get("stars", 3))
	var star_name: String = str(ev.get("star_name", ""))
	lines.append("相位师战力:")
	lines.append("  军团战力：%d · %d★ %s" % [int(raw), stars, star_name])
	# 卡战力简表（单分量公式：每张装备卡加成后战力，前 4 张 + 省略号）
	var card_bd: Array = ev.get("card_breakdown", [])
	if not card_bd.is_empty():
		var parts: Array[String] = []
		var show_n: int = mini(card_bd.size(), 4)
		for i in range(show_n):
			var c: Dictionary = card_bd[i] if card_bd[i] is Dictionary else {}
			var nm: String = String(c.get("name", "?"))
			var lvl: int = int(c.get("level", 0))
			var lvl_str: String = (".Lv%d" % lvl) if lvl > 1 else ""
			parts.append("%s%s:%d" % [nm, lvl_str, int(float(c.get("power", 0.0)))])
		if card_bd.size() > show_n:
			parts.append("...")
		lines.append("  " + " | ".join(parts))


## v7.x: 构建玩家相位师军团战力/星级摘要（单行，供底部栏常驻显示）
## 格式："相位师 军团战力5124 · 4★ 大师"
## 优先读战斗缓存；非战斗时现算（稍慢但保证可见）
func _build_player_master_summary() -> String:
	if PhaseInstrumentManager == null:
		return ""
	# 优先读战斗缓存（battle_manager 在 start_battle 时 set）
	if PhaseInstrumentManager.has_method("get_cached_player_master_eval"):
		var cached: Dictionary = PhaseInstrumentManager.get_cached_player_master_eval()
		if not cached.is_empty():
			return "相位师 军团战力%d · %d★ %s" % [
				int(cached.get("raw_total_score", 0.0)),
				int(cached.get("stars", 3)),
				str(cached.get("star_name", "")),
			]
	# 非战斗场景：现算（不依赖战斗缓存）
	var MasterPlayerAssembler = preload("res://scripts/master_player_assembler.gd")
	return MasterPlayerAssembler.get_player_display_text(PhaseInstrumentManager)


func _refresh_instrument_stats() -> void:
	if instrument_stats_label == null or not is_instance_valid(instrument_stats_label):
		return
	if PhaseInstrumentManager == null or not PhaseInstrumentManager.has_method("get_current_instrument"):
		instrument_stats_label.text = "--"
		if instrument_icon:
			instrument_icon.texture = null
		return
	var cfg: Dictionary = PhaseInstrumentManager.get_current_instrument()
	if cfg.is_empty():
		instrument_stats_label.text = "--"
		if instrument_icon:
			instrument_icon.texture = null
		return
	# v6.2c: 相位仪位置只显示名字 + 星级（统计信息移到 tooltip）
	var inst_name: String = String(cfg.get("name", "未知相位仪"))
	var star: int = int(cfg.get("star", 0))
	if star > 0:
		instrument_stats_label.text = "%s ★%d" % [inst_name, star]
	else:
		instrument_stats_label.text = inst_name
	# v7.x: 追加玩家相位师等级/星级（常驻可见）
	var pm_text: String = _build_player_master_summary()
	if not pm_text.is_empty():
		instrument_stats_label.text += " · " + pm_text
	# 加载相位仪图标
	if instrument_icon:
		var icon_tex: Texture2D = UiAssetLoader.instrument_icon_small(String(cfg.get("id", "")))
		instrument_icon.texture = icon_tex
		instrument_icon.visible = (icon_tex != null)

## v6.2: 构建符文加成精简摘要（用于底部统计行，单行，避免撑高底部栏）
## 格式：" | 符文:攻+15% 生+20% ×2语"（×2语 = 已激活 2 个符文之语）
## 符文之语的名称与详细加成由 tooltip 展示，统计行只给精简计数。
## 无任何符文加成返回空字符串。
func _build_rune_bonus_summary() -> String:
	if PhaseInstrumentManager == null or not PhaseInstrumentManager.has_method("get_rune_bonus"):
		return ""
	var bonus: Dictionary = PhaseInstrumentManager.get_rune_bonus()
	var stats: Dictionary = bonus.get("rune_stats", {})
	var parts: Array[String] = []
	for key in stats.keys():
		var val: float = float(stats[key])
		var pct := int(round(val * 100.0))
		if pct == 0:
			continue
		parts.append(RuneDefinitions.format_stat_bonus(String(key), val))
	# 符文之语只显示激活数量（详情见 tooltip）
	var runeword_count: int = bonus.get("runeword_bonuses", []).size()
	var result: String = ""
	if not parts.is_empty():
		result += " | 符文:" + " ".join(parts)
	if runeword_count > 0:
		result += " ×%d语" % runeword_count
	return result

## v7.x: 计算并返回能量预览信息字符串
## 显示：能量上限(相位仪星级) | 初始能量(=上限) | 净回复/秒 | 相位仪回复值
## 注意：与 EnergyManager._apply_instrument_energy 保持公式一致
func _build_energy_preview_line() -> String:
	if PhaseInstrumentManager == null or not PhaseInstrumentManager.has_method("get_current_instrument"):
		return ""
	# 能量上限 = 基础100 + 相位仪star×200（与 EnergyManager.ENERGY_CAP_PER_STAR 一致）
	var ins: Dictionary = PhaseInstrumentManager.get_current_instrument()
	var pi_star: int = clampi(int(ins.get("star", 1)), 1, 7)
	var energy_max: float = GC.ENERGY_MAX + float(pi_star) * 200.0
	# 初始能量 = 能量上限（满能量开局）
	var energy_start: float = energy_max
	# 相位仪回复值
	var pi_regen: float = 0.0
	if PhaseInstrumentManager.has_method("get_energy_recovery_rate"):
		pi_regen = PhaseInstrumentManager.get_energy_recovery_rate()
	# 净回复 = 基础1.0 + 相位仪回复 − 消耗0.5
	var net_regen: float = GC.ENERGY_REGEN_PER_SEC + pi_regen - GC.PHASE_BASE_DRAIN_PER_SEC
	return " | ⚡上限%d 初始%d 回复%.1f/s(相位%.1f)" % [int(energy_max), int(energy_start), net_regen, pi_regen]

func _collect_cfg_property_lines(cfg: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var props: Array = cfg.get("properties", [])
	if props is Array and not props.is_empty():
		for p in props:
			if not (p is Dictionary):
				continue
			var display: String = String((p as Dictionary).get("display", ""))
			if display.is_empty():
				var pid: String = String((p as Dictionary).get("id", ""))
				display = PhaseInstruments.build_property_display(pid, float((p as Dictionary).get("value", 0.0)))
			if not display.is_empty():
				out.append(display)
		return out
	var dmg: float = float(cfg.get("card_damage_bonus", 0.0))
	var def: float = float(cfg.get("defense_bonus", 0.0))
	var xp_b: float = float(cfg.get("xp_bonus", 0.0))
	var ecr: int = int(cfg.get("energy_cost_reduction", 0))
	if dmg > 0.0: out.append("卡伤 +%.0f%%" % (dmg * 100.0))
	if def > 0.0: out.append("防御 +%.0f%%" % (def * 100.0))
	if xp_b > 0.0: out.append("相位场经验 +%.0f%%" % (xp_b * 100.0))
	if ecr > 0: out.append("能耗 -%d" % ecr)
	return out

## 信号回调
func _on_instrument_slot_clicked(_slot_index: int) -> void:
	instrument_area_clicked.emit()

## 外部调用：强制刷新全部
func refresh() -> void:
	_refresh_all()

## 使相位仪等级标签可点击
func _make_phase_level_label_clickable() -> void:
	if phase_level_label == null or not is_instance_valid(phase_level_label):
		return

	# 创建一个容器包裹标签，使其可点击
	var parent = phase_level_label.get_parent()
	if parent == null:
		return

	_phase_level_label_container = HBoxContainer.new()
	_phase_level_label_container.name = "PhaseLevelLabelContainer"
	_phase_level_label_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_phase_level_label_container.add_theme_constant_override("separation", 4)
	_phase_level_label_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_phase_level_label_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_phase_level_label_container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# B3: 手型已有但无 hover 视觉态——补 modulate 提亮（同槽位 P1-5 模式，只动 rgb 不动 alpha）
	_phase_level_label_container.mouse_entered.connect(func() -> void:
		_phase_level_label_container.modulate = Color(1.18, 1.18, 1.18, _phase_level_label_container.modulate.a))
	_phase_level_label_container.mouse_exited.connect(func() -> void:
		_phase_level_label_container.modulate = Color(1.0, 1.0, 1.0, _phase_level_label_container.modulate.a))
	_phase_level_label_container.z_index = 10
	# 保证有可点区域（避免布局首帧前 combined_minimum_size 为 0 导致点击无效）
	# BU-1：高度从 64 收窄到 28——给 NameSection 里新增的能量条行腾空间
	_phase_level_label_container.custom_minimum_size = Vector2(120, 28)
	_phase_level_label_container.mouse_filter = Control.MOUSE_FILTER_STOP

	var pip_icon := TextureRect.new()
	UiAssetLoader.setup_texrect_icon(pip_icon, UiAssetLoader.ui_icon("icon_phase_instrument"), Vector2(18, 18))

	# 将标签的父容器设置为新的容器
	var label_index = phase_level_label.get_index()
	parent.remove_child(phase_level_label)
	_phase_level_label_container.add_child(pip_icon)
	_phase_level_label_container.add_child(phase_level_label)
	parent.add_child(_phase_level_label_container)
	parent.move_child(_phase_level_label_container, label_index)

	phase_level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phase_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 连接点击事件
	_phase_level_label_container.gui_input.connect(_on_phase_level_label_input)

## 处理相位仪标签点击
func _on_phase_level_label_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		phase_level_label_clicked.emit()
