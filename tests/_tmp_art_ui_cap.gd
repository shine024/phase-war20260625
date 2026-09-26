extends Node
## 美术复核·真实存档逐面板实拍（临时工具，可删）：
## 带存档启动 main，逐个打开 overlay 面板截图（真实数据态），供目视排版复核。
## 运行：echo "uipanel" > .godot/steam_cap_mode.txt 后窗口化跑本场景。

const SHOT_DIR := "res://_steam_assets/shots/"
const MODE_FILE := "res://.godot/steam_cap_mode.txt"

# [面板键, overlay 成员名, 输出名]
const PANELS := [
	["backpack", "backpack_overlay", "ui_backpack"],
	["modification", "modification_overlay", "ui_modification"],
	["evolution", "evolution_overlay", "ui_evolution"],
	["intelligence", "intelligence_overlay", "ui_intelligence"],
	["afk", "afk_overlay", "ui_afk"],
	["faction", "faction_overlay", "ui_faction"],
	["quest", "quest_overlay", "ui_quest"],
	["achievement", "achievement_overlay", "ui_achievement"],
	["collection", "collection_overlay", "ui_collection"],
	["leaderboard", "leaderboard_overlay", "ui_leaderboard"],
	["settings", "settings_overlay", "ui_settings"],
	["help", "help_overlay", "ui_help"],
]


func _ready() -> void:
	var spec := "uipanel"
	if FileAccess.file_exists(MODE_FILE):
		spec = FileAccess.get_file_as_string(MODE_FILE).strip_edges()
	if spec.split(" ", false)[0] != "uipanel":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	await _wait_frames(20)
	var main: Node = await _boot_main()
	for p in PANELS:
		var overlay: Control = main.get(p[1])
		if overlay == null:
			push_warning("[UiCap] 缺 overlay: " + str(p[1]))
			continue
		main.call("_toggle_overlay", overlay, p[0])
		await _wait_frames(80)
		_shot(p[2] + ".png")
		main.call("_toggle_overlay", overlay, p[0])
		await _wait_frames(25)
	# 技能树（v37 起成长入口直进 PhaseMasterSkillHost）
	if main.has_method("_on_progression_pressed"):
		main.call("_on_progression_pressed")
		await _wait_frames(90)
		_shot("ui_skill.png")
		main.call("_toggle_overlay", main.get("growth_overlay"), "growth")
		await _wait_frames(25)
	# 世界地图（真实存档窗口态）
	main.call("_on_world_map")
	await _wait_frames(70)
	_shot("ui_worldmap.png")
	get_tree().quit(0)


func _shot(fname: String) -> void:
	var vp := get_tree().root.get_viewport()
	var tex := vp.get_texture()
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return
	var err := img.save_png(SHOT_DIR + fname)
	print("[UiCap] ", fname, " err=", err)


func _boot_main() -> Node:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("load_game"):
		sm.call("load_game")
	await _wait_frames(10)
	var inst: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	get_tree().current_scene = inst
	await _wait_frames(150)
	var popup: Node = inst.get("popup_layer")
	if popup != null:
		for c in popup.get_children():
			var sc: Script = c.get_script()
			if sc != null and "offline" in String(sc.resource_path):
				c.queue_free()
	return inst


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
