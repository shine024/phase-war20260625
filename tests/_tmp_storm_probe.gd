extends Node
## 风暴复现探针驱动场景：只负责把监视节点挂到 root（独立于 current_scene 存活）。

func _ready() -> void:
	var mon := Node.new()
	mon.name = "StormMonitor"
	mon.set_script(load("res://tests/_tmp_storm_monitor.gd"))
	get_tree().root.add_child.call_deferred(mon)
