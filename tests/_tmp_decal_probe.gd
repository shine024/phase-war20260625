extends Control
## v37.3 战法件贴花实机探针：我方（伪装网+沙包街垒） vs 敌方（扫雷犁+间隙钢板，镜像）。
## 用法：godot --path . res://tests/_tmp_decal_probe.tscn
## 输出：.godot/agent_tools/decal_probe.png

const UnitModDecal = preload("res://scripts/battle/unit_mod_decal.gd")


func _make_mock_unit(parent: Node2D, pos: Vector2, tex_path: String, decal_mods: Array, is_enemy: bool) -> void:
	var holder := Node2D.new()
	holder.position = pos
	parent.add_child(holder)
	var spr := Sprite2D.new()
	spr.name = "Sprite"
	spr.texture = load(tex_path)
	spr.scale = Vector2(0.55, 0.55)
	holder.add_child(spr)
	UnitModDecal.apply(holder, decal_mods, is_enemy)


func _label(parent: Node, pos: Vector2, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", 13)
	parent.add_child(lbl)


func _ready() -> void:
	var svp := SubViewport.new()
	svp.size = Vector2i(680, 380)
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(svp)
	var bg := ColorRect.new()
	bg.color = Color(0.13, 0.16, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	svp.add_child(bg)
	var world := Node2D.new()
	svp.add_child(world)

	var player_tex := "res://assets/card_icons/player/ww1_arm_rolls_mk2.png"
	_make_mock_unit(world, Vector2(180, 200), player_tex,
			["gen_03_camouflage", "for_15_sandbag"], false)
	_make_mock_unit(world, Vector2(500, 200), player_tex,
			["arm_14_mine_plow", "arm_17_spacer_armor"], true)

	_label(world, Vector2(90, 320), "我方：伪装网 + 沙包街垒")
	_label(world, Vector2(400, 320), "敌方：扫雷犁 + 间隙钢板（镜像）")
	for i in 4:
		await get_tree().process_frame
	var img := svp.get_texture().get_image()
	var out_path := ProjectSettings.globalize_path("res://.godot/agent_tools/decal_probe.png")
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	img.save_png(out_path)
	print("[DecalProbe] saved: ", out_path)
	get_tree().quit()
