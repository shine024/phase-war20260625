extends Node
## 美术复核·修复验证采集（临时工具，可删）：
## 设置段归位 / 挂机胶囊文字 / 商店实态 / 标题版本角标 / 基地状态条阴影 逐镜头。
## 运行：echo "verify" > .godot/steam_cap_mode.txt 后窗口化跑本场景。

const SHOT_DIR := "res://_steam_assets/shots/"
const MODE_FILE := "res://.godot/steam_cap_mode.txt"


func _ready() -> void:
	get_window().always_on_top = true
	var spec := "verify"
	if FileAccess.file_exists(MODE_FILE):
		spec = FileAccess.get_file_as_string(MODE_FILE).strip_edges()
	if spec.split(" ", false)[0] != "verify":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	await _wait_frames(20)
	var main: Node = await _boot_main()
	# 设置（显示段归位验证）
	main.call("_toggle_overlay", main.get("settings_overlay"), "settings")
	await _wait_frames(80)
	_shot("v_settings.png")
	main.call("_toggle_overlay", main.get("settings_overlay"), "settings")
	await _wait_frames(20)
	# 挂机（胶囊文字验证）
	main.call("_toggle_overlay", main.get("afk_overlay"), "afk")
	await _wait_frames(70)
	_shot("v_afk.png")
	main.call("_toggle_overlay", main.get("afk_overlay"), "afk")
	await _wait_frames(20)
	# 商店（真实库存验证）
	main.call("_toggle_overlay", main.get("store_overlay"), "store")
	await _wait_frames(80)
	_shot("v_store.png")
	main.call("_toggle_overlay", main.get("store_overlay"), "store")
	await _wait_frames(20)
	main.queue_free()
	await _wait_frames(10)
	# 标题（版本角标验证：左下角不再被裁）
	var ts: Node = _mount("res://scenes/title_screen.tscn")
	await _wait_frames(150)
	_shot("v_title.png")
	ts.queue_free()
	await _wait_frames(10)
	# 基地（状态条阴影验证，需存档）
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("load_game"):
		sm.call("load_game")
	await _wait_frames(10)
	var tb: Node = _mount("res://scenes/bunker/truck_base.tscn")
	await _wait_frames(150)
	_shot("v_truck.png")
	get_tree().quit(0)


func _shot(fname: String) -> void:
	var vp := get_tree().root.get_viewport()
	var tex := vp.get_texture()
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return
	img.save_png(SHOT_DIR + fname)
	print("[VerifyCap] ", fname)


func _mount(path: String) -> Node:
	var inst: Node = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	get_tree().current_scene = inst
	return inst


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
