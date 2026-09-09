extends Node
## 批次② Task 7 boot：改造描述 202 条落地后的 ModificationRegistry 域冒烟
## 跑法：godot --headless --rendering-driver opengl3 --path . res://tests/_tmp_b2_d7_mods_boot.tscn

func _ready() -> void:
	var r := Node.new()
	r.name = "B2D7ModsRunner"
	r.set_script(load("res://tests/_tmp_b2_d7_mods_runner.gd"))
	get_tree().root.add_child.call_deferred(r)
