extends Node
## 泄漏探针引导

func _ready() -> void:
	var r := Node.new()
	r.name = "LeakProbeRunner"
	r.set_script(load("res://tests/_tmp_leak_probe_runner.gd"))
	get_tree().root.add_child.call_deferred(r)
