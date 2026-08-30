extends HBoxContainer
## v24.1 大招双轨释放条——相位仪栏正上方按钮带（BattleBottomBar 内、功能抽屉与相位仪栏之间）：
##   [手动/自动 toggle] [核子轰炸(充能)] [战术核武(armed)] [护盾投射(armed)] [电子屏蔽(armed)]
##
## 默认自动：按钮只读展示就绪状态——把"隐形自动大招系统"变成看得见的东西，这是本条的首要价值；
## 切手动后大招攥住不放（相位仪核子轰炸充能上限 2 / 兵种机制按单位 armed 计数），点击即发。
## 纯时机收益零数值改动；挂机战斗强制自动。仅当次战斗生效：
## battle 开始/结束由 battle_manager 调 UltimateCastController.reset() 复位为自动。

const DT = preload("res://resources/design_tokens.gd")
const UltimateCastControllerScript = preload("res://scripts/battle/ultimate_cast_controller.gd")
const PhaseInstrumentAbilitiesScript = preload("res://managers/battle/phase_instrument_abilities.gd")

## armed/充能轮询周期（组扫描 O(n)，n≤30，开销可忽略）
const POLL_INTERVAL: float = 0.2

## 兵种机制按钮定义（顺序即显示顺序；白名单真身在 UltimateCastController.MANUAL_MECHANISM_IDS）
const MECH_DEFS: Array = [
	{"key": "nuclear_strike", "short": "核武", "name": "战术核武"},
	{"key": "shield_projector", "short": "护盾", "name": "护盾投射"},
	{"key": "jamming_field", "short": "屏蔽", "name": "电子屏蔽"},
]

var _poll_acc: float = 0.0
var _intro_shown := false
var _mode_btn: Button = null
var _ability_box: VBoxContainer = null
var _ability_btn: Button = null      # 核子轰炸（充能制，仅玩家相位仪带该能力时显示）
var _mech_btns: Dictionary = {}      # mech_id -> Button
var _mech_boxes: Dictionary = {}     # mech_id -> VBoxContainer


func _ready() -> void:
	visible = false
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 12)
	_build_mode_btn()
	_build_ability_btn()
	for def in MECH_DEFS:
		_build_mech_btn(def)


func _process(delta: float) -> void:
	var in_battle: bool = BattleManager != null and bool(BattleManager.get("battle_active"))
	visible = in_battle
	if not in_battle:
		return
	if not _intro_shown:
		_intro_shown = true
		FeatureUnlockPopup.show_once("ultimate_cast_bar", "大招手动释放",
			"切到「手动」后，相位仪大招与兵种大招 CD 好了不再自动放，按钮亮起时点击即发。\n可攒 2 发对 Boss 波齐放；挂机与自动模式零损失。")
	_poll_acc += delta
	if _poll_acc < POLL_INTERVAL:
		return
	_poll_acc = 0.0
	_refresh_buttons()


# ─────────────────────────────────────────────
#  构建
# ─────────────────────────────────────────────

func _build_mode_btn() -> void:
	_mode_btn = Button.new()
	_mode_btn.text = "自动"
	_mode_btn.toggle_mode = true
	_mode_btn.custom_minimum_size = Vector2(64, 42)
	_mode_btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	_mode_btn.tooltip_text = "大招自动/手动切换\n自动：CD 好了立即释放（默认，挂机友好）\n手动：大招攥住不放，按钮亮起时点击即发\n仅当前战斗生效"
	_mode_btn.focus_mode = Control.FOCUS_NONE
	_mode_btn.pressed.connect(_on_mode_pressed)
	_apply_mode_style(false)
	add_child(_mode_btn)


func _build_ability_btn() -> void:
	var entry := _make_entry("核爆", "核子轰炸", "核子轰炸：相位仪周期大招（充能上限 2）")
	_ability_box = entry["box"]
	_ability_btn = entry["btn"]
	_ability_btn.pressed.connect(_on_ability_btn_pressed)


func _build_mech_btn(def: Dictionary) -> void:
	var key: String = def["key"]
	var entry := _make_entry(def["short"], def["name"], def["name"] + "：兵种大招（按场上就绪单位计数）")
	_mech_boxes[key] = entry["box"]
	_mech_btns[key] = entry["btn"]
	entry["btn"].pressed.connect(_on_mech_btn_pressed.bind(key))


