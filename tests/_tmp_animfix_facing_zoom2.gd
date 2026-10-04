extends Node2D
## v14 facing 终审实拍 v2：saint(我方, setup(true) 原生链) + t90(敌方姿态模拟)
## 敌方姿态 = 摘 setup 挂的驱动 → flip_h=false 复位 → attach(face_right=false) 重挂，
## 与 enemy_unit.gd:252 生产路径（face_right=false）完全同参。
## 契约：sheet 原生朝左 → 敌方显示朝左、我方显示朝右。t=1.0s notify_fire。

const ConstructUnitScene := preload("res://scenes/units/construct_unit.tscn")
const DefaultCards := preload("res://data/default_cards.gd")


var _u1: Node2D
var _u2: Node2D


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.11, 0.16)
	bg.size = Vector2(4000, 2000)
	bg.position = Vector2(-1000, -500)
	add_child(bg)
	_u1 = _spawn_player("ww1_saint", Vector2(320, 300))
	_u2 = _spawn_enemy_pose("mod_t90", Vector2(900, 300))
	var cam := Camera2D.new()
	cam.position = Vector2(610, 300)
	cam.zoom = Vector2.ONE * 0.8
	add_child(cam)
	cam.make_current()
	# idle 自截（约 0.5s 后，ping-pong 中段）；1.0s 开火 + 0.25s 后截攻击帧
	_snap_delayed(0.5, "res://.godot/unit_review/img25_staging/_relight2/_v14_facing2_idle.png")
	_fire_and_snap_atk()


func _snap_delayed(t: float, path: String) -> void:
	await get_tree().create_timer(t).timeout
	await _snap(path)


func _fire_and_snap_atk() -> void:
	await get_tree().create_timer(1.0).timeout
	for u in [_u1, _u2]:
		if is_instance_valid(u):
			UnitFrameAnim.notify_fire(u.get_node("Sprite"))
	print("FACINGZOOM fire notified")
	# 攻击中帧自截（约开火后 0.25s）
	await get_tree().create_timer(0.25).timeout
	await _snap("res://.godot/unit_review/img25_staging/_relight2/_v14_facing2_atk.png")


func _snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("FACINGZOOM saved ", path)


func _spawn_player(cid: String, pos: Vector2) -> Node2D:
	var card: CardResource = DefaultCards.get_card_by_id(cid)
	var stats: UnitStats = UnitStatsTable.build_stats_from_card(card, -1)
	var u: Node2D = ConstructUnitScene.instantiate()
	add_child(u)
	u.setup(true, stats, "")
	u.position = pos
	var spr := u.get_node("Sprite") as Sprite2D
	print("FACINGZOOM %s 我方 flip_h=%s driver=%s" % [cid, spr.flip_h, spr.get_node_or_null("UnitFrameAnimDriver") != null])
	_label(u, "%s 我方(flip)" % cid)
	return u


func _spawn_enemy_pose(cid: String, pos: Vector2) -> Node2D:
	var card: CardResource = DefaultCards.get_card_by_id(cid)
	var stats: UnitStats = UnitStatsTable.build_stats_from_card(card, -1)
	var u: Node2D = ConstructUnitScene.instantiate()
	add_child(u)
	u.setup(true, stats, "")
	u.position = pos
	var spr := u.get_node("Sprite") as Sprite2D
	# 摘掉 setup 按我方挂的驱动，按敌方参数重挂（与 enemy_unit.gd:252 face_right=false 同参）
	var old := spr.get_node_or_null("UnitFrameAnimDriver")
	if old != null:
		spr.remove_child(old)
		old.free()
	spr.flip_h = false
	var ok: bool = UnitFrameAnim.attach(spr, cid, false)
	var drv := spr.get_node_or_null("UnitFrameAnimDriver")
	print("FACINGZOOM %s 敌方 attach=%s flip_h=%s driver_new=%s" % [cid, ok, spr.flip_h, drv != null and drv != old])
	_label(u, "%s 敌方(原生)" % cid)
	return u


func _label(u: Node2D, txt: String) -> void:
	var lbl := Label.new()
	lbl.text = txt
	lbl.position = Vector2(-80, 95)
	u.add_child(lbl)
