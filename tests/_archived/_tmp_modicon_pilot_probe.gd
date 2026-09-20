extends Control
## v37.2 试点胜者实机渲染探针：8 张新徽章进真实 ModIconTile（26px 常态 / 44px 激活档）。
## 用法：独立窗口跑一次自存图自退出——godot --path . res://tests/_tmp_modicon_pilot_probe.tscn
## 输出：.godot/agent_tools/modicon_pilot_probe.png

const ModIconTileRef = preload("res://scripts/ui/mod_icon_tile.gd")
const STAGE := "res://assets/ui/icons/mod_icons_pilot_stage/"

# mod 文件名 → (中文名, 稀有度)——与试点映射表一致
const ITEMS := [
	["INF_02_ASSAULT_RIFLE", "突击步枪化", "rare"],
	["ARM_03_REACTIVE_ARMOR", "爆反装甲", "epic"],
	["ART_02_EXTENDED_RANGE", "增程弹", "rare"],
	["AA_06_LASER", "激光近防", "legendary"],
	["AIR_06_BVR_MISSILE", "超视距导弹", "epic"],
	["FOR_03_AUTO_TURRET", "自动炮塔", "epic"],
	["REC_04_HIGH_POWER_SCOPE", "高倍瞄准镜", "epic"],
	["enh_dmg_up", "火力训练", "uncommon"],
]


func _ready() -> void:
	var svp := SubViewport.new()
	svp.size = Vector2i(640, 500)
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(svp)
	var bg := ColorRect.new()
	bg.color = Color(0.043, 0.067, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	svp.add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 12)
	grid.position = Vector2(20, 16)
	svp.add_child(grid)
	for it in ITEMS:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 10)
		var tile44 := ModIconTileRef.make({"rarity": it[2], "icon": STAGE + it[0] + ".png", "name": it[1]}, 44, 1)
		var tile26 := ModIconTileRef.make({"rarity": it[2], "icon": STAGE + it[0] + ".png", "name": it[1]}, 26)
		var lbl := Label.new()
		lbl.text = "%s\n%s" % [it[1], it[2]]
		lbl.add_theme_font_size_override("font_size", 13)
		cell.add_child(tile44)
		cell.add_child(tile26)
		cell.add_child(lbl)
		grid.add_child(cell)
	for i in 4:
		await get_tree().process_frame
	var img := svp.get_texture().get_image()
	var out_path := ProjectSettings.globalize_path("res://.godot/agent_tools/modicon_pilot_probe.png")
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	img.save_png(out_path)
	print("[PilotProbe] saved: ", out_path)
	get_tree().quit()
