extends Node2D
## 单位头顶血条：可折叠（紧凑一线）或展开显示，增强视觉效果

const BAR_WIDTH: float = 98.0  # 固定宽度（130 缩减 1/4 → 98）
const HEIGHT_COMPACT: float = 15.0  # 折叠高度（16→15）
const HEIGHT_EXPANDED: float = 21.0  # 展开高度（22→21）

var _ratio: float = 1.0
var _target_ratio: float = 1.0
var _folded: bool = true
var _is_player: bool = true
var _bg: Polygon2D
var _fill: Polygon2D
var _glow: Polygon2D
var _shield_bg: Polygon2D
var _shield_fill: Polygon2D
var _hp_label: Label = null  # HP文本标签（优先使用，自动创建后备）
var _damage_flash: float = 0.0
var _heal_flash: float = 0.0
var _tween: Tween = null
## 预分配多边形数组
var _fill_pts: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _bg_pts: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _glow_pts: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _shield_pts: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _shield_bg_pts: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _shield_gain: float = 0.0  # 护盾获得时的闪光值（0-1）
var _cur_hp: float = 0.0       # 当前HP（用于文本显示）
var _max_hp: float = 100.0     # 最大HP（用于文本显示）

## 血条颜色配置
var _player_colors: Dictionary = {
	"high": Color(0.2, 0.85, 0.4, 1.0),    # 高血量 - 绿色
	"medium": Color(0.9, 0.85, 0.2, 1.0),  # 中血量 - 黄色
	"low": Color(0.95, 0.3, 0.25, 1.0),    # 低血量 - 红色
	"bg": Color(0.12, 0.12, 0.15, 0.95)    # 背景
}

var _enemy_colors: Dictionary = {
	"high": Color(0.95, 0.3, 0.25, 1.0),   # 高血量 - 红色
	"medium": Color(0.95, 0.6, 0.2, 1.0),  # 中血量 - 橙色
	"low": Color(0.8, 0.2, 0.15, 1.0),     # 低血量 - 深红
	"bg": Color(0.12, 0.12, 0.15, 0.95)    # 背景
}

var _selected: bool = false
var _selection_border: Polygon2D = null

func _ready() -> void:
	position = Vector2(0, -40)
	_bg = get_node_or_null("Bg") as Polygon2D
	_fill = get_node_or_null("Fill") as Polygon2D
	_glow = get_node_or_null("Glow") as Polygon2D
	_shield_bg = get_node_or_null("ShieldBg") as Polygon2D
	_shield_fill = get_node_or_null("ShieldFill") as Polygon2D
	_hp_label = get_node_or_null("HpLabel") as Label
	# 如果 HpLabel 不存在，自动创建作为后备
	if _hp_label == null:
		_hp_label = Label.new()
		_hp_label.name = "HpLabel"
		add_child(_hp_label)
	# 统一 Label 文字样式（覆盖 tscn 初始值）
	# 固定白字 + 黑描边：在任何血条底色（玩家绿/敌方红）上都清晰可读
	# Godot 4.x：Label 无 outline_size/outline_color 直接属性，须用主题覆盖；
	# 对齐属性名为 horizontal_alignment/vertical_alignment，值用枚举常量（非裸 int）
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP  # 文字紧靠血条上边
	_hp_label.modulate = Color(1, 1, 1, 1)
	_hp_label.add_theme_constant_override("outline_size", 3)
	_hp_label.add_theme_color_override("outline_color", Color(0, 0, 0, 1.0))
	_hp_label.visible = false
	# 护盾条初始隐藏：单位出生 shield=0，set_shield() 在 shield>0 时才会显示
	if _shield_bg != null:
		_shield_bg.visible = false
	if _shield_fill != null:
		_shield_fill.visible = false
	# 验证关键节点是否存在
	if _bg == null or _fill == null or _shield_bg == null or _shield_fill == null:
		push_error("HpBar: Missing critical nodes! Check tscn structure")
	# v7.x 选中目标高亮：金色描边
	_selection_border = Polygon2D.new()
	_selection_border.name = "SelectionBorder"
	_selection_border.z_index = 15
	_selection_border.visible = false
	add_child(_selection_border)
	_update_selection_border()
	# 监听选中信号
	var sb = get_node_or_null("/root/SignalBus")
	if sb != null and sb.has_signal("unit_selected"):
		sb.unit_selected.connect(_on_unit_selected)
	_update_view()
	set_process(false)

## 选中信号回调
func _on_unit_selected(unit: Node, _is_player: bool, _pos: Vector2) -> void:
	var parent := get_parent()
	var now_selected: bool = (is_instance_valid(unit) and unit == parent)
	if now_selected != _selected:
		_selected = now_selected
		if _selection_border != null:
			_selection_border.visible = _selected

## 外部设置选中态
func set_selected(value: bool) -> void:
	if _selected == value: return
	_selected = value
	if _selection_border != null:
		_selection_border.visible = _selected

