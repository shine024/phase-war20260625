extends Control
## v26.13(D-2): 部署定向指令轮盘——长按我方单位弹出，三向指令：
##   集火（进入点选模式，指定必打目标）/ 守住（锁定当前目标不主动切换）/ 自由（清除指令）
## 约束（DESIGN_COMBAT_DECISION_B0.md）：单场同时生效指令 ≤2；挂机模式不弹；
## 单位死亡指令随节点消失。打开时点击轮盘外 = 取消。

signal command_chosen(cmd: String)

const DT = preload("res://resources/design_tokens.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")

const _CMD_DEFS := [
	{"cmd": "focus", "label": "集火", "tip": "下一步点击一个敌方单位：该单位必先攻击它（候选中优先）", "color_ref": "violet"},
	{"cmd": "hold", "label": "守住", "tip": "锁定当前目标，不再主动切换索敌", "color_ref": "cyan"},
	{"cmd": "free", "label": "自由", "tip": "清除该单位的全部指令，恢复默认索敌", "color_ref": "dim"},
]
const _ARC_RADIUS := 64.0

var _buttons: Array[Button] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP  # 全屏截击：轮盘外点击=取消
	visible = false
	_build()

func _build() -> void:
	for def in _CMD_DEFS:
		var btn := Button.new()
		btn.text = String(def["label"])
		btn.tooltip_text = String(def["tip"])
		btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		btn.custom_minimum_size = Vector2(64, 40)
		var col: Color = DT.COLOR_VIOLET if def["color_ref"] == "violet" else (
			DT.COLOR_CYAN_TECH if def["color_ref"] == "cyan" else DT.COLOR_TEXT_DIM)
		var styles := PanelStyles.make_button_styles(col)
		btn.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
		btn.add_theme_color_override("font_hover_color", DT.COLOR_HOVER_WHITE)
		btn.add_theme_color_override("font_pressed_color", DT.COLOR_HOVER_WHITE)
		btn.add_theme_color_override("font_focus_color", DT.COLOR_HOVER_WHITE)
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			if styles.has(state):
				btn.add_theme_stylebox_override(state, styles[state])
		btn.pressed.connect(_on_cmd_pressed.bind(String(def["cmd"])))
		add_child(btn)
		_buttons.append(btn)

## 在锚点（父容器局部坐标，单位所在处）周围以扇形展开
func open(anchor_screen: Vector2) -> void:
	if _buttons.size() != _CMD_DEFS.size():
		return
	# 三向扇形：集火左上 / 守住右上 / 自由正下（角度以锚点为圆心）
	var angles := [-PI * 0.75, -PI * 0.25, PI * 0.5]
	# 父容器（BattleContainer）局部域尺寸——按钮钳制其内，防贴边单位把按钮顶出屏
	var area := get_parent_area_size()
	for i in range(_buttons.size()):
		var b := _buttons[i]
		var pos: Vector2 = anchor_screen + Vector2(cos(angles[i]), sin(angles[i])) * _ARC_RADIUS \
			- b.custom_minimum_size * 0.5
		pos.x = clampf(pos.x, 0.0, maxf(0.0, area.x - b.custom_minimum_size.x))
		pos.y = clampf(pos.y, 0.0, maxf(0.0, area.y - b.custom_minimum_size.y))
		b.position = pos
	# 全屏遮罩尺寸跟随父容器（set_anchors_and_offsets_preset 连带归零 offsets，
	# 确保"点轮盘外取消"的全屏截击不因根矩形残缺而失效）
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = true

func close() -> void:
	visible = false

func _gui_input(event: InputEvent) -> void:
	# 轮盘区域外的任何点击=取消（按钮自身消费自己的点击）
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			close()
			accept_event()

func _on_cmd_pressed(cmd: String) -> void:
	close()
	command_chosen.emit(cmd)
