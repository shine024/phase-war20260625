extends Node
## 探针壳：把常驻 runner 挂到 /root（场景切换不释放），逻辑见 _tmp_blackgate_entry_probe_runner.gd

func _ready() -> void:
	var runner := Node.new()
	runner.name = "BlackgateProbeRunner"
	runner.set_script(load("res://tests/_tmp_blackgate_entry_probe_runner.gd"))
	get_tree().root.add_child.call_deferred(runner)
