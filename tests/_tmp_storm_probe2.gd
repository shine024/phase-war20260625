extends Node
## 风暴复现探针 v2 驱动场景：把监视节点挂 root（独立于 current_scene 存活）。

func _ready() -> void:
	var mon := Node.new()
	mon.name = "StormMonitor2"
	mon.set_script(load("res://tests/_tmp_storm_monitor2.gd"))
	get_tree().root.add_child.call_deferred(mon)