## 选中描边
func _update_selection_border() -> void:
	if _selection_border == null: return
	var w: float = BAR_WIDTH + 10.0
	var h: float = HEIGHT_EXPANDED + 6.0
	var x0: float = -w * 0.5
	var y0: float = -h * 0.5
	_selection_border.polygon = PackedVector2Array([
		Vector2(x0, y0), Vector2(x0 + w, y0),
		Vector2(x0 + w, y0 + h), Vector2(x0, y0 + h)
	])
	_selection_border.color = Color(0.98, 0.75, 0.15, 0.85)

func _needs_active_process() -> bool:
	if absf(_ratio - _target_ratio) > 0.001: return true
	if _damage_flash > 0.0 or _heal_flash > 0.0: return true
	if _shield_gain > 0.0: return true
	if _ratio <= 0.3: return true
	return false

func _sync_process_state() -> void:
	set_process(_needs_active_process())

func _process(delta: float) -> void:
	if abs(_ratio - _target_ratio) > 0.001:
		var lerp_speed = 5.0
		_ratio = lerp(_ratio, _target_ratio, lerp_speed * delta)
		_update_fill_only()
	if _damage_flash > 0:
		_damage_flash -= delta * 3.0
		if _damage_flash < 0: _damage_flash = 0
		_update_flash_effect()
	if _heal_flash > 0:
		_heal_flash -= delta * 2.0
		if _heal_flash < 0: _heal_flash = 0
		_update_heal_effect()
	if _shield_gain > 0:
		_shield_gain -= delta * 3.0
		if _shield_gain < 0: _shield_gain = 0
		_update_shield_gain_effect()
	_sync_process_state()

func set_ratio(r: float) -> void:
	_target_ratio = clampf(r, 0.0, 1.0)
	_sync_process_state()

func set_ratio_immediate(r: float) -> void:
	_target_ratio = clampf(r, 0.0, 1.0)
	_ratio = _target_ratio
	_update_view()
	_sync_process_state()

func trigger_damage_flash() -> void:
	_damage_flash = 1.0
	set_process(true)

func trigger_heal_flash() -> void:
	_heal_flash = 1.0
	set_process(true)

func set_folded(folded: bool) -> void:
	_folded = folded
	_update_view()
	_sync_process_state()

func get_bar_height() -> float:
	return HEIGHT_COMPACT if _folded else HEIGHT_EXPANDED

func set_side(is_player: bool) -> void:
	_is_player = is_player
	_update_view()
	# HP 文字固定白色 + 黑描边（在 _ready 设定），不跟随阵营色，
	# 否则白字变绿/红叠在同色血条上看不清。
	_sync_process_state()

## 设置HP文本（当前/最大HP），显示在血条内部
func set_hp_text(cur_hp: float, max_hp: float) -> void:
	_cur_hp = cur_hp
	_max_hp = max_hp
	if _hp_label != null:
		_hp_label.text = "%d/%d" % [int(cur_hp), int(max_hp)]
		_hp_label.visible = true

func _update_view() -> void:
	var h: float = HEIGHT_COMPACT if _folded else HEIGHT_EXPANDED
	var half_w: float = BAR_WIDTH * 0.5
	var half_h: float = h * 0.5

	if _bg:
		_bg_pts.set(0, Vector2(-half_w, -half_h))
		_bg_pts.set(1, Vector2(half_w, -half_h))
		_bg_pts.set(2, Vector2(half_w, half_h))
		_bg_pts.set(3, Vector2(-half_w, half_h))
		_bg.polygon = _bg_pts
		var colors = _player_colors if _is_player else _enemy_colors
		_bg.color = colors.bg

	if _glow:
		_glow_pts.set(0, Vector2(-half_w, -half_h))
		_glow_pts.set(1, Vector2(half_w, -half_h))
		_glow_pts.set(2, Vector2(half_w, half_h))
		_glow_pts.set(3, Vector2(-half_w, half_h))
		_glow.polygon = _glow_pts
		_glow.color = Color(0, 0, 0, 0)

	# 同步更新 HpLabel 位置与字号（居中于血条且不溢出）
	# Label 在 Node2D 父节点下：position 是左上角锚点，anchor 系统无效。
	# 需先设固定 size（与血条等大），再把 position 设为 -size/2，让 Label 框中心
	# 对齐血条局部原点；配合 h_alignment/v_alignment=CENTER，文字就叠在血条正中。
	# 字号随血条高度动态调整：font_size 实际渲染行高约为字号 +4~6px，
	# 折叠态(12px)用 8pt(行高~12px)刚好不溢出；展开态(18px)用 12pt 充满。
	if _hp_label != null:
		var lbl_size := Vector2(BAR_WIDTH, h)
		_hp_label.size = lbl_size
		# position.y 上移 1px：文字 TOP 对齐时 baseline 偏下，整体上提让字紧贴血条顶边
		_hp_label.position = Vector2(-lbl_size.x * 0.5, -lbl_size.y * 0.5 - 1.0)
		# Godot 4.x：font_size 须用主题覆盖（add_theme_font_size_override），非直接属性
		# 折叠态(16px高)用 12pt，展开态(22px高)用 16pt，文字紧靠血条上边
		_hp_label.add_theme_font_size_override("font_size", 12 if _folded else 16)
	
	_update_fill_only()

