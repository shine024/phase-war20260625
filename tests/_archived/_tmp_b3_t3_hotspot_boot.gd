extends Node
## 批次③ Task 3 房间化冒烟——boot 场景（runner 直挂 /root，跨场景切换存活）
## 跑法：godot --headless --path . res://tests/_tmp_b3_t3_hotspot_boot.tscn

func _ready() -> void:
	var r := Node.new()
	r.name = "T3HotspotRunner"
	r.set_script(load("res://tests/_tmp_b3_t3_hotspot_runner.gd"))
	get_tree().root.add_child.call_deferred(r)
