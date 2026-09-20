extends SceneTree
## 可玩性冒烟配套（临时工具）：把 _tmp_ui_battle_shot 挂到 slot 3 QA 档跑窗口截图。
## 直接跑 _tmp_ui_battle_shot.tscn 会用默认 slot 1（正式档）——本 wrapper 先切 slot 3
## 再挂载截图工具，保证截图轮的读档/装备/存档全部落在 QA 档上。
## 用法：godot --rendering-driver opengl3 --path . --script tests/_tmp_shot_slot3_boot.gd
## （模式文件 .godot/ui_battle_shot_mode.txt 由调用方预先写好 level/frame）

func _initialize() -> void:
	_boot()


func _boot() -> void:
	await process_frame
	await process_frame
	var sm: Node = root.get_node("/root/SaveManager")
	sm.call("set_slot", 3)
	print("[ShotSlot3] slot=", sm.call("get_slot"))
	var node: Node = (load("res://tests/_tmp_ui_battle_shot.gd") as GDScript).new()
	root.add_child(node)
