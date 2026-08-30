extends Node2D
## v21 P0: 光环范围指示器——战术光环源部署瞬间短亮范围圈，0.85s 淡出自毁。
## 纯视觉 telegraph：不参与任何玩法判定；motion_reduce（无障碍）时完全不生成。
##
## 生成时机：由 AuraManager.register_aura / ModAuraHandler.apply_mod_auras 在 setup 期调用
## spawn_for_unit，内部自延迟到"单位已入树"后挂到单位父节点（部署槽位 snap 后取真实坐标）。
## 延迟回调三重守卫：is_instance_valid / is_inside_tree / is_queued_for_deletion。

const DT = preload("res://resources/design_tokens.gd")
const Layout = preload("res://scripts/card_grid_battle_layout.gd")

const DURATION := 0.85
const PLAYER_COLOR := Color(0.35, 0.85, 1.0, 0.6)
const ENEMY_COLOR := Color(1.0, 0.45, 0.3, 0.6)
## 行距基准（card_grid_battle_layout.ROW_Y_OFFSETS 差值 65-75 的中值，装饰用途无需精确）
const ROW_SPACING_PX := 70.0

var _rx := 100.0
var _ry := 60.0
var _fill := Color(0.35, 0.85, 1.0, 0.07)
var _line := PLAYER_COLOR
var _life := 0.0


func configure(range_cells: int, is_player: bool) -> void:
	var pitch: float = Layout.slot_pitch_px()
	var r: float = float(maxi(1, range_cells)) + 0.55
	_rx = r * pitch
	_ry = r * ROW_SPACING_PX
	_line = PLAYER_COLOR if is_player else ENEMY_COLOR
	_fill = Color(_line.r, _line.g, _line.b, 0.07)
	modulate.a = 1.0


func _draw() -> void:
	# 椭圆 = 圆经 Y 压缩（横向槽距 pitch、纵向行距 ~70px 的比例差）
	var sy: float = _ry / maxf(0.01, _rx)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, sy))
	draw_circle(Vector2.ZERO, _rx, _fill)
	draw_arc(Vector2.ZERO, _rx, 0.0, TAU, 64, _line, 2.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _process(delta: float) -> void:
	_life += delta
	if _life >= DURATION:
		queue_free()
		return
	modulate.a = clampf(1.0 - (_life / DURATION), 0.0, 1.0)


## 部署期入口：内部延迟到单位入树后再挂节点（spawn 系统在 setup 之后才 add_child + 写槽位 meta）。
## 调用方不需要关心时序，setup 期直接调用即可。
static func spawn_for_unit(unit: Node2D, range_cells: int) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if range_cells < 0:
		return
	if DT.is_motion_reduce():
		return
	var ml: Variant = Engine.get_main_loop()
	if ml == null or not (ml is SceneTree):
		return
	var cb := func() -> void:
		if not is_instance_valid(unit) or not unit.is_inside_tree() or unit.is_queued_for_deletion():
			return
		var scr: Script = load("res://scenes/effects/aura_range_indicator.gd")
		if scr == null:
			return
		var ind: Node2D = scr.new()
		ind.configure(range_cells, bool(unit.get("is_player")) if "is_player" in unit else true)
		var parent: Node = unit.get_parent()
		if parent == null:
			parent = (Engine.get_main_loop() as SceneTree).current_scene
		if parent == null:
			return
		parent.add_child(ind)
		ind.global_position = unit.global_position
		ind.z_index = 5
	(ml as SceneTree).process_frame.connect(cb, CONNECT_ONE_SHOT)
