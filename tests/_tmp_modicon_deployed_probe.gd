extends Control
## v37.2 部署验收探针：从 ModificationRegistry 真实数据读 icon 字段渲染（全链路验证）。
## 用法：godot --path . res://tests/_tmp_modicon_deployed_probe.tscn
## 输出：.godot/agent_tools/modicon_deployed_probe.png

const ModIconTileRef = preload("res://scripts/ui/mod_icon_tile.gd")
const ModificationRegistry = preload("res://scripts/systems/modification_registry.gd")

const IDS := [
	"inf_01_submachine_gun", "inf_24_urban_warfare", "arm_04_aps",
	"arm_17_spacer_armor", "art_13_apfsds_sabot", "art_02_extended_range",
	"aa_06_laser", "aa_09_smoke_launcher", "air_06_bvr_missile",
	"for_15_sandbag", "rec_04_high_power_scope", "gen_23_singularity_core",
	"gen_03_camouflage", "eng_12_reactive_engineering", "enh_dmg_up",
	"gen_17_electronic_hijack",
]


func _ready() -> void:
	var svp := SubViewport.new()
	svp.size = Vector2i(760, 480)
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(svp)
	var bg := ColorRect.new()
	bg.color = Color(0.043, 0.067, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	svp.add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 14)
	grid.position = Vector2(20, 16)
	svp.add_child(grid)
	var missing := []
	for mid in IDS:
		var md: Dictionary = ModificationRegistry.get_data(mid)
		if md.is_empty():
			missing.append(mid)
			continue
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 8)
		cell.add_child(ModIconTileRef.make(md, 44, 1))
		cell.add_child(ModIconTileRef.make(md, 26))
		var lbl := Label.new()
		lbl.text = String(md.get("name", mid))
		lbl.add_theme_font_size_override("font_size", 12)
		cell.add_child(lbl)
		grid.add_child(cell)
	for i in 4:
		await get_tree().process_frame
	var img := svp.get_texture().get_image()
	var out_path := ProjectSettings.globalize_path("res://.godot/agent_tools/modicon_deployed_probe.png")
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	img.save_png(out_path)
	print("[DeployProbe] saved: ", out_path, " missing=", missing)
	get_tree().quit()
