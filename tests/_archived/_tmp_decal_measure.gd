extends Control
## v37.3 贴花尺寸实测探针2（复现"半个战场大的沙袋"）：走真实 enemy_unit 链路，
## **不手动重挂贴花**——量 setup() 内 organic 挂载的真实结果。
## 用法：godot --path . res://tests/_tmp_decal_measure.tscn

const EnemyUnitScene = preload("res://scenes/units/enemy_unit.tscn")


func _measure(unit: Node2D, tag: String) -> void:
	var spr: Sprite2D = unit.get_node_or_null("Sprite2D")
	var info := "no-body"
	if spr != null and spr.texture != null:
		var tex := spr.texture
		info = "tex=%s %dx%d scale=%.4f 单位可见宽=%.1f" % [
			tex.get_class(), tex.get_width(), tex.get_height(), spr.scale.x,
			spr.get_rect().size.x * absf(spr.scale.x)]
	var decals := []
	for c in unit.get_children():
		if c is Sprite2D and String(c.name).begins_with("ModDecal_"):
			var s2 := c as Sprite2D
			var dw: float = s2.texture.get_width() * s2.scale.x
			decals.append("%s:实际宽=%.1f" % [String(c.name).trim_prefix("ModDecal_"), dw])
	print("[DecalMeasure2] ", tag, " || ", info, " || decals=", str(decals))


func _ready() -> void:
	# 真实配装自带 art_12_fortification（→沙袋）的炮兵/机枪族
	var archs: Array = ["ww1_sup_mg_nest", "ww1_arty_mortar", "foe_ww1_arty_77mm", "cold_inf_ak"]
	for arch in archs:
		var a := String(arch)
		var u := EnemyUnitScene.instantiate() as Node2D
		add_child(u)
		u.setup(false, 3, a)  # wave=3 中档配装
		if u.has_method("apply_card_grid_enemy_presentation"):
			u.apply_card_grid_enemy_presentation()
		u.set_meta("decal_measure_tag", a)
	print("[DecalMeasure2] ---- 挂载当帧（organic）----")
	await get_tree().process_frame
	for c in get_children():
		if c is Node2D and c.has_meta("decal_measure_tag"):
			_measure(c, String(c.get_meta("decal_measure_tag")) + "/当帧")
	await get_tree().create_timer(0.4).timeout
	print("[DecalMeasure2] ---- 0.4s 后（retry/补偿落地态）----")
	for c in get_children():
		if c is Node2D and c.has_meta("decal_measure_tag"):
			_measure(c, String(c.get_meta("decal_measure_tag")) + "/复测")
	print("[DecalMeasure2] done")
	get_tree().quit()
