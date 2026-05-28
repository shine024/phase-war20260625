extends RefCounted
class_name CardGridFx
## 卡牌格子战术：受击点简短闪光（子弹/光束/炮弹三色）

const GC = preload("res://resources/game_constants.gd")

static func spawn_impact(parent: Node2D, world_pos: Vector2, weapon_type: int) -> void:
	if parent == null:
		return
	var poly := Polygon2D.new()
	var col := Color(1, 0.85, 0.35, 0.95)
	match weapon_type:
		8, 6:  # LASER, SNIPER
			col = Color(0.35, 0.92, 1.0, 0.95)
		3, 9, 11, 10:  # ROCKET, MISSILE, RAIL_CANNON, OMEGA_CANNON
			col = Color(1.0, 0.45, 0.15, 0.95)
		_:
			col = Color(0.95, 0.9, 0.35, 0.92)
	poly.color = col
	poly.polygon = PackedVector2Array([Vector2(-7, -5), Vector2(10, 0), Vector2(-7, 5)])
	parent.add_child(poly)
	poly.global_position = world_pos
	var tw := parent.create_tween()
	tw.tween_property(poly, "scale", Vector2(1.65, 1.65), 0.06)
	tw.tween_property(poly, "modulate:a", 0.0, 0.12)
	tw.finished.connect(poly.queue_free)
