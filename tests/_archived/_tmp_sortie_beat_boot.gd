extends Node
## 批次③ Task 1 出征过场冒烟——boot 场景（runner 直挂 /root，跨场景切换存活）
## 跑法：godot --headless --path . res://tests/_tmp_sortie_beat_boot.tscn

func _ready() -> void:
	var r := Node.new()
	r.name = "SortieBeatRunner"
	r.set_script(load("res://tests/_tmp_sortie_beat_runner.gd"))
	get_tree().root.add_child.call_deferred(r)
