extends Node
## v26.2 战斗界面实机验收截图（全视口含 HUD；临时工具）
## 模式文件 .godot/ui_battle_shot_mode.txt：`level=20 frame=520`

const OUT := "res://.godot/agent_tools/battle_ui_v262.png"
const MODE_FILE := "res://.godot/ui_battle_shot_mode.txt"

var _level := 20
var _shot_frame := 520


func _ready() -> void:
	if FileAccess.file_exists(MODE_FILE):
		for kv in FileAccess.get_file_as_string(MODE_FILE).split(" ", false):
			var p := kv.split("=")
			if p.size() == 2:
				if p[0] == "level": _level = int(p[1])
				elif p[0] == "frame": _shot_frame = int(p[1])
	print("[UiBattleShot] level=", _level, " shot_frame=", _shot_frame)
	_run()


func _run() -> void:
	await _wait_frames(20)
	# 载档（玩家卡组/仪器档位来自存档；无档也能开战，只有初始配置）
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("load_game"):
		print("[UiBattleShot] load_game=", sm.call("load_game"))
	await _wait_frames(10)
	# 挂主场景（绝不 change_scene——会释放驱动器）
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	await _wait_frames(150)
	# 清离线奖励弹窗（纯视觉，不领取不写档）
	var popup: Node = main.get("popup_layer")
	if popup != null:
		for c in popup.get_children():
			var sc: Script = c.get_script()
			if sc != null and "offline" in String(sc.resource_path):
				c.queue_free()
	# 选关开战 + 自动部署（复刻世界地图自由选关链路）
	var gm: Node = get_node_or_null("/root/GameManager")
	gm.call("set_current_level", _level)
	var setup: RefCounted = main.get("_battle_setup")
	setup.call("on_start_battle")
	await _wait_frames(45)
	var bar: Node = main.get("bottom_instrument_bar")
	var btn: Button = bar.get("_auto_deploy_btn") if bar != null else null
	if btn != null:
		btn.button_pressed = true
		btn.pressed.emit()
	print("[UiBattleShot] battle L", _level, " started, auto-deploy ON")
	# 等战斗展开（波次进场/交火/血条出现）
	await _wait_frames(_shot_frame)
	# 全视口截图（含 HUD）
	var tex := get_tree().root.get_viewport().get_texture()
	var img: Image = tex.get_image()
	if img != null and not img.is_empty():
		var err := img.save_png(OUT)
		print("[UiBattleShot] saved err=", err, " size=", img.get_size())
	else:
		print("[UiBattleShot] EMPTY capture")
	get_tree().quit()


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