func _update_fill_only() -> void:
	if _fill == null: return

	var h: float = HEIGHT_COMPACT if _folded else HEIGHT_EXPANDED
	var half_w: float = BAR_WIDTH * 0.5
	var half_h: float = h * 0.5

	var fill_w: float = BAR_WIDTH * _ratio - 4.0
	if fill_w < 0.0: fill_w = 0.0

	_fill_pts.set(0, Vector2(-half_w + 2, -half_h + 2))
	_fill_pts.set(1, Vector2(-half_w + 2 + fill_w, -half_h + 2))
	_fill_pts.set(2, Vector2(-half_w + 2 + fill_w, half_h - 2))
	_fill_pts.set(3, Vector2(-half_w + 2, half_h - 2))
	_fill.polygon = _fill_pts

	var colors = _player_colors if _is_player else _enemy_colors
	var color_key = "high"
	if _ratio <= 0.3: color_key = "low"
	elif _ratio <= 0.6: color_key = "medium"
	_fill.color = colors[color_key]

	if _ratio <= 0.3 and _glow:
		var pulse = (sin(Time.get_ticks_msec() * 0.01) + 1.0) * 0.5
		_glow.color = colors[color_key] * Color(1, 1, 1, 0.3 * pulse)
	else:
		if _glow: _glow.color = Color(0, 0, 0, 0)

func _update_flash_effect() -> void:
	if _fill: _fill.color = Color.WHITE.lerp(_fill.color, 1.0 - _damage_flash)

func _update_heal_effect() -> void:
	if _fill:
		var heal_color = Color(0.4, 1.0, 0.6, 1.0)
		_fill.color = heal_color.lerp(_fill.color, 1.0 - _heal_flash)

## ── 护盾条渲染 ──

func set_shield(shield_value: float, max_hp_val: float) -> void:
	if _shield_bg == null or _shield_fill == null or max_hp_val <= 0: return

	var shield_ratio: float = clampf(shield_value / (max_hp_val * 2.0), 0.0, 1.0)
	# 护盾归零：隐藏护盾条（防止残留显示旧的护盾比例）。>0 时确保可见。
	if shield_ratio <= 0.0:
		_shield_bg.visible = false
		_shield_fill.visible = false
		return
	_shield_bg.visible = true
	_shield_fill.visible = true

	var half_w: float = BAR_WIDTH * 0.5
	var shield_h: float = 6.0

	var sb_pts: PackedVector2Array = _shield_bg_pts
	sb_pts.set(0, Vector2(-half_w + 2, -shield_h - 8.0))
	sb_pts.set(1, Vector2(half_w - 2, -shield_h - 8.0))
	sb_pts.set(2, Vector2(half_w - 2, -shield_h - 2.0))
	sb_pts.set(3, Vector2(-half_w + 2, -shield_h - 2.0))
	_shield_bg.polygon = sb_pts

	var shield_fill_w: float = BAR_WIDTH * shield_ratio - 4.0
	if shield_fill_w < 0.0: shield_fill_w = 0.0
	var sf_pts: PackedVector2Array = _shield_pts
	sf_pts.set(0, Vector2(-half_w + 3, -shield_h - 7.0))
	sf_pts.set(1, Vector2(-half_w + 3 + shield_fill_w, -shield_h - 7.0))
	sf_pts.set(2, Vector2(-half_w + 3 + shield_fill_w, -shield_h - 3.0))
	sf_pts.set(3, Vector2(-half_w + 3, -shield_h - 3.0))
	_shield_fill.polygon = sf_pts

	var shield_color: Color
	if shield_ratio > 0.6: shield_color = Color(0.2, 0.7, 1.0, 0.95)
	elif shield_ratio > 0.3: shield_color = Color(0.3, 0.85, 1.0, 0.9)
	else: shield_color = Color(0.9, 0.7, 0.3, 0.85)
	_shield_fill.color = shield_color

func _update_shield_gain_effect() -> void:
	if _shield_fill == null or _shield_gain <= 0.0: return
	var flash_color: Color = Color.WHITE.lerp(Color(0.3, 0.7, 1.0, 0.9), 1.0 - _shield_gain)
	_shield_fill.color = flash_color
	_shield_fill.modulate = Color(1.0, 1.0, 1.0, 0.5 + _shield_gain * 0.5)

func trigger_shield_gain(amount: float, max_hp_val: float) -> void:
	_shield_gain = 1.0
	set_process(true)