func _make_entry(short: String, full_name: String, tooltip: String) -> Dictionary:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 1)
	var btn := Button.new()
	btn.text = short
	btn.custom_minimum_size = Vector2(52, 28)
	btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	btn.tooltip_text = tooltip
	btn.focus_mode = Control.FOCUS_NONE
	_apply_dim_style(btn)
	box.add_child(btn)
	var lb := Label.new()
	lb.text = full_name
	lb.add_theme_font_size_override("font_size", DT.FONT_SIZE_XSMALL)
	lb.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(lb)
	add_child(box)
	return {"box": box, "btn": btn, "label": lb}


# ─────────────────────────────────────────────
#  状态刷新（0.2s 轮询）
# ─────────────────────────────────────────────

func _refresh_buttons() -> void:
	# 核子轰炸：仅玩家相位仪当前激活能力带它时显示
	var ab: Dictionary = PhaseInstrumentAbilitiesScript.get_active_ability(PhaseInstrumentAbilitiesScript.Owner.PLAYER)
	var has_nuke: bool = String(ab.get("id", "")) == "nuclear_bombardment"
	_ability_box.visible = has_nuke
	if has_nuke:
		var charge: int = PhaseInstrumentAbilitiesScript.get_nuclear_bombardment_charge()
		_set_ready_visual(_ability_btn, charge > 0)
		_set_badge(_ability_btn, charge)
		_ability_btn.tooltip_text = "核子轰炸：充能 %d/%d%s——点击释放%s" % [
			charge, PhaseInstrumentAbilitiesScript.NUKE_CHARGE_CAP,
			"（满）" if charge >= PhaseInstrumentAbilitiesScript.NUKE_CHARGE_CAP else "",
			"，可双发齐放打爆发" if charge >= 2 else ""]
	# 兵种机制按钮：场上出现对应单位才显示；armed 数亮起 + 角标
	var armed: Dictionary = UltimateCastControllerScript.get_armed_mechanisms()
	for def in MECH_DEFS:
		var key: String = def["key"]
		var box: VBoxContainer = _mech_boxes[key]
		box.visible = UltimateCastControllerScript.has_fielded_mechanism(key)
		if not box.visible:
			continue
		var btn: Button = _mech_btns[key]
		var count: int = int(armed.get(key, {}).get("count", 0))
		_set_ready_visual(btn, count > 0)
		_set_badge(btn, count)


## 就绪态切换（带 memo，避免每轮 poll 重刷样式）
func _set_ready_visual(btn: Button, ready: bool) -> void:
	if bool(btn.get_meta("is_ready", false)) == ready:
		return
	btn.set_meta("is_ready", ready)
	if ready:
		_apply_ready_style(btn)
	else:
		_apply_dim_style(btn)


func _set_badge(btn: Button, count: int) -> void:
	var bg := btn.get_node_or_null("BadgeBg") as ColorRect
	var bd := btn.get_node_or_null("Badge") as Label
	if count <= 0:
		if bg != null:
			bg.visible = false
		return
	if bg == null:
		bg = ColorRect.new()
		bg.name = "BadgeBg"
		bg.color = Color(0.95, 0.25, 0.25, 0.95)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.anchor_left = 1.0
		bg.anchor_right = 1.0
		bg.offset_left = -15
		bg.offset_right = -1
		bg.offset_top = -4
		bg.offset_bottom = 10
		btn.add_child(bg)
		bd = Label.new()
		bd.name = "Badge"
		bd.add_theme_font_size_override("font_size", DT.FONT_SIZE_XSMALL)
		bd.add_theme_color_override("font_color", Color.WHITE)
		bd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bd.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.add_child(bd)
	bg.visible = true
	bd.text = str(count)


# ─────────────────────────────────────────────
#  交互
# ─────────────────────────────────────────────

