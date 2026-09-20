extends Node
## R5 内容结构批 boot 冒烟——runner 直挂 /root（autoload 全量可用）
## 跑法：godot --headless --rendering-driver opengl3 --path . res://tests/_tmp_r5_content_boot.tscn

func _ready() -> void:
	var r := Node.new()
	r.name = "R5ContentRunner"
	r.set_script(load("res://tests/_tmp_r5_content_runner.gd"))
	get_tree().root.add_child.call_deferred(r)
