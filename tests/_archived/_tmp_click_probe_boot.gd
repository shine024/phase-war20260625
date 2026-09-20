extends Node
## 真实点击诊断引导：runner 直挂 /root

func _ready() -> void:
	var r := Node.new()
	r.name = "ClickProbeRunner"
	r.set_script(load("res://tests/_tmp_click_probe_runner.gd"))
	get_tree().root.add_child.call_deferred(r)
