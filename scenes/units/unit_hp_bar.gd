extends Node2D
## 单位头顶血条：固定单一形态（不再随选中展开/折叠）。HP 数字常显，选中只靠金色描边。

const BAR_WIDTH: float = 98.0  # 固定宽度（130 缩减 1/4 → 98）
const BAR_HEIGHT: float = 15.0  # 固定高度（v8.x: 去掉展开机制，统一用此值）
# 以下两个常量保留为旧值仅向后兼容（外部 get_bar_height 仍引用 HEIGHT_EXPANDED），
# 实际渲染已统一到 BAR_HEIGHT，不再随选中变化。
const HEIGHT_COMPACT: float = BAR_HEIGHT
const HEIGHT_EXPANDED: float = BAR_HEIGHT

# ── 血条上方状态图标行（buff/debuff，v9.x 新增）──
# 数据由 UnitStatusCollector 从 parent（单位）meta 收集，单位 _physics_process 每 0.3s 调 refresh_status_icons。
const STATUS_ICON_SIZE: float = 11.0        # 基准图标边长（px）
const STATUS_ICON_GAP: float = 2.0          # 图标间距
const STATUS_ROW_Y: float = -22.0           # 图标行垂直中心（护盾条运行时顶约 y=-14，留 8px）
const STATUS_ROW_MAX_W: float = BAR_WIDTH - 4.0  # 行宽上限，超出自适应缩小
const STATUS_DEBUFF_BUFF_GAP: float = 4.0   # debuff 组与 buff 组之间的额外间隔
const STATUS_MAX_ICONS: int = 10            # 单位最多显示图标数（超出按 debuff 优先丢弃）
const STATUS_MIN_ICON_SIZE: float = 5.0     # 自适应缩放下限

var _ratio: float = 1.0
var _target_ratio: float = 1.0
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

# ── 状态图标行（v9.x）──
var _status_entries: Array = []   # collector 返回的当前状态列表 [{kind,stacks,color,is_buff}]
var _status_layout: Array = []    # 排好序 + 算好 rect 的渲染列表（_draw 遍历它）
var _status_sig: String = ""      # signature 去重（状态不变则跳过重绘）
var _status_font: Font = null     # 层数数字字体（_ready 从 HpLabel 缓存）

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
	# 监听选中信号（SignalBus 为 autoload 全局标识符，比 /root/ 绝对路径更稳）
	if SignalBus.has_signal("unit_selected"):
		SignalBus.unit_selected.connect(_on_unit_selected)
	_update_view()
	# 缓存默认字体用于绘制状态层数数字（Node2D 无 get_theme_default_font，从 HpLabel 取）
	if _hp_label != null:
		_status_font = _hp_label.get_theme_default_font()
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
	var h: float = BAR_HEIGHT + 6.0
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
	# v8.x: 用 _target_ratio 判断低血量脉动需求（lerp 收敛后 _ratio==_target_ratio，两者等价；
	# 但掉血瞬间 _target_ratio 先变，用它能立刻激活 process 驱动脉动）
	if _target_ratio <= 0.3: return true
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
	# v8.x: 低血量脉动——血条 lerp 收敛后仍需每帧刷新 glow，否则 sin 脉动冻在末帧形同虚设。
	# 用 _target_ratio 判断（即时响应掉血），避开 lerp 未收敛的过渡帧。
	if _target_ratio <= 0.3:
		_update_low_hp_pulse()
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

## v8.x: 血条已固定单一形态，set_folded 保留为空操作以兼容外部调用方（不再影响渲染）。
func set_folded(_folded: bool) -> void:
	pass

func get_bar_height() -> float:
	return BAR_HEIGHT

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
	var h: float = BAR_HEIGHT
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
		# v8.x: 血条固定单一高度(15px)，字号恒定 12pt
		_hp_label.add_theme_font_size_override("font_size", 12)
	
	_update_fill_only()

func _update_fill_only() -> void:
	if _fill == null: return

	var h: float = BAR_HEIGHT
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

	# v8.x: 低血量 glow 脉动统一交给 _update_low_hp_pulse（每帧由 _process 驱动），
	# 此处仅在非低血量时清零 glow，避免满血时残留发光。
	if _ratio > 0.3 and _glow:
		_glow.color = Color(0, 0, 0, 0)

## v8.x: 低血量（≤30%）glow 红色脉动——独立于 fill 几何，每帧只改 _glow.color。
## 修复原 bug：脉动公式原写在 _update_fill_only 里，但该函数仅在血条 lerp 变化时调用，
## lerp 收敛后脉动冻在末帧。现由 _process 的低血量分支每帧驱动，脉动持续可见。
func _update_low_hp_pulse() -> void:
	if _glow == null:
		return
	var colors = _player_colors if _is_player else _enemy_colors
	var low_c: Color = colors.low
	# 频率 0.008 → 周期约 785ms，比原 0.01(628ms) 稍慢，更有"警报"节奏感
	var pulse: float = (sin(Time.get_ticks_msec() * 0.008) + 1.0) * 0.5
	# 峰值 alpha 0.55（原 0.3 偏弱，战场上看不清），最低保留 0.15 底亮避免完全熄灭
	var a: float = lerpf(0.15, 0.55, pulse)
	_glow.color = Color(low_c.r, low_c.g, low_c.b, a)

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