func _on_mode_pressed() -> void:
	var in_battle: bool = BattleManager != null and bool(BattleManager.get("battle_active"))
	if not in_battle:
		_mode_btn.set_pressed_no_signal(false)
		_apply_mode_style(false)
		UltimateCastControllerScript.set_manual_mode(false)
		return
	# 挂机战斗恒自动：AFK 运行中拒绝切手动（挂机玩家不看屏幕，攥住大招=白丢输出）
	if _mode_btn.is_pressed() and _is_afk_running():
		_mode_btn.set_pressed_no_signal(false)
		_apply_mode_style(false)
		UltimateCastControllerScript.set_manual_mode(false)
		_toast("挂机战斗恒为自动释放")
		return
	var manual: bool = _mode_btn.is_pressed()
	UltimateCastControllerScript.set_manual_mode(manual)
	_apply_mode_style(manual)
	if manual:
		_toast("大招手动释放：CD 好了不再自动放，按钮亮起时点击即发")
	else:
		_toast("大招恢复自动释放")
	_refresh_buttons()


func _on_ability_btn_pressed() -> void:
	if not UltimateCastControllerScript.is_manual():
		_toast("当前为自动释放（左侧可切手动）")
		return
	var result: String = PhaseInstrumentAbilitiesScript.manual_release_nuclear_bombardment()
	match result:
		"fired":
			pass  # 演出与播报由引擎（_fire_nuclear_bombardment）负责
		"no_charge":
			_toast("核子轰炸充能中…")
		"no_target":
			_toast("暂无目标，充能保留")


func _on_mech_btn_pressed(mech_id: String) -> void:
	if not UltimateCastControllerScript.is_manual():
		_toast("当前为自动释放（左侧可切手动）")
		return
	var result: String = UltimateCastControllerScript.release_mechanism(mech_id)
	match result:
		"fired":
			pass
		"none_armed":
			_toast("该大招尚未就绪")
		"no_target":
			_toast("暂无有效目标，充能保留")


## 挂机检测：向上找主场景的 _afk_manager（AFKModeManager.is_running）
func _is_afk_running() -> bool:
	var n: Node = self
	while n != null:
		var afk = n.get("_afk_manager")
		if afk != null and is_instance_valid(afk) and bool(afk.get("is_running")):
			return true
		n = n.get_parent()
	return false


func _toast(msg: String) -> void:
	if SignalBus != null and SignalBus.has_signal("show_toast"):
		SignalBus.show_toast.emit(msg)


# ─────────────────────────────────────────────
#  样式（仿 bottom_instrument_bar AutoDeployBtn / hud-btn 语言）
# ─────────────────────────────────────────────

func _apply_mode_style(active: bool) -> void:
	if active:
		_mode_btn.text = "手动"
		_mode_btn.add_theme_stylebox_override("normal",
			_mk_style(Color(0.12, 0.32, 0.18, 0.95), DT.COLOR_HEALTH, 1))
		_mode_btn.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	else:
		_mode_btn.text = "自动"
		_mode_btn.add_theme_stylebox_override("normal",
			_mk_style(Color(0.08, 0.12, 0.18, 0.85), DT.COLOR_BORDER, 1))
		_mode_btn.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)


func _apply_dim_style(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal",
		_mk_style(Color(0.08, 0.12, 0.18, 0.8), DT.COLOR_BORDER, 1))
	btn.add_theme_stylebox_override("hover",
		_mk_style(Color(0.13, 0.2, 0.3, 0.95),
			Color(DT.COLOR_ACCENT_CYAN.r, DT.COLOR_ACCENT_CYAN.g, DT.COLOR_ACCENT_CYAN.b, 0.6), 1))
	btn.add_theme_stylebox_override("pressed",
		_mk_style(Color(0.05, 0.08, 0.12, 0.95), DT.COLOR_ACCENT_CYAN, 1))
	btn.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	btn.add_theme_color_override("font_hover_color", DT.COLOR_TEXT_BRIGHT)


## 就绪态：琥珀亮边 + 金字（与部署绿/通用青区分，"大招好了"专属语义）
func _apply_ready_style(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal",
		_mk_style(Color(0.3, 0.2, 0.05, 0.95), DT.COLOR_AMBER, 2))
	btn.add_theme_stylebox_override("hover",
		_mk_style(Color(0.42, 0.28, 0.07, 1.0), DT.COLOR_AMBER_SOFT, 2))
	btn.add_theme_stylebox_override("pressed",
		_mk_style(Color(0.2, 0.13, 0.03, 1.0), DT.COLOR_AMBER_SOFT, 2))
	btn.add_theme_color_override("font_color", DT.COLOR_GOLD)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)


func _mk_style(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(bw)
	sb.bg_color = bg
	sb.border_color = border
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	return sb
