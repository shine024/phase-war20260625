extends Node
## v26.18 卡车↔地图链路 E2E 引导：runner 直挂 /root（本节点随首跳被 SceneTransition 换掉）
## 跑法：godot --rendering-driver opengl3 --path . res://tests/_tmp_truck_map_link_boot.tscn

func _ready() -> void:
	var r := Node.new()
	r.name = "MapLinkRunner"
	r.set_script(load("res://tests/_tmp_map_link_runner.gd"))
	get_tree().root.add_child.call_deferred(r)
