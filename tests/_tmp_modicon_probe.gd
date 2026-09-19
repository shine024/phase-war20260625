extends Control
## v37.1 改造图标座视觉探针（临时）：六档稀有度底座 + 详情 44 激活档 + 字母回退 + 禁用态。
## 用法：独立窗口跑一次自存图自退出——
##   godot --path . res://tests/_tmp_modicon_probe.tscn
## 输出：.godot/agent_tools/modicon_probe.png（SubViewport 直采，免窗口 DPI 缩放）

const ModIconTileRef = preload("res://scripts/ui/mod_icon_tile.gd")

const ICON_DIR := "res://assets/ui/icons/mod_icons/"


func _ready() -> void:
	var svp := SubViewport.new()
	svp.size = Vector2i(560, 260)
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(svp)

	var bg := ColorRect.new()
	bg.color = Color(0.043, 0.067, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	svp.add_child(bg)

	var box := VBoxContainer.new()
	box.position = Vector2(16, 12)
	box.add_theme_constant_override("separation", 8)
	svp.add_child(box)

	var title := Label.new()
	title.text = "26px 常态（改造库/制造列表口径）common → mythic"
	box.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var cases := [
		["common", ICON_DIR + "mod_mobility.png"],
		["uncommon", ICON_DIR + "mod_helmet.png"],
		["rare", ICON_DIR + "mod_weapon.png"],
		["epic", ICON_DIR + "mod_ammunition.png"],
		["legendary", ICON_DIR + "gen_stealth_coating.png"],
		["mythic", ICON_DIR + "mod_special.png"],
	]
	for c in cases:
		row.add_child(ModIconTileRef.make({"rarity": c[0], "icon": c[1], "name": c[0]}, 26))

	var title2 := Label.new()
	title2.text = "44px 激活档（详情操作台）· 无图字母回退 · 禁用态"
	box.add_child(title2)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 14)
	box.add_child(row2)
	row2.add_child(ModIconTileRef.make({"rarity": "legendary", "icon": cases[4][1], "name": "leg44"}, 44, 1))
	row2.add_child(ModIconTileRef.make({"rarity": "mythic", "icon": cases[5][1], "name": "myth44"}, 44, 1))
	row2.add_child(ModIconTileRef.make({"rarity": "epic", "icon": "", "name": "fallback"}, 26))
	row2.add_child(ModIconTileRef.make({"rarity": "rare", "icon": cases[2][1], "name": "dim"}, 26, 0, true))

	for i in 4:
		await get_tree().process_frame
	var img := svp.get_texture().get_image()
	var out_path := ProjectSettings.globalize_path("res://.godot/agent_tools/modicon_probe.png")
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	img.save_png(out_path)
	print("[ModIconProbe] saved: ", out_path)
	get_tree().quit()
