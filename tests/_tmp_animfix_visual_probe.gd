extends Node2D
## v14 动画修复批引擎实拍探针：construct_unit 完整呈现链 + UnitFrameAnim.attach
## 两行对照：上排=敌方姿态（flip_h=false，sheet 原生朝左）；下排=我方姿态（flip_h=true 镜像朝右）。
## t=1.0s 全员 notify_fire → 截攻击中帧。截图由 run_scene_headless DRIVEN 模式在外部按帧抓取。

const ConstructUnitScene := preload("res://scenes/units/construct_unit.tscn")
const DefaultCards := preload("res://data/default_cards.gd")

## 修复重点单位（朝向/接地/缩放/复活四类都覆盖）
const PLAYER_ROW := ["ww1_saint", "cold_m14", "ww2_is2", "guardian_future_omega", "fut_inf_c96", "ww1_arm_rolls", "ww1_mark4"]
const ENEMY_ROW := ["mod_t90", "ww1_37mm", "cold_m60", "mod_stinger", "ww2_t34_85", "cold_f4"]
const ROW_ENEMY_Y := 150.0
const ROW_PLAYER_Y := 340.0


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.11, 0.16)
	bg.size = Vector2(6000, 2000)
	bg.position = Vector2(-1500, -600)
	add_child(bg)
	var spawned: Array = []
	var x := 0.0
	for cid in ENEMY_ROW:
		var u := _spawn(cid, false)
		if u == null:
			continue
		var w: float = _unit_w(u)
		u.position = Vector2(x + w * 0.5, ROW_ENEMY_Y)
		x += w + 30.0
		spawned.append(u)
	x = 0.0
	for cid in PLAYER_ROW:
		var u := _spawn(cid, true)
		if u == null:
			continue
		var w: float = _unit_w(u)
		u.position = Vector2(x + w * 0.5, ROW_PLAYER_Y)
		x += w + 30.0
		spawned.append(u)
	_fit_camera(x)
	_run_fire_sequence(spawned)


func _spawn(cid: String, face_right: bool) -> Node2D:
	var card: CardResource = DefaultCards.get_card_by_id(cid)
	if card == null:
		print("PROBE miss card ", cid)
		return null
	var stats: UnitStats = UnitStatsTable.build_stats_from_card(card, -1)
	var u: Node2D = ConstructUnitScene.instantiate()
	add_child(u)
	u.setup(true, stats, "")
	var spr := u.get_node("Sprite") as Sprite2D
	var ok: bool = UnitFrameAnim.attach(spr, cid, face_right)
	print("PROBE %s face_right=%s attach=%s foot_frac=%.4f" % [cid, face_right, ok, _foot_of(spr)])
	var lbl := Label.new()
	lbl.text = cid
	lbl.position = Vector2(-60, 78)
	lbl.scale = Vector2(0.7, 0.7)
	u.add_child(lbl)
	return u


func _foot_of(spr: Sprite2D) -> float:
	var d := spr.get_node_or_null("UnitFrameAnimDriver")
	return float(d.get("sheet_foot_frac")) if d != null else -1.0


func _unit_w(u: Node2D) -> float:
	var spr := u.get_node("Sprite") as Sprite2D
	if spr.texture == null:
		return 120.0
	return float(spr.texture.get_width()) * absf(spr.scale.x) * absf(u.scale.x)


func _fit_camera(extent_w: float) -> void:
	var cam := Camera2D.new()
	var rows_h: float = ROW_PLAYER_Y - ROW_ENEMY_Y + 220.0
	cam.position = Vector2(extent_w * 0.5, (ROW_ENEMY_Y + ROW_PLAYER_Y) * 0.5 + 20.0)
	var zoom: float = minf(1280.0 / (extent_w + 80.0), 720.0 / rows_h)
	cam.zoom = Vector2.ONE * clampf(zoom, 0.2, 1.2)
	add_child(cam)
	cam.make_current()


func _run_fire_sequence(units: Array) -> void:
	await get_tree().create_timer(1.0).timeout
	for u in units:
		if is_instance_valid(u):
			UnitFrameAnim.notify_fire(u.get_node("Sprite"))
	print("PROBE fire notified x%d" % units.size())
