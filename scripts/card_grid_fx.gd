extends RefCounted
class_name CardGridFx
## 卡牌格子战术：受击点简短闪光（子弹/光束/炮弹三色）
## v6.4: Polygon2D 对象池复用，避免每击 new/queue_free

const GC = preload("res://resources/game_constants.gd")

const _POOL_SIZE: int = 24  # 命中闪光池容量
const _POOL_META_KEY := "_card_grid_fx_pool"

## 按武器类型取命中闪光颜色
static func _color_for(weapon_type: int) -> Color:
	match weapon_type:
		8, 6:  # LASER, SNIPER
			return Color(0.35, 0.92, 1.0, 0.95)
		3, 9, 11, 10:  # ROCKET, MISSILE, RAIL_CANNON, OMEGA_CANNON
			return Color(1.0, 0.45, 0.15, 0.95)
		_:
			return Color(0.95, 0.9, 0.35, 0.92)

## 获取静态池（挂在主循环 SceneTree root 的 meta 上）
static func _get_pool() -> Array:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return []
	var root: Window = (loop as SceneTree).root
	if root == null:
		return []
	var pool: Array = root.get_meta(_POOL_META_KEY, [])
	if not root.has_meta(_POOL_META_KEY):
		root.set_meta(_POOL_META_KEY, pool)
	return pool

static func spawn_impact(parent: Node2D, world_pos: Vector2, weapon_type: int) -> void:
	if parent == null:
		return
	var poly := _acquire_polygon()
	poly.color = _color_for(weapon_type)
	poly.polygon = PackedVector2Array([Vector2(-7, -5), Vector2(10, 0), Vector2(-7, 5)])
	poly.scale = Vector2.ONE
	poly.modulate = Color.WHITE
	parent.add_child(poly)
	poly.global_position = world_pos
	var tw := parent.create_tween()
	tw.tween_property(poly, "scale", Vector2(1.65, 1.65), 0.06)
	tw.tween_property(poly, "modulate:a", 0.0, 0.12)
	tw.finished.connect(_release_polygon.bind(poly))

## v6.4: 从池中获取（或新建）Polygon2D
static func _acquire_polygon() -> Polygon2D:
	var pool := _get_pool()
	while not pool.is_empty():
		var p: Polygon2D = pool.pop_back()
		if p != null and is_instance_valid(p):
			p.visible = true
			return p
	return Polygon2D.new()

## v6.4: 归还 Polygon2D 到池（脱离场景树后隐藏复用）
static func _release_polygon(poly: Polygon2D) -> void:
	if poly == null or not is_instance_valid(poly):
		return
	if poly.is_inside_tree() and poly.get_parent() != null:
		poly.get_parent().remove_child(poly)
	poly.visible = false
	var pool := _get_pool()
	if pool.size() < _POOL_SIZE:
		pool.append(poly)
	else:
		poly.queue_free()
