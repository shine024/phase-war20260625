extends Node
## R4 叙事批次 boot 冒烟——runner 直挂 /root（autoload 全量可用）
## 跑法：godot --rendering-driver opengl3 --path . res://tests/_tmp_r4_narr_boot.tscn

func _ready() -> void:
	var r := Node.new()
	r.name = "R4NarrRunner"
	r.set_script(load("res://tests/_tmp_r4_narr_runner.gd"))
	get_tree().root.add_child.call_deferred(r)
