extends Node
## 探针引导：runner 直挂 /root（boot 场景模式，autoload 全量在位）
## 跑法：godot --headless --rendering-driver opengl3 --path . res://tests/_tmp_probe_show_error_boot.tscn

func _ready() -> void:
	var r := Node.new()
	r.name = "ShowErrorProbeRunner"
	r.set_script(load("res://tests/_tmp_probe_show_error_runner.gd"))
	get_tree().root.add_child.call_deferred(r)
