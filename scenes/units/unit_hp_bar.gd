extends Node2D
## 单位头顶血条：可折叠（紧凑一线）或展开显示，增强视觉效果

const BAR_WIDTH: float = 44.0
const HEIGHT_COMPACT: float = 4.0
const HEIGHT_EXPANDED: float = 8.0

var _ratio: float = 1.0
var _target_ratio: float = 1.0
var _folded: bool = true
var _is_player: bool = true
var _bg: Polygon2D
var _fill: Polygon2D
var _glow: Polygon2D
var _damage_flash: float = 0.0
var _heal_flash: float = 0.0
var _tween: Tween = null
## 预分配多边形数组（避免每帧 PackedVector2Array 分配）
var _fill_pts: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _bg_pts: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _glow_pts: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])

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

func _ready() -> void:
	position = Vector2(0, -40)
	_bg = get_node_or_null("Bg") as Polygon2D
	_fill = get_node_or_null("Fill") as Polygon2D
	_glow = get_node_or_null("Glow") as Polygon2D
	_update_view()
	set_process(false)

func _needs_active_process() -> bool:
	if absf(_ratio - _target_ratio) > 0.001:
		return true
	if _damage_flash > 0.0 or _heal_flash > 0.0:
		return true
	# 低血量脉动发光依赖每帧刷新
	if _ratio <= 0.3:
		return true
	return false

func _sync_process_state() -> void:
	set_process(_needs_active_process())

func _process(delta: float) -> void:
	# 平滑过渡血量变化
	if abs(_ratio - _target_ratio) > 0.001:
		var lerp_speed = 5.0
		_ratio = lerp(_ratio, _target_ratio, lerp_speed * delta)
		_update_fill_only()

	# 处理伤害闪烁效果
	if _damage_flash > 0:
		_damage_flash -= delta * 3.0
		if _damage_flash < 0:
			_damage_flash = 0
		_update_flash_effect()

	# 处理治疗闪烁效果
	if _heal_flash > 0:
		_heal_flash -= delta * 2.0
		if _heal_flash < 0:
			_heal_flash = 0
		_update_heal_effect()

	_sync_process_state()

## 设置血量比例（带动画）
func set_ratio(r: float) -> void:
	_target_ratio = clampf(r, 0.0, 1.0)
	_sync_process_state()

## 立即设置血量比例（无动画）
func set_ratio_immediate(r: float) -> void:
	_target_ratio = clampf(r, 0.0, 1.0)
	_ratio = _target_ratio
	_update_view()
	_sync_process_state()

## 触发伤害闪烁效果
func trigger_damage_flash() -> void:
	_damage_flash = 1.0
	set_process(true)

## 触发治疗闪烁效果
func trigger_heal_flash() -> void:
	_heal_flash = 1.0
	set_process(true)

func set_folded(folded: bool) -> void:
	_folded = folded
	_update_view()
	_sync_process_state()

## 查询当前血条渲染高度（折叠=4px / 展开=8px）
## 供 buff_strip 等卡底元素计算避让间距用，避免硬编码与折叠态脱钩
func get_bar_height() -> float:
	return HEIGHT_COMPACT if _folded else HEIGHT_EXPANDED

func set_side(is_player: bool) -> void:
	_is_player = is_player
	_update_view()
	_sync_process_state()

func _update_view() -> void:
	var h: float = HEIGHT_COMPACT if _folded else HEIGHT_EXPANDED
	var half_w: float = BAR_WIDTH * 0.5
	var half_h: float = h * 0.5

	# 更新背景
	if _bg:
		_bg_pts.set(0, Vector2(-half_w, -half_h))
		_bg_pts.set(1, Vector2(half_w, -half_h))
		_bg_pts.set(2, Vector2(half_w, half_h))
		_bg_pts.set(3, Vector2(-half_w, half_h))
		_bg.polygon = _bg_pts
		var colors = _player_colors if _is_player else _enemy_colors
		_bg.color = colors.bg

	# 更新发光效果
	if _glow:
		_glow_pts.set(0, Vector2(-half_w, -half_h))
		_glow_pts.set(1, Vector2(half_w, -half_h))
		_glow_pts.set(2, Vector2(half_w, half_h))
		_glow_pts.set(3, Vector2(-half_w, half_h))
		_glow.polygon = _glow_pts
		_glow.color = Color(0, 0, 0, 0)  # 初始不发光

	_update_fill_only()

func _update_fill_only() -> void:
	if _fill == null:
		return

	var h: float = HEIGHT_COMPACT if _folded else HEIGHT_EXPANDED
	var half_w: float = BAR_WIDTH * 0.5
	var half_h: float = h * 0.5

	# 计算填充宽度
	var fill_w: float = BAR_WIDTH * _ratio - 2.0
	if fill_w < 0.0:
		fill_w = 0.0

	# 更新填充多边形（复用预分配数组）
	_fill_pts.set(0, Vector2(-half_w + 1, -half_h + 1))
	_fill_pts.set(1, Vector2(-half_w + 1 + fill_w, -half_h + 1))
	_fill_pts.set(2, Vector2(-half_w + 1 + fill_w, half_h - 1))
	_fill_pts.set(3, Vector2(-half_w + 1, half_h - 1))
	_fill.polygon = _fill_pts

	# 根据血量百分比选择颜色
	var colors = _player_colors if _is_player else _enemy_colors
	var color_key = "high"
	if _ratio <= 0.3:
		color_key = "low"
	elif _ratio <= 0.6:
		color_key = "medium"

	_fill.color = colors[color_key]

	# 低血量时添加脉动效果
	if _ratio <= 0.3:
		var pulse = (sin(Time.get_ticks_msec() * 0.01) + 1.0) * 0.5
		if _glow:
			_glow.color = colors[color_key] * Color(1, 1, 1, 0.3 * pulse)
	else:
		if _glow:
			_glow.color = Color(0, 0, 0, 0)

func _update_flash_effect() -> void:
	if _fill:
		_fill.color = Color.WHITE.lerp(_fill.color, 1.0 - _damage_flash)

func _update_heal_effect() -> void:
	if _fill:
		var heal_color = Color(0.4, 1.0, 0.6, 1.0)
		_fill.color = heal_color.lerp(_fill.color, 1.0 - _heal_flash)
