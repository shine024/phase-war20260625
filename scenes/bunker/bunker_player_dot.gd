extends Node2D
## 余烬要塞 · 光点主角（陈末）v21 P1
## 设计定调：无角色精灵——黑暗基地里唯一的光。孤独感由意象本身传达。
## - 12px 青白圆点 + 呼吸柔光（scale Tween 循环）
## - 精神值联动：tier1(<50) 光圈缩小；tier2(<30) 变暗偏紫
## - move_to(waypoints)：分段 Tween（水平→沿电梯井→水平），信号 arrived

signal arrived

const COL_NORMAL := Color(0.78, 0.98, 1.0)
const COL_DIM_PURPLE := Color(0.62, 0.5, 0.85)

var _sanity_tier := 0
var _move_tween: Tween
var _breath_tween: Tween

func _ready() -> void:
	z_index = 50
	_start_breath()

## ───────────────────── 视觉 ─────────────────────

func _draw() -> void:
	# 外圈柔光
	var glow_alpha := 0.22
	if _sanity_tier == 1:
		glow_alpha = 0.16
	elif _sanity_tier == 2:
		glow_alpha = 0.10
	draw_circle(Vector2.ZERO, 12.0, Color(COL_NORMAL, glow_alpha))
	# 内核实心
	draw_circle(Vector2.ZERO, 5.0, _core_color())

func _core_color() -> Color:
	match _sanity_tier:
		1:
			return Color(0.62, 0.82, 0.9)
		2:
			return COL_DIM_PURPLE
		_:
			return COL_NORMAL

func _start_breath() -> void:
	_stop_breath()
	_breath_tween = create_tween().set_loops()
	_breath_tween.tween_property(self, "scale", Vector2(1.18, 1.18), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breath_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_breath() -> void:
	if _breath_tween and _breath_tween.is_valid():
		_breath_tween.kill()
	_breath_tween = null

## 精神值档位变化（bunker_main 监听 HUD/manager 后调用）
func set_sanity_tier(tier: int) -> void:
	if tier == _sanity_tier:
		return
	_sanity_tier = tier
	queue_redraw()

## ───────────────────── 移动 ─────────────────────

## 沿路径点顺序移动（每段 0.28s）；路径为空或已在终点则立即 arrived。
func move_to(waypoints: Array) -> void:
	_stop_move()
	var pts: Array = []
	for p in waypoints:
		var v := p as Vector2
		if v != null and v.distance_to(position) > 1.0:
			pts.append(v)
	if pts.is_empty():
		arrived.emit()
		return
	_move_tween = create_tween()
	for v in pts:
		_move_tween.tween_property(self, "position", v, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_callback(func(): arrived.emit())

func _stop_move() -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = null

func _exit_tree() -> void:
	_stop_move()
	_stop_breath()