# ============================================================================
#  v9.x 血条上方状态图标行（buff/debuff）
#  渲染由单位 _physics_process 每 0.3s 调 refresh_status_icons 驱动；
#  signature 去重，仅状态变化时 queue_redraw。
# ============================================================================

## 外部驱动：收集 parent（单位）当前状态，变化才重绘。parent 无效时清空。
func refresh_status_icons() -> void:
	var unit: Node = get_parent()
	if unit == null or not is_instance_valid(unit):
		if not _status_layout.is_empty() or _status_sig != "":
			_status_entries.clear()
			_status_layout.clear()
			_status_sig = ""
			queue_redraw()
		return
	var entries: Array = UnitStatusCollector.collect(unit)
	var sig: String = UnitStatusCollector.signature(entries)
	if sig == _status_sig:
		return  # 状态未变，跳过重绘
	_status_sig = sig
	_status_entries = entries
	_layout_status_row()
	queue_redraw()

## 计算每个图标的 rect：debuff 在左、buff 在右，组间额外间隔；总宽超限自适应缩小。
func _layout_status_row() -> void:
	_status_layout.clear()
	if _status_entries.is_empty():
		return
	var debuff: Array = []
	var buff: Array = []
	for e in _status_entries:
		if bool((e as Dictionary).get("is_buff", false)):
			buff.append(e)
		else:
			debuff.append(e)
	var ordered: Array = debuff + buff
	var count: int = mini(ordered.size(), STATUS_MAX_ICONS)
	var debuff_kept: int = mini(debuff.size(), count)
	var buff_kept: int = count - debuff_kept
	var both_groups: bool = debuff_kept > 0 and buff_kept > 0
	var icon_size: float = STATUS_ICON_SIZE
	var gap: float = STATUS_ICON_GAP
	var total_w: float = float(count) * icon_size + float(maxi(count - 1, 0)) * gap
	if both_groups:
		total_w += STATUS_DEBUFF_BUFF_GAP
	# 自适应缩小（复用 card_grid_buff_strip 的算法思路）
	if total_w > STATUS_ROW_MAX_W:
		var sc: float = STATUS_ROW_MAX_W / total_w
		icon_size = maxf(icon_size * sc, STATUS_MIN_ICON_SIZE)
	# 缩放后重算总宽用于居中
	total_w = float(count) * icon_size + float(maxi(count - 1, 0)) * gap
	if both_groups:
		total_w += STATUS_DEBUFF_BUFF_GAP
	var x_cursor: float = -total_w * 0.5
	for i in range(count):
		var e: Dictionary = ordered[i]
		e["rect"] = Rect2(x_cursor, STATUS_ROW_Y - icon_size * 0.5, icon_size, icon_size)
		_status_layout.append(e)
		x_cursor += icon_size
		if i < count - 1:
			x_cursor += gap
			# debuff→buff 组界处加额外间隔
			if both_groups and i == debuff_kept - 1:
				x_cursor += STATUS_DEBUFF_BUFF_GAP

## 血条根 Node2D 的 _draw：仅画状态图标行（HP/护盾由子 Polygon2D 节点自绘，互不干扰）。
func _draw() -> void:
	if _status_layout.is_empty():
		return
	for e in _status_layout:
		var d: Dictionary = e
		var r: Rect2 = d.get("rect", Rect2())
		var kind: int = int(d.get("kind", -1))
		var col: Color = d.get("color", Color.WHITE)
		var cx: float = r.position.x + r.size.x * 0.5
		var cy: float = r.position.y + r.size.y * 0.5
		var s: float = minf(r.size.x, r.size.y) * 0.42
		UnitStatusCollector.draw_status_icon(kind, self, cx, cy, s, col)
		# 可叠加状态显示层数（右下角小数字，白字 + 黑描边）
		var stacks: int = int(d.get("stacks", 0))
		if stacks > 1 and _status_font != null and UnitStatusCollector.is_stackable(kind):
			var txt: String = str(stacks)
			var fs: int = 6
			var ts: Vector2 = _status_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs)
			var pos: Vector2 = Vector2(r.position.x + r.size.x - ts.x, r.position.y + r.size.y - ts.y)
			var outline := Color(0.0, 0.0, 0.0, 0.95)
			draw_string(_status_font, pos + Vector2(1, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, outline)
			draw_string(_status_font, pos + Vector2(-1, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, outline)
			draw_string(_status_font, pos + Vector2(0, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, outline)
			draw_string(_status_font, pos + Vector2(0, -1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, outline)
			draw_string(_status_font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, Color.WHITE)
